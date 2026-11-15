-- Persisted per-MK2 operation mode and selected manual prototype names.
-- Entity unit_number is the identity. Never store LuaGuiElement or LuaPrototype.
local M = {}

local VALID = {auto=true, all=true, manual=true}
local MAX_FILTERS = 32

local function store()
    storage.mk2_modes = storage.mk2_modes or {}
    return storage.mk2_modes
end

local function valid_energy(name)
    if type(name) ~= 'string' then return false end
    local prototype = prototypes.entity[name]
    if not prototype then return false end
    return (prototype.get_max_energy_usage() or 0) > 0
        or (prototype.get_max_energy_production() or 0) > 0
end

function M.ensure(id)
    if not id then return {mode='auto', filters={}} end
    local all = store()
    local result = all[id]
    if not result then
        result = {mode='auto', filters={}}
        all[id] = result
    end
    if not VALID[result.mode] then result.mode='auto' end
    if type(result.filters) ~= 'table' then result.filters={} end
    return result
end

function M.get(id)
    return M.ensure(id)
end

function M.set_mode(id, value)
    if not VALID[value] or not id then return false end
    M.ensure(id).mode = value
    return true
end

function M.add_filter(id, name)
    if not id or not valid_energy(name) then return false end
    local config = M.ensure(id)
    for _, existing in ipairs(config.filters) do
        if existing == name then return false end
    end
    if #config.filters >= MAX_FILTERS then return false end
    config.filters[#config.filters+1] = name
    table.sort(config.filters)
    return true
end

function M.remove_filter(id, name)
    if not id or type(name) ~= 'string' then return false end
    local config = M.ensure(id)
    for i, existing in ipairs(config.filters) do
        if existing == name then
            table.remove(config.filters, i)
            return true
        end
    end
    return false
end

-- A prototype can disappear after another mod is removed. Ignore stale
-- names rather than failing the entire combinator measurement.
function M.valid_manual_filters(id)
    local result = {}
    for _, name in ipairs(M.ensure(id).filters) do
        if valid_energy(name) then result[#result+1] = name end
    end
    return result
end


-- Portable, versioned MK2 data: only prototype names and primitive values.
-- Native blueprint signal slots are authoritative when Factorio's parameter
-- editor changes them. Mod tags are not modified by that editor.
local function validated_names(names)
    local clean, seen = {}, {}
    if type(names) ~= 'table' then return clean end
    for _, name in pairs(names) do
        if valid_energy(name) and not seen[name] and #clean < MAX_FILTERS then
            seen[name] = true
            clean[#clean+1] = name
        end
    end
    table.sort(clean)
    return clean
end

local function equal_names(a, b)
    local left = validated_names(a)
    local right = validated_names(b)
    if #left ~= #right then return false end
    for i, name in ipairs(left) do
        if name ~= right[i] then return false end
    end
    return true
end

-- source_slots captures the exact native filter signal identities at
-- blueprint creation. Factorio parameterization may replace those identities
-- without replacing custom tags.
function M.export(id, native_slots)
    if not id then return nil end
    local config = M.ensure(id)
    return {
        version=2,
        mode=config.mode,
        filters=validated_names(config.filters),
        source_slots=validated_names(native_slots),
    }
end

-- native_slots are read before the mod writes any new measurement output.
-- A difference against the original blueprint's slot identities means the
-- native parameter editor has changed (or deleted) the filter parameters.
-- For older v1 blueprints the saved filter names are the baseline.
function M.import(id, saved, native_slots)
    if not id or type(saved) ~= 'table' or
        (saved.version ~= 1 and saved.version ~= 2) or
        not VALID[saved.mode] or type(saved.filters) ~= 'table' then
        return false
    end
    local filters = validated_names(saved.filters)
    if saved.mode == 'manual' and native_slots ~= nil then
        local source = saved.version == 2 and saved.source_slots or saved.filters
        if type(source) == 'table' and not equal_names(native_slots, source) then
            filters = validated_names(native_slots)
        end
    end
    store()[id] = {mode=saved.mode, filters=filters}
    return true
end

function M.forget(id)
    if storage.mk2_modes then storage.mk2_modes[id] = nil end
end

function M.clone(source_id, destination_id)
    if not source_id or not destination_id then return end
    local old = M.ensure(source_id)
    local copy = {mode=old.mode, filters={}}
    for _, name in ipairs(old.filters) do
        copy.filters[#copy.filters+1] = name
    end
    store()[destination_id] = copy
end

M.max_filters = MAX_FILTERS
return M
