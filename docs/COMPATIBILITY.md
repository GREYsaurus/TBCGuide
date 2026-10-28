# Client compatibility

## Target

| | Value | How established |
|---|---|---|
| Game | World of Warcraft: The Burning Crusade Classic, **Anniversary realms** (TBC pre-patch 2026-01-13, launch 2026-02-05) | public news coverage |
| Client build | **2.5.6.70577** | wago.tools build list, product `wow_anniversary` (checked 2026-10-28) |
| TOC interface | **20506** | Questie `bundle/v12.3.1` `release.json` (flavor `bcc`, interface 20506); RestedXP's `RXPGuides_TBC.toc` also uses 20506 |
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
