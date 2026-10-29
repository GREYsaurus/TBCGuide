-- TBCGuide - contents of the settings window (rendered by UI/Config.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Every control changes a real setting. (UI/Config.lua can still render `planned` items, but 1.0 has none.)
-- Settings live in the active profile (ns.db.profile); see Core/SavedVars.lua for defaults.

local _, ns = ...

local function T(key, label, extra)
    local it = { type = "toggle", key = key, label = label }
    for k, v in pairs(extra or {}) do it[k] = v end
    return it
end
local function H(text) return { type = "header", text = text } end
local function prof() return ns.db.profile end

local MODIFIERS = { { "CTRL", "CTRL" }, { "ALT", "ALT" }, { "SHIFT", "SHIFT" } }

local pages = {}
ns.ConfigPages = pages

pages.general = { title = "General", items = function() return {
    T("showAllFrames", "Show all Enabled Frames", { tip = "Shows the guide window and the arrow. Off hides both." }),
    T("locked", "Lock Frames"),
    T("autohideRaid", "Autohide in Raids", { tip = "Hides the guide window and arrow while you are in a raid group." }),
    { type = "button", label = "Open setup", tip = "The first-login setup: starting guide, spec profile and automatic upgrades.",
      func = function() ns.Config.frame:Hide() ns.Welcome:Open() end },
    H("Features"),
    T("showMinimapButton", "Enable Minimap Button"),
    T("worldMapButton", "Enable World Map Button", { tip = "A button on the world map that opens the guide browser." }),
    T("hideWindow", "Hide Window"),
    T("showArrow", "Hide waypoint arrow", { invert = true }),
    T("activeItems", "Hide Active Item window", { invert = true, tip = "Buttons for usable quest items in your bags; click one to use the item." }),
    T("vendorTreasures", "Enable Vendor Treasures", { tip = "When a merchant opens, lists and marks the items it sells that are upgrades for your spec profile." }),
    T("flightTimers", "Show Flight Timers", { tip = "A bar with the time left on a flight. Each route is timed the first time you fly it." }),
    T("groupFeatures", "Enable Group Settings", { tip = "Master switch for the party features on the Communications tab and the leader's target on the Targeting tab." }),
    H("Automation"),
    { type = "toggle", label = "Quest auto accept/turn in",
      get = function() return prof().autoAccept and prof().autoTurnIn end,
      set = function(v) prof().autoAccept, prof().autoTurnIn = v, v ns.QuestAuto:Rebuild() end,
      tip = "Guide quests only. Escort quests are never accepted automatically. More options: /tbcg automation." },
    T("autoReward", "Quest auto rewards", { tip = "Takes a reward only when gear scoring shows one clear upgrade, or when your class can use none of them (then the most valuable). Otherwise you choose." }),
    { type = "select", key = "trainerSuggestions", label = "Class Trainer Suggestions",
      values = function() return { { "off", "Off" }, { "important", "Important only" }, { "all", "All" } } end,
      tip = "Lists the spell ranks your class trainer has for you, checked against your spellbook. Train steps with nothing to learn are skipped. Never buys anything.",
      after = function() if ns.Engine then ns.Engine:Refresh() end end },
    T("trainerAuto", "Trainer automation", { tip = "Learns every spell you can afford when you open your class trainer. Spends gold. Hold Shift to skip." }),
    T("flightAuto", "Flight Path automation", { tip = "On a 'fly to' step, takes the flight to that destination when the flight map opens. Hold Shift to skip." }),
    T("bindAuto", "Innkeeper Bind automation", { tip = "On a 'set your hearthstone' step, picks the innkeeper's bind option and confirms it." }),
    T("skipGossip", "Skip Gossip", { tip = "Picks the only option when an NPC has one option and no quests. Hold Shift to skip." }),
    H("Window"),
    { type = "range", key = "scale", label = "Guide Window Scale", min = 0.6, max = 1.6, step = 0.05, percent = true, decimals = 2 },
    { type = "range", key = "guideFontSize", label = "Guide Font Size", min = 9, max = 18, step = 1 },
    { type = "range", key = "arrowScale", label = "Arrow Scale", min = 0.5, max = 2, step = 0.05, percent = true, decimals = 2 },
    { type = "button", label = "Reset Window Settings", tip = "Puts guide window scale, font size and arrow scale back to their defaults. Positions are kept.",
      func = function()
          local d = ns.PROFILE_DEFAULTS
          prof().scale, prof().guideFontSize, prof().arrowScale = d.scale, d.guideFontSize, d.arrowScale
          ns.Config:Changed()
      end },
    H("Inventory"),
    T("inventoryManager", "Enable Inventory Manager", { tip = "Master switch for junk selling, the junk list and junk deletion." }),
    { type = "newline" },
    T("junkIndicator", "Show junk item indicator", { tip = "A coin on bag items the inventory manager would sell." }),
    { type = "toggle", key = "discardJunkFull", label = "Discard junk items if bag is full", span = 2,
      tip = "When your bags are full, deletes the junk item worth least at a vendor. Quest, guide and protected items are never touched." },
    T("junkModifierToggle", "Toggle junk with modified right click", { span = 2, tip = "Modifier + right-click an item in your bags to add it to (or remove it from) your junk list. Listed items are sold and deleted like grey items." }),
    { type = "select", key = "junkModifier", label = "Right Click Modifier", values = function() return MODIFIERS end },
    T("autoSellJunk", "Auto Sell Junk"),
    { type = "newline" },
    { type = "keybind", label = "Delete Cheapest Junk Item Keybind",
      get = function() return ns.Assist:JunkKey() end, set = function(key) ns.Assist:SetJunkKey(key) end },
    { type = "button", label = "Reset Junk List", func = function() ns.Assist:ResetJunkList() end },
    H("Talents"),
    T("talentHints", "Enable Talents Guides", { tip = "Chat reminders to spend talent points, following your chosen build." }),
    T("showTalentSuggestions", "Show Talent Suggestions", { tip = "In the default talent window: numbered markers on your plan's next picks, a panel with the plan, and a tooltip line. Follows your spec profile. Never spends points.",
      after = function() if ns.TalentHints then ns.TalentHints:Refresh() end end }),
    T("talentPlan", "Enable Talent Plan", { tip = "On level-up, lists your build's next picks. Also /tbcg talents plan." }),
    { type = "range", key = "talentPlanCount", label = "Talent Plan Number", min = 1, max = 70, step = 1, tip = "How many upcoming picks the plan lists." },
} end }

pages.guide = { title = "Guide Routing", items = function() return {
    T("skipOverleveled", "Skip overleveled steps", { tip = "Skips picking up quests that are grey for your level, unless a later quest in the guide needs them." }),
    T("showElite", "Show Group Quests"),
    T("speedRoute", "Maximum-speed route", { tip = "Hides optional side quests." }),
    T("autoAdvance", "Advance steps automatically"),
    T("autoSelectGuide", "Pick a guide on first login"),
    H("Expansion"),
    { type = "desc", text = "TBCGuide covers levels 1-70: classic zones to 58-60, then Outland." },
    H("Dungeons"),
    T("showDungeonSteps", "Include Dungeon Quests", { tip = "When disabled, TBCGuide skips dungeon quests and recommends an outdoor leveling route where available. Quests already in your log stay in the guide." }),
    { type = "newline" },
    { type = "desc", text = "Pick single dungeons below. * = the guides have quests for it; the others are listed for completeness. Recommended = not outleveled and at most 8 levels above you." },
    { type = "button", label = "Select Recommended Dungeons", func = function()
        local lvl, off = UnitLevel and UnitLevel("player") or 1, {}
        for _, d in ipairs(ns.Dungeons) do if not ns.DungeonRecommended(d, lvl) then off[d.name] = true end end
        prof().dungeonOff = off
        if ns.Engine.guide then ns.Engine:Refresh() end
    end },
    { type = "button", label = "Select all Dungeons", func = function()
        prof().dungeonOff = {}
        if ns.Engine.guide then ns.Engine:Refresh() end
    end },
    { type = "newline" },
} end }

-- One switch per dungeon of the player's faction.
do
    local base = pages.guide.items
    pages.guide.items = function()
        local out = base()
        local faction = ns.Compat.PlayerInfo().faction
        for _, d in ipairs(ns.DungeonsFor(faction)) do
            out[#out + 1] = { type = "toggle", label = d.name .. (ns.DungeonHasQuests(d.name) and " *" or ""),
                tip = string.format("Usually run at levels %d-%d.", d.min, d.max),
                disabled = function() return not prof().showDungeonSteps end,
                get = function() return not (type(prof().dungeonOff) == "table" and prof().dungeonOff[d.name]) end,
                set = function(v)
                    if type(prof().dungeonOff) ~= "table" then prof().dungeonOff = {} end
                    prof().dungeonOff[d.name] = (not v) or nil
                    if ns.Engine.guide then ns.Engine:Refresh() end
                end }
        end
        return out
    end
end

pages.targeting = { title = "Targeting", items = function() return {
    T("markEnabled", "Enable Targeting", { tip = "Raid markers: /tbcg mark, the marker bar and guide marking." }),
    T("maxNameplateDistance", "Maximize Nameplate Distance", { tip = "Sets the game's nameplate distance to 41 yards (default 20), so step mobs are seen and marked sooner. Turning it off restores your previous value." }),
    H("Target Markers"),
    T("autoMark", "Mark Enemy Targets", { tip = "NPCs a guide step names with [mark=...]." }),
    T("autoMarkObjectives", "Mark Enemy Mobs", { tip = "The kill objectives of your current kill steps, one icon per mob type." }),
    T("markFriendly", "Mark Friendly Targets", { tip = "The NPC who gives or takes the current step's quest." }),
    T("markInGroup", "Enable Target Markers (Group)", { tip = "Allow automatic marking while you are in a party or raid (icons are visible to the group)." }),
    T("markReplace", "Replace existing markers"),
    T("markNotify", "Chat messages for markers"),
    T("markClearOnAdvance", "Remove my markers on step change", { span = 2 }),
    { type = "select", key = "defaultMarker", label = "Default marker",
      values = function() local o = {} for i = 8, 1, -1 do o[#o + 1] = { i, ns.Marker.Label(i) } end return o end },
    H("Targeting Macro"),
    T("targetMacro", "Create Targeting Macro", { tip = "Keeps a 'TBCGuide' macro that targets the current step's NPCs (/tar). Put it on an action bar.",
      after = function() ns.Assist:UpdateMacro() end }),
    T("targetNotify", "Notify on new target", { tip = "A chat line when an NPC from the current step first comes into view." }),
    H("Raid Marker Bar"),
    { type = "toggle", label = "Show the raid marker bar",
      get = function() return prof().showMarkerBar end,
      set = function(v) if (prof().showMarkerBar and true or false) ~= v then ns.MarkerBar:Toggle() end end },
    H("Active Target Frame"),
    T("activeTargets", "Enable Active Target Frame", { tip = "Click-to-target buttons for the current step's NPCs (/tar). Updates after combat." }),
    T("atEnemy", "Show Enemy Target"),
    T("atFriendly", "Show Friendly Target"),
    T("atLeader", "Follow Party Leader Target", { tip = "Adds your party leader's target. Needs Enable Group Settings (General)." }),
    T("atHideBg", "Hide Targets Background"),
    { type = "range", key = "atScale", label = "Active Targets Scale", min = 0.8, max = 3, step = 0.05, percent = true },
    { type = "button", label = "Reset Window Position", func = function() ns.ActiveTargets:ResetPosition() end },
} end }

pages.tracker = { title = "Leveling Tracker", items = function() return {
    { type = "desc", text = "Tracks how long each level takes (played time from the server) and your XP per hour. Levels finished before you installed this version show as -." },
    T("trackerEnabled", "Enable Leveling Tracker"),
    T("trackerWithCharacter", "Always Open Leveling Report With Character Panel", { span = 2 }),
    { type = "button", label = "Open Leveling Report", func = function() ns.LevelTracker:ToggleReport() end },
    H("Level Splits"),
    T("splitsEnabled", "Enable Level Splits", { tip = "A small window with the time each recent level took." }),
    T("splitsCompare", "Compare Next Level", { tip = "Shows how the running level compares with the previous one." }),
    T("splitsTotal", "Show Total Time Split"),
    T("splitsHideBg", "Hide Splits Background"),
    { type = "range", key = "splitsHistory", label = "Level Splits History", min = 1, max = 70, step = 1 },
    { type = "range", key = "splitsFont", label = "Level Splits Font Size", min = 9, max = 17, step = 1 },
    { type = "range", key = "splitsAlpha", label = "Level Splits Opacity", min = 0.1, max = 1, step = 0.05, percent = true },
} end }

pages.comms = { title = "Communications", items = function() return {
    T("versionCheck", "Enable Addon Version Checks", { tip = "Tells you when a group or guild member runs a newer TBCGuide." }),
    T("questNotify", "Chat messages for quest automation"),
    H("Announcements"),
    T("announceLevelEmote", "Announce Level Ups (Emote)"),
    T("announceLevelParty", "Announce Level Ups (Party Chat)"),
    T("announceLevelGuild", "Announce Level Ups (Guild Chat)"),
    T("announceComplete", "Announce Step completion", { tip = "Party chat when a guide quest's objectives are all done. Needs Enable Group Settings." }),
    T("announceCollect", "Announce Step collection", { tip = "Party chat on guide quest progress, e.g. Wolf Meat: 3/8. Needs Enable Group Settings." }),
    T("announceFlight", "Announce Step flying timers", { tip = "Party chat when you take a flight, with the arrival time once the route is known." }),
    T("announceSkipQuestie", "Don't announce when Questie is loaded", { span = 2, tip = "Questie can announce quest progress itself; this avoids double messages." }),
    H("Grouping"),
    { type = "desc", text = "Needs Enable Group Settings (General). Announcements go to party chat, never to raids." },
    T("announceAlways", "Send announcements without another TBCGuide user in group", { span = 2,
      tip = "Off: only announce when another party member runs TBCGuide (learned from version checks)." }),
    { type = "newline" },
    T("autoShareQuests", "Automatic quest sharing", { tip = "Shares a guide quest with your party right after you accept it." }),
} end }

pages.tips = { title = "Tips", items = function() return {
    T("tipsEnabled", "Enable Tips"),
    H("Drowning"),
    T("drownWarn", "Enable Warning"),
    T("drownSound", "Enable Warning Sound"),
    { type = "range", key = "drownThreshold", label = "Threshold", min = 5, max = 50, step = 1, suffix = "%" },
    T("drownFlash", "Screen Edge Flash"),
    H("Emergency Actions"),
    T("lowHealthWarn", "Enable Warning", { tip = "Warns when your health drops below the threshold." }),
    { type = "range", key = "lowHealthThreshold", label = "Threshold", min = 5, max = 40, step = 1, suffix = "%" },
    T("lowHealthAnim", "Enable Warning Sound"),
    T("lowHealthFlash", "Screen Edge Flash"),
    H("Dangerous Mobs Tracking"),
    T("trackMobsMap", "Track Mobs on Map", { tip = "World map pins for elite and rare mobs in the shown zone (bundled data)." }),
    T("trackRares", "Track Rare Mobs", { tip = "A chat alert and sound when a rare mob's nameplate appears (rares from the bundled database)." }),
    T("skipKilledRares", "Skip mobs already killed"),
    T("trackTreasures", "Track Treasures", { tip = "World map pins for treasure chests in the shown zone." }),
    H("Item Upgrade"),
    T("gearEnabled", "Enable Item Upgrade"),
    -- Profiles of the player's own class only, so another class's profile can never be active.
    { type = "select", label = "Spec profile",
      tip = "Used for tooltips, quest rewards and automatic upgrades. Saved for this character. Automatic upgrades need a spec chosen here.",
      values = function()
          local o = { { "auto", "Automatic (tooltips only)" } }
          for _, p in ipairs(ns.Gear:ProfilesForClass(ns.Gear:Context().class)) do
              local name = p.spec and ns.Upgrade:ProfileName(p) or (p.role .. ", leveling")
              o[#o + 1] = { p.id, name .. (p.context == "pve-preraid" and " (pre-raid)" or "") .. (p.weights and "" or " *") }
          end
          return o
      end,
      get = function() return ns.char.gearProfile or "auto" end,
      set = function(v) ns.char.gearProfile = (v ~= "auto") and v or nil ns.AutoEquip:OnProfileChanged() end },
    T("gearQuestRewards", "Quest Reward Recommendation"),
    T("autoReward", "Quest Reward Automation"),
    T("gearTooltip", "Disable Tooltips", { invert = true }),
    T("gearShowPercent", "Show score change (%)"),
    T("gearShowConfidence", "Show profile confidence"),
    T("auctioneer", "Enable Auctioneer", { tip = "Adds an Upgrades tab to the auction house. You start each scan yourself while the auction house is open; prices are the listings that scan saw, so old or partial scans may no longer match what is for sale. Nothing is ever bought." }),
    H("Automatic Upgrades"),
    { type = "desc", text = "Equips gear from your bags when it is an upgrade for your spec profile (* = estimated from a stat priority). "
        .. "Never in combat, never Bind-on-Equip items, nothing is sold or deleted. Estimates are spec scores, not DPS or healing." },
    { type = "toggle", label = "Enable automatic upgrades",
      tip = "Off by default. Needs a spec profile. Bind-on-Equip items are never equipped automatically.",
      get = function() return prof().autoEquip end,
      set = function(v)
          if not v then prof().autoEquip = false return end
          local p, why = ns.Upgrade:ActiveProfile()
          if not p then prof().autoEquip = false ns:Print("Automatic upgrades: " .. why .. " (Spec profile).") return end
          ns.Config:Confirm("Automatically equip upgrades for " .. ns.Upgrade:ProfileName(p) .. "?\n\n"
              .. "Empty slots get any usable item; filled slots only a higher estimated spec score. "
              .. "Never in combat, never Bind-on-Equip items, replaced items stay in your bags.",
              function() prof().autoEquip = true ns.AutoEquip:Schedule() end)
      end },
    T("autoEquipEmpty", "Fill empty gear slots", { tip = "Any usable non-BoE item goes into an empty slot, even if it is not ideal for your spec." }),
    { type = "range", key = "autoEquipMinPct", label = "Minimum upgrade", min = 0, max = 20, step = 0.5, decimals = 1, suffix = "%",
      tip = "For occupied slots. 0 means any strictly higher score." },
    T("equipNotify", "On-screen equip messages"),
    T("equipChat", "Copy equip messages to chat"),
    T("boeMarkers", "Mark Bind-on-Equip upgrades in bags", { tip = "A small arrow on BoE items that would be an upgrade. Equip them yourself." }),
    { type = "button", label = "Clear excluded items",
      tip = "Items excluded with /tbcg gear exclude <item> are allowed again.",
      func = function() ns.Upgrade:Exclusions().items = {} ns.AutoEquip:Schedule() end },
    H("Protected Slots (never changed automatically)"),
} end }

-- One toggle per gear slot, stored per character.
do
    local base = pages.tips.items
    pages.tips.items = function()
        local out = base()
        for _, slot in ipairs(ns.Gear.SCORED_SLOTS) do
            out[#out + 1] = { type = "toggle", label = ns.Gear.SLOT_NAMES[slot],
                get = function() return ns.Upgrade:SlotExcluded(slot) end,
                set = function(v) ns.Upgrade:Exclusions().slots[slot] = v and true or nil ns.AutoEquip:Schedule() end }
        end
        return out
    end
end

pages.help = { title = "Help", items = function() return {
    H("Commands"),
    { type = "desc", text = "|cffffd100/tbcg|r - show or hide the guide window\n"
        .. "|cffffd100/tbcg options|r - this window   |cffffd100/tbcg guide|r - guide browser   |cffffd100/tbcg talents|r - talent guide\n"
        .. "|cffffd100/tbcg next|r, |cffffd100prev|r, |cffffd100skip|r - step control   |cffffd100/tbcg gear|r - gear overview\n"
        .. "|cffffd100/tbcg mark|r, |cffffd100unmark|r, |cffffd100markbar|r - raid markers   |cffffd100/tbcg minimap|r - minimap button\n"
        .. "|cffffd100/tbcg debug|r [api|marks|quest <id>] - diagnostics   |cffffd100/tbcg help|r - every command" },
    H("The guide skips steps - why?"),
    { type = "desc", text = "A step is skipped automatically when your race or class cannot take the quest, when an earlier step it depends on was skipped, when an optional quest is not in your log, or (with Skip overleveled steps) when the quest is grey for your level. Hover a step to see the reason. Turn skipping off with Disable step skips (Advanced Settings)." },
    H("I am behind the guide's levels"),
    { type = "desc", text = "The routes assume normal experience and killing what is on your way between objectives. When a guide needs a minimum level it says so, sometimes with a grind step naming mobs and a place. Bonus or reduced experience makes the level ranges shift; just follow the steps." },
    H("Nothing gets a raid marker"),
    { type = "desc", text = "Type /tbcg debug marks: it shows the current rule, whether you may mark (in a raid only the leader and assistants can) and the last decision." },
    H("Where are my settings?"),
    { type = "desc", text = "Settings are profiles (Profiles tab), shared between characters that use the same profile. Guide progress, talents and junk-sale totals always belong to the character." },
} end }

pages.advanced = { title = "Advanced Settings", items = function() return {
    T("debug", "Enable Debug"),
    T("lowQuality", "Low Quality Settings", { tip = "Redraws the arrow at most every 150 ms and shows fewer map pins." }),
    { type = "range", key = "arrowUpdateMs", label = "Update Frequency (ms)", min = 5, max = 150, step = 5,
      tip = "How often the arrow is redrawn." },
    T("preloadData", "Pre load all data", { tip = "Loads item data for your guide's quests and your bags at login, so tooltips and scoring do not wait." }),
    T("checkConflicts", "Check for Addon Incompatibility", { span = 2, tip = "At login, warns when another leveling guide add-on is loaded." }),
    H("Debug"),
    T("disableStepSkips", "Disable step skips", { tip = "Never skip steps automatically; you skip them yourself." }),
    { type = "toggle", label = "Display Lua Errors",
      get = function() return ns.Assist:LuaErrors() end, set = function(v) ns.Assist:LuaErrors(v) end,
      tip = "The game's own Lua error pop-up (scriptErrors setting)." },
    T("showMapPins", "Disable Map Pins", { invert = true }),
} end }

local function profileNames(exclude)
    local out = {}
    for _, name in ipairs(ns.Profiles:List()) do
        if not (exclude and exclude[name]) then out[#out + 1] = { name, name } end
    end
    return out
end

pages.profiles = { title = "Profiles", items = function() return {
    { type = "button", label = "Reload guides and UI", func = function() ReloadUI() end },
    { type = "button", label = "Reset Guide Progress", func = function()
        ns.Config:Confirm("Reset your progress in the current guide?", function() ns.Engine:Reset() end)
    end },
    { type = "newline" },
    { type = "desc", text = "Profiles hold your settings, so characters can share them or each have their own. Guide progress always belongs to the character. Reset Profile puts the active profile back to its default values." },
    { type = "button", label = "Reset Profile", func = function()
        ns.Config:Confirm("Reset every setting in the profile '" .. ns.Profiles:Current() .. "' to its default?", function() ns.Profiles:Reset() end)
    end },
    { type = "label", span = 2, text = function() return "Current Profile: |cffffd100" .. tostring(ns.Profiles:Current()) .. "|r" end },
    { type = "desc", text = "Create a new profile by entering a name, or pick an existing one." },
    { type = "input", label = "New", span = 2, func = function(text)
        local ok, why = ns.Profiles:Set(text)
        if not ok then ns:Print("Profile not created: " .. tostring(why)) end
    end },
    { type = "newline" },
    { type = "select", label = "Existing Profiles", span = 2, values = function() return profileNames() end,
      get = function() return ns.Profiles:Current() end, set = function(v) ns.Profiles:Set(v) end },
    { type = "desc", text = "Copy the settings from an existing profile into the active profile." },
    { type = "select", label = "Copy From", span = 2, empty = "",
      values = function() return profileNames({ [ns.Profiles:Current()] = true }) end,
      get = function() return nil end,
      set = function(v) ns.Config:Confirm("Copy all settings from '" .. v .. "' into '" .. ns.Profiles:Current() .. "'?", function() ns.Profiles:CopyFrom(v) end) end },
    { type = "desc", text = "Delete profiles you no longer use. The active profile and the default profile cannot be deleted." },
    { type = "select", label = "Delete a Profile", span = 2, empty = "",
      values = function() return profileNames({ [ns.Profiles:Current()] = true, [ns.Profiles:Default()] = true }) end,
      get = function() return nil end,
      set = function(v) ns.Config:Confirm("Delete the profile '" .. v .. "'?", function() ns.Profiles:Delete(v) end) end },
    H(""),
    { type = "button", label = "Set current profile as default", span = 2, func = function()
        ns.Profiles:SetDefault()
        ns:Print("New characters will start with the profile '" .. ns.Profiles:Current() .. "'.")
    end },
    { type = "label", span = 1, text = function() return "Default: |cffffd100" .. tostring(ns.Profiles:Default()) .. "|r" end },
} end }
