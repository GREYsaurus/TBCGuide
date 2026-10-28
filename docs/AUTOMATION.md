# Automation: quests, junk and orphaned quests

Added in 0.2.0. Settings live under **Interface > AddOns > TBCGuide > Automation**, or `/tbcg automation`. Every option can also be changed with `/tbcg set <option> on|off`.

**Hold Shift** while talking to an NPC or opening a vendor to skip all automation for that interaction.

## Defaults

| Setting (`/tbcg set ...`) | Default | What it does |
|---|---|---|
| `autoAccept` | **on** | Accept quests that have an open accept step in the **active guide** |
| `autoAcceptOptional` | off | ...also guide steps marked `[optional]` |
| `autoAcceptGroup` | off | ...also `[elite]`, `[group]` and `[dungeon]` steps |
| `autoTurnIn` | **on** | Turn in guide quests that need no reward choice |
| `turnInUnrelated` | off | Also turn in completed quests that are not in the guide (repeatable quests are never included) |
| `questNotify` | on | Chat messages for accepted, turned-in and manual-only quests |
| `autoSellJunk` | **off** | Sell junk when a vendor window opens |
| `sellNotify` | on | One-line summary of each junk sale |
| `sellNotifyItems` | off | One chat line per item sold |
| `speedRoute` | off | Maximum-speed route: hide `[optional]` side quests (guide and automation) |

Why these defaults: quest automation only touches quests the guide was going to send you to anyway, so it is on. Junk selling removes items from your bags, and buyback only holds the last 12, so it is opt-in.

## Rules that no setting can change

1. **Escort and scripted-event quests are never accepted automatically.** A quest is treated as manual-only if **any** of these is true:
   - it is on the curated list in `Database/EscortQuests.lua` (55 quests), or on your own list (`/tbcg escort add <questID>`);
   - its QuestieDB `questFlags` has `PARTY_ACCEPT` (bit 2). cmangos sets this on escort-type quests; it also catches a few "defend/wait" event quests, which stay manual too;
   - the database objective or trigger text, or the text the client shows on the offer panel, reads like an escort ("escort", "accompany", "safely", "lead ... back to", "Protect/Follow/Defend <Name>", "stay alive");
   - the quest is **not in the bundled database** at all (status unknown).

   The guide prints *"... is an escort/event quest ... Accept it manually"* instead. 32 of the 1,222 quests the guides accept are manual-only under these rules (29 by the flag, 3 by the curated list) (`/tbcg debug escort <id>` shows the reason for any quest). Party escort confirmations (`QUEST_ACCEPT_CONFIRM`) are never answered by the add-on.
2. **A reward is never chosen for you.** If the reward panel offers more than one choice, the add-on stops, leaves the panel open and prints *"Choose your reward"*. The guide advances only when the game reports `QUEST_TURNED_IN`. With zero or one reward there is nothing to choose: the default UI pre-selects a single reward, and the add-on clicks *Complete Quest*. If the client cannot report the number of choices, the quest stays manual.
3. **Nothing is reported until the game confirms it.** "Accepted" waits for `QUEST_ACCEPTED`, and "Turned in" waits for `QUEST_TURNED_IN`. A junk sale counts only when the bag slot is actually empty. If confirmation does not arrive within 4 seconds, you get a "could not confirm" message and the guide does not advance.
4. **Quests shared by other players are never accepted automatically**, and quests that **cost money** to complete stay manual.

## Quest automation flow

| Window | What happens |
|---|---|
| Gossip / greeting list | Completed guide quests are turned in first (they often unlock the next ones). Then **one** guide quest is opened. The game re-shows the list and the add-on runs again, so a hub is emptied in a few automatic steps. Escort quests are not even opened. |
| Quest offer (`QUEST_DETAIL`) | Accepted if it is an open guide quest and passes the checks: not an escort, not already in the log, log not full (25), not shared by a player. |
| Progress (`QUEST_PROGRESS`) | *Continue* is clicked if the quest is completable and is a guide turn-in. |
| Reward (`QUEST_COMPLETE`) | 0-1 rewards: completed. 2+ rewards: you choose (rule 2). |

Quests are matched by **quest ID**. On old-style greeting windows that show only titles, a title is used only if exactly one open guide step has that title, and the offer panel's `GetQuestID()` is still checked before accepting. The same quest is not re-tried for 5 seconds.

## Junk selling

When `autoSellJunk` is on and a vendor window opens, the add-on sells bag items (backpack and bags 1-4, never the bank or keyring) that pass **every** check:

- item quality is **Poor (grey)**, the game's own junk classification. Cheap white/green items are never candidates;
- item info is loaded, the item has a sell price, and the slot is not locked;
- not a quest item: not item class *Quest*, not quest-bound, not flagged by the client as a quest item, and not an item that starts a quest;
- not needed by any quest in your log or any open step of the active guide (objective items and items the quest giver hands you);
- not on your protected list (`/tbcg protect <itemID|link>`, or the box on the settings page);
- not in a protected category. Consumable, Container, Reagent, Trade Goods and Recipe are protected by default and can be changed. Quest and Key are always protected.

Items are sold one at a time, 0.2 s apart. Each slot is tried once per visit. Selling stops when the vendor closes. The summary reports **confirmed** sales and copper (sell price × stack, which is exactly what vendors pay). The settings page and `/tbcg protected` show the running total.

## Orphaned quests

**"Orphaned"** means the quest is in your log, but no open step of the active guide and no step of any **later guide on your route** (the `@next` chain to 70) accepts, completes or turns it in. For example, Westfall's *The Killing Fields* picked up while still in Elwynn is **not** orphaned, because the Westfall guide turns it in later.

- Open with the **Orphaned (N)** button on the quest log window, or `/tbcg orphans`.
- Orphaned quests are ticked by default. Class, profession and seasonal quests are listed but **not** ticked.
- **Abandon N** asks for confirmation in a standard dialog ("This cannot be undone"). Quests are then abandoned one at a time using the default UI's own sequence. Before each one, the quest ID at that log position is re-checked, so a shifted log can never drop the wrong quest. Only removals the game confirms are reported.
- With no guide loaded, nothing is called orphaned.

## Client API evidence (TBC Classic 2.5.6, interface 20506)

The add-on could not be run in the client for this release. The APIs were chosen from:

- **Questie v12.3.1** (`Questie_TBC.toc` declares interface **20506**; master branch, checked 2026-10-28). Its `Modules/Auto/AutoQuesting.lua` and `Modules/QuestieCompat.lua` drive these calls on this client: `GetQuestID`, `AcceptQuest`, `CompleteQuest`, `IsQuestCompletable`, `GetNumQuestChoices`, `GetQuestReward`, the greeting functions, `C_GossipInfo.GetAvailableQuests/GetActiveQuests`, and `C_GossipInfo.SelectAvailableQuest/SelectActiveQuest` **with a quest ID**. Bags use `C_Container.*`, with the legacy globals as fallback. Questie also auto-confirms party escorts and accepts quests from players; TBCGuide deliberately does neither.
- **warcraft.wiki.gg** lists `C_GossipInfo.SelectAvailableQuest` (argument changed from index to `optionID`/questID in 10.0.0), `C_GossipInfo.GetAvailableQuests` (fields include `questID`) and `C_Container.UseContainerItem` for Burning Crusade Classic 2.5.6.

Every call goes through `Compat/Compat.lua` with nil-checks and legacy fallbacks. Each API is on the reviewed allowlist (`tools/wow_api_allowlist.txt`). `/tbcg debug api` shows which ones your client has.

## What was tested, and what still needs the game

Tested headless (`tests/test_automation.lua` with real Lua 5.1 and mocked client APIs):

- junk: off by default; only eligible greys sold; 10 kinds of protected items kept; refused sales reported and not retried; Shift and cursor suppression; stops when the vendor closes; totals;
- quests: guide-only acceptance; escort exclusion by each signal (flag, curated list, live text, unknown quest, user list), even with every option on; no auto-confirm of party escorts; full log; player shares; Shift; confirmation-before-success; failed accept and turn-in not claimed; reward choice left to the player, then the guide resumes after `QUEST_TURNED_IN`; unrelated and repeatable turn-ins; title fallback on greeting windows;
- orphans: route-aware detection, special quests not pre-selected, confirmation required, index safety.

**Needs in-game verification** (see the checklist in `docs/COMPATIBILITY.md`): that each API exists and behaves as above on 2.5.6, gossip and greeting quest IDs, `GetNumQuestChoices` on the reward panel, sale timing against server throttling, the quest-log button position, and the confirmation dialog.
