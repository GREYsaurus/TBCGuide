# Talent suggestions in the talent window

Setting: **Show Talent Suggestions** (General → Talents, on by default). In the default talent window (press N) TBCGuide adds:

- **Numbered markers** (1, 2, 3) on the next picks of your plan in the tree you are viewing; pick 1 also glows.
- **A panel** beside the window:
  - the plan's name and its next three picks (tree, rank, level);
  - why the next pick cannot be taken yet (tier points or a prerequisite missing);
  - how far your talents differ from the plan, and your unspent points;
  - the plan's source.
- **A tooltip line** on talents: "pick N of your plan", "your plan takes X/Y", or "not in your plan".

**TBCGuide never spends a talent point.** There is no `LearnTalent` call anywhere in the add-on; you click the talent yourself.

## Which plan

The plan follows the **spec profile** you picked (setup window, or Settings → Tips → Spec profile), as mapped in `TBCGuide/Talents/ProfileBuilds.lua`.

- Below level 70 the spec's leveling plan is used, at 70 its level-70 plan. A spec with only one plan uses it all the way, since every plan's point order starts at level 10.
- **Without a spec profile:** the build chosen in the TBCGuide talent window (`/tbcg talents`), or your class's leveling build.
- **Spec with no plan:** the panel says so plainly and nothing is marked.

**Deviation:** if you spent points elsewhere, the panel counts them and suggestions continue with the plan's next missing pick. If that pick is now blocked (not enough points in its tree, or a prerequisite missing), the panel says what it needs.

**Matching** is by tree, tier and column from the client's own talent data, never by name, so every client language works.

## Coverage

| Class | Spec (profile) | Plan | Points | Validation |
|---|---|---|---|---|
| Warrior | Arms | Arms (leveling) | 61 (levels 10-70) | ranks, tiers, prerequisites against client data |
| Warrior | Fury | Fury (level 70 raid DPS) | 61 (levels 10-70) | same |
| Warrior | Protection | Protection (level 70 tank) | 61 (levels 10-70) | same |
| Paladin | Retribution | Retribution (leveling) | 61 (levels 10-70) | same |
| Paladin | Holy | Holy (level 70 healer) | 61 (levels 10-70) | same |
| Paladin | Protection | Protection (level 70 tank) | 61 (levels 10-70) | same |
| Hunter | Beast Mastery | BM (leveling) below 70, BM (70) at 70 | 61 (levels 10-70) | same |
| Hunter | Marksmanship | **no plan** | - | - |
| Hunter | Survival | **no plan** | - | - |
| Rogue | Combat | Combat Swords (leveling) | 61 (levels 10-70) | same |
| Rogue | Assassination | Mutilate (level 70) | 61 (levels 10-70) | same |
| Rogue | Subtlety | **no plan** | - | - |
| Priest | Shadow | Shadow (leveling) | 61 (levels 10-70) | same |
| Priest | Holy | Holy (level 70 healer) | 61 (levels 10-70) | same |
| Priest | Discipline | **no plan** | - | - |
| Shaman | Enhancement | Enhancement (leveling) | 61 (levels 10-70) | same |
| Shaman | Elemental | Elemental (level 70) | 61 (levels 10-70) | same |
| Shaman | Restoration | Restoration (level 70 healer) | 61 (levels 10-70) | same |
| Mage | Frost | Frost (leveling / AoE) | 61 (levels 10-70) | same |
| Mage | Fire | Fire (level 70 raid DPS) | 61 (levels 10-70) | same |
| Mage | Arcane | **no plan** | - | - |
| Warlock | Affliction | Affliction (leveling) | 61 (levels 10-70) | same |
| Warlock | Destruction | Destruction (level 70 raid DPS) | 61 (levels 10-70) | same |
| Warlock | Demonology | **no plan** | - | - |
| Druid | Feral (cat and bear) | Feral (leveling, cat and bear) | 61 (levels 10-70) | same |
| Druid | Balance | Balance (level 70 DPS) | 61 (levels 10-70) | same |
| Druid | Restoration | **no plan** | - | - |

21 of 28 spec profiles have a plan (Feral cat and bear share one); 7 are marked **no plan**. The tests check every plan: no rank above the talent's maximum, no point before its tier unlocks, prerequisites met, no more than 61 points (`tests/test_talent_hints.lua`).

## Source

**Every plan is TBCGuide's own build, not taken from Icy Veins or Wowhead.** Each was written for this project and checked point by point against the client's talent data. The panel says this on every plan.

Plans sourced from Icy Veins or Wowhead TBC, with attribution, were requested but are **not done**: comparing each plan level by level with those guides needs research per spec. The 7 specs without a plan are in the same position. Both are listed under Limitations.

## Limitations

- **Not run in the game yet.** The window names used come from the default UI of the Classic clients: `PlayerTalentFrame`, `PlayerTalentFrameTalent1..40`, `PlayerTalentFrame_Update` and `PanelTemplates_GetSelectedTab`. Each is checked before use. If 2.5.6 names them differently, the markers and panel do not appear, while the tooltip line (hooked on `GameTooltip:SetTalent`) still works. In-game checklist: `docs/COMPATIBILITY.md` → Talent window.
- **No external sources:** plans are not compared with Icy Veins or Wowhead.
- **7 specs have no plan.**
- **No respec advice:** a Hunter changing from the BM leveling plan to the BM 70 plan at 70 is not told to respec.
