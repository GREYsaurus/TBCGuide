-- TBCGuide - headless tests: settings window, profiles and the features behind it
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
-- Loaded by tests/run_tests.lua after boot; uses TEST.check and TEST.ns.

local check, ns = TEST.check, TEST.ns
local CF, A, P = ns.Config, ns.Assist, ns.Profiles
local function prof() return ns.db.profile end
local function printed(pattern, from)
    for i = (from or 0) + 1, #MOCK.printed do if string.find(MOCK.printed[i], pattern, 1, true) then return true end end
    return false
end

-- Window ------------------------------------------------------------------------------------------------
check(CF.frame ~= nil and _G.TBCGuideConfigFrame == CF.frame, "settings window created at login")
CF:Create()
check(_G.TBCGuideConfigFrame == CF.frame, "created only once")
check(string.find(CF.title:GetText(), "TBCGuide - Version", 1, true), "title shows the add-on name and version")
local ids = { "general", "guide", "targeting", "tracker", "comms", "tips", "help", "advanced", "profiles" }
local tabCount = 0
for _ in pairs(CF.tabs) do tabCount = tabCount + 1 end
check(tabCount == 9, "two rows of tabs: 7 + 2 (Look and Feel removed)")
CF:Show()
check(CF.current == "general" and CF.frame:IsShown(), "opens on General")

-- Every page builds; every real control points at an existing setting -----------------------------------
local real, plannedCount = 0, 0
for _, id in ipairs(ids) do
    local ok, err = pcall(CF.Show, CF, id)
    check(ok and CF.built[id] and #CF.built[id].widgets > 0, "page " .. id .. " builds: " .. tostring(err))
    for _, it in ipairs(ns.ConfigPages[id].items(CF)) do
        if it.planned then plannedCount = plannedCount + 1
        elseif it.key then
            real = real + 1
            check(prof()[it.key] ~= nil, "page " .. id .. ": setting '" .. it.key .. "' exists")
        elseif it.type == "toggle" or it.type == "range" or it.type == "select" then
            real = real + 1
            check(type(it.get) == "function" and (it.set ~= nil), "page " .. id .. ": '" .. tostring(it.label) .. "' has get/set")
        end
    end
end
check(real >= 100 and plannedCount == 0, "real controls: " .. real .. ", planned (disabled): " .. plannedCount)

local function widget(page, label)
    for _, w in ipairs(CF.built[page].widgets) do
        if w.item and w.item.label == label then return w end
    end
end

-- Toggles change settings and take effect -------------------------------------------------------------
CF:Show("general")
local w = widget("general", "Show all Enabled Frames")
w.frame:SetChecked(false)
w.frame.scripts.OnClick(w.frame)
check(prof().showAllFrames == false and not ns.MainFrame.frame:IsShown(), "unticking Show all Enabled Frames hides the guide window")
w.frame:SetChecked(true)
w.frame.scripts.OnClick(w.frame)
check(prof().showAllFrames == true, "ticking it again turns it back on")
w = widget("general", "Hide waypoint arrow")
w.frame:SetChecked(true)
w.frame.scripts.OnClick(w.frame)
check(prof().showArrow == false, "inverted toggle: Hide waypoint arrow sets showArrow off")
w.frame:SetChecked(false)
w.frame.scripts.OnClick(w.frame)
check(prof().showArrow == true, "and back on")
w = widget("general", "Quest auto accept/turn in")
w.frame:SetChecked(false)
w.frame.scripts.OnClick(w.frame)
check(prof().autoAccept == false and prof().autoTurnIn == false, "combined toggle sets accept and turn-in")
w.frame:SetChecked(true)
w.frame.scripts.OnClick(w.frame)
CF:Show("tips")
w = widget("tips", "Enable Auctioneer")
check(w and not w.item.planned and w.frame.scripts.OnClick ~= nil, "Enable Auctioneer is a working option")
CF:Show("advanced")
w = widget("advanced", "Update Frequency (ms)")
w.frame:SetValue(100)
check(prof().arrowUpdateMs == 100, "slider writes its setting")
prof().arrowUpdateMs = 50
CF:SyncAll()
check(w.frame:GetValue() == 50, "sync shows the stored value")
CF.frame:Hide()

-- Profiles --------------------------------------------------------------------------------------------
local first = P:Current()
check(first == "Default", "existing settings live in the 'Default' profile")
prof().scale = 1.3
check(P:Set("Alt") and P:Current() == "Alt" and prof().scale == 1, "new profile starts from defaults")
check(TBCGuideDB.profileKeys[ns.CharKey()] == "Alt", "the character remembers its profile")
check(P:CopyFrom("Default") and prof().scale == 1.3, "copy from another profile")
prof().scale = 0.8
check(TBCGuideDB.profiles.Default.scale == 1.3, "profiles are separate tables")
check(not P:Delete("Alt") and not P:Delete("Default"), "active and default profiles cannot be deleted")
P:Reset()
check(prof().scale == 1 and prof().showAllFrames == true, "reset puts the active profile back to defaults")
check(P:Set("Default") and prof().scale == 1.3, "switching back restores the other profile's settings")
check(P:Delete("Alt") and TBCGuideDB.profiles.Alt == nil, "unused profile deleted")
check(not P:Set("   "), "blank profile names are refused")
-- a profile used by another character is reassigned when deleted
P:Set("Shared")
P:Set("Default")
TBCGuideDB.profileKeys["Other - Realm"] = "Shared"
P:Delete("Shared")
check(TBCGuideDB.profileKeys["Other - Realm"] == "Default", "characters on a deleted profile fall back to the default")
-- set as default: new characters start with it
P:Set("Main")
P:SetDefault()
local name = MOCK.player.name
MOCK.player.name = "Newchar"
ns:InitSavedVariables()
check(P:Current() == "Main", "a new character starts with the default profile")
MOCK.player.name = name
ns:InitSavedVariables()
check(P:Current() == "Main", "the character keeps its profile after a reload")
P:Set("Default")
TBCGuideDB.defaultProfile = "Default"
P:Delete("Main")
-- migration from the single pre-0.5.0 profile
local saved = TBCGuideDB
TBCGuideDB = { profile = { scale = 1.4, autoMarkObjectives = true } }
ns:InitSavedVariables()
check(TBCGuideDB.profile == nil and TBCGuideDB.profiles.Default.scale == 1.4 and prof().scale == 1.4, "old settings become the Default profile")
check(rawget(ns.db, "profile") == TBCGuideDB.profiles.Default and rawget(TBCGuideDB, "profile") == nil, "the profile table is saved once (no alias)")
TBCGuideDB = saved
ns:InitSavedVariables()
prof().scale = 1

-- Frames: autohide in raids --------------------------------------------------------------------------
ns.db.frames.main.shown = true -- the player has the window open
prof().autohideRaid = true
MOCK.inRaid = true
A:ApplyFrames()
check(not A:FramesAllowed() and not ns.MainFrame.frame:IsShown(), "autohide in raids hides the guide window")
MOCK.inRaid = false
A:ApplyFrames()
check(A:FramesAllowed() and ns.MainFrame.frame:IsShown(), "shown again after leaving the raid")
prof().autohideRaid = false

-- Trainer automation -----------------------------------------------------------------------------------
local services, bought = {}, {}
function GetNumTrainerServices() return #services end
function GetTrainerServiceInfo(i) return services[i].name, nil, services[i].kind end
function GetTrainerServiceCost(i) return services[i].cost end
function BuyTrainerService(i) table.insert(bought, services[i].name) table.remove(services, i) end
services = { { name = "Known", kind = "used", cost = 1 }, { name = "Too dear", kind = "available", cost = 1e9 }, { name = "Cheap", kind = "available", cost = 10 } }
MOCK.money = 100
A:TrainerStep()
check(#bought == 0, "trainer automation off: nothing learned")
prof().trainerAuto = true
A:TrainerStep()
A:TrainerStep()
check(#bought == 1 and bought[1] == "Cheap", "learns affordable spells only")
prof().trainerAuto = false

-- Guide-step automation (flight, bind, gossip) ---------------------------------------------------------
local step
local realCurrent = ns.Engine.CurrentStep
ns.Engine.CurrentStep = function() return step end
local taken
function NumTaxiNodes() return 2 end
function TaxiNodeName(i) return ({ "Stormwind, Elwynn", "Sentinel Hill, Westfall" })[i] end
function TaxiNodeGetType() return "REACHABLE" end
function TakeTaxiNode(i) taken = i end
step = { "fly", dest = "Sentinel Hill" }
A:OnTaxiMap()
check(taken == 2, "flight path automation flies to the fly step's destination")
taken = nil
step = { "accept", q = 1 }
A:OnTaxiMap()
check(taken == nil, "no fly step: the flight map is left to you")
MOCK.shift = true
step = { "fly", dest = "Sentinel Hill" }
A:OnTaxiMap()
check(taken == nil, "Shift held: no automatic flight")
MOCK.shift = false

local options, selected = {}, {}
C_GossipInfo.GetOptions = function() return options end
C_GossipInfo.SelectOption = function(id) table.insert(selected, id) end
options = { { name = "Make this inn your home.", type = "binder", gossipOptionID = 11 }, { name = "Trade", type = "vendor", gossipOptionID = 12 } }
step = { "bind", place = "Goldshire" }
check(A:OnGossip() == "bind" and selected[1] == 11, "bind step: the innkeeper's bind option is chosen")
local confirmed = false
function ConfirmBinder() confirmed = true end
check(A:OnConfirmBinder() and confirmed, "bind step: the bind is confirmed")
step = { "accept", q = 1 }
confirmed = false
check(not A:OnConfirmBinder() and not confirmed, "no bind step: the bind confirmation is left to you")
selected = {}
options = { { name = "Tell me more.", type = "gossip", gossipOptionID = 21 } }
check(A:OnGossip() == "skip" and selected[1] == 21, "skip gossip: the only option is chosen")
options[2] = { name = "Something else", type = "gossip", gossipOptionID = 22 }
selected = {}
check(A:OnGossip() == nil and #selected == 0, "several options: nothing is chosen")
options = { { name = "Bind", type = "binder", gossipOptionID = 31 } }
check(A:OnGossip() == nil, "a lone bind option is never chosen outside a bind step")
MOCK.gossip.available = { { questID = 5, title = "q" } }
options = { { name = "Tell me more.", type = "gossip", gossipOptionID = 41 } }
check(A:OnGossip() == nil, "NPC with quests: gossip is not skipped")
MOCK.gossip.available = {}
prof().skipGossip = false
check(A:OnGossip() == nil, "Skip Gossip off: nothing chosen")
prof().skipGossip = true

-- Targeting macro and notifications ------------------------------------------------------------------------
step = { "complete", q = 790, mark = { i = 8, npcs = { 3281 } } } -- Sarkoth, as compiled from the Durotar guide
local body, n = A:MacroBody()
check(n >= 1 and string.sub(body, 1, 12) == "/cleartarget" and string.find(body, "/tar Sarkoth", 1, true) and #body <= 255, "macro targets the step's NPCs")
local macros = {}
function GetMacroIndexByName(nm) return macros[nm] and 1 or 0 end
function GetNumMacros() return 0 end
function CreateMacro(nm, icon, b) macros[nm] = b return 1 end
function EditMacro(idx, nm, icon, b) macros["TBCGuide"] = b end
A.lastBody = nil
MOCK.combat = true
A:UpdateMacro()
check(macros.TBCGuide == nil and A.macroPending, "no macro changes in combat (done after combat)")
MOCK.combat = false
MOCK.fire("PLAYER_REGEN_ENABLED")
check(macros.TBCGuide ~= nil and string.find(macros.TBCGuide, "Sarkoth", 1, true), "macro created after combat")
local before = #MOCK.printed
MOCK.units.nameplate1 = MOCK.creature(3281, 501, "Sarkoth")
A.notified = {}
A:OnUnitSeen("nameplate1")
A:OnUnitSeen("nameplate1")
local count = 0
for i = before + 1, #MOCK.printed do if string.find(MOCK.printed[i], "nearby", 1, true) then count = count + 1 end end
check(count == 1, "notify on new target: once per NPC")
MOCK.units.nameplate1 = nil
-- rare mobs
prof().trackRares = true
before = #MOCK.printed
MOCK.units.nameplate2 = MOCK.creature(79, 502, "Narg the Taskmaster")
A:OnUnitSeen("nameplate2")
check(printed("Rare:", before), "rare mob alert")
MOCK.cleu = { 0, "UNIT_DIED", false, "", "", 0, 0, MOCK.units.nameplate2.guid }
MOCK.fire("COMBAT_LOG_EVENT_UNFILTERED")
MOCK.cleu = nil
check(ns.char.killedRares[79] == true, "killed rares are remembered")
prof().skipKilledRares = true
before = #MOCK.printed
MOCK.units.nameplate2 = MOCK.creature(79, 503, "Narg the Taskmaster")
A:OnUnitSeen("nameplate2")
check(not printed("Rare:", before), "already killed rares are skipped when asked")
prof().trackRares, prof().skipKilledRares = false, false
MOCK.units.nameplate2 = nil
ns.Engine.CurrentStep = realCurrent

-- Level-up announcements -------------------------------------------------------------------------------
local sent = {}
function SendChatMessage(msg, chan) table.insert(sent, chan .. ":" .. msg) end
function IsInGuild() return true end
A:OnLevelUp(12)
check(#sent == 0, "announcements off by default")
prof().announceLevelEmote, prof().announceLevelGuild = true, true
A:OnLevelUp(12)
check(#sent == 2 and string.find(sent[1], "EMOTE:", 1, true) and string.find(sent[2], "GUILD:", 1, true), "emote and guild announcements")
prof().announceLevelEmote, prof().announceLevelGuild = false, false

-- Warnings ----------------------------------------------------------------------------------------------
check(A:CheckBreath(10000, 60000) == true, "breath below 20%: warning")
check(A:CheckBreath(9000, 60000) == nil, "warned once per dive")
A:CheckBreath(50000, 60000)
check(A:CheckBreath(10000, 60000) == true, "warns again after taking a breath")
prof().drownWarn = false
A.warned.breath = nil
check(A:CheckBreath(1000, 60000) == nil, "breath warning can be turned off")
prof().drownWarn = true
local hp = 100
function UnitHealth() return hp end
function UnitHealthMax() return 100 end
function UnitIsDeadOrGhost() return false end
hp = 15
check(A:CheckHealth() == true, "low health warning")
check(A:CheckHealth() == nil, "low health warned once")
hp = 50
A:CheckHealth()
hp = 10
check(A:CheckHealth() == true, "warns again after recovering")

-- Junk list, deletion, inventory manager -----------------------------------------------------------------
MOCK.items[95001] = { name = "Cheap Grey", quality = 0, sellPrice = 5, classID = 15 }
MOCK.items[95002] = { name = "Dear Grey", quality = 0, sellPrice = 500, classID = 15 }
MOCK.items[95003] = { name = "White Trinket", quality = 1, sellPrice = 50, classID = 15 }
MOCK.bags[0] = { [1] = { itemID = 95002, count = 1 }, [2] = { itemID = 95001, count = 1 }, [3] = { itemID = 95003, count = 1 } }
local deleted = {}
C_Container.PickupContainerItem = function(bag, slot) MOCK.cursor = MOCK.bags[bag][slot] and { bag = bag, slot = slot } end
function DeleteCursorItem() local c = MOCK.cursor table.insert(deleted, MOCK.bags[c.bag][c.slot].itemID) MOCK.bags[c.bag][c.slot] = nil MOCK.cursor = false end
local realCursor = ns.Compat.CursorHasItem
ns.Compat.CursorHasItem = function() return MOCK.cursor and true or false end
check(A:DeleteCheapestJunk(true) and deleted[1] == 95001, "deletes the junk item worth least")
A:ToggleJunk(95003)
check(ns.db.junkList[95003] == true, "junk list: item added")
local scan = ns.Vendor:Scan()
local listed = false
for _, e in ipairs(scan) do if e.itemID == 95003 then listed = true end end
check(listed, "listed items are sold like grey items")
A:ToggleJunk(95003)
check(ns.db.junkList[95003] == nil, "junk list: item removed")
prof().inventoryManager = false
check(not A:DeleteCheapestJunk(true), "inventory manager off: nothing deleted")
prof().inventoryManager = true
MOCK.combat = true
check(not A:DeleteCheapestJunk(true), "never deletes in combat")
MOCK.combat = false
-- discard when full
C_Container.GetContainerNumFreeSlots = function() return 0 end
deleted = {}
A:OnBagsChanged()
check(#deleted == 0, "discard-when-full is off by default")
prof().discardJunkFull = true
A:OnBagsChanged()
check(deleted[1] == 95002, "bags full: the cheapest junk item is discarded")
prof().discardJunkFull = false
C_Container.GetContainerNumFreeSlots = nil
ns.Compat.CursorHasItem = realCursor
A:ToggleJunk(95001)
A:ResetJunkList()
check(next(ns.db.junkList) == nil, "reset junk list")
MOCK.bags[0] = {}

-- Conflicts ------------------------------------------------------------------------------------------------
C_AddOns.IsAddOnLoaded = function(nm) return nm == "RXPGuides" end
before = #MOCK.printed
A:CheckConflicts()
check(printed("Other leveling guide add-ons are loaded", before) and printed("RXPGuides", before), "warns about other guide add-ons")
prof().checkConflicts = false
before = #MOCK.printed
A:CheckConflicts()
check(not printed("Other leveling guide", before), "conflict check can be turned off")
prof().checkConflicts = true
C_AddOns.IsAddOnLoaded = function() return false end

-- Skip overleveled steps ------------------------------------------------------------------------------------
MOCK.player.race, MOCK.player.class, MOCK.player.faction = "Human", "WARRIOR", "Alliance"
ns.Engine:Load("A_Human_Elwynn", { reset = true })
MOCK.player.level = 40
ns.Engine:Refresh()
local g = ns.Engine.guide
local greyIdx, chainIdx
for i, s in ipairs(g.steps) do
    if s[1] == "accept" and s.q then
        if ns.Engine.prereqOf[s.q] then chainIdx = chainIdx or i elseif not greyIdx and ns.Engine:IsGrey(s.q) then greyIdx = i end
    end
end
check(greyIdx and ns.Engine.status[greyIdx] == "skipped" and ns.Engine.autoReason[greyIdx] == "grey quest for your level", "grey quest pickup skipped")
check(chainIdx and ns.Engine.status[chainIdx] ~= "skipped", "a grey quest that unlocks a later quest is kept")
prof().disableStepSkips = true
ns.Engine:Refresh()
check(ns.Engine.status[greyIdx] ~= "skipped", "Disable step skips: nothing is skipped automatically")
prof().disableStepSkips = false
prof().skipOverleveled = false
ns.Engine:Refresh()
check(ns.Engine.status[greyIdx] ~= "skipped", "Skip overleveled steps off: grey quests stay")
prof().skipOverleveled = true
MOCK.player.level = 1
ns.Engine:Load("A_Human_Elwynn", { reset = true })

-- Quest auto rewards ---------------------------------------------------------------------------------------
-- (items 90001/90002 come from tests/test_gear.lua: a clear upgrade for a level-70 rogue)
MOCK.player.class, MOCK.player.level = "ROGUE", 70
ns.char.gearProfile = "rogue_combat_raid"
MOCK.equipped = { [8] = 90002 }
MOCK.questChoices = { 90002, 90001 }
MOCK.dialog = { questID = 88000, title = "Reward Quest", choices = 2, completable = true }
local pick = ns.GearUI:AutoRewardChoice()
check(pick and pick.index == 2, "auto reward: the clear gear upgrade")
MOCK.questChoices = { 90001, 90001 }
check(ns.GearUI:AutoRewardChoice() == nil, "auto reward: a tie is left to the player")
MOCK.calls, MOCK.dialog = {}, { questID = 88001, title = "Reward Quest", choices = 2, completable = true }
MOCK.questChoices = { 90002, 90001 }
prof().turnInUnrelated = true
MOCK.fire("QUEST_COMPLETE")
local chose = false
for _, c in ipairs(MOCK.calls) do if c == "reward:88001:2" then chose = true end end
check(not chose, "Quest auto rewards off (default): no reward chosen")
prof().autoReward = true
ns.GearUI.rankedQuest = {}
MOCK.calls = {}
ns.QuestAuto.tried = {}
MOCK.fire("QUEST_COMPLETE")
for _, c in ipairs(MOCK.calls) do if c == "reward:88001:2" then chose = true end end
check(chose, "Quest auto rewards on: the clear upgrade is chosen")
prof().autoReward, prof().turnInUnrelated = false, false
MOCK.dialog, MOCK.questChoices, MOCK.equipped = nil, {}, {}
ns.char.gearProfile = nil
MOCK.player.class, MOCK.player.level = "WARRIOR", 1

-- Step text colours ----------------------------------------------------------------------------------------
prof().colorQuest = { r = 1, g = 0, b = 0 }
local title = ns.StepText:Title({ "accept", q = 783, title = "A Threat Within" })
check(string.find(title, "|cffff0000", 1, true), "quest colour comes from the profile")
prof().colorQuest = { r = 1, g = 0.82, b = 0 }

-- Help and profile pages show TBCGuide's own commands -----------------------------------------------------
local helpText = ""
for _, it in ipairs(ns.ConfigPages.help.items(CF)) do if it.text then helpText = helpText .. it.text end end
check(string.find(helpText, "/tbcg", 1, true) and not string.find(helpText, "/rxp", 1, true), "help lists TBCGuide commands")
check(#ns.errors == 0, "no captured errors after settings tests: " .. table.concat(ns.errors, " | "))
