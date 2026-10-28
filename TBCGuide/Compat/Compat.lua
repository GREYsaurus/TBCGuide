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

function C.OpenOptionsPanel(frame)
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
