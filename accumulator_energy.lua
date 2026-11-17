-- ECMOD24: physical battery energy in J (not power in W).
-- LuaElectricNetwork.get_accumulators_energy is quality-aware in Factorio 2.1.
-- This module only reads the network. It does not mutate accumulator energy.
local M = {}

local function accumulator(name)
    local entity = prototypes.entity[name]
    return entity and entity.type == "accumulator"
end

local function read_pair(network, options)
    local pair = network.get_accumulators_energy(options)
    if not pair then return 0, 0 end
    return pair.energy or 0, pair.capacity or 0
end

-- Returns energy and capacity in joules. nil filters = entire power grid.
-- A nonempty MK2 selection containing no accumulators intentionally reads 0,
-- rather than silently switching to unfiltered totals.
function M.collect(net, filters, qualities)
    if not net or not net.valid then return 0, 0 end
    local sub = net.electric_network
    local network = sub and sub.valid and sub.parent_network
    if not network or not network.valid then return 0, 0 end

    if filters == nil then
        return read_pair(network, {})
    end

    local total_energy, total_capacity = 0, 0
    local seen = {}
    for _, name in ipairs(filters) do
        if not seen[name] and accumulator(name) then
            seen[name] = true
            local options = {name=name}
            if qualities and qualities[name] then
                options.quality = qualities[name]
            end
            local energy, capacity = read_pair(network, options)
            total_energy = total_energy + energy
            total_capacity = total_capacity + capacity
        end
    end
    return total_energy, total_capacity
end

return M
