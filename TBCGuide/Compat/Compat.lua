-- TBCGuide - client compatibility layer
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Every game API the add-on calls goes through this file. Each wrapper checks the function
-- exists and degrades to a safe value when it does not, so a missing/renamed API never
-- prevents initialisation. ns.Compat.missing lists what was unavailable (/tbcg debug api).

local _, ns = ...

local C = {}
ns.Compat = C
C.missing = {}

local function has(fnPath)
    local t = _G
    for part in string.gmatch(fnPath, "[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return t
end
C.Has = has

local function note(name)
    if not C.missing[name] then C.missing[name] = true end
end

-- Client info ----------------------------------------------------------------------------------

function C.GetInterface()
    if GetBuildInfo then
        local _, build, _, tocVersion = GetBuildInfo()
        return tonumber(tocVersion) or 0, build
    end
    return 0, "?"
end

function C.GetAddOnMetadata(addon, field)
    local f = has("C_AddOns.GetAddOnMetadata") or has("GetAddOnMetadata")
    if f then return f(addon, field) end
    note("GetAddOnMetadata")
end

function C.IsAddOnLoaded(addon)
    local f = has("C_AddOns.IsAddOnLoaded") or has("IsAddOnLoaded")
    if f then return f(addon) and true or false end
    return false
end

-- Player ---------------------------------------------------------------------------------------

function C.PlayerInfo()
    local _, raceFile = UnitRace("player")
    local _, classFile = UnitClass("player")
    local faction = UnitFactionGroup("player")
    return {
        race = raceFile,           -- e.g. "Human", "Scourge", "BloodElf", "Draenei"
        class = classFile,         -- e.g. "WARRIOR"
        faction = faction,         -- "Alliance" / "Horde"
        level = UnitLevel("player") or 1,
        name = UnitName("player"),
    }
end

-- Quest history --------------------------------------------------------------------------------

local completedCache, completedCacheTime = nil, 0

function C.IsQuestCompleted(questId)
    if not questId then return false end
    local f = has("C_QuestLog.IsQuestFlaggedCompleted") or has("IsQuestFlaggedCompleted")
    if f then return f(questId) and true or false end
    note("IsQuestFlaggedCompleted")
    -- Legacy fallback: GetQuestsCompleted() fills a table (expensive; cache for 2s).
    if GetQuestsCompleted then
        if not completedCache or (GetTime() - completedCacheTime) > 2 then
            completedCache = {}
            local r = GetQuestsCompleted(completedCache)
            if type(r) == "table" then completedCache = r end
            completedCacheTime = GetTime()
        end
        return completedCache[questId] and true or false
    end
    return false
end

-- Quest log ------------------------------------------------------------------------------------
-- Returns { [questId] = { index=, title=, level=, complete=bool|nil, failed=bool, objectives={ {text=,done=,type=} } } }

function C.ScanQuestLog()
    local result = {}
    local num = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for i = 1, num do
        local title, level, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(i)
        if title and not isHeader then
            if not questId and C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
                questId = C_QuestLog.GetQuestIDForLogIndex(i)
            end
            if questId and questId > 0 then
                local entry = { index = i, title = title, level = level, objectives = {} }
                entry.complete = (isComplete == 1 or isComplete == true)
                entry.failed = (isComplete == -1)
                local nObj = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i) or 0
                for o = 1, nObj do
                    local text, objType, finished = GetQuestLogLeaderBoard(o, i)
                    entry.objectives[o] = { text = text, type = objType, done = finished and true or false }
                end
                -- Quests with zero objectives are "complete" as soon as they are in the log.
                if nObj == 0 and not entry.failed then entry.complete = true end
                result[questId] = entry
            end
        end
    end
    return result
end

-- Map / position -------------------------------------------------------------------------------

function C.GetPlayerMapPosition()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        note("C_Map.GetPlayerMapPosition")
        return nil
    end
    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapId, "player")
    if not pos then return mapId end
    local x, y = pos:GetXY()
    if not x or (x == 0 and y == 0) then return mapId end
    return mapId, x * 100, y * 100
end

-- Converts a zone-map position (0-100) into world coordinates (continent, wx, wy).
function C.MapToWorld(mapId, x, y)
    if not (mapId and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, mapId, CreateVector2D(x / 100, y / 100))
    if not ok or not pos then return nil end
    local wx, wy = pos:GetXY()
    return continent, wx, wy
end

function C.GetMapName(mapId)
    if mapId and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapId)
        if info then return info.name end
    end
end

function C.GetPlayerFacing()
    if GetPlayerFacing then return GetPlayerFacing() end
    note("GetPlayerFacing")
end

function C.GetZoneText()
    return GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText()) or ""
end

function C.GetBindLocation()
    return GetBindLocation and GetBindLocation() or nil
end

-- Talents --------------------------------------------------------------------------------------
-- The TBC talent API is player-class only. Signatures differ slightly across Classic builds, so
-- callers get normalised tables and never rely on positional quirks.

function C.GetNumTalentTabs()
    return GetNumTalentTabs and GetNumTalentTabs() or 0
end

function C.GetTalentTabName(tab)
    if not GetTalentTabInfo then return nil end
    local a, b = GetTalentTabInfo(tab)
    if type(a) == "number" then return b end -- (id, name, ...) signature
    return a                                 -- (name, icon, pointsSpent, ...) signature
end

function C.GetTalent(tab, index)
    if not GetTalentInfo then return nil end
    local name, icon, tier, column, rank, maxRank = GetTalentInfo(tab, index)
    if not name then return nil end
    return { name = name, icon = icon, tier = tier, column = column, rank = rank or 0, maxRank = maxRank or 0 }
end

function C.GetNumTalents(tab)
    return GetNumTalents and GetNumTalents(tab) or 0
end

function C.GetUnspentTalentPoints()
    if UnitCharacterPoints then return (UnitCharacterPoints("player")) or 0 end
    if GetUnspentTalentPoints then return GetUnspentTalentPoints() or 0 end
    note("UnitCharacterPoints")
    return 0
end

-- Bags / items / money -------------------------------------------------------------------------
-- 2.5.x Anniversary clients expose C_Container; older Classic builds only have the globals.
-- Both are supported (same split Questie uses for interface 20506).

C.NUM_BAGS = 4 -- backpack (0) + four bag slots (1-4). Bank and keyring are never touched.

function C.GetContainerNumSlots(bag)
    local f = has("C_Container.GetContainerNumSlots") or has("GetContainerNumSlots")
    if f then return f(bag) or 0 end
    note("GetContainerNumSlots")
    return 0
end

-- Returns a normalised record or nil for an empty slot:
-- { itemID=, count=, locked=bool, quality=, link=, noValue=bool, bound=bool|nil }
-- `bound` is this copy's binding state; nil when the client does not report it (legacy API).
function C.GetContainerItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local i = C_Container.GetContainerItemInfo(bag, slot)
        if not i then return nil end
        local bound
        if i.isBound ~= nil then bound = i.isBound and true or false end
        return { itemID = i.itemID, count = i.stackCount or 1, locked = i.isLocked and true or false,
                 quality = i.quality, link = i.hyperlink, noValue = i.hasNoValue and true or false, bound = bound }
    end
    if GetContainerItemInfo then
        local _, count, locked, quality, _, _, link, _, noValue, itemID = GetContainerItemInfo(bag, slot)
        if not link and not itemID then return nil end
        if not itemID and link then itemID = tonumber(string.match(link, "item:(%d+)")) end
        return { itemID = itemID, count = count or 1, locked = locked and true or false,
                 quality = quality, link = link, noValue = noValue and true or false }
    end
    note("GetContainerItemInfo")
    return nil
end

-- Selling is "use item while a merchant window is open". Not a protected action in Classic.
function C.UseContainerItem(bag, slot)
    local f = has("C_Container.UseContainerItem") or has("UseContainerItem")
    if f then f(bag, slot) return true end
    note("UseContainerItem")
    return false
end

-- Quest-item flag for a bag slot, where the client offers it (nil = unknown).
function C.ContainerItemIsQuestItem(bag, slot)
    local f = has("C_Container.GetContainerItemQuestInfo")
    if f then
        local ok, info = pcall(f, bag, slot)
        if ok and type(info) == "table" then return (info.isQuestItem or (info.questID and info.questID > 0)) and true or false end
        return nil
    end
    f = has("GetContainerItemQuestInfo")
    if f then
        local ok, isQuestItem, questId = pcall(f, bag, slot)
        if ok then return (isQuestItem or (questId and questId > 0)) and true or false end
    end
    return nil
end

-- { name=, quality=, sellPrice=, classID=, subclassID=, bindType= } or nil while the item is not cached.
function C.GetItemInfo(item)
    local f = has("C_Item.GetItemInfo") or has("GetItemInfo")
    if not f then note("GetItemInfo") return nil end
    local name, _, quality, _, _, _, _, _, _, _, sellPrice, classID, subclassID, bindType = f(item)
    if not name then return nil end
    return { name = name, quality = quality, sellPrice = sellPrice, classID = classID,
             subclassID = subclassID, bindType = bindType }
end

function C.GetMoney() return GetMoney and GetMoney() or 0 end

function C.CursorHasItem() return CursorHasItem and CursorHasItem() and true or false end

function C.FormatMoney(copper)
    copper = math.floor(copper or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return string.format("%dg %ds %dc", g, s, c) end
    if s > 0 then return string.format("%ds %dc", s, c) end
    return string.format("%dc", c)
end

-- Quest dialogs (gossip / greeting / detail / progress / reward) -------------------------------
-- Verified against Questie v12.3.1 (TOC 20506), which drives the same calls on this client:
-- C_GossipInfo.Get*/Select*Quest take and return quest IDs; GetQuestID() is valid on the
-- detail/progress/reward panels; GetNumQuestChoices()/GetQuestReward() are core APIs.

-- { {questID=, title=, isComplete=, repeatable=} } for the open gossip window.
local function gossipList(modern, legacy, stride, completeAt)
    local f = has(modern)
    if f then
        local ok, list = pcall(f)
        if ok and type(list) == "table" then return list end
        return {}
    end
    f = has(legacy)
    if not f then return {} end
    local raw, out = { f() }, {}
    for i = 1, #raw, stride do
        out[#out + 1] = { title = raw[i], questID = 0, isComplete = completeAt and raw[i + completeAt] and true or false,
                          index = #out + 1 }
    end
    return out
end

function C.GossipAvailableQuests() return gossipList("C_GossipInfo.GetAvailableQuests", "GetGossipAvailableQuests", 7) end
function C.GossipActiveQuests() return gossipList("C_GossipInfo.GetActiveQuests", "GetGossipActiveQuests", 6, 3) end

-- Select by quest ID on modern clients; legacy clients select by list position.
function C.GossipSelectAvailable(q)
    if C_GossipInfo and C_GossipInfo.SelectAvailableQuest and q.questID and q.questID > 0 then
        C_GossipInfo.SelectAvailableQuest(q.questID) return true
    end
    if SelectGossipAvailableQuest and q.index then SelectGossipAvailableQuest(q.index) return true end
    return false
end

function C.GossipSelectActive(q)
    if C_GossipInfo and C_GossipInfo.SelectActiveQuest and q.questID and q.questID > 0 then
        C_GossipInfo.SelectActiveQuest(q.questID) return true
    end
    if SelectGossipActiveQuest and q.index then SelectGossipActiveQuest(q.index) return true end
    return false
end

-- QUEST_GREETING lists (NPCs without a gossip menu). IDs are not always exposed; 0 = unknown.
function C.GreetingAvailableQuests()
    local out = {}
    local n = GetNumAvailableQuests and GetNumAvailableQuests() or 0
    for i = 1, n do
        local id = 0
        if GetAvailableQuestInfo then
            local ok, a5 = pcall(function() return select(5, GetAvailableQuestInfo(i)) end)
            if ok and type(a5) == "number" then id = a5 end
        end
        out[i] = { index = i, title = GetAvailableTitle and GetAvailableTitle(i), questID = id }
    end
    return out
end

function C.GreetingActiveQuests()
    local out = {}
    local n = GetNumActiveQuests and GetNumActiveQuests() or 0
    for i = 1, n do
        local title, isComplete
        if GetActiveTitle then title, isComplete = GetActiveTitle(i) end
        local id = 0
        if GetActiveQuestID then
            local ok, v = pcall(GetActiveQuestID, i)
            if ok and type(v) == "number" then id = v end
        end
        out[i] = { index = i, title = title, questID = id, isComplete = isComplete and true or false }
    end
    return out
end

function C.GreetingSelectAvailable(i) if SelectAvailableQuest then SelectAvailableQuest(i) return true end return false end
function C.GreetingSelectActive(i) if SelectActiveQuest then SelectActiveQuest(i) return true end return false end

-- Quest ID of the open detail/progress/reward panel (nil when unknown or closed).
function C.DialogQuestID()
    if not GetQuestID then note("GetQuestID") return nil end
    local id = GetQuestID()
    if id and id > 0 then return id end
    return nil
end

function C.DialogTitle() return GetTitleText and GetTitleText() or nil end

-- All text the offer panel shows; used for the escort keyword check.
function C.DialogText()
    local a = GetObjectiveText and GetObjectiveText() or ""
    local b = GetQuestText and GetQuestText() or ""
    return tostring(a) .. "\n" .. tostring(b)
end

-- True when the quest was offered by another player (party share), not by an NPC/object.
function C.DialogFromPlayer()
    if UnitIsPlayer and UnitExists and UnitExists("questnpc") then return UnitIsPlayer("questnpc") and true or false end
    return false
end

function C.QuestLogSize()
    local max = (C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept())
        or MAX_QUESTLOG_QUESTS or ns.Target.questLogMax or 25
    local count = 0
    if GetNumQuestLogEntries then
        local _, numQuests = GetNumQuestLogEntries()
        count = numQuests or (ns.Tracker and ns.Tracker:Count()) or 0
    end
    return count, max
end

function C.IsModifierHeld() return IsShiftKeyDown and IsShiftKeyDown() and true or false end

-- Abandons the quest at a quest log index (the default UI's own sequence). The quest id is
-- re-checked against that index first so a shifted log can never drop the wrong quest.
function C.AbandonQuestAt(index, questId)
    if not (SelectQuestLogEntry and SetAbandonQuest and AbandonQuest and GetQuestLogTitle) then
        note("AbandonQuest")
        return false
    end
    local title, _, _, isHeader, _, _, _, id = GetQuestLogTitle(index)
    if not id and C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then id = C_QuestLog.GetQuestIDForLogIndex(index) end
    if not title or isHeader or id ~= questId then return false end
    SelectQuestLogEntry(index)
    SetAbandonQuest()
    AbandonQuest()
    return true
end

-- Raid target icons -------------------------------------------------------------------------------
-- SetRaidTarget/GetRaidTargetIndex exist on 2.5.6 (warcraft.wiki.gg). Solo players and party
-- members may mark; in a raid only the leader and assistants. Retail 12.0 made SetRaidTarget
-- secure-only; if this client ever does the same, the call is blocked and Marker.lua falls back
-- to the click-driven marker bar (SecureActionButtonTemplate).

function C.GetRaidTargetIndex(unit)
    if not (GetRaidTargetIndex and UnitExists and UnitExists(unit)) then return nil end
    local i = GetRaidTargetIndex(unit)
    if i and i >= 1 and i <= 8 then return i end
    return nil
end

-- Sets (index 1-8) or clears (0) a unit's icon. Never toggles: SetRaidTarget removes an icon
-- the unit already has, so that case is skipped. Returns false if the call errored or is missing.
function C.SetRaidTarget(unit, index)
    if not SetRaidTarget then note("SetRaidTarget") return false end
    if index ~= 0 and C.GetRaidTargetIndex(unit) == index then return true end
    if index == 0 and not C.GetRaidTargetIndex(unit) then return true end
    local ok = pcall(SetRaidTarget, unit, index)
    return ok
end

-- NPC id from a creature GUID ("Creature-0-<server>-<instance>-<zone>-<npcId>-<spawn>"), or nil.
function C.UnitNpcId(unit)
    if not (UnitGUID and UnitExists and UnitExists(unit)) then return nil end
    local guid = UnitGUID(unit)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id), guid
end

-- Whether the player may set raid icons right now; false plus a reason if not.
function C.CanMark()
    local inRaid = (IsInRaid and IsInRaid()) or (GetNumRaidMembers and GetNumRaidMembers() > 0) or false
    if not inRaid then return true end
    local leader = (UnitIsGroupLeader and UnitIsGroupLeader("player")) or (IsRaidLeader and IsRaidLeader())
    local assist = (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) or (IsRaidOfficer and IsRaidOfficer())
    if leader or assist then return true end
    return false, "in a raid only the leader and assistants can set raid markers"
end

-- Unit tokens that can be marked without changing target: target, mouseover, focus, nameplates.
function C.MarkableUnits()
    local out = { "target", "mouseover", "focus" }
    for i = 1, 40 do
        local u = "nameplate" .. i
        if UnitExists and UnitExists(u) then out[#out + 1] = u end
    end
    return out
end

function C.InCombat() return InCombatLockdown and InCombatLockdown() and true or false end

-- UI -------------------------------------------------------------------------------------------

C.BackdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil

function C.SetSpellTooltip(tooltip, spellId)
    if tooltip.SetSpellByID then
        tooltip:SetSpellByID(spellId)
    else
        tooltip:SetHyperlink("spell:" .. spellId)
    end
end

-- Registers a canvas frame with the game's options UI (new Settings API or legacy).
function C.RegisterOptionsPanel(frame, title)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(frame, title)
        Settings.RegisterAddOnCategory(category)
        C.optionsCategory = category
        return
    end
    if InterfaceOptions_AddCategory then
        frame.name = title
        InterfaceOptions_AddCategory(frame)
        return
    end
    note("InterfaceOptions_AddCategory")
end

-- Child page under the add-on's options entry (call after RegisterOptionsPanel).
function C.RegisterOptionsSubPanel(frame, parentTitle, title)
    if C.optionsCategory and Settings and Settings.RegisterCanvasLayoutSubcategory then
        local sub = Settings.RegisterCanvasLayoutSubcategory(C.optionsCategory, frame, title)
        C.subCategories = C.subCategories or {}
        C.subCategories[frame] = sub
        return
    end
    if InterfaceOptions_AddCategory then
        frame.name = title
        frame.parent = parentTitle
        InterfaceOptions_AddCategory(frame)
        return
    end
    note("InterfaceOptions_AddCategory")
end

function C.OpenOptionsPanel(frame)
    local sub = C.subCategories and C.subCategories[frame]
    if sub and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(sub:GetID())
        return true
    end
    if C.optionsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(C.optionsCategory:GetID())
        return true
    end
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(frame)
        InterfaceOptionsFrame_OpenToCategory(frame) -- legacy client bug: first call may only open the frame
        return true
    end
    return false
end
