# Energy Combinator 2.1: modular development branch

Source baseline: `main` version 1.2.14, commit `cd1ed627a6f5ba4e4bc871b7407e6d4fe09cc7cb`.

Scope: isolated development. Do not install, publish, or merge until native Factorio QA and user in-game acceptance.

## Current ownership (stage 1)

- `control.lua`: Factorio event registrations, lifecycle, state assembly, circuit-signal writing and orchestration. It remains the **only physical signal writer** for slots 1-5.
- `electric_statistics.lua`: cumulative network statistics, filtered prototype counts and maximum power estimates.
- `electric_direct.lua`: direct local-network power measurement for MK1.
- `filter_baseline.lua`: MK2 cumulative statistics baseline reset when the effective filter selection changes.
- `power_rounding.lua`: rounding and half-boundary handling; must preserve X5 750 kW -> 8 nearest.
- `power_units.lua`: display unit conversions and factor labels.
- `energy_gui.lua`: overview, settings and diagnostics presentation; reads circuit slots, never writes measured signals.
- `alt_units.lua`: one ALT label per active combinator.

## Compatibility invariants

1. Retain existing prototype names, slot layout, GUI and shortcut, saved scaling factor, MK2 feedback and map-wide rounding settings.
2. Preserve MK1's local `flow_last_tick.total_transfer * 60` measurement and legacy/global-network fallback.
3. Preserve MK2's building filters and correct cumulative-statistics rebasing on a filter change.
4. Reuse existing 1.2.14 GUI, rounding and ALT behavior without another writer.
5. Never change installed ZIPs, user saves or the Factorio Mod Portal during modular development.

## Candidate Factorio 2.1 API improvements (not yet enabled)

`LuaFlowStatistics.get_current_input_sample(id)` and `.get_current_output_sample(id)` return samples for the **current tick**, not an average of a configured five-tick update interval. Evaluate against cumulative deltas for radar, solar, accumulators, shortages, mixed filters, filter transitions and saves before replacing MK2. New quality-specific statistics require explicit quality/normalization semantics. `LuaElectricNetwork` and `LuaElectricSubNetwork` are available for more precise network introspection. See https://lua-api.factorio.com/latest/classes/LuaFlowStatistics.html.

## Gates for follow-on work

1. Static source inspection and Lua syntax checks on new modules.
2. Isolated Windows-System/HAUSE1 Factorio 2.1.24 tests comparing original 1.2.14 and modular source for MK1/MK2, all filter transitions and X5 rounding.
3. Placed-save migration and blueprint/paste persistence, GUI clicks, ALT text, circuit feedback, mixed filters and direct meter diagnostics.
4. User in-game acceptance, compatibility and multiplayer/platform tests before any installation, merge or release.
