# Hunter pet skills and warlock demon skills

**Commands:**
- `/tbcg pet` shows the list.
- `/tbcg pet defer` hides reminders until your next level.
- `/tbcg pet waypoint` points the arrow at the nearest pet trainer (hunter) or demon trainer (warlock).

**Where it shows:** train steps also list up to three entries, under the same setting as the class trainer suggestions (*Class Trainer Suggestions*: Off / Important only / All).

**Advice only:** TBCGuide never tames, stables, abandons or summons pets, and never buys or uses Grimoires.

## How each class learns them (client 2.5.6)

| | Hunter pets | Warlock demons |
|---|---|---|
| Who learns first | The **hunter** learns a skill rank: general skills (Growl, Great Stamina, Natural Armor, the resistances) from a pet trainer; others by taming a beast that already knows the rank. | No separate first step. |
| How the pet gets it | Taught in the **Beast Training** window. Costs the pet's **training points**, not gold. | Using a **Grimoire** (bought from a demon trainer) while that demon is summoned. Costs gold. |
| What limits it | Pet level, pet family, training points | Warlock level (the Grimoire's required level) |
| First rank | Innate or taught | The demon knows it when summoned (no Grimoire exists) |

## Data

`TBCGuide/Classes/PetData.lua` is generated from the client tables (`tools/src/PetTables.cs`, `tools/build.ps1 import-client`):

| What | From | Count |
|---|---|---|
| Tameable families and their own skills | CreatureFamily + SkillLineAbility | 23 families |
| Hunter pet skills (rank, level) | SkillLineAbility, Spell, SpellLevels | 140 skills (67 general) |
| Demon skills | SkillLineAbility (Imp, Voidwalker, Succubus, Felhunter, Felguard) | 88 |
| Grimoire for each rank | ItemSparse (name, base price, required level) + ItemEffect + SpellEffect (learn spell) | 83 |

Old Grimoire items that teach nothing in this client are ignored. Helper spells, scaling auras, the old pet talents and hunter talents are left out.

## What TBCGuide can see, and what it cannot

| State | How | If unavailable |
|---|---|---|
| Active pet's skills and ranks | the pet spellbook (`HasPetSpells`, `GetSpellBookItemName`) | "call your pet" / "this client does not show the pet spellbook" |
| Hunter pet family | which family-only skills the pet has; the English family name on English clients | general skills only, said plainly |
| Skills the hunter knows, and training-point costs | only while **Beast Training** is open (`GetCraftInfo`). Recognised by its contents, so Enchanting's window is never mistaken for it. Remembered per character. | the advice says "open Beast Training once" |
| Pet training points | `GetPetTrainingPoints` | not shown |
| Skills a demon knows | only while that demon is summoned; remembered per character | "summon your Voidwalker once"; no Grimoire is suggested for a demon never seen |
| Grimoires you already carry | bag scan | not marked |
| Skills of pets in the stable | **not visible** | not covered |

## Prices

Grimoire prices are the item's **base** price from the client data. A reputation discount can lower what you pay, and the text says so. Training points are shown separately from gold.

## Limitations

- **Beast sources:** which beasts teach which hunter skill rank is not in the client tables, so TBCGuide names no specific beast to tame.
- **Untested here:** the pet trainer list of general skills is general game knowledge, untested in 2.5.6.
- **Family detection:** a hunter pet with no family-only skill yet, on a non-English client, gets general-skill advice only.
- **Not in game yet:** none of this has been run in the game. Tests: `tests/test_costs_pets.lua`, against mocked pet spellbook, Beast Training and bag APIs.
