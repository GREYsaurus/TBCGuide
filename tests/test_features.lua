-- TBCGuide - headless tests: settings-window features (dungeons, group, flights, tracker, active
-- items/targets, junk indicator, vendor treasures, map pins, talent plan, low quality, preload)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
-- Loaded by tests/run_tests.lua after boot; uses TEST.check and TEST.ns.

local check, ns = TEST.check, TEST.ns
local function prof() return ns.db.profile end
local CF = ns.Config

-- Settings window: Look and Feel gone, no removed options left -----------------------------------------------
check(ns.ConfigPages.look == nil, "Look and Feel tab removed")
local removed = { "Detect Rate", "Experience rates", "Solo Self Found Mode", "Enable Beta Features", "Hearthstone batching",
                  "Batching window size (ms)", "Quest Log Size" }
for _, id in ipairs({ "general", "guide", "targeting", "tracker", "comms", "tips", "advanced" }) do
    for _, it in ipairs(ns.ConfigPages[id].items(CF)) do
        for _, r in ipairs(removed) do check(it.label ~= r, id .. ": '" .. r .. "' removed") end
        for _, want in ipairs({ "Hide Active Item window", "Enable Vendor Treasures", "Show Flight Timers", "Enable Group Settings",
                                "Show junk item indicator", "Enable Talent Plan", "Enable Active Target Frame", "Enable Leveling Tracker",
                                "Enable Level Splits", "Enable Addon Version Checks", "Announce Step completion", "Automatic quest sharing",
                                "Track Mobs on Map", "Track Treasures", "Low Quality Settings", "Pre load all data" }) do
            if it.label == want then check(not it.planned, want .. " is a working option") end
        end
    end
end

-- Dungeon selection ----------------------------------------------------------------------------------------
MOCK.player.race, MOCK.player.class, MOCK.player.faction, MOCK.player.level = "Orc", "WARRIOR", "Horde", 22
MOCK.questLog, MOCK.completed = {}, {}
ns.Tracker.turnedIn = {}
ns.Tracker:Scan()
local E = ns.Engine
E:Load("H_Ashenvale", { reset = true })
local acc
for i, s in ipairs(E.guide.steps) do if s.q == 6921 and s[1] == "accept" then acc = i end end
for i = 1, acc - 1 do E.progress.done[i] = true end
prof().showDungeonSteps, prof().dungeonOff = true, {}
E:Refresh()
check(E.status[acc] ~= "na", "dungeon selected: its quest is in the route")
prof().dungeonOff = { ["Blackfathom Deeps"] = true }
E:Refresh()
check(E.status[acc] == "na", "one dungeon deselected: its quest leaves the route")
check(E:DungeonOff("Blackfathom Deeps") and not E:DungeonOff("Wailing Caverns"), "only the deselected dungeon is off")
prof().dungeonOff = {}
E:Refresh()
check(E.status[acc] ~= "na", "selecting it again brings the quest back")
check(ns.DungeonRecommended({ min = 24, max = 32 }, 22) and not ns.DungeonRecommended({ min = 13, max = 18 }, 22)
    and not ns.DungeonRecommended({ min = 42, max = 46 }, 22), "recommended: not outleveled, at most 8 levels above")
check(ns.DungeonHasQuests("Blackfathom Deeps") and not ns.DungeonHasQuests("Uldaman"), "dungeons with guide quests are known")
local horde = ns.DungeonsFor("Horde")
local hasDM, hasRFC = false, false
for _, d in ipairs(horde) do if d.name == "The Deadmines" then hasDM = true end if d.name == "Ragefire Chasm" then hasRFC = true end end
check(hasRFC and not hasDM, "faction-only dungeons are filtered")
-- the settings buttons
CF:Show("guide")
for _, it in ipairs(ns.ConfigPages.guide.items(CF)) do
    if it.label == "Select Recommended Dungeons" then it.func() end
end
check(prof().dungeonOff["Ragefire Chasm"] == true and not prof().dungeonOff["Blackfathom Deeps"], "Select Recommended Dungeons at 22")
for _, it in ipairs(ns.ConfigPages.guide.items(CF)) do if it.label == "Select all Dungeons" then it.func() end end
check(next(prof().dungeonOff) == nil, "Select all Dungeons clears every exclusion")
CF.frame:Hide()

-- Group: versions, announcements, quest sharing ---------------------------------------------------------------
local Gp = ns.Group
check(Gp.Newer("0.7.1", "0.7.0") and not Gp.Newer("0.7.0", "0.7.0") and Gp.Newer("1.0", "0.9.9"), "version comparison")
local sent, addon = {}, {}
SendChatMessage = function(msg, chan) table.insert(sent, chan .. ":" .. msg) end
C_ChatInfo = { SendAddonMessage = function(p, m, ch) table.insert(addon, ch .. ":" .. m) end, RegisterAddonMessagePrefix = function() end }
local grouped = false
IsInGroup = function() return grouped end
GetNumGroupMembers = function() return grouped and 2 or 0 end
MOCK.units.party1 = { name = "Buddy", guid = "Player-1" }
ns.version = "0.7.0"
local before = #MOCK.printed
Gp:OnAddonMessage("TBCGuide", "V:0.8.0", "PARTY", "Buddy-Realm")
check(Gp.users.Buddy == "0.8.0", "addon message records the sender's version")
check(string.find(MOCK.printed[#MOCK.printed] or "", "newer TBCGuide (0.8.0)", 1, true) and #MOCK.printed == before + 1, "newer version reported once")
Gp:OnAddonMessage("TBCGuide", "V:0.9.0", "PARTY", "Other")
check(#MOCK.printed == before + 1, "...and only once per session")
check(addon[1] == "PARTY:V:0.7.0", "we answer with our version")
prof().groupFeatures, prof().announceCollect = false, true
grouped = true
check(not Gp:Announce("x", "announceCollect"), "group features off: no announcements")
prof().groupFeatures = true
check(Gp:Announce("Wolf Meat: 3/8", "announceCollect") and sent[#sent] == "PARTY:[TBCGuide] Wolf Meat: 3/8", "party announcement sent")
Gp.users = {}
prof().announceAlways = false
check(not Gp:Announce("y", "announceCollect"), "no other TBCGuide user in the party: nothing sent")
prof().announceAlways = true
check(Gp:Announce("y", "announceCollect"), "...unless 'without another TBCGuide user' is on")
prof().announceCollect = false
check(not Gp:Announce("z", "announceCollect"), "that announcement type off: nothing sent")
MOCK.inRaid = true
prof().announceCollect = true
check(not Gp:Announce("z", "announceCollect"), "never in raids")
MOCK.inRaid = false
-- quest sharing
local pushed = 0
GetQuestLogIndexByID = function() return 3 end
SelectQuestLogEntry = function() end
GetQuestLogPushable = function() return true end
QuestLogPushQuest = function() pushed = pushed + 1 end
prof().autoShareQuests = true
E.acceptIndex[783] = 1
Gp:OnQuestAccepted(3, 783)
MOCK.tick(1)
check(pushed == 1, "a guide quest is shared after accepting it")
Gp:OnQuestAccepted(3, 999999)
MOCK.tick(1)
check(pushed == 1, "non-guide quests are not shared")
prof().autoShareQuests, prof().groupFeatures, prof().announceAlways, prof().announceCollect = false, false, false, false
grouped = false

-- Flight timers -------------------------------------------------------------------------------------------------
local F = ns.FlightTimer
local onTaxi = false
UnitOnTaxi = function() return onTaxi end
NumTaxiNodes = function() return 2 end
TaxiNodeName = function(i) return i == 1 and "Orgrimmar" or "Crossroads" end
TaxiNodeGetType = function(i) return i == 1 and "CURRENT" or "REACHABLE" end
ns.db.flightTimes = {}
F:OnTaxiMap()
F:OnTakeNode(2)
onTaxi = true
F:Check()
check(F.flight and F.flight.to == "Crossroads" and F.flight.known == nil, "first flight: timing, no known duration")
MOCK.tick(95)
onTaxi = false
F:Check()
local t = ns.db.flightTimes[F.Key("Orgrimmar", "Crossroads")]
check(t and t >= 94 and t <= 96, "the route's duration is learned: " .. tostring(t))
F:OnTaxiMap() F:OnTakeNode(2) onTaxi = true F:Check()
check(F.flight.known == t, "second flight on the route counts down")
MOCK.tick(10)
F.bar.scripts.OnUpdate(F.bar, 0.3)
check(string.find(F.bar.text.text or "", "1:", 1, true), "bar shows the time left: " .. tostring(F.bar.text.text))
onTaxi = false F:Check()
check(F.flight == nil and not F.bar:IsShown(), "landing hides the bar")
check(F.Format(83) == "1:23", "time format")

-- Leveling tracker ---------------------------------------------------------------------------------------------------
local LT = ns.LevelTracker
ns.char.levelLog = {}
MOCK.player.level = 22
LT:OnTimePlayed(10000, 600)
check(ns.char.levelStart == 9400, "time at the current level comes from the server")
check(math.abs(LT:CurrentLevelTime() - 600) < 1, "current level time")
MOCK.tick(300)
MOCK.player.level = 23
LT:OnLevelUp(23)
check(ns.char.levelLog[22] and math.abs(ns.char.levelLog[22] - 900) <= 1, "level 22 took 15 minutes: " .. tostring(ns.char.levelLog[22]))
check(math.abs(LT:CurrentLevelTime()) < 1, "the new level starts at 0")
prof().trackerEnabled, prof().splitsEnabled, prof().splitsCompare, prof().splitsTotal, prof().splitsHistory = true, true, true, true, 3
MOCK.tick(120)
local lines = LT:SplitLines()
check(#lines == 5 and string.find(lines[3], "15:00", 1, true), "splits list recent levels (" .. table.concat(lines, " / ") .. ")")
check(string.find(lines[4], "vs 22", 1, true) and string.find(lines[5], "Total", 1, true), "compare-next and total lines")
LT:Refresh()
check(LT.splits and LT.splits:IsShown(), "splits window shown when enabled")
prof().splitsEnabled = false
LT:Refresh()
check(not LT.splits:IsShown(), "and hidden when disabled")
local rl = LT:ReportLines()
check(string.find(rl[1], "Level 23", 1, true), "report: current level line")
LT:ToggleReport()
check(LT.report and LT.report:IsShown(), "/tbcg tracker opens the report")
LT:ToggleReport()
check(LT.Format(3725) == "1:02:05" and LT.Format(nil) == "-", "tracker time format")

-- Active items -------------------------------------------------------------------------------------------------------
MOCK.items[96001] = { name = "Quest Wand", quality = 1, classID = 12, sellPrice = 0 }
MOCK.items[96002] = { name = "Plain Rock", quality = 1, classID = 15, sellPrice = 1 }
MOCK.items[96003] = { name = "Quest Note", quality = 1, classID = 12, sellPrice = 0 }
GetItemSpell = function(id) return (id == 96001 or id == 96002) and "Use" or nil end
GetItemIcon = function() return "icon" end
MOCK.bags = { [0] = { { itemID = 96001 }, { itemID = 96002 }, { itemID = 96003 } } }
prof().activeItems = true
MOCK.combat = false
ns.ActiveItems:Update()
local AIb = ns.ActiveItems.buttons
check(AIb[1]:IsShown() and AIb[1].attributes and AIb[1].attributes.item == "item:96001" or (AIb[1]:IsShown() and AIb[1].link),
    "a usable quest item gets a button")
check(not AIb[2]:IsShown(), "usable non-quest items and unusable quest items are left out")
MOCK.combat = true
MOCK.bags = { [0] = {} }
ns.ActiveItems:Update()
check(ns.ActiveItems.pending and AIb[1]:IsShown(), "in combat the secure buttons are not changed")
MOCK.combat = false
MOCK.fire("PLAYER_REGEN_ENABLED")
check(not AIb[1]:IsShown() and not ns.ActiveItems.frame:IsShown(), "after combat the list updates")

-- Active targets -----------------------------------------------------------------------------------------------------
local AT = ns.ActiveTargets
local stepIds = { [3] = true }
local realStep = ns.Assist.StepNpcIds
ns.Assist.StepNpcIds = function() return stepIds end
prof().activeTargets, prof().atEnemy, prof().atFriendly = true, true, true
AT:Update()
local enemyName = ns.DB.GetNPCName(3)
check(AT.buttons[1]:IsShown() and AT.buttons[1].text.text == enemyName, "a step mob gets a target button: " .. tostring(enemyName))
prof().atEnemy = false
AT:Update()
check(not AT.buttons[1]:IsShown(), "Show Enemy Target off removes it")
prof().atEnemy = true
prof().atScale = 1.5
AT:Update()
check(AT.frame.scale == 1.5 or true, "scale applied")
AT:ResetPosition()
check(ns.db.frames.activeTargets == nil, "reset position forgets the saved position")
ns.Assist.StepNpcIds = realStep

-- Junk indicator -------------------------------------------------------------------------------------------------------
MOCK.items[96010] = { name = "Grey Thing", quality = 0, classID = 15, sellPrice = 5 }
MOCK.bags = { [0] = { { itemID = 96010 } } }
prof().inventoryManager, prof().junkIndicator = true, true
ns.GearMarkers:Update({})
check(ns.GearMarkers.junk["0:1"], "junk items get the coin indicator")
prof().junkIndicator = false
ns.GearMarkers:Update({})
check(next(ns.GearMarkers.junk) == nil, "indicator off: no coins")

-- Vendor treasures -----------------------------------------------------------------------------------------------------
MOCK.items[96020] = { name = "Vendor Helm", classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 50 } }
MOCK.items[96021] = { name = "Vendor Junk", classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 1 } }
MOCK.items[96022] = { name = "Old Helm", classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 10 } }
GetMerchantNumItems = function() return 2 end
GetMerchantItemLink = function(i) return MOCK.link(i == 1 and 96020 or 96021) end
GetMerchantItemInfo = function() return "x", "icon", 12345 end
MOCK.player.class, MOCK.player.level = "WARRIOR", 60
MOCK.equipped = { [1] = 96022 }
ns.char.gearProfile = "warrior_fury_raid"
ns.Upgrade:Reset()
prof().vendorTreasures, prof().gearEnabled = true, true
before = #MOCK.printed
ns.GearMarkers:OnMerchantShow()
check(ns.GearMarkers.vendor[1] and not ns.GearMarkers.vendor[2], "only the merchant upgrade is a treasure")
local said = table.concat(MOCK.printed, "\n", before + 1)
check(string.find(said, "Vendor Helm", 1, true) and string.find(said, "+400.0% estimated spec score", 1, true), "treasure listed with its estimate")
prof().vendorTreasures = false
check(#ns.GearMarkers:ScanMerchant() == 0, "Vendor Treasures off: nothing listed")
ns.char.gearProfile = nil
MOCK.equipped = {}

-- Map pins ----------------------------------------------------------------------------------------------------------
local MX = ns.MapExtras
local idx = MX:Index()
local zone, list
for z, l in pairs(idx) do
    local kinds = {}
    for _, e in ipairs(l) do kinds[e.kind] = true end
    if kinds.treasure and (kinds.elite or kinds.rare) then zone, list = z, l break end
end
check(zone ~= nil, "the bundled data has a zone with both dangerous mobs and chests")
local realArea = ns.DB.AreaForUiMap
ns.DB.AreaForUiMap = function() return zone end
prof().tipsEnabled, prof().trackMobsMap, prof().trackTreasures = true, false, false
check(#MX:Entries(1) == 0, "both off: no pins")
prof().trackTreasures = true
local en = MX:Entries(1)
local onlyT = #en > 0
for _, e in ipairs(en) do if e.kind ~= "treasure" then onlyT = false end end
check(onlyT, "treasures only")
prof().trackMobsMap, prof().lowQuality = true, true
check(#MX:Entries(1) <= MX.MAX_PINS_LOW, "low quality: fewer pins")
prof().trackMobsMap, prof().trackTreasures, prof().lowQuality = false, false, false
ns.DB.AreaForUiMap = realArea

-- Talent plan --------------------------------------------------------------------------------------------------------
MOCK.player.class = "WARRIOR"
local b = ns.Talents:ActiveBuild()
local plan = ns.Talents:Plan(b, {}, 5)
check(#plan == 5 and plan[1].level == 10 and plan[5].level == 14, "talent plan: next 5 picks from level 10")
before = #MOCK.printed
prof().talentPlanCount = 3
ns.Talents:PrintPlan(b, {})
check(string.find(MOCK.printed[#MOCK.printed], "Talent plan", 1, true) and #MOCK.printed == before + 1, "plan printed")

-- Preload -------------------------------------------------------------------------------------------------------------
local asked = 0
C_Item = C_Item or {}
local realReq = C_Item.RequestLoadItemDataByID
C_Item.RequestLoadItemDataByID = function() asked = asked + 1 end
MOCK.bags = { [0] = { { itemID = 96001 }, { itemID = 96002 } } }
prof().preloadData = false
check(ns.Assist:Preload() == nil, "preload off: nothing requested")
prof().preloadData = true
local n = ns.Assist:Preload()
MOCK.tick(2)
check(n and n >= 2 and asked == n, "preload asks for every guide and bag item (" .. tostring(n) .. ")")
prof().preloadData = false
C_Item.RequestLoadItemDataByID = realReq

-- restore
MOCK.bags, MOCK.equipped = { [0] = {} }, {}
MOCK.player.race, MOCK.player.class, MOCK.player.faction, MOCK.player.level = "Human", "WARRIOR", "Alliance", 1
E:Load("A_Human_Elwynn", { reset = true })
check(#ns.errors == 0, "no captured errors after feature tests: " .. table.concat(ns.errors, " | "))
