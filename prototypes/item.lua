local function create_building_item(name, order_flag)
	return {
		type = "item",
		name = name,
		icon = "__Factorissimo__/graphics/icons/" .. name .. ".png",
		flags = {"goes-to-quickbar"},
		subgroup = "production-machine",
		order = "y[factory]-" .. order_flag .. "[" .. name .. "]",
		place_result = name,
		stack_size = 10
	}
end

local function create_accumulator_item(name, order_flag)
	return {
    type = "item",
    name = name,
    icon = "__base__/graphics/icons/accumulator.png",
    flags = {"hidden"},
    subgroup = "production-machine",
    order = "y[factory]-z[invisible]-" .. order_flag,
    place_result = name,
    stack_size = 50
  }
end

data:extend({
  create_building_item("small-factory", "a"),
  create_building_item("medium-factory", "b"),
  create_building_item("large-factory", "c"),
  create_building_item("huge-factory", "d"),
  create_accumulator_item("factory-power-provider", "a"),
  create_accumulator_item("factory-power-provider-mk2", "b"),
  create_accumulator_item("factory-power-provider-mk3", "c"),
  create_accumulator_item("factory-power-provider-mk4", "d"),
  create_building_item("small-power-plant", "e"),
  create_building_item("medium-power-plant", "f"),
  create_building_item("large-power-plant", "g"),
  create_building_item("huge-power-plant", "h"),
  create_accumulator_item("factory-power-receiver", "e"),
  create_accumulator_item("factory-power-receiver-mk2", "f"),
  create_accumulator_item("factory-power-receiver-mk3", "g"),
  create_accumulator_item("factory-power-receiver-mk4", "h"),
  {
    type = "item",
    name = "factory-power-distributor",
    icon = "__base__/graphics/icons/substation.png",
    flags = {"hidden"},
    subgroup = "production-machine",
    order = "y[factory]-z[invisible]-c",
    place_result = "factory-power-distributor",
    stack_size = 50
  },
  {
    type = "item",
    name = "factory-gate",
    icon = "__base__/graphics/icons/gate.png",
    flags = {"hidden"},
    subgroup = "production-machine",
    order = "y[factory]-z[invisible]-d",
    place_result = "factory-gate",
    stack_size = 50
  }
})