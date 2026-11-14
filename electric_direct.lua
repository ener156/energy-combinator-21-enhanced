--- Direct local-electric-network measurement for MK1.
--- Returns watts, or nil if the direct flow API cannot be used.
local M = {}

function M.read_watts(net, sat)
    if not (net and net.valid and sat and sat.valid) then return nil end
    if net.surface.has_global_electric_network then return nil end
    if net.electric_network_id == nil or net.electric_network_id ~= sat.electric_network_id then return nil end
    local sub = net.electric_network
    local parent = sub and sub.valid and sub.parent_network
    local transfer = parent and parent.valid and parent.flow_last_tick
    local watts = transfer and transfer.total_transfer and transfer.total_transfer * 60
    if watts and watts == watts and watts >= 0 and watts < math.huge then
        return watts
    end
    return nil
end

return M
