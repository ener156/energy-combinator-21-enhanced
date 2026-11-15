-- Energy Combinator 2.1: Tips & Tricks example.
-- This file is executed as a simulation init command, not as control.lua.
-- Keep the scene independent of technologies, inventories, robots and
-- obsolete 1.x constant-combinator signal methods.
local surface = game.surfaces[1]
if not surface then return end

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

-- In this view the combintors report the net's normal four power signals.
-- MK2 remains in its automatic default: without external filter signals it
-- measures the full electric network, just like MK1.
