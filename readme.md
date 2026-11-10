# Energy Combinator 2.1 Enhanced

Independent, community-maintained Factorio 2.1 fork of **Energy Combinator** by **VinDust**, which itself is based on **Power Combinator** by **dodo.the.last**.

This mod reports electric network power statistics through the circuit network. Tier 1 exposes current consumption and production and their estimated maximum values, with a selectable scaling exponent. Tier 2 adds circuit-controlled entity filtering. Existing in-game prototype names are retained for compatibility with established layouts, but the internal mod ID is different.

Factorio 2.1 startup and runtime smoke tests have passed. Version 1.2.1 also addresses scaling persistence, circuit-filter feedback and Tips & Tricks integration. These tests do not establish full multiplayer, migrated-save or space-platform compatibility.

## Opening the combinator settings

Hover your mouse pointer over a placed Energy Combinator and press **Ctrl + Shift + E**. The normal Factorio combinator window will open, so you can inspect its circuit signals and adjust the scaling factor. Normal clicks continue to behave as before.

Change the shortcut under **Settings > Controls > Mods > Open Energy Combinator settings**. The mod automatically updates its output signals, so manual changes to those output slots will not persist.

## Scaling factor X

The **Scaling factor X** signal in slot 1 sets the unit of all four reported power signals: `signal = watts / 10^X`. It does not change actual electric power. Circuit signals are integers. Current consumption and production are **rounded to the nearest whole signal point**; estimated maximum consumption rounds upward even for tiny nonzero values at high X (e.g. 1 MW at X=15 gives 1), while estimated maximum production rounds downward to avoid overstating the capacity. Tiny floating-point errors at an exact integer boundary are normalized first (for example, 800 kW with X=5 gives 8, not 7).

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
