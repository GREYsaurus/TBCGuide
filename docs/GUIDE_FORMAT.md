# Writing guides (`guides-src/*.guide`)

Guides are plain text, one step per line. `tools/build.ps1 guides` compiles them into `TBCGuide/Guides/Compiled/*.lua` and checks them against the bundled quest database. **Never edit the compiled files.**

Files are compiled in path order (`alliance/`, `horde/`, `outland/`, `shared/`, then file name). That order matters for the route checks: a turn-in in a later file can match an accept in an earlier one.

## Header

```
@guide A_Westfall                  unique id
@name Westfall                     display name
@faction Alliance                  Alliance | Horde | Both
@races Human,Dwarf                 optional; Night Elf / NightElf, Undead / Scourge, Blood Elf / BloodElf accepted
@classes Warrior                   optional; usually omitted
@levels 10-16                      intended level range
@zone Westfall                     zone name exactly as in the bundled zone table
@chapter Azeroth                   Azeroth | Outland
@start                             marks a racial starting guide (requires @races)
@desc Free text, can repeat to continue.
@next A_Redridge                   next guide; repeatable, first match wins
@next H_Feralas [faction=Horde]    conditions: [race=..] [class=..] [faction=..]
```

## Steps

```
<verb> <arguments> [flags] | <note text> [flags]
```

| Verb | Arguments | Completes when |
|---|---|---|
| `accept` | quest | quest is in the log or already turned in |
| `turnin` | quest | quest-completed flag / `QUEST_TURNED_IN` |
| `complete` | quest (`[obj=N]` for one objective) | quest log reports complete |
| `goto` | `x,y` (zone = guide zone, or `[zone=...]`) | arrow arrives within 12 yards, or manual |
| `talk` | NPC name or id | manual |
| `train` | - (expands to one step per class, with that class's trainer from the database) | trainer window closed |
| `fp` | place name | "New flight path discovered" or taxi map opened |
| `fly` / `hs` / `travel` | destination zone/subzone name | zone change to the destination, or manual |
| `bind` | inn location name | `GetBindLocation()` matches |
| `level` | level | player level reached |
| `grind` | `<level> <Mob>[, <Mob>...] [@ location]` | player level reached (same as `level`). Each mob must exist in the database and spawn in the step's zone, or the build fails. The arrow points at the spawn nearest the previous step unless `[at=x,y]` is given. Example: `grind 10 Riverpaw Outrunner, Riverpaw Runt @ south of Westbrook Garrison [at=27.8,81.2] \| note` |
| `note` / `buy` / `use` / `collect` | text | manual (`buy` also completes on closing a vendor) |
| `guide` | guide id | manual |

### Quest references

- `accept A Threat Within` - by name. The compiler finds the quest that fits the guide's faction and races, is not yet done on the route, and has its prerequisites met.
- `accept 783` - by id.
- `accept 783 A Threat Within` - id plus name. The compiler fails if they disagree, which catches typos.

If a name is ambiguous (e.g. the three "Rite of Vision" quests), the compiler stops and lists the candidate ids. Write the id.

### Flags

`[optional]`, `[elite]`, `[group]` or `[group=3]`, `[dungeon=Shadowfang Keep]`, `[class=Warrior,Paladin]`, `[race=Human]`, `[zone=Orgrimmar]`, `[at=x,y]` (explicit coordinates; marked unverified), `[obj=2]`, `[unverified]`, `[mark=skull]` / `[mark=cross:Lieutenant Benedict]` / `[mark=star:1234]` (raid marker; see docs/RAID_MARKERS.md). Separate several flags with `;` inside one bracket: `[elite; group=3; optional]`.

**Dungeon quests:** tag every step (accept, complete, turn-in) of a quest that can only be done inside an instance with `[dungeon=<instance>]`. The *Include Dungeon Quests* setting leaves tagged steps out of the route. Follow-up quests that need an excluded dungeon quest are skipped automatically, so don't tag those. Don't tag an outdoor quest that only sends you towards a dungeon (a breadcrumb, or objectives at the entrance). You rarely need to write the tag: the compiler tags a quest's steps itself when the bundled data puts every objective inside one dungeon or raid (the one authoritative mapping; audit in `docs/generated/dungeon-quests.csv`). A hand-written tag wins, for quests the data cannot place. Quests with only some objectives inside are listed in `docs/generated/dungeon-mixed.csv` and are not tagged.

### What the compiler adds for you

- the quest title, giver/finisher NPC name and coordinates (the spawn nearest the previous step);
- trainers, flight masters and innkeepers, looked up by NPC flags in the zone;
- a verification flag: `v=1` for database-derived data, `v=0` for hand-written coordinates.

### What the compiler checks

Errors (the build fails): unknown or ambiguous quests, quests not available to the guide's faction or races, class quests without `[class=]`, unknown zones or guides, malformed lines.

Warnings (`docs/generated/guide-warnings.log`): prerequisites not turned in anywhere on the route, turn-ins without an accept, quests whose required level is above the guide's range, repeatable quests, and complete-steps with no objective location in the data.

Write notes only when you are sure of them. For complete-steps, the add-on already shows the quest log objectives and the database objective text.

## Route checks (`tools/build.ps1 routes`)

After compiling, every race/class route is walked step by step (docs/ROUTE_OPTIMIZATION.md). The build fails if a quest is accepted before one of its prerequisites is turned in on that route, if a complete-step comes before its accept, or if the quest log would exceed 25. Accept a quest after the turn-in that unlocks it, and give every pickup a turn-in somewhere on the route.

An `[optional]` turn-in of a quest accepted in an **earlier** guide (a breadcrumb) is skipped automatically for players who do not have it in their log. A non-optional one is never auto-skipped.
