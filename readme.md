# Energy Combinator 2.1 Enhanced

Independent, community-maintained Factorio 2.1 fork of **Energy Combinator** by **VinDust**, which itself is based on **Power Combinator** by **dodo.the.last**.

This mod reports electric network power statistics through the circuit network. Tier 1 exposes current consumption and production and their estimated maximum values, with a selectable scaling exponent. Tier 2 adds circuit-controlled entity filtering. Existing in-game prototype names are retained for compatibility with established layouts, but the internal mod ID is different.

Factorio 2.1 support and 14 code-level changes were validated with an isolated startup and 120-tick runtime smoke test on Factorio 2.1. This does not imply full functional, multiplayer, existing-save or space-platform testing.

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
