-- Lua-only interface and circuit ownership regression tests.
-- Run from the mod root: lua tests/modular_circuit_test.lua
package.path = "./?.lua;" .. package.path

local function eq(actual, expected, label)
    assert(actual == expected,
        ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

defines = {wire_connector_id={circuit_red=1,circuit_green=2}}
function table_size(t)
    local n=0
    for _ in pairs(t) do n=n+1 end
    return n
end

local function behavior()
    local slots={}
    local section={filters_count=5}
    function section.get_slot(index) return slots[index] end
    function section.set_slot(index, value)
        slots[index]=value
        if index > section.filters_count then section.filters_count=index end
    end
    function section.clear_slot(index) slots[index]=nil end
    setmetatable(section, {__newindex=function(t, key, value)
        if key == "filters" then
            for i=1,section.filters_count do slots[i]=nil end
            for i,slot in ipairs(value) do slots[i]=slot end
        else
            rawset(t,key,value)
        end
    end})
    local control={sections_count=1, sections={[1]=section}}
    function control.add_section()
        control.sections_count=1
        control.sections={[1]=section}
        return section
    end
    control.entity={get_signals=function() return nil end}
    function control.get_circuit_network() return nil end
    return control, slots, section
end

local slots_module=require "circuit_slots"
local control, slots=behavior()
slots_module.initialize(control, false)
eq(slots[1].value.name, "power-factor", "factor default after initialization")
eq(slots[1].min, 3, "default X=3")
slots_module.write_power(control, 5, 8, 7, 10, 11)
eq(slots[1].min, 5, "X5 is stored at slot 1")
eq(slots[2].value.name, "power-consumption", "consumption signal type")
eq(slots[2].min, 8, "rounded consumption output")
eq(slots[3].min, 7, "production output")
eq(slots[4].min, 10, "max consumption output")
eq(slots[5].min, 11, "max production output")
eq(slots_module.apply_factor(control, 4), true, "GUI factor change accepted")
eq(slots[1].min, 4, "GUI factor changed X to 4")
slots[1]={value={name="unrelated"},min=99}
eq(slots_module.apply_factor(control, 2), false, "GUI does not modify unrelated slot")
eq(slots[1].min, 99, "unrelated slot remains intact")

local circuit, output, section=behavior()
slots_module.initialize(circuit, true)
section.filters_count=7
output[6]={value={name="radar",type="item"},min=1}
output[7]={value={name="solar-panel",type="item"},min=2}
circuit.entity.get_signals=function()
    return {{signal={name="radar",type="item"}, count=2},
            {signal={name="solar-panel",type="item"}, count=1}}
end
local state={control=circuit,prev_outputs={}}
slots_module.write_filter_counts(state,{radar=3,["solar-panel"]=1})
eq(output[6].value.name, "radar", "MK2 radar feedback slot")
eq(output[6].min, 3, "MK2 radar feedback count")
eq(output[7].min, 1, "MK2 solar feedback count")
eq(state.prev_outputs.radar, 1, "feedback remembers previous radar count")
eq(state.prev_outputs["solar-panel"], 2, "feedback remembers previous solar count")
circuit.entity.get_signals=function() return nil end
slots_module.write_filter_counts(state,{})
eq(output[6], nil, "missing network clears first filter slot")
eq(output[7], nil, "missing network clears second filter slot")
eq(next(state.prev_outputs), nil, "missing network resets feedback baselines")

prototypes={item={
    radar={place_result={
        name="radar",
        get_max_energy_usage=function() return 5000 end,
        get_max_energy_production=function() return 0 end,
    }},
    ["solar-panel"]={place_result={
        name="solar-panel",
        get_max_energy_usage=function() return 0 end,
        get_max_energy_production=function() return 10000 end,
    }},
}}
local reader=require "mk2_filters"
local filter_control, _, _=behavior()
filter_control.get_circuit_network=function(id) return id==1 and {} or nil end
filter_control.entity.get_signals=function()
    return {{signal={name="radar",type="item"},count=2},
            {signal={name="solar-panel",type="item"},count=1}}
end
local read_state={control=filter_control,prev_outputs={radar=1,["solar-panel"]=1}}
local selected=reader.read(read_state,true)
eq(#selected, 1, "only one selected item exceeds feedback threshold")
eq(selected[1], "radar", "radar remains selected")
eq(reader.read(read_state,false),nil,"MK1 reads no MK2 filter selection")
filter_control.entity.get_signals=function() return nil end
eq(#reader.read(read_state,true),0,"MK2 no circuit connection yields empty filters")
print("EC_MODULAR_CIRCUIT_LUA_TEST=PASS")
