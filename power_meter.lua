-- Owns current power measurement, cumulative statistics baselines, rounding,
-- unrounded GUI snapshots and diagnostics. Dispatches physical circuit writes
-- exclusively through circuit_slots.lua; no direct native section writes here.
local power_rounding = require "power_rounding"
local alt_units = require "alt_units"
local electric_statistics = require "electric_statistics"
local electric_direct = require "electric_direct"
local filter_baseline = require "filter_baseline"
local circuit_slots = require "circuit_slots"
local meter_sensors = require "meter_sensors"
local mk2_filters = require "mk2_filters"
local mk2_modes = require "mk2_modes"

local M = {}
local INT32_MAX = 2^31

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

local function is_valid(entity)
    return entity and entity.valid
end

---@param state ECombState
---@param tick integer
---@return nil
function M.write(state, tick, modes, is_mk2)
    meter_sensors.connect(state.sat, state.net)
    local control = state.control
    local net_id = is_valid(state.net) and state.net.electric_network_id or nil
    local satisfaction_id = is_valid(state.sat) and state.sat.electric_network_id or nil
    local is_global = is_valid(state.net) and state.net.surface.has_global_electric_network
    local details = {
        network_id = net_id,
        satisfaction_id = satisfaction_id,
        connected = net_id ~= nil and satisfaction_id ~= nil and
            (net_id == satisfaction_id or is_global),
        is_mk2 = is_mk2 == true,
        method = is_global and "global" or "statistics",
        enabled = control.enabled,
        filter_count = 0,
    }
    state.diagnostics = details
    if not control.enabled then
        details.method = "disabled"
        -- A disabled combinator does not measure. Discard cumulative baselines
        -- so the first enabled sample never averages an entire disabled period.
        state.tick = tick
        state.input, state.output = nil, nil
        state.filter_signature = nil
        return meter_sensors.set_light(state, false)
    end
    local signal = circuit_slots.ensure_factor(control)
    alt_units.sync(state, signal.min)
    if not details.connected then
        -- Match MK1's disconnected behavior: no live power or filter feedback.
        -- Keeping only the X factor allows a clean first sample on reconnect.
        state.tick = tick
        state.input, state.output = nil, nil
        state.filter_signature = nil
        state.last_watts = {
            current_consumption = 0, current_production = 0,
            maximum_consumption = 0, maximum_production = 0,
        }
        circuit_slots.write_power(control, signal.min, 0, 0, 0, 0)
        if is_mk2 then
            local configuration = mk2_modes.get(state.entity.unit_number)
            if configuration.mode == 'manual' then
                circuit_slots.write_manual_preview(state,
                    mk2_modes.valid_manual_filters(state.entity.unit_number), {})
            else
                circuit_slots.write_filter_counts(state, {}, false)
            end
        end
        meter_sensors.set_light(state, false)
        return
    end
    local filters, selected_mode = mk2_filters.read(state, is_mk2)
    details.filter_mode = selected_mode or 'all'
    details.filter_active = filters ~= nil and #filters > 0
    details.filter_count = filters and #filters or 0
    -- Read-only snapshot for the overview GUI. In AUTO this is the list of
    -- valid, externally detected energy prototypes; in MANUAL the selection.
    -- Never reuse old values after power loss or when disabled.
    details.filter_names = filters or {}
    if is_mk2 and filters == nil and state.filter_signature ~= nil then
        -- A filter cable was just removed. Start fresh unfiltered statistics
        -- and allow the MK1 direct network-flow path immediately below.
        -- When the wire returns, the next filtered sample rebases again.
        state.filter_signature = nil
        state.input, state.output = nil, nil
    end
    local scale = 10 ^ -signal.min
    local variance = 60 / (tick - state.tick)
    local input, output, maxin, maxout, counts = electric_statistics.collect(state.net, state.sat, filters)
    details.filter_counts = counts
    filter_baseline.rebase_if_changed(state, filters, input, output)
    -- Keep existing cumulative inputs, building filters and capacity estimates authoritative.
    local input_diff = diff(input, state.input) * variance * scale
    local output_diff = diff(output, state.output) * variance * scale
    state.input, state.output, state.tick = input, output, tick
    -- MK1 and MK2 without control wires measure the complete electric
    -- network directly when available. A wired MK2 remains filter-driven.
    -- Global networks and unavailable direct flow use cumulative statistics.
    if not is_mk2 or filters == nil then
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
    meter_sensors.set_light(state, enabled)
    circuit_slots.write_power(control, signal.min, input_diff, output_diff, maxin, maxout)
    if is_mk2 then
        -- Only AUTO with actual external filters generates circuit feedback.
        -- Manual modes must never echo the incoming circuit into filters.
        if selected_mode == 'manual' then
            circuit_slots.write_manual_preview(state,
                mk2_modes.valid_manual_filters(state.entity.unit_number), counts)
        elseif selected_mode == 'auto' and filters ~= nil then
            circuit_slots.write_filter_counts(state, counts, details.connected)
        else
            circuit_slots.write_filter_counts(state, {}, false)
        end
    end
end

M.rounding_modes = rounding_modes

return M
