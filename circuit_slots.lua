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
        -- Restore ALL native filter slots from a placed blueprint, including
        -- Factorio-parameterised entity signals. Previously only slot 6 was
        -- retained, destroying edited parameters in slots 7+ on construction.
        local section = control.sections[1]
        for index = IDX, section.filters_count do
            local saved = section.get_slot(index)
            if saved and saved.value then
                saved.index = index
                parameters[index] = saved
            end
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

-- Storage signals live in a dedicated logistic section, not fixed slots 6+
-- in section 1: MK2 uses those slots for up to 32 native filter-feedback items.
local STORAGE_ENERGY = {type="virtual", quality="normal", comparator="=",
    name="power-accumulator-energy"}
local STORAGE_CAPACITY = {type="virtual", quality="normal", comparator="=",
    name="power-accumulator-capacity"}

local function storage_section(control, create)
    -- Search by unique signal identity so native blueprints and user-added
    -- sections can reorder the sections without losing the storage outputs.
    for i = 2, control.sections_count do
        local section = control.sections[i]
        for slot = 1, math.min(section.filters_count, 2) do
            local filter = section.get_slot(slot)
            local name = filter and filter.value and filter.value.name
            if name == STORAGE_ENERGY.name or name == STORAGE_CAPACITY.name then
                return section
            end
        end
    end
    if create then return control.add_section() end
    return nil
end

function M.write_storage(control, stored_joules, capacity_joules)
    local section = storage_section(control, true)
    if not section then return false end
    section.set_slot(1, {value=STORAGE_ENERGY, min=stored_joules})
    section.set_slot(2, {value=STORAGE_CAPACITY, min=capacity_joules})
    return true
end

function M.read_storage(control, name)
    if not control or not control.valid then return nil end
    local section = storage_section(control, false)
    if not section then return nil end
    for i = 1, 2 do
        local filter = section.get_slot(i)
        if filter and filter.value and filter.value.name == name then
            return filter.min or 0
        end
    end
    return nil
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
local function clear_filter_counts(state)
    local control = state.control
    local section = control.sections[1]
    if section then
        for i = IDX, section.filters_count do
            set_signal(control, i, nil)
        end
    end
    -- Feedback must not survive loss of the electric network or circuit wires.
    -- Clearing the history also avoids interpreting the old feedback as inputs
    -- after the network is reconnected.
    state.prev_outputs = {}
end

---@param state ECombState
---@param counts table<string,integer>
---@param electric_connected boolean|nil
function M.write_filter_counts(state, counts, electric_connected)
    local control = state.control
    -- A constant combinator can still report its own output signals even after
    -- the external red/green wire is unplugged. Do not use get_signals() alone
    -- to decide whether filter feedback may remain in native output slots.
    if electric_connected == false or
        (not control.get_circuit_network(defines.wire_connector_id.circuit_red) and
         not control.get_circuit_network(defines.wire_connector_id.circuit_green)) then
        return clear_filter_counts(state)
    end
    local signals = control.entity.get_signals(defines.wire_connector_id.circuit_red,
        defines.wire_connector_id.circuit_green)
    if signals == nil then
        return clear_filter_counts(state)
    end
    local section = control.sections[1]
    local max_index = math.max(section.filters_count + 1, table_size(signals) + IDX)
    local prev_outputs = {}
    for i = 1, max_index - IDX do
        local index = IDX + i - 1
        local prev_signal = get_signal(control, index)
        if prev_signal and prev_signal.value then
            prev_outputs[prev_signal.value.name] = prev_signal.min
        end
        local received = signals[i]
        local feedback
        if received and received.signal and received.signal.name and
            received.signal.type ~= "virtual" then
            feedback = {value = {
                name = received.signal.name,
                type = received.signal.type or "item",
                quality = "normal", comparator = "="},
                min = counts[received.signal.name] or 0}
        end
        set_signal(control, index, feedback)
    end
    state.prev_outputs = prev_outputs
end


-- Manual filtering uses the same measured prototype counts as AUTO.
-- A missing cable does not suppress the native display. These output counts
-- are also tracked as own feedback so switching MANUAL->AUTO cannot interpret
-- the last manual output as an external filter input.
function M.write_manual_preview(state, names, counts, qualities)
    local control = state.control
    if control.sections_count == 0 then control.add_section() end
    local section = control.sections[1]
    local stop = math.max(section.filters_count, IDX + #names - 1)
    for index = IDX, stop do
        local name = names[index - IDX + 1]
        local preview
        if name then
            local count = counts and counts[name] or 0
            preview = {value={name=name, type="item",
                quality=(qualities and qualities[name]) or "normal",
                comparator="="}, min=count}
        end
        set_signal(control, index, preview)
    end
    local own = {}
    for _, name in ipairs(names) do
        own[name] = counts and counts[name] or 0
    end
    state.prev_outputs = own
end


-- Read, but never mutate, native filter identities supplied by a blueprint.
-- The Factorio parameter editor changes signal identities in these slots,
-- while mod-private blueprint tags retain their original values.
function M.read_manual_filter_names(control)
    local names = {}
    if not control or control.sections_count == 0 then return names end
    local section = control.sections[1]
    for index = IDX, section.filters_count do
        local filter = section.get_slot(index)
        local value = filter and filter.value
        if value and value.type == 'item' and type(value.name) == 'string' then
            local item = prototypes.item[value.name]
            local placed = item and item.place_result
            names[#names+1] = placed and placed.name or value.name
        end
    end
    return names
end

M.get = get_signal
M.ensure_factor = function(control) return default_signal(control, DEFAULT_F) end
M.factor_signal = F

return M
