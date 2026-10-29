-- TBCGuide - minimal World of Warcraft API mocks for headless tests (Lua 5.1)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Only what the add-on touches is mocked. Frames accept any method call (returning nil)
-- so UI construction runs; behaviour that matters for tests (events, OnUpdate, quest log,
-- player info, talents) is modelled explicitly and controllable through MOCK.

MOCK = {
    time = 0,
    frames = {},
    player = { race = "Human", class = "WARRIOR", faction = "Alliance", level = 1, name = "Tester" },
    questLog = {},        -- array of { id=, title=, complete=bool, objectives={ {text=, done=} } }
    completed = {},       -- [questId] = true
    bind = "Northshire Abbey",
    zone = "Elwynn Forest",
    talents = {},         -- [tab] = { {name=, tier=, column=, rank=, maxRank=}, ... }
    printed = {},
}

local frameMeta
local function newObject(kind)
    local o = { __kind = kind, scripts = {}, events = {}, shown = true, children = {} }
    return setmetatable(o, frameMeta)
end

frameMeta = {
    __index = function(self, key)
        local special = {
            SetScript = function(s, name, fn) s.scripts[name] = fn end,
            GetScript = function(s, name) return s.scripts[name] end,
            HookScript = function(s, name, fn)
                local old = s.scripts[name]
                s.scripts[name] = function(...) if old then old(...) end fn(...) end
            end,
            RegisterEvent = function(s, ev) s.events[ev] = true end,
            UnregisterEvent = function(s, ev) s.events[ev] = nil end,
            Show = function(s) s.shown = true end,
            Hide = function(s) s.shown = false end,
            SetShown = function(s, v) s.shown = v and true or false end,
            IsShown = function(s) return s.shown end,
            IsVisible = function(s) return s.shown end,
            SetAttribute = function(s, k, v) local t = rawget(s, "attributes") or {} rawset(s, "attributes", t) t[k] = v end,
            GetAttribute = function(s, k) local t = rawget(s, "attributes") return t and t[k] end,
            SetScale = function(s, v) rawset(s, "scale", v) end,
            CreateTexture = function() return newObject("Texture") end,
            CreateFontString = function()
                local fs = newObject("FontString")
                fs.text = ""
                fs.SetText = function(f, t) f.text = t end
                fs.GetText = function(f) return f.text end
                fs.GetStringHeight = function() return 12 end
                fs.GetFont = function() return "Fonts\\FRIZQT__.TTF", 12 end
                return fs
            end,
            GetWidth = function() return 300 end,
            GetHeight = function() return 200 end,
            GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
            GetEffectiveScale = function() return 1 end,
            GetChecked = function(s) return s.checked end,
            SetChecked = function(s, v) s.checked = v end,
            GetText = function(s) return s.text or "" end,
            SetText = function(s, t) s.text = t end,
            GetParent = function(s) return s.parent end,
            SetParent = function(s, p) s.parent = p end,
            GetValue = function(s) return s.value or 0 end,
            SetValue = function(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end,
            SetPoint = function(s, ...) s.point = { ... } end,
            ClearAllPoints = function(s) s.point = nil end,
        }
        if special[key] then return special[key] end
        return function() return nil end
    end,
}

function CreateFrame(kind, name, parent)
    local f = newObject(kind)
    f.parent = parent
    table.insert(MOCK.frames, f)
    if name then _G[name] = f end
    return f
end

UIParent = newObject("Frame")
WorldMapFrame = newObject("Frame")
-- Minimap: 140 px wide, centred at (1000, 600), scale 1. The cursor is MOCK.cursorX/Y.
Minimap = newObject("Frame")
Minimap.GetCenter = function() return 1000, 600 end
Minimap.GetWidth = function() return 140 end
Minimap.GetEffectiveScale = function() return 1 end
MOCK.cursorX, MOCK.cursorY = 0, 0
function GetCursorPosition() return MOCK.cursorX, MOCK.cursorY end
InterfaceOptionsFrame = newObject("Frame")
InterfaceOptionsFrame.shown = false
MOCK.optionsOpened = 0
function HideUIPanel(f) f:Hide() end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(MOCK.printed, msg) end }
UISpecialFrames = {}
SlashCmdList = {}
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", MAGE = "Mage" }
ERR_NEWTAXIPATH = "New flight path discovered!"
BackdropTemplateMixin = {}

function MOCK.fire(event, ...)
    for _, f in ipairs(MOCK.frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

function MOCK.tick(seconds)
    local step = 0.05
    local t = 0
    while t < seconds do
        MOCK.time = MOCK.time + step
        t = t + step
        for _, f in ipairs(MOCK.frames) do
            if f.scripts.OnUpdate and f.shown then f.scripts.OnUpdate(f, step) end
        end
        local due = {}
        for i = #MOCK.timers, 1, -1 do
            if MOCK.timers[i].at <= MOCK.time then table.insert(due, table.remove(MOCK.timers, i)) end
        end
        for _, d in ipairs(due) do d.fn() end
    end
end

MOCK.timers = {}
C_Timer = { After = function(sec, fn) table.insert(MOCK.timers, { at = MOCK.time + sec, fn = fn }) end }

function GetTime() return MOCK.time end
function GetBuildInfo() return "2.5.6", "70577", "Oct 1 2026", 20506 end
C_AddOns = { GetAddOnMetadata = function(_, field) if field == "Version" then return "test" end end, IsAddOnLoaded = function() return false end }

function UnitRace() return MOCK.player.race, MOCK.player.race end
function UnitClass() return MOCK.player.class, MOCK.player.class end
function UnitFactionGroup() return MOCK.player.faction end
function UnitLevel() return MOCK.player.level end
function UnitName() return MOCK.player.name end
function GetRealmName() return MOCK.realm or "Testrealm" end
function UnitXP() return 50 end
function UnitXPMax() return 100 end
function GetRealZoneText() return MOCK.zone end
function GetZoneText() return MOCK.zone end
function GetSubZoneText() return "" end
function GetBindLocation() return MOCK.bind end
function GetPlayerFacing() return 0 end

C_QuestLog = { IsQuestFlaggedCompleted = function(id) return MOCK.completed[id] == true end }
function GetNumQuestLogEntries() return #MOCK.questLog, #MOCK.questLog end
function GetQuestLogTitle(i)
    local q = MOCK.questLog[i]
    if not q then return nil end
    return q.title, 1, nil, false, false, q.complete and 1 or nil, nil, q.id
end
function GetNumQuestLeaderBoards(i) return #(MOCK.questLog[i].objectives or {}) end
function GetQuestLogLeaderBoard(o, i)
    local ob = MOCK.questLog[i].objectives[o]
    return ob.text, "monster", ob.done
end

C_Map = {
    GetBestMapForUnit = function() return 1429 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.48, 0.42 end } end,
    GetWorldPosFromMapPos = function(_, v) return 0, { GetXY = function() return v.x * 1000, v.y * 1000 end } end,
    GetMapInfo = function() return { name = "Elwynn Forest" } end,
}
function CreateVector2D(x, y) return { x = x, y = y } end

function GetNumTalentTabs() return 3 end
function GetTalentTabInfo(tab) return "Tab" .. tab end
function GetNumTalents(tab) return #(MOCK.talents[tab] or {}) end
function GetTalentInfo(tab, i)
    local t = MOCK.talents[tab] and MOCK.talents[tab][i]
    if not t then return nil end
    return t.name, "icon", t.tier, t.column, t.rank, t.maxRank
end
function UnitCharacterPoints() return 0 end
function GetSpellTexture() return "icon" end
function GetSpellInfo() return "Spell", nil, "icon" end

function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_Initialize() end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton() end
function UIDropDownMenu_SetText() end
function CloseDropDownMenus() end
function InterfaceOptions_AddCategory() end
function InterfaceOptionsFrame_OpenToCategory() MOCK.optionsOpened = MOCK.optionsOpened + 1; InterfaceOptionsFrame:Show() end
function ReloadUI() end
function hooksecurefunc() end

tinsert = table.insert
tremove = table.remove
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

bit = bit or {
    band = function(a, b)
        local r, m = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then r = r + m end
            a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
        end
        return r
    end,
}

-- Bags, items, money, merchant (junk selling) ------------------------------------------------------
MOCK.money = 0
MOCK.bags = { [0] = {} }      -- [bag][slot] = { itemID=, count=, locked=, questItem=, noValue= }
MOCK.items = {}               -- [itemID] = { name=, quality=, sellPrice=, classID=, bindType=, uncached= }
MOCK.merchantOpen = false
MOCK.sellFails = {}           -- [itemID] = true: the server refuses to buy it
MOCK.useCalls = {}
MOCK.cursor = false
MOCK.shift = false

local function bagItem(bag, slot) return MOCK.bags[bag] and MOCK.bags[bag][slot] end

C_Container = {
    GetContainerNumSlots = function(bag) return MOCK.bags[bag] and 16 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local b = bagItem(bag, slot)
        if not b then return nil end
        local it = MOCK.items[b.itemID] or {}
        return { itemID = b.itemID, stackCount = b.count or 1, isLocked = b.locked or false, quality = it.quality,
                 hyperlink = "|Hitem:" .. b.itemID .. "|h[" .. tostring(it.name) .. "]|h", hasNoValue = b.noValue or false,
                 isBound = b.bound }
    end,
    GetContainerItemQuestInfo = function(bag, slot)
        local b = bagItem(bag, slot)
        return { isQuestItem = b and b.questItem or false, questID = nil, isActive = false }
    end,
    UseContainerItem = function(bag, slot)
        table.insert(MOCK.useCalls, { bag = bag, slot = slot })
        local b = bagItem(bag, slot)
        if not b or not MOCK.merchantOpen or MOCK.sellFails[b.itemID] then return end
        local it = MOCK.items[b.itemID]
        MOCK.money = MOCK.money + (it.sellPrice or 0) * (b.count or 1)
        MOCK.bags[bag][slot] = nil
    end,
}

-- Equipping (Gear/AutoEquip.lua). The cursor holds { itemID=, bound=, bag=, slot= } in MOCK.cursorItem.
MOCK.cursorItem = nil
MOCK.freeOverride = nil      -- number: pretend this many free bag slots
MOCK.equipFails = false      -- EquipCursorItem does nothing (item stays on the cursor)
MOCK.equipCalls = {}
MOCK.equippedBound = {}      -- [slot] = true once something was equipped there
local function setCursor(c) MOCK.cursorItem = c MOCK.cursor = c ~= nil end
function C_Container.PickupContainerItem(bag, slot)
    local b = bagItem(bag, slot)
    if MOCK.cursorItem then
        local c = MOCK.cursorItem
        MOCK.bags[bag] = MOCK.bags[bag] or {}
        MOCK.bags[bag][slot] = { itemID = c.itemID, bound = c.bound }
        setCursor(b and { itemID = b.itemID, bound = b.bound, bag = bag, slot = slot } or nil)
        return
    end
    if not b or b.locked then return end
    MOCK.bags[bag][slot] = nil
    setCursor({ itemID = b.itemID, bound = b.bound, bag = bag, slot = slot })
end
function C_Container.GetContainerNumFreeSlots(bag)
    if not MOCK.bags[bag] then return 0 end
    if MOCK.freeOverride then return bag == 0 and MOCK.freeOverride or 0 end
    local used = 0
    for _ in pairs(MOCK.bags[bag]) do used = used + 1 end
    return 16 - used
end
function ClearCursor() setCursor(nil) end
MOCK.pickupContainerItem = C_Container.PickupContainerItem
MOCK.getContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots
function GetInventoryItemID(unit, slot) return unit == "player" and MOCK.equipped[slot] or nil end
local function freeSpot()
    for bag = 0, 4 do
        if MOCK.bags[bag] then for slot = 1, 16 do if not MOCK.bags[bag][slot] then return bag, slot end end end
    end
end
function EquipCursorItem(slot)
    local c = MOCK.cursorItem
    table.insert(MOCK.equipCalls, { slot = slot, itemID = c and c.itemID })
    if not c or MOCK.equipFails then return end
    local it = MOCK.items[c.itemID] or {}
    if (it.bindType == 2 and not c.bound) or it.askBind then MOCK.fire("EQUIP_BIND_CONFIRM", slot) return end
    local out = {}
    if MOCK.equipped[slot] then out[#out + 1] = MOCK.equipped[slot] end
    if it.equipLoc == "INVTYPE_2HWEAPON" and MOCK.equipped[17] then out[#out + 1] = MOCK.equipped[17] MOCK.equipped[17] = nil end
    MOCK.equipped[slot] = c.itemID
    setCursor(nil)
    for i, id in ipairs(out) do
        local bag, s = c.bag, c.slot
        if i > 1 or MOCK.bags[bag][s] then bag, s = freeSpot() end
        MOCK.bags[bag][s] = { itemID = id, bound = true }
    end
    if not MOCK.holdEquipEvent then MOCK.fire("PLAYER_EQUIPMENT_CHANGED", slot) end
end

local function itemId(id)
    if type(id) == "string" then id = tonumber(string.match(id, "item:(%d+)")) end
    return id
end
function MOCK.link(id) return "|cffffffff|Hitem:" .. id .. "::::::::70:::::|h[" .. tostring(MOCK.items[id] and MOCK.items[id].name) .. "]|h|r" end
-- MOCK.items[id] may also carry gear fields: equipLoc=, ilvl=, reqLevel=, subclassID=, stats={ITEM_MOD_*=n}
function GetItemInfo(id)
    id = itemId(id)
    local it = MOCK.items[id]
    if not it or it.uncached then return nil end
    return it.name, MOCK.link(id), it.quality, it.ilvl or 1, it.reqLevel or 1, "type", "subtype", 1, it.equipLoc or "",
        "icon", it.sellPrice, it.classID, it.subclassID or 0, it.bindType or 0
end
function GetItemStats(link)
    local it = MOCK.items[itemId(link)]
    if not it then return nil end
    local out = {}
    for k, v in pairs(it.stats or {}) do out[k] = v end
    return out
end
MOCK.equipped = {}   -- [inventory slot] = itemID
MOCK.ratings = {}    -- [CR index] = rating
function GetInventoryItemLink(unit, slot)
    local id = unit == "player" and MOCK.equipped[slot]
    return id and MOCK.link(id) or nil
end
function GetCombatRating(i) return MOCK.ratings[i] or 0 end
MOCK.questChoices = {} -- [i] = itemID for the open reward panel
function GetQuestItemLink(kind, i) local id = kind == "choice" and MOCK.questChoices[i] return id and MOCK.link(id) or nil end

-- Tooltips: GetItem returns MOCK.tooltipItem's link; AddLine records lines.
local function tooltip(name)
    local tt = CreateFrame("GameTooltip", name)
    tt.lines = {}
    tt.GetItem = function(s) local id = s.item return id and MOCK.items[id] and MOCK.items[id].name, id and MOCK.link(id) end
    tt.AddLine = function(s, text) table.insert(s.lines, text) end
    tt.NumLines = function(s) return #s.lines + 1 end
    tt.GetName = function() return name end
    return tt
end
GameTooltip = tooltip("GameTooltip")
ItemRefTooltip = tooltip("ItemRefTooltip")
function GetMoney() return MOCK.money end
function CursorHasItem() return MOCK.cursor end
function IsShiftKeyDown() return MOCK.shift end

-- Quest dialogs (gossip / greeting / detail / progress / reward) -----------------------------------
MOCK.gossip = { available = {}, active = {} }  -- { {questID=, title=, isComplete=} }
MOCK.greeting = { available = {}, active = {} } -- { {title=, isComplete=} } (no ids, like old clients)
MOCK.dialog = nil      -- { questID=, title=, text=, choices=, completable=, money=, fromPlayer= }
MOCK.calls = {}        -- log of automation calls, e.g. "accept", "select_available:783"

local function copyList(l)
    local out = {}
    for i, v in ipairs(l) do out[i] = { questID = v.questID, title = v.title, isComplete = v.isComplete } end
    return out
end
local function call(s) table.insert(MOCK.calls, s) end

C_GossipInfo = {
    GetAvailableQuests = function() return copyList(MOCK.gossip.available) end,
    GetActiveQuests = function() return copyList(MOCK.gossip.active) end,
    SelectAvailableQuest = function(id) call("select_available:" .. tostring(id)) end,
    SelectActiveQuest = function(id) call("select_active:" .. tostring(id)) end,
}
function GetNumAvailableQuests() return #MOCK.greeting.available end
function GetAvailableTitle(i) return MOCK.greeting.available[i] and MOCK.greeting.available[i].title end
function GetNumActiveQuests() return #MOCK.greeting.active end
function GetActiveTitle(i) local a = MOCK.greeting.active[i] return a and a.title, a and a.isComplete end
function SelectAvailableQuest(i) call("greeting_available:" .. i) end
function SelectActiveQuest(i) call("greeting_active:" .. i) end

function GetQuestID() return MOCK.dialog and MOCK.dialog.questID or 0 end
function GetTitleText() return MOCK.dialog and MOCK.dialog.title or "" end
function GetObjectiveText() return MOCK.dialog and MOCK.dialog.text or "" end
function GetQuestText() return "" end
function GetNumQuestChoices() return MOCK.dialog and MOCK.dialog.choices or 0 end
function IsQuestCompletable() return MOCK.dialog and MOCK.dialog.completable or false end
function GetQuestMoneyToGet() return MOCK.dialog and MOCK.dialog.money or 0 end
function UnitExists(u) return u == "questnpc" and MOCK.dialog ~= nil end
function UnitIsPlayer(u) return u == "questnpc" and MOCK.dialog ~= nil and MOCK.dialog.fromPlayer or false end
function AcceptQuest() call("accept:" .. tostring(GetQuestID())) end
function CompleteQuest() call("complete:" .. tostring(GetQuestID())) end
function GetQuestReward(i) call("reward:" .. tostring(GetQuestID()) .. ":" .. tostring(i)) end

-- Quest log abandon + confirmation popups ------------------------------------------------------------
MOCK.selectedLog = nil
MOCK.popups = {}
StaticPopupDialogs = {}
function StaticPopup_Show(name, a) table.insert(MOCK.popups, { name = name, arg = a }) end
function SelectQuestLogEntry(i) MOCK.selectedLog = i end
function SetAbandonQuest() MOCK.abandonArmed = MOCK.selectedLog end
function AbandonQuest()
    if MOCK.abandonArmed then
        table.remove(MOCK.questLog, MOCK.abandonArmed)
        table.insert(MOCK.calls, "abandon")
        MOCK.abandonArmed = nil
    end
end
QuestLogFrame = CreateFrame("Frame", "QuestLogFrame")

-- Units and raid target icons -----------------------------------------------------------------------
-- MOCK.units[token] = { guid=, name=, dead= }; icons are stored per GUID like the real client
-- (one icon per unit, each icon on one unit). MOCK.markDenied makes the client ignore SetRaidTarget.
MOCK.units = {}
MOCK.icons = {}
MOCK.markCalls = 0
MOCK.inRaid, MOCK.leader, MOCK.assist, MOCK.combat = false, false, false, false

function MOCK.creature(npcId, spawn, name)
    return { guid = string.format("Creature-0-4372-0-17-%d-%010d", npcId, spawn or 1), name = name or ("npc " .. npcId) }
end

local baseUnitExists, baseUnitName = UnitExists, UnitName
function UnitExists(u)
    if MOCK.units[u] then return true end
    return baseUnitExists(u)
end
function UnitName(u)
    if u and MOCK.units[u] then return MOCK.units[u].name end
    return baseUnitName(u)
end
function UnitGUID(u) return MOCK.units[u] and MOCK.units[u].guid end
function UnitIsDead(u) return MOCK.units[u] and MOCK.units[u].dead or false end
function GetRaidTargetIndex(u)
    local x = MOCK.units[u]
    return x and MOCK.icons[x.guid] or nil
end
function SetRaidTarget(u, i)
    MOCK.markCalls = MOCK.markCalls + 1
    if MOCK.markDenied then return end
    local x = MOCK.units[u]
    if not x then return end
    if i == 0 or MOCK.icons[x.guid] == i then
        MOCK.icons[x.guid] = nil -- real client: same icon again toggles it off
    else
        for g, ic in pairs(MOCK.icons) do if ic == i then MOCK.icons[g] = nil end end
        MOCK.icons[x.guid] = i
    end
    MOCK.fire("RAID_TARGET_UPDATE")
end
-- Combat log: MOCK.cleu = { timestamp, subevent, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, destGUID, ... }
function CombatLogGetCurrentEventInfo() return unpack(MOCK.cleu or {}) end
-- A unit dies: like the real client, its raid icon disappears WITHOUT a RAID_TARGET_UPDATE event.
function MOCK.kill(u)
    u.dead = true
    MOCK.icons[u.guid] = nil
    MOCK.cleu = { MOCK.time, "UNIT_DIED", false, "", "", 0, 0, u.guid }
    MOCK.fire("COMBAT_LOG_EVENT_UNFILTERED")
    MOCK.cleu = nil
end
function IsInRaid() return MOCK.inRaid end
function UnitIsGroupLeader() return MOCK.leader end
function UnitIsGroupAssistant() return MOCK.assist end
function InCombatLockdown() return MOCK.combat end
function strsplit(sep, s)
    local out = {}
    for part in string.gmatch(s, "([^" .. sep .. "]+)") do out[#out + 1] = part end
    return unpack(out)
end
