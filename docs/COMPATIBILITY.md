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
