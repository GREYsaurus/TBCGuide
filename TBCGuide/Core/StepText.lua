-- TBCGuide - human-readable step text and navigation targets
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

local StepText = {}
ns.StepText = StepText

local QUEST = "|cffffd100%s|r"
local NPC = "|cff66ccff%s|r"
local DIM = "|cff999999%s|r"
local WARN = "|cffff7744%s|r"

local function questName(s)
    return (s.q and ns.DB.GetQuestName(s.q)) or s.title or ("quest " .. tostring(s.q))
end

local function fmtCoords(s)
    if s.x and s.y then
        local zn = s.z and ns.DB.ZoneName(s.z)
        return string.format("%.1f, %.1f%s", s.x, s.y, zn and (" " .. zn) or "")
    end
    return nil
end

-- Main line of a step.
function StepText:Title(s)
    local k = s[1]
    if k == "accept" then
        local who = s.npc and (" from " .. string.format(NPC, s.npc)) or ""
        return "Accept " .. string.format(QUEST, questName(s)) .. who
    elseif k == "turnin" then
        local who = s.npc and (" to " .. string.format(NPC, s.npc)) or ""
        return "Turn in " .. string.format(QUEST, questName(s)) .. who
    elseif k == "complete" then
        return "Complete " .. string.format(QUEST, questName(s))
    elseif k == "goto" then
        return s.text or ("Go to " .. (fmtCoords(s) or "the marked location"))
    elseif k == "train" then
        return "Train new skills" .. (s.npc and (" at " .. string.format(NPC, s.npc)) or " at your class trainer")
    elseif k == "fp" then
        return "Get the flight path" .. (s.place and (" at " .. s.place) or "") .. (s.npc and (" (" .. string.format(NPC, s.npc) .. ")") or "")
    elseif k == "fly" then
        return "Fly to " .. (s.dest or "?")
    elseif k == "hs" then
        return "Use your Hearthstone" .. (s.dest and (" to " .. s.dest) or "")
    elseif k == "bind" then
        return "Set your Hearthstone at " .. (s.place or "the inn") .. (s.npc and (" (" .. string.format(NPC, s.npc) .. ")") or "")
    elseif k == "level" then
        return "Reach level " .. tostring(s.level)
    elseif k == "talk" then
        return "Talk to " .. string.format(NPC, s.npc or "?")
    elseif k == "guide" then
        local g = ns.Guides:Get(s.guide)
        return "Continue with: " .. (g and g.name or tostring(s.guide))
    end
    return s.text or k
end

-- Detail lines (objectives, notes, warnings) under the title.
function StepText:Details(s)
    local lines = {}
    if s[1] == "complete" and s.q then
        local e = ns.Tracker:GetEntry(s.q)
        if e and #e.objectives > 0 then
            for i, o in ipairs(e.objectives) do
                if not s.obj or s.obj == i then
                    lines[#lines + 1] = (o.done and "|cff55ff55- " or "|cffffffff- ") .. (o.text or "?") .. "|r"
                end
            end
        else
            local _, text = ns.DB.GetQuestObjectives(s.q)
            if text and text ~= "" then lines[#lines + 1] = string.format(DIM, text) end
            if not e and not ns.Tracker:IsTurnedIn(s.q) then
                lines[#lines + 1] = string.format(WARN, "Quest is not in your log.")
            end
        end
    elseif s[1] == "turnin" and s.q and not ns.Tracker:InLog(s.q) and not ns.Tracker:IsTurnedIn(s.q) then
        lines[#lines + 1] = string.format(WARN, "Quest is not in your log - skip this step if you did not take it.")
    elseif s[1] == "level" then
        local xp, maxXp = UnitXP("player"), UnitXPMax("player")
        if maxXp and maxXp > 0 then
            lines[#lines + 1] = string.format(DIM, string.format("Level %d, %d%% through", UnitLevel("player"), math.floor(xp / maxXp * 100)))
        end
    end
    if s.text and s[1] ~= "goto" and s[1] ~= "note" and s[1] ~= "travel" then
        lines[#lines + 1] = s.text
    end
    local tags = {}
    if s.elite then tags[#tags + 1] = "Elite" end
    if s.group then tags[#tags + 1] = "Group quest" .. (type(s.group) == "number" and (" (" .. s.group .. ")") or "") end
    if s.dungeon then tags[#tags + 1] = "Dungeon: " .. tostring(s.dungeon) end
    if s.optional then tags[#tags + 1] = "Optional" end
    if s.v == 0 then tags[#tags + 1] = "unverified" end
    if #tags > 0 then lines[#lines + 1] = string.format(WARN, table.concat(tags, " - ")) end
    local c = fmtCoords(s)
    if c and s[1] ~= "goto" then lines[#lines + 1] = string.format(DIM, c) end
    return lines
end

-- Navigation target for a step: zoneAreaId, x, y, label. Uses compiled coordinates first and
-- falls back to live database lookups for quest steps.
function StepText:Target(s)
    if s.x and s.y and s.z then return s.z, s.x, s.y, s.npc or s.text end
    if not s.q then return nil end
    if s[1] == "accept" then
        local npcs = ns.DB.GetQuestStartNPCs(s.q)
        if npcs[1] then
            local z, x, y = ns.DB.GetNPCPosition(npcs[1])
            if z then return z, x, y, ns.DB.GetNPCName(npcs[1]) end
        end
    elseif s[1] == "turnin" then
        local npcs, objs = ns.DB.GetQuestEndNPCs(s.q)
        if npcs[1] then
            local z, x, y = ns.DB.GetNPCPosition(npcs[1])
            if z then return z, x, y, ns.DB.GetNPCName(npcs[1]) end
        end
        if objs[1] then
            local z, x, y = ns.DB.GetObjectPosition(objs[1])
            if z then return z, x, y, ns.DB.GetObjectName(objs[1]) end
        end
    elseif s[1] == "complete" then
        local px, py
        local mapId, mx, my = ns.Compat.GetPlayerMapPosition()
        local area = mapId and ns.DB.AreaForUiMap(mapId)
        if mx then px, py = mx, my end
        local z, x, y, label = ns.DB.GetObjectiveLocation(s.q, area, px, py)
        if z then return z, x, y, label end
    end
end
