# Talent plans and talent-window suggestions

## What the player sees

Setting: **Show Talent Suggestions** (General → Talents, on by default). In the default talent window (N):

- **Markers:** numbered markers (1, 2, 3) on the plan's next picks in the tree you're viewing; pick 1 glows.
- **A panel beside the window:**
  - the plan and its next three picks (tree, rank, level);
  - what blocks the next pick, if anything (tier points or a prerequisite);
  - how many points you spent off-plan;
  - unspent points;
  - where the plan comes from.
- **A tooltip line on each talent:** "pick N of your plan", "your plan takes X/Y", or "not in your plan".
- **Never spends a point.** TBCGuide never spends a point, resets talents or buys a respec; there is no `LearnTalent` call anywhere.
- **Off-plan points:** the panel counts them, suggestions continue with the plan's next missing pick, and the panel says that matching the plan exactly would need a respec.

**Matching:** talents are matched by client talent id, tree, tier and column, never by name, and names come from the client in its language. Plans store client talent ids (`{talentId, points}`).

## Which plan

The plan follows the **spec profile** (setup window, or Settings → Tips → Spec profile). It is the same profile that gear scoring, automatic upgrades and the auction tab use; no second spec system exists.

- **One plan per spec:** each spec has one plan, from the first talent point at level 10 through 70, with no forced respec (`TBCGuide/Talents/ProfileBuilds.lua`).
- **Frost variants:** Frost defaults to AoE; the single-target plan can be chosen in the TBCGuide talent window (`/tbcg talents`). That choice is saved per character and only applies while it belongs to your spec.
- **Without a spec profile:** the build chosen in the TBCGuide talent window is used, or else the class's first leveling plan.
- **Gear scoring is untouched:** changing or choosing a talent plan never changes gear-scoring weights.
- **Old saved choices:** build ids saved per character before this change (for example `warrior_arms_leveling`) resolve to their replacement (`Talents.ALIASES`).

## Source policy

Every plan comes from the guides linked from the Icy Veins TBC Classic leveling index (https://www.icy-veins.com/tbc-classic/leveling-guides) except Assassination, for which no build was found (see the mapping).

**Where the point order comes from:** each guide's build is a talent-calculator link (`...talent-calculator#tc-<points>`). The Icy Veins calculator script (`tbc-talent-calculator-*.js`, read on 2026-10-29) shows that the string is the **ordered list of points**, one character per point, in the order they were added. Characters map to talents through the calculator's own talent table, which carries each talent's rank-1 spell id.

**How TBCGuide uses it:**
1. Read each guide's point string from its page (`data-talentcalculator-pointsurl`).
2. Map every character to its rank-1 spell, then to the client's talent id.
3. Use that order as the plan's leveling order: point 1 at level 10, one point per level.

So the order is the source's own, except where noted below. No guide prose is copied; the add-on stores only talent ids and point counts.

## Mapping (class → profile → source → plan)

All guides were last updated by Icy Veins on 2026-01-12 (page metadata).

| Class | TBCGuide profile(s) | Icy Veins source (leveling index) | Plan id | Trees | Order |
|---|---|---|---|---|---|
| Druid | Balance | balance-druid-leveling-guide | druid_balance_iv | 47/0/14 | source |
| Druid | Feral cat, Feral bear | feral-druid-leveling-guide (one guide for both) | druid_feral_iv | 0/47/14 | source |
| Druid | Restoration | restoration-druid-leveling-guide | druid_resto_iv | 0/0/61 | source |
| Hunter | Beast Mastery | beast-mastery-hunter-leveling-guide | hunter_bm_iv | 47/14/0 | source |
| Hunter | Marksmanship | marksmanship-hunter-leveling-guide | hunter_mm_iv | 16/45/0 | source |
| Hunter | Survival | survival-hunter-leveling-guide | hunter_sv_iv | 5/12/44 | source |
| Mage | Arcane | arcane-mage-leveling-guide | mage_arcane_iv | 61/0/0 | source |
| Mage | Fire | fire-mage-leveling-guide | mage_fire_iv | 11/47/3 | source |
| Mage | Frost (default) | frost-aoe-mage-leveling-guide | mage_frost_aoe_iv | 18/0/43 | source |
| Mage | Frost (variant) | frost-single-target-mage-leveling-guide | mage_frost_st_iv | 10/0/51 | source |
| Paladin | Holy | holy-paladin-leveling-guide | paladin_holy_iv | 43/11/7 | source |
| Paladin | Protection | protection-paladin-leveling-guide | paladin_prot_iv | 11/50/0 | source |
| Paladin | Retribution | retribution-paladin-leveling-guide | paladin_ret_iv | 5/10/46 | source |
| Priest | Discipline | discipline-priest-leveling-guide | priest_disc_iv | 41/20/0 | source |
| Priest | Holy | holy-priest-leveling-guide | priest_holy_iv | 20/41/0 | source |
| Priest | Shadow | shadow-priest-leveling-guide (first, 61-point build) | priest_shadow_iv | 14/0/47 | source |
| Rogue | Combat | combat-rogue-leveling-guide | rogue_combat_iv | 20/41/0 | source |
| Rogue | Subtlety | subtlety-rogue-leveling-guide | rogue_sub_iv | 20/0/41 | source |
| Rogue | Assassination | **none found** (see gaps) | rogue_mutilate_70 (TBCGuide's own) | 41/20/0 | TBCGuide |
| Shaman | Elemental | elemental-shaman-leveling-guide | shaman_ele_iv | 41/0/20 | source |
| Shaman | Enhancement | enhancement-shaman-leveling-guide | shaman_enh_iv | 17/44/0 | source |
| Shaman | Restoration | restoration-shaman-leveling-guide | shaman_resto_iv | 0/5/56 | source |
| Warlock | Affliction | affliction-warlock-leveling-guide (Unstable Affliction build) | warlock_aff_iv | 44/17/0 | source |
| Warlock | Demonology | demonology-warlock-leveling-guide | warlock_demo_iv | 20/41/0 | source order, applied from level 10 (see below) |
| Warlock | Destruction | not on the leveling index. Uses destruction-warlock-dps-pve-spec-builds-talents, "Shadow and Fire Destruction" | warlock_destro_iv | 0/19/40 (59 points) | source |
| Warrior | Arms | arms-warrior-leveling-guide | warrior_arms_iv | 35/26/0 | source |
| Warrior | Fury | fury-warrior-leveling-guide | warrior_fury_iv | 18/43/0 | source |
| Warrior | Protection | protection-warrior-leveling-guide | warrior_prot_iv | 13/5/43 | source |

Level-by-level listings of every plan: `docs/generated/talent-plans.md`. The plan data is `TBCGuide/Talents/Builds/IcyVeins.lua`.

## Source context and our decisions

- **Demonology:** the guide's single build is headed "Felguard Leveling Build (50-70)", and the page says to level as Affliction before 50. The build's own point string starts in Demonology and runs all 61 points legally from the first. TBCGuide applies that order **from level 10**, so there is no Affliction phase and no respec. Applying the 50-70 build from level 10 is our decision, not the source's instruction.
- **Restoration Druid and Restoration Shaman:** the guides present healing builds and suggest a damage spec for solo questing. They are used as the leveling plan for those profiles, as chosen.
- **Shadow Priest:** the page has a second, 30-point build that puts Discipline first. Its 61-point Shadow build is used.
- **Frost AoE Mage:** the page has a second, 12-point calculator. Its 61-point build is used.
- **Affliction:** the page also shows a Shadow Mastery / Demonic Sacrifice build. The Unstable Affliction build (the page's main leveling build) is used.
- **Feral:** the index has one Feral leveling guide. It is used for both the cat and the bear profile.
- **Destruction:** no Destruction leveling guide on the index. The related Destruction PvE builds page has a matching build, used here. Its calculator string spends **59** points (two unspent at 70). The plan keeps 59 points and ends two points early; no points were invented. The validator and tests allow exactly this one exception.

## Validation (static, point by point)

Every plan was checked against the client's talent data (`Talents/Data/TalentTrees.lua`, client build 2.5.6.70577) at three points: when decoded, by `tools/build.ps1 validate`, and by the headless tests.

Checks at every point, in order:
- talent exists for the class;
- rank ≤ the talent's maximum;
- 5 × (tier − 1) points already in its tree;
- prerequisite talent at the required rank;
- one point per level from 10;
- total ≤ 61.

| Result | Plans |
|---|---|
| 61 points, every point legal | 26 Icy Veins plans, plus Assassination (TBCGuide's own) |
| 59 points, every point legal | Destruction (source spends 59) |
| Errors | none |

**Source corrections needed:** none. No point string contained an impossible allocation. Characters outside the calculator's table (none in the leveling guides; `=` padding on some PvE build pages) are ignored, exactly as the calculator itself ignores them.

## Differences from the previous plans

The old TBCGuide builds were written for this project and were not taken from Icy Veins. They were replaced, keeping the old ids as aliases. In the table, "points that differ" means final points in a different talent.

| Plan | Previous | Trees before → after | Final points that differ |
|---|---|---|---|
| Balance | druid_balance_70 | 47/0/14 → 47/0/14 | 9 |
| Feral | druid_feral_leveling | 0/43/18 → 0/47/14 | 5 |
| Beast Mastery | hunter_bm_leveling | 45/16/0 → 47/14/0 | 5 |
| Fire | mage_fire_70 | 10/48/3 → 11/47/3 | 3 |
| Frost AoE | mage_frost_leveling | 20/0/41 → 18/0/43 | 19 |
| Holy Paladin | paladin_holy_70 | 41/20/0 → 43/11/7 | 22 |
| Protection Paladin | paladin_prot_70 | 13/48/0 → 11/50/0 | 17 |
| Retribution | paladin_ret_leveling | 17/0/44 → 5/10/46 | 18 |
| Holy Priest | priest_holy_70 | 15/41/0 → 20/41/0 | 6 |
| Shadow | priest_shadow_leveling | 15/0/40 → 14/0/47 | 13 |
| Combat | rogue_combat_leveling | 19/42/0 → 20/41/0 | 10 |
| Elemental | shaman_ele_70 | 45/0/16 → 41/0/20 | 13 |
| Enhancement | shaman_enh_leveling | 20/41/0 → 17/44/0 | 15 |
| Restoration Shaman | shaman_resto_70 | 0/17/44 → 0/5/56 | 15 |
| Affliction | warlock_aff_leveling | 41/20/0 → 44/17/0 | 11 |
| Destruction | warlock_destro_70 | 0/21/40 → 0/19/40 | 17 |
| Arms | warrior_arms_leveling | 45/16/0 → 35/26/0 | 11 |
| Fury | warrior_fury_70 | 17/44/0 → 18/43/0 | 14 |
| Protection Warrior | warrior_prot_70 | 5/15/41 → 13/5/43 | 19 |

New, with no previous plan: Restoration Druid, Marksmanship, Survival, Arcane, Frost single-target, Discipline, Subtlety, Demonology.

**Removed:** the old Hunter BM level-70 build; one BM plan now runs 10-70.

## Gaps

- **Assassination Rogue:** no Assassination leveling guide on the Icy Veins TBC leveling index. The Rogue class overview has no build, and the Rogue PvE builds page lists only Combat builds. The profile keeps TBCGuide's own Mutilate plan, labelled in the panel as TBCGuide's, not Icy Veins'. Wowhead was not used.
- **Destruction:** sourced from the PvE builds page, not a leveling guide (above).

## In-game checklist (not yet done)

- [ ] **Profile switching:** change the spec profile with the talent window open. The markers and panel switch to the new plan, and gear weights in item tooltips follow the profile, not the talent plan.
- [ ] **Frost:** choose "Frost single-target" in `/tbcg talents`. The talent window follows it; choosing a Fire plan there does not override a Frost profile.
- [ ] **Spent points:** on a character with points spent along the plan, pick 1 is the first missing point. With off-plan points, the panel shows the count and mentions a respec, and nothing changes on its own.
- [ ] **Several unspent points:** markers 1-3 show the next three distinct talents.
- [ ] **Talent reset at a trainer:** after the reset, the markers restart at pick 1. TBCGuide never initiates the reset.
- [ ] **Localization:** on a German or French client, markers sit on the right talents (matched by position and id), and tooltip lines appear on the right talents.
- [ ] **Saved choice:** a character that had an old build selected (for example Arms leveling) still gets the Arms plan after updating.
- [ ] **Demonology:** at level 10 the first marker is in Demonology (Demonic Embrace).
