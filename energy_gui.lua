-- Owns the dedicated Energy Combinator GUI. It only reads measurements:
-- the existing control.lua owns circuit state and provides the factor writer.
local units = require "power_units"
local M = {}
local ROOT = "ec_enhanced_gui"
-- Map settings stay authoritative; dropdowns are just editors for those settings.
local ROUNDING = {
    {key="energy-combinator-round-current-consumption", gui="ec_round_current_cons"},
    {key="energy-combinator-round-current-production", gui="ec_round_current_prod"},
    {key="energy-combinator-round-maximum-consumption", gui="ec_round_max_cons"},
    {key="energy-combinator-round-maximum-production", gui="ec_round_max_prod"},
}
local MODES = {"nearest", "up", "down"}
local ALT_SETTING = "energy-combinator-show-alt-units"

local function mode_index(value)
    for index, mode in ipairs(MODES) do
        if mode == value then return index end
    end
    return 1
end


local function gui_context()
    storage.energy_gui_context = storage.energy_gui_context or {}
    return storage.energy_gui_context
end

local function get_factor(state)
    if not state or not state.control or not state.control.valid then return 3 end
    if state.control.sections_count == 0 then return 3 end
    local filter = state.control.sections[1].get_slot(1)
    return filter and filter.min or 3
end

local function find(element, wanted)
    if element.name == wanted then return element end
    for _, child in pairs(element.children) do
        local found = find(child, wanted)
        if found then return found end
    end
    return nil
end

local function caption_key(key)
    return {"energy-combinator-gui." .. key}
end

local function row(table_gui, name, value_name)
    table_gui.add{type="label", caption=caption_key(name)}
    table_gui.add{type="label", name=value_name, caption="—"}
end

function M.close(player)
    if not player or not player.valid then return end
    local frame = player.gui.screen[ROOT]
    if frame and frame.valid then frame.destroy() end
    gui_context()[player.index] = nil
end

function M.open(player, state)
    if not player or not player.valid or not state or not state.entity.valid then return end
    M.close(player)
    local entity = state.entity
    local frame = player.gui.screen.add{
        type="frame", name=ROOT, direction="vertical",
        caption=caption_key("title"),
    }
    frame.auto_center = true
    frame.style.minimal_width = 510
    local header = frame.add{type="flow", direction="horizontal"}
    header.add{type="label", caption=entity.name:find("MK2", 1, true) and caption_key("mk2") or caption_key("mk1")}
    header.add{type="empty-widget", style="draggable_space"}.style.horizontally_stretchable = true
    header.add{type="sprite-button", name="ec_close", sprite="utility/close", style="frame_action_button"}

    local tabs = frame.add{type="tabbed-pane", name="ec_tabs"}
    local overview_tab = tabs.add{type="tab", caption=caption_key("overview")}
    local overview = tabs.add{type="flow", name="ec_overview", direction="vertical"}
    tabs.add_tab(overview_tab, overview)
    overview.add{type="label", caption=caption_key("factor")}
    overview.add{type="label", name="ec_unit", caption="—", style="heading_2_label"}
    local grid = overview.add{type="table", column_count=2}
    grid.style.horizontal_spacing = 16
    grid.style.vertical_spacing = 8
    row(grid, "current-consumption", "ec_current_cons")
    row(grid, "current-production", "ec_current_prod")
    row(grid, "maximum-consumption", "ec_max_cons")
    row(grid, "maximum-production", "ec_max_prod")

    local settings_tab = tabs.add{type="tab", caption=caption_key("settings")}
    local setting_flow = tabs.add{type="flow", name="ec_settings", direction="vertical"}
    tabs.add_tab(settings_tab, setting_flow)
    setting_flow.add{type="label", caption=caption_key("factor-help")}
    local change = setting_flow.add{type="flow", direction="horizontal"}
    change.add{type="textfield", name="ec_factor_input", text=tostring(get_factor(state)),
               numeric=true, allow_negative=true}
    change.add{type="button", name="ec_apply_factor", caption=caption_key("apply-factor"), style="confirm_button"}
    setting_flow.add{type="label", caption=caption_key("rounding-mapwide")}
    local rounding_table = setting_flow.add{type="table", column_count=2}
    rounding_table.style.horizontal_spacing = 14
    rounding_table.style.vertical_spacing = 8
    for _, item in ipairs(ROUNDING) do
        rounding_table.add{type="label", caption={"mod-setting-name." .. item.key}}
        local choices = {}
        for _, mode in ipairs(MODES) do
            choices[#choices + 1] = {"string-mod-setting." .. item.key .. "-" .. mode}
        end
        local dropdown = rounding_table.add{
            type="drop-down", name=item.gui, items=choices,
            selected_index=mode_index(settings.global[item.key].value),
        }
        dropdown.style.minimal_width = 190
    end
    setting_flow.add{
        type="checkbox", name="ec_alt_checkbox", caption=caption_key("alt-checkbox"),
        state=settings.global[ALT_SETTING].value,
    }

    local diag_tab = tabs.add{type="tab", caption=caption_key("diagnostics")}
    local diag = tabs.add{type="flow", name="ec_diagnostics", direction="vertical"}
    tabs.add_tab(diag_tab, diag)
    diag.add{type="label", name="ec_net_status", caption="—"}
    diag.add{type="label", name="ec_net_id", caption="—"}
    diag.add{type="label", name="ec_sat_id", caption="—"}
    diag.add{type="label", name="ec_measurement_mode", caption="—"}
    diag.add{type="label", name="ec_filter_status", caption="—"}
    diag.add{type="label", name="ec_combinator_status", caption="—"}

    local footer = frame.add{type="flow", direction="horizontal"}
    footer.add{type="button", name="ec_open_native", caption=caption_key("native")}
    footer.add{type="button", name="ec_close_bottom", caption=caption_key("close")}
    gui_context()[player.index] = entity.unit_number
    M.refresh(player, state)
    player.opened = frame
end

local function value(frame, name, text)
    local label = find(frame, name)
    if label then label.caption = text end
end

function M.refresh(player, state)
    if not player or not player.valid then return end
    local frame = player.gui.screen[ROOT]
    if not frame or not frame.valid then return end
    if not state or not state.entity or not state.entity.valid
       or gui_context()[player.index] ~= state.entity.unit_number then
        M.close(player)
        return
    end
    local factor = get_factor(state)
    value(frame, "ec_unit", "X=" .. tostring(factor) .. "  ·  " .. units.factor_label(factor))
    local watts = state.last_watts or {}
    value(frame, "ec_current_cons", units.watts_text(watts.current_consumption))
    value(frame, "ec_current_prod", units.watts_text(watts.current_production))
    value(frame, "ec_max_cons", units.watts_text(watts.maximum_consumption))
    value(frame, "ec_max_prod", units.watts_text(watts.maximum_production))
    local details = state.diagnostics or {}
    local connected = details.connected == true
    value(frame, "ec_net_status", connected and caption_key("network-connected") or caption_key("network-unavailable"))
    value(frame, "ec_net_id", {"energy-combinator-gui.network-id", tostring(details.network_id or "—")})
    value(frame, "ec_sat_id", {"energy-combinator-gui.satisfaction-id", tostring(details.satisfaction_id or "—")})
    local method = details.method or "unknown"
    value(frame, "ec_measurement_mode", {"energy-combinator-gui.measurement-mode", caption_key("method-" .. method)})
    if details.is_mk2 then
        value(frame, "ec_filter_status", {"energy-combinator-gui.filter-count", details.filter_count or 0})
    else
        value(frame, "ec_filter_status", caption_key("filter-mk1"))
    end
    value(frame, "ec_combinator_status", details.enabled == false and caption_key("combinator-disabled") or caption_key("combinator-enabled"))
    for _, item in ipairs(ROUNDING) do
        local dropdown = find(frame, item.gui)
        if dropdown then
            local selected = mode_index(settings.global[item.key].value)
            if dropdown.selected_index ~= selected then dropdown.selected_index = selected end
        end
    end
    local checkbox = find(frame, "ec_alt_checkbox")
    if checkbox then checkbox.state = settings.global[ALT_SETTING].value end
end

function M.refresh_open_players(states)
    for index, unit_number in pairs(gui_context()) do
        local player = game.get_player(index)
        if player and player.valid then M.refresh(player, states[unit_number]) end
    end
end

function M.handle_click(event, states, apply_factor, open_native)
    local element = event.element
    if not element or not element.valid then return end
    local name = element.name
    if name ~= "ec_close" and name ~= "ec_close_bottom"
       and name ~= "ec_open_native" and name ~= "ec_apply_factor" then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local unit_number = gui_context()[player.index]
    if not unit_number then return end
    local state = states[unit_number]
    if name == "ec_close" or name == "ec_close_bottom" then
        M.close(player)
    elseif name == "ec_open_native" then
        if state and state.entity and state.entity.valid then
            M.close(player)
            open_native(player, state.entity)
        end
    elseif name == "ec_apply_factor" then
        local frame = player.gui.screen[ROOT]
        local field = frame and find(frame, "ec_factor_input")
        local factor = field and tonumber(field.text)
        if factor and factor == math.floor(factor) and factor >= -32 and factor <= 32 then
            if state and state.entity and state.entity.valid then
                apply_factor(state, factor)
                M.refresh(player, state)
            end
        else
            player.print(caption_key("factor-invalid"))
        end
    end
end

-- Factorio permits mods to update their own runtime-global settings.
-- All combinators use the same values on the next measurement tick.
function M.handle_selection(event, states)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    local frame = player and player.gui.screen[ROOT]
    local id = player and gui_context()[player.index]
    if not frame or not frame.valid or not states[id] then return end
    for _, item in ipairs(ROUNDING) do
        if element.name == item.gui and find(frame, item.gui) == element then
            if game.is_multiplayer() and not player.admin then
                player.print(caption_key("requires-admin"))
                M.refresh(player, states[id])
                return
            end
            local mode = MODES[element.selected_index]
            if mode and settings.global[item.key].value ~= mode then
                settings.global[item.key] = {value=mode}
            end
            return
        end
    end
end

function M.handle_checked(event, states)
    local element = event.element
    if not element or not element.valid or element.name ~= "ec_alt_checkbox" then return end
    local player = game.get_player(event.player_index)
    local frame = player and player.gui.screen[ROOT]
    local id = player and gui_context()[player.index]
    if not frame or not frame.valid or not states[id] then return end
    if find(frame, "ec_alt_checkbox") ~= element then return end
    if game.is_multiplayer() and not player.admin then
        player.print(caption_key("requires-admin"))
        M.refresh(player, states[id])
        return
    end
    if settings.global[ALT_SETTING].value ~= element.state then
        settings.global[ALT_SETTING] = {value=element.state}
    end
end

function M.on_closed(event)
    if not event.element or not event.element.valid then return end
    if event.element.name ~= ROOT then return end
    local player = game.get_player(event.player_index)
    if player then M.close(player) end
end

return M
