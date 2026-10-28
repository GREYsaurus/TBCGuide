# Known limitations

Stated plainly, so nobody mistakes "files exist" for "finished and tested".

## Testing

- **Never run in the game client.** The add-on was built without access to WoW. The checks that did run are Lua 5.1 syntax parsing, the global/API lint, the guide compiler (quest resolution against the database) and content validation. Runtime behaviour (frames, events, arrow maths, map pins, talent API mapping) is unverified.
- **The Lua unit-test harness (`tests/`) has not been executed.** No Lua interpreter was available in the build environment (downloading one was blocked). It may itself contain bugs.

## Guides

- **Route quality is unproven.** Every quest step resolves to a real TBC quest with the right faction and race, and every route reaches 70 on paper. But nobody has played the routes. Possible issues:
  - **XP sufficiency.** Guides contain the core quests of each zone, not every quest. Some players will need to grind (there are `level` gate steps) or do extra quests.
  - **Travel notes** (boats, zeppelins, flight paths) are written from general knowledge and are not machine-checked.
  - **Quest ordering** inside a zone may not be optimal.
- **Some steps have no navigation target.** About 70 complete-steps (escorts, talk-to and event quests) have no objective location in the data, so the arrow cannot point at them. The text still explains the step.
- **Alternative prerequisite chains.** A few accept-steps depend on a quest from another zone or route (listed in `docs/generated/guide-warnings.log`). At runtime the engine auto-skips quests the character cannot take for race, class or exclusivity reasons, but **not** for unmet prerequisites. The step stays open and can be skipped by hand.
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
