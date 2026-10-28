# Known limitations

Stated plainly, so nobody mistakes "files exist" for "finished and tested".

## Testing

- **0.1.0 has been played in the client by the author; the 0.2.0 additions have not.** Quest automation, junk selling, the orphaned-quest window and the route changes are verified only by the offline tools and by 284 headless tests (real Lua 5.1, mocked client APIs). The mocks model the APIs as documented and as Questie uses them on interface 20506; real client behaviour may differ. Checklist: `docs/COMPATIBILITY.md`.

## Automation

- **Escort detection is conservative.** Any escort signal makes a quest manual (see `docs/AUTOMATION.md`), so some non-escort event quests (e.g. totem "cleansing" quests flagged party-accept) also need a click. That is deliberate.
- **Old-style greeting windows** may not expose quest IDs. Then a quest is matched by title only when exactly one open guide step has that title; otherwise it stays manual.
- **Junk selling sells only Poor (grey) items.** It never sells cheap whites or greens, and has no "sell unwanted gear" mode.
- **Turn-ins with exactly one reward** are completed automatically (the default UI pre-selects a single reward). Two or more always wait for you.
- **Quests that cost money** to complete, quests shared by players and party escort confirmations are always left to you.
- **Orphaned quests** are judged against the active guide and the `@next` chain from it. If you leveled off-route or use a guide that is not on your race's chain, quests may be listed that you still want; nothing is abandoned without your confirmation.

## Raid markers

- **Not run in the client yet.** Marking behaviour is tested headless only (mocked APIs that model the documented rules).
- If 2.5.6 restricts `SetRaidTarget` to secure code (as Retail 12.0 does), automatic and slash-command marking are blocked. TBCGuide detects that, switches automatic marking off, and the click-driven marker bar remains.
- Icons can only be cleared on units you can currently see (target, mouseover, focus, nameplates).
- Automatic marking only reacts to units you look at; it never searches for or targets units itself.

## Guides

- **Route speed is unmeasured.** The route audit (`docs/ROUTE_AUDIT.md`) proves every route is completable in order, never overfills the quest log, and has no pickup that is never turned in. But no route has been timed, and no XP-per-hour figure is claimed. Possible issues:
  - **XP sufficiency.** Guides contain the core quests of each zone, not every quest. Some players will need to grind (there are `level` gate steps) or do extra quests.
  - **Travel notes** (boats, zeppelins, flight paths) are written from general knowledge and are not machine-checked.
  - **Travel order** inside a zone is not reordered automatically. Hub revisits are measured (438) but are left for play-tested tuning.
  - **20 mild level-gated pickups** remain, mostly in start zones (listed in the audit).
- **Some steps have no navigation target.** About 70 complete-steps (escorts, talk-to and event quests) have no objective location in the data, so the arrow cannot point at them. The text still explains the step.
- **Alternative prerequisite chains.** A few accept-steps depend on a quest from another zone or route (listed in `docs/generated/guide-warnings.log`). At runtime the engine auto-skips quests the character cannot take for race, class or exclusivity reasons, but **not** for unmet prerequisites. The step stays open and can be skipped by hand. (Within each race/class route, prerequisite order is now checked by the build.)
- **Undead and Blood Elf characters join the Barrens guide at 18-20.** Its first part will be low level for them. The selector starts them at the right guide, but within it they may want to skip the lowest quests.
- **Not covered:** professions, dungeon walkthroughs (only dungeon quest hints), PvP and battleground leveling, reputation grinds, attunements. Alternative zones (Desolace, Swamp of Sorrows, Badlands, Searing Gorge, Blasted Lands, Azshara, Eastern Plaguelands, Winterspring, Silithus, Burning Steppes for Horde) are not separate guides.
- **Class quests** are only partly included: letters, Vile Familiars and some trainer hints. Most class-quest chains (e.g. warrior stance quests, shaman totems, druid forms, warlock pets) are mentioned in class tips but are not step-by-step.

## Quest database

- Derived from **QuestieDB v1.0.9** (TBC). Upstream data may contain errors; we fix nothing in it without a source (`Database/Overrides.lua` is empty).
- **5 upstream corrections were skipped** because they depend on the player's class or race at runtime (see `docs/generated/questie-import.log`). Faction-specific correction tables (`LoadFactionFixes`) were not applied.
- **Licensing:** see THIRD_PARTY_LICENSES.md. To build a release **without** the QuestieDB-derived database:
  1. Remove the five `Database\QuestieTBC\*.lua` lines from `TBCGuide.toc`.
  2. Delete the `Database/QuestieTBC` folder from the package.

  Guides still work because compiled guides carry their own quest ids, names, NPCs and coordinates. However, those values are themselves derived from the same data. A fully clean build would need guides re-compiled against a different data source.

## Talents

- Builds are **legal** (verified against client tables) but their **quality** is the project's judgement and is untested. Talent descriptions come from the client tooltip at runtime.
- Reading your actual talents works only for your own class (TBC API limit). Talents are mapped by tree, tier and column. If the client orders trees differently from the data, `/tbcg debug talents` reports mismatches.
- The calculator does not apply talents to your character (no auto-learn). That is deliberate.

## UI and navigation

- The arrow and map pin use stock client textures. Rotation and pin placement are unverified in-game.
- The arrow needs `GetPlayerFacing` and `C_Map` world-position functions. In instances, or if they are missing, it shows plain coordinates.
- No minimap pins of its own. Use TomTom for those.
- The options panel uses the new Settings API if present, otherwise the legacy one. Which one 2.5.6 has is unverified.

## Advice text

- `Classes/ClassAdvice.lua` is marked `status = "unverified"`. Ability names and training levels are from developer knowledge, not client data.
