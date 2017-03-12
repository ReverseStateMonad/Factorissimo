if not factorissimo then factorissimo = {} end
if not factorissimo.config then factorissimo.config = {} end

require("config")
require("updates")
require("connections")

-- GLOBALS --
local function guarantee_global_table(subtable)
   global[subtable] = global[subtable] or {}
end

local function glob_init()
   guarantee_global_table("dirty-connections")
	guarantee_global_table("factory-surface")
	guarantee_global_table("surface-structure")
   guarantee_global_table("surface-construction-queue")
	guarantee_global_table("surface-layout")
	guarantee_global_table("surface-exit")
	guarantee_global_table("health-data")
   guarantee_global_table("exit-check")
	init_connection_structure()
end

script.on_init(function()
	glob_init()
	init_update_system()
end)

script.on_configuration_changed(function(configuration_changed_data)
	glob_init()
	do_required_updates()
end)

-- SETTINGS --

local DEBUG = false

local LAYOUT = require("layouts")

-- FACTORY DATA GET/SET FUNCTIONS
local function get_surface(factory)
	return global["factory-surface"][factory.unit_number]
end

local function get_structure(surface)
	return global["surface-structure"][surface.name]
end

local function set_structure(surface, structure_id, entity)
	global["surface-structure"][surface.name][structure_id] = entity
end

local function get_layout_by_name(surface_name)
   local layout_name = global["surface-layout"][surface_name]
	if layout_name then
		return LAYOUT[layout_name]
	else
		return nil
	end
end

local function get_layout(surface)
	return get_layout_by_name(surface.name)
end

local function save_health_data(factory)
	local i = #global["health-data"] + 1
	if i > factory.prototype.max_health-1 then
		for _, player in pairs(game.players) do
			player.print("You have picked up too many factories at once. Tell the dev about this, he'll be impressed and slightly worried.")
		end
	else
		if i > factory.prototype.max_health-100 then
			for _, player in pairs(game.players) do
				player.print("Approaching factory pickup limit. What are you doing with all these factories in your inventory?")
			end
		end
		global["health-data"][i] = {
			surface = get_surface(factory),
			health = factory.health,
			backer_name = factory.backer_name,
			energy = factory.energy,
		}
		factory.health = i
	end
end

local function get_and_delete_health_data(health)
	local health_int = math.floor(health+0.5)
	local data = global["health-data"][health_int]
	global["health-data"][health_int] = nil
	return data
end

local function mark_connections_dirty(factory)
	local surface = get_surface(factory)
	if surface then
      global["dirty-connections"][surface.name] = true
   end
end

-- FACTORY INTERIOR GENERATION --

-- Daytime values: 0 is eternal night, 1 is regular, 2 is eternal day
local function reset_daytime(surface)
	local daytime = 0
	local layout = get_layout(surface)
	if layout then
      if layout.is_power_plant then
         daytime = factorissimo.config.power_plant_daytime
      else
         daytime = factorissimo.config.factory_daytime
      end
      if daytime == 1 then
         surface.daytime = game.surfaces["nauvis"].daytime
         surface.freeze_daytime(false)
      else
         if daytime == 0 then
            surface.daytime = 0.5 -- Midnight
         else
            surface.daytime = 0 -- Midday
         end
         surface.freeze_daytime(true)
      end
   end
end

local function delete_entities(surface)
	for _, entity in pairs(surface.find_entities({{-1000, -1000},{1000, 1000}})) do
		entity.destroy()
	end
end

local function place_entity(surface, data, structure_id)
   local entity = surface.create_entity(data)
	if entity then
		entity.minable = false
		entity.rotatable = false
		entity.destructible = false
		if structure_id then
			set_structure(surface, structure_id, entity)
		end
	end
end

local function process_tile_map(tile_map, surface, x_offset, y_offset)
   local data, count = {}, 0
   for x, col in pairs(tile_map) do
      local x_final = x + x_offset
      for y, tile_name in pairs(col) do
         count = count + 1
         data[count] = { name = tile_name, position = { x_final, y + y_offset } }
      end
   end
   surface.set_tiles(data)
end

local function build_factory_interior(surface_name)
   local structure = global["surface-structure"][surface_name]
   local factory = structure.parent
   local surface = get_surface(factory)
   local layout = get_layout_by_name(surface_name)
   local constructor = layout.constructor
	delete_entities(surface)
   local centering_offset = constructor.centering_offset

	process_tile_map(constructor.tile_map, surface, centering_offset, centering_offset)
   local parent_force = factory.force
   place_entity(surface, { name = layout.provider, position = { constructor.provider_x, constructor.provider_y }, force = parent_force }, "power_provider")
	for _, coords in ipairs(constructor.distributors) do
      place_entity(surface, { name = "factory-power-distributor", position = { coords.x, coords.y }, force = parent_force })
	end
	for _, coords in ipairs(constructor.gates) do
		place_entity(surface, { name = "factory-gate", position = { coords.x, coords.y }, force = parent_force, direction = coords.dir })
	end
   global["surface-construction-queue"][surface_name] = nil
end

script.on_event(defines.events.on_chunk_generated, function(event)
   local queue = global["surface-construction-queue"]
   local surface_name = event.surface.name
   local chunks_remaining = queue[surface_name]
   if chunks_remaining then
      queue[surface_name] = chunks_remaining - 1
   end
end)

-- FACTORY WORLD ASSIGNMENT --
local function get_exit_offsets(factory, layout)
   local f_pos, surface = factory.position, factory.surface
   local fx, fy = f_pos.x, f_pos.y
   return {
		north = {x = fx + layout.north.exit_x, y = fy + layout.north.exit_y, surface = surface},
		south = {x = fx + layout.south.exit_x, y = fy + layout.south.exit_y, surface = surface},
		east = {x = fx + layout.east.exit_x, y = fy + layout.east.exit_y, surface = surface},
		west = {x = fx + layout.west.exit_x, y = fy + layout.west.exit_y, surface = surface}
	}
end

local function create_surface(factory, layout)
	local surface_name = "Inside factory " .. factory.unit_number
	local surface = game.create_surface(surface_name, { width = 64 * layout.chunk_radius - 62, height = 64 * layout.chunk_radius - 62 })
	surface.request_to_generate_chunks({0, 0}, layout.chunk_radius)
	global["factory-surface"][factory.unit_number] = surface -- surface_name
	global["surface-structure"][surface_name] = { parent = factory, connections = {} }
   global["surface-construction-queue"][surface_name] = 4 * layout.chunk_radius * layout.chunk_radius
	global["surface-layout"][surface_name] = layout.name
	global["surface-exit"][surface_name] = get_exit_offsets(factory, layout)
	reset_daytime(surface)
end

local function connect_factory_to_existing_surface(factory, surface)
   local surface_name = surface.name
	global["factory-surface"][factory.unit_number] = surface
	global["surface-structure"][surface_name].parent = factory
	local layout = get_layout(surface)
	global["surface-exit"][surface_name] = get_exit_offsets(factory, layout)
   connect_surface(surface_name)
end

-- PLACING, PICKING UP FACTORIES

-- RECURSION

local function factory_placement_valid(inner_surface, outer_surface)
	if get_structure(inner_surface) and get_structure(outer_surface) then
      if factorissimo.config.recursion == 0 then
         return false
      elseif factorissimo.config.recursion < 3 then
         local inner_tier = get_layout(inner_surface).tier or 0
         local outer_tier = get_layout(outer_surface).tier or 0
         if factorissimo.config.recursion == 1 then return inner_tier < outer_tier end
         return inner_tier <= outer_tier
      end
	end
	return true
end

local function on_built_factory(factory)
	factory.operable = false
	local health_data = get_and_delete_health_data(factory.health)
   local inner_surface
	if health_data then
      inner_surface = health_data.surface
      health_data.surface = nil
		connect_factory_to_existing_surface(factory, inner_surface)
		for k, v in pairs(health_data) do
			factory[k] = v
		end
	else
      inner_surface = get_surface(factory)
      if not inner_surface then -- Should always be the case, but just in case
         local layout = LAYOUT[factory.name]
         create_surface(factory, layout)
         factory.energy = 0
         inner_surface = get_surface(factory)
      end
	end
   local outer_surface = factory.surface
   local structure = get_structure(inner_surface)
   structure.valid_placement = factory_placement_valid(inner_surface, outer_surface)
end

 -- Workaround to not really being able to store information in a deconstructed entity:
 -- I store the factory information in the factory item by modifying its health value right before it is picked up, and storing all relevant
 -- information in a global table indexed by the new unique health value (including the factory's actual health). When the damaged factory item is
 -- placed down again, I look for its health value in the table and retrieve the information from there, restoring its name, health,
 -- stored energy, and most importantly the link to the surface acting as its interior.
 -- This has the neat side effect of making initialized factories non-stackable.
 -- However things may break a little if some other mod has the bright idea of changing health values of my items,
 -- or aborting factory deconstruction, or, well, you get the point.

local function on_picked_up_factory(factory)
	save_health_data(factory)
	local structure = get_structure(get_surface(factory))
	for _, data in pairs(structure.connections) do
		destroy_connection(data)
	end
	structure.connections = {}
end

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, function(event)
	local entity = event.created_entity
	if LAYOUT[entity.name] then -- entity is factory
		on_built_factory(entity)
	else
		local radius = entity_type_connection_radius(entity.type)
		if radius then
			-- Entity may need to update factory connections
			local x, y = entity.position.x, entity.position.y
			local entities = entity.surface.find_entities_filtered{ area = {{x - radius, y - radius},{x + radius, y + radius}}, type = "assembling-machine" }
			for _, entity2 in pairs(entities) do
				if get_surface(entity2) then
					-- entity2 is factory
					mark_connections_dirty(entity2)
				end
			end
		end
	end
end)

script.on_event({defines.events.on_preplayer_mined_item, defines.events.on_robot_pre_mined}, function(event)
	local factory = event.entity
	if LAYOUT[factory.name] then
		on_picked_up_factory(factory)
	end
end)

script.on_event({defines.events.on_entity_died}, function(event)
	local factory = event.entity
	if LAYOUT[factory.name] then
		local structure = get_structure(get_surface(factory))
		for _, data in pairs(structure.connections) do
			destroy_connection(data)
		end
		structure.connections = {}
	end
end)

-- FACTORY MECHANICS

-- ENTERING/LEAVING FACTORIES

local function get_entrance_at(surface, px, py, pn)
	local transfer_to = nil
   local entities = surface.find_entities_filtered{ area = { { px - 0.3, py - 0.3 }, { px + 0.3, py + 0.3 } }, type = "assembling-machine" }
   for _, entity in pairs(entities) do
      local layout = LAYOUT[entity.name]
		if layout then
         local fpos = entity.position
         local fx, fy = fpos.x, fpos.y
         local entrance = false
         if math.abs(fx - px) < 0.6 then
            if fy < py then
               entrance = "south"
            else
               entrance = "north"
            end
         elseif math.abs(fy - py) < 0.6 then
            if fx < px then
               entrance = "east"
            else
               entrance = "west"
            end
         end
         if entrance then
            local new_surface = get_surface(entity)
            local surface_name = new_surface.name
            if global["exit-check"][pn] ~= surface_name then
               local structure = get_structure(new_surface)
               if structure.valid_placement and not global["surface-construction-queue"][surface_name] then
                  reset_daytime(new_surface)
                  transfer_to = { x = layout[entrance].entrance_x, y = layout[entrance].entrance_y, surface = new_surface }
                  break
               end
            end
         end
		end
	end
   global["exit-check"][pn] = nil
	return transfer_to
end

local function get_exit_at(surface, px, py, pn)
	local transfer_to = nil
	-- Depends on location/orientation of gates
	local entities = surface.find_entities_filtered{ area = { { px - 1, py - 1 }, { px + 1, py + 1 } }, name = "factory-gate" }
	if entities[1] then
		local dir = entities[1].direction
		if dir == defines.direction.east then
			if py > 0 then
				dir = "south" -- factory gate has direction perpendicular to the exit direction
			else
				dir = "north"
			end
		elseif dir == defines.direction.north then
			if px > 0 then
				dir = "east"
			else
				dir = "west"
			end
		end
      local surface_name = surface.name
      transfer_to = global["surface-exit"][surface_name][dir]
      if transfer_to then
         global["exit-check"][pn] = surface_name
      end
	end
	return transfer_to
end

local function attempt_player_transfer(player)
   if player.connected and player.character and player.vehicle == nil then
      local surface, position, id_num = player.surface, player.position, player.character.unit_number
      local x, y = position.x, position.y

      local destination = get_entrance_at(surface, x, y, id_num) or get_exit_at(surface, x, y, id_num)

      if destination then
         player.teleport({destination.x, destination.y}, destination.surface)
      end
   end
end

-- register factory management in on tick event

script.on_event(defines.events.on_tick, function(event)
	-- PLAYER TRANSFER
	for _, player in pairs(game.players) do
      attempt_player_transfer(player)
	end
	
	-- CONNECTIONS
	update_pending_connections() -- this now includes pollution + energy transfer
   for surface_name, _ in pairs(global["dirty-connections"]) do
      if not global["surface-construction-queue"][surface_name] then -- Don't check connections before construction of interior is finished
         check_connections(surface_name) -- Check for updated connections
      end
	end

	-- FACTORY CONSTRUCTION
   for surface_name, chunks_remaining in pairs(global["surface-construction-queue"]) do
      if chunks_remaining <= 0 then
         build_factory_interior(surface_name)
         connect_surface(surface_name) -- Connect surface and check connections once the factory is finished
      end
   end
end)

-- DEBUGGING

if DEBUG then
	script.on_event(defines.events.on_player_created, function(event)
		local player = game.players[event.player_index]
		player.insert{name="small-factory", count=10}
		player.insert{name="express-transport-belt", count=200}
		player.insert{name="steel-axe", count=10}
		player.insert{name="medium-electric-pole", count=100}
		player.cheat_mode = true
		--player.gui.top.add{type="button", name="enter-factory", caption="Enter Factory"}
		--player.gui.top.add{type="button", name="leave-factory", caption="Leave Factory"}
		player.gui.top.add{type="button", name="debug", caption="Debug"}
		player.force.research_all_technologies()
	end)
end

script.on_event(defines.events.on_gui_click, function(event)
	local player = game.players[event.player_index]
	if event.element.name == "enter-factory" then
		try_enter_factory(player)
	end
	if event.element.name == "leave-factory" then
		try_leave_factory(player)
	end
	if event.element.name == "debug" then
		debug_this(player)
	end
end)

function dbg(text)
	if DEBUG then
		game.players[1].print(text)
	end
end

function debug_this(player)
	if player.connected then
		if player.character then
			dbg("Player character: " .. player.character.name)
		else
			dbg("Player missing character")
		end
	else
		return
	end
	local i = 0
	local entities = player.surface.find_entities_filtered{area = {{player.position.x-3, player.position.y-3},{player.position.x+3, player.position.y+3}}}
	for _, entity in pairs(entities) do
		if entity.unit_number then
			i = i + 1
			player.print("(" .. i .. ") Entity: " .. entity.name)
			player.print("(" .. i .. ") Buffer size: " .. (entity.electric_buffer_size or "-"))
			player.print("(" .. i .. ") Energy: " .. (entity.energy or "-"))
			player.print("(" .. i .. ") Health: " .. (entity.health or "-"))
		end
	end
end