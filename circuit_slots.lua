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

-- Storage signals are appended to the existing FIRST logistic section.
-- Slots 1..5 remain power signals; MK2 feedback occupies slots 6..(5+N),
-- followed by two storage signals. No additional [Unassigned group] appears.
local STORAGE_ENERGY = {type="virtual", quality="normal", comparator="=",
    name="power-accumulator-energy"}
local STORAGE_CAPACITY = {type="virtual", quality="normal", comparator="=",
    name="power-accumulator-capacity"}

local function is_storage_slot(slot)
    local name = slot and slot.value and slot.value.name
    return name == STORAGE_ENERGY.name or name == STORAGE_CAPACITY.name
end

-- Remove the previous storage tail before any feedback update. Its exact
-- indices change whenever a MK2 adds/removes a building filter.
local function clear_storage_tail(control)
    if control.sections_count == 0 then return end
    local section = control.sections[1]
    for i = section.filters_count, IDX, -1 do
        if is_storage_slot(section.get_slot(i)) then
            section.clear_slot(i)
        end
    end
end

local function clear_legacy_storage_sections(control)
    -- Old ECMOD24 saves had a second section with the two battery signals.
    -- Migrate their outputs into section 1. Preserve unrelated user sections.
    for i = control.sections_count, 2, -1 do
        local section = control.sections[i]
        if section and section.is_manual then
            local had_storage, has_other = false, false
            for j = section.filters_count, 1, -1 do
                if is_storage_slot(section.get_slot(j)) then
                    had_storage = true
                    section.clear_slot(j)
                else
                    local slot = section.get_slot(j)
                    if slot and slot.value then has_other = true end
                end
            end
            if had_storage and not has_other and section.group == "" then
                control.remove_section(i)
            end
        end
    end
end

function M.write_storage(control, stored_joules, capacity_joules)
    if control.sections_count == 0 then control.add_section() end
    clear_storage_tail(control)
    clear_legacy_storage_sections(control)
    local section = control.sections[1]
    -- Append after feedback rather than reserving slots 38/39, which would
    -- leave 32 empty slots in MK1 or a lightly filtered MK2.
    -- The MK2 legacy contract reserves feedback slots 6..10: those must
    -- be empty whenever the circuit wire is unplugged or manual ALL is
    -- selected. Keep battery outputs in the SAME first section but place
    -- them no earlier than slot 11; with >5 filters they follow the feedback.
    local is_mk2 = control.entity and
        control.entity.name:find("MK2", 1, true) ~= nil
    local first = math.max(is_mk2 and IDX + 5 or IDX,
        section.filters_count + 1)
    section.set_slot(first, {value=STORAGE_ENERGY, min=stored_joules})
    section.set_slot(first + 1, {value=STORAGE_CAPACITY, min=capacity_joules})
    return true
end

function M.read_storage(control, name)
    if not control or not control.valid then return nil end
    for i = 1, control.sections_count do
        local section = control.sections[i]
        for slot = 1, section.filters_count do
            local filter = section.get_slot(slot)
            if filter and filter.value and filter.value.name == name then
                return filter.min or 0
            end
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
    clear_storage_tail(control)
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
    clear_storage_tail(control)
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
    local candidate_signals = {}
    for _, candidate in ipairs(signals) do
        if candidate.signal and candidate.signal.name and
            candidate.signal.type ~= "virtual" then
            candidate_signals[#candidate_signals+1] = candidate
        end
    end
    local max_index = math.max(section.filters_count + 1, #candidate_signals + IDX)
    local prev_outputs = {}
    for i = 1, max_index - IDX do
        local index = IDX + i - 1
        local prev_signal = get_signal(control, index)
        if prev_signal and prev_signal.value then
            prev_outputs[prev_signal.value.name] = prev_signal.min
        end
        local received = candidate_signals[i]
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
    clear_storage_tail(control)
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
