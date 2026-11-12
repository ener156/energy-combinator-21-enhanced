-- Owns all render objects used for the ALT-mode unit label.
-- Only stable render IDs are stored. Rendering objects follow their entity target.
local units = require "power_units"
local M = {}
local SETTING = "energy-combinator-show-alt-units"

local function label_map()
    storage.energy_alt_labels = storage.energy_alt_labels or {}
    return storage.energy_alt_labels
end

function M.remove(unit_number)
    if not unit_number then return end
    local map = label_map()
    local record = map[unit_number]
    if record then
        local object = rendering.get_object_by_id(record.id)
        if object then object.destroy() end
        map[unit_number] = nil
    end
end

function M.sync(state, factor)
    if not state or not state.entity or not state.entity.valid then return end
    local entity = state.entity
    local id = entity.unit_number
    if not settings.global[SETTING].value then
        M.remove(id)
        return
    end

    local map = label_map()
    local record = map[id]
    local object = record and rendering.get_object_by_id(record.id)
    if object then
        if record.factor ~= factor then
            object.text = units.factor_label(factor)
            record.factor = factor
        end
        return
    end
    local created = rendering.draw_text{
        text = units.factor_label(factor),
        surface = entity.surface,
        target = {type="entity", entity=entity, offset={0, -0.75}},
        color = {r=1, g=0.93, b=0.64, a=1},
        scale = 0.75,
        alignment = "center",
        vertical_alignment = "bottom",
        only_in_alt_mode = true,
        forces = {entity.force},
    }
    map[id] = {id=created.id, factor=factor}
end

function M.reset()
    local map = label_map()
    for unit_number in pairs(map) do M.remove(unit_number) end
end

function M.rebuild(states, factor_getter)
    M.reset()
    for _, state in pairs(states or {}) do
        if state.entity and state.entity.valid then
            M.sync(state, factor_getter(state))
        end
    end
end

return M
