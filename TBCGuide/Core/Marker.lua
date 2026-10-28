-- TBCGuide - raid target icons: manual marking and guide-driven marking
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Uses the game's own raid target icons (SetRaidTarget). Guide steps may carry
-- mark = { i = <1-8>, npcs = { <npc ids> } } (compiled from [mark=...], docs/RAID_MARKERS.md).
-- Units are matched by NPC id from their GUID, never by name.
--
-- Safety rules (docs/RAID_MARKERS.md):
--  * only units the current step names are marked, and only when they are seen as the target,
--    mouseover, focus or a nameplate - nothing is scanned or targeted on its own;
--  * one attempt per unit per step; a unit is never marked again after the player (or anyone)
--    changes or removes its icon;
--  * an existing icon is not replaced unless markReplace is on;
--  * one live unit per step holds the icon, so it does not jump between mobs;
--  * success is reported only when GetRaidTargetIndex shows the icon afterwards;
--  * if the client blocks or rejects marking, automatic marking stops and says how to mark by click.

local _, ns = ...

local M = { rule = nil, marked = {}, handsOff = {}, tried = {}, current = nil, failures = 0, blocked = false }
ns.Marker = M

M.NAMES = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }
local VERIFY_DELAY = 0.4
local MAX_FAILURES = 2

local C -- ns.Compat
local function prof() return ns.db.profile end

function M.Icon(i, size)
    return string.format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:%d|t", i, size or 0)
end

function M.Label(i) return M.Icon(i) .. " " .. (M.NAMES[i] or "?") end

-- "skull", "Skull", "8" -> 8; nil if unknown.
function M.Parse(arg)
    if type(arg) ~= "string" then return nil end
    arg = string.lower(string.match(arg, "^%s*(%S*)") or "")
    local n = tonumber(arg)
    if n and n >= 1 and n <= 8 then return math.floor(n) end
    for i, name in ipairs(M.NAMES) do if name == arg then return i end end
    if arg == "x" then return 7 end
    return nil
end

local function say(msg) if prof().markNotify then ns:Print(msg) end end

-- Rule for a step: explicit guide mark, or (opt-in) the default icon on kill objectives.
function M:RuleFor(s)
    local p = prof()
    if not (s and p.markEnabled and p.autoMark) then return nil end
    local npcs, icon = {}, nil
    if type(s.mark) == "table" and s.mark.i and s.mark.npcs then
        icon = s.mark.i
        for _, id in ipairs(s.mark.npcs) do npcs[id] = true end
    elseif p.autoMarkObjectives and (s[1] == "complete" or s[1] == "grind") and s.q then
        local q = ns.DB.GetQuestByID(s.q)
        if q then
            for _, id in ipairs(q.objectives.creatures) do npcs[id] = true end
            for _, id in ipairs(q.objectives.killCredit) do npcs[id] = true end
        end
        icon = p.defaultMarker
    end
    if not icon or not next(npcs) then return nil end
    return { icon = icon, npcs = npcs, step = s }
end

function M:OnStep()
    local old = self.rule
    if old and prof().markClearOnAdvance then self:ClearOwn() end
    self.rule = self:RuleFor(ns.Engine:CurrentStep())
    self.marked, self.handsOff, self.tried, self.current, self.failures, self.stopped, self.toldWhy =
        {}, {}, {}, nil, 0, false, false
    if self.rule then
        for _, u in ipairs(C.MarkableUnits()) do self:Consider(u) end
    end
end

-- Finds a currently visible unit token for a GUID (target, mouseover, focus, nameplates).
function M:UnitFor(guid)
    for _, u in ipairs(C.MarkableUnits()) do
        if UnitGUID and UnitGUID(u) == guid then return u end
    end
end

function M:Explain(msg)
    if self.toldWhy then return end
    self.toldWhy = true
    say(msg)
end

-- Called for a unit the player is looking at; marks it if the current step names it.
function M:Consider(unit)
    local r = self.rule
    if not r or self.stopped or self.blocked then return end
    local id, guid = C.UnitNpcId(unit)
    if not id or not r.npcs[id] then return end
    if self.handsOff[guid] or self.tried[guid] then return end
    if UnitIsDead and UnitIsDead(unit) then return end
    local cur = C.GetRaidTargetIndex(unit)
    if cur == r.icon then
        self.marked[guid] = r.icon
        self.current = guid
        return
    end
    if cur and not prof().markReplace then
        self.handsOff[guid] = true -- someone else's icon; leave it
        return
    end
    -- Keep the icon on one living unit instead of moving it between mobs of the same kind.
    if self.current and self.current ~= guid then
        local u = self:UnitFor(self.current)
        if not u or not (UnitIsDead and UnitIsDead(u)) then return end
        self.current = nil
    end
    local can, why = C.CanMark()
    if not can then return self:Explain("Raid marker not set: " .. why .. ". Mark it yourself or ask the raid leader.") end
    self.tried[guid] = true
    local name = UnitName and UnitName(unit) or "target"
    if not C.SetRaidTarget(unit, r.icon) then return self:Failed(name, "the client refused the call") end
    C_Timer.After(VERIFY_DELAY, function() M:Verify(guid, r, name) end)
end

function M:Verify(guid, r, name)
    if self.rule ~= r then return end
    local u = self:UnitFor(guid)
    if not u then return end -- out of sight: result unknown, claim nothing
    if C.GetRaidTargetIndex(u) == r.icon then
        self.marked[guid] = r.icon
        self.current = guid
        say("Marked " .. tostring(name) .. " with " .. M.Label(r.icon) .. ".")
    else
        self:Failed(name, "the icon did not appear")
    end
end

function M:Failed(name, why)
    self.failures = self.failures + 1
    if self.failures >= MAX_FAILURES then
        self.stopped = true
        say("Could not mark " .. tostring(name) .. " (" .. why .. "). Automatic marking is paused for this step; use /tbcg mark or the marker bar (/tbcg markbar).")
    else
        say("Could not mark " .. tostring(name) .. " (" .. why .. ").")
    end
end

-- Any icon change: a unit we marked that now shows a different icon (or none) was changed by the
-- player, another addon or a group member. Leave it alone and stop automatic marking for the rest
-- of this step, so the player's choice is not undone on the next mob either.
function M:OnRaidTargetUpdate()
    for guid, icon in pairs(self.marked) do
        local u = self:UnitFor(guid)
        if u and C.GetRaidTargetIndex(u) ~= icon then
            self.marked[guid] = nil
            self.handsOff[guid] = true
            if self.current == guid then self.current = nil end
            self.stopped = true
            ns:Debug("raid marker changed by someone else; automatic marking paused for this step")
        end
    end
end

-- Removes icons this module placed in the current step, if they are still ours and visible.
function M:ClearOwn()
    for guid, icon in pairs(self.marked) do
        local u = self:UnitFor(guid)
        if u and C.GetRaidTargetIndex(u) == icon then C.SetRaidTarget(u, 0) end
    end
    self.marked = {}
end

function M:OnBlocked(addon, func)
    if addon ~= ns.name or not (type(func) == "string" and string.find(func, "RaidTarget")) then return end
    self.blocked = true
    ns:Print("This client only allows raid markers from a click. Automatic marking is off; use the marker bar (/tbcg markbar).")
end

-- Manual marking -----------------------------------------------------------------------------------

function M:MarkTarget(icon)
    if not prof().markEnabled then return ns:Print("Raid markers are turned off (/tbcg set markEnabled on).") end
    icon = icon or prof().defaultMarker
    if not (UnitExists and UnitExists("target")) then return ns:Print("You have no target to mark.") end
    local can, why = C.CanMark()
    if not can then return ns:Print("Cannot set a raid marker: " .. why .. ".") end
    local name = UnitName("target") or "target"
    if C.GetRaidTargetIndex("target") == icon then return ns:Print(name .. " already has " .. M.Label(icon) .. ".") end
    local guid = UnitGUID and UnitGUID("target")
    if not C.SetRaidTarget("target", icon) then
        return ns:Print("Could not mark " .. name .. ". Try the marker bar (/tbcg markbar).")
    end
    C_Timer.After(VERIFY_DELAY, function()
        local u = guid and M:UnitFor(guid)
        if u and C.GetRaidTargetIndex(u) == icon then
            if prof().markNotify then ns:Print("Marked " .. name .. " with " .. M.Label(icon) .. ".") end
        elseif u then
            ns:Print("Marking " .. name .. " did not take effect. Try the marker bar (/tbcg markbar).")
        end
    end)
end

function M:Unmark()
    if not (UnitExists and UnitExists("target")) then return ns:Print("You have no target.") end
    local cur = C.GetRaidTargetIndex("target")
    if not cur then return ns:Print("Your target has no raid marker.") end
    local can, why = C.CanMark()
    if not can then return ns:Print("Cannot clear the raid marker: " .. why .. ".") end
    local guid = UnitGUID and UnitGUID("target")
    if guid then self.handsOff[guid] = true end
    C.SetRaidTarget("target", 0)
    C_Timer.After(VERIFY_DELAY, function()
        local u = guid and M:UnitFor(guid)
        if u and not C.GetRaidTargetIndex(u) then
            if prof().markNotify then ns:Print("Raid marker removed.") end
        elseif u then
            ns:Print("The raid marker could not be removed.")
        end
    end)
end

function M:Init()
    C = ns.Compat
    ns:Listen("TBCG_STEP_CHANGED", function() M:OnStep() end)
    ns:Listen("TBCG_GUIDE_CHANGED", function() M:OnStep() end)
    ns:On("PLAYER_TARGET_CHANGED", function() M:Consider("target") end)
    ns:On("UPDATE_MOUSEOVER_UNIT", function() M:Consider("mouseover") end)
    ns:On("NAME_PLATE_UNIT_ADDED", function(_, unit) if unit then M:Consider(unit) end end)
    ns:On("RAID_TARGET_UPDATE", function() M:OnRaidTargetUpdate() end)
    ns:On("ADDON_ACTION_BLOCKED", function(_, addon, func) M:OnBlocked(addon, func) end)
    ns:On("ADDON_ACTION_FORBIDDEN", function(_, addon, func) M:OnBlocked(addon, func) end)
    self:OnStep()
end
