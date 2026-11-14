# Energy Combinator 2.1: modular development branch

Source baseline: `main` version 1.2.14, commit `cd1ed627a6f5ba4e4bc871b7407e6d4fe09cc7cb`.

Scope: isolated development. Do not install, publish, or merge until native Factorio QA and user in-game acceptance.

## Current ownership (stage 4 + targeted bugfixes)

- `control.lua`: only event registration, update scheduling, lifecycle/GUI dispatch, plus per-tick orchestration; has no direct power measurement or circuit slot writer.
- `power_meter.lua`: **single owner of power-measurement computation**, cumulative input/output comparison, Factorio statistics/direct fallbacks, scaling, rounding, physical GUI snapshot, and diagnostics; discards `state.input`, `state.output` and `state.filter_signature` baselines and advances `state.tick` when disabled, so the first enabled MK2/fallback sample cannot average an inactive interval. Delegates all native circuit slot writes to `circuit_slots.lua`.
- `electric_statistics.lua`: cumulative network statistics, filtered prototype counts and maximum power estimates.
- `electric_direct.lua`: direct local-network power measurement for MK1.
- `filter_baseline.lua`: MK2 cumulative statistics baseline reset when the effective filter selection changes.
- `mk2_filters.lua`: MK2 item-signal-to-energy-prototype selection with feedback compensation; **read-only** for circuit slots.
- `circuit_slots.lua`: **sole writer for all native combinator slots** (factor X in slot 1, four power outputs in slots 2-5, MK2 feedback in slots 6+); initializes default slots and handles GUI factor updates.
- `meter_sensors.lua`: single owner for hidden meter lookup/creation, circuit wire attachment, sensor-status lamp and disposal.
- `combinator_state.lua`: active combinator allocation/cleanup, persistent registration mapping, existing-entity reconstruction and delegation to sensor/circuit/ALT modules. If either hidden meter cannot be obtained, `meter_sensors.dispose` cleans up any partially created meter before abandoning the state.
- `power_rounding.lua`: rounding and half-boundary handling; must preserve X5 750 kW -> 8 nearest.
- `power_units.lua`: display unit conversions and factor labels.
- `energy_gui.lua`: overview, settings and diagnostics presentation; reads circuit slots, never writes measured signals.
- `alt_units.lua`: one ALT label per active combinator.

## Source and test evidence

- Branch source checkpoint: `main` 1.2.14 remains untouched; modular branch only.
- `control.lua` is now 160 lines vs. original 668 lines; Factorio 2.1 GUI, four rounding modes, ALT code and factor mapping are unchanged.
- GitHub source readback and static owner/code-reference checks passed for this extraction. These checks **do not** establish Factorio runtime correctness.
- Five Lua-only regression tests executed locally with `texlua` (Lua 5.3): measurement, circuit, lifecycle, power_meter, migration — **5/5 PASS**. All eight owner modules and five test files passed Lua `loadfile` syntax verification, and **13/13 GitHub blob SHA comparisons matched**. The added `tests/modular_migration_test.lua` uses the actual `circuit_slots.lua` and `combinator_state.lua` owners with mocked Factorio interfaces: existing MK1 X5 / MK2 X6 and item slot 6 persist through `rebuild`, hidden sensors are reused, stale registrations do not remove reconstructed states, cleanup affects only the removed combinator, and failure to create the second hidden meter removes the first. This verifies the algorithm in mocked Lua **not** a real Factorio save migration. New blobs: `combinator_state.lua` `696ec4053035d90c3f1e40af4adce8dfe2d38540`; `tests/modular_migration_test.lua` `5f7f51481123c7ab6d438a56e5aa2805e322d7b1`.
- Corrected native QA is `ECMOD5-QA-20261114-6C2E84F1`, submitted to the self-hosted Windows-System runner at request commit `82d68e751452108e883ee226095ed75a021b0354`, pinned script `ener156/Scripts@c836542202a390a6d774f02981728df1a55d3616`, pinned functional mod source `1192e1facbc95d8f5e287d306d637700f9df319f`. Tests existing radar/solar/multiple/empty filter sequence and disables/re-enables the MK2 via the Factorio `LuaConstantCombinatorControlBehavior.enabled` property. Uses only an isolated temporary mods directory. **No run ID or Factorio result verified.** Previous stage-4 script tested `meter_sensors.connect` against `control.lua` instead of its actual owner `power_meter.lua`, making its preflight check invalid; stage-5 script corrects this. Stage-3 and stage-4 requests are superseded as test candidates, not counted as a PASS.
- Architecture implementation is now ready for native review. Avoid further arbitrary extraction until Factorio 2.1.24 run evidence is available. Preserve native save and GUI semantics.

## Compatibility invariants

1. Retain existing prototype names, slot layout, GUI and shortcut, saved scaling factor, MK2 feedback and map-wide rounding settings.
2. Preserve MK1's local `flow_last_tick.total_transfer * 60` measurement and legacy/global-network fallback.
3. Preserve MK2's building filters and correct cumulative-statistics rebasing on a filter change.
4. Reuse existing 1.2.14 GUI, rounding and ALT behavior without another writer.
5. Never change installed ZIPs, user saves or the Factorio Mod Portal during modular development.

## Candidate Factorio 2.1 API improvements (not yet enabled)

`LuaFlowStatistics.get_current_input_sample(id)` and `.get_current_output_sample(id)` return samples for the **current tick**, not an average of a configured five-tick update interval. Evaluate against cumulative deltas for radar, solar, accumulators, shortages, mixed filters, filter transitions and saves before replacing MK2. New quality-specific statistics require explicit quality/normalization semantics. `LuaElectricNetwork` and `LuaElectricSubNetwork` are available for more precise network introspection. See https://lua-api.factorio.com/latest/classes/LuaFlowStatistics.html.

## Gates for follow-on work

1. Static inspection and 5/5 local Lua 5.3 mock tests plus 13/13 syntax/GitHub SHA verifications PASS. Native Factorio 2.1.24 QA remains OPEN.
2. Isolated Windows-System/HAUSE1 Factorio 2.1.24 tests comparing original 1.2.14 and modular source for MK1/MK2, all filter transitions, disable/re-enable behavior, and X5 rounding.
3. Native placed-save migration still OPEN despite local mocked rebuild PASS; blueprint/paste persistence, GUI clicks, ALT text, circuit feedback, mixed filters and direct meter diagnostics remain OPEN.
4. User in-game acceptance, compatibility and multiplayer/platform tests before any installation, merge or release.
