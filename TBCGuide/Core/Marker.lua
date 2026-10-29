-- TBCGuide - raid target icons: manual marking and guide-driven marking
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Uses the game's own raid target icons (SetRaidTarget). Guide steps may carry
-- mark = { i = <1-8>, npcs = { <npc ids> } } (compiled from [mark=...], docs/RAID_MARKERS.md);
-- kill objectives of `complete` steps are marked too when autoMarkObjectives is on (default).
-- Units are matched by NPC id from their GUID, never by name.
--
-- Safety rules (docs/RAID_MARKERS.md):
--  * only units the current step names are marked, and only when they are seen as the target,
--    mouseover, focus or a nameplate - nothing is scanned or targeted on its own;
--  * one attempt per unit per step; a unit is never marked again after the player (or anyone)
--    changes or removes its icon;
--  * an existing icon is not replaced unless markReplace is on;
--  * one live unit per icon holds it, so it does not jump between mobs; a unit that dies (seen via
--    UNIT_DIED, since the game removes the icon without RAID_TARGET_UPDATE) frees it for the next;
--  * success is reported only when GetRaidTargetIndex shows the icon afterwards;
--  * if the client blocks or rejects marking, automatic marking stops and says how to mark by click.

local _, ns = ...

local M = { rule = nil, marked = {}, markedNpc = {}, handsOff = {}, tried = {}, holder = {}, lastSeen = {}, failures = 0, blocked = false }
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

-- Rules ----------------------------------------------------------------------------------------------
-- The rule covers the current step plus the following open `complete` steps (guides list kill
-- objectives that are done together one after another). Each step contributes one icon:
--   * an explicit [mark=...] keeps its own icon;
--   * otherwise (autoMarkObjectives) its quest's kill objectives, kill-credit NPCs and the droppers
--     of its quest items (only when at most 3 NPCs drop the item, like the guide compiler) get the
--     next free icon in the order: default marker, skull, cross, square, moon, triangle, diamond,
--     circle, star. At most MAX_TYPES icons are handed out, so mob types never share or fight
--     over one icon. An NPC id named by two steps keeps the first step's icon.
local MAX_TYPES = 4
local ICON_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 }
local BLOCK_SCAN = 8
M.MAX_TYPES = MAX_TYPES

local function objectiveNpcs(s)
    local q = s.q and ns.DB.GetQuestByID(s.q)
    if not q then return nil end
    local npcs = {}
    for _, id in ipairs(q.objectives.creatures) do npcs[id] = true end
    for _, id in ipairs(q.objectives.killCredit) do npcs[id] = true end
    for _, itemId in ipairs(q.objectives.items) do
        local it = ns.DB.GetItemByID(itemId)
        if it and #it.npcDrops >= 1 and #it.npcDrops <= 3 then
            for _, id in ipairs(it.npcDrops) do npcs[id] = true end
        end
    end
    return next(npcs) and npcs or nil
end

-- Builds the rule for the active guide position, or nil plus the reason there is none.
function M:BuildRule()
    local p = prof()
    if not p.markEnabled then return nil, "raid markers are turned off (markEnabled)" end
    if not p.autoMark then return nil, "guide marking is turned off (autoMark)" end
    local E = ns.Engine
    local g, cur = E.guide, E.current
    if not (g and cur) then return nil, "no active guide step" end
    local parts = {}
    for i = cur, math.min(#g.steps, cur + BLOCK_SCAN) do
        local s, st = g.steps[i], E.status[i]
        local open = (i == cur) or st == "pending" or st == "active"
        if i > cur and open and s[1] ~= "complete" then break end
        if open then
            if type(s.mark) == "table" and s.mark.i and s.mark.npcs then
                local npcs = {}
                for _, id in ipairs(s.mark.npcs) do npcs[id] = true end
                parts[#parts + 1] = { icon = s.mark.i, npcs = npcs, step = i }
            elseif p.autoMarkObjectives and s[1] == "complete" then
                local npcs = objectiveNpcs(s)
                if npcs then parts[#parts + 1] = { npcs = npcs, step = i } end
            end
        end
    end
    if #parts == 0 then
        return nil, p.autoMarkObjectives and "this step names no NPC to mark"
            or "this step has no [mark] and objective marking is off (autoMarkObjectives)"
    end
    local used, order = {}, {}
    for _, part in ipairs(parts) do if part.icon then used[part.icon] = true end end
    -- A mob type keeps the icon it had under the previous rule (while that icon is free), so
    -- finishing one kill step does not move the other steps' icons around.
    local prev = self.rule and self.rule.types
    if prev then
        for _, part in ipairs(parts) do
            if not part.icon then
                for id in pairs(part.npcs) do
                    local old = prev[id]
                    if old and not used[old] then part.icon, used[old] = old, true break end
                end
            end
        end
    end
    local candidates = { p.defaultMarker }
    for _, i in ipairs(ICON_ORDER) do candidates[#candidates + 1] = i end
    for _, i in ipairs(candidates) do
        if not used[i] then used[i] = true order[#order + 1] = i end
    end
    local types, icons, n, nextIcon = {}, {}, 0, 1
    for _, part in ipairs(parts) do
        local icon = part.icon
        if not icon and n < MAX_TYPES and order[nextIcon] then
            icon = order[nextIcon]
            nextIcon = nextIcon + 1
        end
        if icon and (icons[icon] or n < MAX_TYPES) then
            local added = false
            for id in pairs(part.npcs) do
                if not types[id] then types[id] = icon added = true end
            end
            if added and not icons[icon] then icons[icon] = true n = n + 1 end
        end
    end
    if not next(types) then return nil, "this step names no NPC to mark" end
    local keys = {}
    for id, icon in pairs(types) do keys[#keys + 1] = id .. "=" .. icon end
    table.sort(keys)
    return { types = types, icons = icons, sig = table.concat(keys, ","), step = cur }
end

local function resetState(self)
    self.marked, self.markedNpc, self.handsOff, self.tried, self.holder, self.lastSeen =
        {}, {}, {}, {}, {}, {}
    self.failures, self.stopped, self.toldWhy = 0, false, false
end

-- Diagnostics: the last decision, shown by /tbcg debug marks. Outcomes (attempts, refusals,
-- successes) also go to the debug log; per-unit "not a match" decisions are recorded silently.
function M:Note(reason, unitName, outcome)
    self.last = { reason = reason, name = unitName, at = GetTime and GetTime() or 0 }
    if outcome then ns:Debug("marker: " .. reason .. (unitName and (" (" .. tostring(unitName) .. ")") or "")) end
end

-- Our icons that the new rule no longer wants are forgotten, and removed from the unit when
-- markClearOnAdvance is on. Icons the new rule still wants (same NPC, same icon) stay put, so a
-- mob that belongs to the next step too is not cleared and re-marked.
function M:DropStale(rule)
    for guid, icon in pairs(self.marked) do
        local id = self.markedNpc[guid]
        if not (rule and rule.types[id] == icon) then
            if prof().markClearOnAdvance then
                local u = self:UnitFor(guid)
                if u and C.GetRaidTargetIndex(u) == icon then C.SetRaidTarget(u, 0) end
            end
            self:Release(guid)
        end
    end
end

-- The active step changed (or a different guide was loaded): new rule, fresh state except for
-- icons that are still valid.
function M:OnStep()
    local rule, why = self:BuildRule()
    self:DropStale(rule)
    local marked, markedNpc, holder, seen = self.marked, self.markedNpc, self.holder, self.lastSeen
    self.gen = (self.gen or 0) + 1
    resetState(self)
    self.marked, self.markedNpc, self.holder = marked, markedNpc, holder
    for guid in pairs(marked) do self.lastSeen[guid] = seen[guid] end
    self.rule, self.noRuleWhy = rule, why
    if rule then
        for _, u in ipairs(C.MarkableUnits()) do self:Consider(u) end
    end
end

-- Steps after the current one finished (or settings changed): refresh the rule but keep the
-- per-step state, so units already tried or left alone stay that way.
function M:OnRefresh()
    if not self.gen then return end
    local rule, why = self:BuildRule()
    local oldSig = self.rule and self.rule.sig
    if (rule and rule.sig) == oldSig then return end
    self:DropStale(rule)
    self.rule, self.noRuleWhy = rule, why
    if rule then
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

-- Whether the unit currently holding `icon` for this step should keep it: it must be visible,
-- alive and still wear the icon. A unit out of sight keeps it unless it was seen dying (the game
-- removes a dead unit's icon without firing RAID_TARGET_UPDATE) or has not been seen for a while.
local HOLDER_TIMEOUT = 60
function M:HolderKeeps(icon, exceptGuid)
    local h = self.holder[icon]
    if not h or h == exceptGuid then return false end
    local u = self:UnitFor(h)
    if u then
        if UnitIsDead and UnitIsDead(u) then return false end
        return C.GetRaidTargetIndex(u) == icon
    end
    local seen = self.lastSeen[h]
    return seen ~= nil and (GetTime() - seen) < HOLDER_TIMEOUT
end

function M:Release(guid)
    local icon = self.marked[guid]
    self.marked[guid], self.markedNpc[guid] = nil, nil
    if icon and self.holder[icon] == guid then self.holder[icon] = nil end
end

-- Called for a unit the player is looking at; marks it if the current guide position names it.
function M:Consider(unit)
    local r = self.rule
    if not r then return end
    local id, guid = C.UnitNpcId(unit)
    if not id then return end
    local icon = r.types[id]
    local name = UnitName and UnitName(unit) or "target"
    if not icon then return self:Note("not an NPC of the current step", name) end
    self.lastSeen[guid] = GetTime()
    if self.blocked then return self:Note("blocked by the client", name) end
    if self.stopped then return self:Note("paused for this step", name) end
    if self.handsOff[guid] then return self:Note("left alone (someone else's icon, or changed by hand)", name) end
    if UnitIsDead and UnitIsDead(unit) then return self:Note("dead", name) end
    local cur = C.GetRaidTargetIndex(unit)
    if cur == icon then
        self.marked[guid], self.markedNpc[guid], self.holder[icon] = icon, id, guid
        return self:Note("already has the icon", name)
    end
    if cur and not prof().markReplace then
        self.handsOff[guid] = true -- someone else's icon; leave it
        return self:Note("already has another raid icon", name, true)
    end
    if self.tried[guid] then return self:Note("already tried this unit", name) end
    -- Keep each icon on one living unit instead of moving it between mobs of the same kind.
    if self:HolderKeeps(icon, guid) then return self:Note("icon is on another living mob of this step", name) end
    if self.holder[icon] then self:Release(self.holder[icon]) end
    local can, why = C.CanMark()
    if not can then
        self:Note("not permitted: " .. why, name, true)
        return self:Explain("Raid marker not set: " .. why .. ". Mark it yourself or ask the raid leader.")
    end
    self.tried[guid] = true
    if not SetRaidTarget then
        self:Note("SetRaidTarget is not available in this client", name, true)
        return self:Failed(name, "the marking function is missing")
    end
    if not C.SetRaidTarget(unit, icon) then
        self:Note("the client refused the call", name, true)
        return self:Failed(name, "the client refused the call")
    end
    self:Note("asked the client to mark", name, true)
    local gen = self.gen
    C_Timer.After(VERIFY_DELAY, function() M:Verify(guid, gen, icon, id, name) end)
end

function M:Verify(guid, gen, icon, id, name)
    if self.gen ~= gen then return end
    local u = self:UnitFor(guid)
    if not u then return end -- out of sight: result unknown, claim nothing
    if C.GetRaidTargetIndex(u) == icon then
        self.marked[guid], self.markedNpc[guid], self.holder[icon] = icon, id, guid
        self:Note("marked", name, true)
        say("Marked " .. tostring(name) .. " with " .. M.Label(icon) .. ".")
    else
        self:Note("the icon did not appear", name, true)
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

-- Any icon change: a living unit we marked that now shows a different icon (or none) was changed
-- by the player, another addon or a group member. Leave it alone and stop automatic marking for
-- the rest of this step, so the player's choice is not undone on the next mob either. A dead unit
-- simply lost its icon by dying.
function M:OnRaidTargetUpdate()
    for guid, icon in pairs(self.marked) do
        local u = self:UnitFor(guid)
        if u and C.GetRaidTargetIndex(u) ~= icon then
            self:Release(guid)
            if not (UnitIsDead and UnitIsDead(u)) then
                self.handsOff[guid] = true
                self.stopped = true
                self:Note("an icon we set was changed by someone else; paused for this step", nil, true)
            end
        end
    end
end

-- A marked unit died: its icon is gone (no RAID_TARGET_UPDATE is fired), so the next mob may get it.
function M:OnUnitDied(guid)
    if guid and self.marked[guid] then
        self:Release(guid)
        self:Note("marked mob died; its icon is free again", nil, true)
    end
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
    ns:Listen("TBCG_REFRESH", function() M:OnRefresh() end)
    ns:On("RAID_TARGET_UPDATE", function() M:OnRaidTargetUpdate() end)
    -- Only UNIT_DIED is looked at, and only while this module has marked something.
    ns:On("COMBAT_LOG_EVENT_UNFILTERED", function()
        if not next(M.marked) or not CombatLogGetCurrentEventInfo then return end
        local _, sub, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
        if sub == "UNIT_DIED" then M:OnUnitDied(destGUID) end
    end)
    ns:On("ADDON_ACTION_BLOCKED", function(_, addon, func) M:OnBlocked(addon, func) end)
    ns:On("ADDON_ACTION_FORBIDDEN", function(_, addon, func) M:OnBlocked(addon, func) end)
    self:OnStep()
end
