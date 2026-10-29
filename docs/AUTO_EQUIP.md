# Automatic upgrades, BoE markers and equip notifications

Opt-in. TBCGuide can equip better gear from your bags for the spec you choose, tell you on screen when it did, and mark Bind-on-Equip upgrades it will not equip for you.

**Not yet tested in the game client.** Offline checks pass (lint, and 1,399 headless tests under Lua 5.1). The in-game checklist is at the end.

## What happens

Rules, applied in this order:

1. **An unbound Bind-on-Equip item is never equipped automatically**, not even into an empty slot. There is no setting to change this.
2. **Only items your character can use now:**
   - your class's armor and weapon types;
   - your level;
   - dual wield for off-hand weapons;
   - nothing the game's tooltip shows in red.
3. **Nothing happens while any of these is true:**
   - you're in combat or dead;
   - the cursor holds an item;
   - a merchant, trade, bank, mail or auction window is open;
   - another equip is still in progress;
   - this item's binding state can't be read;
   - automation is off, or the item or slot is protected.
4. **Empty slots** get any usable non-BoE item, even one that isn't ideal for your spec (*Fill empty gear slots*).
5. **Filled slots** only get a certain upgrade: a strictly higher estimated spec score, at or above your *Minimum upgrade*.

**Before anything is equipped:**
- **Spec choice:** nothing is equipped until you choose a spec profile for the character. The *Automatic* choice is for tooltips only.
- **Asks first:** switching the feature on asks for confirmation and says what will happen.

**Each change:**
- **One at a time:** one item, then TBCGuide waits until the game shows it in the slot, then looks again.
- **Notification:** you get one notification per confirmed change.
- **Failures:** an attempt that fails isn't retried this session, and doesn't produce a message.
- **Replaced items stay in your bags.** Nothing is sold, deleted or disenchanted, and nothing is taken from the bank, mail or auction house.

**Binding:**
- **What is checked:** this copy's own binding state. The bag API reports whether a copy is bound; if it doesn't, the tooltip's *Soulbound* / *Binds when equipped* line is used. The item's template type is never enough.
- **Unknown state:** if neither source answers, the item is skipped.
- **Bind confirmation:** if the game still asks to confirm binding, TBCGuide cancels, puts the item back in its bag slot and doesn't try it again. It never confirms a bind.

**Login:** the first check waits 3 seconds after login or a loading screen, and bag event bursts are grouped.

**Item data:** items the game hasn't loaded yet are waited for, up to 10 retries, then until the next bag change. They're never scored as zero.

## How "upgrade" is decided

One evaluator (`TBCGuide/Gear/Upgrade.lua`) is used for automatic equipping, bag markers, bag tooltips and notifications.

**Whole configurations are compared.** The slots an item would change are scored before and after:
- **Two-hander:** compared with main hand + off hand together.
- **Ring or trinket:** compared with each of the two slots. The empty one, or the one giving the best positive gain, is used.
- **One-hander, dual wielder:** both hands are checked. Otherwise the main hand only.
- **Off-hand or shield:** never equipped while you hold a two-hander, because the main hand would be left empty.
- **Bag space:** a two-hander replacing two weapons needs one free bag slot.

**Score:** stat amount × weight, summed. On top of that:
- **Weapon DPS:** valued at 14 × the profile's AP weight (RAP weight for a hunter's ranged slot). The off hand counts half.
- **School damage** (*+X Shadow damage*): counts as spell damage for profiles of that school.
- **Caps:** hit, spell hit, expertise and defense count only up to the profile's cap. Caps apply at level 70 only; below that they're level-70 raid assumptions that don't fit.

**Upgrade %:** (new − current) / current × 100, shown to one decimal as *estimated spec score*. It's not a promise of more DPS, healing or survival.
- **Empty slot:** shows *Empty slot filled*.
- **Current score of 0:** shows *Upgrade - percentage unavailable*.
- **Never shown:** infinity or NaN.

**Equal scores, and items just replaced,** are never swapped in. That stops loops.

**Uncertain (never equipped over a filled slot, never marked):**
- a use effect, a chance-on-hit effect, an equip line that isn't a plain stat, or a set bonus, on either the new item or the one it would replace;
- a second copy of a ring or trinket you already wear, because unique-equipped isn't checked.

**Text matching:** the tooltip patterns are for English clients. On other languages, most items with an *Equip:* line count as uncertain, which is the safe side.

## Profiles and how each is scored

Choose one under **Tips → Item Upgrade → Spec profile**. It's saved for this character.
- **Your class only:** the dropdown lists only your class's profiles, so another class's profile can't become active.
- **Changing it** re-evaluates your bags and clears markers that no longer apply.
- **Starred entries (\*)** are estimated from a stat priority.

**Two kinds of scoring basis:**
- **Published numbers** come from wowsims/tbc (MIT, commit 3301fca) or from Icy Veins' own EP tables. Details are in [GEAR_RESEARCH.md](GEAR_RESEARCH.md).
- **Estimated from priority** is TBCGuide's own heuristic, not endorsed by any source. Icy Veins and Wowhead publish only an order of stats for these specs. Each stat gets:
  - **budget:** its approximate cost compared with one point of a primary stat (TBC itemisation rule of thumb);
  - **rank factor:** 1.0 for the first listed stat, falling to 0.4 for the last.

  Stats that aren't listed count 0. Every one of these estimates is labelled *Estimate* in the bag tooltip.
- **Where to edit:** all heuristic values are in one table, `ns.GearProfiles.heuristic` in `TBCGuide/Gear/Profiles.lua`.

| Class | Spec | Profile | Scoring basis | Caps (level 70 only) | Confidence | Sources | Assumptions and limits |
|---|---|---|---|---|---|---|---|
| Rogue | Combat (pre-raid) | `rogue_combat_preraid` | Published numbers: Exp 2.48, Hit 2.26, Agi 2.16, Haste 2.13, Crit 1.67, Str 1.1, AP 1, ArP 0.29 | Hit 142, Exp 103 | high | S2 icy-veins.com/tbc-classic/rogue-dps-pve-stat-priority (EP table, Pre-Raid column); S1 agrees on order (ui/rogue/sim.ts) | Average pre-raid gear, raid buffs. Hit cap 142 is for special attacks vs a boss; white hits keep gaining to 363. |
| Rogue | Combat | `rogue_combat_raid` | Published numbers: Exp 3.107, Hit 2.852, Haste 2.311, Agi 2.214, Crit 1.763, Str 1.1, AP 1, ArP 0.44 | Hit 142, Exp 103 | high | S1 ui/rogue/sim.ts epWeights; S2 EP table (Tier 4 column) agrees within 0.5 | wowsims Combat talents, P1 raid preset, full raid buffs. |
| Rogue | Assassination | `rogue_assassination_raid` | Estimated from priority: Exp > Hit > Agi > Haste > Crit > ArP | Hit 142, Exp 103 | low | S2 icy-veins.com/tbc-classic/rogue-dps-pve-stat-priority (read 2026-10-29); S3 wowhead.com/tbc/guide/classes/rogue/dps-stat-priority-attributes-pve (read 2026-10-29) | Priority only. Both sources publish one Rogue page for all specs; its EP table is the Combat one, so it is not reused for Assassination. |
| Rogue | Subtlety | `rogue_subtlety_raid` | Estimated from priority: Exp > Hit > Agi > Haste > Crit > ArP | Hit 142, Exp 103 | low | S2 icy-veins.com/tbc-classic/rogue-dps-pve-stat-priority (read 2026-10-29); S3 wowhead.com/tbc/guide/classes/rogue/dps-stat-priority-attributes-pve (read 2026-10-29) | Priority only; same single Rogue page as Assassination. Subtlety is rarely a raid spec in TBC. |
| Warlock | Destruction | `warlock_destruction_raid` | Published numbers: Spell hit 1.956, Spell haste 1.350, SP 1, Spell crit 0.882, Int 0.261 | Spell hit 202 | high | S2 icy-veins.com/tbc-classic/destruction-warlock-dps-pve-stat-priority; S1 ui/warlock/sim.ts (P4, hit-capped) agrees on order | Shadow Destruction, T4/T5 gear. Spirit (0.094) counts only with Improved Drain Soul, so it is left out. |
| Warlock | Affliction | `warlock_affliction_raid` | Published numbers: Spell hit 1.930, Spell haste 1.362, SP 1, Spell crit 0.528, Int 0.156 | Spell hit 202 | medium | S2 icy-veins.com/tbc-classic/affliction-warlock-dps-pve-stat-priority | Unstable Affliction build, T4/T5 gear, Affliction spells not capped by Suppression (1.429 if they are). |
| Warlock | Demonology | `warlock_demonology_raid` | Published numbers: Spell hit 1.596, Spell haste 1.362, SP 1, Spell crit 0.596, Int 0.220, Sta 0.058 | Spell hit 202 | medium | S2 icy-veins.com/tbc-classic/demonology-warlock-dps-pve-stat-priority | Felguard build, T4/T5 gear. |
| Shaman | Restoration | `shaman_restoration_raid` | Published numbers: Mp5 2, Spell haste 1.5, Healing 1, Spell crit 0.6, Int 0.5, Sta 0.2 | - | medium | S2 icy-veins.com/tbc-classic/restoration-shaman-healer-pve-stat-priority | Source calls these an estimate; fight length changes Mp5's value a lot. |
| Shaman | Enhancement | `shaman_enhancement_raid` | Published numbers: Exp 2.871, Str 2.2, Haste 1.944, Hit 1.665, Crit 1.357, Agi 1.317, AP 1, SP 0.433, ArP 0.283, Int 0.078 | Hit 142, Exp 103 | medium | S1 ui/enhancement_shaman/sim.ts epWeights | wowsims P1 preset, full raid buffs. S2 and S3 priorities agree; S2 cites S1, so one source. |
| Shaman | Elemental | `shaman_elemental_raid` | Published numbers: Spell haste 1.25, SP 1, Spell crit 0.78, Int 0.33, Mp5 0.08 | - | medium | S1 ui/elemental_shaman/sim.ts epWeights | wowsims P1 preset (hit-capped: spell hit is not scored). |
| Druid | Balance | `druid_balance_raid` | Published numbers: Spell haste 1.29, SP 1, Spell crit 0.84, Int 0.54, Spi 0.1 | - | medium | S1 ui/balance_druid/sim.ts epWeights | wowsims P1 preset (hit-capped: spell hit is not scored). Guides rank SP above Haste. |
| Druid | Feral DPS (cat) | `druid_feral_raid` | Published numbers: Agi 3.5, Hit 3.2, Exp 3.2, Crit 2.37, Str 2.266, Haste 1.36, AP 1, Feral AP 1, ArP 0.47 | Hit 142, Exp 103 | medium | S1 ui/feral_druid/sim.ts epWeights | wowsims P4 preset, cat form. |
| Druid | Feral Tank (bear) | `druid_bear_raid` | Estimated from priority: Exp > Agi > Sta > Hit > Str > Crit > Haste > Dodge > Def > AP > Armor > ArP | - | low | S2 feral-druid-tank page; S3 wowhead feral tank page | Priority only. wowsims tank EP mixes threat and survival and is not used. |
| Druid | Restoration | `druid_restoration_raid` | Estimated from priority: Healing > Spell haste > Spi > Mp5 > Int > Spell crit > Sta | Spell haste 242 | low | S2 restoration-druid-healer page; S3 wowhead druid healer page |  |
| Hunter | Beast Mastery | `hunter_bm_raid` | Published numbers: Agi 2.5, Crit 2.3, Haste 1.97, RAP 1, ArP 0.4, Str 0.15, AP 0.15, Int 0.01 | Hit 142 | medium | S1 ui/hunter/sim.ts epWeights | wowsims P1 preset (hit-capped: hit is not scored). Guides value ArP far higher in later phases. |
| Hunter | Marksmanship | `hunter_mm_raid` | Estimated from priority: Hit > ArP > Agi > RAP > Crit | Hit 142 | low | S2 icy-veins.com/tbc-classic/marksmanship-hunter-dps-pve-stat-priority (updated 2026-01-12, read 2026-10-29) | Priority only. Cap 142 without raid buffs (the source's 79 assumes Improved Faerie Fire and a Draenei). |
| Hunter | Survival | `hunter_sv_raid` | Estimated from priority: Agi > Crit > Hit > ArP > RAP | Hit 95 | low | S2 icy-veins.com/tbc-classic/survival-hunter-dps-pve-stat-priority (updated 2026-01-12, read 2026-10-29) | Priority only. Surefooted gives 3% hit, so 6% (95 rating) comes from gear without raid buffs. Values raid-wide Expose Weakness, not personal damage. |
| Mage | Arcane | `mage_arcane_raid` | Published numbers: Int 1.29, SP 1, Spi 0.89, Spell haste 0.84, Spell crit 0.77, Mp5 0.61 | - | medium | S1 ui/mage/sim.ts epWeights | wowsims Arcane talents, P1 preset (hit-capped: spell hit is not scored). |
| Mage | Fire | `mage_fire_raid` | Estimated from priority: Spell hit > SP > Spell haste > Spell crit > Int > Sta > Spi > Mp5 | Spell hit 165 | low | S2 fire-mage-dps page; S3 wowhead mage page (puts Haste above SP) |  |
| Mage | Frost | `mage_frost_raid` | Estimated from priority: Spell hit > SP > Spell haste > Spell crit > Int > Sta > Spi > Mp5 | Spell hit 127 | low | S2 frost-mage-dps page |  |
| Priest | Shadow | `priest_shadow_raid` | Published numbers: SP 1, Spell haste 1.0, Spell crit 0.163, Spi 0.11, Int 0.05 | - | medium | S1 ui/shadow_priest/sim.ts epWeights | wowsims P1 preset (hit-capped); the sim file itself flags the haste value as uncertain. |
| Priest | Holy | `priest_holy_raid` | Estimated from priority: Spell haste > Healing > Spell crit > Spi > Int > Mp5 > Sta | - | low | S2 holy-priest-healer page; S3 wowhead priest healer page |  |
| Priest | Discipline | `priest_discipline_raid` | Estimated from priority: Spell haste > Healing > Spell crit > Spi > Int > Mp5 > Sta | - | low | S2 holy-priest-healer page (used for Discipline); S3 wowhead priest healer page | No TBC Discipline stat page exists (S2 404, checked again 2026-10-29). Uses the priest healer priority. |
| Paladin | Retribution | `paladin_retribution_raid` | Published numbers: Exp 4.70, Haste 3.27, Str 2.42, Crit 1.98, Agi 1.88, AP 1, SP 0.35, ArP 0.24 | Hit 142, Exp 103 | medium | S1 ui/retribution_paladin/sim.ts epWeights | wowsims P4 preset (hit not scored). Guides rank Haste much lower than this. |
| Paladin | Holy | `paladin_holy_raid` | Estimated from priority: Healing > Mp5 > Spell crit > Int > Spell haste > Sta | - | low | S2 holy-paladin-healer page; S3 wowhead holy paladin page |  |
| Paladin | Protection | `paladin_protection_raid` | Estimated from priority: Def > Dodge > Parry > Block > Sta > SP > Spell hit > Exp | Def 490 | low | S2 protection-paladin-tank page; S3 wowhead paladin tank page | Priority only. wowsims numbers rejected (copied from the warrior sim). |
| Warrior | Fury | `warrior_fury_raid` | Published numbers: Exp 3.29, Str 2.17, Haste 2.07, Crit 1.83, Agi 1.4, AP 1, ArP 0.5 | Hit 142, Exp 103 | medium | S1 ui/warrior/sim.ts epWeights | wowsims P1 preset (hit-capped: hit is not scored). Guides rank Crit above Haste. |
| Warrior | Arms | `warrior_arms_raid` | Estimated from priority: Hit > Exp > Crit > ArP > Str > AP > Agi > Haste | Hit 142, Exp 103 | low | S2 arms-warrior-dps page |  |
| Warrior | Protection | `warrior_protection_raid` | Estimated from priority: Sta > Armor > Def > Agi > Dodge > Parry > Block value > Exp > Hit | Def 490 | low | S2 protection-warrior-tank page | Priority only. wowsims numbers rejected (placeholder). |

**Sources:**
- **S1:** wowsims/tbc `ui/<spec>/sim.ts` (MIT).
- **S2:** Icy Veins TBC Classic stat pages, `icy-veins.com/tbc-classic/<spec>-pve-stat-priority`. The Marksmanship, Survival and Rogue pages say "Reviewed and Updated for TBC Anniversary Realms" (Dec 2025).
- **S3:** Wowhead TBC stat pages, `wowhead.com/tbc/guide/classes/...`, for TBC Classic 2.5.x.

No guide text is copied into the add-on; only stat names, orders and numbers.

**Checked again on 2026-10-29:** Icy Veins has no Discipline Priest page (404), and has a single Rogue page for all specs, whose EP table is the Combat one.

**Heuristic budget per point:**
- 1: Str, Agi, Sta, Int, Spi, all ratings, Defense, Dodge, Parry, Block;
- 0.86: SP; 0.5: AP; 0.4: RAP and Feral AP; 0.45: Healing;
- 2.5: Mp5; 0.65: Block value; 0.14: ArP; 0.02: Armor.

## BoE markers and tooltips

**Marker:** a small green arrow at the top left of a bag button, on an unbound BoE item. It appears when the item:
- is usable now;
- is a certain upgrade, or would fill an empty slot;
- is under your chosen profile.

The overlay is a texture, so it doesn't take clicks and the icon, count and quality border stay visible. Markers refresh when your bags, equipment, profile or settings change, and are cleared from reused buttons.

**Bag tooltip:**
- *Upgrade for: Frost*;
- *+X.X% estimated spec score*, or *Empty slot (Head)*;
- what it would replace;
- *Bind on Equip - manual equip required*.

Non-BoE upgrades show the same lines without the BoE note. The lines appear while *Disable Tooltips* is off.

**Equipping a marked item:** do it yourself. The game asks you to confirm the bind.

**Bag support:**
- **Supported:** the default bag frames (`ContainerFrame1`–`13`).
- **Not supported:** bag replacement add-ons (Bagnon, AdiBags, ArkInventory, Baganator and others) use their own buttons, so they get no markers. Tooltips over their buttons don't get the upgrade lines either. TBCGuide had no bag add-on integrations before this.

## Notifications

After a confirmed change, a message with the item's icon appears at the top of the screen for 4 seconds:
- *Auto-equipped: [Item] - +8.4% estimated spec score (Frost)*
- *Auto-equipped: [Item] - Empty slot filled (Head)*

**Queue:** at most three wait in line; more go to chat instead.

**Chat copy:** optional, *Copy equip messages to chat*.

## Settings

All of these are under **Tips → Item Upgrade / Automatic Upgrades / Protected Slots**:

| Setting | Default | Notes |
|---|---|---|
| Spec profile | Automatic (tooltips only) | Per character; your class only |
| Enable automatic upgrades | off | Needs a spec profile; asks for confirmation |
| Fill empty gear slots | on | Non-BoE items only |
| Minimum upgrade | 0% | Filled slots; 0 means any strictly higher score |
| On-screen equip messages | on | |
| Copy equip messages to chat | off | |
| Mark Bind-on-Equip upgrades in bags | on | |
| Protected slots | none | Per character; never changed automatically |
| Clear excluded items | | Undoes `/tbcg gear exclude` |

**Commands:**
- `/tbcg gear auto`: status and the last problem.
- `/tbcg gear exclude <item link or id>`: keep an item out of automatic upgrades. It's never equipped or replaced, and its tooltip says so.
- `/tbcg gear include <item link or id>`: allow it again.

## Client limits

- **Equipping:** uses `PickupContainerItem` + `EquipCursorItem` from the exact bag slot, so the right copy is equipped. Neither function is protected outside combat in the Classic clients, so no click is needed. If a future client protects them, attempts fail and nothing is announced. Equip marked items by right-clicking them yourself.
- **Not checked:**
  - unique-equipped limits (treated as uncertain);
  - whether a weapon skill is trained (only class rules and the red tooltip text);
  - gems, sockets, enchantments, resilience and weapon speed.
- **`/tbcg debug api`** shows whether the client has the functions this needs: `EquipCursorItem`, `C_Container.PickupContainerItem`, `GetInventoryItemID`, `IsEquippableItem` and the free-slot counter.

## In-game test checklist

1. **Before a spec is chosen:** choose no spec and turn the feature on. It should refuse.
2. **Upgrade:** choose your spec, turn it on and confirm. Loot or buy a non-BoE upgrade. It should be equipped once, with one message showing a sensible percentage.
3. **Empty slot:** take off a piece, then put a weaker non-BoE item for that slot in your bags. It should be equipped, with *Empty slot filled*.
4. **BoE:** with a BoE item for an empty slot, and another for a filled slot:
   - neither is equipped;
   - both show the green arrow;
   - the tooltips say *Bind on Equip - manual equip required*;
   - the icon, count and border are still readable, and clicking works normally.
5. **Weapons:**
   - **Two-hander:** dual wielding with nearly full bags, a two-hander upgrade isn't equipped. With a free bag slot, it is, and both one-handers land in your bags.
   - **Shield:** with a two-hander equipped, a shield is never equipped.
6. **Rings and trinkets:** a better ring replaces your weaker ring. A trinket with a *Use:* effect isn't equipped over a filled slot.
7. **Combat:** loot an upgrade in combat. Nothing happens until combat ends, then it's equipped.
8. **Windows:** with a merchant, bank or mail window open, nothing is equipped until you close it.
9. **Spec change:** switch spec in the dropdown. Markers and tooltips should update straight away.
10. **Login:** log out and back in with several upgrades in your bags. Messages should be few and readable, and nothing should repeat.
11. **Reload:** after `/reload`, the settings, profile, protected slots and exclusions should be unchanged.
12. **Diagnostics:** run `/tbcg debug api` and report anything missing.
