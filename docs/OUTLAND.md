# Outland (58-70): route pass

All 13 Outland guides were reviewed with the same tools as the 1-60 work. All numbers are from the route audit on the guides of 0.9.0 (`69914bd`) and the current guides, with the same model (`docs/LEVELS_31_60.md` → The model). They are estimates, and none of this has been played in the game.

## Inventory

| Guide | Faction | Levels | Hub(s) | Next |
|---|---|---|---|---|
| A_Hellfire / H_Hellfire | A / H | 58-62 | Honor Hold / Thrallmar | Zangarmarsh |
| A_Zangarmarsh / H_Zangarmarsh | A / H | 61-64 | Telredor, Orebor Harborage / Zabra'jin | Terokkar |
| A_Terokkar / H_Terokkar | A / H | 63-65 | Allerian Stronghold / Stonebreaker Hold | Nagrand |
| A_Nagrand / H_Nagrand | A / H | 64-67 | Telaar / Garadar | Blade's Edge |
| A_BladesEdge / H_BladesEdge | A / H | 66-68 | Sylvanaar, Toshley's Station / Thunderlord, Mok'Nathal | Netherstorm |
| Both_Netherstorm | both | 67-70 | Area 52 | Shadowmoon |
| A_Shadowmoon / H_Shadowmoon | A / H | 68-70 | Wildhammer / Shadowmoon Village | end |

Every Outland zone is represented. The level-70 content (Isle of Quel'Danas, reputation dailies) is outside the leveling route and is not covered.

## What changed

- **Reorder:** every guide was reordered within its travel segments; every quest, chain and gate was kept. Content is identical except the additions below.
- **Notes:** 166 notes from the bundled data, on drop sources, elites ("bring help or skip"), escorts, and "needs level N" on gated pickups.
- **Horde Blade's Edge:** Mok'Nathal Village's three chains were added (Dertrok, Leoroxx, Spiritcaller Dohgar): 10 quests, 15 → 25.
- **Train steps:** a train step without a place now points the arrow at the nearest class trainer of your faction.
- **Saved progress:** follows the new order (chained layouts).

| Guide | Travel 0.9.0 → now | Quests | Grind levels 0.9.0 → now | Gated pickups |
|---|---|---|---|---|
| A_Hellfire | 828 → 519 | 60 | 1.33 → 1.33 | 6 → 8 |
| H_Hellfire | 738 → 467 | 51 | 1.51 → 1.51 | 3 → 6 |
| A_Zangarmarsh | 323 → 174 | 39 | 0.08 | 0 |
| H_Zangarmarsh | 401 → 251 | 37 | 0.11 | 0 |
| A_Terokkar | 465 → 367 | 33 | 1.25 | 0 |
| H_Terokkar | 426 → 305 | 33 | 1.28 | 0 |
| A_Nagrand | 367 → 192 | 36 | 1.22 | 0 |
| H_Nagrand | 386 → 205 | 39 | 1.24 | 0 |
| A_BladesEdge | 258 → 193 | 33 | 0.28 | 0 |
| H_BladesEdge | 215 → 192 | 15 → 25 | 0.66 → 0.46 | 0 |
| Both_Netherstorm | 358 → 220 | 35 | 0.31 | 0 |
| A_Shadowmoon | 132 → 76 | 18 | 0.64 | 0 |
| H_Shadowmoon | 89 → 65 | 18 | 0.64 | 0 |

**How travel is measured:** per character, as straight-line map percent within a zone plus 25 per zone change. Flight paths and terrain are not modelled, so these are approximations, comparable only within one guide.

**Gated pickups:** the new ones in Hellfire are within 0.3 levels of their requirement in the model. The guide skips them if you are lower and brings them back once you reach 60. Each carries a "needs level 60" note.

## Review notes

- **Dungeons:** dungeon tagging is data-driven. None of the Outland routes' quests are confined to an instance in the data, so nothing new was tagged. The Hellfire Ramparts quests stay optional.
- **Solo vs group:** elite objectives are marked by the data notes.
- **Flying:** no guide requires a flying mount.
- **Reputation:** no route quest needs reputation beyond what the route itself earns.

## Not done (Outland)

- **Coverage is still thin late:** Shadowmoon (18 quests per faction, 12-13% of the zone) and Netherstorm (35 quests, 23%). Players are usually 69-70 there, and the model grinds 0.6 levels in Shadowmoon.
- **Terokkar and Nagrand** have about 1.25 grind levels each and many unused solo quests (`docs/generated/coverage-outland.csv`, 901 candidates). Those were not reviewed one by one in this pass.
