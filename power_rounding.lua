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

return M
