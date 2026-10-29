# Raid markers

Added in 0.3.0. TBCGuide can put the game's own raid target icons (star, circle, diamond, triangle, moon, square, cross, skull) on units. You can mark by hand, or let guide steps mark the NPCs they are about.

Settings live under **Interface > AddOns > TBCGuide > Raid markers**, or `/tbcg markers`.

## Commands

| Command | What it does |
|---|---|
| `/tbcg mark [icon]` | Marks your target. Without an icon it uses the default marker (skull). Icons: `star circle diamond triangle moon square cross skull` or `1`-`8`. |
| `/tbcg unmark` | Clears your target's marker. |
| `/tbcg marker <icon>` | Sets the default marker. |
| `/tbcg markbar` | Shows or hides the marker bar: 8 icon buttons plus *clear*, for your current target (out of combat only). |
| `/tbcg markers` | Opens the raid marker settings. |
| `/tbcg debug marks` | Shows the settings, the current rule (each icon and its NPCs) or why there is none, whether you can mark right now, and the last marking decision (no match, already marked, not permitted, blocked, marked, ...). With `/tbcg set debug on`, attempts and refusals are also logged to chat. |

With no target you get a short message, never an error. Marking an icon the target already has is a no-op. The raw API would toggle it off; TBCGuide never does.

## Settings and defaults

| Setting (`/tbcg set ...`) | Default | What it does |
|---|---|---|
| `markEnabled` | on | Turns commands, the bar and guide marking on or off |
| `autoMark` | on | Guide marking: NPCs that the current steps name with `[mark=...]` |
| `autoMarkObjectives` | on (changed after 0.4.0) | Also marks the kill objectives of the current `complete` steps, one icon per step (see below). Settings saved by older versions are switched on once, with a chat note |
| `markReplace` | off | Lets automatic marking replace an icon that is already on the unit |
| `markClearOnAdvance` | on | Removes TBCGuide's own automatic icons when the step changes or another guide is loaded |
| `markNotify` | on | Chat messages for marking results |
| Default marker | skull | Dropdown on the settings page, or `/tbcg marker <icon>` |

## Guide data: `[mark=...]`

A step flag (docs/GUIDE_FORMAT.md) lets the compiler resolve NPC IDs from the bundled QuestieDB data:

```
complete 790 Sarkoth [mark=skull]                          # the quest's kill target / item dropper
complete Vanquish the Betrayers [mark=cross:Lieutenant Benedict]   # one named objective NPC
turnin Report to Gryan Stoutmantle [mark=star]             # the quest finisher
talk Some NPC [mark=moon]                                  # the talk target
complete Some Quest [mark=square:1234]                     # an explicit NPC id
accept Some Quest                                          # no flag: markers are left alone
```

| Step | `[mark=icon]` marks |
|---|---|
| `accept` | the quest's giver NPCs |
| `turnin` | the quest's finisher NPCs |
| `talk` | that NPC |
| `complete` | the kill-objective creatures, plus the NPCs that drop a quest item when the item has at most 3 drop sources (e.g. a named mob's head) |

- `[mark=icon:<id>]` names an NPC ID, which must exist in the database.
- `[mark=icon:<name>]` names an NPC by exact name. The compiler narrows it to the NPCs the step is about, then to the zone. **If more than one NPC ID remains, the build fails** and lists the IDs to choose from.
- The compiled step carries `mark = { i = <1-8>, npcs = { ids } }`. At runtime, units are matched **only by NPC ID**, taken from their GUID; names are never used.

Examples in the shipped guides:

- Elwynn: *Bounty on Garrick Padfoot*, skull;
- Durotar: *Sarkoth*, skull; *Vanquish the Betrayers*, cross on Lieutenant Benedict;
- Eversong: *Wanted: Thaelis the Hungerer*, skull;
- Westfall: Gryan Stoutmantle, star.

## How automatic marking behaves

**Which NPCs.** The rule covers the current step plus the open `complete` steps right after it (guides list kill objectives you do together one after another). Each step gets one icon:

- a step with `[mark=icon...]` keeps that icon for its NPCs;
- otherwise, with `autoMarkObjectives` on, its quest's kill-objective creatures, kill-credit NPCs and the droppers of its quest items get an icon. Item droppers count only when at most 3 NPCs drop the item, the same rule the compiler uses. Icons are handed out in the order: default marker, skull, cross, square, moon, triangle, diamond, circle, star. Icons already used by `[mark]` steps are skipped, and at most 4 icons are used, so different mob types never share or fight over one icon. All NPC IDs of one step (variants of one mob) share its icon. A mob type keeps its icon when an earlier step finishes.

Units are matched **only by NPC ID** from their GUID, so a mob with the same name but a different ID, or an unrelated mob, is never marked.

**When.** A unit is considered only when you **look at it**: it becomes your target, your mouseover, your focus, or shows a nameplate. TBCGuide never scans for units or changes your target. It marks the unit only if all of these hold:

1. its NPC ID is in the current rule;
2. the unit is alive, and TBCGuide has not already tried it in this step;
3. the unit has no icon, or it already has this icon. With `markReplace` on, an existing icon may be replaced;
4. no other living unit holds that icon for this step, so the icon does not jump between mobs of the same kind. The holder loses it when it dies (seen from the combat log's `UNIT_DIED`; the game removes a dead mob's icon without a `RAID_TARGET_UPDATE`), when it is visible without the icon, or when it has not been seen for 60 seconds. The next matching mob you look at then gets the icon;
5. you are allowed to mark (see below).

After each attempt, TBCGuide checks `GetRaidTargetIndex` and reports **"Marked ..."** only if the icon is really there.

- If marking fails twice in a step, automatic marking pauses for that step and tells you to use `/tbcg mark` or the bar.
- If you, another add-on or a group member **changes or removes** an icon TBCGuide placed on a living unit, that unit is never marked again, and automatic marking pauses for the rest of the step. A unit that lost its icon by dying does not count.
- On a step change, icons the new rule still wants (same NPC, same icon) stay. Other icons TBCGuide placed are removed, but only if they are still TBCGuide's and the unit is visible. Icons set by anyone else are never cleared.
- Marking is not limited in combat; the client does not restrict it there.

## Client rules (TBC Classic 2.5.6)

- **APIs:** `SetRaidTarget(unit, index)` (0 clears) and `GetRaidTargetIndex(unit)`, both listed for TBC Classic 2.5.6 on warcraft.wiki.gg. Units are identified with `UnitGUID`; events used are `RAID_TARGET_UPDATE`, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `NAME_PLATE_UNIT_ADDED` and `COMBAT_LOG_EVENT_UNFILTERED` (only `UNIT_DIED` of units TBCGuide marked is read). warcraft.wiki.gg documents that `RAID_TARGET_UPDATE` does not fire when a marked mob dies, although the icon is removed.
- **Who can mark:** solo players and every party member can mark. In a **raid** only the leader and assistants can, so TBCGuide checks first and explains instead of trying.
- **Visibility:** icons are only shown to your group. Solo, only you see them.
- **Protected functions:** Retail 12.0 made `SetRaidTarget` callable only from secure code. This is not documented for 2.5.6, and TBCGuide does not assume either way. Calls are wrapped in `pcall`, and `ADDON_ACTION_BLOCKED`/`ADDON_ACTION_FORBIDDEN` are watched. If the client blocks marking, automatic marking switches off with a message.
- **Marker bar:** its buttons are `SecureActionButtonTemplate` macro buttons, so a click is a normal player action that works even when the API is secure-only. Secure frames cannot be shown or hidden in combat, so `/tbcg markbar` waits until you leave combat.

## Limits

- An icon can only be cleared through a unit you can see (target, mouseover, focus or nameplate). Icons on units out of sight are left for the game to clear (for example, on death).
- Only NPCs in the bundled QuestieDB data can be named in guides.
- Not verified in the game client yet; see the checklist in docs/COMPATIBILITY.md.
