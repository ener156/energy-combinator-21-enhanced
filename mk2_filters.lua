-- Owns MK2's selection of buildable energy-prototype filters from circuit inputs.
-- Circuit-section output and feedback bookkeeping are owned by circuit_slots.lua.
local mk2_modes = require "mk2_modes"
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
    if not is_mk2 then return nil, 'all' end
    local config = mk2_modes.get(state.entity.unit_number)
    if config.mode == 'all' then return nil, 'all' end
    if config.mode == 'manual' then
        local manual = mk2_modes.valid_manual_filters(state.entity.unit_number)
        return #manual > 0 and manual or nil, 'manual'
    end
    local control = state.control
    local connected_wire_count = (
        (control.get_circuit_network(defines.wire_connector_id.circuit_red)   and 1 or 0) +
        (control.get_circuit_network(defines.wire_connector_id.circuit_green) and 1 or 0))
    -- AUTO: filter only when valid external energy-item signals exist.
    -- Empty or disconnected circuit inputs fall back to full-grid MK1 mode.
    -- Feedback from this combinator is subtracted below to avoid self-filtering.
    if connected_wire_count == 0 then return nil, 'auto' end
    local signals = control.entity.get_signals(defines.wire_connector_id.circuit_green, defines.wire_connector_id.circuit_red)
    local filters = {}
    if signals == nil then return nil, 'auto' end
    for _, signal in pairs(signals) do
        local item = prototypes.item[signal.signal.name]
        local prev_count = state.prev_outputs[signal.signal.name] or 0
        local entity = item and item.place_result
        if entity and has_energy(entity) and signal.count > prev_count * connected_wire_count then
            -- Red/green can carry the same entity; keep one prototype only.
            local present = false
            for _, existing in ipairs(filters) do
                if existing == entity.name then present = true; break end
            end
            if not present then table.insert(filters, entity.name) end
        end
    end
    table.sort(filters)
    return #filters > 0 and filters or nil, 'auto'
end

return M
