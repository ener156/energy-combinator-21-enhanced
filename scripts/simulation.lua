-- Energy Combinator 2.1: Tips & Tricks example.
-- This file is executed as a simulation init command, not as control.lua.
-- Keep the scene independent of technologies, inventories, robots and
-- obsolete 1.x constant-combinator signal methods.
local function build_demo()
    local surface = game.surfaces[1]
    if not surface then return false end

    local force = game.forces.player
    surface.daytime = 0
    surface.freeze_daytime = true

-- Only place prototypes provided by the active simulation mod set.
-- Tips simulations need not include the player's other installed mods.
local function place(name, x, y)
    if not prototypes.entity[name] then return nil end
    return surface.create_entity{
        name = name,
        position = {x, y},
        force = force,
        raise_built = true,
    }
end

-- Two measurement tiers sharing a single local electric network.
local mk1 = place("power-combinator", -4, 0)
local mk2 = place("power-combinator-MK2", -4, 2)
local pole = place("substation", 0, 0)
local radar = place("radar", 5, 1)

-- Native producers visibly demonstrate the difference between production
-- and consumption. The demo intentionally avoids technology-unlocked items
-- such as logistic storage chests and other nonessential entities.
local producers = {
    {-5, -4}, {-1, -4}, {3, -4}, {7, -4},
}
for _, position in ipairs(producers) do
    place("solar-panel", position[1], position[2])
end

    -- Both combinators now report the four power signals from one network.
    -- Without an external filter, MK2 defaults to measuring the full grid.
    return mk1 ~= nil and mk2 ~= nil and pole ~= nil and radar ~= nil
end

-- Tip init_file runs in a simulation console and builds the scene immediately.
-- Requiring the module from a headless test has no side effects: the same
-- function can be invoked explicitly to test the real scene definition.
if game and game.simulation then build_demo() end
return build_demo
