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
local function make_rectangle(tile, x1, y1, w, h)
	return { x1 = x1, x2 = x1 + w, y1 = y1, y2 = y1 + h, tile = tile }
end

local function floor_size_border(radius)
	local corner, size = -1 - radius, 2 * radius + 2
	return make_rectangle("factory-wall", corner, corner, size, size)
end

local function floor_size(radius)
	local corner, size = -radius, 2 * radius
	return make_rectangle("factory-floor", corner, corner, size, size)
end

local function device_border_at(x, y)
	return make_rectangle("factory-wall", x - 2, y - 2, 4, 4)
end

local function entrance_border_at(direction, radius)
	local result
	if direction == defines.direction.north then
		result = make_rectangle("factory-wall", -3, radius, 6, 4)
	elseif direction == defines.direction.south then
		result = make_rectangle("factory-wall", -3, -4 - radius, 6, 4)
	elseif direction == defines.direction.east then
		result = make_rectangle("factory-wall", radius, -3, 4, 6)
	elseif direction == defines.direction.west then
		result = make_rectangle("factory-wall", -4 - radius, -3, 4, 6)
	end
	return result
end

local function entrance_at(direction, radius)
	local result
	if direction == defines.direction.north then
		result = make_rectangle("factory-entrance", -2, radius, 4, 3)
	elseif direction == defines.direction.south then
		result = make_rectangle("factory-entrance", -2, -3 - radius, 4, 3)
	elseif direction == defines.direction.east then
		result = make_rectangle("factory-entrance", radius, -2, 3, 4)
	elseif direction == defines.direction.west then
		result = make_rectangle("factory-entrance", -3 - radius, -2, 3, 4)
	end
	return result
end

local function connection_border_at(x, y)
	return make_rectangle("factory-wall", math.floor(x) - 1, math.floor(y) - 1, 3, 3)
end

local function connection_at(x, y)
	return make_rectangle("factory-entrance", math.floor(x), math.floor(y), 1, 1)
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
		rectangles = {},
		provider_x = -9,
		provider_y = radius + 2,
		distributors = get_distributors(size),
		gates = make_gates(size)
	}
	table.insert(constructor.rectangles, floor_size_border(radius))
	table.insert(constructor.rectangles, entrance_border_at(defines.direction.north, radius))
	table.insert(constructor.rectangles, entrance_border_at(defines.direction.south, radius))
	table.insert(constructor.rectangles, entrance_border_at(defines.direction.east, radius))
	table.insert(constructor.rectangles, entrance_border_at(defines.direction.west, radius))
	table.insert(constructor.rectangles, device_border_at(constructor.provider_x, constructor.provider_y))
	for c1 = 4.5 - radius, radius - 4.5, 9 do
		table.insert(constructor.rectangles, connection_border_at(-0.5 - radius, c1))
		table.insert(constructor.rectangles, connection_border_at(radius + 0.5, c1))
		table.insert(constructor.rectangles, connection_border_at(c1, -0.5 - radius))
		table.insert(constructor.rectangles, connection_border_at(c1, radius + 0.5))
	end
	table.insert(constructor.rectangles, floor_size(radius))
	for _, coords in pairs(constructor.distributors) do
		table.insert(constructor.rectangles, device_border_at(coords.x, coords.y))
	end
	table.insert(constructor.rectangles, entrance_at(defines.direction.north, radius))
	table.insert(constructor.rectangles, entrance_at(defines.direction.south, radius))
	table.insert(constructor.rectangles, entrance_at(defines.direction.east, radius))
	table.insert(constructor.rectangles, entrance_at(defines.direction.west, radius))
	for c1 = 4.5 - radius, radius - 4.5, 9 do
		table.insert(constructor.rectangles, connection_at(-0.5 - radius, c1))
		table.insert(constructor.rectangles, connection_at(radius + 0.5, c1))
		table.insert(constructor.rectangles, connection_at(c1, -0.5 - radius))
		table.insert(constructor.rectangles, connection_at(c1, radius + 0.5))
	end
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