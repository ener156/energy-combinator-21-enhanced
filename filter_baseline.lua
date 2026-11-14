--- Owns the MK2 filter-change baseline for cumulative flow statistics.
--- A changed selection must never be compared against the previous selection.
local M = {}

function M.rebase_if_changed(state, filters, input, output)
    if filters == nil then return false end -- MK1 has no filter signature
    local sorted_filters = {table.unpack(filters)}
    table.sort(sorted_filters)
    local signature = table.concat(sorted_filters, "\n")
    if state.filter_signature == signature then return false end
    state.filter_signature = signature
    state.input, state.output = input, output
    return true
end

return M
