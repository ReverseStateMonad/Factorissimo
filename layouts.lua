-- Factory layouts

-- Defines
local SIZE_SMALL = 3
local SIZE_MEDIUM = 6
local SIZE_LARGE = 9
local SIZE_HUGE = 12

local function index_size(size)
	if size == SIZE_SMALL then
		return "small"
	elseif size == SIZE_MEDIUM then
		return "medium"
	elseif size == SIZE_LARGE then
		return "large"
	elseif size == SIZE_HUGE then
		return "huge"
	end
	return nil -- should never happen
end

-- Constructor functions
local function construct_tile_map(constructor, radius)
   local tile_map = {}
   local function map_tile_rectangle(tile_name, x1, y1, w, h)
      for x = x1, x1 + w - 1 do
         tile_map[x] = tile_map[x] or {}
         for y = y1, y1 + h - 1 do
            tile_map[x][y] = tile_name
         end
      end
   end

   local function map_floor_border()
      local size = 2 * radius + 2
      map_tile_rectangle("factory-wall", 4, 4, size, size)
   end

   local function map_floor()
      local size = 2 * radius
      map_tile_rectangle("factory-floor", 5, 5, size, size)
   end

   local function map_device_border_at(x, y)
      map_tile_rectangle("factory-wall", x + radius + 3, y + radius + 3, 4, 4)
   end

   local function map_entrance_at(direction)
      if direction == defines.direction.north then
         map_tile_rectangle("factory-wall", radius + 2, 2 * radius + 5, 6, 4)
         map_tile_rectangle("factory-entrance", radius + 3, 2 * radius + 5, 4, 3)
      elseif direction == defines.direction.south then
         map_tile_rectangle("factory-wall", radius + 2, 1, 6, 4)
         map_tile_rectangle("factory-entrance", radius + 3, 2, 4, 3)
      elseif direction == defines.direction.east then
         map_tile_rectangle("factory-wall", 2 * radius + 5, radius + 2, 4, 6)
         map_tile_rectangle("factory-entrance", 2 * radius + 5, radius + 3, 3, 4)
      elseif direction == defines.direction.west then
         map_tile_rectangle("factory-wall", 1, radius + 2, 4, 6)
         map_tile_rectangle("factory-entrance", 2, radius + 3, 3, 4)
      end
   end

   local function map_connection_at(x, y)
      map_tile_rectangle("factory-wall", x - 1, y - 1, 3, 3)
      map_tile_rectangle("factory-entrance", x, y, 1, 1)
   end
   map_floor_border()
   for c1 = 9, 2 * radius, 9 do
      map_connection_at(4, c1)
      map_connection_at(2 * radius + 5, c1)
      map_connection_at(c1, 4)
      map_connection_at(c1, 2 * radius + 5)
	end
   map_floor()
   map_device_border_at(constructor.provider_x, constructor.provider_y)
   for _, coords in pairs(constructor.distributors) do
		map_device_border_at(coords.x, coords.y)
	end
   map_entrance_at(defines.direction.north)
   map_entrance_at(defines.direction.south)
   map_entrance_at(defines.direction.east)
   map_entrance_at(defines.direction.west)
   constructor.tile_map = tile_map
end

local function get_distributors(size)
	local result
	if size == SIZE_SMALL then -- a single distributor will do
		result = {
			{ x = 9, y = 20 }
		}
	elseif size == SIZE_MEDIUM then -- two needed, one at the top and one at the bottom
		result = {
			{ x = 9, y = 38 },
			{ x = -9, y = -38 }
		}
	elseif size < 15 then -- four needed inside the build area
		result = {
			{x = 45, y = 45 },
			{x = -45, y = -45 },
			{x = 45, y = -45 },
			{x = -45, y = 45 }
		}
	end -- size 12 is probably large enough for now (144 X 144 build area, 48 connection points) 
	return result
end

local function make_gates(size)
	local radius = size * 6 + 3.5
	return {
		{ x = -1.5, y = radius, dir = defines.direction.east },
		{ x = -0.5, y = radius, dir = defines.direction.east },
		{ x = 0.5, y = radius, dir = defines.direction.east },
		{ x = 1.5, y = radius, dir = defines.direction.east },
		{ x = -1.5, y = -radius, dir = defines.direction.west },
		{ x = -0.5, y = -radius, dir = defines.direction.west },
		{ x = 0.5, y = -radius, dir = defines.direction.west },
		{ x = 1.5, y = -radius, dir = defines.direction.west },
		{ x = -radius, y = -1.5, dir = defines.direction.south },
		{ x = -radius, y = -0.5, dir = defines.direction.south },
		{ x = -radius, y = 0.5, dir = defines.direction.south },
		{ x = -radius, y = 1.5, dir = defines.direction.south },
		{ x = radius, y = -1.5, dir = defines.direction.north },
		{ x = radius, y = -0.5, dir = defines.direction.north },
		{ x = radius, y = 0.5, dir = defines.direction.north },
		{ x = radius, y = 1.5, dir = defines.direction.north }
	}
end

local function make_constructor(size)
	local radius = size * 6
	local constructor = {
		centering_offset = -5 - radius,
		provider_x = -9,
		provider_y = radius + 2,
		distributors = get_distributors(size),
		gates = make_gates(size)
	}
   construct_tile_map(constructor, radius)
	return constructor
end

-- Constructor table
local constructors = {
	small = make_constructor(SIZE_SMALL), -- size of 3n corresponds to a factory with 6nX6n external footprint, 16n connection points and 36nX36n internal construction area
	medium = make_constructor(SIZE_MEDIUM),
	large = make_constructor(SIZE_LARGE),
	huge = make_constructor(SIZE_HUGE)
}

-- Connection functions

local function make_connection(direction, index, size)
	local result
	local radius = size * 6
	local offset
	if index > math.floor(size * 2 / 3) then
		offset = 0.5
	else
		offset = -1.5
	end
	if direction == defines.direction.north then
		result = {
			outside_x = index - math.floor(size * 2 / 3) + offset,
			outside_y = -0.5 - size,
			inside_x = index * 9 - radius - 4.5,
			inside_y = -0.5 - radius,
			direction_in = (direction + 4) % 8,
			direction_out = direction
		}
	elseif direction == defines.direction.south then
		result = {
			outside_x = index - math.floor(size * 2 / 3) + offset,
			outside_y = 0.5 + size,
			inside_x = index * 9 - radius - 4.5,
			inside_y = 0.5 + radius,
			direction_in = (direction + 4) % 8,
			direction_out = direction
		}
	elseif direction == defines.direction.east then
		result = {
			outside_x = 0.5 + size,
			outside_y = index - math.floor(size * 2 / 3) + offset,
			inside_x = 0.5 + radius,
			inside_y = index * 9 - radius - 4.5,
			direction_in = (direction + 4) % 8,
			direction_out = direction
		}
	elseif direction == defines.direction.west then
		result = {
			outside_x = -0.5 - size,
			outside_y = index - math.floor(size * 2 / 3) + offset,
			inside_x = -0.5 - radius,
			inside_y = index * 9 - radius - 4.5,
			direction_in = (direction + 4) % 8,
			direction_out = direction
		}
	end
	return result
end

local function make_connections(size)
	local result = {}
	for i = 1, math.floor(size * 4 / 3) do
		table.insert(result, make_connection(defines.direction.north, i, size))
		table.insert(result, make_connection(defines.direction.east, i, size))
		table.insert(result, make_connection(defines.direction.south, i, size))
		table.insert(result, make_connection(defines.direction.west, i, size))
	end
	return result
end

-- Connection table
local connections = {
	small = make_connections(SIZE_SMALL),
	medium = make_connections(SIZE_MEDIUM),
	large = make_connections(SIZE_LARGE),
	huge = make_connections(SIZE_HUGE)
}

-- Door information table
local doors = {
	small_north = {
		direction = "north",
		entrance_x = 0,
		entrance_y = -20,
		exit_x = 0,
		exit_y = -3
	},
	small_south = {
		direction = "south",
		entrance_x = 0,
		entrance_y = 20,
		exit_x = 0,
		exit_y = 3
	},
	small_east = {
		direction = "east",
		entrance_x = 20,
		entrance_y = 0,
		exit_x = 3,
		exit_y = 0
	},
	small_west = {
		direction = "west",
		entrance_x = -20,
		entrance_y = 0,
		exit_x = -3,
		exit_y = 0
	},
	medium_north = {
		direction = "north",
		entrance_x = 0,
		entrance_y = -38,
		exit_x = 0,
		exit_y = -6
	},
	medium_south = {
		direction = "south",
		entrance_x = 0,
		entrance_y = 38,
		exit_x = 0,
		exit_y = 6
	},
	medium_east = {
		direction = "east",
		entrance_x = 38,
		entrance_y = 0,
		exit_x = 6,
		exit_y = 0
	},
	medium_west = {
		direction = "west",
		entrance_x = -38,
		entrance_y = 0,
		exit_x = -6,
		exit_y = 0
	},
	large_north = {
		direction = "north",
		entrance_x = 0,
		entrance_y = -56,
		exit_x = 0,
		exit_y = -9
	},
	large_south = {
		direction = "south",
		entrance_x = 0,
		entrance_y = 56,
		exit_x = 0,
		exit_y = 9
	},
	large_east = {
		direction = "east",
		entrance_x = 56,
		entrance_y = 0,
		exit_x = 9,
		exit_y = 0
	},
	large_west = {
		direction = "west",
		entrance_x = -56,
		entrance_y = 0,
		exit_x = -9,
		exit_y = 0
	},
	huge_north = {
		direction = "north",
		entrance_x = 0,
		entrance_y = -74,
		exit_x = 0,
		exit_y = -12
	},
	huge_south = {
		direction = "south",
		entrance_x = 0,
		entrance_y = 74,
		exit_x = 0,
		exit_y = 12
	},
	huge_east = {
		direction = "east",
		entrance_x = 74,
		entrance_y = 0,
		exit_x = 12,
		exit_y = 0
	},
	huge_west = {
		direction = "west",
		entrance_x = -74,
		entrance_y = 0,
		exit_x = -12,
		exit_y = 0
	}
}

local LAYOUT = {
	["small-factory"] = {
		name = "small-factory",
		constructor = constructors.small,
		tier = 0,
		chunk_radius = 1,
		is_power_plant = false,
		provider = "factory-power-provider",
		possible_connections = connections.small,
		north = doors.small_north,
		south = doors.small_south,
		east = doors.small_east,
		west = doors.small_west
	},
	["small-power-plant"] = {
		name = "small-power-plant",
		constructor = constructors.small,
		tier = 0,
		chunk_radius = 1,
		is_power_plant = true,
		provider = "factory-power-receiver",
		possible_connections = connections.small,
		north = doors.small_north,
		south = doors.small_south,
		east = doors.small_east,
		west = doors.small_west
	},
	["medium-factory"] = {
		name = "medium-factory",
		constructor = constructors.medium,
		tier = 1,
		chunk_radius = 2,
		is_power_plant = false,
		provider = "factory-power-provider-mk2",
		possible_connections = connections.medium,
		north = doors.medium_north,
		south = doors.medium_south,
		east = doors.medium_east,
		west = doors.medium_west
	},
	["medium-power-plant"] = {
		name = "medium-power-plant",
		constructor = constructors.medium,
		tier = 1,
		chunk_radius = 2,
		is_power_plant = true,
		provider = "factory-power-receiver-mk2",
		possible_connections = connections.medium,
		north = doors.medium_north,
		south = doors.medium_south,
		east = doors.medium_east,
		west = doors.medium_west
	},
	["large-factory"] = {
		name = "large-factory",
		constructor = constructors.large,
		tier = 2,
		chunk_radius = 2,
		is_power_plant = false,
		provider = "factory-power-provider-mk3",
		possible_connections = connections.large,
		north = doors.large_north,
		south = doors.large_south,
		east = doors.large_east,
		west = doors.large_west
	},
	["large-power-plant"] = {
		name = "large-power-plant",
		constructor = constructors.large,
		tier = 2,
		chunk_radius = 2,
		is_power_plant = true,
		provider = "factory-power-receiver-mk3",
		possible_connections = connections.large,
		north = doors.large_north,
		south = doors.large_south,
		east = doors.large_east,
		west = doors.large_west
	},
	["huge-factory"] = {
		name = "huge-factory",
		constructor = constructors.huge,
		tier = 3,
		chunk_radius = 3,
		is_power_plant = false,
		provider = "factory-power-provider-mk4",
		possible_connections = connections.huge,
		north = doors.huge_north,
		south = doors.huge_south,
		east = doors.huge_east,
		west = doors.huge_west
	},
	["huge-power-plant"] = {
		name = "huge-power-plant",
		constructor = constructors.huge,
		tier = 3,
		chunk_radius = 3,
		is_power_plant = true,
		provider = "factory-power-receiver-mk4",
		possible_connections = connections.huge,
		north = doors.huge_north,
		south = doors.huge_south,
		east = doors.huge_east,
		west = doors.huge_west
	}
}

return LAYOUT