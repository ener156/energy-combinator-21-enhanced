-- Owns hidden electrical meters, their wire connection and status lamp.
-- Behavior preserved from Energy Combinator 1.2.14 during modular extraction.
local M = {}

local function find_entities(entity, name)
    return entity.surface.find_entities_filtered{name=name, position=entity.position}
end

local function find_single_entity(parent, name)
    local result
    for i,entity in pairs(find_entities(parent, name)) do
        if i == 1 then result = entity else entity.destroy() end
    end
    return result
end

local function create_hidden_entity(surface, options)
    local entity = surface.create_entity(options)
    if not entity then return nil end
    entity.destructible = false
    entity.minable_flag = false
    return entity
end

local function default_entity(parent, name)
    return find_single_entity(parent, name)
        or create_hidden_entity(parent.surface, {
               name = name,
               position = parent.position,
               force = parent.force,
           })
end


---@param a LuaEntity
---@param b LuaEntity
-- Even poles whose prototype has no red/green anchor can expose a
-- generic connector in Factorio 2.1. Player wires attached to the invisible
-- meter must be removed. Never touch copper/electricity or parent combinator
-- circuits; these two hidden sensor entities are the only cleanup targets.
local function strip_hidden_circuits(entity)
    if not (entity and entity.valid) then return end
    for _, id in ipairs{
        defines.wire_connector_id.circuit_red,
        defines.wire_connector_id.circuit_green,
    } do
        local connector = entity.get_wire_connector(id, false)
        if connector and connector.connection_count > 0 then
            connector.disconnect_all(defines.wire_origin.player)
            -- No internal circuit links are needed anymore; remove legacy
            -- invisible links left by earlier ECMOD versions as well.
            connector.disconnect_all(defines.wire_origin.script)
        end
    end
end

local function connect_wires(satisfaction, network)
    strip_hidden_circuits(satisfaction)
    strip_hidden_circuits(network)
end

local function toggle_light(state, value)
    local circuit = state.light.circuit_condition
    local condition = circuit.condition or {}
    local desired = value and 0 or 1
    if condition.constant == desired then return end
    condition.constant = desired
    circuit.condition = condition
    state.light.circuit_condition = circuit
end

M.obtain = default_entity
M.connect = connect_wires
M.set_light = toggle_light

function M.dispose(state)
    if state.net and state.net.valid then state.net.destroy() end
    if state.sat and state.sat.valid then state.sat.destroy() end
    state.net, state.sat = nil, nil
end

return M
