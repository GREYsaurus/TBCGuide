-- TBCGuide - contents of the settings window (rendered by UI/Config.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Every control either changes a real setting or is marked `planned` (shown disabled, does nothing).
-- Settings live in the active profile (ns.db.profile); see Core/SavedVars.lua for defaults.

local _, ns = ...

local function T(key, label, extra)
    local it = { type = "toggle", key = key, label = label }
    for k, v in pairs(extra or {}) do it[k] = v end
    return it
end
local function planned(label, default) return { type = "toggle", label = label, planned = true, default = default } end
local function H(text) return { type = "header", text = text } end
local function prof() return ns.db.profile end

local MODIFIERS = { { "CTRL", "CTRL" }, { "ALT", "ALT" }, { "SHIFT", "SHIFT" } }

local pages = {}
ns.ConfigPages = pages

pages.general = { title = "General", items = function() return {
    T("showAllFrames", "Show all Enabled Frames", { tip = "Shows the guide window and the arrow. Off hides both." }),
    T("locked", "Lock Frames"),
    T("autohideRaid", "Autohide in Raids", { tip = "Hides the guide window and arrow while you are in a raid group." }),
    H("Features"),
    T("showMinimapButton", "Enable Minimap Button"),
    T("worldMapButton", "Enable World Map Button", { tip = "A button on the world map that opens the guide browser." }),
    T("hideWindow", "Hide Window"),
    T("showArrow", "Hide waypoint arrow", { invert = true }),
    planned("Hide Active Item window"),
    planned("Enable Vendor Treasures", true),
    planned("Show Flight Timers", true),
    planned("Enable Group Settings"),
    H("Automation"),
    { type = "toggle", label = "Quest auto accept/turn in",
      get = function() return prof().autoAccept and prof().autoTurnIn end,
      set = function(v) prof().autoAccept, prof().autoTurnIn = v, v ns.QuestAuto:Rebuild() end,
      tip = "Guide quests only. Escort quests are never accepted automatically. More options: /tbcg automation." },
    T("autoReward", "Quest auto rewards", { tip = "Takes a reward only when gear scoring shows one clear upgrade, or when your class can use none of them (then the most valuable). Otherwise you choose." }),
    T("trainerAuto", "Trainer automation", { tip = "Learns every spell you can afford when you open your class trainer. Spends gold. Hold Shift to skip." }),
    T("flightAuto", "Flight Path automation", { tip = "On a 'fly to' step, takes the flight to that destination when the flight map opens. Hold Shift to skip." }),
    T("bindAuto", "Innkeeper Bind automation", { tip = "On a 'set your hearthstone' step, picks the innkeeper's bind option and confirms it." }),
    T("skipGossip", "Skip Gossip", { tip = "Picks the only option when an NPC has one option and no quests. Hold Shift to skip." }),
    H("Inventory"),
    T("inventoryManager", "Enable Inventory Manager", { tip = "Master switch for junk selling, the junk list and junk deletion." }),
    { type = "newline" },
    planned("Show junk item indicator"),
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
    planned("Enable Talent Plan", true),
    { type = "range", label = "Talent Plan Number", min = 1, max = 70, step = 1, planned = true, default = 5 },
} end }

pages.guide = { title = "Guide Routing", items = function() return {
    H("Experience"),
    planned("Detect Rate", true),
    { type = "range", label = "Experience rates", min = 1, max = 2, step = 0.05, percent = true, planned = true, default = 1 },
    { type = "newline" },
    T("skipOverleveled", "Skip overleveled steps", { tip = "Skips picking up quests that are grey for your level, unless a later quest in the guide needs them." }),
    T("showElite", "Show Group Quests"),
    planned("Solo Self Found Mode"),
    T("speedRoute", "Maximum-speed route", { tip = "Hides optional side quests." }),
    T("autoAdvance", "Advance steps automatically"),
    T("autoSelectGuide", "Pick a guide on first login"),
    H("Expansion"),
    { type = "desc", text = "TBCGuide covers levels 1-70: classic zones to 58-60, then Outland." },
    H("Dungeons"),
    T("showDungeonSteps", "Include Dungeon Quests", { tip = "When disabled, TBCGuide skips dungeon quests and recommends an outdoor leveling route where available. Quests already in your log stay in the guide." }),
    { type = "newline" },
    { type = "desc", text = "Choosing single dungeons is planned. Include Dungeon Quests above turns all of them on or off." },
    { type = "button", label = "Select Recommended Dungeons", planned = true, span = 1 },
    { type = "button", label = "Select all Dungeons", planned = true, span = 1 },
} end }

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
    planned("Follow Party Leader Macro"),
    H("Raid Marker Bar"),
    { type = "toggle", label = "Show the raid marker bar",
      get = function() return prof().showMarkerBar end,
      set = function(v) if (prof().showMarkerBar and true or false) ~= v then ns.MarkerBar:Toggle() end end },
    H("Active Target Frame"),
    planned("Enable Active Target Frame", true),
    planned("Show Enemy Target", true),
    planned("Show Friendly Target", true),
    planned("Follow Party Leader Target"),
    planned("Hide Targets Background"),
    { type = "range", label = "Active Targets Scale", min = 0.8, max = 3, step = 0.05, percent = true, planned = true, default = 1 },
    { type = "button", label = "Reset Window Position", planned = true },
} end }

pages.tracker = { title = "Leveling Tracker", items = function() return {
    { type = "desc", text = "The leveling tracker is planned for a later version of TBCGuide." },
    planned("Enable Leveling Tracker", true),
    planned("Always Open Leveling Report With Character Panel"),
    H("Level Splits"),
    planned("Enable Level Splits"),
    planned("Compare Next Level"),
    planned("Show Total Time Split", true),
    planned("Hide Splits Background"),
    { type = "range", label = "Level Splits History", min = 1, max = 70, planned = true, default = 10 },
    { type = "range", label = "Level Splits Font Size", min = 9, max = 17, planned = true, default = 11 },
    { type = "range", label = "Level Splits Opacity", min = 0.1, max = 1, step = 0.05, percent = true, planned = true, default = 0.9 },
} end }

pages.comms = { title = "Communications", items = function() return {
    planned("Enable Addon Version Checks", true),
    T("questNotify", "Chat messages for quest automation"),
    H("Announcements"),
    T("announceLevelEmote", "Announce Level Ups (Emote)"),
    T("announceLevelParty", "Announce Level Ups (Party Chat)"),
    T("announceLevelGuild", "Announce Level Ups (Guild Chat)"),
    planned("Announce Step completion"),
    planned("Announce Step collection"),
    planned("Announce Step flying timers"),
    planned("Ignore Questie announcements"),
    H("Grouping"),
    planned("Send announcements without another TBCGuide user in group"),
    { type = "newline" },
    planned("Automatic quest sharing"),
} end }

pages.tips = { title = "Tips", items = function() return {
    T("tipsEnabled", "Enable Tips"),
    planned("Quest Sellable Recommendation", true),
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
    planned("Track Mobs on Map"),
    T("trackRares", "Track Rare Mobs", { tip = "A chat alert and sound when a rare mob's nameplate appears (rares from the bundled database)." }),
    T("skipKilledRares", "Skip mobs already killed"),
    planned("Track Treasures"),
    H("Item Upgrade"),
    T("gearEnabled", "Enable Item Upgrade"),
    { type = "select", label = "Talents",
      values = function()
          local o = { { "auto", "Automatic (talents and level)" } }
          for _, p in ipairs(ns.Gear:ProfilesForClass(ns.Gear:Context().class)) do
              o[#o + 1] = { p.id, (p.spec or p.role) .. " - " .. p.context }
          end
          return o
      end,
      get = function() return ns.char.gearProfile or "auto" end,
      set = function(v) ns.char.gearProfile = (v ~= "auto") and v or nil end },
    planned("Always Show Total EP"),
    T("gearQuestRewards", "Quest Reward Recommendation"),
    T("autoReward", "Quest Reward Automation"),
    T("gearTooltip", "Disable Tooltips", { invert = true }),
    T("gearShowPercent", "Show score change (%)"),
    T("gearShowConfidence", "Show profile confidence"),
    planned("Enable Auctioneer"),
} end }

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

pages.look = { title = "Look and Feel", items = function() return {
    { type = "select", label = "Choose Theme", planned = true, values = function() return { { "tbcg", "TBCGuide" } } end,
      get = function() return "tbcg" end },
    { type = "button", label = "Preview Frame Positions", planned = true },
    H("Text"),
    { type = "color", label = "Kill", planned = true, default = { r = 1, g = 0.35, b = 0.2 } },
    { type = "color", key = "colorFriendly", label = "Friendly" },
    { type = "color", label = "Loot", planned = true, default = { r = 0.2, g = 0.8, b = 0.9 } },
    { type = "color", key = "colorWarning", label = "Warning" },
    { type = "color", key = "colorQuest", label = "Quest" },
    { type = "color", label = "Buy", planned = true, default = { r = 0.1, g = 0.6, b = 0.1 } },
    { type = "button", label = "Reset Colors", func = function()
        local d = ns.PROFILE_DEFAULTS
        for _, k in ipairs({ "colorFriendly", "colorQuest", "colorWarning" }) do prof()[k] = { r = d[k].r, g = d[k].g, b = d[k].b } end
        ns.Config:Changed()
    end },
    H("Guide Window"),
    { type = "range", key = "scale", label = "Window Scale", min = 0.6, max = 1.6, step = 0.05, percent = true, decimals = 2 },
    { type = "range", key = "guideFontSize", label = "Guide Font Size", min = 9, max = 18, step = 1 },
    { type = "range", key = "stepsShown", label = "Steps shown", min = 1, max = 8, step = 1 },
    T("showStepList", "Show step list", { tip = "Shows the upcoming steps under the current one." }),
    planned("Hide completed steps"),
    planned("Show unused guides", true),
    { type = "button", label = "Reset window positions", func = function()
        ns.Config:Confirm("Reset the guide window and arrow positions? This reloads the UI.", function()
            ns.db.frames.main = { point = "RIGHT", x = -60, y = 120, w = 320, h = 230, shown = true }
            ns.db.frames.arrow = { point = "TOP", x = 0, y = -120 }
            ReloadUI()
        end)
    end },
    H("Waypoint Arrow"),
    { type = "range", key = "arrowScale", label = "Arrow Scale", min = 0.2, max = 2, step = 0.05, percent = true, decimals = 2 },
    { type = "range", label = "Arrow Text Size", min = 5, max = 20, planned = true, default = 9 },
    { type = "button", label = "Reset Arrow Position", func = function()
        ns.db.frames.arrow = { point = "TOP", x = 0, y = -120 }
        local a = ns.Nav and ns.Nav.arrow
        if a then a:ClearAllPoints() a:SetPoint("TOP", UIParent, "TOP", 0, -120) end
    end },
    H("Active Items"),
    { type = "range", label = "Active Item Scale", min = 0.8, max = 3, step = 0.05, percent = true, planned = true, default = 1 },
    planned("Hide Background"),
    { type = "button", label = "Reset Window Position", planned = true },
    H("Map Options"),
    T("showMapPins", "Show the target on the world map"),
    T("useTomTom", "Send waypoints to TomTom"),
    planned("Hide Mini Map Pins"),
    planned("Highlight active map pins"),
    { type = "range", label = "Number of Map Pins", min = 0, max = 20, planned = true, default = 7 },
    { type = "range", label = "Map Pin Scale", min = 0.05, max = 1, step = 0.05, percent = true, planned = true, default = 1 },
    { type = "range", label = "Distance Between Pins", min = 0.05, max = 2, step = 0.05, decimals = 2, planned = true, default = 1 },
    { type = "range", label = "Map Pin Background Opacity", min = 0, max = 1, step = 0.05, percent = true, planned = true, default = 0.35 },
} end }

pages.advanced = { title = "Advanced Settings", items = function() return {
    planned("Enable Beta Features"),
    T("debug", "Enable Debug"),
    planned("Low Quality Settings"),
    planned("Hearthstone batching"),
    { type = "range", label = "Batching window size (ms)", min = 1, max = 50, planned = true, default = 6 },
    { type = "range", key = "arrowUpdateMs", label = "Update Frequency (ms)", min = 5, max = 150, step = 5,
      tip = "How often the arrow is redrawn." },
    planned("Pre load all data"),
    T("checkConflicts", "Check for Addon Incompatibility", { span = 2, tip = "At login, warns when another leveling guide add-on is loaded." }),
    H("Debug"),
    T("disableStepSkips", "Disable step skips", { tip = "Never skip steps automatically; you skip them yourself." }),
    { type = "toggle", label = "Display Lua Errors",
      get = function() return ns.Assist:LuaErrors() end, set = function(v) ns.Assist:LuaErrors(v) end,
      tip = "The game's own Lua error pop-up (scriptErrors setting)." },
    T("showMapPins", "Disable Map Pins", { invert = true }),
    { type = "range", label = "Quest Log Size", min = 20, max = 40, planned = true, default = 25 },
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
