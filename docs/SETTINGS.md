# Settings window

`/tbcg options`, or left-click the minimap button, opens the TBCGuide settings window. It has two rows of tabs: **General, Guide Routing, Targeting, Leveling Tracker, Communications, Tips, Help** and **Look and Feel, Advanced Settings, Profiles**. Escape closes it. Changes apply immediately and are saved in your current profile.

Above the tabs are four buttons:
- **Guide Browser** opens the guide browser.
- **Talent Guide** opens the talent guide.
- **Report an Issue** shows a link to copy.
- **Choose the Best Guide for Me** loads the guide that fits your race, class and level.

Options shown **greyed out** are planned and do nothing yet; hovering one says so. Nothing in the window pretends to work. Not tested in the game client yet.

## What each tab controls

### General
- **Window Management:** *Show all Enabled Frames* hides the guide window and arrow together when off. *Lock Frames* and *Autohide in Raids* do what they say.
- **Features:** minimap button, world map button (opens the guide browser), *Hide Window* and *Hide waypoint arrow*.
- **Automation:**

  | Option | Default | What it does |
  |---|---|---|
  | Quest auto accept/turn in | on | Guide quests only. More options: `/tbcg automation` |
  | Quest auto rewards | off | Takes a reward only when gear scoring shows one clear upgrade, or when your class can use none of them (then the most valuable). Otherwise you choose |
  | Trainer automation | off | Learns every spell you can afford at your class trainer; spends gold |
  | Flight Path automation | on | On a "fly to" step, takes that flight when the flight map opens |
  | Innkeeper Bind automation | on | On a "set your hearthstone" step, picks the innkeeper's bind option and confirms it |
  | Skip Gossip | on | Picks the only option when an NPC has one option and no quests (never a bind option outside a bind step) |

  Hold **Shift** while talking to an NPC to skip all of these once.
- **Inventory:**
  - *Enable Inventory Manager* is the master switch for everything below it.
  - *Toggle junk with modified right click*: modifier + right-click a bag item adds it to, or removes it from, your junk list. You pick the modifier.
  - *Auto Sell Junk*.
  - *Discard junk items if bag is full* (off by default) deletes the junk item worth least at a vendor when your bags are full.
  - *Delete Cheapest Junk Item Keybind* (click, then press a key; right-click unbinds).
  - *Reset Junk List*.
  - Junk means grey items plus your junk list. Quest, quest-starting, guide-needed and protected items are never sold or deleted, and nothing is deleted in combat.
- **Talents:** *Enable Talents Guides* turns on the chat reminders to spend talent points.

### Guide Routing
- *Skip overleveled steps* (on) skips picking up quests that are grey for your level, unless a later quest in the guide needs them.
- *Show Group Quests*, *Maximum-speed route*, *Advance steps automatically* and *Pick a guide on first login*.
- **Include Dungeon Quests** (on by default). Off leaves out every step tagged as a dungeon quest: its pickup, objective and turn-in.
  - **Follow-ups** that need an excluded dungeon quest are skipped too, with the reason shown, and the guide continues with the next step.
  - **Already in your log:** a dungeon quest you have already accepted keeps its steps, and TBCGuide never abandons quests.
  - **Applies immediately,** and turning it back on restores the steps without touching your progress.
  - **Tagged today:** only Horde Ashenvale *Amongst the Ruins* (Blackfathom Deeps), because it's the only guide quest that needs an instance.
- Choosing single dungeons is planned.

### Targeting
- *Enable Targeting* turns raid markers on or off.
- *Maximize Nameplate Distance* sets the game's nameplate distance to 41 yards and restores your old value when turned off.
- **Target Markers:**
  - *Mark Enemy Targets*: guide `[mark]` NPCs.
  - *Mark Enemy Mobs*: kill objectives.
  - *Mark Friendly Targets*: the quest giver or finisher.
  - *Enable Target Markers (Group)*.
  - Replace and clear options, and the default marker. See [RAID_MARKERS.md](RAID_MARKERS.md).
- **Targeting Macro:**
  - *Create Targeting Macro* keeps a "TBCGuide" macro with `/tar` lines for the current step's NPCs. Drag it to an action bar from the Macros window, General tab. It's never edited in combat.
  - *Notify on new target* prints one chat line when a current-step NPC first comes into view.
- **Raid Marker Bar:** shows or hides the marker bar.

### Communications
- Level-up announcements to emote, party or guild chat. All are off by default.

### Tips
- **Drowning:** warning, sound, threshold, screen-edge flash.
- **Emergency Actions:** low-health warning, threshold, sound, flash.
- **Rare mobs:** *Track Rare Mobs* gives a chat alert and sound when a rare's nameplate appears (rares from the bundled database). It can skip rares this character already killed.
- **Item Upgrade:** gear scoring switches, the scoring profile ("Talents"), and quest reward recommendation and automation. See [GEAR_SCORING.md](GEAR_SCORING.md).

### Look and Feel
- **Text colours:** friendly NPCs, quests and warnings in the guide window, plus *Reset Colors*.
- **Guide window:** scale, font size, number of steps shown, *Show step list*, reset window positions.
- **Waypoint arrow:** scale, reset position.
- **Map:** world map pin, TomTom waypoints.

### Advanced Settings
- *Enable Debug*.
- *Update Frequency (ms)*: how often the arrow redraws.
- *Check for Addon Incompatibility*: warns at login when another leveling guide add-on is loaded.
- **Debug section:**
  - *Disable step skips*: nothing is skipped automatically.
  - *Display Lua Errors*: the game's own error pop-up.
  - *Disable Map Pins*.

### Profiles
- **Profiles hold settings.** Guide progress, talents and junk-sale totals always stay with the character.
- **Current Profile** shows which one this character uses. A **new** profile starts from the defaults.
- **Existing Profiles** switches profile.
- **Copy From** copies another profile's settings into the active one.
- **Delete a Profile** removes one; the active and default profiles cannot be deleted. Characters that used a deleted profile fall back to the default.
- **Reset Profile** restores the defaults.
- **Set current profile as default** makes new characters start with it.
- Settings saved before 0.5.0 become the **Default** profile automatically.
- *Reload guides and UI* and *Reset Guide Progress* (asks first) are at the top.

## Planned (shown greyed out)

- **General:** Active Item window, Vendor Treasures, Flight Timers, Group Settings, junk item indicator in bags, talent plan.
- **Guide Routing:** experience-rate detection, Solo Self Found mode, dungeon selection.
- **Targeting:** follow-leader macro, Active Target frame.
- **Leveling Tracker:** the whole tab.
- **Communications:** version checks, step announcements, quest sharing.
- **Tips:** map tracking of dangerous mobs and treasures, auctioneer and total EP display, sellable-quest-item hints.
- **Look and Feel:** themes, kill, loot and buy colours, arrow text size, active items, extra map-pin options.
- **Advanced:** beta features, low-quality mode, hearthstone batching, preloading, quest log size.
