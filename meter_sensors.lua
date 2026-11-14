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
local function connect_wires(a,b)
    for _, wire in ipairs{defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green} do
        if not a.get_circuit_network(wire) then
            local connector_a = a.get_wire_connector(wire, true)
            local connector_b = b.get_wire_connector(wire, true)
            connector_a.connect_to(connector_b, false, defines.wire_origin.script)
        end
    end
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
