require("config")
-- Local tables
local connection_methods = {}

local connection_radii = {}

-- File constants
local BELT_ITEM_WIDTH = 0.28125 -- Width of a single item on a transport belt
local BELT_PLACEMENTS = {
   0,
   BELT_ITEM_WIDTH,
   2 * BELT_ITEM_WIDTH,
   3 * BELT_ITEM_WIDTH,
}
local LAYOUT = require("layouts")
local LEFT_LINE = defines.transport_line.left_line
local RIGHT_LINE = defines.transport_line.right_line

-- Called during global initialization
function init_connection_structure()
	global["connections"] = global["connections"] or {}
end

-- Connection management functions
local function validate_connection(data)
	if data.__valid then
      local methods = connection_methods[data.__type]
      return methods and methods.validate_connection(data)
	else
		return nil
	end
end

-- Connections are stored in a global list of circular queues with sizes depending on connections' update intervals
-- we expect to update connections many times more frequently than we add new connections, so we want
-- to make our update function as fast as possible at the expense of adding to queue being slightly slower
-- removing connections should also be similarly rare, so we can accept that being a little slower as well
local function process_queue(queue)
   for i = queue.count, 1, -1 do
      local data = queue[i]
      local methods = connection_methods[data.__type]
      if data.__valid and methods and methods.validate_connection(data) then
         local idle_time = data.idle_time
         if idle_time then
            if idle_time == 1 then
               data.idle_time = nil
            else
               data.idle_time = idle_time - 1
            end
         else
            methods.on_update(data)
         end
      else -- invalid connection, remove from queue
         if data.__valid then
            if methods then
               methods.on_destroy(data)
            end
            data.__valid = false
         end
         table.remove(queue, i)
         queue.count = queue.count - 1
      end
   end
end

function update_pending_connections()
	for t, queue in pairs(global["connections"]) do
		if t == 1 then
			-- queue 1 is just a single queue that requires processing every tick
			process_queue(queue)
		else
			-- other queues are lists of sub-queues, plus an index for current sub-queue to process this tick
         local ix = queue.ix
			process_queue(queue[ix])
			-- advance index
			if ix == t then
				queue.ix = 1
			else
				queue.ix = ix + 1
			end
		end
	end
end

local function add_connection_to_queue(data, timing)
	if not global["connections"][timing] then
		-- first connection added with this timing, set up queue
		global["connections"][timing] = {}
		if timing == 1 then
         global["connections"][timing].count = 0
      else
			global["connections"][timing].ix = 1
			for i = 1, timing do
				global["connections"][timing][i] = { count = 0 }
			end
		end
	end
   local queue = global["connections"][timing]
	if timing == 1 then
      local ct = queue.count + 1
      queue.count = ct
      queue[ct] = data
	else
		-- spread connections out across ticks
		local best_ix = 1
		local crowding = queue[1].count
		for i = 2, timing do
			local c = queue[i].count
			if c < crowding then
				best_ix = i
				crowding = c
			end
		end
      local q = queue[best_ix]
      local ct = crowding + 1
      q.count = ct
		q[ct] = data
	end
end

local function test_for_connection(parent_surface, interior, raw_specs, fx, fy)
	local px = fx + raw_specs.outside_x
	local py = fy + raw_specs.outside_y
	for _, outside_entity in pairs(parent_surface.find_entities_filtered{area = {{px-0.2, py-0.2},{px+0.2, py+0.2}}}) do
		if outside_entity.unit_number then
			local entity_type = outside_entity.type
			local methods = connection_methods[entity_type]
			if methods then
				local connectable = methods.connectable_predicate(outside_entity, raw_specs)
				if connectable then
					local data, timing = methods.establish_connection(outside_entity, interior, {
							outside_pos = {x = px, y = py},
							inside_pos = {x = raw_specs.inside_x, y = raw_specs.inside_y},
							direction_in = raw_specs.direction_in,
							direction_out = raw_specs.direction_out,
						})
					if data then
						data.__valid = true
						data.__type = entity_type
						add_connection_to_queue(data, timing)
						return data
					end
				end
			end
		end
	end
	return nil
end

function check_connections(surface_name)
   local structure = global["surface-structure"][surface_name]
   if structure then
      local factory = structure.parent
      if factory and factory.valid then
         local surface = global["factory-surface"][factory.unit_number]
         local parent_surface = factory.surface
         local layout = LAYOUT[global["surface-layout"][surface_name]]
         for id, pconn in pairs(layout.possible_connections) do
            local data = structure.connections[id]
            if data then
               if not validate_connection(data) then
                  destroy_connection(data)
               end
               if not data.__valid then
                  data = nil
                  structure.connections[id] = nil
               end
            end
            if data == nil and structure.valid_placement then
               local pos = factory.position
               structure.connections[id] = test_for_connection(parent_surface, surface, pconn, pos.x, pos.y)
            end
         end
         global["dirty-connections"][surface_name] = nil
      end
   end
end

function connect_surface(surface_name)
   local methods = connection_methods["surface_power"]
   local data, timing = methods.establish_connection(surface_name)
   if data then
      data.__valid = true
      data.__type = "surface_power"
      add_connection_to_queue(data, timing)

      methods = connection_methods["surface_pollution"]
      data, timing = methods.establish_connection(surface_name)
      data.__valid = true
      data.__type = "surface_pollution"
      add_connection_to_queue(data, timing)
   end
   check_connections(surface_name)
end

function destroy_connection(data)
	if data.__valid then
      local methods = connection_methods[data.__type]
      if methods then
         methods.on_destroy(data)
      end
		data.__valid = false
	end
end

function entity_type_connection_radius(entity_type)
	return connection_radii[entity_type]
end

local function register_connectable_entity_type(entity_type, methods, radius)
	connection_methods[entity_type] = methods
	connection_radii[entity_type] = radius or 1 -- all basic connectable entities are 1x1, but larger items (e.g. loaders) may need a larger search radius
end

---- Interface to allow mods to add custom connection types.
---- This interface should be used, once per connection type, directly from control.lua or dependencies, NOT from inside any callbacks such as on_init or on_event.

---- HOW TO USE THIS API:
---- First create an interface like this:
--[[

remote.add_interface("unique_interface_name_here",
	{
		connectable_predicate = function(outside_entity, conn_specs)
			return remote.call(interface, "connectable_predicate", outside_entity, conn_specs)
		end,
		establish_connection = function(outside_entity, interior, conn_specs)
			return remote.call(interface, "connectable_predicate", outside_entity, interior, conn_specs)
		end,
		validate_connection = function(data)
			return remote.call(interface, "validate_connection", data)
		end,
		on_update = function(data)
			return remote.call(interface, "on_update", data)
		end,
		on_destroy = function(data)
			return remote.call(interface, "on_destroy", data)
		end
	}

]]
--Then register your interface using the API, like this:
--[[

remote.call("factorissimo_connections", "register_connectable_entity_type", "type_name_here", "unique_interface_name_here", connection_radius)

]]
-- The functions in the interface should be as follows:

-- connectable_predicate: receives an entity of the type being registered and a table containing basic information on the connection being considered
--		(having these keys: outside_pos, inside_pos, direction_in, direction_out (outside_pos and inside_pos are x,y pairs))
--		returns a boolean value specifying whether the connection should be established

-- establish_connection: receives an entity of the type being registered, the interior surface of the factory being connected to, and the table of connection information
--		should create whatever entity is necessary on the inside of the factory
--		returns a table containing the information necessary for the following functions to operate and the number of ticks between connection updates

-- validate_connection: receives a connection data table (as returned by establish_connection)
--		returns a boolean specifying whether the connected entities are still valid

-- on_update: receives a connection data table (as returned by establish_connection)
--		should perform whatever transfers between the connected entities are necessary
--		no return value needed

-- on_destroy: receives a connection data table (as returned by establish_connection)
--		if the interior entity is still valid should mark it as invalid, otherwise if the exterior entity is valid should mark that as invalid
--		and should perform any specialized clean-up necessary

-- Important notice: Remember that people may disable your mod from their save, in which case your connection type handler is no longer available for Factorissimo.
-- Your responsibility is to make sure that nothing breaks in case this happens. For example you should not make your connection entities unminable, otherwise they cannot be removed after your mod is disabled.

remote.add_interface("factorissimo_connections",
	{
		register_connectable_entity_type = function(entity_type, interface, radius)
			-- See below for calls
			register_connectable_entity_type(entity_type, {
				connectable_predicate = function(outside_entity, conn_specs)
					return remote.call(interface, "connectable_predicate", outside_entity, conn_specs)
				end,
				establish_connection = function(outside_entity, interior, conn_specs)
					return remote.call(interface, "connectable_predicate", outside_entity, interior, conn_specs)
				end,
				validate_connection = function(data)
					return remote.call(interface, "validate_connection", data)
				end,
				on_update = function(data)
					return remote.call(interface, "on_update", data)
				end,
				on_destroy = function(data)
					return remote.call(interface, "on_destroy", data)
				end
			}, radius)
		end
	}
)

-- Connection instances start here
local function validate_basic(data)
	return data.outside.valid and data.inside.valid
end

local function on_destroy_basic(data)
	if data.inside.valid then
		data.inside.destroy()
		if data.outside.valid then
			data.outside.rotatable = true
		end
	elseif data.outside.valid then
		data.outside.destroy()
	end
end

local function belt_update(data)
   local placement_limit = data.placement_limit

   local lane_from, lane_to = data.from_left, data.to_left
   local left_idle = lane_to.get_item_count()
   if left_idle < placement_limit then
      local placement_index = left_idle + 1
      local placement = BELT_PLACEMENTS[placement_index]
      for item_type, supply in pairs(lane_from.get_contents()) do
         local remaining_supply = supply
         while remaining_supply > 0 and lane_to.insert_at(placement, { name = item_type }) do
            remaining_supply = remaining_supply - 1
            placement_index = placement_index + 1
            if placement_index > placement_limit then break end
            placement = BELT_PLACEMENTS[placement_index]
         end
         if remaining_supply == 0 then
            lane_from.remove_item({ name = item_type, count = supply })
            if placement_index > placement_limit then break end
         else
            if remaining_supply ~= supply then
               local transfer_count = supply - remaining_supply
               lane_from.remove_item({ name = item_type, count = transfer_count })
            end
            break
         end
      end
      left_idle = placement_index - 1
   end

   lane_from, lane_to = data.from_right, data.to_right
   local right_idle = lane_to.get_item_count()
   if right_idle < placement_limit then
      local placement_index = right_idle + 1
      local placement = BELT_PLACEMENTS[placement_index]
      for item_type, supply in pairs(lane_from.get_contents()) do
         local remaining_supply = supply
         while remaining_supply > 0 and lane_to.insert_at(placement, { name = item_type }) do
            remaining_supply = remaining_supply - 1
            placement_index = placement_index + 1
            if placement_index > placement_limit then break end
            placement = BELT_PLACEMENTS[placement_index]
         end
         if remaining_supply == 0 then
            lane_from.remove_item({ name = item_type, count = supply })
            if placement_index > placement_limit then break end
         else
            if remaining_supply ~= supply then
               local transfer_count = supply - remaining_supply
               lane_from.remove_item({ name = item_type, count = transfer_count })
            end
            break
         end
      end
      right_idle = placement_index - 1
   end

   local idle_time = math.max(left_idle, right_idle)
   if idle_time > 1 then
      data.idle_time = idle_time - 1
   end
end

local transport_belt_methods = {
	connectable_predicate = function(outside_entity, conn_specs)
		return outside_entity.direction == conn_specs.direction_in or outside_entity.direction == conn_specs.direction_out
	end,
	establish_connection = function(outside_entity, interior, conn_specs)
		local inside_entity = interior.create_entity{ name = outside_entity.name, position = conn_specs.inside_pos, force = outside_entity.force, direction = outside_entity.direction }
		if inside_entity then
			outside_entity.rotatable = false
			inside_entity.rotatable = false
			local from, to
			if outside_entity.direction == conn_specs.direction_in then
				from = outside_entity
            to = inside_entity
			else
				from = inside_entity
            to = outside_entity
			end
         local data = {
               outside = outside_entity,
               inside = inside_entity,
					from_left = from.get_transport_line(LEFT_LINE),
               from_right = from.get_transport_line(RIGHT_LINE),
					to_left = to.get_transport_line(LEFT_LINE),
               to_right = to.get_transport_line(RIGHT_LINE),
               placement_limit = 4,
				}
			local queue_timing = math.floor(BELT_ITEM_WIDTH / outside_entity.prototype.belt_speed)
			-- convert from belt speed in tiles/tick to time in ticks/item
			return data, queue_timing
		end
		return nil
	end,
	validate_connection = validate_basic,
	on_update = belt_update,
	on_destroy = on_destroy_basic
}

register_connectable_entity_type("transport-belt", transport_belt_methods)

local underground_belt_methods = {
	connectable_predicate = function(outside_entity, conn_specs)
		return outside_entity.direction == conn_specs.direction_in and outside_entity.belt_to_ground_type == "output" or outside_entity.direction == conn_specs.direction_out and outside_entity.belt_to_ground_type == "input"
	end,
	establish_connection = function(outside_entity, interior, conn_specs)
		local inside_entity = interior.create_entity{ name = outside_entity.name, position = conn_specs.inside_pos, force = outside_entity.force, direction = outside_entity.direction, type = outside_entity.belt_to_ground_type }
		if inside_entity then
			outside_entity.rotatable = false
			inside_entity.rotatable = false
			local from, to
			if outside_entity.direction == conn_specs.direction_in then
				from = outside_entity
            to = inside_entity
			else
				from = inside_entity
            to = outside_entity
			end
         local data = {
               outside = outside_entity,
               inside = inside_entity,
					from_left = from.get_transport_line(LEFT_LINE),
               from_right = from.get_transport_line(RIGHT_LINE),
					to_left = to.get_transport_line(LEFT_LINE),
               to_right = to.get_transport_line(RIGHT_LINE),
               placement_limit = 2,
				}
			local queue_timing = math.floor(BELT_ITEM_WIDTH / outside_entity.prototype.belt_speed)
			return data, queue_timing
		end
		return nil
	end,
	validate_connection = validate_basic,
	on_update = belt_update,
	on_destroy = on_destroy_basic
}

register_connectable_entity_type("underground-belt", underground_belt_methods)

local function on_pipe_update(data)
   local outside, inside = data.outside.fluidbox, data.inside.fluidbox
	local fluid1 = outside[1]
	local fluid2 = inside[1]
   local delta
	if fluid1 and fluid2 then
      local fluid_type = fluid1.type
		if fluid_type == fluid2.type then
         local a1, a2 = fluid1.amount, fluid2.amount
         delta = math.abs(a1 - a2)
			local t1, t2 = fluid1.temperature, fluid2.temperature
			if t1 == t2 then -- should be very common to have equal temps, and significantly reduces computation cost
            fluid1.amount = (a1 + a2) / 2
				outside[1] = fluid1
            inside[1] = fluid1
			else
				local amount = a1 + a2
				local temperature = (a1 * t1 + a2 * t2) / amount -- Total temperature balance
            local fluid = { type = fluid_type, amount = amount / 2, temperature = temperature }
				outside[1] = fluid
            inside[1] = fluid
			end
      else
         delta = 0
		end
	else
		local fluid = fluid1 or fluid2
      if fluid then
         delta = fluid.amount
         fluid.amount = delta / 2
         outside[1] = fluid
         inside[1] = fluid
      else
         delta = 0
      end
	end

   if delta <= 8 then
      data.idle_time = 9 - math.ceil(delta)
   end
end

local pipe_methods = {
	connectable_predicate = function(outside_entity, conn_specs)
		return true
	end,
	establish_connection = function(outside_entity, interior, conn_specs)
		local inside_entity = interior.create_entity{ name = outside_entity.name, position = conn_specs.inside_pos, force = outside_entity.force }
		if inside_entity then
			return {
				inside = inside_entity,
				outside = outside_entity
			}, 1
		end
		return nil
	end,
	validate_connection = validate_basic,
	on_update = on_pipe_update,
	on_destroy = on_destroy_basic
}

register_connectable_entity_type("pipe", pipe_methods)

local pipe_to_ground_methods = {
	connectable_predicate = function(outside_entity, conn_specs)
		return outside_entity.direction == conn_specs.direction_in
	end,
	establish_connection = function(outside_entity, interior, conn_specs)
		local inside_entity = interior.create_entity{ name = outside_entity.name, position = conn_specs.inside_pos, force = outside_entity.force, direction = outside_entity.direction }
		if inside_entity then
			outside_entity.rotatable = false
			inside_entity.rotatable = false
			return {
				inside = inside_entity,
				outside = outside_entity
			}, 1
		end
		return nil
	end,
	validate_connection = validate_basic,
	on_update = on_pipe_update,
	on_destroy = on_destroy_basic
}

register_connectable_entity_type("pipe-to-ground", pipe_to_ground_methods)

-- Basic factory surface connections (special cases, connectable_predicate not required)
local function validate_by_factory(data)
   return data.factory.valid
end

local function no_op_on_destroy(data)
   return nil
end

local power_methods = {
   establish_connection = function(surface_name)
      local layout = LAYOUT[global["surface-layout"][surface_name]]
      if layout then
         local data
         local structure = global["surface-structure"][surface_name]
         local factory = structure.parent
         local provider = structure.power_provider
         if layout.is_power_plant then
            data = {
               factory = factory,
               from = provider,
               to = factory,
               multiplier = factorissimo.config.power_output_multiplier
            }
         else
            data = {
               factory = factory,
               from = factory,
               to = provider,
               multiplier = factorissimo.config.power_input_multiplier
            }
         end
         return data, 1
      else
         return nil
      end
   end,
   validate_connection = validate_by_factory,
   on_update = function(data)
      local from, to = data.from, data.to
      local supply, unused = from.energy, to.energy
      local max_transfer_energy = math.min(supply, to.electric_buffer_size - unused)
      from.energy = supply - max_transfer_energy
      to.energy = unused + max_transfer_energy * data.multiplier
   end,
   on_destroy = no_op_on_destroy
}

register_connectable_entity_type("surface_power", power_methods)

local pollution_methods = {
   establish_connection = function(surface_name)
      local structure = global["surface-structure"][surface_name]
      local factory = structure.parent
      return {
         factory = factory,
         from = global["factory-surface"][factory.unit_number],
         to = factory.surface,
         position = factory.position
      }, 60
   end,
   validate_connection = validate_by_factory,
   on_update = function(data)
      -- transfer pollution
      local from, to, pos = data.from, data.to, data.position
      local mul = factorissimo.config.pollution_multiplier
      for y = -1,1,2 do
         for x = -1,1,2 do
            local pos2 = { x, y }
            local pollution = from.get_pollution(pos2) / 2
            from.pollute(pos2, -pollution)
            to.pollute(pos, pollution * mul)
         end
      end
   end,
   on_destroy = no_op_on_destroy
}

register_connectable_entity_type("surface_pollution", pollution_methods)