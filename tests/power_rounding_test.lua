-- Run from the repository root: lua tests/power_rounding_test.lua
package.path = "./?.lua;" .. package.path
local rounding = require "power_rounding"

local function check(name, input, expected)
    local actual = rounding.floor_maximum_production(input)
    assert(actual == expected,
        string.format("%s: input=%.17g; expected=%d; actual=%d", name, input, expected, actual))
    print("ROUNDING_PASS|" .. name)
end

check("exact-800kw-x5", 800000 * 10^-5, 8)
check("floating-800kw-x5", 7.999999999999999, 8)
check("exact-800kw-x4", 800000 * 10^-4, 80)
check("exact-800kw-x6", 800000 * 10^-6, 0)
check("fraction-799.9kw-x5", 7.999, 7)
check("fraction-799.999kw-x5", 7.99999, 7)
check("fraction-750kw-x5", 7.5, 7)
check("480kw-x5", 480000 * 10^-5, 4)
check("60kw-x5", 60000 * 10^-5, 0)
check("25555w-x5", 25555 * 10^-5, 0)
check("other-boundary", 0.9999999999999999, 1)
check("zero", 0, 0)
print("EC126_ROUNDING_REGRESSION=PASS")
