local common = require "common"
local power_rounding = require "power_rounding"
local alt_units = require "alt_units"
local energy_gui = require "energy_gui"
local electric_statistics = require "electric_statistics"
local electric_direct = require "electric_direct"
local filter_baseline = require "filter_baseline"
local circuit_slots = require "circuit_slots"
local mk2_filters = require "mk2_filters"
local INT32_MAX = 2^31

local MK1 = common.prototype_prefix .. "power-combinator"
local MK2 = common.prototype_prefix .. "power-combinator-MK2"
local MK = {[MK1]=true,[MK2]=true}
local features = {filter = {[MK2]=true}}
local GUI_SHORTCUT = "energy-combinator-open-settings"
local gui_open_requests = {} -- one-tick permission for deliberate GUI opening

--------------------------------------------------------------------------------

local function diff(a,b) return a - (b or a) end
local function is_int32(n) return n == n and n >= -INT32_MAX and n < INT32_MAX end

-- Maximum-consumption rounding is handled without precision truncation in power_rounding.lua.
-- Runtime-global settings are sampled once per update tick, so changes apply
-- immediately to every combinator without extra storage or migration events.
local function rounding_modes()
    local configured = settings.global
    return {
        current_consumption = configured["energy-combinator-round-current-consumption"].value,
        current_production = configured["energy-combinator-round-current-production"].value,
        maximum_consumption = configured["energy-combinator-round-maximum-consumption"].value,
        maximum_production = configured["energy-combinator-round-maximum-production"].value,
    }
end


---@alias EntityUnitNumber integer

---@class SimpleSignal
    ---@field type SignalIDType
    ---@field name string
    ---@field count integer


--------------------------------------------------------------------------------

local function is_valid(entity)
    return entity and entity.valid
end


--------------------------------------------------------------------------------

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


--------------------------------------------------------------------------------

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
local function State(entity)
    local state = {entity=entity, tick=game.tick, prev_outputs={}}
    state.net = default_entity(entity, 'power-combinator-meter-network')
    state.sat = default_entity(entity, 'power-combinator-meter-satisfaction')
    if state.net and state.sat then connect_wires(state.sat, state.net) end
    if not (state.net and state.sat) then return nil end
    state.control = entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    circuit_slots.initialize(state.control, features.filter[state.entity.name])
    state.light = state.sat.get_or_create_control_behavior()
    state.light.circuit_condition = {condition={
        comparator = "=",
        first_signal = circuit_slots.factor_signal,
        constant = 1, -- 0 means on and 1 means off
    }}
    return state
end


---@param state ECombState
---@param tick integer
---@return nil
local function write(state, tick, modes)
    connect_wires(state.sat, state.net)
    local control = state.control
    local net_id = is_valid(state.net) and state.net.electric_network_id or nil
    local satisfaction_id = is_valid(state.sat) and state.sat.electric_network_id or nil
    local is_global = is_valid(state.net) and state.net.surface.has_global_electric_network
    local details = {
        network_id = net_id,
        satisfaction_id = satisfaction_id,
        connected = net_id ~= nil and satisfaction_id ~= nil and
            (net_id == satisfaction_id or is_global),
        is_mk2 = features.filter[state.entity.name] == true,
        method = is_global and "global" or "statistics",
        enabled = control.enabled,
        filter_count = 0,
    }
    state.diagnostics = details
    if not control.enabled then
        details.method = "disabled"
        return toggle_light(state, false)
    end
    local signal = circuit_slots.ensure_factor(control)
    alt_units.sync(state, signal.min)
    local filters = mk2_filters.read(state, features.filter[state.entity.name])
    details.filter_count = filters and #filters or 0
    local scale = 10 ^ -signal.min
    local variance = 60 / (tick - state.tick)
    local input, output, maxin, maxout, counts = electric_statistics.collect(state.net, state.sat, filters)
    filter_baseline.rebase_if_changed(state, filters, input, output)
    -- Keep existing cumulative inputs, building filters and capacity estimates authoritative.
    local input_diff = diff(input, state.input) * variance * scale
    local output_diff = diff(output, state.output) * variance * scale
    state.input, state.output, state.tick = input, output, tick
    -- MK1 measures the complete local network directly when the API permits.
    -- MK2 and global-network fallback keep the existing filtered statistics.
    if not features.filter[state.entity.name] then
        local watts = electric_direct.read_watts(state.net, state.sat)
        if watts then
            input_diff, output_diff = watts * scale, watts * scale
            details.method = "direct"
        end
    end
    -- A display-only snapshot of the measured physical power, before any chosen
    -- circuit rounding. The authoritative network measurement remains in this owner.
    state.last_watts = {
        current_consumption = scale ~= 0 and input_diff / scale or nil,
        current_production = scale ~= 0 and output_diff / scale or nil,
        maximum_consumption = maxin * 60,
        maximum_production = maxout * 60,
    }
    maxin = power_rounding.round_signal(maxin * 60 * scale, modes.maximum_consumption)
    maxout = power_rounding.round_signal(maxout * 60 * scale, modes.maximum_production)
    input_diff = power_rounding.round_signal(input_diff, modes.current_consumption)
    output_diff = power_rounding.round_signal(output_diff, modes.current_production)
    local enabled = is_int32(input_diff) and is_int32(output_diff) and is_int32(maxin) and is_int32(maxout)
    if not enabled then
        input_diff,output_diff,maxin,maxout = 0, 0, 0, 0 -- don't show anything
    end
    toggle_light(state, enabled)
    circuit_slots.write_power(control, signal.min, input_diff, output_diff, maxin, maxout)
    if features.filter[state.entity.name] then
        circuit_slots.write_filter_counts(state, counts)
    end
end

--------------------------------------------------------------------------------

---@param entity LuaEntity
local function alloc(entity)
    if entity and entity.unit_number and MK[entity.prototype.name] then
        local state = State(entity)
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
local function cleanup(entity)
    if type(entity) =="number" then
        ---@type table
        entity = {unit_number=entity}
    end
    if entity and entity.unit_number then
        local state = storage.state[entity.unit_number]
        if state then
            alt_units.remove(entity.unit_number)
            if is_valid(state.net) then state.net.destroy() end
            if is_valid(state.sat) then state.sat.destroy() end
            storage.state[entity.unit_number] = nil
            if state.registration then storage.registrations[state.registration] = nil end
            state.net = nil
            state.sat = nil
        end
    end
end

local function update(tick)
    local modes = rounding_modes()
    local invalid = {}
    for id, state in pairs(storage.state) do
        if not (is_valid(state.entity) and is_valid(state.net) and is_valid(state.sat)) then
            table.insert(invalid, id)
        elseif state.tick < tick then
            write(state, tick, modes)
        end
    end
    for _, id in ipairs(invalid) do cleanup(id) end
    energy_gui.refresh_open_players(storage.state)
end

local function init()
    alt_units.reset()
    for _, player in pairs(game.players) do energy_gui.close(player) end
    storage.state = {}
    storage.energy_gui_context = {}
    storage.registrations = {}
    for _, surface in pairs(game.surfaces) do
        for _, combinator in pairs(surface.find_entities_filtered{name={MK1,MK2}}) do
            alloc(combinator)
        end
    end
end

--------------------------------------------------------------------------------

local filters = {
    {filter = "name", name = MK1},
    {filter = "name", name = MK2},
}

local events = {
    entity = {
        added = {
            defines.events.on_built_entity,
            defines.events.script_raised_built,
            defines.events.script_raised_revive,
            defines.events.on_robot_built_entity,
        },
        removed = {
            defines.events.on_object_destroyed,
        },
    },
}

--------------------------------------------------------------------------------

script.on_init(init)
script.on_configuration_changed(init)

script.on_event(events.entity.added, function (event)
    alloc(event.entity)
end)
script.on_event(events.entity.removed, function (event)
    local unit_number = storage.registrations and storage.registrations[event.registration_number]
    if unit_number then cleanup(unit_number) end
end)

-- Hover over a combinator and press the configurable shortcut to open its vanilla GUI.
-- Normal clicks still use the original signal-driven behavior.
local function open_native_gui(player, entity)
    gui_open_requests[player.index] = {unit_number = entity.unit_number, tick = game.tick}
    player.opened = entity
end

script.on_event(GUI_SHORTCUT, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local entity = player.selected
    if not (is_valid(entity) and MK[entity.name]) then return end
    energy_gui.close(player)
    open_native_gui(player, entity)
end)

script.on_event(defines.events.on_gui_opened, function(event)
    local player = game.get_player(event.player_index)
    local entity = event.entity
    if not player or not is_valid(entity) or not MK[entity.name] then return end

    local request = gui_open_requests[event.player_index]
    gui_open_requests[event.player_index] = nil
    if request and request.unit_number == entity.unit_number and request.tick == event.tick then
        return -- opened intentionally with the shortcut
    end
    -- Suppress only the vanilla constant-combinator window for normal clicks.
    player.opened = nil
    energy_gui.open(player, storage.state[entity.unit_number])
end)

-- Only circuit_slots.lua writes scaling factor in the native circuit section.
local function apply_gui_factor(state, factor)
    if circuit_slots.apply_factor(state.control, factor) then
        alt_units.sync(state, factor)
    end
end

script.on_event(defines.events.on_gui_click, function(event)
    energy_gui.handle_click(event, storage.state, apply_gui_factor, open_native_gui)
end)
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    energy_gui.handle_selection(event, storage.state)
end)
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    energy_gui.handle_checked(event, storage.state)
end)
script.on_event(defines.events.on_gui_closed, energy_gui.on_closed)
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    if event.setting == "energy-combinator-show-alt-units" then
        alt_units.rebuild(storage.state, function(state)
            local slot = circuit_slots.get(state.control, 1)
            return slot and slot.min or 3
        end)
    end
    if event.setting and (event.setting:find("energy-combinator-round-", 1, true) == 1
          or event.setting == "energy-combinator-show-alt-units") then
        energy_gui.refresh_open_players(storage.state)
    end
end)

for _,event in ipairs(events.entity.added) do
    script.set_event_filter(event, filters)
end

local check_interval = settings.startup['power-combinator-update-tick'].value --[[@as integer]]
if check_interval > 0 then
    script.on_nth_tick(check_interval, function (event)
        update(event.tick)
    end)
end
