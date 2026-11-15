-- ECMOD22: manual entity filters with an explicit quality choice.
-- Run from mod root: texlua tests/modular_quality_filter_test.lua
package.path="./?.lua;"..package.path
local function eq(a,b,msg)
    assert(a==b,(msg or "mismatch")..": expected "..tostring(b)..", got "..tostring(a))
end
storage={}
defines={flow_precision_index={one_second=1,five_seconds=2},
         wire_connector_id={circuit_red=1,circuit_green=2}}
local function prototype(name, usage, production, rare_usage, uncommon_production)
    return {name=name, type="radar", electric_energy_source_prototype={drain=0},
        get_max_energy_usage=function(quality)
            return quality=="rare" and (rare_usage or usage) or usage
        end,
        get_max_energy_production=function(quality)
            return quality=="uncommon" and (uncommon_production or production) or production
        end}
end
prototypes={quality={normal={level=0},uncommon={level=1},rare={level=2},legendary={level=4}},
    entity={
        radar=prototype("radar",5000,0,8000),
        ["solar-panel"]=prototype("solar-panel",0,10000,nil,15000),
        ["stone-furnace"]=prototype("stone-furnace",0,0)},
    item={}}
for name,entity in pairs(prototypes.entity) do
    prototypes.item[name]={place_result=entity}
end
local modes=require "mk2_modes"
local filters=require "mk2_filters"
local baseline=require "filter_baseline"
local stats=require "electric_statistics"
local id=201
eq(modes.set_mode(id,"manual"),true,"manual mode")
eq(modes.add_filter(id,"solar-panel"),true,"add solar")
eq(modes.add_filter(id,"radar"),true,"add radar")
local selected, mode, quality=filters.read({entity={unit_number=id}},true)
eq(mode,"manual","mode returned")
eq(#selected,2,"two building filters")
eq(next(quality),nil,"existing-style selections default to all qualities")
eq(modes.set_filter_quality(id,"solar-panel","uncommon"),true,"select uncommon")
eq(modes.set_filter_quality(id,"radar","rare"),true,"select rare")
eq(modes.set_filter_quality(id,"radar","unknown-quality"),false,"reject invalid quality")
selected, mode, quality=filters.read({entity={unit_number=id}},true)
eq(quality["solar-panel"],"uncommon","read solar quality")
eq(quality.radar,"rare","read radar quality")

local netstat={
    input_counts={radar=100},output_counts={["solar-panel"]=200},
    input_quality_counts={normal={radar=100},rare={radar=250}},
    output_quality_counts={normal={["solar-panel"]=200},uncommon={["solar-panel"]=450}},
    get_flow_count=function(query)
        local q=type(query.name)=="table" and query.name.quality or "normal"
        if query.name and ((type(query.name)=="table" and query.name.name) or query.name)=="radar" then
            return q=="rare" and 2 or (q=="normal" and 1 or 0)
        end
        return q=="uncommon" and 3 or (q=="normal" and 1 or 0)
    end}
local net={valid=true,electric_network_id=3,electric_network_statistics=netstat,
    surface={has_global_electric_network=false}}
local sat={valid=true,electric_network_id=3,electric_buffer_size=1,energy=1}
local input,output,maxin,maxout,counts=stats.collect(net,sat,selected,quality)
eq(input,250,"rare-only consumption excludes normal radar")
eq(output,450,"uncommon-only output excludes normal solar")
eq(maxin*60,960000,"rare-only max consumption")
eq(maxout*60,2700000,"uncommon-only max production")
eq(counts.radar,2,"rare feedback only")
eq(counts["solar-panel"],3,"uncommon feedback only")

local state={filter_signature=nil,input=0,output=0}
eq(baseline.rebase_if_changed(state,selected,input,output,quality),true,"first quality selection rebase")
eq(baseline.rebase_if_changed(state,selected,input,output,quality),false,"unchanged quality no rebase")
eq(modes.set_filter_quality(id,"solar-panel","normal"),true,"quality switch")
selected,mode,quality=filters.read({entity={unit_number=id}},true)
eq(baseline.rebase_if_changed(state,selected,input,output,quality),true,"quality switch rebases")
eq(modes.set_filter_quality(id,"solar-panel","all"),true,"all-qualities restore")
selected,mode,quality=filters.read({entity={unit_number=id}},true)
eq(quality["solar-panel"],nil,"all-qualities removes restriction")
local bp=modes.export(id,{"radar","solar-panel"})
eq(bp.version,3,"blueprint format v3")
eq(bp.qualities.radar,"rare","quality saved into blueprint")
eq(modes.import(202,bp,{"radar","solar-panel"}),true,"import v3 blueprint")
eq(modes.filter_qualities(202).radar,"rare","blueprint quality restored")
modes.clone(202,203)
eq(modes.filter_qualities(203).radar,"rare","cloning preserves quality")
modes.set_filter_quality(202,"radar","normal")
eq(modes.filter_qualities(203).radar,"rare","cloned quality map independent")
eq(modes.import(204,{version=2,mode="manual",filters={"radar"},
    source_slots={"radar"}},{"radar"}),true,"older v2 blueprint supported")
eq(modes.filter_qualities(204).radar,nil,"v2 defaults to all")
eq(modes.remove_filter(203,"radar"),true,"remove filtered building")
eq(modes.filter_qualities(203).radar,nil,"removal clears quality restriction")
print("ECMOD22_MANUAL_QUALITY_FILTER_LUA_TEST=PASS")
