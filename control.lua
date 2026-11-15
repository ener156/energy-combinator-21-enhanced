local common = require "common"
local alt_units = require "alt_units"
local energy_gui = require "energy_gui"
local circuit_slots = require "circuit_slots"
local power_meter = require "power_meter"
local combinator_state = require "combinator_state"
local mk2_modes = require "mk2_modes"

local MK1 = common.prototype_prefix .. "power-combinator"
local MK2 = common.prototype_prefix .. "power-combinator-MK2"
local MK = {[MK1]=true,[MK2]=true}
local features = {filter = {[MK2]=true}}
local GUI_SHORTCUT = "energy-combinator-open-settings"
local gui_open_requests = {} -- one-tick permission for deliberate GUI opening

--------------------------------------------------------------------------------



---@alias EntityUnitNumber integer

---@class SimpleSignal
    ---@field type SignalIDType
    ---@field name string
    ---@field count integer


--------------------------------------------------------------------------------

local function is_valid(entity)
    return entity and entity.valid
end



local function update(tick)
    local modes = power_meter.rounding_modes()
    local invalid = {}
    for id, state in pairs(storage.state) do
        if not (is_valid(state.entity) and is_valid(state.net) and is_valid(state.sat)) then
            table.insert(invalid, id)
        elseif state.tick < tick then
            power_meter.write(state, tick, modes, features.filter[state.entity.name])
        end
    end
    for _, id in ipairs(invalid) do combinator_state.cleanup(id) end
    energy_gui.refresh_open_players(storage.state)
end
local function init()
    alt_units.reset()
    for _, player in pairs(game.players) do energy_gui.close(player) end
    storage.energy_gui_context = {}
    storage.energy_gui_filter_signatures = {}
    combinator_state.rebuild({MK1,MK2}, MK, features.filter)
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
    local entity = event.entity
    combinator_state.allocate(entity, MK, features.filter)
    -- Factorio forwards per-blueprint entity tags on actual placement and
    -- robot revival; the settings must be restored for the NEW unit number.
    if entity and entity.valid and entity.name == MK2 and event.tags then
        mk2_modes.import(entity.unit_number, event.tags.ecmod9_mk2)
    end
end)
script.on_event(events.entity.removed, function (event)
    combinator_state.cleanup_registration(event.registration_number)
end)

script.on_event(defines.events.on_entity_cloned, function(event)
    local source, destination = event.source, event.destination
    if not (source and source.valid and destination and destination.valid
            and source.name == MK2 and destination.name == MK2) then return end
    mk2_modes.clone(source.unit_number, destination.unit_number)
end)

-- Shift+right/left entity settings copy must also copy the MK2's
-- per-unit persisted manual filters, not just vanilla constant slots.
script.on_event(defines.events.on_entity_settings_pasted, function(event)
    local source, destination = event.source, event.destination
    if source and destination and source.valid and destination.valid and
        source.name == MK2 and destination.name == MK2 then
        mk2_modes.clone(source.unit_number, destination.unit_number)
    end
end)

-- Portable blueprint payload: names and mode are stored on the blueprint
-- entity itself; storage unit numbers must never be serialized into a stamp.
local pending_blueprints = {}

local function write_blueprint_tags(blueprint, mapping)
    if not blueprint or not mapping then return false end
    if not blueprint.is_blueprint_setup() then return false end
    for index, entity in pairs(mapping) do
        if entity and entity.valid and entity.name == MK2 then
            blueprint.set_blueprint_entity_tag(index, "ecmod9_mk2",
                mk2_modes.export(entity.unit_number))
        end
    end
    return true
end

script.on_event(defines.events.on_player_setup_blueprint, function(event)
    if not event.mapping or not event.mapping.valid then return end
    local mapping = event.mapping.get()
    local player = game.get_player(event.player_index)
    local blueprint = event.stack or event.record or
        (player and (player.blueprint_to_setup or player.cursor_stack))
    if write_blueprint_tags(blueprint, mapping) then
        pending_blueprints[event.player_index] = nil
    else
        -- The interactive blueprint confirmation window may be unfinished
        -- while the selection event fires. Finish at confirm time instead.
        pending_blueprints[event.player_index] = mapping
    end
end)

script.on_event(defines.events.on_player_configured_blueprint, function(event)
    local mapping = pending_blueprints[event.player_index]
    pending_blueprints[event.player_index] = nil
    if not mapping then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local blueprint = player.blueprint_to_setup or player.cursor_stack
    write_blueprint_tags(blueprint, mapping)
end)

-- Factorio 2.1 raises this for stamping a blueprint over existing entities.
script.on_event(defines.events.on_blueprint_settings_pasted, function(event)
    local entity = event.entity
    if entity and entity.valid and entity.name == MK2 and event.tags then
        mk2_modes.import(entity.unit_number, event.tags.ecmod9_mk2)
    end
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
script.on_event(defines.events.on_gui_elem_changed, function(event)
    energy_gui.handle_elem_changed(event, storage.state)
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
