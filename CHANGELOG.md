# Changelog

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
