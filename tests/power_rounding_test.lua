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
-- Maximum consumption must never lose positive demand at very high X.
local function ceil_check(name, input, expected)
    local actual = rounding.ceil_maximum_consumption(input)
    assert(actual == expected,
        string.format("%s: input=%.17g; expected=%d; actual=%d", name, input, expected, actual))
    print("ROUNDING_PASS|" .. name)
end

ceil_check("zero-demand", 0, 0)
ceil_check("1mw-x15", 1000000 * 10^-15, 1)
ceil_check("1mw-x14", 1000000 * 10^-14, 1)
ceil_check("1mw-x9", 1000000 * 10^-9, 1)
ceil_check("1mw-x6", 1000000 * 10^-6, 1)
ceil_check("1mw-x5", 1000000 * 10^-5, 10)
ceil_check("1mw-x4", 1000000 * 10^-4, 100)
ceil_check("1mw-x0", 1000000, 1000000)
ceil_check("tiny-positive", 1e-15, 1)
ceil_check("fraction-20.1", 20.1, 21)
ceil_check("integer-20", 20, 20)
check("production-800kw-x5-unchanged", 800000 * 10^-5, 8)
check("production-800kw-x6-unchanged", 800000 * 10^-6, 0)
print("EC127_ROUNDING_REGRESSION=PASS")
