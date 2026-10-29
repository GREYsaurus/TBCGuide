# Changelog

## 0.9.4

### Added
- **Roaming Waypoints for Kill Objectives** (Settings → General, on by default): on a kill step with a verified route, the arrow walks a loop of points through the mobs' known spawn area and moves to the next point when you reach one, until the objective is done. Navigation only: it never targets, fights or completes a step for you.
  - **Supported now:** 194 quest objectives in 170 quests, with 160 distinct routes in 39 zones, from the starting zones to Shadowmoon Valley, for both factions. Every other step keeps its normal waypoint.
  - **How the routes were made:** each point is the centre of real spawns, and every leg was checked against the full spawn list, kept away from elites and other-faction towns, and reviewed zone by zone. Caves, mines, multi-level areas, named and elite enemies, escorts and small spawn spots keep a single waypoint.
  - **Records:** all 949 candidate objectives have a recorded decision and reason (docs/research/roaming-dispositions.csv). None of the routes has been walked in the game yet.
  - **Checking the target:** on English clients a route only runs when the quest log's objective names its target.
  - **Controls:** *Next patrol point* and *Normal objective waypoint* buttons, `/tbcg route next | off | on`, and a key binding for the next point.
  - **Routes** are built from real spawn data and checked by the compiler (docs/ROAMING.md); `docs/generated/roaming-candidates.csv` lists the steps that could get one next.
- **Waypoints you choose** (such as `/tbcg train waypoint`) are no longer replaced by the periodic objective retargeting on kill steps.

### Fixed
- **Active Item window:** clicking an item now uses it. The buttons were set up correctly as secure item buttons, but on this client a secure button acts on the mouse-down event (the default "use on key down" setting) and ours only listened for mouse-up, so clicks did nothing. They now listen for both, and the client acts once.
  - **Also:** the buttons show the total stack count and the item's cooldown, and grey out when the item is used up during combat (the list itself changes after combat, so a button never shows one item and uses another). Shift-click links the item in chat, Alt-drag moves the window; neither uses it.


## 0.9.3

### Fixed
- **Discard junk if bag is full** now works without any confirmation: when the bags are full, the cheapest junk item is destroyed on your next click in the game world, key press or loot click, one item each time.
  - **Why the change:** the client only lets add-ons destroy items during a click or key press, so the old attempt from a bag update was refused and left the item on your cursor.
  - **Safety:** every attempt re-checks the slot and the junk rules, and waits while you are in combat, holding an item, or at a merchant, trade, bank, mail or auction window.
  - **Feedback:** success is reported only once the bags confirm it, and failed items are not retried.

- **Innkeeper Bind automation** sets your hearthstone again, and bind steps complete on every client.
  - **Why it failed:** on this client the innkeeper's gossip options have no type, so the bind option was never found; the confirmation used a function the client no longer has; and the step only completed when the game's home name equalled the guide's English town name, which fails for The Crossroads, Theramore Isle, Grom'gol Base Camp, the inns with their own area (Thunderbrew Distillery, Stoutlager Inn, Deepwater Tavern, Gallows' End Tavern, Wildhammer Keep) and every non-English client.
  - **Now:** each bind step names its inn by client area id and innkeeper id. TBCGuide acts only at that innkeeper, confirms only a dialog for that inn, and completes the step only once the game reports the new home. Quest turn-ins at the innkeeper go first. Nothing is retried; declining, closing the window, changing step or turning the setting off cancels it.


## 0.9.2

### Added
- **Winterspring** (both factions, through the Timbermaw tunnel from Felwood) and **Horde Swamp of Sorrows** (Stonard).
- **More quests on existing routes:**
  - Mudsprocket in Dustwallow (both factions);
  - Andre Firebeard, Gahz'ridian and The Thirsty Goblin in Tanaris;
  - Shizzle's Flyer, the bloodpetal quests and Finding the Source in Un'Goro;
  - the Revantusk board in Horde Hinterlands;
  - the Cabal quests and Warden Treelos in Terokkar;
  - Aeris Landing and Wazat in Nagrand, plus Sunspring for Alliance.
- **Less grinding:** in the route model, grinding from 30 to 58 falls from 12.3 to 10.5 levels (Alliance) and from 12.2 to 9.4 (Horde). See docs/LEVELS_31_60.md.
- **Assassination talent plan** from Wowhead's TBC leveling build (docs/TALENTS.md).
- **Training costs** on train steps: from the trainer you have open, or as last seen. Partial totals are marked, and the list says whether you can afford it.
- **Pet and demon skills** (`/tbcg pet`): hunter pet skills (family, pet level, training points, Beast Training) and warlock Grimoires (level, base price, demon trainer). See docs/PETS.md.

### Changed
- **Felwood** now leads into Winterspring.
- **Saved progress** follows guides reordered in any release since 0.7.0.


## 0.9.1

### Added
- **New zones in the 31-60 route:**
  - Desolace (Alliance and Horde) and the Badlands (Alliance and Horde);
  - Searing Gorge and Eastern Plaguelands (shared, with Horde-only Nathanos steps).
- **Expanded guides:** Horde Feralas (4 → 14 quests), Alliance Western Plaguelands (9 → 26, with the Chillwind cauldron chain), Horde Western Plaguelands (14 → 20), Felwood (both), and Horde Blade's Edge (15 → 25, Mok'Nathal Village).
  - In the route model, grinding from 30 to 58 falls from about 17 to 12.3 levels (Alliance) and from 16 to 12.2 (Horde). See docs/LEVELS_31_60.md.
- **Outland:** all 13 guides were reordered within their travel segments (estimated travel down about 35%), with 166 data notes. See docs/OUTLAND.md.
- **Talent plans for every spec**, taken from the Icy Veins TBC Classic leveling guides in their own point order. Each runs from the first point at 10 to 70 with no forced respec, including Demonology from level 10. New: Marksmanship, Survival, Subtlety, Discipline, Arcane, Demonology, Restoration Druid and Frost single-target. See docs/TALENTS.md.

### Changed
- **Existing talent plans** now follow the Icy Veins builds. Old saved choices still resolve to the new plans, and learned talents are never touched. Assassination keeps TBCGuide's own plan, because Icy Veins has no Assassination leveling build.
- **Saved progress** follows guides reordered across several releases (0.7.0 or 0.9.0 → now).
- **Shared guides** can mark steps `[faction=Horde]` or `[faction=Alliance]`.

## 0.9.0

Our biggest update yet: a first-login setup, bag add-on support, non-English client support, class trainer suggestions, talent suggestions in the talent window, an auction house upgrades tab, and a full route pass from level 1 to 60.

### Changed
- **1-30 routes tidied:** the 25 guides that got quests in 0.6.0 were reordered within their travel segments, keeping every quest, chain and gate.
  - **Travel:** per-character travel on those guides is 36% lower than in 0.7.0 (an approximate, map-distance measure).
  - **Gated pickups:** the ones the new XP model flags fell from 206 to 116.
  - **Notes:** 514 notes taken from the bundled data were added (drop sources, objects, elites, escorts, turn-in zones, level needed).

  Details and the method: docs/ROUTE_PASS_1.0.md.
- **31-60 routes tidied:** the 18 guides from Thousand Needles / Arathi to Western Plaguelands were reordered within their travel segments (summed travel -29%, every quest and chain kept), with 62 data notes. Saved progress follows. Coverage matrix and status: docs/LEVELS_31_60.md.
- **Pickups you're too low for** are skipped with the reason instead of blocking the guide. They come back if you reach the level before moving on.
- **Saved progress** follows the reordered steps (`Guides/Layouts.lua`).

### Added
- **Auction house Upgrades tab** (*Enable Auctioneer*): a scan you start, with progress, cancel and partial/stale labels, and upgrades for your spec grouped by slot, scored exactly like automatic upgrades.
  - **Filters:** price, minimum % and slot, with a sort by % or price.
  - **Never automatic:** nothing is ever bought.

  See docs/AUCTION.md.
- **Window settings** (General): guide window scale, font size and arrow scale, with a reset.
- **First-login setup:** pick a guide and a spec profile, and opt in to automatic upgrades explicitly (off unless ticked). Saved per character; skip, resume after a reload, or reopen from Settings → General. Existing characters are not interrupted.
- **Bag add-ons:** the BoE upgrade arrow and junk markers also work in Bagnon, AdiBags and Baganator (docs/BAGS.md). Not yet tested in game.
- **Non-English clients:** tooltip reading uses the client's own strings for binding and effects; unread equip effects make an upgrade uncertain instead of being ignored (docs/LOCALES.md).
- **Dungeon quests** are tagged from quest data in the compiler, with hand tags winning. The route XP model no longer counts dungeon quest XP (docs/DUNGEONS.md).
- **Class trainer suggestions** (*Class Trainer Suggestions*: Off / Important only / All): train steps list the spell ranks your trainer has for you, from the client's own spell tables checked against your spellbook. Train steps with nothing new are skipped. Talent ranks only after the talent, class-quest spells listed apart, `/tbcg train` (defer, waypoint). Never buys anything (docs/TRAINER.md).
- **Talent suggestions in the talent window** (*Show Talent Suggestions*): numbered markers on your plan's next picks, a panel with the plan, deviations and what blocks the next pick, and tooltip lines. Follows your spec profile (21 of 28 have a plan). Never spends points (docs/TALENTS.md).
- **Route audit XP model:** QuestieDB TBC quest XP and the post-2.3 XP table, a per-character travel measure, and `docs/generated/level-gates.csv`.

### Removed
- The unfinished *Follow Party Leader Macro*, *Quest Sellable Recommendation* and *Always Show Total EP* options. The settings window has no greyed-out placeholders left.

## 0.7.0

### Added
- **Automatic upgrades** (opt-in, Tips → Automatic Upgrades). TBCGuide equips gear from your bags for the spec profile you choose.
  - **What it equips:** empty slots get any usable item; filled slots only a higher estimated spec score.
  - **Never:** in combat, with an open merchant, trade, bank, mail or auction window, or when the binding is unknown. **Never unbound Bind-on-Equip items.**
  - **How:** one change at a time, confirmed before an on-screen message (optionally also in chat).
  - **Protection:** protected slots, plus `/tbcg gear exclude <item>`.
  - Details: docs/AUTO_EQUIP.md.
- **BoE upgrade markers:** a green arrow on unbound Bind-on-Equip upgrades in the default bags. The tooltip says what it replaces and the estimated spec-score change, and that you need to equip it yourself.
- **Spec profiles for every spec:** Marksmanship and Survival Hunter, Discipline Priest, and Assassination and Subtlety Rogue, so all 28 specs have one; Feral cat and bear stay separate.
  - The Spec profile dropdown lists only your class and is saved per character.
  - Specs without published numbers use **estimated** weights for automatic upgrades, labelled as estimates.

- **Settings window features built** (all were greyed out before):
  - **General:**
    - Active Item window (click to use quest items);
    - Vendor Treasures (merchant items that are upgrades for your spec);
    - flight timers (each route is timed the first time you fly it);
    - Group Settings switch;
    - junk coin indicator in bags;
    - talent plan (`/tbcg talents plan`).
  - **Guide Routing:** choose single dungeons, *Select Recommended* and *Select all*.
  - **Targeting:** Active Target Frame (click-to-target buttons for the step's NPCs, optional party leader target).
  - **Leveling Tracker:** time per level from played time, XP per hour, a leveling report (`/tbcg tracker`), level splits with history, compare and total.
  - **Communications:** version checks, party announcements (completion, collection, flights; only to other TBCGuide users unless you allow it), automatic quest sharing.
  - **Tips:** map pins for elite/rare mobs and treasure chests.
  - **Advanced:** low-quality mode, pre-load item data.

### Changed
- **New look:** every TBCGuide window has a flat dark style with a blue accent.
  - Title bars; flat buttons, checkboxes, inputs, sliders and tabs.
  - The settings window has one tab row, and the guide window a slimmer progress bar.
- **Removed:** the Look and Feel tab, and the options that had nothing to act on (XP rate, Solo Self Found, beta features, hearthstone batching, quest log size).

### Fixed
- The shared event throttle could stop with an error when one throttled job scheduled another.

Not tested in the game client.

## 0.6.0

### Changed
- **Denser 1-30 routes:** 448 quests added across 25 guides, including class quests that used to be only a note on train steps, such as *Taming the Beast*, druid forms, totem quests and Voidwalker. Every added quest passed the compiler and route audit. Not tested in the game client.

## 0.5.0

### Fixed
- Horde *Trouble in the Deeps* is now turned in at Zoram'gar Outpost in Ashenvale, where its quest giver is. Before, the Stonetalon guide asked you to turn it in there, with an empty objective step. The note for *Amongst the Ruins* now says the Fathom Stone is inside Blackfathom Deeps.

### Added
- **Settings window** (`/tbcg options`, minimap button). It has two rows of tabs (General, Guide Routing, Targeting, Leveling Tracker, Communications, Tips, Help / Look and Feel, Advanced Settings, Profiles) with gold section headers, checkboxes, sliders, dropdowns, colour swatches and a key-binding button. Options that are planned but not built yet are shown greyed out and do nothing. See docs/SETTINGS.md.
- **Profiles:** create, switch, copy from, delete, reset, and set as default for new characters. Existing settings become the "Default" profile.
- **NPC automation:** flight path (fly to the guide's destination), innkeeper bind on bind steps, skip single-option gossip, and trainer automation (off by default). Hold Shift to skip.
- **Quest auto rewards** (off by default): only a clear gear-score upgrade, or the most valuable reward when your class can use none of them.
- **Junk:** a junk list (modifier + right-click in bags), a key binding that deletes the cheapest junk item, and optional discarding when bags are full. A master *Inventory Manager* switch covers all of them.
- **Routing:** skip overleveled (grey) quest pickups unless a later quest needs them, and *Disable step skips* for debugging.
- **Include Dungeon Quests** (Guide Routing; on by default): off leaves dungeon quest steps out of the route, skips follow-ups that need them and moves straight on. Quests already in your log keep their steps. The only guide quest that needs an instance, Horde Ashenvale *Amongst the Ruins* (Blackfathom Deeps), is now tagged. The compiler warns about untagged quests whose objectives are only inside instances.
- **Targeting:** mark friendly quest NPCs, allow or forbid marking in groups, a "TBCGuide" targeting macro, a note when a step NPC comes into view, and maximum nameplate distance.
- **Tips:** drowning and low-health warnings (sound, screen flash, thresholds) and rare-mob alerts.
- **Look and feel:** step text colours, guide font size, step list toggle, arrow scale and update rate.
- **Other:** world map button, level-up announcements (emote/party/guild, off by default), and a warning when another leveling guide add-on is loaded.


## 0.4.1

### Added
- **Minimap button.** Left-click opens the TBCGuide settings, and clicking again closes them. Right-click shows or hides the guide window. Drag it around the minimap; the position is saved when you let go and kept across reloads. Square minimaps from other add-ons are supported. *Show the minimap button* on the settings page and `/tbcg minimap` hide or show it; `/tbcg options` always opens settings. Native code, no libraries.

### Fixed
- **Raid markers marked almost nothing.** Only 5 guide steps carried a `[mark]`, and marking a step's kill objectives was off by default. It is now on by default. Settings saved by older versions are switched on once, with a chat note; `/tbcg set autoMarkObjectives off` turns it off.
- **After the first marked mob died, no other mob of that step was marked.** The game removes a dead mob's icon without an icon event, and the add-on kept waiting for the dead mob. Deaths are now read from the combat log (`UNIT_DIED`, only for units TBCGuide marked). A held icon is also released when its mob is visible without it, or has not been seen for 60 seconds. A dead mob losing its icon no longer pauses marking for the step.
- **Kill steps done together are covered at once.** The current step and the open `complete` steps right after it each get their own icon: default marker first, then skull, cross, square, and so on, at most 4. Icons stay with their mob type when one step finishes, and still-valid icons are not cleared and re-set on a step change.
- `/tbcg debug marks` shows the settings, each icon's NPCs, why there is no rule, and the last marking decision. Attempts and refusals go to the debug log.


## 0.4.0

### Added
- **Gear scoring.** Item tooltips compare an item with what you wear. Quest reward choices are ranked in chat; you still choose, and a reward is never picked automatically. `/tbcg gear` (also `/tbcgear`) lists equipped items, empty slots and upgrades in your bags.
- **Researched profiles:** stat weights come from wowsims/tbc and Icy Veins TBC pages, with sources, assumptions and confidence recorded in docs/GEAR_RESEARCH.md. Specs and levels without published numbers get a stat-by-stat comparison instead of an invented score. Level-70 weights are never applied to leveling characters automatically.
- **Caps and slots:** hit and expertise count only up to the profile's cap. Two-handers, dual wielding, off-hands, rings and trinkets, and class armor and weapon types are handled. Weapon DPS, sockets, equip effects and set bonuses are listed as not scored.
- *Gear* settings page and `/tbcg gear profiles`, `/tbcg gear profile <id|auto>`. See docs/GEAR_SCORING.md.


## 0.3.2

### Fixed
- **Missing class quests in the starting guides.** *Verdant Note* (tauren druid) was missing because only the Human guide had the level-1 class letters. All seven starting guides now have them: the *Note*, *Sigil*, *Parchment*, *Tablet*, *Scroll*, *Rune* and *Memorandum* letters, plus the blood elf and draenei *… Training* quests.
- Warlock starting quests added: *The Stolen Tome* (Elwynn), *Beginnings* (Dun Morogh), *Piercing the Veil* (Tirisfal) and *Windows to the Source* (Eversong).
- Durotar warlocks now do *Vile Familiars* (1499), which unlocks *Burning Blade Medallion*. Before this, the route sent warlocks to a quest they could not take.
- Shaman *Call of Earth* (Earth Totem) chains added in Durotar, Mulgore and Azuremyst.
- New regression test: every level-1 class quest a starting guide's races can take there must be in that guide exactly once. Audit and reasoning: docs/CLASS_QUEST_AUDIT.md.


## 0.3.1

### Added
- `grind` guide step: which mobs to kill, where, and until which level. It completes on reaching the level, like a `level` step, and is never based on XP. The compiler checks every mob against the bundled database and the step's zone. Example: Elwynn's level-10 gate now names the Riverpaw gnolls south of Westbrook Garrison.

### Fixed
- The earlier grind-step work completed grind steps as soon as they appeared, because of an XP check. It also added text on every window redraw, and three unused settings. Grind steps now complete on level only; the redraw text and unused settings are removed.


## 0.3.0

### Added
- **Raid markers.** `/tbcg mark [icon]`, `/tbcg unmark`, `/tbcg marker <icon>`, a marker bar (`/tbcg markbar`, secure click buttons), a *Raid markers* settings page and `/tbcg debug marks`.
- **Guide-driven marking:** new step flag `[mark=icon]`, `[mark=icon:<npc id>]` or `[mark=icon:<exact name>]`. The compiler resolves NPC IDs from the bundled data and fails on ambiguous names. Units are matched only by NPC ID. Each unit gets one attempt per step. Existing icons are not replaced by default. Changes made by the player are respected (automatic marking pauses), only TBCGuide's own icons are cleared when the step changes, and results are verified before "Marked" is reported. Permission is checked in raids. If the client blocks marking, it falls back to the marker bar.
- Example marks in Elwynn, Westfall, Durotar and Eversong. Optional `autoMarkObjectives` marks kill objectives with the default icon.

### Fixed
- Durotar *Vanquish the Betrayers*: the note now describes the real objectives (Kul Tiras sailors and marines, Lieutenant Benedict at Tiragarde Keep).


## 0.2.0

### Added
- **Quest automation.** Accepts and turns in quests that have an open step in the active guide. Escort and scripted-event quests are never auto-accepted (multiple signals, unknown means manual; no setting overrides it). A reward is never chosen when there is more than one. Success is reported only after the game confirms it. Hold Shift to skip once. On by default for guide quests.
- **Junk selling** at vendors: Poor-quality items only, with protected items and categories, and quest, quest-starting and guide-needed items always kept. Sales are counted only when confirmed, with a running total. **Off by default.**
- **Orphaned quests:** an *Orphaned (N)* button on the quest log, and `/tbcg orphans`. Lists quests that the active guide and the rest of the route will never turn in, and abandons the selected ones after confirmation.
- *Automation* settings page; commands `automation`, `orphans`, `protect`/`unprotect`/`protected`, `escort add|remove`, `debug escort <id>`.
- *Maximum-speed route* option (hides optional side quests).
- Route optimization model: `tools/build.ps1 routes` writes `docs/ROUTE_AUDIT.md` and fails the build on impossible quest order or quest-log overflow.
- `docs/AUTOMATION.md`, `docs/ROUTE_OPTIMIZATION.md`.

### Changed
- Routes: 26 impossible quest orders fixed (Horde, Draenei, Blood Elf, Netherstorm). About 90 pickups that were never turned in removed. 13 breadcrumbs now turned in where the route passes the recipient. Level gate added for Horde Feralas. Unreachable level-gated pickups removed. Peak quest log on the worst route went from 65 to 10. Details in docs/ROUTE_OPTIMIZATION.md.
- Optional turn-ins of breadcrumbs from an earlier guide are skipped when the quest is not in your log.
- Quest data import also exports `questFlags`.

### Fixed
- Test mocks (`tinsert`), so the headless test suite runs; it now runs as part of development (284 checks).

## 0.1.0
- First release.
