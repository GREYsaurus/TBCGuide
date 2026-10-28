-- TBCGuide - orphaned quests: quests in the log that the guide route will never finish
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- A quest is "orphaned" when it is in the quest log and no OPEN step of the active guide, and no
-- step of any later guide on this character's route (the @next chain), accepts, completes or
-- turns it in. Such quests take log space the route needs and are never handed in by the guide.
--
-- Nothing is ever abandoned automatically: the player sees the list (UI/OrphanFrame.lua), picks
-- quests, and confirms in a dialog. Class, profession and seasonal quests are listed but not
-- pre-selected. Abandoning goes one quest at a time and only counts quests the game removed.

local _, ns = ...

local Orphans = { queue = nil }
ns.Orphans = Orphans

local ABANDON_CONFIRM_DELAY = 0.6

-- Quest ids the route will still touch, from the active guide's open steps onward.
function Orphans:FutureQuests()
    local E = ns.Engine
    local g = E.guide
    if not g then return nil end
    local info = ns.Compat.PlayerInfo()
    local future = {}
    for i, s in ipairs(g.steps) do
        local st = E.status[i]
        if s.q and (st == "active" or st == "pending") then future[s.q] = true end
    end
    local seen = { [g.id] = true }
    local nextG = ns.Guides:NextFor(g, info)
    while nextG and not seen[nextG.id] do
        seen[nextG.id] = true
        for _, s in ipairs(nextG.steps) do
            if s.q and ns.Guides:StepApplies(s, info) then future[s.q] = true end
        end
        nextG = ns.Guides:NextFor(nextG, info)
    end
    return future
end

-- Quests that are usually kept on purpose even off-route (class, profession, seasonal).
function Orphans:IsSpecial(questId)
    local q = ns.DB.GetQuestByID(questId)
    if not q then return false end
    if q.classes and q.classes ~= 0 then return true, "class quest" end
    local zone = ns.QDB.quests[questId] and ns.QDB.quests[questId][ns.QDB.QUEST.ZONE]
    if zone and zone < 0 then return true, "profession/class/seasonal quest" end
    return false
end

-- Returns a sorted list of { id=, title=, level=, complete=, special=, why= } or nil, reason.
function Orphans:Find()
    local future = self:FutureQuests()
    if not future then return nil, "no guide is loaded" end
    local out = {}
    for q, e in pairs(ns.Tracker.log) do
        if not future[q] then
            local special, why = self:IsSpecial(q)
            out[#out + 1] = { id = q, title = e.title or ns.DB.GetQuestName(q) or ("quest " .. q), level = e.level or 0,
                              complete = e.complete and true or false, special = special, why = why }
        end
    end
    table.sort(out, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.title < b.title
    end)
    return out
end

-- Abandon -----------------------------------------------------------------------------------------

-- Starts abandoning the given quest ids (already confirmed by the player in a dialog).
function Orphans:Abandon(ids)
    if self.queue then return ns:Print("Already abandoning quests; please wait.") end
    self.queue = { ids = ids, pos = 1, done = {}, failed = {} }
    self:Next()
end

function Orphans:Next()
    local job = self.queue
    if not job then return end
    local q = job.ids[job.pos]
    if not q then return self:Finish() end
    job.pos = job.pos + 1
    ns.Tracker:Scan() -- log indices move after every removal
    local e = ns.Tracker.log[q]
    if not e then return self:Next() end -- already gone (turned in or abandoned by hand)
    if not ns.Compat.AbandonQuestAt(e.index, q) then
        job.failed[#job.failed + 1] = e.title
        return self:Next()
    end
    C_Timer.After(ABANDON_CONFIRM_DELAY, function()
        ns.Tracker:Scan()
        if ns.Tracker.log[q] then job.failed[#job.failed + 1] = e.title else job.done[#job.done + 1] = e.title end
        Orphans:Next()
    end)
end

function Orphans:Finish()
    local job = self.queue
    self.queue = nil
    if #job.done > 0 then ns:Print("Abandoned " .. #job.done .. " orphaned quest(s): " .. table.concat(job.done, ", ")) end
    if #job.failed > 0 then ns:Print("|cffff7744Could not abandon:|r " .. table.concat(job.failed, ", ")) end
    ns:Fire("TBCG_ORPHANS_CHANGED")
end
