--- Owns the MK2 filter-change baseline for cumulative flow statistics.
--- A changed selection must never be compared against the previous selection.
local M = {}

function M.rebase_if_changed(state, filters, input, output, qualities)
    if filters == nil then return false end -- MK1 has no filter signature
    local sorted_filters = {table.unpack(filters)}
    table.sort(sorted_filters)
    local names = {}
    for _, name in ipairs(sorted_filters) do
        -- A quality change is a real filter change: rebase the cumulative
        -- statistics instead of subtracting counts for different selections.
        local quality = qualities and qualities[name]
        names[#names + 1] = quality and (name .. "@" .. quality) or name
    end
    local signature = table.concat(names, "\n")
    if state.filter_signature == signature then return false end
    state.filter_signature = signature
    state.input, state.output = input, output
    return true
end

return M
