-- Single owner for the signal-factor -> displayed unit mapping.
-- The existing slot-1 power-factor remains the only authoritative factor.
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

function M.watts_text(watts)
    if type(watts) ~= "number" or watts ~= watts or math.abs(watts) == math.huge then
        return "—"
    end
    local abs_value = math.abs(watts)
    local group = 0
    while abs_value >= 1000 and group < #suffixes - 1 do
        abs_value = abs_value / 1000
        group = group + 1
    end
    local scaled = watts / (1000 ^ group)
    local places = abs_value < 10 and 2 or (abs_value < 100 and 1 or 0)
    -- UI only: do not round or modify actual circuit output signals.
    return string.format("%." .. places .. "f %s", scaled, suffixes[group + 1])
end

return M
