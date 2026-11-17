-- Pure Lua regression for hidden sensors and active state lifecycle.
-- Run from the mod root: lua tests/modular_lifecycle_test.lua
package.path = "./?.lua;" .. package.path

local function eq(actual, expected, label)
    assert(actual == expected,
        ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

defines = {
    wire_connector_id = {circuit_red=1, circuit_green=2},
    wire_origin = {script=3},
}
local wire_count, sensor_creations, sensor_destructions = 0, 0, 0
local alt_sync, alt_remove, registration = {}, {}, 0
local initialized = {}
package.loaded["circuit_slots"] = {
    factor_signal={type="virtual", name="power-factor"},
    initialize=function(control, is_mk2)
        control.initialized=true
        initialized[#initialized+1]=is_mk2 and "MK2" or "MK1"
    end,
    get=function(control, index)
        eq(index, 1, "factor stored in slot 1")
        return {min=3}
    end,
}
package.loaded["alt_units"] = {
    sync=function(state, factor)
        alt_sync[#alt_sync+1]={id=state.entity.unit_number, factor=factor}
    end,
    remove=function(id) alt_remove[#alt_remove+1]=id end,
}

local sensors = {}
local function make_meter(name, position)
    sensor_creations = sensor_creations + 1
    local meter={name=name, position=position, valid=true}
    function meter.get_circuit_network(_) return nil end
    function meter.get_wire_connector(_, _)
        return {connect_to=function(_, _, _) wire_count=wire_count+1 end}
    end
    function meter.get_or_create_control_behavior() return {} end
    function meter.destroy()
        meter.valid=false
        sensor_destructions=sensor_destructions+1
    end
    sensors[#sensors+1]=meter
    return meter
end

local surface = {}
local entities={}
function surface.find_entities_filtered(options)
    if type(options.name)=="table" then return entities end
    local found={}
    for _,sensor in ipairs(sensors) do
        if sensor.valid and sensor.name==options.name
            and sensor.position.x==options.position.x then
            found[#found+1]=sensor
        end
    end
    return found
end
function surface.create_entity(options) return make_meter(options.name, options.position) end

local function make_entity(id, name)
    local combinator={unit_number=id, name=name, prototype={name=name},surface=surface, position={x=id,y=0},force="player"}
    function combinator.get_or_create_control_behavior() return {} end
    return combinator
end
entities[1]=make_entity(11,"test-mk1")
entities[2]=make_entity(12,"test-mk2")
game={tick=500, surfaces={[1]=surface}}
storage={}
script={
    register_on_object_destroyed=function(_)
        registration=registration+1
        return registration
    end,
}
local lifecycle=require "combinator_state"
local names={"test-mk1","test-mk2"}
local allowed={["test-mk1"]=true,["test-mk2"]=true}
local filter={["test-mk2"]=true}
lifecycle.rebuild(names, allowed, filter)
eq(storage.state[11].tick,500,"created state uses game tick")
eq(storage.state[12].tick,500,"second state uses game tick")
eq(storage.state[11].control.initialized,true,"control behavior initialized")
eq(#initialized,2,"both tiers initialized")
eq(initialized[1],"MK1","first tier stays MK1")
eq(initialized[2],"MK2","second tier stays MK2")
eq(sensor_creations,4,"two hidden meters per combinator")
eq(wire_count,4,"two circuit wires per sensor pair")
eq(#alt_sync,2,"ALT labels synchronized")
eq(alt_sync[1].factor,3,"original factor defaults to X3")
eq(storage.registrations[1],11,"first destruction registration")
eq(storage.registrations[2],12,"second destruction registration")

local light=storage.state[11].light.circuit_condition
eq(light.condition.first_signal.name,"power-factor","status lamp uses factor signal")
eq(light.condition.constant,1,"sensor lamp initial condition is disabled")

lifecycle.cleanup_registration(1)
eq(storage.state[11],nil,"deleted combinator state removed")
eq(storage.registrations[1],nil,"destroy registration removed")
eq(sensor_destructions,2,"both hidden meters destroyed")
eq(alt_remove[1],11,"ALT text removed")
lifecycle.cleanup_registration(1)
eq(sensor_destructions,2,"cleanup is idempotent")
eq(storage.state[12]~=nil,true,"other combinator unaffected")

local ignored=make_entity(99,"unrelated")
lifecycle.allocate(ignored,allowed,filter)
eq(storage.state[99],nil,"unrelated entity ignored")

-- Rebuild is a fresh registry reconstruction on configuration change.
lifecycle.rebuild(names,allowed,filter)
eq(storage.state[11]~=nil,true,"placed first tier restored")
eq(storage.state[12]~=nil,true,"placed second tier restored")
eq(storage.registrations[3],11,"rebuild gives a fresh registration for first entity")
eq(storage.registrations[4],12,"rebuild gives a fresh registration for second entity")
print("EC_MODULAR_LIFECYCLE_LUA_TEST=PASS")
