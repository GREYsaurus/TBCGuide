-- TBCGuide - live quest log tracking
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- The bundled database says what quests EXIST; this module says what the character actually
-- HAS (quest log) and HAS DONE (completion flags + turn-ins seen this session).

local _, ns = ...

local Tracker = { log = {}, turnedIn = {}, lastScan = 0 }
ns.Tracker = Tracker

function Tracker:Scan()
    local ok, result = pcall(ns.Compat.ScanQuestLog)
    if ok and result then
        self.log = result
    else
        ns:Error("quest log scan failed: " .. tostring(result))
    end
    self.lastScan = GetTime()
    ns:Fire("TBCG_QUESTS_CHANGED")
end

function Tracker:InLog(questId)
    return questId and self.log[questId] ~= nil
end

function Tracker:IsComplete(questId)
    local e = questId and self.log[questId]
    return e and e.complete or false
end

function Tracker:ObjectiveDone(questId, objIndex)
    local e = questId and self.log[questId]
    if not e then return false end
    local o = e.objectives[objIndex]
    return o and o.done or false
end

function Tracker:IsTurnedIn(questId)
    if not questId then return false end
    if self.turnedIn[questId] then return true end
    return ns.Compat.IsQuestCompleted(questId)
end

function Tracker:GetEntry(questId) return questId and self.log[questId] end

function Tracker:Count()
    local n = 0
    for _ in pairs(self.log) do n = n + 1 end
    return n
end

-- Context used by DB.IsQuestAvailable
function Tracker:Context()
    local info = ns.Compat.PlayerInfo()
    info.isCompleted = function(id) return Tracker:IsTurnedIn(id) end
    info.inLog = function(id) return Tracker:InLog(id) end
    return info
end

local function rescan() Tracker:Scan() end

function Tracker:Init()
    ns:On("QUEST_LOG_UPDATE", function() ns:Throttle("questscan", 0.3, rescan) end)
    ns:On("UNIT_QUEST_LOG_CHANGED", function(_, unit)
        if unit == "player" then ns:Throttle("questscan", 0.3, rescan) end
    end)
    ns:On("QUEST_ACCEPTED", function(_, a, b)
        -- Classic: (questLogIndex, questId); some builds: (questId)
        local questId = b or a
        ns:Debug("accepted " .. tostring(questId))
        ns:Throttle("questscan", 0.1, rescan)
    end)
    ns:On("QUEST_TURNED_IN", function(_, questId)
        if questId then Tracker.turnedIn[questId] = true end
        ns:Debug("turned in " .. tostring(questId))
        ns:Throttle("questscan", 0.1, rescan)
    end)
    ns:On("QUEST_REMOVED", function() ns:Throttle("questscan", 0.2, rescan) end)
    self:Scan()
end
