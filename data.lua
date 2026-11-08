local common = require "common"
local data_utility = require "data_utility"

local times = data_utility.times
local deepmerge = data_utility.deepmerge
local set = data_utility.set
local rm_icon = data_utility.rm_icon
local tint_hint = data_utility.tint_hint
local rescale = data_utility.rescale

--------------------------------------------------------------------------------

---@type fun(tb: table): table
table.deepcopy = table.deepcopy

local max_health = 100
local color = {
    cyan   = {r=0.6,g=1,b=1,a=1},
    yellow = {r=1,g=1,b=0,a=1},
    dark   = {r=0,g=0,b=0,a=1},
}

local hidden = {
    "placeable-neutral",
    "not-deconstructable",
    "not-blueprintable",
    "not-on-map",
    "hide-alt-info",
    "not-in-made-in",
    "no-copy-paste",
    "not-in-kill-statistics",
    "not-selectable-in-game",
}

local transparent = {
    filename = common.graphics_path .. "transparent.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    frame_count = 1,
    axially_symmetrical = false,
    direction_count = 1,
}
local transparent4 = set(table.deepcopy(transparent),'direction_count',4)

local function fix_copper(point)
    point = table.deepcopy(point)
    for _,layer in pairs(point) do
        layer.copper = layer.red
    end
    return times(4, point)
end


local steam = data.raw['fluid']['steam']
local cc = data.raw["constant-combinator"]["constant-combinator"]


local icons = {
    internal = {
        {icon = steam.icon, icon_size = steam.icon_size, tint = color.yellow},
        {icon = common.graphics_path .. "power-production.png", icon_size = 64, scale = 0.5, tint = color.dark},
    },
    combinator = {
        {icon = cc.icon, icon_size = cc.icon_size, tint = color.yellow},
        {icon = common.graphics_path .. "power-production.png", icon_size = 64, scale = 0.5},
    },
    combinator2 = {
        {icon = cc.icon, icon_size = cc.icon_size, tint = color.yellow},
        {icon = common.graphics_path .. "power-production.png", icon_size = 64, scale = 0.5},
        {
            icon = "__core__/graphics/icons/search.png",
            icon_size = 32,
            shift = {-10, 10},
            scale = 0.4,
        },
    },
}


data:extend{


    -- entity --------------------------------------------------------------


    tint_hint(rm_icon(deepmerge(table.deepcopy(cc), {
        name = common.prototype_prefix .. "power-combinator",
        minable = {result = common.prototype_prefix .. "power-combinator"},
        flags = {"not-rotatable", table.unpack(cc.flags)},
        fast_replaceable_group = "power-combinator",
        icons = icons.combinator,
        order = "z-c[combinator]-c[constant-combinator]-p[power-combinator]-a[MK1]",
    })), color.yellow),

    rescale(tint_hint(rm_icon(deepmerge(table.deepcopy(cc), {
        name = common.prototype_prefix .. "power-combinator-MK2",
        minable = {result = common.prototype_prefix .. "power-combinator-MK2"},
        flags = {"not-rotatable", table.unpack(cc.flags)},
        fast_replaceable_group = "power-combinator",
        icons = icons.combinator2,
        --[[ Disable scale
        collision_box = {{-0.75, -0.75}, {0.75, 0.75}},
        selection_box = {{-1, -1}, {1, 1}},]]
        order = "z-c[combinator]-c[constant-combinator]-p[power-combinator]-b[MK2]",
    })), color.yellow), 1),

    {   type = "lamp", -- has energy satisfaction
        name = "power-combinator-meter-satisfaction",
        collision_mask = {layers={ghost=true}},
        max_health = max_health,
        selectable_in_game = false,
        light = {intensity = 0, size = 0},
        flags = {"not-selectable-in-game", table.unpack(hidden)},
        order = "z",
        glow_size = 0,
        glow_color_intensity = 0,
        signal_to_color_mapping = {},
        collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
        selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
--         selection_box = {{-1, -1}, {0, 0}},
        icons = icons.internal,
        picture_on  = {layers={transparent}},
        picture_off = {layers={transparent}},
        energy_usage_per_tick = "0.00000000001W",
        energy_source = {
            type = "electric",
            usage_priority = "primary-input",
            render_no_power_icon = false,
        },
        circuit_wire_connection_point = table.deepcopy(circuit_connector_definitions["lamp"].points),
        circuit_connector_sprites = table.deepcopy(circuit_connector_definitions["lamp"].sprites),
        circuit_wire_max_distance = 0.5,
    },

    {   type = "electric-pole", -- has electric_network_statistics
        name = "power-combinator-meter-network",
        collision_mask = {layers={ghost=true}},
        max_health = max_health,
        flags = hidden,
        order = "z",
        supply_area_distance = 0.5,
        maximum_wire_distance = 9,
        track_coverage_during_build_by_moving = false,
        draw_circuit_wires = false,
        collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
        selection_box = {{-0.2, 0.1}, {0.7, 0.7}},
        connection_points = fix_copper(circuit_connector_definitions["lamp"].points),
        water_reflection = {pictures = transparent},
        radius_visualisation_picture = {
            filename = "__base__/graphics/entity/small-electric-pole/electric-pole-radius-visualization.png",
            width = 12,
            height = 12,
            priority = "extra-high-no-scale",
        },
        icons = icons.internal,
        pictures = {layers = {
            transparent4,
            set(table.deepcopy(transparent4),'draw_as_shadow',true),
        }},
    },


    -- item ----------------------------------------------------------------


    rm_icon(deepmerge(table.deepcopy(data.raw.item["constant-combinator"]), {
        name = common.prototype_prefix .. "power-combinator",
        place_result = common.prototype_prefix .. "power-combinator",
        order = "c[combinators]-c[constant-combinator]-p[power-combinator]-a[MK1]",
        icons = icons.combinator,
    })),

    rm_icon(deepmerge(table.deepcopy(data.raw.item["constant-combinator"]), {
        name = common.prototype_prefix .. "power-combinator-MK2",
        place_result = common.prototype_prefix .. "power-combinator-MK2",
        order = "c[combinators]-c[constant-combinator]-p[power-combinator]-b[MK2]",
        icons = icons.combinator2,
    })),


    -- recipe --------------------------------------------------------------


    {   type = "recipe",
        name = common.prototype_prefix .. "power-combinator",
        energy_required = 15,
        ingredients = {
            {type="item", name="small-lamp", amount=2},
            {type="item", name="constant-combinator", amount=2},
        },
        results = {{type="item", name=common.prototype_prefix .. "power-combinator", amount=1}},
        enabled = false,
    },

    {   type = "recipe",
        name = common.prototype_prefix .. "power-combinator-MK2",
        energy_required = 30,
        ingredients = {
            {type="item", name=common.prototype_prefix .. "power-combinator", amount=2},
            {type="item", name="constant-combinator", amount=2},
            {type="item", name="advanced-circuit", amount=4},
        },
        results = {{type="item", name=common.prototype_prefix .. "power-combinator-MK2", amount=1}},
        enabled = false,
    },


    -- technology ----------------------------------------------------------


    {   type = "technology",
        name = common.prototype_prefix .. "power-combinator",
        prerequisites = {
            "circuit-network",
            "electric-energy-distribution-1",
        },
        icon = common.graphics_path .. "technology.png",
        icon_size = 128,
        order = "a-h-d-a",
        effects = {
            {type = "unlock-recipe", recipe = common.prototype_prefix .. "power-combinator"},
        },
        unit = {
            time = 30,
            count = 50,
            ingredients = {
                {"automation-science-pack", 1},
                {  "logistic-science-pack", 1},
            },
        },
    },

    {   type = "technology",
        name = common.prototype_prefix .. "power-combinator-MK2",
        prerequisites = {
            common.prototype_prefix .. "power-combinator",
            "electric-energy-distribution-2",
        },
        icon = common.graphics_path .. "technology2.png",
        icon_size = 128,
        order = "a-h-d-a",
        effects = {
            {type = "unlock-recipe", recipe = common.prototype_prefix .. "power-combinator-MK2"},
        },
        unit = {
            time = 45,
            count = 100,
            ingredients = {
                {"automation-science-pack", 1},
                {  "logistic-science-pack", 1},
                {  "chemical-science-pack", 1},
            },
        },
    },


    -- achievement ---------------------------------------------------------


    {   type = "research-achievement",
        name = "power-combinator-research",
        technology = common.prototype_prefix .. "power-combinator",
        order = "a[progress]-o[combinator]-p[power]-[MK1]",
        icon = common.graphics_path .. "research-achievement.png",
        icon_size = 128,
    },

    {   type = "research-achievement",
        name = "power-combinator-research2",
        technology = common.prototype_prefix .. "power-combinator-MK2",
        order = "a[progress]-o[combinator]-p[power]-[MK2]",
        icon = common.graphics_path .. "research2-achievement.png",
        icon_size = 128,
    },


    -- signal --------------------------------------------------------------


    {   type = "virtual-signal",
        name = "power-consumption",
        order = "a[power]-a[cur]-a[consumption]",
        subgroup = "combinator-signals",
        icon = common.graphics_path .. "power-consumption.png",
        icon_size = 64,
    },

    {   type = "virtual-signal",
        name = "power-production",
        order = "a[power]-a[cur]-b[production]",
        subgroup = "combinator-signals",
        icon = common.graphics_path .. "power-production.png",
        icon_size = 64,
    },

    {   type = "virtual-signal",
        name = "power-max-consumption",
        order = "a[power]-m[max]-a[consumption]",
        subgroup = "combinator-signals",
        icon = common.graphics_path .. "power-max-consumption.png",
        icon_size = 64,
    },

    {   type = "virtual-signal",
        name = "power-max-production",
        order = "a[power]-m[max]-b[production]",
        subgroup = "combinator-signals",
        icon = common.graphics_path .. "power-max-production.png",
        icon_size = 64,
    },


    -- tips and tricks -----------------------------------------------------


    {   type = "tips-and-tricks-item",
        name = common.prototype_prefix .. "power-combinator",
        tag = "[item=power-combinator]",
        category = "circuit-network",
        dependencies = {"circuit-network"},
        order = "b",
        indent = 1,
        trigger = {
            type = "sequence",
            triggers = {
                {
                    type = "research",
                    technology = common.prototype_prefix .. "power-combinator",
                },
                {
                    type = "time-elapsed",
                    ticks = 60 * 60 * 5,
                },
            },
        },
        simulation = {
            mods = {common.mod_name}, -- use the current fork mod ID for the simulation
            init_file = common.mod_root .. "scripts/simulation.lua",
            generate_map = false,
            checkboard = true,
        },
    },

}


    -- shared with capacity-combinator -------------------------------------


 do local circuit = data.raw["tips-and-tricks-item"]["circuit-network"]
    circuit.category = "circuit-network"
    circuit.order = "a"
    circuit.is_title = true
end

if not data.raw["tips-and-tricks-item-category"]["circuit-network"] then data:extend{
    {   type = "tips-and-tricks-item-category",
        name = "circuit-network",
        order = "z-[circuit-network]",
    },
} end

if not data.raw["virtual-signal"]["power-factor"] then data:extend{
    {   type = "virtual-signal",
        name = "power-factor",
        order = "a[power]-z[factor]",
        subgroup = "combinator-signals",
        icon = common.graphics_path .. "power-factor.png",
        icon_size = 64,
    },
} end

if not data.raw["item-subgroup"]["combinator-signals"] then data:extend{
    {   type = "item-subgroup",
        name = "combinator-signals",
        group = "signals",
        order = "c[combinator]-a[signal]-a[info]",
    },
} end
