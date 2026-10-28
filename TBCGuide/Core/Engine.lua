-- TBCGuide - guide progression engine
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Step states: "done", "skipped", "active", "pending", "na" (not for this character).
-- Completion rules per step type are in COMPLETERS below. Rules only use reliable signals
-- (quest flags, quest log, level, bind location, explicit UI messages). Anything else waits for
-- the player to click the step (manual confirmation) - the engine never guesses.

local _, ns = ...

local Engine = { guide = nil, current = nil, status = {}, autoReason = {} }
ns.Engine = Engine

local T -- tracker, set in Init

local function info() return ns.Compat.PlayerInfo() end

-- Returns true when the step's completion signal is present.
local COMPLETERS = {
    accept = function(s) return T:InLog(s.q) or T:IsTurnedIn(s.q) end,
    turnin = function(s) return T:IsTurnedIn(s.q) end,
    complete = function(s)
        if T:IsTurnedIn(s.q) then return true end
        if s.obj then return T:ObjectiveDone(s.q, s.obj) end
        return T:IsComplete(s.q)
    end,
    level = function(s) return (UnitLevel("player") or 1) >= (s.level or 1) end,
    bind = function(s)
        local loc = ns.Compat.GetBindLocation()
        return s.place and loc and string.lower(loc) == string.lower(s.place) or false
    end,
}
-- A grind step ends exactly like a level step: when the player reaches s.level. (UnitXP only
-- counts XP into the current level, so an XP threshold would misfire after a level-up.)
COMPLETERS.grind = COMPLETERS.level

-- Steps whose completion is remembered once observed (cannot be re-derived later).
local STICKY = { ["goto"] = true, note = true, train = true, fp = true, fly = true, hs = true, travel = true,
                 talk = true, buy = true, use = true, collect = true, bind = true, level = true, grind = true }

function Engine:Init()
    T = ns.Tracker
    ns:Listen("TBCG_QUESTS_CHANGED", function() Engine:Refresh() end)
    ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(0.5, function() Engine:Refresh() end) end)
    ns:On("ZONE_CHANGED_NEW_AREA", function() Engine:OnZoneChanged() end)
    ns:On("ZONE_CHANGED", function() Engine:OnZoneChanged() end)
    ns:On("PLAYER_CONTROL_GAINED", function() Engine:OnZoneChanged() end) -- landing after a flight
    ns:On("UI_INFO_MESSAGE", function(_, a, b) Engine:OnInfoMessage(type(b) == "string" and b or a) end)
    ns:On("TAXIMAP_OPENED", function() Engine:CompleteCurrentOfType("fp") end)
    ns:On("TRAINER_CLOSED", function() Engine:CompleteCurrentOfType("train") end)
    ns:On("CONFIRM_BINDER", function() C_Timer.After(1, function() Engine:Refresh() end) end)
    ns:On("HEARTHSTONE_BOUND", function() Engine:Refresh() end)
    ns:On("MERCHANT_CLOSED", function() Engine:CompleteCurrentOfType("buy") end)
end

function Engine:Load(guideId, opts)
    local g = ns.Guides:Get(guideId)
    if not g then
        ns:Print("Unknown guide: " .. tostring(guideId))
        return false
    end
    self.guide = g
    self.forced = nil
    self.current = nil
    self.status = {}
    self.autoReason = {}
    ns.char.activeGuide = g.id
    local hist = ns.char.history
    for i = #hist, 1, -1 do if hist[i] == g.id then table.remove(hist, i) end end
    table.insert(hist, 1, g.id)
    while #hist > 15 do table.remove(hist) end
    if opts and opts.reset then ns:ResetProgress(g.id) end
    self.progress = ns:GetProgress(g.id)
    self:Refresh(true)
    ns:Fire("TBCG_GUIDE_CHANGED", g)
    return true
end

-- Whether a quest step should be skipped automatically for this character, and why.
function Engine:AutoSkipReason(s, ctx)
    if not s.q then return nil end
    if s[1] == "accept" then
        if T:IsTurnedIn(s.q) then return nil end -- counts as done, not skipped
        local ok, why = ns.DB.IsQuestAvailable(s.q, ctx)
        if not ok and (why == "race" or why == "class" or why == "exclusive" or why == "too high level") then
            return "not available (" .. why .. ")"
        end
    elseif s[1] == "turnin" or s[1] == "complete" then
        if not T:InLog(s.q) and not T:IsTurnedIn(s.q) then
            -- The player never picked it up (or abandoned it). If the matching accept step was
            -- skipped / not applicable, skip this too rather than blocking the route.
            local acc = self.acceptIndex and self.acceptIndex[s.q]
            if acc then
                local st = self.status[acc]
                if st == "skipped" or st == "na" then return "quest was skipped" end
            elseif not self.acceptIndex or not self.acceptIndex[s.q] then
                -- Accepted in an earlier guide: only block if the DB says the player could have it.
                local ok, why = ns.DB.IsQuestAvailable(s.q, ctx)
                if not ok and (why == "race" or why == "class") then return "not available (" .. why .. ")" end
                -- Optional pick-ups from an earlier guide (breadcrumbs): if the quest log has been
                -- read and the quest is not there, the player never took it. Re-evaluated on every
                -- refresh, never saved, so a late quest log scan cannot skip it for good.
                if s.optional and T.lastScan > 0 then return "not in your quest log" end
            end
        end
    end
    return nil
end

function Engine:Refresh(silent)
    local g = self.guide
    if not g then return end
    local p = self.progress
    local ctx = T:Context()
    local prof = ns.db.profile
    self.acceptIndex = {}
    for i, s in ipairs(g.steps) do
        if s[1] == "accept" and s.q then self.acceptIndex[s.q] = i end
    end

    local firstOpen
    for i, s in ipairs(g.steps) do
        local st
        if not ns.Guides:StepApplies(s, ctx) then
            st = "na"
        elseif (s.dungeon and not prof.showDungeonSteps) or (s.elite and not prof.showElite)
            or (s.optional and prof.speedRoute) then
            st = "na"
        elseif p.skipped[i] then
            st = "skipped"
        elseif p.done[i] then
            st = "done"
        else
            local fn = COMPLETERS[s[1]]
            if fn and fn(s) then
                st = "done"
                if STICKY[s[1]] then p.done[i] = true end
            else
                local why = self:AutoSkipReason(s, ctx)
                if why then
                    st = "skipped"
                    self.autoReason[i] = why
                else
                    st = "pending"
                end
            end
        end
        self.status[i] = st
        if st == "pending" and not firstOpen then firstOpen = i end
    end

    if self.forced and (not firstOpen or self.forced < firstOpen) then
        firstOpen = self.forced
        if self.status[firstOpen] ~= "pending" then self.status[firstOpen] = "pending" end
    else
        self.forced = nil
    end
    local old = self.current
    self.current = firstOpen
    if firstOpen then
        self.status[firstOpen] = "active"
        p.step = firstOpen
    end
    if not firstOpen then
        p.step = #g.steps + 1
        if old and not silent then self:OnGuideFinished() end
    end
    if old ~= self.current then ns:Fire("TBCG_STEP_CHANGED", self.current, old) end
    ns:Fire("TBCG_REFRESH")
end

function Engine:OnGuideFinished()
    local g = self.guide
    local nextG = ns.Selector:NextAfter(g, info())
    if nextG then
        ns:Print("Guide complete: " .. g.name .. ". Next: " .. nextG.name)
        if ns.db.profile.autoAdvance then
            C_Timer.After(1, function() Engine:Load(nextG.id) end)
        end
    else
        ns:Print("Guide complete: " .. g.name .. ". Open /tbcg guide to choose the next guide.")
    end
end

-- Manual controls -------------------------------------------------------------------------------

function Engine:MarkDone(i)
    if not self.guide then return end
    i = i or self.current
    if not i then return end
    self.forced = nil
    self.progress.done[i] = true
    self.progress.skipped[i] = nil
    self:Refresh()
end

function Engine:Skip(i)
    if not self.guide then return end
    i = i or self.current
    if not i then return end
    self.forced = nil
    self.progress.skipped[i] = true
    self:Refresh()
end

-- /tbcg next: complete (manual) the current step.
function Engine:Next() self:MarkDone() end

-- /tbcg prev: reopen the most recent done/skipped step before the current one.
function Engine:Prev()
    if not self.guide then return end
    local from = (self.current or (#self.guide.steps + 1)) - 1
    for i = from, 1, -1 do
        local st = self.status[i]
        if st == "done" or st == "skipped" then
            self.progress.done[i] = nil
            self.progress.skipped[i] = nil
            self.autoReason[i] = nil
            -- Quest-derived completions cannot be undone, so the step is shown as current until
            -- the player advances again (Refresh honours self.forced).
            self.forced = i
            self:Refresh()
            return
        end
    end
end

function Engine:Reset()
    if not self.guide then return end
    ns:ResetProgress(self.guide.id)
    self.progress = ns:GetProgress(self.guide.id)
    self.autoReason = {}
    self:Refresh(true)
    ns:Print("Progress reset for " .. self.guide.name)
end

function Engine:CompleteCurrentOfType(kind)
    local s = self:CurrentStep()
    if s and s[1] == kind then self:MarkDone(self.current) end
end

function Engine:CurrentStep()
    return self.guide and self.current and self.guide.steps[self.current]
end

-- Zone-based completion for travel steps (fly/hs/travel/goto-zone).
function Engine:OnZoneChanged()
    local s = self:CurrentStep()
    if not s then return end
    if (s[1] == "fly" or s[1] == "hs" or s[1] == "travel") and s.dest then
        local zone = string.lower(ns.Compat.GetZoneText() or "")
        local sub = string.lower(GetSubZoneText and GetSubZoneText() or "")
        local dest = string.lower(s.dest)
        if zone == dest or sub == dest then self:MarkDone(self.current) end
    end
end

local NEW_FP = ERR_NEWTAXIPATH or "New flight path discovered!"
function Engine:OnInfoMessage(msg)
    if msg == NEW_FP then self:CompleteCurrentOfType("fp") end
end

-- Progress summary for the UI.
function Engine:Counts()
    local done, total = 0, 0
    if not self.guide then return 0, 0 end
    for i = 1, #self.guide.steps do
        local st = self.status[i]
        if st ~= "na" then
            total = total + 1
            if st == "done" or st == "skipped" then done = done + 1 end
        end
    end
    return done, total
end

-- Next N open steps starting at the current one (for display).
function Engine:Upcoming(n)
    local out = {}
    if not self.guide or not self.current then return out end
    for i = self.current, #self.guide.steps do
        local st = self.status[i]
        if st == "active" or st == "pending" then
            out[#out + 1] = i
            if #out >= n then break end
        end
    end
    return out
end
