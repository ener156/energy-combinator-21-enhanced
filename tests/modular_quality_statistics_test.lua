-- Quality-aware electric-network statistics regression for Factorio 2.1.
-- Run from the mod root: texlua tests/modular_quality_statistics_test.lua
package.path = "./?.lua;" .. package.path

local function eq(actual, expected, label)
    assert(actual == expected,
        ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

defines = {flow_precision_index={one_second=1, five_seconds=2}}

local function entity(normal_usage, normal_output, quality_usage, quality_output, kind)
    return {
        type=kind or "solar-panel",
        electric_energy_source_prototype={drain=0},
        get_max_energy_usage=function(quality)
            return (quality_usage and quality_usage[quality]) or normal_usage
        end,
        get_max_energy_production=function(quality)
            return (quality_output and quality_output[quality]) or normal_output
        end,
    }
end

prototypes={entity={
    radar=entity(5000, 0, {rare=8000}, nil, "radar"),
    ["solar-panel"]=entity(0, 10000, nil, {uncommon=13000,legendary=25000}),
    ["electric-energy-interface"]=entity(100, 100, nil, nil, "electric-energy-interface"),
}}

local flows={
    ["input:radar:normal"]=1, ["input:radar:rare"]=2,
    ["output:solar-panel:normal"]=1,
    ["output:solar-panel:uncommon"]=2,
    ["output:solar-panel:legendary"]=1,
}

local stat={
    valid=true,
    -- The old normal-only tables remain populated when quality buckets exist.
    input_counts={radar=100},
    output_counts={["solar-panel"]=400},
    input_quality_counts={
        normal={radar=100},
        rare={radar=200},
    },
    output_quality_counts={
        normal={["solar-panel"]=400},
        uncommon={["solar-panel"]=800},
        legendary={["solar-panel"]=1000},
    },
    get_flow_count=function(query)
        local id=query.name
        local name=type(id)=="table" and id.name or id
        local quality=type(id)=="table" and id.quality or "normal"
        return flows[query.category..":"..name..":"..quality] or 0
    end,
}
local net={valid=true,electric_network_id=30,electric_network_statistics=stat,
    surface={has_global_electric_network=false}}
local sat={valid=true,electric_network_id=30,electric_buffer_size=1,energy=1}
local statistics=require "electric_statistics"

local input,output,maxin,maxout,counts=statistics.collect(net,sat,nil)
eq(input,300,"normal and rare cumulative consumption")
eq(output,2200,"normal uncommon legendary cumulative production")
eq(maxin*60,1260000,"quality-adjusted maximum consumption")
eq(maxout*60,3660000,"quality-adjusted maximum production")
eq(counts.radar,3,"normal and rare radar counts")
eq(counts["solar-panel"],4,"normal uncommon legendary solar counts")

input,output,maxin,maxout,counts=statistics.collect(net,sat,{"solar-panel"})
eq(input,0,"filtered production ignores radar")
eq(output,2200,"one MK2 prototype filter includes all solar qualities")
eq(maxout*60,3660000,"filtered quality production capacity")
eq(counts["solar-panel"],4,"filter feedback combines quality counts")
eq(counts.radar,nil,"no radar filter feedback")

input,output,maxin,maxout,counts=statistics.collect(net,sat,{"radar"})
eq(input,300,"radar filter includes rare radar")
eq(output,0,"radar filter ignores solar")
eq(maxin*60,1260000,"radar filter uses rare capacity")
eq(counts.radar,3,"radar filter counts all qualities")

-- A network containing only non-normal generators must not report zero.
stat.input_counts={}
stat.output_counts={}
stat.input_quality_counts={}
stat.output_quality_counts={uncommon={["solar-panel"]=500}}
input,output,maxin,maxout,counts=statistics.collect(net,sat,nil)
eq(input,0,"quality-only network has no consumers")
eq(output,500,"quality-only output is included")
eq(maxout*60,1560000,"quality-only output capacity: two uncommon panels")
eq(counts["solar-panel"],2,"quality-only generator count")

-- Legacy mock/API shape without quality maps remains supported.
stat.input_counts={radar=100}
stat.output_counts={["solar-panel"]=400}
stat.input_quality_counts=nil
stat.output_quality_counts=nil
input,output,maxin,maxout=statistics.collect(net,sat,nil)
eq(input,100,"legacy normal consumption")
eq(output,400,"legacy normal production")
eq(maxin*60,300000,"legacy normal maximum consumption")
eq(maxout*60,600000,"legacy normal maximum production")
-- Regression from actual ECMOD22 user save: six legendary accumulators
-- (180 MJ total storage, 6 * 750 kW discharge capacity) appear separately
-- under accumulator charge in Factorio. They must not add 4.5 MW to MAX
-- generation, though their real discharge and building count remain visible.
prototypes.entity.accumulator = entity(750000, 750000, nil,
    {legendary=750000}, "accumulator")
flows["output:accumulator:legendary"] = 6
flows["input:accumulator:legendary"] = 6
stat.input_counts = {}
stat.input_quality_counts = {legendary={accumulator=111}}
stat.output_counts = {}
stat.output_quality_counts = {legendary={accumulator=111}}
input,output,maxin,maxout,counts=statistics.collect(net,sat,nil)
eq(input,111,"legendary accumulator charge still counted")
eq(maxin,0,"six legendary accumulators do not inflate max consumption")
eq(output,111,"legendary accumulator discharge still counted")
eq(maxout,0,"six legendary accumulators do not add 4.5MW generation capacity")
eq(counts.accumulator,6,"accumulator count still available to MK2")
input,output,maxin,maxout,counts=statistics.collect(net,sat,{"accumulator"})
eq(output,111,"filtered accumulator discharge still counted")
eq(maxout,0,"filtered accumulator capacity excludes storage")
eq(counts.accumulator,6,"filtered accumulator feedback count")
print("EC_MODULAR_QUALITY_STATISTICS_LUA_TEST=PASS")
