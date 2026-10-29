# Levels 31-60: coverage pass

This pass adds routes for four zones no guide visited, expands the thinnest existing guides, and re-measures progression against 0.9.0 under the same model.

Tools: `tools/build.ps1 routes` (route audit and XP model) and the coverage and disposition scripts described below.

Generated files in `docs/generated/`:
- `guide-xp.csv`
- `route-metrics.csv`
- `level-gates.csv`
- `coverage-31-60.csv`
- `candidates-31-60-disposition.csv`

**Everything here is a static check or a modelled estimate. None of it has been played in the game.**

## The model (unchanged in this pass)

`tools/src/RouteAnalyzer.cs` walks every race/class route step by step:

| Item | How the model treats it |
|---|---|
| Quest XP | QuestieDB's TBC XP per quest, with the level penalty (full XP up to 5 levels above the quest; less beyond). |
| XP table | The post-2.3 XP-to-level table. |
| Kill XP | **Assumed** at half the quest XP earned (`KillShare = 0.5`). It is not data. |
| Rested and discovery XP | None. |
| Dungeons | No dungeon quest XP and no dungeon kills. |
| Optional, elite and group quests on the route | Counted, as if done. |
| `level` and `grind` steps | Lift the model to that level. The lift is reported as **grind levels**: the levels the player must grind because quests (plus the assumed kills) do not get them there. |

The model was not changed to make these numbers look better. One measurement was added: per-guide XP (`guide-xp.csv`), which records the model level entering and leaving each guide, the quests-only level and the grind levels. It reads the same walk; it doesn't change it.

**What "16-17 levels of grinding" meant:** in 0.9.0, the grind levels of the guides from level 30 to 58 summed to 16.96 for Alliance and 15.96 for Horde. That is, about 60% of those 28 levels came from `level` steps rather than from quest XP plus the assumed kill XP.

## Before and after (same model, same data)

Both columns come from the same tooling run on the guides of commit `69914bd` (0.9.0) and on the current guides.

**Grind levels by band:** each guide counts in the band of its entry level.

| Band | Alliance 0.9.0 | Alliance now | Horde 0.9.0 | Horde now |
|---|---|---|---|---|
| 30-40 | 6.51 | 4.54 | 4.03 | 3.11 |
| 40-50 | 5.36 | 4.28 | 6.58 | 4.75 |
| 50-58 | 5.09 | 3.44 | 5.35 | 4.36 |
| **30-58** | **16.96** | **12.26** | **15.96** | **12.22** |
| Distinct quests, 30-58 guides | 160 | 237 | 168 | 221 |
| Pickups above the model's level, 30-58 | 4 | 3 | 2 | 3 |

**Grinding is reduced, not solved.** About 44% of the 30-58 levels still come from `level` steps in the model. The `level` steps stay in the guides as the explicit fallback: each says which level to reach before moving on, and some name mobs near the hub.

## New guides

| Guide | Faction | Levels | Distinct quests | Zone coverage | Placement |
|---|---|---|---|---|---|
| A_Desolace (Nijel's Point) | Alliance | 33-37 | 21 | 20/36 | Arathi → **Desolace** → Stranglethorn. The Reclaimers breadcrumb is picked up in Ironforge on the way. |
| H_Desolace (Ghost Walker Post, Shadowprey) | Horde | 33-36 | 7 | 6/32 | Thousand Needles → **Desolace** → Arathi |
| A_Badlands | Alliance | 38-41 | 15 | 11/28 | Stranglethorn → **Badlands** → Dustwallow; the Ironforge follow-ups are on the way out |
| H_Badlands (Kargath) | Horde | 35-38 | 6 | 5/17 | Arathi → **Badlands** → Stranglethorn. The trip to Kargath is on foot through the Wetlands and Loch Modan, and the guide says so. |
| Both_SearingGorge (Thorium Point) | both | 47-50 | 13 | 13/25 A, 13/19 H | Hinterlands → **Searing Gorge** → Un'Goro |
| Both_EasternPlaguelands (Light's Hope) | both, plus Horde-only Nathanos steps | 56-58 | 10 | 8/55 A, 10/60 H | Western Plaguelands → **Eastern Plaguelands** → Hellfire. The `level 58` gate and the Dark Portal note moved here. |

The Desolace routes take the Magram side of the centaur choice. The Gelkis quests are listed as excluded.

## Thin guides

The 0.9.0 counts were unique quests per guide, from `route-metrics.csv`.

| Guide | 0.9.0 | Now | What changed |
|---|---|---|---|
| H_Feralas | 4 | 14 | Rewritten around Camp Mojache: the Woodpaw chain and Zukk'ash hive, the Grimtotem and sprite darter pair, two Gordunni ogre quests and the yeti hides, plus the existing harpy and giant quests. |
| A_Arathi | 7 | 7 | **Not expanded.** Faldir's Cove needs level 35, and Worth Its Weight in Gold needs a Stormwind breadcrumb the route doesn't pass. Both are deferred in the disposition record. Desolace now follows Arathi instead. |
| A_Felwood | 8 | 9 | Added Salve via Hunting. Corrected a wrong note: Seeking Spiritual Aid goes to the Barrens, not Winterspring. The Jaedenar chain is deferred because of that Barrens trip. |
| H_Felwood | 8 | 9 | Salve via Hunting. |
| A_Western Plaguelands | 9 | 26 | Rewritten around Chillwind Camp's cauldron chain (four cauldrons, Mission Accomplished), Andorhal's watchtowers, Chromie's two quests and the Dalson cabinet. The Ironforge call-to-arms breadcrumb is picked up on the way. |
| H_Western Plaguelands | 14 | 20 | Added the watchtowers, Chromie and the Dalson cabinet. Added the Undercity call-to-arms breadcrumb: the data requires it for Scarlet Diversions, and no route picked it up before. |

## Remaining gaps

| Guide (model) | Grind levels now | Why it stays |
|---|---|---|
| Felwood (both) | 2.2 | Felwood's other quests are repeatable salve turn-ins, profession or class quests, or chains that leave the zone. Winterspring (55-60) is still unvisited. |
| Tanaris (both) | 1.75 | Unchanged in this pass. |
| A_Arathi | 1.84 | See above. |
| H_Hinterlands | 1.71 | Unchanged. |
| H_Western Plaguelands | 1.67 | The Horde chain was already in place; the additions cut it from 3.04. |
| H_Desolace, H_Badlands | 1.39 each | Horde Desolace and Badlands have fewer good solo quests than the Alliance versions. |

**Still unvisited:** Swamp of Sorrows, Azshara, Winterspring, Silithus, the Blasted Lands and Alliance Thousand Needles.

**Fallback:** where the model still needs grinding, the guide's `level` step stops progress until you reach the level. Pickups above your level are skipped with the reason and come back when you reach the level.

## Handoffs (checked by the route audit, 0 errors on all 52 routes)

- **Alliance 30→31:** Wetlands → Hillsbrad → Arathi → Desolace.
- **Horde 30→31:** Hillsbrad → Thousand Needles → Desolace → Arathi.
- **Late Azeroth → Outland:** Western Plaguelands now ends at `level 57` and leads to the Eastern Plaguelands. That guide ends with `level 58`, a train step and the Dark Portal note, then links to A_Hellfire or H_Hellfire by faction.

## Candidates

`docs/generated/candidates-31-60-disposition.csv` covers the 496 candidates from 0.9.0 plus the candidates in the four new zones: 682 in all.

| Status | Count | Meaning |
|---|---|---|
| Added | 44 | now on a route |
| Deferred | 403 | Has a stated reason. Common ones: escort or event, starts from an item drop, elite objective, needs a quest the route skips, turned in outside the route's zones, level fit. |
| Excluded | 5 | the Gelkis side of the Desolace centaur choice |
| Unverified | 230 | Not reviewed in this pass; the rule check found no blocker. These are the next things to look at. |

How the reasons were assigned:
- **Manual review** (`reviewed=yes`): quests I read while writing the routes.
- **Rule-based** (`reviewed=rule`): read from the data. The rules check for the party flag, an item start, an elite objective NPC, prerequisites not on the route, and a turn-in zone the route never visits.
- **Never counted as baseline XP:** repeatable, class, profession and dungeon quests are left out of the candidate list entirely.

## Shared-system changes this pass needed

- **Guide compiler:** steps in a shared (`Both`) guide can now carry `[faction=Alliance|Horde]` and resolve faction-only quests. The runtime already filtered such steps; the compiler had been ignoring the flag.
- **Saved progress:** layouts now chain. A character who saved on 0.7.0 or on 0.9.0 is moved to the same step in the current order (`Guides/Layouts.lua`, `ns:ApplyLayout`).

## Pass 2 (after 0.9.1)

**Measured how:** with the same model and data on the guides of `06e788d` (0.9.1) and the current guides. The model is unchanged.

**Gate changes:** two `level` steps were lowered, because the following guide's quests need no more.
- **Felwood:** 54 → 53. Winterspring follows, and its quests need 52-53.
- **Swamp of Sorrows:** 41 → 40. Dustwallow's quests need 38-39.

Those are content changes, not model changes. One pickup was moved behind the gate that unlocks it: *Finding the Source*, now after Un'Goro's `level 51` step.

| Band | Alliance 0.9.1 | Alliance now | Horde 0.9.1 | Horde now |
|---|---|---|---|---|
| 30-40 | 4.54 | 4.54 | 3.11 | 2.90 |
| 40-50 | 4.28 | 3.18 | 4.75 | 3.21 |
| 50-58 | 3.44 | 2.81 | 4.36 | 3.29 |
| **30-58** | **12.26** | **10.53** | **12.22** | **9.40** |
| Distinct quests, 30-58 guides | 237 | 268 | 221 | 266 |
| Pickups above the model's level, 30-58 | 3 | 5 | 3 | 6 |

**Gated pickups:** the new ones are optional or noted, and the engine skips each until you reach its level: Gahz'ridian (43), The Thirsty Goblin (44), Continued Threat (41).

**Added:**

| Guide | Faction | Distinct quests | Notes |
|---|---|---|---|
| Both_Winterspring (new) | both; Enraged Wildkin chain Alliance-only | 15 | Entered via Speak to Salfa from Felwood's Nafien. Everlook hunts, Winterfall, Kel'Theril. The Everlook Report is turned in at WPL and Duke Nicholas at EPL. |
| H_SwampOfSorrows (new) | Horde | 10 | Stonard, Misty Reed Strand (Threat From the Sea chain), Magtoor |
| A_ and H_Dustwallow | both | +6 each | Moxie's crash quests, Help for Mudsprocket, Bloodfen Feathers, Goreclaw, Catch a Dragon by the Tail |
| Both_Tanaris | both | +3 | Andre Firebeard; Gahz'ridian and The Thirsty Goblin (optional, level-gated) |
| Both_UngoroCrater | both | +4 | Shizzle's Flyer, Muigin and Larion / Larion and Muigin (by faction), Finding the Source |
| H_Hinterlands | Horde | +4 | the Revantusk board: Separation Anxiety, Dark Vessels, Job Opening, Hexx (optional) |
| A_ and H_Felwood | both | +1 each | Speak to Salfa (the Winterspring link) |

**Felwood:** the old "2.2 levels" was Felwood's own gate (54) on top of thin content. Felwood plus Winterspring now model at 1.14 + 1.35 (Alliance) and 0.94 + 1.35 (Horde), against 2.24 / 2.21 for Felwood alone before. Winterspring adds about 0.6 level of quest XP; the rest is still grinding.

**Candidates:** 741 rows in `candidates-31-60-disposition.csv`.

| Status | Count |
|---|---|
| Added | 74 |
| Already covered | 2 |
| Deferred | 464 |
| Excluded | 5 |
| Unverified | 196 |

Most of the priority zones (Tanaris, Hinterlands, Un'Goro, Dustwallow) were reviewed by hand. 4 Tanaris, 4 Un'Goro and 16 Dustwallow candidates remain unverified, mainly the Theramore breadcrumb chains and quests whose objectives have no spawn data.

**Remaining:**
- **Grinding:** about 10.5 (Alliance) and 9.4 (Horde) levels from 30 to 58. The largest single gaps are Arathi (Alliance, 1.84), Tanaris's level-44 gate, Winterspring (1.35) and Desolace and Badlands (Horde, 1.39 each).
- **Unvisited:** Azshara, Silithus and the Blasted Lands.
- **Fallback:** the `level` steps stay the explicit instruction.
