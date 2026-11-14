-- Owns every write to the combinator's circuit section: factor and power
-- signals in slots 1..5, plus MK2 feedback in slots 6 and above.
-- Extracted from the 1.2.14-compatible modular development branch.
local M = {}

local I,O,F,C,P = table.unpack{
    {type="virtual", quality="normal", comparator="=", name="power-consumption"},
    {type="virtual", quality="normal", comparator="=", name="power-production"},
    {type="virtual", quality="normal", comparator="=", name="power-factor"},
    {type="virtual", quality="normal", comparator="=", name="power-max-consumption"},
    {type="virtual", quality="normal", comparator="=", name="power-max-production"},
}
local INT32_MAX = 2^31
local DEFAULT_F = {value=F, min=3, index=1}
local DEFAULTS  = {
    DEFAULT_F,
    {value=I, min=0, index=2},
    {value=O, min=0, index=3},
    {value=C, min=0, index=4},
    {value=P, min=0, index=5},
}

local IDX = 6 -- first MK2 filter feedback slot

--- Get signal at index from top section.
--- <br> Returns nil if no signal at given index.
---@param control LuaConstantCombinatorControlBehavior
---@param idx integer
---@return LogisticFilter
local function get_signal(control, idx)
    if control.sections_count == 0 then
        control.add_section()
    end
    local section = control.sections[1]
    return section.get_slot(idx)
end

---@param control LuaConstantCombinatorControlBehavior
---@param idx integer
---@param signal LogisticFilter | nil
local function set_signal(control, idx, signal)
    if control.sections_count == 0 then
        control.add_section()
    end

    local section = control.sections[1]
    if signal == nil then
        section.clear_slot(idx)
    else
        section.set_slot(idx, signal)
    end
end

---@param a SignalFilter
---@param b SignalFilter
---@return boolean
local function same_signal(a,b)
    return a.type == b.type and a.name == b.name
end

---@class LogisticFilterWithIndex : LogisticFilter
    ---@field index integer

---@param control LuaConstantCombinatorControlBehavior
---@param default LogisticFilterWithIndex
---@return LogisticFilter
local function default_signal(control, default)
    local signal = get_signal(control, default.index)
    if signal == nil or signal.value == nil then return default end
    if signal and same_signal(signal.value, default.value) then return signal end
    set_signal(control, default.index, default)
    return default
end

function M.initialize(control, is_mk2)
    local parameters = {table.unpack(DEFAULTS)}
    parameters[DEFAULT_F.index] = default_signal(control, DEFAULT_F)
    parameters[DEFAULT_F.index].index = DEFAULT_F.index
    if is_mk2 then
        local saved_filter = get_signal(control, IDX)
        if saved_filter then
            saved_filter.min = 0
            saved_filter.index = IDX
            parameters[IDX] = saved_filter
        end
    end
    if control.sections_count == 0 then control.add_section() end
    local section = control.sections[1]
    section.filters = parameters
end

function M.write_power(control, factor, input_diff, output_diff, maxin, maxout)
    set_signal(control, DEFAULT_F.index, {value=F, min=factor})
    set_signal(control, 2, {value=I, min=input_diff})
    set_signal(control, 3, {value=O, min=output_diff})
    set_signal(control, 4, {value=C, min=maxin})
    set_signal(control, 5, {value=P, min=maxout})
end

function M.apply_factor(control, factor)
    local section = control.sections[1]
    local slot = section.get_slot(DEFAULT_F.index)
    if not slot or not slot.value or slot.value.name ~= F.name then return false end
    slot.min = factor
    section.set_slot(DEFAULT_F.index, slot)
    return true
end

---@param state ECombState
---@param counts table<string,integer>
function M.write_filter_counts(state, counts)
    local control = state.control
    local signals = control.entity.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
        local signals_count = control.sections[1].filters_count
        local filters_index = 6
        if signals == nil then
            for i = filters_index, signals_count, 1 do set_signal(control, i, nil) end
            state.prev_outputs = {} -- reset feedback when all circuit inputs disappear
            return
        end
        local max_index = math.max(signals_count + 1, table_size(signals) + filters_index)
        local prev_outputs = {}
        ---@type LogisticFilter | nil
        local filter_signal
        for i = 1, max_index - filters_index, 1 do
            local prev_signal = get_signal(control, filters_index + i - 1)
            if prev_signal and prev_signal.value ~= nil then
                prev_outputs[prev_signal.value.name] = prev_signal.min
            end

            if signals[i] ~= nil and signals[i].signal.name ~= nil and signals[i].signal.type ~= "virtual" then
                filter_signal = {value={
                    name=signals[i].signal.name,
                    type=signals[i].signal.type or "item",
                    quality="normal", comparator="="}}
                filter_signal.min = counts[signals[i].signal.name] or 0 -- unreported entities have no energy flow
            else
                filter_signal = nil
            end
            set_signal(control, filters_index + i - 1, filter_signal)
        end
        state.prev_outputs = prev_outputs
end

M.get = get_signal
M.ensure_factor = function(control) return default_signal(control, DEFAULT_F) end
M.factor_signal = F

return M
