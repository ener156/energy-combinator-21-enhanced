-- Rounding modes are shared by the map so all combinators and multiplayer clients
-- use identical circuit values. Existing 1.2.7 behavior remains the default.
local function rounding_setting(name, default, order)
    return {
        type = "string-setting",
        name = name,
        setting_type = "runtime-global",
        allowed_values = {"nearest", "up", "down"},
        default_value = default,
        order = order,
    }
end

data:extend({
    {
        type = "int-setting",
        name = "power-combinator-update-tick",
        setting_type = "startup",
        minimum_value = 1,
        default_value = 5,
        order = "a",
    },
    rounding_setting("energy-combinator-round-current-consumption", "nearest", "b-a"),
    rounding_setting("energy-combinator-round-current-production", "nearest", "b-b"),
    rounding_setting("energy-combinator-round-maximum-consumption", "up", "b-c"),
    rounding_setting("energy-combinator-round-maximum-production", "down", "b-d"),
})
