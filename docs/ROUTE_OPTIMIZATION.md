# Route optimization (0.2.0)

This document covers how the 1-70 routes were evaluated and changed, what the sources say, and what is and is not claimed.

**No XP-per-hour or time-to-70 figure is claimed anywhere.** Nobody has timed these routes. The changes below are justified by things the data can show: impossible quest orders, wasted pickups, quest-log overflow and level gates. Their effect on actual leveling speed still needs to be measured in play.

## 1. Research: sources consulted

| Source | Applies to TBC Classic 2.5.x? | What it contributed | How it was used |
|---|---|---|---|
| [Warcraft Tavern: TBC Alliance leveling guide](https://www.warcrafttavern.com/tbc/guides/alliance-leveling-guide/) and [Horde guide](https://www.warcrafttavern.com/tbc/guides/horde-leveling-guide/) | Yes (TBC Classic) | Outland order and ranges: Hellfire 58-61, Zangarmarsh 61-63, Terokkar 63-65, Nagrand 65-67, Blade's Edge 67-68, Netherstorm 68-69(70), Shadowmoon 69-70. Also: start Hellfire at 59-60 if possible, grind a little rather than run a dungeon when slightly short, skip respawn-dependent quests when ahead, train on even levels when a city flight is near | Confirms the existing Outland chain and ranges; no reorder needed. Basis for `level` gates and the "grind briefly" note style |
| [Noob to Boss: TBC Classic 1-70 (Anniversary 2026)](https://noobtoboss.com/tbc-classic-1-70-leveling-guide/) | Claims Anniversary | Go to Outland at 58 rather than grinding to 60 in Azeroth; Outland order (matches the above); finish the Draenei and Blood Elf start zones to 10 | Confirms the 58 transition and the start-zone policy. Its Azeroth level bands are loose (e.g. Redridge listed at 25-40), so they were **not** used |
| [Engadget: patch 2.3 leveling changes](https://www.engadget.com/2007-10-08-leveling-improvements-for-patch-2-3.html), [Blizzard forums](https://us.forums.blizzard.com/en/wow/t/regarding-leveling-time/960041), [bittsguides](https://bittsguides.com/?p=955) | Yes; the TBC Classic pre-patch is 2.4.3-based | XP needed for 20-60 was reduced (about 15-17%; some newer guides say 30%, which is unsupported), and quest XP for 30-60 was raised | Zone `@levels` were not widened; the conflict is noted here instead of picking a number |
| Warcraft Tavern / [Massively OP](https://massivelyop.com/?p=344342) / Blizzard forum threads on entering Outland at 58 | Yes | Entering at 58 works but has only a few level-58/59 Hellfire quests; expect some grinding to 60 | Existing Hellfire guides already start with the low quests; kept |
| QuestieDB TBC data (bundled, pinned commit) | Yes (TBC flavor) | Prerequisites (`preQuestGroup`/`preQuestSingle`), required levels, quest levels, start/end NPCs and coordinates, `questFlags` | **The optimization model's input.** All order fixes follow these prerequisites |
| Icy Veins, Zygor | TBC | Proprietary or paywalled | Not used for content |

Information from Vanilla Classic or Retail was not used for ranges. The patch 2.3 sources are period articles about the same ruleset that TBC Classic runs.

**Conflicts and decisions.** Sources disagree on Zangarmarsh (60-64 vs 61-63) and Netherstorm (66-70 vs 67-70). The routes keep their existing 61-64 and 67-70, which sit inside both. Sources disagree on the size of the 2.3 XP cut, so no route depends on it.

## 2. The optimization model (`tools/build.ps1 routes`)

`tools/src/RouteAnalyzer.cs` walks **every one of the 52 race/class routes** step by step, the way a player of that race and class would (class- and race-filtered steps included), and checks:

- **Dependency order (error).** A quest is accepted before one of its prerequisites is turned in on the same route, so the NPC will not offer it yet. Also a complete-step before the accept.
- **Quest-log capacity (error above 25, warning above 22).** Peak number of quests held at once.
- **Pickups never turned in.** These cost NPC clicks and log space and give no XP.
- **Duplicate pickups.**
- **Level gates.** Quest required level is above the estimated character level at that step. The estimate interpolates between the guide's `@levels` and its own `level N` checkpoints. It is a planning estimate, not a measurement.
- **Reduced-XP pickups.** The estimated level is 6 or more above the quest level, where the TBC quest XP formula starts cutting rewards.
- **Travel (per guide).** Straight-line distance between consecutive located steps (zone-map percent, comparable within one guide), zone changes, and hub revisits (returning to an NPC cluster after leaving it).

It writes `docs/ROUTE_AUDIT.md` and `docs/generated/route-metrics.csv`, and compares against `docs/generated/route-metrics-baseline.csv` (the 0.1.0 routes). `build.ps1 all` now **fails** on any order or capacity error, so these defects cannot come back.

XP per quest is not in the bundled data and was not invented. "Efficiency" in this model means **not wasting** steps, travel or log space. It does not attempt to rank quests by XP per hour.

## 3. Audit of the 0.1.0 guide database (baseline)

The full baseline report is kept in `docs/generated/route-audit-baseline.md`.

| Finding (0.1.0) | Count |
|---|---|
| Distinct impossible-order pickups (prerequisite turned in later on the route) | **26**, all in Horde, Draenei, Blood Elf and shared Netherstorm routes; 514 route-level errors once multiplied by race/class |
| Quests accepted and never turned in anywhere on the route | **106** |
| Peak quest log on the worst route | **65 / 25** (impossible in game). The never-turned-in pickups piled up |
| Duplicate pickups | 1 (*Report to Orgnil*, Durotar) |
| Level-gated pickups | 28 |
| Hub revisits, all guides | 454 |

Examples of the impossible orders:

- Undead start: *Rattling the Rattlecages* before *The Mindless Ones*; *The Scarlet Crusade* before *Night Web's Hollow*.
- Barrens: *Supplies for the Crossroads* before *Disrupt the Attacks*; the Ratchet *Missing Shipment* chain before *Southsea Freebooters*.
- Dustwallow (Horde): *Return to Krog* placed 30 lines after the two quests it unlocks.
- Thousand Needles: *Serpent Wild* and *Sacred Fire* before *Alien Egg*.
- Silverpine: *Thule Ravenclaw* before *Rot Hide Origins*.
- Eversong: *Report to Lanthan Perilon* before *Unfortunate Measures*.

In the game, each of these leaves the player at an NPC with nothing to offer. With 0.2.0's automation, they would also stall the accept step.

## 4. What changed

| Change | Effect | Why it should help |
|---|---|---|
| **26 order fixes** across 15 guides: each quest is accepted after its prerequisite is turned in, mostly at the same NPC. The Silverpine chain was rewritten in full chain order (*Rot Hide Origins → Thule Ravenclaw → Report to Hadrec → Assault on Fenris Isle*) | 0 order errors on all 52 routes | No dead stops at NPCs; the accept automation can actually take the quest. Some fixes add a short return trip, which is the real cost the old order hid |
| **~90 dead pickups removed**: optional "WANTED"/elite pickups, side quests never worked, and chain tails left open at a zone exit | Steps 4,281 → 4,204; never-turned-in 106 → 0 | Fewer NPC interactions and no log clutter; no XP lost, since none of them were ever turned in |
| **13 deliveries turned in where the route already passes the recipient**: e.g. *Word from Azure Watch*, *Letter to Jin'Zil* (Stonetalon), *Warn Bolvar!* and *Reassignment* (during the Stormwind visit in Burning Steppes), *The Cenarion Expedition* (Zangarmarsh), *Ak'Zeloth*, *A Peon's Burden*, *Farstrider Retreat*, *The Longbeards* | Quest XP that was being thrown away | Free turn-ins with no extra travel |
| ***Blessings of the Ancients*** (talk to two NPCs at Cenarion Refuge) completed on the spot, and ***Plants of Zangarmarsh*** turned in on the next Refuge visit (optional) | Previously accepted and never turned in | XP with no detour |
| **Level checks**: Horde Feralas gets a `level 45` gate (every Camp Mojache quest needs 45, while Tanaris ends at 44). Unreachable pickups removed: *The Strength of Corruption* (needs 47), *Coming of Age* (needs 10 in Azure Watch, but the route reaches 10 only on the way out), *Destroy the Legion* (needs 27 as you leave Ashenvale) | Level-gated 28 → 20 (the rest are mild, mostly start zones) | The guide no longer sends you to quests the NPC will not offer yet |
| **Quest-log peak** | 65 → **10** on the worst route | Leaves room for optional, dungeon and class quests; the automation never hits a full log on the main route |
| **Engine**: optional turn-ins for quests from an earlier guide (breadcrumbs) are skipped automatically if the quest is not in your log | Players who skipped a breadcrumb are not stuck | Re-evaluated on every refresh, never saved |
| **Route option `speedRoute`** (*Maximum-speed route*, default off) hides all `[optional]` side quests | 123 optional steps | One meaningful variant instead of many near-duplicate routes. Dungeon and group content already has its own toggles (`showDungeonSteps`, `showElite`, `autoAcceptGroup`) |

### Measured route metrics, 0.1.0 → 0.2.0 (all 54 guides)

| Metric | 0.1.0 | 0.2.0 |
|---|---|---|
| Route errors (order / capacity) | 514 | **0** |
| Route warnings | 32 | **0** |
| Steps | 4,281 | 4,204 |
| Quests touched | 1,314 | 1,222 |
| Never turned in | 106 | **0** |
| Peak quest log (worst route) | 65 | **10** |
| Level-gated pickups | 28 | 20 |
| Straight-line travel (sum, map %) | 16,265 | 15,868 (−2.4%) |
| Hub revisits | 454 | 438 |

Travel is a proxy for walking distance, not time. It fell in most guides, but **rose in a few** (e.g. Azuremyst, Durotar, Burning Steppes, Horde Zangarmarsh) where correct ordering needs a return trip, or a turn-in was added. Per-guide values are in `docs/ROUTE_AUDIT.md`.

## 5. Class-specific recommendations

The routes stay shared across classes. No meaningful per-class route difference could be supported with evidence, and duplicate routes would multiply maintenance. Class differences are handled where they apply:

- class-filtered steps (`[class=...]`) for class quests and trainers;
- the class leveling tips (`/tbcg class`): pet classes, healing and downtime, AoE;
- `autoAcceptGroup` / `showElite` / `showDungeonSteps` for classes that solo elites well (hunter, warlock) or have a group.

## 6. Known remaining issues (need play-testing)

- **20 mild level-gated pickups**, mostly in start zones, where XP is front-loaded so the linear estimate under-reads; plus 3 in Alliance Hillsbrad (need 30, estimate 28.4). See `docs/ROUTE_AUDIT.md`.
- **Hub revisits (438)** are measured but were not reordered automatically. Moving steps between hubs safely needs knowledge the data does not have (objective areas, respawns, elites). This is the next optimization target once routes have been timed.
- **XP sufficiency** between `level` gates is unmeasured.
- Order fixes follow QuestieDB prerequisites. If upstream data is wrong for a quest, the fix only moves the pickup later; it never removes one.
