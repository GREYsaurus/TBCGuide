# Settings window

`/tbcg options`, or left-click the minimap button, opens the TBCGuide settings window. It has one row of tabs: **General, Guide Routing, Targeting, Leveling Tracker, Communications, Tips, Advanced Settings, Profiles, Help**. Escape closes it. Changes apply immediately and are saved in your current profile.

Under the title bar are five buttons:
- **Guide Browser** opens the guide browser.
- **Talent Guide** opens the talent guide.
- **Leveling Report** shows time per level and XP per hour.
- **Report an Issue** shows a link to copy.
- **Choose the Best Guide for Me** loads the guide that fits your race, class and level.

Every option in the window works; none is a greyed-out placeholder.

None of this has been tested in the game client yet.

**Look:** every TBCGuide window shares one flat dark style with a blue accent. The colours are in one table, `W.THEME` in `TBCGuide/UI/Widgets.lua`.

## What each tab controls

### General
- **First-login setup:** a new character gets a short setup window: guide, spec profile, and an explicit opt-in for automatic upgrades (off unless ticked, and only with a spec profile). Saved per character. *Skip* keeps the defaults; closing it keeps the choices for next time. *Open setup* (General) reopens it. Characters that already used TBCGuide are not asked.
- **Window Management:** *Show all Enabled Frames* hides the guide window and arrow together when off. *Lock Frames* and *Autohide in Raids* do what they say.
- **Features:** minimap button, world map button (opens the guide browser), *Hide Window* and *Hide waypoint arrow*.
- **Automation:**

  | Option | Default | What it does |
  |---|---|---|
  | Quest auto accept/turn in | on | Guide quests only. More options: `/tbcg automation` |
  | Quest auto rewards | off | Takes a reward only when gear scoring shows one clear upgrade, or when your class can use none of them (then the most valuable). Otherwise you choose |
  | Class Trainer Suggestions | Important only | Off / Important only / All: what your trainer has for you, checked against your spellbook; train steps with nothing new are skipped. Never buys (docs/TRAINER.md) |
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
- **Features:**
  - *Hide Active Item window* (off by default): buttons for usable quest items in your bags. Click one to use the item. They update after combat, because secure buttons can't change in combat.
  - *Enable Vendor Treasures* (on): when a merchant opens, lists and marks items it sells that are upgrades for your spec profile, the same estimate as automatic upgrades. Needs a spec profile.
  - *Show Flight Timers* (on): a bar with the time left on a flight. TBCGuide ships no flight data, so each route is timed the first time you fly it and counts down after that.
  - *Enable Group Settings* (off): master switch for the party features on the Communications tab and the leader's target on the Targeting tab.
- **Window:**
  - *Guide Window Scale* (60-160%);
  - *Guide Font Size* (9-18);
  - *Arrow Scale* (50-200%).

  These apply as you drag, and the window and arrow stay where they are on screen. *Reset Window Settings* puts just these three back to their defaults.
- **Inventory:** *Show junk item indicator* (off) puts a coin on bag items the inventory manager would sell.
- **Talents:**
  - *Show Talent Suggestions* (on): markers, a panel and tooltip lines in the default talent window for your spec profile's plan. Never spends points (docs/TALENTS.md).
  - *Enable Talents Guides* turns on the chat reminders to spend talent points.
  - *Enable Talent Plan* and *Talent Plan Number* add your build's next picks to those reminders. `/tbcg talents plan` shows them any time.

### Guide Routing
- *Skip overleveled steps* (on) skips picking up quests that are grey for your level, unless a later quest in the guide needs them.
- *Show Group Quests*, *Maximum-speed route*, *Advance steps automatically* and *Pick a guide on first login*.
- **Include Dungeon Quests** (on by default). Off leaves out every step tagged as a dungeon quest: its pickup, objective and turn-in.
  - **Follow-ups** that need an excluded dungeon quest are skipped too, with the reason shown, and the guide continues with the next step.
  - **Already in your log:** a dungeon quest you have already accepted keeps its steps, and TBCGuide never abandons quests.
  - **Applies immediately,** and turning it back on restores the steps without touching your progress.
  - **Tagged today:** only Horde Ashenvale *Amongst the Ruins* (Blackfathom Deeps), because it's the only guide quest that needs an instance.
- **Single dungeons:** one switch per dungeon of your faction. A dungeon marked * has quests in the guides; today that's only Blackfathom Deeps.
  - **Select Recommended Dungeons** keeps the ones you haven't outleveled that start at most 8 levels above you.
  - **Select all Dungeons** turns them all back on.
  - Level ranges are the usual approximate ones (`TBCGuide/Database/Dungeons.lua`).

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
- **Active Target Frame:** click-to-target buttons (`/tar <name>`) for the current step's NPCs.
  - **Who:** enemies in red, quest givers and finishers in green.
  - **Party leader:** *Follow Party Leader Target* adds your party leader's target. It needs *Enable Group Settings*.
  - **Look:** background on or off, scale, and *Reset Window Position*.
  - **Combat:** it updates after combat.

### Leveling Tracker
- **What it tracks:** how long each level takes, using played time from the server (asked for quietly at login), and your XP per hour this session.
  - Levels finished before this version show as `-`.
- **Leveling report:** `/tbcg tracker` or the button at the top of the window. It shows:
  - the current level's time;
  - XP per hour, and an estimate of when you'll level;
  - total played time;
  - your average time per level.

  *Always Open Leveling Report With Character Panel* opens it with the character window.
- **Level Splits:** a small window with the time each recent level took.
  - *History* sets how many levels it shows.
  - *Compare Next Level* compares the running level with the previous one.
  - Also: total time, font size, opacity and hiding the background.

### Communications
- **Enable Addon Version Checks** (on): tells you once when a group or guild member runs a newer TBCGuide.
  - Uses hidden add-on messages; nothing appears in chat.
  - It's also how TBCGuide knows which party members use it.
- **Level-up announcements** to emote, party or guild chat. All are off by default.
- **Party announcements** (all off by default, and all need *Enable Group Settings*):
  - *Announce Step completion*: a guide quest's objectives are all done.
  - *Announce Step collection*: progress, such as *Wolf Meat: 3/8*.
  - *Announce Step flying timers*: you took a flight, with the arrival time once the route is known.
  - *Don't announce when Questie is loaded*: avoids double messages, since Questie can announce progress itself.
  - **Never in raids.** They are only sent when another party member runs TBCGuide, unless *Send announcements without another TBCGuide user in group* is on.
- *Automatic quest sharing*: shares a guide quest with your party right after you accept it.

### Tips
- **Drowning:** warning, sound, threshold, screen-edge flash.
- **Emergency Actions:** low-health warning, threshold, sound, flash.
- **Rare mobs:** *Track Rare Mobs* gives a chat alert and sound when a rare's nameplate appears (rares from the bundled database). It can skip rares this character already killed.
- **Map pins:** both come from the bundled data, which covers quest NPCs and mobs, not every elite in the game.
  - *Track Mobs on Map*: world map pins for elite and rare mobs in the zone shown.
  - *Track Treasures*: pins for treasure chests.
- **Item Upgrade:**
  - gear scoring switches;
  - the **Spec profile** (per character; your class's profiles only);
  - quest reward recommendation and automation.

  See [GEAR_SCORING.md](GEAR_SCORING.md).
- **Automatic Upgrades** (opt-in): see [AUTO_EQUIP.md](AUTO_EQUIP.md).
  - **Equipping:** *Enable automatic upgrades* asks first and needs a spec profile. Unbound Bind-on-Equip items are never equipped automatically, and no setting changes that.
  - **Other options:**
    - *Fill empty gear slots*;
    - *Minimum upgrade* (%);
    - on-screen and chat equip messages;
    - *Mark Bind-on-Equip upgrades in bags*;
    - *Clear excluded items*.
- **Protected Slots:** one switch per gear slot. Automatic upgrades never change a protected slot.

### Advanced Settings
- *Enable Debug*.
- *Update Frequency (ms)*: how often the arrow redraws.
- *Low Quality Settings*: the arrow redraws at most every 150 ms, and the map shows fewer pins.
- *Pre load all data*: at login, and when you change guide, asks the game for the item data your guide's quests and your bags use, so tooltips and scoring don't wait.
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

## Removed

**The Look and Feel tab** is gone. Its settings keep their current values but can no longer be changed in the window:
- text colours;
- guide window scale, font size, steps shown and step list;
- arrow scale;
- map pin and TomTom.

**Options with nothing to act on in TBCGuide** were removed:
- *Detect Rate* and *Experience rates*;
- *Solo Self Found Mode*;
- *Enable Beta Features*;
- *Hearthstone batching* and its window size;
- *Quest Log Size*: the TBC quest log is fixed at 25.

**Removed before 1.0:** three placeholders that were never built:
- *Follow Party Leader Macro*;
- *Quest Sellable Recommendation*;
- *Always Show Total EP*.

Gear scoring itself is unchanged.

**Enable Auctioneer** (Tips → Item Upgrade, on): adds the auction house **Upgrades** tab. See [AUCTION.md](AUCTION.md).
- **Scanning:** you start each scan yourself while the auction house is open.
- **Prices:** they are the cheapest buyouts that scan saw, so old or partial scans may no longer match what's for sale.
- **Never automatic:** nothing is ever bought.
