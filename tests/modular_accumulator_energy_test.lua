-- ECMOD24 isolated tests for Factorio 2.1 accumulator energy totals.
package.path = "./?.lua;" .. package.path
local function eq(actual, expected, msg)
    assert(actual == expected, (msg or "value")..": expected "..
        tostring(expected)..", got "..tostring(actual))
end

prototypes={entity={
    accumulator={type="accumulator"},
    ["quality-accumulator"]={type="accumulator"},
    radar={type="radar"},
}}
local calls={}
local all={energy=180000000,capacity=180000000}
local per={
    ["accumulator:*"]={energy=180000000,capacity=180000000},
    ["accumulator:legendary"]={energy=180000000,capacity=180000000},
    ["accumulator:normal"]={energy=0,capacity=0},
    ["quality-accumulator:*"]={energy=5000000,capacity=10000000},
    ["quality-accumulator:normal"]={energy=5000000,capacity=10000000},
}
local parent={valid=true,get_accumulators_energy=function(args)
    local key=args.name and (args.name..":"..(args.quality or "*")) or "*"
    calls[#calls+1]=key
    return per[key] or all
end}
local pole={valid=true,electric_network={valid=true,parent_network=parent}}
local battery=require "accumulator_energy"

local stored,max=battery.collect(pole,nil,nil)
eq(stored,180000000,"whole grid stored energy")
eq(max,180000000,"whole grid capacity")
eq(calls[#calls],"*","unfiltered API call")

stored,max=battery.collect(pole,{"radar"},{})
eq(stored,0,"radar filter suppresses battery energy")
eq(max,0,"radar filter suppresses battery capacity")

stored,max=battery.collect(pole,{"accumulator"},{})
eq(stored,180000000,"all qualities filter stored")
eq(max,180000000,"all qualities filter capacity")
eq(calls[#calls],"accumulator:*","all qualities uses unqualified query")

stored,max=battery.collect(pole,{"accumulator"},{accumulator="legendary"})
eq(stored,180000000,"legendary stored")
eq(max,180000000,"legendary capacity")
eq(calls[#calls],"accumulator:legendary","legendary quality API filter")

stored,max=battery.collect(pole,{"accumulator"},{accumulator="normal"})
eq(stored,0,"normal selection excludes legendary energy")
eq(max,0,"normal selection excludes legendary capacity")

stored,max=battery.collect(pole,{"accumulator","accumulator","quality-accumulator"},{accumulator="legendary"})
eq(stored,185000000,"multiple prototype stored sum without duplication")
eq(max,190000000,"multiple prototype capacity without duplication")

stored,max=battery.collect({valid=false},nil,nil)
eq(stored,0,"disconnected stored")
eq(max,0,"disconnected capacity")

local units=require "power_units"
eq(units.joules_at_factor(180000000,6),"180 MJ","factor X6 in MJ")
eq(units.joules_at_factor(180000000,3),"180000 kJ","factor X3 in kJ")
eq(units.joules_at_factor(nil,3),"—","missing battery sample")
print("ECMOD24_ACCUMULATOR_STORAGE_LUA_TEST=PASS")
