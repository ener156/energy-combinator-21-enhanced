--- Electricity-statistics collection and prototype-based capacity estimates.
--- Single owner for cumulative statistics used by MK2 and fallback networks.
--- Extracted unchanged from Energy Combinator 1.2.14; no new API sampling yet.
local M = {}

local PRECISION_INDEX = defines.flow_precision_index["one_second"]   -- factorio <  1.1.25
                     or defines.flow_precision_index["five_seconds"] -- factorio >= 1.1.25

---Merge two tables and sum values with same keys
---@param tb1 table<any,number>
---@param tb2 table<any,number>
local function merge_number_tables(tb1, tb2)
    local tb = {}
    for key, value in pairs(tb1) do
        tb[key] = value
    end
    for key, value in pairs(tb2) do
        tb[key] = (tb[key] or 0) + value
    end
    return tb
end

---@param a integer
---@param b integer
---@param c table<string,integer>
---@param d integer
---@param e integer
---@param f table<string,integer>
---@return integer
---@return integer
---@return table<string,integer>
local function add(a, b, c, d, e, f) return a + d, b + e, merge_number_tables(c, f) end

local function is_buggy(name)
    local  prototype = prototypes.entity[name]
    return prototype
       and prototype.type == 'electric-energy-interface' -- buggy as hell
end

local function max_consumption(name, quality)
    if name == 'power-combinator-meter-satisfaction' then return 0 end -- remove meter lamp from max consumption
    local prototype = prototypes.entity[name]
    if not prototype then return 0 end
    local source = prototype.electric_energy_source_prototype or {}
    local usage  = prototype.get_max_energy_usage(quality) or 0
    local drain  = source.drain or 0
    return usage + drain
end

local function max_production(name, quality)
    local  prototype = prototypes.entity[name]
    return prototype and prototype.get_max_energy_production(quality) or 0
end

---@param statistic LuaFlowStatistics
---@param name string
---@param category "'input'" | "'output'" | "'storage'"
local function statistic_value(statistic, name, category, quality)
    -- A bare prototype name is *normal* quality only. The quality-specific
    -- ID is necessary for Factorio to count higher-quality entities.
    local id = quality == "normal" and name or {name=name, quality=quality}
    return statistic.get_flow_count{
        precision_index = PRECISION_INDEX,
        category = category,
        count = true,
        name  = id,
    }
end

---@param statistic LuaFlowStatistics
---@param category "'input'" | "'output'" | "'storage'"
---@param filters string[] | nil
---@return integer
---@return integer
---@return table<string,integer>
local function sum_stats(statistic, category, filters, qualities)
    local is_input = category == "input"
    local sum, maxs, counts = 0, 0, {}
    local capacity = is_input and max_consumption or max_production
    local normal_values = is_input and statistic.input_counts or statistic.output_counts
    local by_quality = is_input and statistic.input_quality_counts or statistic.output_quality_counts

    -- MK2 prototype filters apply to *all* qualities of the selected building.
    local allowed
    if filters then
        allowed = {}
        for _, name in pairs(filters) do allowed[name] = true end
    end

    local function accumulate(quality, values)
        for name, value in pairs(values or {}) do
            if (not allowed or allowed[name])
                and (not qualities or not qualities[name] or qualities[name] == quality)
                and not is_buggy(name) then
                local count = statistic_value(statistic, name, category, quality)
                counts[name] = (counts[name] or 0) + count
                maxs = maxs + count * capacity(name, quality)
                sum = sum + value
            end
        end
    end

    -- Prefer the explicit normal-quality bucket when available. Otherwise
    -- retain the legacy unqualified table; do not count normal twice.
    accumulate("normal", by_quality and by_quality.normal or normal_values)
    if by_quality then
        for quality, values in pairs(by_quality) do
            if quality ~= "normal" then accumulate(quality, values) end
        end
    end
    return sum, maxs, counts
end

---@param statistics table<integer,LuaFlowStatistics>
---@param satisfaction table<integer,number>
---@param filters string[] | nil
local function calculate_values(statistics, satisfaction, filters, qualities)
    local input, output, maxin, maxout, count = 0, 0, 0, 0, {}
    for electric_network_id, statistic in pairs(statistics) do
        if satisfaction[electric_network_id] then
             input, maxin , count = add( input, maxin , count, sum_stats(statistic, "input" , filters, qualities))
            output, maxout, count = add(output, maxout, count, sum_stats(statistic, "output", filters, qualities))
        end
    end
    return input, output, maxin, maxout, count
end

---@param net LuaEntity
---@param sat LuaEntity
---@param filters string[] | nil
local function collect_electric_statistics(net, sat, filters, qualities)
    local statistics, satisfaction = {}, {}
    if net and net.electric_network_id then
        statistics[net.electric_network_id] = net.electric_network_statistics
    end
    if sat and sat.electric_network_id and sat.electric_buffer_size and sat.electric_buffer_size > 0 then
        satisfaction[sat.electric_network_id] = sat.energy / sat.electric_buffer_size
    end
    if net and net.valid and net.surface.has_global_electric_network then
        local global_stats = net.surface.global_electric_network_statistics
        if global_stats and global_stats.valid then
            local ratio
            if sat and sat.valid and sat.electric_buffer_size and sat.electric_buffer_size > 0 then
                ratio = sat.energy / sat.electric_buffer_size
            end
            if ratio then
                return calculate_values({[1] = global_stats}, {[1] = ratio}, filters, qualities)
            end
        end
    end
    return calculate_values(statistics, satisfaction, filters, qualities)
end

M.collect = collect_electric_statistics

return M
