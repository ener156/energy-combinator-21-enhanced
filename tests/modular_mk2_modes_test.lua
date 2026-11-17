-- Regression for MK2 AUTO / manual full grid / saved building filters.
-- Run from the mod root: texlua tests/modular_mk2_modes_test.lua
package.path = './?.lua;' .. package.path
local function eq(a,b,msg)
    assert(a==b, (msg or 'mismatch')..': expected '..tostring(b)..' got '..tostring(a))
end
storage = {}
defines={wire_connector_id={circuit_red=1,circuit_green=2}}
prototypes={item={},entity={}}
local function entity(name,use,prod)
    local proto={name=name,
        get_max_energy_usage=function() return use end,
        get_max_energy_production=function() return prod end}
    prototypes.entity[name]=proto
    prototypes.item[name]={place_result=proto}
end
entity('radar',5000,0)
entity('solar-panel',0,10000)
entity('stone-furnace',0,0)
local settings=require 'mk2_modes'
local filter=require 'mk2_filters'
local wired=false
local current=nil
local ctrl={entity={get_signals=function() return current end}}
function ctrl.get_circuit_network(id)
    if wired and id==1 then return {} end
    return nil
end
local state={entity={unit_number=100},control=ctrl,prev_outputs={}}
local function read() return filter.read(state,true) end
local f,mode=read()
eq(f,nil,'AUTO without a cable uses entire grid')
eq(mode,'auto','AUTO default')
wired=true
f,mode=read()
eq(f,nil,'AUTO with an empty cable uses entire grid')
current={{signal={name='power-factor',type='virtual'},count=100}}
f=read()
eq(f,nil,'AUTO virtual-only input uses entire grid')
current={{signal={name='stone-furnace',type='item'},count=4}}
f=read()
eq(f,nil,'AUTO ignores non-electric entities')
current={{signal={name='radar',type='item'},count=1},
         {signal={name='radar',type='item'},count=2}}
f,mode=read()
eq(#f,1,'AUTO deduplicates radar')
eq(f[1],'radar','AUTO radar')
state.prev_outputs={radar=3}
current={{signal={name='radar',type='item'},count=3}}
eq(read(),nil,'AUTO excludes its own circuit feedback')
current={{signal={name='radar',type='item'},count=4},
         {signal={name='solar-panel',type='item'},count=2}}
f=read()
eq(#f,2,'AUTO selects two valid energy prototypes')
eq(f[1],'radar','AUTO sorts radar first')
eq(f[2],'solar-panel','AUTO sorts solar second')
eq(settings.set_mode(100,'all'),true,'set manual all-grid')
f,mode=read()
eq(f,nil,'all-grid mode ignores external circuit filters')
eq(mode,'all','all-grid mode')
eq(settings.set_mode(100,'manual'),true,'set manual filtering')
f,mode=read()
eq(f,nil,'empty manual filters use entire grid')
eq(mode,'manual','manual mode')
eq(settings.add_filter(100,'stone-furnace'),false,'reject non-electric manual filter')
eq(settings.add_filter(100,'radar'),true,'add radar')
eq(settings.add_filter(100,'radar'),false,'reject duplicate')
eq(settings.add_filter(100,'solar-panel'),true,'add solar')
f=read()
eq(#f,2,'manual filter count')
wired=false
current=nil
f=read()
eq(#f,2,'manual works without circuit wires')
eq(settings.remove_filter(100,'radar'),true,'remove radar')
f=read()
eq(#f,1,'one manual filter remains')
eq(f[1],'solar-panel','remaining solar')
settings.clone(100,101)
eq(settings.get(101).mode,'manual','clone operation mode')
eq(#settings.get(101).filters,1,'clone filter values')
settings.remove_filter(100,'solar-panel')
eq(read(),nil,'empty manual returns to whole grid')
eq(#settings.get(101).filters,1,'clone does not share mutable table')
package.loaded['mk2_modes']=nil
settings=require 'mk2_modes'
eq(settings.get(100).mode,'manual','save-like module reload preserves mode')
eq(settings.get(101).filters[1],'solar-panel','save-like module reload preserves filter')
settings.forget(100)
eq(storage.mk2_modes[100],nil,'destroyed entity settings removed')
print('ECMOD9_THREE_MODES_UNIT_TEST=PASS')
