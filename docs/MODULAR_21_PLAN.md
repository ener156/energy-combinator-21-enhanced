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
- **Native Factorio 2.1.24 on HAUSE1 confirmed:** ECMOD5 [run 43612941228](https://github.com/ener156/Respberry-Windows-Runner/actions/runs/43612941228) tested source `1192e1facbc95d8f5e287d306d637700f9df319f` and logged `ECMOD5_NATIVE_FACTORIO_FILTER_QA=PASS`, `Test passed at tick 561`, and `WINDOWS_SYSTEM_SCRIPT_RC=0`. ECMOD4 [run 43610164077](https://github.com/ener156/Respberry-Windows-Runner/actions/runs/43610164077) failed exclusively during a mistaken preflight owner-file check, now corrected; ECMOD3 [run 43607849131](https://github.com/ener156/Respberry-Windows-Runner/actions/runs/43607849131) passed the earlier source stage.
- **Newest functional source native PASS:** ECMOD6 [run 43615139125](https://github.com/ener156/Respberry-Windows-Runner/actions/runs/43615139125), pinned source `3a612ccea9cb8e31f19ec6abbda10f2ffe9d6c13`, completed successfully with `ECMOD6_NATIVE_FACTORIO_FILTER_SENSOR_QA=PASS`, `Test passed at tick 596`, `WINDOWS_SYSTEM_SCRIPT_RC=0`. Cases: radar, solar, both, none, filter restoration, disabled/re-enabled MK2, MK1 meter-pair creation, retaining its X5 factor, removing MK1 and verifying only its hidden meters were removed while the MK2 meters stayed. This verifies normal sensor lifecycle, **not** deliberate failure of one hidden-meter creation in the live engine (the partial-failure branch is mock-tested only).
- **Test ZIP staged and verified:** Native-tested ECMOD6 ZIP (42 entries, 151,329 bytes), SHA-256 `DD84B8C8BF4E1AF79D4E6046B54487728679F36BF2DA71F50636DDD03A5B6516`, saved separately as `F:\Downloads\Energy-Combinator-Modular-Test\energy-combinator-21-enhanced_1.2.14.zip` with `TEST_INFO.txt`. The self-hosted [staging run 43616266713](https://github.com/ener156/Respberry-Windows-Runner/actions/runs/43616266713) logged `ECMOD6_STAGE_VERIFIED=PASS`, the candidate checksum and `ECMOD6_STAGE_STABLE_SHA256=6A818F1E078C3687399D25D9581F1D2F8082C6774A3D03304F99C29DBE00AD32`, followed by `WINDOWS_SYSTEM_SCRIPT_RC=0`. The original 1.2.14 archive, installed mod directory and all saves were unchanged. The staged archive has the same internal mod name/version as stable 1.2.14; use **only as a separate manual test**, never alongside the stable ZIP in one mod directory. This does not establish real saved-game migration.
- **Native user-save load/migration QA:** User-provided `wd.zip` (SHA-256 `ECB59AAAA8D94430DD13FE37DBFEB9BA56FF2F807E6E5A1836E99AE76BEC6995`, 11,638,137 bytes, 86 valid ZIP entries) contains `energy-combinator-21-enhanced` **1.2.4** in serialized `script.dat`, not 1.2.14. It was confirmed byte-identical at the HAUSE1 save path. [ECMOD-WD native run 43620291249](https://github.com/ener156/Respberry-Windows-Runner/actions/runs/43620291249), job 132524256028, copied 208 enabled mod archives into a fresh isolated temp mod directory, used only the staged modular 1.2.14 ZIP, and loaded a verified copy of the exact save. Native Factorio log: `Loading mod energy-combinator-21-enhanced 1.2.14`, `ECMOD_WD_NATIVE|TOTAL=2|MK1=2|MK2=0|MISSING_SENSOR_PAIRS=0|INVALID_FACTOR_SLOTS=0|FIRST_FACTOR=3`, `ECMOD_WD_NATIVE_MIGRATION=PASS`, `Test passed at tick 1343319`, exit 0; temp work removed and original save/mod directory unchanged. **Scope:** existing 1.2.4 MK1 combinators load under modular code with valid factor slots and paired sensors. The fixture has **no placed MK2**, so persistence of saved MK2 filters is not covered. Also not covered: write-back/reload of migrated save, a dedicated 1.2.14-to-modular saved fixture, visual GUI/ALT acceptance and multiplayer.
- Modular architecture and current-source filter/sensor runtime QA now have native evidence, including the above limited user-save load. Preserve save and GUI semantics before final approval.

## Compatibility invariants

1. Retain existing prototype names, slot layout, GUI and shortcut, saved scaling factor, MK2 feedback and map-wide rounding settings.
2. Preserve MK1's local `flow_last_tick.total_transfer * 60` measurement and legacy/global-network fallback.
3. Preserve MK2's building filters and correct cumulative-statistics rebasing on a filter change.
4. Reuse existing 1.2.14 GUI, rounding and ALT behavior without another writer.
5. Never change installed ZIPs, user saves or the Factorio Mod Portal during modular development.

## Candidate Factorio 2.1 API improvements (not yet enabled)

`LuaFlowStatistics.get_current_input_sample(id)` and `.get_current_output_sample(id)` return samples for the **current tick**, not an average of a configured five-tick update interval. Evaluate against cumulative deltas for radar, solar, accumulators, shortages, mixed filters, filter transitions and saves before replacing MK2. New quality-specific statistics require explicit quality/normalization semantics. `LuaElectricNetwork` and `LuaElectricSubNetwork` are available for more precise network introspection. See https://lua-api.factorio.com/latest/classes/LuaFlowStatistics.html.

## Gates for follow-on work

1. Static inspection and 5/5 local Lua 5.3 mock tests plus 13/13 syntax/GitHub SHA verifications PASS. Current-source native Factorio filter/sensor regression ECMOD6 PASS; broader native migration/GUI/multiplayer gate remains OPEN.
2. Isolated Windows-System/HAUSE1 Factorio 2.1.24 tests comparing original 1.2.14 and modular source for MK1/MK2, all filter transitions, disable/re-enable behavior, and X5 rounding.
3. Native 1.2.4 user-save MK1 load/migration PASS (two existing MK1, no existing MK2). Remaining: migration of actual existing MK2 filters, re-save/re-load persistence, 1.2.14 fixture, blueprint/paste, GUI/ALT and multiplayer acceptance.
4. User in-game acceptance, compatibility and multiplayer/platform tests before any installation, merge or release.
