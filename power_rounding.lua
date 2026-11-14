-- Pure rounding helper for electricity signals.
-- Maximum production is estimated from prototype per-tick energy values.
-- Multiplication by 60 and decimal scaling may yield e.g. 7.999999999999999
-- for a mathematically exact 8 signal points.
local M = {}

function M.floor_maximum_production(value)
    local down = math.floor(value)
    local remainder = (down + 1) - value
    -- Accept only numerical noise near the next integer (never ordinary fractions).
    -- The tolerance is capped at one millionth of a signal point.
    local tolerance = math.min(1e-6, math.max(1e-9, math.abs(value) * 1e-12))
    if remainder > 0 and remainder <= tolerance then
        return down + 1
    end
    return down
end

-- A positive demand smaller than 1 signal point still requires 1 after scaling.
-- Do not truncate to eight decimal places before calling ceil: for X=15,
-- 1 MW is 1e-9 signal points, which would otherwise become zero.
function M.ceil_maximum_consumption(value)
    -- An exact prototype load (e.g. 1 MW) may become 100.00000000000001
    -- signal points after converting from Joules/tick and applying scaling.
    -- Snap only the numerical noise immediately ABOVE a positive whole number.
    -- Do not suppress tiny positive demands below one point: X=15 must give 1.
    local down = math.floor(value)
    if down > 0 then
        local noise = value - down
        local tolerance = math.min(1e-7, math.abs(value) * 1e-13)
        if noise <= tolerance then return down end
    end
    return math.ceil(value)
end

-- All four circuit output slots can independently select a rounding strategy.
-- For maxima, the existing precision-aware helpers avoid floating-point noise
-- turning mathematically exact integers into off-by-one signal counts.
function M.round_signal(value, mode)
    if mode == "up" then
        if value < 0 then
            return -M.floor_maximum_production(-value)
        end
        return M.ceil_maximum_consumption(value)
    elseif mode == "down" then
        return M.floor_maximum_production(value)
    end
    -- Round to the nearest integer, with exact halves away from zero.
    -- Per-tick prototype energy * 60 * 10^-X can turn an exact 7.5 into
    -- 7.499999999999999 (e.g. 750 kW at X=5). That tiny binary error must
    -- not turn the mathematically rounded signal 8 into 7.
    -- Only values within a tightly bounded tolerance of a half boundary
    -- are snapped; real fractions such as 7.49999 still round down.
    local magnitude = math.abs(value)
    local whole = math.floor(magnitude)
    local fractional = magnitude - whole
    local tolerance = math.min(1e-9, math.max(1e-12, magnitude * 1e-13))
    local rounded = whole + ((fractional >= 0.5 or
        0.5 - fractional <= tolerance) and 1 or 0)
    return value < 0 and -rounded or rounded
end

return M
