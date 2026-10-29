# Gear scoring

TBCGuide compares items with what you wear: on item tooltips, for quest rewards (ranked in chat when a quest offers a choice), and with `/tbcg gear` (also `/tbcgear`). It never equips, buys or chooses anything. Quest rewards are always picked by you.

The stat weights come from researched sources, listed with their assumptions in [GEAR_RESEARCH.md](GEAR_RESEARCH.md). Nothing has been tested in the game client yet.

## How an item is scored

1. **Profile.** One profile per class, spec, role and context, in `TBCGuide/Gear/Profiles.lua`, chosen like this:
   - Your **main talent tree** picks the spec. A Feral druid gets the cat profile unless you choose the bear profile.
   - Only profiles whose **level range** contains your level are used, so **level-70 weights are never applied to a leveling character automatically**.
   - At 70, a pre-raid profile is preferred over a raid profile when both exist (Rogue only).
   - `/tbcg gear profile <id>` or *Next profile* on the settings page overrides this; `auto` goes back to detection. A profile made for a higher level says so.
   - No matching profile means no score, and the tooltip says why.
2. **Numeric profiles** (`weights`):
   - `score = sum(stat amount × weight)` over the stats the profile weights.
   - Stats without a weight add nothing. Weights are per point of stat or rating, normalised so AP, RAP, SP or Healing = 1 (the profile's `normalization`).
   - **Caps:** hit, spell hit and expertise only count up to the profile's cap. Your current rating (`GetCombatRating`) minus the replaced item's rating is the starting point, so hit beyond the cap scores 0 and swapping hit for hit stays neutral. If the client cannot report your rating, the cap is not applied.
   - **Upgrade %** = (new score − current score) / current score × 100. It's shown only when both scores are valid under the same profile and the current score is above 0. It's labelled as a *score* change, not a DPS or healing change. Empty slots show the score only.
3. **Priority-only profiles** (`priority`) cover leveling, most healers and tanks, Fire and Frost Mage, and Arms. **No number is produced.** The item is compared stat by stat in priority order and called *better* or *worse* only when it is at least as good, or no better, on every listed stat; otherwise *mixed*, with the differences listed.

## Slots

- **Two-handers** are compared with main hand + off hand together.
- **Off-hands and shields** are compared with the off hand. While you hold a two-hander, the tooltip says you'd need a one-hander.
- **One-handers:**
  - Dual wielders compare them with the weaker hand. Dual wield is assumed for warriors and hunters from 20, rogues from 10, and Enhancement shamans from 40.
  - Everyone else compares them with the main hand.
- **Rings and trinkets** are compared with the weaker of the two. An empty slot is filled first.
- **Class rules:** armor type (mail for hunters and shamans and plate for warriors and paladins from 40), shields, relics and weapon types are checked against general class rules. Whether you have *trained* a weapon skill is not checked.
- **Required level** above yours is shown as a note.

## Not scored (shown as notes, never given an invented value)

- **Weapon DPS:** no source gives it a weight on this scale. For leveling, the weapon is usually the most important item, so compare DPS yourself.
- Sockets, gems and enchantments; equip, use and chance-on-hit effects; set bonuses; resilience.
- **Unique-equipped:** you get a note when you already wear the same ring or trinket.
- **Generic vs spell ratings:** generic hit, crit and haste rating is treated as melee/ranged, and spell ratings as spell. Spell damage and healing are separate stats, so they're never double counted. This follows TBC itemisation and has not been checked in the client.

## Settings

The *Gear* page under TBCGuide in the game options has:
- on/off switches for gear scoring, tooltips, quest-reward ranking, percentages and confidence;
- profile choice;
- *Reset gear settings*.

From chat: `/tbcg set gearTooltip off`, and the same for `gearEnabled`, `gearQuestRewards`, `gearShowPercent` and `gearShowConfidence`.

## Updating profiles

Profiles are plain data in `TBCGuide/Gear/Profiles.lua`; no code changes are needed.

1. Record the new source in `docs/GEAR_RESEARCH.md`: URL, date, game version and phase, context, assumptions, and whether it gives numbers.
2. Edit or add the profile. Use the stat keys listed at the top of the file, keep `sources` and `assumptions` accurate, and set `confidence` by the rules in the research doc.
3. Only add `weights` when a source publishes numbers. Otherwise use `priority`. Never derive numbers from a priority list.
4. Run the tests (`tests/run_tests.lua`). They check every profile's structure: unique id, valid class, confidence, level range, sources, known stat keys, weights *or* priority, and no numbers on leveling profiles.
