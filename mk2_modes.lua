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


-- Blueprint/copy-paste payload contains only validated primitive values.
-- Never persist a LuaEntity, unit number, GUI element, or prototype in tags.
function M.export(id)
    if not id then return nil end
    local config = M.ensure(id)
    local saved = {version=1, mode=config.mode, filters={}}
    for _, name in ipairs(config.filters) do
        if valid_energy(name) and #saved.filters < MAX_FILTERS then
            saved.filters[#saved.filters+1] = name
        end
    end
    return saved
end

function M.import(id, saved)
    if not id or type(saved) ~= 'table' or saved.version ~= 1
        or not VALID[saved.mode] or type(saved.filters) ~= 'table' then
        return false
    end
    local config = {mode=saved.mode, filters={}}
    for _, name in pairs(saved.filters) do
        if valid_energy(name) and #config.filters < MAX_FILTERS then
            local duplicate = false
            for _, value in ipairs(config.filters) do
                if value == name then duplicate = true; break end
            end
            if not duplicate then config.filters[#config.filters+1] = name end
        end
    end
    table.sort(config.filters)
    store()[id] = config
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
