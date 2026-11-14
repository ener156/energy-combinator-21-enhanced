# Energy Combinator 2.1: modular development branch

Source baseline: `main` version 1.2.14, commit `cd1ed627a6f5ba4e4bc871b7407e6d4fe09cc7cb`.

Scope: isolated development. Do not install, publish, or merge until native Factorio QA and user in-game acceptance.

## Current ownership (stage 3)

- `control.lua`: event registration, measurement orchestration, diagnostics and final rounding; delegates sensor connections, state ownership and all circuit-slot writes.
- `electric_statistics.lua`: cumulative network statistics, filtered prototype counts and maximum power estimates.
- `electric_direct.lua`: direct local-network power measurement for MK1.
- `filter_baseline.lua`: MK2 cumulative statistics baseline reset when the effective filter selection changes.
- `mk2_filters.lua`: MK2 item-signal-to-energy-prototype selection with feedback compensation; **read-only** for circuit slots.
- `circuit_slots.lua`: **sole writer for all native combinator slots** (factor X in slot 1, four power outputs in slots 2-5, MK2 feedback in slots 6+); initializes default slots and handles GUI factor updates.
- `meter_sensors.lua`: single owner for hidden meter lookup/creation, circuit wire attachment, sensor-status lamp and disposal.
- `combinator_state.lua`: active combinator allocation/cleanup, persistent registration mapping, existing-entity reconstruction and delegation to sensor/circuit/ALT modules.
- `power_rounding.lua`: rounding and half-boundary handling; must preserve X5 750 kW -> 8 nearest.
- `power_units.lua`: display unit conversions and factor labels.
- `energy_gui.lua`: overview, settings and diagnostics presentation; reads circuit slots, never writes measured signals.
- `alt_units.lua`: one ALT label per active combinator.

## Source and test evidence

- Branch source checkpoint: `main` 1.2.14 remains untouched; modular branch only.
- `control.lua` is now 248 lines vs. original 668 lines; Factorio 2.1 GUI, four rounding modes, ALT code and factor mapping are unchanged.
- GitHub source readback and static owner/code-reference checks passed for this extraction. These checks **do not** establish Factorio runtime correctness.
- Lua-only tests committed in `tests/modular_measurement_test.lua`, `tests/modular_circuit_test.lua` and `tests/modular_lifecycle_test.lua`. All **three executed locally** with `texlua` (Lua 5.3) and printed their explicit `...=PASS` markers. All seven module files and all three test files passed `loadfile` syntax checks. Prior to executing, the ten local files were verified byte-for-byte by matching their Git blob hashes against GitHub. This is **local Lua-mock QA**, not a Factorio 2.1.24 / Lua 5.2 runtime, installed-mod, save migration or user in-game test. Do not mark native QA or user acceptance as PASS.
- Self-hosted Windows-System QA request: `ECMOD3-QA-20261114-7C6B39A1` in `ener156/Respberry-Windows-Runner@windows-desktop-exec`, pinned script `ener156/Scripts@34a3639f3456fad08d4824ba0657c3266c519773`. This is a submitted request only, **not** a verified QA result. The script uses an isolated temporary mod directory and the 1.2.14 baseline ZIP; no installed mod or personal save is modified.
- Next candidates: isolate measurement rounding/snapshot composition and GUI event orchestration only if this reduces ownership complexity. Preserve native Factorio save and GUI semantics.

## Compatibility invariants

1. Retain existing prototype names, slot layout, GUI and shortcut, saved scaling factor, MK2 feedback and map-wide rounding settings.
2. Preserve MK1's local `flow_last_tick.total_transfer * 60` measurement and legacy/global-network fallback.
3. Preserve MK2's building filters and correct cumulative-statistics rebasing on a filter change.
4. Reuse existing 1.2.14 GUI, rounding and ALT behavior without another writer.
5. Never change installed ZIPs, user saves or the Factorio Mod Portal during modular development.

## Candidate Factorio 2.1 API improvements (not yet enabled)

`LuaFlowStatistics.get_current_input_sample(id)` and `.get_current_output_sample(id)` return samples for the **current tick**, not an average of a configured five-tick update interval. Evaluate against cumulative deltas for radar, solar, accumulators, shortages, mixed filters, filter transitions and saves before replacing MK2. New quality-specific statistics require explicit quality/normalization semantics. `LuaElectricNetwork` and `LuaElectricSubNetwork` are available for more precise network introspection. See https://lua-api.factorio.com/latest/classes/LuaFlowStatistics.html.

## Gates for follow-on work

1. Static inspection and local Lua 5.3 mock/syntax tests PASS (Git-blob matched source). Re-execution on authorized self-hosted infrastructure and native Factorio 2.1.24 QA remain OPEN.
2. Isolated Windows-System/HAUSE1 Factorio 2.1.24 tests comparing original 1.2.14 and modular source for MK1/MK2, all filter transitions and X5 rounding.
3. Placed-save migration and blueprint/paste persistence, GUI clicks, ALT text, circuit feedback, mixed filters and direct meter diagnostics.
4. User in-game acceptance, compatibility and multiplayer/platform tests before any installation, merge or release.
