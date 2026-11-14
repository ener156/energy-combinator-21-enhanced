-- Owns active combinator state lifecycles, persistent registrations,
-- hidden-meter attachment and already-placed combinator reconstruction.
-- The main script continues to own Factorio event registration.
local circuit_slots = require "circuit_slots"
local meter_sensors = require "meter_sensors"
local alt_units = require "alt_units"
local M = {}

---@class ECombState
    ---@field control LuaConstantCombinatorControlBehavior
    ---@field entity LuaEntity
    ---@field tick integer
    ---@field net LuaEntity @ meter-network entity
    ---@field sat LuaEntity @ meter-satisfaction entity
    ---@field input integer
    ---@field output integer
    ---@field prev_outputs table<string,integer>

---@param entity LuaEntity
---@return ECombState
local function new_state(entity, is_mk2)
    local state = {entity=entity, tick=game.tick, prev_outputs={}}
    state.net = meter_sensors.obtain(entity, 'power-combinator-meter-network')
    state.sat = meter_sensors.obtain(entity, 'power-combinator-meter-satisfaction')
    if not (state.net and state.sat) then
        -- Do not leave a hidden network meter orphaned when its pair cannot
        -- be created (for example, during placement or mod migration).
        meter_sensors.dispose(state)
        return nil
    end
    meter_sensors.connect(state.sat, state.net)
    state.control = entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    circuit_slots.initialize(state.control, is_mk2)
    state.light = state.sat.get_or_create_control_behavior()
    state.light.circuit_condition = {condition={
        comparator = "=",
        first_signal = circuit_slots.factor_signal,
        constant = 1, -- 0 means on and 1 means off
    }}
    return state
end

---@param entity LuaEntity
function M.allocate(entity, allowed, is_filter)
    if entity and entity.unit_number and allowed[entity.prototype.name] then
        local state = new_state(entity, is_filter[entity.name])
        if not state then return end
        storage.state[entity.unit_number] = state
        local factor_slot = circuit_slots.get(state.control, 1)
        alt_units.sync(state, factor_slot and factor_slot.min or 3)
        local registration = script.register_on_object_destroyed(entity)
        state.registration = registration
        storage.registrations[registration] = entity.unit_number
    end
end

---@param entity LuaEntity | EntityUnitNumber
function M.cleanup(entity)
    if type(entity) =="number" then
        ---@type table
        entity = {unit_number=entity}
    end
    if entity and entity.unit_number then
        local state = storage.state[entity.unit_number]
        if state then
            alt_units.remove(entity.unit_number)
            meter_sensors.dispose(state)
            storage.state[entity.unit_number] = nil
            if state.registration then storage.registrations[state.registration] = nil end
        end
    end
end

function M.rebuild(prototype_names, allowed, is_filter)
    storage.state = {}
    storage.registrations = {}
    for _, surface in pairs(game.surfaces) do
        for _, combinator in pairs(surface.find_entities_filtered{name=prototype_names}) do
            M.allocate(combinator, allowed, is_filter)
        end
    end
end

function M.cleanup_registration(registration)
    local unit_number = storage.registrations and storage.registrations[registration]
    if unit_number then M.cleanup(unit_number) end
end

return M
