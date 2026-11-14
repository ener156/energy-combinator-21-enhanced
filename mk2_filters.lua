-- Owns MK2's selection of buildable energy-prototype filters from circuit inputs.
-- Circuit-section output and feedback bookkeeping are owned by circuit_slots.lua.
local M = {}

---@param entity LuaEntityPrototype
---@return boolean
local function has_energy(entity)
    return (entity.get_max_energy_usage()      or 0) > 0
        or (entity.get_max_energy_production() or 0) > 0
end

---@param state ECombState
---@return string[] | nil
function M.read(state, is_mk2)
    local control = state.control
    if not is_mk2 then return end
    local connected_wire_count = (
        (control.get_circuit_network(defines.wire_connector_id.circuit_red)   and 1 or 0) +
        (control.get_circuit_network(defines.wire_connector_id.circuit_green) and 1 or 0))
    -- With no red/green control wire, MK2 behaves like unfiltered MK1.
    -- nil = no circuit filter mode; {} = circuit mode with no valid filters.
    -- Do not rely on get_signals(): native combinator outputs can echo here.
    if connected_wire_count == 0 then return nil end
    local signals = control.entity.get_signals(defines.wire_connector_id.circuit_green, defines.wire_connector_id.circuit_red)
    local filters = {}
    if signals == nil then return filters end
    for _, signal in pairs(signals) do
        local item = prototypes.item[signal.signal.name]
        local prev_count = state.prev_outputs[signal.signal.name] or 0
        local entity = item and item.place_result
        if entity and has_energy(entity) and signal.count > prev_count * connected_wire_count then
            table.insert(filters, entity.name)
        end
    end
    return filters
end

return M
