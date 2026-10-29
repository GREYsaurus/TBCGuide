# Dungeon quests

## One mapping

A step belongs to a dungeon when it carries `dungeon=<instance>`. That comes from one place: the guide compiler (`tools/src/GuideCompiler.cs`).

- **From data:** when the bundled QuestieDB data puts **every** objective of a quest inside one dungeon or raid, the compiler tags its accept, complete and turn-in steps itself. Objectives here are kill targets, objects, and the NPCs or objects that drop quest items.
- **By hand:** `[dungeon=...]` in the guide source wins, for quests the data cannot place (objectives without spawn data).
- **Not tagged:** quests with only some objectives inside an instance. These are listed for review in `docs/generated/dungeon-mixed.csv`. Breadcrumbs that only send you to an entrance are not tagged either.

Raids count as instances for this purpose, so a raid-only quest is tagged and left out with the dungeons.

## Filtering

- **Include Dungeon Quests** off, or the dungeon switched off under Guide Routing → Dungeons: the tagged steps are left out.
- Quests already in your log or already turned in stay in the route.
- **Follow-up quests** that need an excluded dungeon quest are skipped with the reason "needs a dungeon quest", so no step waits on a quest you will not do (`Core/Engine.lua`, `NeedsExcluded`).

## XP

The route audit's XP model (`tools/src/RouteAnalyzer.cs`) gives **no XP for dungeon quest turn-ins** and none for dungeon kills. Level gates and the "needs level" skips therefore hold for players who skip dungeons. Players who do the dungeons will be ahead of the model.

## Audit (levels 1-30, this build)

| What | Count | Source |
|---|---|---|
| Dungeon quests on the routes | 1 (*Amongst the Ruins*, Blackfathom Deeps, Horde Ashenvale; 3 steps) | hand tag |
| Untagged route quests whose data puts every objective inside an instance | 0 | `docs/generated/dungeon-quests.csv` (empty) |
| Route quests with some objectives inside an instance | 2: *Bartolo's Yeti Fur Cloak* (565), *Grimtotem Spying* (5064). Both can be finished outdoors; not tagged. | `docs/generated/dungeon-mixed.csv` |

The 1-30 routes are built for solo questing, so they contain almost no dungeon quests. The 31-60 numbers are in `docs/LEVELS_31_60.md`.
