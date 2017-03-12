local LAYOUT = require("layouts")
-- local duplicates of functions from control.lua in case of subsequent changes
local function add_tile_rect_03(tiles, tile_name, xmin, ymin, xmax, ymax) -- tiles is rw
	local i = #tiles
	for x = xmin, xmax-1 do
		for y = ymin, ymax-1 do
			i = i + 1
			tiles[i] = {name = tile_name, position={x, y}}
		end
	end
end

local function place_entity_03(surface, entity_name, x, y, force, direction)
	local entity = surface.create_entity{name = entity_name, position = {x, y}, force = force, direction = direction}
	if entity then
		entity.minable = false
		entity.rotatable = false
		entity.destructible = false
	end
	return entity
end

local function update03()
   -- Update exit data
   if global["surface-exit"] then
      for surface_name, old_exit in pairs(global["surface-exit"]) do
         local fx, fy = old_exit.x, old_exit.y - 3
         local surface = old_exit.surface
         local layout = LAYOUT["small-factory"]
         global["surface-exit"][surface_name] = {
            north = {x = fx + layout.north.exit_x, y = fy + layout.north.exit_y, surface = surface},
            south = {x = fx + layout.south.exit_x, y = fy + layout.south.exit_y, surface = surface},
            east = {x = fx + layout.east.exit_x, y = fy + layout.east.exit_y, surface = surface},
            west = {x = fx + layout.west.exit_x, y = fy + layout.west.exit_y, surface = surface}
         }
      end
   end
   -- Fix surface layouts
   if global["surface-layout"] and global["surface-structure"] then
		for surface_name, structure in pairs(global["surface-structure"]) do -- Don't iterate over surface-layout because we're changing that
			local layout = global["surface-layout"][surface_name]
			-- Update layout
         if type(layout) == "table" then
            if layout.is_power_plant then
               global["surface-layout"][surface_name] = "small-power-plant"
            else
               global["surface-layout"][surface_name] = "small-factory"
            end
         end

         local surface = surfaces[surface_name]
         if surface then
            layout = LAYOUT[global["surface-layout"][surface_name]]
            -- Fix tiles
            local tiles = {}
            for _, rect in pairs(layout.constructor.rectangles) do
               add_tile_rect_03(tiles, rect.tile, rect.x1, rect.y1, rect.x2, rect.y2)
            end
            surface.set_tiles(tiles)
            -- Place exits
            for _, coords in pairs(layout.constructor.gates) do
               place_entity_03(surface, "factory-gate", coords.x, coords.y, structure.parent.force, coords.dir)
            end
         end
      end
   end
   -- Remove obsolete connections
   for _, q in ipairs(global["connections"]) do
      for _, data in ipairs(q) do
         if data.inside.valid then
            data.inside.destroy()
            if data.outside.valid then
               data.outside.rotatable = true
            end
         elseif data.outside.valid then
            data.outside.destroy()
         end
      end
   end
   -- Remove obsolete connection queue
   global["connections"] = {}
   -- Update existing factories
   if global["surface-structure"] then
      for surface_name, structure in pairs(global["surface-structure"]) do
         global["dirty-connections"][surface_name] = true
         if structure.finished then
            connect_surface(surface_name)
         else
            global["surface-construction-queue"][surface_name] = structure.chunks_required - structure.chunks_generated
         end
         structure.connections = {}
         structure.finished = nil
         structure.ticks = nil
         structure.chunks_required = nil
         structure.chunks_generated = nil
      end
   end
end
-- update01 and update02 have been superseded by newer changes

function init_update_system()
		global.update_version = 3 -- Latest update
end

function do_required_updates()
	global.update_version = global.update_version or 0
	if global.update_version < 3 then
		update03()
		global.update_version = 3
	end
end
