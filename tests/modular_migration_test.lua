-- Lua-only real-owner compatibility regression: existing combinators and hidden meters.
-- Run at the mod root: texlua tests/modular_migration_test.lua
package.path = './?.lua;' .. package.path

local function eq(actual, expected, message)
    assert(actual == expected, ('%s: expected %s; got %s'):format(message, tostring(expected), tostring(actual)))
end

defines = {
    wire_connector_id = {circuit_red=1, circuit_green=2},
    wire_origin = {script=3},
}
local factors = {}
local removed_alt = {}
package.loaded['alt_units'] = {
    sync = function(state, factor) factors[state.entity.unit_number] = factor end,
    remove = function(id) removed_alt[id] = true end,
}

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for k, v in pairs(value) do result[copy(k)] = copy(v) end
    return result
end

local function new_section()
    local slot_data = {}
    local section = {filters_count=0}
    function section.get_slot(i) return copy(slot_data[i]) end
    function section.set_slot(i, value)
        slot_data[i] = copy(value)
        if i > section.filters_count then section.filters_count = i end
    end
    function section.clear_slot(i) slot_data[i] = nil end
    setmetatable(section, {__newindex=function(t, key, value)
        if key == 'filters' then
            for i in pairs(slot_data) do slot_data[i] = nil end
            for i, v in ipairs(value) do slot_data[i] = copy(v) end
            rawset(t, 'filters_count', #value)
        else
            rawset(t, key, value)
        end
    end})
    return section
end

local function new_combinator(id, name, surface)
    local control, section
    local entity = {
        name=name, prototype={name=name}, unit_number=id, valid=true,
        surface=surface, force='player', position={x=id,y=0},
    }
    function entity.get_or_create_control_behavior()
        if not control then
            section = new_section()
            control = {sections_count=1, sections={[1]=section}, entity=entity, enabled=true}
            function control.get_circuit_network() return nil end
            function control.add_section()
                control.sections_count = 1
                control.sections[1] = section
                return section
            end
        end
        return control
    end
    function entity.get_signals() return nil end
    return entity
end

local meters, placed = {}, {}
local surface = {fail_satisfaction=false}
local serial, creations, destructions, connections = 0, 0, 0, 0
function surface.find_entities_filtered(args)
    local names = args.name
    if type(names) == 'table' then
        local result = {}
        for _,entity in pairs(placed) do
            for _,name in ipairs(names) do
                if entity.valid and entity.name == name then result[#result+1] = entity end
            end
        end
        return result
    end
    local result = {}
    for _,entity in ipairs(meters) do
        if entity.valid and entity.name == names and entity.position.x == args.position.x then
            result[#result+1] = entity
        end
    end
    return result
end
function surface.create_entity(args)
    if surface.fail_satisfaction and args.name == 'power-combinator-meter-satisfaction' then
        return nil
    end
    creations = creations + 1
    serial = serial + 1
    local meter = {valid=true, name=args.name, position=args.position, id=serial}
    function meter.get_or_create_control_behavior()
        if not meter.behavior then meter.behavior = {} end
        return meter.behavior
    end
    function meter.get_circuit_network() return nil end
    function meter.get_wire_connector()
        return {connect_to=function() connections = connections + 1 end}
    end
    function meter.destroy()
        destructions = destructions + 1
        meter.valid = false
    end
    meters[#meters+1] = meter
    return meter
end

local valid_meters_at = function(x)
    local n = 0
    for _, meter in ipairs(meters) do
        if meter.valid and meter.position.x == x then n = n+1 end
    end
    return n
end

local mk1_name, mk2_name = 'power-combinator', 'power-combinator-MK2'
placed[1] = new_combinator(11, mk1_name, surface)
placed[2] = new_combinator(12, mk2_name, surface)
game = {tick=500, surfaces={[1]=surface}}
storage = {state={}, registrations={}}
local reg = 0
script = {register_on_object_destroyed=function()
    reg = reg + 1
    return reg
end}

local slots = require 'circuit_slots'
local lifecycle = require 'combinator_state'
local names = {mk1_name, mk2_name}
local allowed = {[mk1_name]=true,[mk2_name]=true}
local filters = {[mk2_name]=true}

lifecycle.rebuild(names, allowed, filters)
eq(creations, 4, 'first init creates two meters per placed combinator')
eq(valid_meters_at(11), 2, 'MK1 has both meters')
eq(valid_meters_at(12), 2, 'MK2 has both meters')
local mk1_control = storage.state[11].control
local mk2_control = storage.state[12].control
eq(slots.apply_factor(mk1_control, 5), true, 'MK1 factor update')
eq(slots.apply_factor(mk2_control, 6), true, 'MK2 factor update')
mk2_control.sections[1].set_slot(6, {
    value={type='item',name='radar',quality='normal',comparator='='}, min=3,
})
-- A configuration migration/branch upgrade must preserve existing entity settings.
lifecycle.rebuild(names, allowed, filters)
eq(creations, 4, 'existing hidden meters are reused, not duplicated')
eq(valid_meters_at(11), 2, 'MK1 meter count after migration')
eq(valid_meters_at(12), 2, 'MK2 meter count after migration')
eq(storage.state[11].control, mk1_control, 'MK1 control behavior persists')
eq(storage.state[12].control, mk2_control, 'MK2 control behavior persists')
eq(slots.get(mk1_control, 1).min, 5, 'MK1 factor X5 preserved')
eq(slots.get(mk2_control, 1).min, 6, 'MK2 factor X6 preserved')
eq(slots.get(mk2_control, 6).value.name, 'radar', 'MK2 item signal retained')
eq(factors[11], 5, 'MK1 ALT factor follows preserved X5')
eq(factors[12], 6, 'MK2 ALT factor follows preserved X6')
eq(storage.registrations[3], 11, 'MK1 gets new destruction registration')
eq(storage.registrations[4], 12, 'MK2 gets new destruction registration')
lifecycle.cleanup_registration(1)
eq(storage.state[11] ~= nil, true, 'old registration cannot remove restored MK1')
lifecycle.cleanup_registration(3)
eq(storage.state[11], nil, 'new MK1 registration cleans up its state')
eq(valid_meters_at(11), 0, 'only MK1 sensors destroyed')
eq(valid_meters_at(12), 2, 'MK2 sensors remain intact')
eq(removed_alt[11], true, 'MK1 ALT label removed')

-- If the second hidden meter cannot be created, the first must not remain orphaned.
local failed = new_combinator(13, mk2_name, surface)
surface.fail_satisfaction = true
lifecycle.allocate(failed, allowed, filters)
eq(storage.state[13], nil, 'failed allocation creates no active state')
eq(valid_meters_at(13), 0, 'partial hidden-meter allocation is cleaned up')

print('EC_MODULAR_MIGRATION_LUA_TEST=PASS')
