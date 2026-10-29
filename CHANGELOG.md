# Changelog

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
