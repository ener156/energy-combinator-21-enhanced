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

local function max_consumption(name)
    if name == 'power-combinator-meter-satisfaction' then return 0 end -- remove meter lamp from max consumption
    local prototype = prototypes.entity[name]
    if not prototype then return 0 end
    local source = prototype.electric_energy_source_prototype or {}
    local usage  = prototype.get_max_energy_usage() or 0
    local drain  = source.drain or 0
    return usage + drain
end

local function max_production(name)
    local  prototype = prototypes.entity[name]
    return prototype and prototype.get_max_energy_production() or 0
end

---@param statistic LuaFlowStatistics
---@param name string
---@param category "'input'" | "'output'" | "'storage'"
local function statistic_value(statistic, name, category)
    return statistic.get_flow_count{
        precision_index = PRECISION_INDEX,
        category = category,
        count = true,
        name  = name,
    }
end

---@param statistic LuaFlowStatistics
---@param category "'input'" | "'output'" | "'storage'"
---@param filters string[] | nil
---@return integer
---@return integer
---@return table<string,integer>
local function sum_stats(statistic, category, filters)
    local is_input = category == "input"
    local sum, maxs, counts = 0, 0, {}
    local f      = is_input and max_consumption or max_production
    local values = is_input and statistic.input_counts or statistic.output_counts
    if filters then
        local filtered = {}
        for _, filter in pairs(filters) do
            filtered[filter] = values[filter]
        end
        values = filtered
    end
    for name, value in pairs(values) do
        if not is_buggy(name) then
            local count = statistic_value(statistic, name, category)
            counts[name] = (counts[name] or 0) + count
            maxs = maxs + count * f(name)
            sum  = sum  + value
        end
    end
    return sum, maxs, counts
end

---@param statistics table<integer,LuaFlowStatistics>
---@param satisfaction table<integer,number>
---@param filters string[] | nil
local function calculate_values(statistics, satisfaction, filters)
    local input, output, maxin, maxout, count = 0, 0, 0, 0, {}
    for electric_network_id, statistic in pairs(statistics) do
        if satisfaction[electric_network_id] then
             input, maxin , count = add( input, maxin , count, sum_stats(statistic, "input" , filters))
            output, maxout, count = add(output, maxout, count, sum_stats(statistic, "output", filters))
        end
    end
    return input, output, maxin, maxout, count
end

---@param net LuaEntity
---@param sat LuaEntity
---@param filters string[] | nil
local function collect_electric_statistics(net, sat, filters)
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
                return calculate_values({[1] = global_stats}, {[1] = ratio}, filters)
            end
        end
    end
    return calculate_values(statistics, satisfaction, filters)
end

M.collect = collect_electric_statistics

return M
