# Class quest audit (0.3.2)

How the starting guides were checked for class quests, what was added and what was left out on purpose. The source of truth is the bundled QuestieDB TBC data (`TBCGuide/Database/QuestieTBC`): quest IDs, races, classes, prerequisites, givers and drop sources were all looked up there. Nothing here has been tested in the game client yet.

## Why *Verdant Note* was missing

Every starting zone gives a level-1 class letter after the first quest (*Verdant Note* for tauren druids, from Grull Hawkwind after *The Hunt Begins*). Only the Human guide had them. The other six starting guides were written without them. Nothing in the build flagged it, because the compiler only checks quests a guide names, and the route audit only checks the order of prerequisites that are on the route.

## Method

1. Listed every class-restricted quest with required level 12 or lower from the database (class mask, races, giver and zone, prerequisites), and compared it with the compiled guides.
2. Added a regression test (`tests/run_tests.lua`). For every starting guide, each level-1 class quest must appear exactly once as accept and once as turn-in, if the guide's races can take it, its giver stands in the guide's zone and the guide hands in its prerequisite.
3. Rebuilt the guides. The compiler checked faction, race and class on every new step, and the route audit walked all 52 race/class routes for order, log size and level gates.

## Fixed (confirmed omissions)

| Class | Quests | Restriction | Guide | Problem → fix |
|---|---|---|---|---|
| Druid | 3094 *Verdant Note* | Tauren | Mulgore, after *The Hunt Begins* | Missing → accept after 747, turn in at Gart Mistrunner before training |
| Druid | 3120 *Verdant Sigil* | Night elf | Teldrassil, after *The Balance of Nature* | Missing → added |
| Warrior, Hunter, Shaman | 3091–3093 *Simple / Etched / Rune-Inscribed Note* | Tauren | Mulgore | Missing → added |
| All classes | 2383, 3087–3090 (*… Parchment*), orc; 3065, 3082–3086 (*… Tablet*), troll | Orc / Troll | Durotar, after *Cutting Teeth* | Missing → added with `[race=]` |
| All classes | 3095–3099 *… Scroll* | Undead | Tirisfal, after *The Mindless Ones* | Missing → added |
| All classes | 3106–3110 *… Rune*, dwarf; 3112–3115 *… Memorandum*, gnome | Dwarf / Gnome | Dun Morogh, after *Dwarven Outfitters* | Missing → added with `[race=]` |
| Warrior, Hunter, Rogue, Priest | 3116–3119 *… Sigil* | Night elf | Teldrassil | Missing → added |
| All classes | 8328, 8563, 8564, 9392, 9393, 9676 *… Training* | Blood elf | Eversong, after *Reclaiming Sunstrider Isle* | Missing → added |
| All classes | 9287–9291, 9421 *… Training* | Draenei | Azuremyst, at the crash-site trainers | Missing → added |
| Warlock | 1598 *The Stolen Tome* | Human | Elwynn | Missing starting warlock quest → added |
| Warlock | 1599 *Beginnings* | Gnome | Dun Morogh | Missing → added |
| Warlock | 1470 *Piercing the Veil* | Undead | Tirisfal | Missing → added |
| Warlock | 8344 *Windows to the Source* | Blood elf | Eversong | Missing → added |
| Warlock | 1499 *Vile Familiars* (Ruzan → Zureetha) | Orc | Durotar | Missing. *Burning Blade Medallion* (794) needs 792 **or** 1499, and warlocks get 1485 instead of 792, so warlocks could not take 794 → added |
| Shaman | 1516–1518 *Call of Earth* | Orc / Troll | Durotar | Missing level-4 Earth Totem chain → added |
| Shaman | 1519–1521 *Call of Earth* | Tauren | Mulgore | Missing → added |
| Shaman | 9449–9451 *Call of Earth* | Draenei | Azuremyst | Missing → added |

The level gates (level 4 for *Call of Earth*, level 2 for the draenei training quests) are checked by the route audit, which passes.

## Checked and left out on purpose

- ***Well Watcher Solanian*** (10068–10073, blood elf): these are breadcrumbs for *Solanian's Belongings* (8330), which the route accepts first, so they are no longer offered.
- ***Earth Sapta*** (1462, 1463): repeatable replacements for a lost sapta, not route quests.
- **Priest robe quests at level 5** (*In Favor of …* / *Garments of …*, *Cleansing the Scar*, *Help Tavara*): real class quests in the starting zones. They need you to heal and buff an NPC, and their reward is optional. **Possible omission:** a candidate for a later pass.
- **Level 10+ class chains** (warrior Defensive Stance, warlock Voidwalker, hunter taming, druid Bear Form, shaman *Call of Fire* / *Call of Water*, mage and rogue city quests): they send you to capital cities or other zones, and the guides intentionally cover them with a note on the `train` step instead of routing them. They were not added.
- Quests with level 0 or 1 that the database marks as unused or not a quest (for example 9599, 10638), and level-60 quests listed under a class (7668), are not part of leveling.

## What was not verified

- Nothing was run in the game client. The step text (for example "Spirit Rock", "Kodo Rock", the Earth Totem reward) follows the quest text in the database. The draenei *… Training* quests have no objective text in the database, so their notes only say where the trainer is.
- The route audit does not flag a prerequisite that is never on the route, because it could have been done elsewhere. That is how the warlock *Burning Blade Medallion* gap got through. The new regression test covers level-1 class quests in the starting guides only.
