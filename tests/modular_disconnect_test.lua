package.path = './?.lua;' .. package.path
local function eq(actual, expected, label)
  assert(actual == expected, ('%s: expected %s got %s'):format(label,tostring(expected),tostring(actual)))
end
function table_size(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
defines={wire_connector_id={circuit_red=1,circuit_green=2}}
local wire_connected=true
local grid_connected=true
local signal_list={
  {signal={name='radar',type='item'},count=5},
  {signal={name='solar-panel',type='item'},count=6},
}
local section={filters_count=5}
local contents={}
function section.get_slot(i) return contents[i] end
function section.set_slot(i,v) contents[i]=v if i>section.filters_count then section.filters_count=i end end
function section.clear_slot(i) contents[i]=nil end
setmetatable(section,{__newindex=function(t,k,v)
  if k=='filters' then
    for i in pairs(contents) do contents[i]=nil end
    for i,x in ipairs(v) do contents[i]=x end
    rawset(t,'filters_count',#v)
  else rawset(t,k,v) end
end})
local control={sections_count=1,sections={[1]=section},enabled=true}
function control.get_circuit_network(id) return wire_connected and {id=id} or nil end
function control.add_section() return section end
local entity={valid=true,unit_number=202,name='power-combinator-MK2'}
function entity.get_signals()
  -- Factorio may return the combinator's own output signals even without wires.
  return signal_list
end
control.entity=entity
function entity.get_or_create_control_behavior() return control end
local slots=require 'circuit_slots'
slots.initialize(control,true)
slots.apply_factor(control,1)
local state={entity=entity,control=control,
  net={valid=true,electric_network_id=9,surface={has_global_electric_network=false}},
  sat={valid=true,electric_network_id=9},
  tick=10, prev_outputs={}, input=0, output=0}
-- A manually configured second native section belongs to the player, not this mod.
local extra={value={name='manual-signal',type='item'},min=1}
control.sections[2]={get_slot=function() return extra end}
control.sections_count=2
-- Verify the circuit feedback itself independent of power metering.
slots.write_filter_counts(state,{radar=1,['solar-panel']=2},true)
eq(slots.get(control,6).value.name,'radar','connected feedback first item')
eq(slots.get(control,7).min,2,'connected feedback second item count')
eq(slots.get(control,1).min,1,'factor intact before disconnect')
-- Electric grid disappears despite a still-connected circuit wire.
slots.write_filter_counts(state,{radar=1,['solar-panel']=2},false)
eq(slots.get(control,6),nil,'electrical disconnect clears feedback slot 6')
eq(slots.get(control,7),nil,'electrical disconnect clears feedback slot 7')
eq(next(state.prev_outputs),nil,'electrical disconnect resets echo bookkeeping')
eq(control.sections[2].get_slot(1),extra,'manual extra section not altered')
-- Feedback restores when the grid and input signals come back.
slots.write_filter_counts(state,{radar=3,['solar-panel']=4},true)
eq(slots.get(control,6).min,3,'reconnect restores radar count')
eq(slots.get(control,7).min,4,'reconnect restores solar count')
-- Now physically remove both circuit wires while get_signals() still returns stale echo.
wire_connected=false
slots.write_filter_counts(state,{radar=3,['solar-panel']=4},true)
eq(slots.get(control,6),nil,'no circuit wires clear echoed filter signal')
eq(slots.get(control,7),nil,'no circuit wires clear echoed solar signal')
eq(control.sections[2].get_slot(1),extra,'no circuit wire keeps manual section')
wire_connected=true
-- Verify the integration: power_meter must drive zero power and clear feedback
-- in the FIRST disconnected update, then restore on reconnection.
package.loaded.electric_statistics={collect=function()
  return 5000, 2000, 1000, 2000, {radar=3,['solar-panel']=4}
end}
package.loaded.electric_direct={read_watts=function() return nil end}
package.loaded.mk2_filters={read=function(_,is_mk2) return is_mk2 and {'radar','solar-panel'} or nil end}
package.loaded.alt_units={sync=function(s,factor) s.alt_factor=factor end}
package.loaded.meter_sensors={
  connect=function() end,
  set_light=function(s,on) s.light=on end,
}
package.loaded.filter_baseline={rebase_if_changed=function(s,filters,input,output)
  local k=filters and table.concat(filters,',') or ''
  if s.filter_signature~=k then s.filter_signature=k s.input=input s.output=output end
end}
settings={global={
 ['energy-combinator-round-current-consumption']={value='nearest'},
 ['energy-combinator-round-current-production']={value='nearest'},
 ['energy-combinator-round-maximum-consumption']={value='nearest'},
 ['energy-combinator-round-maximum-production']={value='nearest'},
}}
local power=require 'power_meter'
local modes=power.rounding_modes()
slots.write_filter_counts(state,{radar=3,['solar-panel']=4},true)
-- Grid loss after previous updates; filter selections and feedback were nonzero.
state.net.electric_network_id=nil
state.sat.electric_network_id=nil
power.write(state,20,modes,true)
eq(slots.get(control,1).min,1,'factor preserved on grid loss')
for i=2,5 do eq(slots.get(control,i).min,0,'power slot '..i..' zero on disconnect') end
for i=6,7 do eq(slots.get(control,i),nil,'feedback slot '..i..' cleared on disconnect') end
eq(state.last_watts.current_consumption,0,'GUI current display cleared')
eq(state.last_watts.maximum_production,0,'GUI maximum display cleared')
eq(state.input,nil,'old cumulative input cleared')
eq(state.filter_signature,nil,'old filter baseline cleared')
eq(state.diagnostics.connected,false,'disconnected diagnostics')
eq(state.light,false,'disconnected status light')
eq(control.sections[2].get_slot(1),extra,'manual native section still preserved')
state.net.electric_network_id=9
state.sat.electric_network_id=9
power.write(state,25,modes,true)
eq(slots.get(control,6).min,3,'feedback repopulates when grid returns')
eq(slots.get(control,7).min,4,'second feedback repopulates when grid returns')
eq(slots.get(control,2).min,0,'first reconnected sample rebaselines without spike')
eq(state.diagnostics.connected,true,'connected diagnostics restored')
print('EC_MODULAR_DISCONNECT_TEST=PASS')
