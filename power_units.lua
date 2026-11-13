-- Single owner for factor X to displayed signal-unit conversion.
-- Circuit output and rounding remain authoritative in control.lua.
local M = {}
local suffixes = {"W", "kW", "MW", "GW", "TW", "PW", "EW", "ZW", "YW"}

function M.factor_label(x)
    if type(x) ~= "number" or x ~= math.floor(x) then return "W" end
    local group = math.floor(x / 3)
    if group < 0 or group >= #suffixes then
        return "10^" .. tostring(x) .. " W"
    end
    local coefficient = 10 ^ (x % 3)
    local suffix = suffixes[group + 1]
    return coefficient == 1 and suffix or (tostring(coefficient) .. " " .. suffix)
end

-- Display the unrounded physical measurement strictly in the selected X units.
-- E.g. 13000 watts at X=6 -> "0.013 MW", at X=2 -> "130 × 100 W".
-- This only formats UI strings; no precision is removed from circuit outputs.
function M.watts_at_factor(watts, factor)
    if type(watts) ~= "number" or watts ~= watts or math.abs(watts) == math.huge then
        return "—"
    end
    if type(factor) ~= "number" or factor ~= math.floor(factor) then return "—" end
    local divisor = 10 ^ factor
    if divisor == 0 or divisor == math.huge then return "—" end
    local scaled = watts / divisor
    if scaled ~= scaled or math.abs(scaled) == math.huge then return "—" end
    local abs = math.abs(scaled)
    local value
    if (abs > 0 and abs < 0.000001) or abs >= 10000000 then
        value = string.format("%.6g", scaled)
    else
        value = string.format("%.6f", scaled)
        value = value:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    end
    local label = M.factor_label(factor)
    if factor % 3 == 0 then return value .. " " .. label end
    return value .. " × " .. label
end

return M
