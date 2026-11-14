-- Pure Lua regression tests for the complete power-measurement owner.
-- Run from the mod root: texlua tests/modular_power_meter_test.lua
package.path = "./?.lua;" .. package.path

local function eq(actual, expected, label)
    assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

local sample={input=1000, output=1000, maxin=12500, maxout=12500, counts={radar=1}}
local direct_watts=750000
local filters={"radar"}
local writes=0
package.loaded["electric_statistics"]={
    collect=function(net, sat, selection)
        return sample.input, sample.output, sample.maxin, sample.maxout, sample.counts
    end,
}
package.loaded["electric_direct"]={read_watts=function() return direct_watts end}
package.loaded["mk2_filters"]={read=function(_,is_mk2) return is_mk2 and filters or nil end}
package.loaded["alt_units"]={sync=function(state,factor) state.last_alt_factor=factor end}
package.loaded["meter_sensors"]={
    connect=function(a,b) eq(a~=nil and b~=nil,true,"sensor pair present") end,
    set_light=function(state,enabled) state.light_on=enabled end,
}
package.loaded["circuit_slots"]={
    ensure_factor=function(control) return {min=control.factor} end,
    write_power=function(control,factor,i,o,mi,mo)
        writes=writes+1
        control.outputs={factor,i,o,mi,mo}
    end,
    write_filter_counts=function(state,counts) state.last_filter_counts=counts end,
}

settings={global={
    ["energy-combinator-round-current-consumption"]={value="nearest"},
    ["energy-combinator-round-current-production"]={value="nearest"},
    ["energy-combinator-round-maximum-consumption"]={value="up"},
    ["energy-combinator-round-maximum-production"]={value="down"},
}}
local meter=require "power_meter"
local modes=meter.rounding_modes()
eq(modes.current_consumption,"nearest","consumption rounding mode")
eq(modes.maximum_consumption,"up","maximum consumption rounding mode")
eq(modes.maximum_production,"down","maximum production rounding mode")

local function state(factor, tick)
    return {
        entity={name="test-power-combinator"},
        net={valid=true,electric_network_id=7,surface={has_global_electric_network=false}},
        sat={valid=true,electric_network_id=7},
        control={enabled=true,factor=factor},
        tick=tick,prev_outputs={}
    }
end

-- MK1: direct, 750kW and X5 round nearest to 8 (1.2.13 compatibility fix).
local mk1=state(5,5)
meter.write(mk1,10,modes,false)
eq(mk1.control.outputs[1],5,"MK1 factor X5")
eq(mk1.control.outputs[2],8,"MK1 X5 nearest 7.5 becomes 8")
eq(mk1.control.outputs[3],8,"MK1 direct output mirrors network transfer")
eq(mk1.control.outputs[4],8,"MK1 max demand ceil 7.5")
eq(mk1.control.outputs[5],7,"MK1 max production floor 7.5")
eq(mk1.last_watts.current_consumption,750000,"GUI snapshot stores physical watts")
eq(mk1.diagnostics.method,"direct","MK1 direct method")
eq(mk1.diagnostics.connected,true,"connected sensors")
eq(mk1.light_on,true,"good MK1 power signal enables sensor light")

-- MK1 fallback: cumulative statistics when direct flow cannot be read.
direct_watts=nil
mk1.control.factor=0
sample.input=2000
sample.output=4000
meter.write(mk1,15,modes,false)
eq(mk1.control.outputs[2],12000,"MK1 fallback consumption delta")
eq(mk1.control.outputs[3],36000,"MK1 fallback production delta")
eq(mk1.diagnostics.method,"statistics","MK1 fallback method")
eq(mk1.last_alt_factor,0,"ALT factor follows selected unit")

-- MK2: initial filter rebases cumulative totals, preventing millions of watts.
local mk2=state(5,5)
sample.input=10000
sample.output=0
filters={"radar"}
meter.write(mk2,10,modes,true)
eq(mk2.control.outputs[2],0,"initial MK2 filter consumption rebase")
eq(mk2.control.outputs[3],0,"initial MK2 filter production rebase")
eq(mk2.diagnostics.filter_count,1,"one MK2 selected prototype")
eq(mk2.diagnostics.is_mk2,true,"MK2 diagnostics flag")
eq(mk2.last_filter_counts.radar,1,"MK2 feedback counts written")

sample.input=110000
sample.output=50000
meter.write(mk2,20,modes,true)
eq(mk2.control.outputs[2],6,"MK2 filtered consumption 600kW at X5")
eq(mk2.control.outputs[3],3,"MK2 filtered production 300kW at X5")
eq(mk2.control.outputs[4],8,"MK2 maximum demand rounded up")
eq(mk2.control.outputs[5],7,"MK2 maximum generation rounded down")
eq(mk2.diagnostics.method,"statistics","MK2 does not use direct flow")

filters={"solar-panel"}
sample.input=999999999
sample.output=99999999
meter.write(mk2,25,modes,true)
eq(mk2.control.outputs[2],0,"MK2 changed selection rebases large input")
eq(mk2.control.outputs[3],0,"MK2 changed selection rebases large output")
eq(mk2.diagnostics.filter_count,1,"filter count after switch")

-- Overflow suppresses all four physical outputs and darkens status light.
sample.input=sample.input+200000000
sample.output=sample.output
mk2.control.factor=0
meter.write(mk2,30,modes,true)
eq(mk2.control.outputs[2],0,"overflow suppresses consumption output")
eq(mk2.control.outputs[3],0,"overflow suppresses production output")
eq(mk2.control.outputs[4],0,"overflow suppresses maximum consumption")
eq(mk2.control.outputs[5],0,"overflow suppresses maximum production")
eq(mk2.light_on,false,"overflow disables lamp")

-- Disabled combinator must not generate new circuit slot values.
local disabled=state(5,10)
disabled.control.enabled=false
local before=writes
meter.write(disabled,15,modes,false)
eq(disabled.diagnostics.method,"disabled","disabled diagnostics")
eq(disabled.light_on,false,"disabled status lamp")
eq(writes,before,"disabled combinator does not write power slots")
print("EC_MODULAR_POWER_METER_LUA_TEST=PASS")
