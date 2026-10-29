# Client compatibility

## Target

| | Value | How established |
|---|---|---|
| Game | World of Warcraft: The Burning Crusade Classic, **Anniversary realms** (TBC pre-patch 2026-01-13, launch 2026-02-05) | public news coverage |
| Client build | **2.5.6.70577** | wago.tools build list, product `wow_anniversary` (checked 2026-10-28) |
| TOC interface | **20506** | Questie `bundle/v12.3.1` `release.json` (flavor `bcc`, interface 20506) |
| Lua | 5.1 (WoW embedded) | standard for all WoW clients |
| Races | 10 (incl. Draenei, Blood Elf), 52 race/class combinations | client `CharBaseInfo` table, build 2.5.6.70577 |
| Talents | 3 trees per class, 61 points at 70 (first at 10) | client `Talent`/`TalentTab` tables |

All of this lives in `TBCGuide/Config/Target.lua`. Older 2.5.x builds (e.g. original TBC Classic 2.5.4, interface 20504) are **not** claimed to work. The add-on warns if the interface is outside 20500-20599.

## API usage and fallbacks

Every API is reached through `Compat/Compat.lua` and listed with its status in `tools/wow_api_allowlist.txt`. Summary:

| Feature | APIs | If missing |
|---|---|---|
| Quest completion | `C_QuestLog.IsQuestFlaggedCompleted` / `IsQuestFlaggedCompleted` / `GetQuestsCompleted` | next fallback in turn; ultimately manual |
| Quest log | `GetQuestLogTitle` (8th return = questID), `GetNumQuestLeaderBoards`, `GetQuestLogLeaderBoard` | `C_QuestLog.GetQuestIDForLogIndex` for the id; otherwise manual |
| Events | `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, `QUEST_LOG_UPDATE`, `QUEST_REMOVED`, `UNIT_QUEST_LOG_CHANGED` | registration is pcall-guarded; periodic rescans still work |
| Position | `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition`, `C_Map.GetWorldPosFromMapPos`, `GetPlayerFacing` | arrow shows plain coordinates |
| Map pin | `WorldMapFrame:GetCanvas()`, `:GetMapID()`, `OnMapChanged` | pin hidden |
| Talents | `GetTalentInfo`, `GetTalentTabInfo`, `GetNumTalents`, `UnitCharacterPoints` | calculator works in simulated mode only |
| Options | `Settings.RegisterCanvasLayoutCategory` or `InterfaceOptions_AddCategory` | `/tbcg set <opt> on|off` |
| Frames | `BackdropTemplate` for `SetBackdrop` | panels without backdrops |

## In-game verification checklist

None of these have been done yet. Tick them off on a real client:

- [ ] Add-on loads with no Lua errors (`/console scriptErrors 1`). `/tbcg debug errors` is empty.
- [ ] `/tbcg debug api`: every listed API reports `yes` (or the fallback works).
- [ ] `/tbcg debug talents`: **0 data mismatches** for your class (talent tier/column/rank mapping is correct).
- [ ] A new character of each race gets its own start guide automatically.
- [ ] Accepting, completing and turning in quests advances steps automatically.
- [ ] `/reload` and logout/login keep the guide and step.
- [ ] Left-click / right-click on steps marks done or skips; `/tbcg prev` reopens a step.
- [ ] Arrow points the right way, shows distance, and turns green on arrival. Check the world-map pin is placed correctly.
- [ ] With TomTom installed, waypoints appear in TomTom.
- [ ] `fp`, `bind`, `train` and `hs` steps complete as described in docs/GUIDE_FORMAT.md.
- [ ] Talent window: tooltips show the right spell text, the simulation obeys tier and prereq rules, and live mode shows your talents.
- [ ] Options panel appears under Interface > AddOns and the settings persist.
- [ ] A boosted or high-level character (e.g. level 58) gets an appropriate guide (Hellfire).
- [ ] Draenei and Blood Elf routes: Azuremyst to Bloodmyst to Ashenvale, and Eversong to Ghostlands to Barrens.

### 0.2.0 automation (see docs/AUTOMATION.md)

- [ ] `/tbcg debug api`: the automation APIs (C_Container, C_GossipInfo, GetQuestID, AcceptQuest, GetNumQuestChoices, ...) report `yes`.
- [ ] Gossip NPC with several guide quests: completed ones are turned in first, then each guide quest is accepted, with "Accepted:" printed only after it appears in the log.
- [ ] A quest-giver with the plain greeting window (no gossip) behaves the same.
- [ ] An unrelated quest at the same NPC is **not** accepted.
- [ ] An escort quest in the guide (e.g. *Protecting the Shipment*, *Rescue OOX-17/TN!*, Horde *Free From the Hold*) is **not** accepted, and the chat message says why. A party member starting an escort: the confirmation is left to you.
- [ ] A turn-in with **several rewards** stays open with "Choose your reward". No reward is picked. After you pick one, the guide advances.
- [ ] A turn-in with no reward or a single reward completes automatically.
- [ ] Holding Shift while talking to an NPC disables automation for that conversation.
- [ ] With a full quest log (25), a guide quest is not accepted and the message says the log is full.
- [ ] Junk selling OFF (default): opening a vendor sells nothing.
- [ ] Junk selling ON: grey items are sold. Grey items needed by a quest in your log, protected items and protected categories stay. The summary's copper matches the money gained.
- [ ] Quest log window: the **Orphaned (N)** button is visible and not overlapping anything. The list matches expectations. **Abandon** asks for confirmation and removes only the ticked quests.
- [ ] *Maximum-speed route* (Interface > AddOns > TBCGuide) hides optional steps; turning it off restores them.

### 0.3.0 raid markers (see docs/RAID_MARKERS.md)

- [ ] `/tbcg debug api`: `SetRaidTarget`, `GetRaidTargetIndex` and `UnitGUID` report `yes`.
- [ ] No target: `/tbcg mark skull` prints "You have no target to mark." with no Lua error.
- [ ] Solo: `/tbcg mark skull` puts a skull on your target (check the target frame and the world), and "Marked ..." is printed. `/tbcg unmark` removes it. Marking the same icon twice leaves it on.
- [ ] In a party, as any member: marking works. In a raid without assist: it is refused with a reason. As raid assistant or leader: it works.
- [ ] Orc/Troll, Durotar step *Sarkoth*: targeting Sarkoth puts a skull on him automatically (once). Other scorpids are not marked.
- [ ] Change that skull by hand: TBCGuide does not put it back, and does not mark another Sarkoth in the same step.
- [ ] A mob that already has an icon is not re-marked (default `markReplace` off).
- [ ] Advancing the step removes TBCGuide's skull but not icons you set yourself.
- [ ] In combat: marking by command and by the marker bar works. `/tbcg markbar` toggling is refused in combat.
- [ ] Marker bar buttons mark and clear your target. If the client ever blocks addon marking, the chat message says so and the bar still works.
- [ ] Raid marker settings page appears under TBCGuide, and changes persist after `/reload`.

### 1.0 additions (not yet run in the game)

**First-login setup** (docs/SETTINGS.md)
- [ ] A new character sees the setup window about 2 seconds after login (not in combat). An existing character with progress does not.
- [ ] Skip: no window again after `/reload`; the recommended guide loads; automatic upgrades stay off.
- [ ] Close the window half-way, `/reload`: the choices are still there (resume). Settings → General → Open setup reopens it.
- [ ] Finish with the opt-in ticked and a spec profile: automatic upgrades on. Ticked without a spec profile: stays off.

**Bag add-ons** (docs/BAGS.md), each with an unbound BoE upgrade and a grey item in the bags
- [ ] Bagnon 12.1.7: green arrow and junk coin on the right slots; tooltip lines; moving the item moves the arrow; bank and other characters show none.
- [ ] AdiBags 1.10.29 (may need *Load out of date AddOns*): the same. The module *TBCGuide markers* is listed in AdiBags' modules.
- [ ] Baganator 839: the arrow appears in its corner (Icons settings); choosing *TBCGuide* as the junk source shows its coin on the grey item.
- [ ] With none installed: default bags unchanged, no Lua errors.

**Non-English client** (docs/LOCALES.md)
- [ ] On a German or French client: a BoE item shows the arrow (binding read from the client strings); a Soulbound item never does.
- [ ] An item with an *Equip:* effect beyond its stats is marked uncertain (no arrow, no automatic equip).

**Class trainer suggestions** (docs/TRAINER.md)
- [ ] On a train step, the step lists spells your trainer actually has (compare with the trainer window); known spells are not listed.
- [ ] With everything learned, the train step is skipped with "nothing important to train yet". *Off* restores plain train steps.
- [ ] `/tbcg train`, `/tbcg train defer`, `/tbcg train waypoint` (arrow to a class trainer of your faction).
- [ ] A warrior at 10 sees Defensive Stance as "from a class quest". A talent rank (e.g. Mortal Strike 2) appears only after the talent.
- [ ] Nothing is bought unless *Trainer automation* is on.

**Talent window** (docs/TALENTS.md)
- [ ] Press N: numbered markers on the plan's next picks in the open tree, a panel to the right, and a tooltip line on talents.
- [ ] Switching trees moves the markers; spending a point updates them. No point is spent by TBCGuide.
- [ ] Spend a point off-plan: the panel counts the deviation. A spec with no plan (e.g. Subtlety) says so.
- [ ] *Show Talent Suggestions* off: no markers, panel or tooltip line.

**Levels 31-60** (docs/LEVELS_31_60.md)
- [ ] Play a reordered 31-60 guide from a 0.7.0 save: the guide stays on the same step after updating.

### Coverage pass (not yet run in the game)

- [ ] **Alliance 33:** Arathi → Ironforge (Reclaimers breadcrumb) → Menethil → Auberdine → Desolace. Nijel's Point quests accept; the Malem escort completes.
- [ ] **Horde 33:** Thousand Needles → Desolace. Khan Dez'hepah, then Centaur Bounty; the Shadowprey flight path is learned.
- [ ] **Badlands:** the Alliance Ryedol chain reaches Ironforge. The Horde trip to Kargath on foot is survivable, and Kargath's quests accept at 36.
- [ ] **Searing Gorge:** Thorium Point quests accept at 45+. Kalaran's chain reaches Set Them Ablaze!.
- [ ] **Eastern Plaguelands:** Little Pamela is picked up in WPL; Horde sees the Nathanos steps and Alliance does not. The guide ends at 58 and hands off to Hellfire.
- [ ] **Alliance WPL:** Courier Hammerfall in Ironforge gives the call to arms, and the cauldron chain flows through Chillwind Camp.
- [ ] **Horde Feralas and Blade's Edge:** the new loops run in order with no step pointing back across the zone.
- [ ] **Saved progress:** a 0.9.0 (or 0.7.0) save on a reordered guide (e.g. A_WesternPlaguelands, H_Hellfire) stays on the same step.

### Coverage pass 2 (not yet run in the game)

- [ ] **Felwood → Winterspring:** Speak to Salfa leads through the Timbermaw tunnel. The Everlook quests accept at 53-54. Alliance sees Enraged Wildkin; Horde does not.
- [ ] **Horde Stranglethorn → Swamp of Sorrows → Dustwallow:** Stonard and the Misty Reed Strand quests, and the flight out from Stonard.
- [ ] **Dustwallow:** Moxie's quests and the Mudsprocket loop, then the flight to Gadgetzan.
- [ ] **Training costs:** open a class trainer. Train-step lines show prices and a total that matches the trainer. Close it, and the prices show as last seen. A profession trainer does not change them.
- [ ] **Hunter:** call a pet. `/tbcg pet` names its family (also on a non-English client if it has a family skill). Open Beast Training and the training-point costs appear. Nothing is tamed or abandoned.
- [ ] **Warlock:** `/tbcg pet` asks you to summon each demon once. After summoning, Grimoires you still need are listed, ones in your bags are marked, and after using one it drops off.
- [ ] **Assassination:** with the Assassination profile, talent-window markers follow the Wowhead plan, and Mutilate is suggested at 50.

### Junk discard (not yet run in the game)

- [ ] **Off (default):** fill your bags with a grey item, then click the world and press keys. Nothing is destroyed.
- [ ] **On, bags full:** your next click on the world (or key press) destroys the cheapest grey item with no popup, and chat says "Destroyed (not sold)". Only one item per click; the next one goes only if the bags fill again.
- [ ] **Things it must leave alone:** quest items, guide items, protected items and white or green gear. Hold an item on the cursor and click the world: nothing is destroyed and the cursor item stays.
- [ ] **Waits:** with a merchant, mail, bank or trade window open, or in combat, clicks destroy nothing; the first click after closing it (or leaving combat) does.
- [ ] **Loot:** with full bags, click an item in the loot window: junk is destroyed, and a second click loots. Typing in chat and movement keys work as normal throughout.
- [ ] **Turning it off** stops it at once. **Keybind:** *Delete Cheapest Junk Item* destroys one item per key press, with the same checks.

### Hearthstone binding (not yet run in the game)

Turn on the *Enable Debug* setting to see the `bind:` lines in chat (off by default).
- [ ] **Right inn:** on a bind step (for example Goldshire), talk to the step's innkeeper. The bind option is chosen, the dialog is confirmed, chat says "Hearthstone set to ..." and the step completes. Check that the step stays open until that message.
- [ ] **Inn with its own area:** Kharanos, Thelsamar, Menethil Harbor, Brill or Aerie Peak (or The Crossroads, Theramore, Grom'gol): the step completes after binding. If not, note the name your character sheet / hearthstone tooltip shows.
- [ ] **Wrong inn:** talk to another town's innkeeper during a bind step: nothing is chosen, one chat line says so.
- [ ] **Already bound there:** reopen the step (`/tbcg prev`) and talk to the innkeeper: nothing is chosen and the step completes.
- [ ] **Quests first:** an innkeeper with a guide quest to hand in: the quest is handled first; talk again to bind.
- [ ] **Decline / close:** hold Shift (nothing happens) or press No on the dialog yourself, or close the window: nothing is retried, the step stays open.
- [ ] **Setting off:** with Innkeeper Bind automation off, nothing is chosen; binding by hand still completes the step.
- [ ] **Non-English client** (if available): the same as the first item.
