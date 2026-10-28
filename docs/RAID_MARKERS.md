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
| `/tbcg debug marks` | Shows the current step's marker rule, its NPCs, and whether you can mark right now. |

With no target you get a short message, never an error. Marking an icon the target already has is a no-op. The raw API would toggle it off; TBCGuide never does.

## Settings and defaults

| Setting (`/tbcg set ...`) | Default | What it does |
|---|---|---|
| `markEnabled` | on | Turns commands, the bar and guide marking on or off |
| `autoMark` | on | Marks NPCs that the current guide step names with `[mark=...]`. Steps without it leave markers alone |
| `autoMarkObjectives` | off | Also marks kill objectives of unmarked `complete` steps with the default marker |
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

A unit is considered only when you **look at it**: it becomes your target, your mouseover, your focus, or shows a nameplate. TBCGuide never scans for units or changes your target. It marks the unit only if all of these hold:

1. the current step has a marker rule, and the unit's NPC ID is one of the step's NPCs;
2. the unit is alive, and TBCGuide has not already tried it in this step;
3. the unit has no icon, or it already has this icon. With `markReplace` on, an existing icon may be replaced;
4. no other living unit is holding this step's icon, so the icon does not jump between mobs of the same kind;
5. you are allowed to mark (see below).

After each attempt, TBCGuide checks `GetRaidTargetIndex` and reports **"Marked ..."** only if the icon is really there.

- If marking fails twice in a step, automatic marking pauses for that step and tells you to use `/tbcg mark` or the bar.
- If you, another add-on or a group member **changes or removes** an icon TBCGuide placed, that unit is never marked again, and automatic marking pauses for the rest of the step.
- On a step change, only icons TBCGuide placed itself are removed, and only if they are still TBCGuide's and the unit is visible. Icons set by anyone else are never cleared.

## Client rules (TBC Classic 2.5.6)

- **APIs:** `SetRaidTarget(unit, index)` (0 clears) and `GetRaidTargetIndex(unit)`, both listed for TBC Classic 2.5.6 on warcraft.wiki.gg. Units are identified with `UnitGUID`; events used are `RAID_TARGET_UPDATE`, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT` and `NAME_PLATE_UNIT_ADDED`.
- **Who can mark:** solo players and every party member can mark. In a **raid** only the leader and assistants can, so TBCGuide checks first and explains instead of trying.
- **Visibility:** icons are only shown to your group. Solo, only you see them.
- **Protected functions:** Retail 12.0 made `SetRaidTarget` callable only from secure code. This is not documented for 2.5.6, and TBCGuide does not assume either way. Calls are wrapped in `pcall`, and `ADDON_ACTION_BLOCKED`/`ADDON_ACTION_FORBIDDEN` are watched. If the client blocks marking, automatic marking switches off with a message.
- **Marker bar:** its buttons are `SecureActionButtonTemplate` macro buttons, so a click is a normal player action that works even when the API is secure-only. Secure frames cannot be shown or hidden in combat, so `/tbcg markbar` waits until you leave combat.

## Limits

- An icon can only be cleared through a unit you can see (target, mouseover, focus or nameplate). Icons on units out of sight are left for the game to clear (for example, on death).
- Only NPCs in the bundled QuestieDB data can be named in guides.
- Not verified in the game client yet; see the checklist in docs/COMPATIBILITY.md.
