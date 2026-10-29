# Levels 31-60: route pass and status

This covers the 18 guides from Thousand Needles / Arathi (29-35) to Western Plaguelands (55-58), plus their handoffs. Method and tools: the same as the 1-30 pass (`docs/ROUTE_PASS_1.0.md`). Generated numbers: `docs/generated/guide-xp.csv`, `route-metrics.csv`, `level-gates.csv` and `coverage-31-60.csv`.

## What changed

- **Reorder:** steps were reordered within their travel segments in 15 of the 18 guides. Every quest, chain, prerequisite and level gate was kept. Summed segment travel fell from **4,372 to 3,121** (-29%). This is the same approximate measure as before: map-percent straight lines, plus a fixed cost per zone change.
- **Notes:** 62 notes from the bundled data were added: drop sources, objects, escorts, turn-in zones, and "needs level N" on the 4 gated pickups.
- **Train steps:** each guide already had one. Each now lists what your trainer has (`docs/TRAINER.md`) and is skipped when there is nothing new. A train step without a place points the arrow at the nearest class trainer of your faction.
- **Dungeon tags:** tags now come from the quest data (`docs/DUNGEONS.md`). The 31-60 routes contain **no** dungeon-only quests, so nothing new was tagged.
- **Saved progress:** `Guides/Layouts.lua` now maps old step positions to new ones for all 40 reordered guides (1-30 and 31-60), with every step matched. Characters keep their place.

## Handoffs (checked)

- **30 → 31:** every Alliance route reaches *Arathi Highlands* through Wetlands → Hillsbrad, and every Horde route reaches *Thousand Needles* through Hillsbrad. The audit walks all 52 race/class routes; 0 errors.
- **58 → Outland:** both Western Plaguelands guides end with `level 58`, a train step and the Dark Portal note. The Hellfire guides start with the optional *Through the Dark Portal* herald quest.

## Matrix

**Columns:**

- **Quests:** distinct quests the guide uses.
- **Zone coverage:** that faction's quests the data places in the zone (level window -3/+4, not class, profession or repeatable) that any route uses.
- **Model:** the XP-model level entering → leaving the guide, averaged over the routes.
- **Grind:** levels the guide's `level` steps add on top of quest XP.
- **Travel:** per-character travel after the reorder.

| Guide | Side | Levels | Quests | Zone coverage | Model | Grind | Travel | Gated | Group |
|---|---|---|---|---|---|---|---|---|---|
| A_Arathi | A | 30-34 | 7 | 4/7 (57%) | 30 → 33 | 1.84 | 80 | 0 | 4 |
| A_Stranglethorn | A | 32-40 | 47 | 20/74 (27%) | 33 → 38 | 3.05 | 484 | 0 | 0 |
| A_Dustwallow | A | 36-41 | 23 | 23/74 (31%) | 38 → 41 | 1.62 | 215 | 0 | 0 |
| Both_Tanaris | A | 41-45 | 12 | 12/29 (41%) | 41 → 44 | 1.95 | 35 | 1 | 2 |
| A_Feralas | A | 43-47 | 19 | 19/42 (45%) | 44 → 46 | 0.86 | 272 | 2 | 2 |
| A_Hinterlands | A | 45-49 | 9 | 9/20 (45%) | 46 → 48 | 1.23 | 93 | 0 | 0 |
| Both_UngoroCrater | A | 48-52 | 13 | 13/41 (32%) | 48.5 → 51 | 1.32 | 309 | 1 | 1 |
| A_Felwood | A | 51-54 | 8 | 7/24 (29%) | 51 → 54 | 2.31 | 92 | 0 | 0 |
| A_BurningSteppes | A | 53-56 | 13 | 11/17 (65%) | 54 → 55 | 0.37 | 133 | 0 | 1 |
| A_WesternPlaguelands | A | 55-58 | 9 | 9/54 (17%) | 55 → 58 | 2.41 | 98 | 0 | 0 |
| H_ThousandNeedles | H | 29-33 | 42 | 20/38 (53%) | 30 → 32.9 | 0.00 | 473 | 0 | 0 |
| H_Arathi | H | 32-35 | 14 | 12/15 (80%) | 32.9 → 35 | 0.93 | 103 | 0 | 0 |
| H_Stranglethorn | H | 34-40 | 19 | 18/63 (29%) | 35 → 39 | 2.84 | 146 | 0 | 0 |
| H_Dustwallow | H | 37-42 | 29 | 29/59 (49%) | 39 → 41 | 0.26 | 298 | 0 | 0 |
| Both_Tanaris | H | 41-45 | 12 | 12/32 (38%) | 41 → 44 | 1.95 | 35 | 1 | 2 |
| H_Feralas | H | 43-47 | 4 | 4/32 (12%) | 44 → 46 | 1.60 | 36 | 0 | 0 |
| H_Hinterlands | H | 44-50 | 13 | 13/30 (43%) | 46 → 49 | 1.71 | 54 | 0 | 0 |
| Both_UngoroCrater | H | 48-52 | 13 | 13/40 (32%) | 48.5 → 51 | 1.32 | 309 | 1 | 1 |
| H_Felwood | H | 51-54 | 8 | 7/22 (32%) | 51 → 54 | 2.31 | 151 | 0 | 0 |
| H_WesternPlaguelands | H | 54-58 | 14 | 13/51 (25%) | 54 → 58 | 3.04 | 208 | 0 | 0 |

**Zones no route visits** (that faction's quests, quest level 30-60): Desolace 38 A / 35 H, Badlands 29 / 22, Swamp of Sorrows 13 / 19, Searing Gorge 26 / 19, Azshara 20 / 29, Winterspring 41 / 34, Eastern Plaguelands 55 / 60, Silithus 54 / 54, Blasted Lands 19 / 21.

## XP gates and assumptions

**XP model** (`tools/src/RouteAnalyzer.cs`):

- QuestieDB's TBC quest XP with the level penalty;
- the post-2.3 XP table;
- kill XP **assumed** at half the quest XP;
- **no** rested, discovery, group or dungeon XP, and no XP for dungeon quests;
- `level`/`grind` steps lift the model to their level.

These are planning estimates, not measurements.

**Result:** from 30 to 58 the model has an Alliance character grinding about **17 of the 28 levels**, and a Horde character about **16**. The existing `level` steps cover this: the guides tell you to reach each level before moving on, and the 4 pickups above their level are skipped and come back once you reach it. Players who do dungeons or have rested XP will be well ahead of the model.

## Status per guide

| Guide | Order | Notes | Gates | Train | Handoff | Quest density |
|---|---|---|---|---|---|---|
| All 18 above | reordered (15) / unchanged (3: A_Stranglethorn, H_ThousandNeedles, H_Dustwallow already optimal for the measure) | done | checked; level steps in place | suggestions + waypoint | checked | **open**: see checkpoint |

## Checkpoint: not done in this pass

The one large gap is **quest density**. The 31-60 guides use 12-80% of their zones' quests and skip nine zones entirely, which is why the model needs so much grinding. Closing that means writing new routes (Desolace, Badlands, Searing Gorge, Swamp of Sorrows, Azshara, Winterspring, Eastern Plaguelands, Silithus) and extending the thin ones (Horde Feralas 4 quests, Alliance Arathi 7, Felwood 8, Western Plaguelands 9). That is guide-writing work for a separate pass.

- **Starting list:** the 496 eligible quests not on any route, in `docs/generated/coverage-31-60.csv`.
- **Rules:** same as the 1-30 pass: original routes, compiler checks, route audit at 0 errors.

Nothing here has been played in the game.
