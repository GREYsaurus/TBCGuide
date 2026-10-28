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
| `note` / `buy` / `use` / `collect` | text | manual (`buy` also completes on closing a vendor) |
| `guide` | guide id | manual |

### Quest references

- `accept A Threat Within` - by name. The compiler finds the quest that fits the guide's faction and races, is not yet done on the route, and has its prerequisites met.
- `accept 783` - by id.
- `accept 783 A Threat Within` - id plus name. The compiler fails if they disagree, which catches typos.

If a name is ambiguous (e.g. the three "Rite of Vision" quests), the compiler stops and lists the candidate ids. Write the id.

### Flags

`[optional]`, `[elite]`, `[group]` or `[group=3]`, `[dungeon=Shadowfang Keep]`, `[class=Warrior,Paladin]`, `[race=Human]`, `[zone=Orgrimmar]`, `[at=x,y]` (explicit coordinates; marked unverified), `[obj=2]`, `[unverified]`. Separate several flags with `;` inside one bracket: `[elite; group=3; optional]`.

### What the compiler adds for you

- the quest title, giver/finisher NPC name and coordinates (the spawn nearest the previous step);
- trainers, flight masters and innkeepers, looked up by NPC flags in the zone;
- a verification flag: `v=1` for database-derived data, `v=0` for hand-written coordinates.

### What the compiler checks

Errors (the build fails): unknown or ambiguous quests, quests not available to the guide's faction or races, class quests without `[class=]`, unknown zones or guides, malformed lines.

Warnings (`docs/generated/guide-warnings.log`): prerequisites not turned in anywhere on the route, turn-ins without an accept, quests whose required level is above the guide's range, repeatable quests, and complete-steps with no objective location in the data.

Write notes only when you are sure of them. For complete-steps, the add-on already shows the quest log objectives and the database objective text.
