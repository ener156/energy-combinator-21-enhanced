# Energy Combinator 2.1 Enhanced

Independent, community-maintained Factorio 2.1 fork of **Energy Combinator** by **VinDust**, which itself is based on **Power Combinator** by **dodo.the.last**.

This mod reports electric network power statistics through the circuit network. Tier 1 exposes current consumption and production and their estimated maximum values, with a selectable scaling exponent. Tier 2 adds circuit-controlled entity filtering. Existing in-game prototype names are retained for compatibility with established layouts, but the internal mod ID is different.

Factorio 2.1 startup and runtime smoke tests have passed. Version 1.2.1 also addresses scaling persistence, circuit-filter feedback and Tips & Tricks integration. These tests do not establish full multiplayer, migrated-save or space-platform compatibility.

## Precision-safe nearest rounding (1.2.13 development)

Mathematical nearest rounding now treats binary floating-point noise near exact
half-integer boundaries correctly. For example, an estimated 750 kW at X=5
represents 7.5 signal points and rounds to 8 with the nearest mode even if
energy-per-tick conversion yields 7.499999999999998 internally. Real values
below the half boundary, such as 7.499999999, still round down. All up/down
rounding semantics, measured values and Tier 2 filters are unchanged. No
external circuit wire is required to measure power; the withdrawn 1.2.12 cable
experiment is not part of this candidate.

## Factor-aware overview and circuit outputs (1.2.11 development)

The Overview tab uses the selected **signal factor X** for its physical
measurement display, rather than switching units automatically: 13 kW
at X=6 is shown as **0.013 MW**, at X=3 as **13 kW**, and at X=2 as
**130 × 100 W**. Values are display-only and retain their unrounded
physical meaning. A native-style panel places the four power-signal
icons and unrounded measurements alongside each real **integer output**
read from the constant-combinator circuit slots (2–5).

Scaling remains authoritative in circuit slot 1; the GUI does not cache
independent output values or change energy usage. The native combinator
GUI remains accessible as before.

## Direct rounding controls and diagnostics (1.2.10 development)

The GUI Settings tab now contains four drop-down selectors for the same existing
**runtime-global map settings** that were introduced in 1.2.8. They change
current consumption, current production, maximum consumption and maximum
production independently. Factorio's Mod Settings menu still edits those same
values; there is no duplicate authority. The ALT-unit label can also be
enabled or disabled in the same tab. In multiplayer, only administrators can
change these shared map settings from the custom GUI.

The Diagnostics tab shows each hidden sensor's electric-network ID, whether
the two sensors are connected to one network, which measurement path was used
(direct local flow, statistics/estimate or experimental global statistics),
and the number of active Tier 2 entity types selected by the circuit filters.
ALT unit labels sit above the native circuit signal icons with a compact
font size for longer unit names. All real circuit signal values are unchanged.

## Dedicated GUI and ALT unit labels (1.2.9 development)

Normal-click a placed Energy Combinator to open its own tabbed overview with
physical power readings, circuit scaling, settings and diagnostics. The
**Original combinator settings** button continues to open the native circuit
interface. Hover and press **Ctrl + Shift + E** for the same native interface
as in 1.2.8. Scaling still belongs exclusively to the first circuit signal
slot; GUI changes write that exact slot rather than keeping a competing value.

With Factorio's ALT-information mode enabled, the unit label next to the entity
shows the currently selected resolution: X=0 → W, X=3 → kW, X=5 → 100 kW,
X=6 → MW, X=9 → GW, X=15 → PW. This can be disabled globally per save
under **Settings > Mod settings > Map > Show power unit in ALT mode**.
The ALT label does not create or change circuit signals.

The GUI displays physical power from the existing measurement calculations;
its decimal formatting does not change circuit values or the selected rounding
rules. The maximum values are capacity estimates, not necessarily the grid's
total unsatisfied demand. GUI/ALT visual acceptance is still pending.

## Opening the combinator settings

Hover your mouse pointer over a placed Energy Combinator and press **Ctrl + Shift + E**. The normal Factorio combinator window will open, so you can inspect its circuit signals and adjust the scaling factor. Normal clicks continue to behave as before.

Change the shortcut under **Settings > Controls > Mods > Open Energy Combinator settings**. The mod automatically updates its output signals, so manual changes to those output slots will not persist.

## Scaling factor X

The **Scaling factor X** signal in slot 1 sets the unit of all four reported power signals: `signal = watts / 10^X`. It does not change actual electric power. Circuit signals are integers. Current consumption and production are **rounded to the nearest whole signal point**; estimated maximum consumption rounds upward even for tiny nonzero values at high X (e.g. 1 MW at X=15 gives 1), with insignificant floating-point noise at exact integer boundaries normalized first. Estimated maximum production rounds downward to avoid overstating the capacity. Tiny floating-point errors at an exact integer boundary are normalized first (for example, 800 kW with X=5 gives 8, not 7).

| X | One signal point equals |
|---|---|
| 0 | 1 W |
| 1 | 10 W |
| 2 | 100 W |
| 3 | 1 kW |
| 4 | 10 kW |
| 5 | 100 kW |
| 6 | 1 MW |

For example, at 20 kW the current power signal is 20 with X=3 or 200 with X=2. **X=3 is the default**, suitable for typical kW-scale networks. Lower X gives finer resolution; higher X keeps circuit signal values manageable in large networks. Update any combinator threshold values when changing X. The same explanation is available in the **Scaling factor X signal tooltip** and in **Tips & Tricks** in German, English and Russian.

## Rounding settings (version 1.2.8 development)

Open **Settings > Mod settings > Map** to configure the four circuit output signals
independently: **Current consumption**, **Current production**,
**Maximum consumption**, and **Maximum production**. Every signal offers
**Nearest integer**, **Round up**, or **Round down**. Settings are shared by all
combinators in the same save (including multiplayer) and take effect on the next
scheduled output update; there is no restart or per-combinator override.

The defaults match the previous version: nearest for both current power signals,
up for maximum consumption, down for maximum production. Existing precision
corrections still prevent tiny floating-point artifacts at whole-number boundaries
from creating incorrect off-by-one values. With maximum consumption set to
**Round up**, tiny positive power requirements also remain nonzero at high X.
When selecting nearest or down instead, very small values may intentionally
become zero. All circuit outputs remain **integers**, not decimal text.
Actual electric power flow and the scaling factor X are unchanged.

## Compatibility and migration

- Do not enable this fork alongside energy-combinator, energy-combinator-2, power-combinator or capacity-combinator. All of these conflict with this fork.
- To switch from VinDust's original mod, back up your save, disable the old mod, enable this fork, and verify existing combinators and researched recipes in the loaded save.
- Existing entities and signals retain their original prototype IDs. Research state and script state are not guaranteed until verified against an existing save.
- Global electric networks and space-platform behavior are experimental and require an in-game test.
- Multiplayer behavior has not been verified.

## Credits and license

- Original Power Combinator: dodo.the.last, https://mods.factorio.com/mod/power-combinator
- Factorio 2.0 Energy Combinator fork: VinDust, https://mods.factorio.com/mod/energy-combinator
- Factorio 2.1 Enhanced maintenance: ener156

The source mod and its predecessor were released under The Unlicense (public domain); this derivative is also released under The Unlicense. See LICENSE.

## Updating

For existing 1.2.0 installations, upgrade to 1.2.1 using the same mod ID. The change does not rename prototype IDs. For installations coming from a different mod ID, follow the save-migration precautions above.

## Historical documentation

`power-combinator_readme.md` is retained as upstream reference material. Claims in that historical file (including multiplayer compatibility) do not constitute a validation of this fork.

## Project history

The entries below describe **other projects and releases**, not past releases of Energy Combinator 2.1 Enhanced:

- **Power Combinator** by dodo.the.last: the original project on which Energy Combinator was based.
- **Energy Combinator** by VinDust, version 1.0.0 (10 November 2024): updated for Factorio 2.0.
- **Energy Combinator** by VinDust, version 1.1.0 (11 November 2024): filter controls changed to circuit signals; old combinator GUI removed.
- **Energy Combinator** by VinDust, version 1.1.1 (13 November 2024): red wire removed from the recipe.
- **Energy Combinator 2.1** by n0t49a1n, version 2.1.1 (24 October 2026): a separate Factorio 2.1 compatibility fork.
- **Energy Combinator 2.1** by n0t49a1n, version 2.1.2 (24 October 2026): fixed the read-only `minable` error in that separate fork.

See the [original Energy Combinator](https://mods.factorio.com/mod/energy-combinator), [Power Combinator](https://mods.factorio.com/mod/power-combinator), and [Energy Combinator 2.1](https://mods.factorio.com/mod/energy-combinator-2) for their own release histories.
