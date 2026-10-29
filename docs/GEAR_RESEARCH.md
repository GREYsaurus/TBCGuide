# Gear scoring: research record

Research for TBCGuide's gear scoring (Step B). All pages were read on **2026-10-28** unless noted. This file records where every number and priority came from, what each source assumes, and how confident we are that it applies. It is the source of truth for `TBCGuide/Gear/Profiles.lua`. How the engine uses the profiles is described in [GEAR_SCORING.md](GEAR_SCORING.md).

Nothing here has been checked in the game client. Confidence describes the **evidence**, not in-game accuracy.

## 1. Sources consulted

| # | Source | What it gives | Version / date | Access |
|---|---|---|---|---|
| S1 | wowsims/tbc (github.com/wowsims/tbc), `ui/<spec>/sim.ts`, field `epWeights`, commit `3301fca` (2026-08-06), MIT licence | **Numbers.** Default EP weights per sim, in rating units, normalised to AP, RAP or SP = 1 | TBC 2.4 mechanics; level-70 raid presets (P1 or P4 gear), full raid buffs | Cloned and read directly |
| S2 | Icy Veins TBC Classic stat pages, `icy-veins.com/tbc-classic/<spec>-pve-stat-priority` (25 pages) | Priority lists, caps and rating conversions. **Numbers** only for Rogue, Warlock (×3) and Restoration Shaman | Most say "Reviewed/Updated for TBC Anniversary" (Jun–Dec 2025); several were last changed 2021–2022 | Read in the built-in browser (WebFetch gets 403) |
| S3 | Wowhead TBC stat pages, `wowhead.com/tbc/guide/classes/<class>[/<spec>]/<role>-stat-priority-attributes-pve` (17 pages + Rogue) | Priority lists and caps. **Numbers** only for Rogue (AP equivalents) | Modified Dec 2025 – Aug 2026; written for TBC Classic 2.5.x | Read in the built-in browser. Wowhead then began refusing requests (CloudFront error), so only the pages read before that are used |
| S4 | Icy Veins TBC leveling guides (`/tbc-classic/<class>-leveling-guide`, 22 pages) | Leveling stat advice: qualitative and sparse | 2021, page shell updated 2026 | Read in the built-in browser |
| S5 | Wowhead TBC leveling-tips pages (9 classes) | No stat guidance found | 2026 | Read in the built-in browser |
| S6 | Rating Buster add-on documentation (wowace.com/projects/rating-buster) and Warcraft Wiki talk page "Combat rating system" | Rating-to-percent scaling by level (60–70: × 82/(262 − 3·level)) | 2007 TBC era | Search results only; the main wiki page now shows Cataclysm or Retail tables and was **not** used for values |
| — | GearMatic (local install, TOC text only) | Feature set; says its weights come from Icy Veins | 5.25.7, "All Rights Reserved" | Only the file list and TOC were read; no code or data used |

**Not used:**
- Wowhead Retail pages (the TBC URL for Fury redirected to Retail, Midnight).
- Elitist Jerks archives, Seventy Upgrades, Osthyvel's Mage Sim (named by S2 but not read).
- Any snippet-only numbers.

**Not independent:** Wowhead's Rogue AP equivalents (Str 1.10, Agi 2.21, Hit 2.85, Exp 3.11, Haste 2.31, Crit 1.76, ArP 0.42) are within 0.02 of S1's Rogue defaults, so they look derived from wowsims. They count as one source, not two. Icy Veins' Enhancement and Elemental pages also point readers to wowsims.

## 2. Level-70 rating conversions and caps (TBC)

These come from S2 and S3, and the two agree.

| Stat | Rating per 1% at 70 | PvE cap at 70 |
|---|---|---|
| Melee/ranged hit | 15.77 | 9% vs +3 boss = 142 rating. Dual-wield white hits: 363 for Rogue vs boss (S2 table) |
| Spell hit | 12.62 | 16% vs boss = 202 rating, before talents and raid buffs (S2 Fire: 165 / 152 / 127 / 114 with buffs) |
| Expertise | 3.9423 rating per point; 1 point = 0.25% | 26 points (6.5%) = 103 rating; 83 for a Human using a sword or mace |
| Spell haste | 15.77 | None stated (Restoration Druid: 242 rating, from S2) |
| Spell crit | 22.08 | — |
| Defense | — | 490 (crit immunity vs boss) |
| Avoidance (Protection Paladin) | — | 102.4% (crush immunity) |

Caps depend on talents, race and raid buffs, so the engine must treat them as **assumptions**, not facts about the player. Below 70 the ratings are worth more per point (S6). Level-70 weights in rating units therefore do **not** carry over to leveling.

## 3. Per spec: evidence, agreement and proposed confidence

Weights are per point of stat or rating, with AP/RAP/SP = 1. "Phase" is the gear set the numbers were made with.

### Rogue (Combat): **High** at 70
- S2 gives a table by tier. Pre-raid: Agi 2.16, Str 1.1, Crit 1.67, Hit 2.26, Haste 2.13, Exp 2.48, ArP 0.29, AP 1. T4–Sunwell values rise slowly.
- S1 (Combat, P1): Agi 2.214, Str 1.1, Hit 2.852, Crit 1.763, Haste 2.311, Exp 3.107, ArP 0.44.
- Same normalisation. S1 and S2 agree on order; only Hit and Expertise rise with gear. S3's priority (Exp > Hit > Haste > Agi > Crit > Str/AP > ArP) matches.
- **Use:** S2's pre-raid column for "70 pre-raid" and S1 for "70 raid". Hit capped at 142 for specials or 363 for white hits; Expertise capped at 26 points.

### Warlock: **Destruction High; Affliction and Demonology Medium**
- S2 gives spell-power equivalents at T4/T5, assuming 3 Shadow Destruction + 1 Affliction outside the caster group:
  - Shadow Destruction: Crit 0.882, Hit 1.956 (until cap), Int 0.261, Spi 0.094 (only with Improved Drain Soul talent), Haste 1.350, Sta 0.
  - Fire Destruction: Crit 0.705, Hit 1.775, Int 0.209, Haste 1.425.
  - Unstable Affliction build: Crit 0.528, Hit 1.429 (with Suppression) or 1.930, Int 0.156, Haste 1.362.
  - Felguard (Demonology): Crit 0.596, Hit 1.596, Int 0.220, Sta 0.058, Haste 1.362.
- S1 (Destruction, P4 gear, hit-capped preset so no hit weight): Int 0.4, Spi 0.1, Crit 0.8, Haste 1.2.
- S1 and S2 are independent and agree on order: Hit > Haste > SP > Crit > Int. They differ on Int (0.26 vs 0.4), probably because of gear phase.
- S2 and S3 priorities match.

### Shaman
- **Restoration: Medium.** S2 gives numbers but says they are an estimate, with no method shown: Healing 1, Haste 1.5, Mp5 2, Crit 0.6, Int 0.5, Sta 0.2. S3's priority (Healing > Mp5 > Int > Haste > Crit) roughly agrees, but S3 ranks Int above Haste. S3 also says fight length strongly changes the value of Mp5. There is no healer simulation.
- **Enhancement: Medium.** S1 (P1): Str 2.2, Agi 1.317, Int 0.078, SP 0.433, AP 1, Hit 1.665, Crit 1.357, Haste 1.944, ArP 0.283, Exp 2.871. S2 and S3 priorities agree (Exp > Str > Hit > Haste > Crit > Agi). S2 itself points to S1, so this is effectively one source.
- **Elemental: Medium.** S1 (P1): Int 0.33, SP 1, Crit 0.78, Haste 1.25, Mp5 0.08, no hit weight. S2's priority (Hit to a low cap > Haste > SP > Crit > Int) agrees. S2 and S3 both note the spell hit cap is only about 4% from gear, because talents and Totem of Wrath supply the rest.

### Druid
- **Balance: Medium.** S1 (P1): Int 0.54, Spi 0.1, SP 1, Crit 0.84, Haste 1.29.
  - *Disagreement:* S1 puts Haste above SP; S2 and S3 put SP above Haste.
  - Hit to 16% is first in S2 and S3; S1 has no hit weight.
- **Feral (cat): Medium.** S1 (P4): Agi 3.5, Str 2.266, AP 1, Hit 3.2, Exp 3.2, Crit 2.37, Haste 1.36, ArP 0.47. S2 and S3 priorities agree, except S2 puts Str above Crit.
- **Feral (bear): Low.** S1's tank EP mixes threat and survival (Sta 3.05, Agi 4.6, Exp 7.3, Armor 0.59, Def 2.2, Dodge 1.7). Normalised to AP, they are hard to interpret for survival. S2 and S3 priorities agree with each other (Exp > Agi > Sta/Hit …).
- **Restoration: Low.** Priority only: Healing > Haste (to 242) > Spirit > Mp5 > Int > Crit (S2); S3 is nearly the same. No numbers.

### Hunter (Beast Mastery): **Medium**; Marksmanship and Survival **Low**
- S1 (BM, P1, hit-capped preset): Agi 2.5, Str 0.15, AP 0.15, RAP 1, Hit 0.3, Crit 2.3, Haste 1.97, ArP 0.4, Int 0.01.
- *Disagreement:* S2 and S3 rank Armor Penetration second, right after hit; S1 values it at 0.4. ArP's value grows with gear phase, so S1's P1 number is used and the conflict is recorded.
- S2's Survival list differs (Agi first, hit cap 2%). There are no numbers for Marksmanship or Survival.

### Mage: Arcane **Medium**; Fire and Frost **Low**
- S1's mage defaults are for **Arcane** (P1): Int 1.29, Spi 0.89, SP 1, Crit 0.77, Haste 0.84, Mp5 0.61. S2's Arcane list (Hit to 76 > Int ≥ SP > Haste > Crit > Spi) agrees.
- **Fire and Frost:** S2 and S3 give priority lists only: Hit > SP > Haste > Crit > Int. S3 puts Haste above SP for Fire. No numbers.

### Priest: Shadow **Medium**; Holy and Discipline **Low**
- S1 (Shadow, P1): Int 0.05, Spi 0.11, SP 1, Crit 0.163, Haste 1.0, Mp5 0. The sim file itself notes the haste value is uncertain.
- *Disagreement:* S3 does not list Haste (SP > Hit > Crit > Int/Spi/Mp5); S2 lists Hit > SP > Haste > Crit.
- **Holy:** priority only. S2: Haste > Healing > Crit > Spi > Int > Mp5. S3: Haste > Healing > Int/Spi > Crit > Mp5.
- **Discipline:** no stat page exists (S2 returns 404).
- S1 also has a "Smite" DPS sim. It's a niche spec and not proposed.

### Paladin: Retribution **Medium**; Holy and Protection **Low**
- S1 (Ret, P4, no hit weight): Str 2.42, Agi 1.88, AP 1, Crit 1.98, Exp 4.70, Haste 3.27, ArP 0.24, SP 0.35.
- *Disagreement:* S1 values Haste highly (3.27); S2 ranks Haste fifth and S3 doesn't list it.
- **Holy:** priority only. S2: Healing > Mp5 > Crit > Int > Haste. S3: Healing > Int > Crit > Mp5.
- **Protection:** S1's numbers are **rejected**. They are identical to the Protection Warrior defaults even though the reference stat differs, so they're a copied placeholder. Priority only, from S2 and S3: Defense to 490 > Avoidance to 102.4% > Stamina > SP > Hit > Expertise.

### Warrior: Fury **Medium**; Arms **Low**; Protection **Low**
- S1 (Fury, P1, hit-capped preset): Str 2.17, Agi 1.4, AP 1, Exp 3.29, Hit 0.41, Crit 1.83, Haste 2.07, ArP 0.5.
- *Disagreement:*
  - S2 lists Hit > Exp > Crit > ArP > Str > Agi > Haste.
  - S3 lists Hit > Exp > Crit > Str > ArP > Haste.
  - S1 ranks Haste above Crit. S3 notes haste is very strong for Fury but desyncs Arms.
- **Arms:** priority only.
- **Protection:** S1's numbers are rejected (see Paladin). Priority only, from S2: Stamina > Armor > Defense to 490 > Agility > Dodge/Parry > Block Value, plus Expertise and Hit for threat.

## 4. Leveling (1–69): no numerical evidence

- S4 has only a few sentences:
  - Rogue: hit and agility;
  - Mage: intellect, then spirit;
  - Enhancement Shaman: strength, and the weapon matters most;
  - Feral Druid: agility and strength;
  - other casters: intellect and spell power.
- S5 has nothing on stats, and S3's endgame pages explicitly send leveling readers elsewhere.
- No source gives numerical leveling weights.
- **Conclusion:** leveling profiles can only be **qualitative** (ordered stat groups). The rules forbid inventing numbers from them, so the engine must not show a numeric score or upgrade % for them.

## 5. Gaps

- **No numerical weights at all:** Restoration Druid, Holy Priest, Discipline Priest, Holy Paladin, Protection Paladin, Protection Warrior, Arms Warrior, Fire Mage, Frost Mage, Marksmanship Hunter, Survival Hunter, Assassination and Subtlety Rogue (S2 has one Rogue page, written for Combat).
- **No PvP research.**
- **Hit below cap:** S1's caster and Fury/BM presets are already hit-capped, so S1 has no value for hit below the cap. Only S2's Warlock numbers and S1/S2's Rogue numbers give one.
