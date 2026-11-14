-- Lua-only regression tests for the isolated modular measurement owners.
-- Run from the mod root: lua tests/modular_measurement_test.lua
package.path = "./?.lua;" .. package.path

local function eq(actual, expected, label)
    assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

-- MK2 filter baseline: only a changed effective filter set rebases totals.
local baseline = require "filter_baseline"
local state = {input=10, output=20}
eq(baseline.rebase_if_changed(state, {"radar", "solar-panel"}, 1000, 2000), true, "first selection")
eq(state.input, 1000, "initial input baseline")
eq(state.output, 2000, "initial output baseline")
eq(baseline.rebase_if_changed(state, {"solar-panel", "radar"}, 1500, 2500), false, "reorder is not a change")
eq(state.input, 1000, "reorder keeps input")
eq(baseline.rebase_if_changed(state, {"radar"}, 1500, 2500), true, "filter removal")
eq(state.input, 1500, "changed filter rebases input")
eq(baseline.rebase_if_changed(state, {}, 2000, 3000), true, "empty filter is a real selection")
eq(baseline.rebase_if_changed(state, nil, 3000, 4000), false, "MK1 has no filter baseline")
eq(state.input, 2000, "MK1 never rebases")

-- MK1 local direct network transfer, with safe fallback on unsupported networks.
local direct = require "electric_direct"
local net = {
    valid = true, electric_network_id = 7, surface={has_global_electric_network=false},
    electric_network = {valid=true, parent_network={
        valid=true, flow_last_tick={total_transfer=5000}
    }}
}
local sat = {valid=true, electric_network_id=7}
eq(direct.read_watts(net, sat), 300000, "MK1 direct 300kW")
net.electric_network.parent_network.flow_last_tick.total_transfer = 0
eq(direct.read_watts(net, sat), 0, "zero is a valid direct reading")
sat.electric_network_id = 8
eq(direct.read_watts(net, sat), nil, "disconnected sensors fallback")
sat.electric_network_id = 7
net.surface.has_global_electric_network = true
eq(direct.read_watts(net, sat), nil, "global network falls back to statistics")
net.surface.has_global_electric_network = false
net.electric_network.parent_network.flow_last_tick.total_transfer = 0/0
eq(direct.read_watts(net, sat), nil, "NaN is rejected")
net.electric_network.parent_network.flow_last_tick.total_transfer = 5000

-- Legacy cumulative statistics and maximum-capacity estimates were extracted,
-- not changed. Mock only the Factorio runtime interfaces they access.
defines = {flow_precision_index={one_second=1, five_seconds=2}}
local function prototype(name, usage, production, kind)
    return {
        type=kind or "radar",
        electric_energy_source_prototype={drain=0},
        get_max_energy_usage=function() return usage end,
        get_max_energy_production=function() return production end
    }
end
prototypes = {entity={
    radar=prototype("radar", 5000, 0),
    ["solar-panel"]=prototype("solar-panel", 0, 10000),
    ["electric-energy-interface"]=prototype("electric-energy-interface", 100, 100, "electric-energy-interface")
}}
local function fake_statistics()
    return {
        valid=true,
        input_counts={radar=1000, ["electric-energy-interface"]=99999},
        output_counts={["solar-panel"]=2000, ["electric-energy-interface"]=99999},
        get_flow_count=function(query)
            if query.name == "radar" and query.category == "input" then return 1 end
            if query.name == "solar-panel" and query.category == "output" then return 1 end
            return 0
        end
    }
end
local statistics = require "electric_statistics"
local stat = fake_statistics()
local meter = {
    valid=true, electric_network_id=7, electric_network_statistics=stat,
    surface={has_global_electric_network=false}
}
local satisfaction = {valid=true, electric_network_id=7, electric_buffer_size=1, energy=1}
local input, output, max_input, max_output, counts = statistics.collect(meter, satisfaction, nil)
eq(input, 1000, "unfiltered total consumption")
eq(output, 2000, "unfiltered total production")
eq(max_input * 60, 300000, "unfiltered maximum consumption")
eq(max_output * 60, 600000, "unfiltered maximum production")
eq(counts.radar, 1, "radar count")
eq(counts["solar-panel"], 1, "solar count")
input, output, max_input, max_output = statistics.collect(meter, satisfaction, {"radar"})
eq(input, 1000, "filtered radar consumption")
eq(output, 0, "filtered radar no production")
eq(max_output, 0, "filtered radar max production")
input, output = statistics.collect(meter, satisfaction, {})
eq(input, 0, "empty filter has zero consumption")
eq(output, 0, "empty filter has zero production")
satisfaction.electric_network_id = 99
input, output = statistics.collect(meter, satisfaction, nil)
eq(input, 0, "isolated satisfaction network suppresses disconnected statistics")
eq(output, 0, "isolated satisfaction network suppresses production")
print("EC_MODULAR_MEASUREMENT_LUA_TEST=PASS")
