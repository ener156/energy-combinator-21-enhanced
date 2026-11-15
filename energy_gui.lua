-- Owns the dedicated Energy Combinator GUI. It only reads measurements:
-- the existing control.lua owns circuit state and provides the factor writer.
local units = require "power_units"
local mk2_modes = require "mk2_modes"
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
local MK2_MODES = {"auto", "all", "manual"}
local ALT_SETTING = "energy-combinator-show-alt-units"
-- The output column reads the existing constant-combinator slots; it is not a
-- second cache or signal writer. Physical measurements stay in state.last_watts.
local POWER_ROWS = {
    {key="current-consumption", watts="current_consumption", slot=2,
     signal="power-consumption", measured="ec_current_cons", output="ec_signal_cons"},
    {key="current-production", watts="current_production", slot=3,
     signal="power-production", measured="ec_current_prod", output="ec_signal_prod"},
    {key="maximum-consumption", watts="maximum_consumption", slot=4,
     signal="power-max-consumption", measured="ec_max_cons", output="ec_signal_max_cons"},
    {key="maximum-production", watts="maximum_production", slot=5,
     signal="power-max-production", measured="ec_max_prod", output="ec_signal_max_prod"},
}

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

local function gui_filter_signatures()
    storage.energy_gui_filter_signatures = storage.energy_gui_filter_signatures or {}
    return storage.energy_gui_filter_signatures
end

local function gui_overview_signatures()
    storage.energy_gui_overview_signatures = storage.energy_gui_overview_signatures or {}
    return storage.energy_gui_overview_signatures
end

local function mk2_mode_index(value)
    for i, mode in ipairs(MK2_MODES) do
        if mode == value then return i end
    end
    return 1
end

-- Use Factorio's quality prototypes, including qualities added by other mods.
-- "all" is the default for every existing building filter.
local function quality_options()
    local values, captions = {"all"}, {caption_key("quality-all")}
    local ordered = {}
    for name, prototype in pairs(prototypes.quality or {}) do
        ordered[#ordered + 1] = {name=name, prototype=prototype}
    end
    table.sort(ordered, function(a, b)
        local al, bl = a.prototype.level or 0, b.prototype.level or 0
        return al == bl and a.name < b.name or al < bl
    end)
    for _, item in ipairs(ordered) do
        values[#values + 1] = item.name
        captions[#captions + 1] = item.prototype.localised_name or item.name
    end
    -- Compatibility with unmodified/minimal prototype tables in tests.
    if #values == 1 then
        values[2], captions[2] = "normal", caption_key("quality-normal")
    end
    return values, captions
end

local function quality_index(quality, options)
    for i, name in ipairs(options) do
        if name == (quality or "all") then return i end
    end
    return 1
end

local function quality_caption(quality)
    if not quality then return caption_key("quality-all") end
    local proto = prototypes.quality and prototypes.quality[quality]
    return proto and proto.localised_name or
        (quality == "normal" and caption_key("quality-normal") or quality)
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

-- Native tabs remain in use for selection, but their content widgets are
-- deliberately empty. Real pages are siblings of the tabbed pane so the
-- non-selected (possibly tall) manual-filter editor never enlarges Diagnosis.
-- Unlike a fixed height, this respects player-specific GUI scaling and locale.
local function resize_active_tab(player, frame, state)
    local tabs = find(frame, "ec_tabs")
    if not tabs or not tabs.valid then return end
    local index = tabs.selected_tab_index or 1
    local changed = false
    for i, name in ipairs({"ec_overview", "ec_settings", "ec_diagnostics"}) do
        local page = frame[name]
        if page and page.valid and page.visible ~= (index == i) then
            page.visible = index == i
            changed = true
        end
    end
    if changed then frame.force_auto_center() end
end

local function row(table_gui, entry)
    table_gui.add{
        type="label",
        caption={"", "[virtual-signal=" .. entry.signal .. "] ", caption_key(entry.key)},
    }
    table_gui.add{type="label", name=entry.measured, caption="—"}
    table_gui.add{type="label", name=entry.output, caption="—"}
end

local function circuit_value(state, index)
    if not state.control or not state.control.valid then return "—" end
    if state.control.sections_count == 0 then return "—" end
    local filter = state.control.sections[1].get_slot(index)
    if not filter or not filter.value then return "—" end
    return tostring(filter.min or 0)
end

function M.close(player)
    if not player or not player.valid then return end
    local frame = player.gui.screen[ROOT]
    if frame and frame.valid then frame.destroy() end
    gui_context()[player.index] = nil
    gui_filter_signatures()[player.index] = nil
    gui_overview_signatures()[player.index] = nil
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
    frame.style.minimal_width = 880
    frame.style.maximal_width = 940
    local header = frame.add{type="flow", direction="horizontal"}
    header.add{type="label", caption=entity.name:find("MK2", 1, true) and caption_key("mk2") or caption_key("mk1")}
    header.add{type="empty-widget", style="draggable_space"}.style.horizontally_stretchable = true
    header.add{type="sprite-button", name="ec_close", sprite="utility/close", style="frame_action_button"}

    local tabs = frame.add{type="tabbed-pane", name="ec_tabs"}
    -- The native tab selector has only empty content pages; explicitly stretch
    -- its lower border across the same width as the real pages below.
    tabs.style.horizontally_stretchable = true
    tabs.style.minimal_width = 850
    local overview_tab = tabs.add{type="tab", caption=caption_key("overview")}
    tabs.add_tab(overview_tab, tabs.add{type="empty-widget"})
    local overview = frame.add{type="flow", name="ec_overview", direction="vertical"}
    local resolution = overview.add{type="flow", direction="horizontal"}
    resolution.add{type="label", caption=caption_key("factor")}
    resolution.add{type="label", name="ec_unit", caption="—", style="heading_2_label"}
    local intro = overview.add{type="label", caption=caption_key("overview-explanation")}
    intro.style.single_line = false
    intro.style.maximal_width = 820
    -- Native-style shallow panel with a measured-input and circuit-output column.
    local panel = overview.add{type="frame", direction="vertical", style="inside_shallow_frame_with_padding"}
    local grid = panel.add{type="table", name="ec_power_grid", column_count=3}
    grid.style.horizontal_spacing = 24
    grid.style.vertical_spacing = 7
    grid.add{type="label", caption=caption_key("power-signal")}
    grid.add{type="label", caption=caption_key("power-measured")}
    grid.add{type="label", caption=caption_key("power-output")}
    for _, entry in ipairs(POWER_ROWS) do
        row(grid, entry)
    end
    if entity.name:find("MK2", 1, true) then
        local filter_panel = overview.add{
            type="frame", direction="vertical",
            style="inside_shallow_frame_with_padding",
        }
        filter_panel.add{type="label", caption=caption_key("overview-filters-title"),
                         style="heading_2_label"}
        filter_panel.add{type="label", name="ec_overview_filter_source", caption="—"}
        filter_panel.add{type="label", name="ec_overview_filter_scope", caption="—"}
        -- The header belongs ABOVE the scrollable list, never below it.
        local headings = filter_panel.add{type="flow", name="ec_filter_headings", direction="horizontal"}
        headings.add{type="label", caption=caption_key("overview-filter-building"),
            style="bold_label"}.style.minimal_width = 590
        headings.add{type="label", caption=caption_key("overview-filter-number"),
            style="bold_label"}
        local scroller = filter_panel.add{
            type="scroll-pane", name="ec_overview_filter_scroller",
            direction="vertical",
        }
        scroller.style.maximal_height = 180
        scroller.style.minimal_width = 680
        scroller.add{type="flow", name="ec_overview_filter_list", direction="vertical"}
    end
    overview.add{type="label", caption=caption_key("rounding-hint")}

    local settings_tab = tabs.add{type="tab", caption=caption_key("settings")}
    tabs.add_tab(settings_tab, tabs.add{type="empty-widget"})
    local setting_flow = frame.add{type="flow", name="ec_settings", direction="vertical"}
    setting_flow.visible = false
    local columns = setting_flow.add{type="flow", name="ec_settings_columns", direction="horizontal"}
    columns.style.horizontal_spacing = 14
    local general = columns.add{type="frame", name="ec_general_panel", direction="vertical",
        style="inside_shallow_frame_with_padding"}
    general.style.minimal_width = 390
    general.add{type="label", caption=caption_key("settings-general-title"),
        style="heading_2_label"}
    local factor_help = general.add{type="label", caption=caption_key("factor-help")}
    factor_help.style.single_line = false
    factor_help.style.maximal_width = 360
    local change = general.add{type="flow", direction="horizontal"}
    local factor_field = change.add{type="textfield", name="ec_factor_input",
        text=tostring(get_factor(state)), numeric=true, allow_negative=true}
    factor_field.style.width = 95
    change.add{type="button", name="ec_apply_factor", caption=caption_key("apply-factor"),
        style="confirm_button"}
    local rounding_help = general.add{type="label", caption=caption_key("rounding-mapwide")}
    rounding_help.style.single_line = false
    rounding_help.style.maximal_width = 360
    local rounding_table = general.add{type="table", column_count=2}
    rounding_table.style.horizontal_spacing = 8
    rounding_table.style.vertical_spacing = 7
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
        dropdown.style.minimal_width = 150
    end
    general.add{
        type="checkbox", name="ec_alt_checkbox", caption=caption_key("alt-checkbox"),
        state=settings.global[ALT_SETTING].value,
    }
    if entity.name:find("MK2", 1, true) then
        local configuration = mk2_modes.get(entity.unit_number)
        local filters = columns.add{type="frame", name="ec_filter_settings_panel", direction="vertical",
            style="inside_shallow_frame_with_padding"}
        filters.style.minimal_width = 420
        filters.add{type="label", caption=caption_key("mk2-mode-title"),
            style="heading_2_label"}
        local selector = filters.add{type="drop-down", name="ec_mk2_mode",
            items={caption_key("mode-auto"), caption_key("mode-all"), caption_key("mode-manual")},
            selected_index=mk2_mode_index(configuration.mode)}
        selector.style.minimal_width = 285
        local mode_help = filters.add{type="label", caption=caption_key("mk2-mode-help")}
        mode_help.style.single_line = false
        mode_help.style.maximal_width = 400
        -- Preserve manual filters while Auto / Full Grid is selected, but
        -- show only a concise inactive summary outside manual filter mode.
        filters.add{type="label", name="ec_mk2_manual_inactive", caption=""}
        local manual = filters.add{type="flow", name="ec_mk2_manual", direction="vertical"}
        manual.add{type="label", caption=caption_key("mk2-manual-title")}
        local quality_hint = manual.add{type="label", caption=caption_key("mk2-quality-help")}
        quality_hint.style.single_line = false
        quality_hint.style.maximal_width = 400
        local add = manual.add{type="flow", direction="horizontal"}
        add.add{type="choose-elem-button", name="ec_mk2_add_entity", elem_type="entity"}
        local pick_help = add.add{type="label", caption=caption_key("mk2-manual-add-help")}
        pick_help.style.single_line = false
        pick_help.style.maximal_width = 335
        -- Up to 32 filters can be selected. Keep the settings tab and its
        -- footer usable instead of growing the entire GUI off-screen.
        local manual_scroll = manual.add{
            type="scroll-pane", name="ec_mk2_filter_scroller",
            direction="vertical",
        }
        manual_scroll.style.maximal_height = 240
        manual_scroll.style.minimal_width = 400
        manual_scroll.add{type="flow", name="ec_mk2_filter_list", direction="vertical"}
    end

    local diag_tab = tabs.add{type="tab", caption=caption_key("diagnostics")}
    tabs.add_tab(diag_tab, tabs.add{type="empty-widget"})
    local diag = frame.add{type="flow", name="ec_diagnostics", direction="vertical"}
    diag.visible = false
    tabs.selected_tab_index = 1
    local diag_columns = diag.add{type="flow", name="ec_diagnostics_columns",
        direction="horizontal"}
    diag_columns.style.horizontal_spacing = 14
    local network = diag_columns.add{type="frame", name="ec_diagnostics_network",
        direction="vertical", style="inside_shallow_frame_with_padding"}
    network.style.minimal_width = 390
    network.add{type="label", caption=caption_key("diagnostics-network-title"),
        style="heading_2_label"}
    network.add{type="label", name="ec_net_status", caption="—"}
    network.add{type="label", name="ec_net_id", caption="—"}
    network.add{type="label", name="ec_sat_id", caption="—"}
    network.add{type="label", name="ec_combinator_status", caption="—"}
    local measurement = diag_columns.add{type="frame", name="ec_diagnostics_measurement",
        direction="vertical", style="inside_shallow_frame_with_padding"}
    measurement.style.minimal_width = 420
    measurement.add{type="label", caption=caption_key("diagnostics-measurement-title"),
        style="heading_2_label"}
    measurement.add{type="label", name="ec_measurement_mode", caption="—"}
    measurement.add{type="label", name="ec_filter_status", caption="—"}
    local mode_status = measurement.add{type="label", name="ec_filter_mode_status",
        caption="—"}
    mode_status.style.single_line = false
    mode_status.style.maximal_width = 395

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

local function update_manual_list(player, frame, config)
    local list = find(frame, "ec_mk2_filter_list")
    if not list then return end
    local signature_parts = {}
    for _, name in ipairs(config.filters) do
        signature_parts[#signature_parts + 1] =
            name .. "@" .. ((config.qualities and config.qualities[name]) or "all")
    end
    local signature = table.concat(signature_parts, "\n")
    if gui_filter_signatures()[player.index] ~= signature then
        list.clear()
        local quality_ids, quality_labels = quality_options()
        for i, name in ipairs(config.filters) do
            local line = list.add{type="flow", direction="horizontal"}
            local prototype = prototypes.entity[name]
            local caption = prototype and prototype.localised_name or name
            local label = line.add{type="label",
                caption={"", "[entity=" .. name .. "] ", caption}}
            label.style.minimal_width = 192
            label.style.maximal_width = 215
            local selected = (config.qualities and config.qualities[name]) or "all"
            local quality = line.add{type="drop-down", name="ec_mk2_quality_" .. i,
                items=quality_labels, selected_index=quality_index(selected, quality_ids)}
            quality.style.minimal_width = 135
            line.add{type="button", name="ec_mk2_remove_" .. i,
                caption=caption_key("mk2-manual-remove")}
        end
        if #config.filters == 0 then
            list.add{type="label", caption=caption_key("mk2-manual-empty")}
        end
        gui_filter_signatures()[player.index] = signature
    end
    local add = find(frame, "ec_mk2_add_entity")
    if add then add.enabled = config.mode == "manual" and #config.filters < mk2_modes.max_filters end
    for i=1,#config.filters do
        local button = find(list, "ec_mk2_remove_" .. i)
        if button then button.enabled = config.mode == "manual" end
    end
end

-- Rebuild only when the effective filter names change. Measured quantities
-- update on every refresh without rebuilding widgets on every Factorio tick.
local function update_filter_overview(player, frame, state, config, details)
    local list = find(frame, "ec_overview_filter_list")
    if not list then return end
    local current = details.filter_mode == config.mode
    local names
    if config.mode == "manual" then
        names = mk2_modes.valid_manual_filters(state.entity.unit_number)
    elseif config.mode == "auto" and current then
        names = details.filter_names or {}
    else
        names = {}
    end
    value(frame, "ec_overview_filter_source",
        {"energy-combinator-gui.overview-filter-source",
         caption_key("mode-" .. config.mode)})
    local measuring = details.connected == true and details.enabled ~= false
    local active = #names > 0 and config.mode ~= "all"
    local scope = not measuring and caption_key("overview-filter-not-measuring")
        or active and caption_key("mk2-effective-filtered")
        or caption_key("mk2-effective-all")
    value(frame, "ec_overview_filter_scope",
        {"energy-combinator-gui.overview-filter-scope", scope})

    local signature_parts = {}
    for _, name in ipairs(names) do
        local quality = config.mode == "manual" and
            config.qualities and config.qualities[name] or nil
        signature_parts[#signature_parts + 1] = name .. "@" .. (quality or "all")
    end
    local signature = config.mode .. ":" .. table.concat(signature_parts, "\n")
    if gui_overview_signatures()[player.index] ~= signature then
        list.clear()
        for i, name in ipairs(names) do
            local line = list.add{type="flow", direction="horizontal"}
            local prototype = prototypes.entity[name]
            local quality = config.mode == "manual" and
                config.qualities and config.qualities[name] or nil
            local name_label = line.add{type="label", caption={
                "", "[entity=" .. name .. "] ",
                prototype and prototype.localised_name or name,
                " (", quality_caption(quality), ")",
            }}
            name_label.style.minimal_width = 585
            line.add{type="label", name="ec_overview_filter_count_" .. i, caption="—"}
        end
        if #names == 0 then
            local reason = not measuring and "overview-filter-no-data"
                or config.mode == "auto" and "overview-filter-auto-empty"
                or config.mode == "manual" and "overview-filter-manual-empty"
                or "overview-filter-all"
            list.add{type="label", caption=caption_key(reason)}
        end
        gui_overview_signatures()[player.index] = signature
    end
    local measured = current and measuring
    local counts = measured and details.filter_counts or nil
    for i, name in ipairs(names) do
        value(list, "ec_overview_filter_count_" .. i,
            counts and tostring(counts[name] or 0)
                   or "—")
    end
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
    for _, entry in ipairs(POWER_ROWS) do
        value(frame, entry.measured, units.watts_at_factor(watts[entry.watts], factor))
        value(frame, entry.output, circuit_value(state, entry.slot))
    end
    local details = state.diagnostics or {}
    local connected = details.connected == true
    value(frame, "ec_net_status", connected and caption_key("network-connected") or caption_key("network-unavailable"))
    value(frame, "ec_net_id", {"energy-combinator-gui.network-id", tostring(details.network_id or "—")})
    value(frame, "ec_sat_id", {"energy-combinator-gui.satisfaction-id", tostring(details.satisfaction_id or "—")})
    local method = details.method or "unknown"
    value(frame, "ec_measurement_mode", {"energy-combinator-gui.measurement-mode", caption_key("method-" .. method)})
    if state.entity.name:find("MK2", 1, true) then
        local config = mk2_modes.get(state.entity.unit_number)
        local selector = find(frame, "ec_mk2_mode")
        if selector and selector.selected_index ~= mk2_mode_index(config.mode) then
            selector.selected_index = mk2_mode_index(config.mode)
        end
        local manual = find(frame, "ec_mk2_manual")
        if manual then manual.visible = config.mode == "manual" end
        local inactive = find(frame, "ec_mk2_manual_inactive")
        if inactive then
            inactive.visible = config.mode ~= "manual"
            if config.mode ~= "manual" then
                inactive.caption = {"energy-combinator-gui.mk2-manual-inactive",
                    tostring(#config.filters)}
            end
        end
        update_manual_list(player, frame, config)
        update_filter_overview(player, frame, state, config, details)
        value(frame, "ec_filter_status", {"energy-combinator-gui.filter-count", details.filter_count or 0})
        local effective = details.filter_active and caption_key("mk2-effective-filtered")
            or caption_key("mk2-effective-all")
        value(frame, "ec_filter_mode_status", {"energy-combinator-gui.mk2-effective",
            caption_key("mode-" .. config.mode), effective})
    else
        value(frame, "ec_filter_status", caption_key("filter-mk1"))
        value(frame, "ec_filter_mode_status", "")
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
    resize_active_tab(player, frame, state)
end

function M.handle_tab_changed(event, states)
    local player = game.get_player(event.player_index)
    local frame = player and player.gui.screen[ROOT]
    if not frame or not frame.valid or find(frame, "ec_tabs") ~= event.element then return end
    local unit = gui_context()[player.index]
    local state = unit and states[unit]
    if state and state.entity and state.entity.valid then
        resize_active_tab(player, frame, state)
    end
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
    local remove_index = tonumber(name:match("^ec_mk2_remove_(%d+)$"))
    if name ~= "ec_close" and name ~= "ec_close_bottom"
       and name ~= "ec_open_native" and name ~= "ec_apply_factor"
       and not remove_index then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local unit_number = gui_context()[player.index]
    if not unit_number then return end
    local state = states[unit_number]
    if remove_index then
        if state and state.entity and state.entity.valid then
            local config = mk2_modes.get(state.entity.unit_number)
            if config.mode == 'manual' and config.filters[remove_index] then
                mk2_modes.remove_filter(state.entity.unit_number, config.filters[remove_index])
                gui_filter_signatures()[player.index] = nil
                M.refresh(player, state)
            end
        end
    elseif name == "ec_close" or name == "ec_close_bottom" then
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
    local quality_row = tonumber(element.name:match("^ec_mk2_quality_(%d+)$"))
    if quality_row and find(frame, element.name) == element then
        local state = states[id]
        if not state.entity or not state.entity.valid then return end
        local config = mk2_modes.get(id)
        local name = config.mode == "manual" and config.filters[quality_row]
        local choices = quality_options()
        local quality = choices[element.selected_index]
        if name and quality and mk2_modes.set_filter_quality(id, name, quality) then
            gui_filter_signatures()[player.index] = nil
            M.refresh(player, state)
        end
        return
    end
    if element.name == 'ec_mk2_mode' and find(frame, 'ec_mk2_mode') == element then
        local state = states[id]
        if state.entity and state.entity.valid then
            local mode = MK2_MODES[element.selected_index]
            if mode and mk2_modes.set_mode(state.entity.unit_number, mode) then
                M.refresh(player, state)
            end
        end
        return
    end
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

-- Factorio entity picker: select an electrical building to add a manual filter.
function M.handle_elem_changed(event, states)
    local element = event.element
    if not element or not element.valid or element.name ~= 'ec_mk2_add_entity' then return end
    local player = game.get_player(event.player_index)
    local frame = player and player.gui.screen[ROOT]
    local id = player and gui_context()[player.index]
    local state = id and states[id]
    if not frame or not frame.valid or not state or
       find(frame, 'ec_mk2_add_entity') ~= element then return end
    local config = mk2_modes.get(id)
    if config.mode == 'manual' and element.elem_value then
        if not mk2_modes.add_filter(id, element.elem_value) then
            player.print(caption_key('mk2-manual-invalid'))
        end
    end
    element.elem_value = nil
    gui_filter_signatures()[player.index] = nil
    M.refresh(player, state)
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
