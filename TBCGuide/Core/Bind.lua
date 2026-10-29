-- TBCGuide - setting the hearthstone at an innkeeper on a guide "bind" step (setting: bindAuto)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Flow, only while the current step is a bind step and the player has opened an innkeeper's gossip:
--   1. GOSSIP_SHOW: the NPC must be the step's innkeeper (by NPC id from the GUID, or another
--      innkeeper of the same town). Quest automation goes first if it has something to do here.
--   2. The one gossip option marked as the binder (type "binder" on older APIs; the binder icon on
--      the modern C_GossipInfo, whose options have no type) is selected. A pending state starts.
--   3. CONFIRM_BINDER: its area name must be one of the step's areas ([area=] ids, named by the
--      client in its own language). Only then is the binder interaction confirmed.
--   4. HEARTHSTONE_BOUND: GetBindLocation() is read back and must match; only then is the step done.
-- Nothing is retried. The pending state ends on decline, gossip closed without a confirmation,
-- step/guide change, setting off, or a timeout; it is never saved, so a reload starts clean.

local _, ns = ...

local B = { pending = nil, warned = {} }
ns.Bind = B

local PICK_TIMEOUT, BOUND_TIMEOUT = 10, 10
local BINDER_ICONS = { [132052] = true, ["Interface\\GossipFrame\\BinderGossipIcon"] = true }

local function prof() return ns.db.profile end
local function now() return GetTime and GetTime() or 0 end
local function dbg(msg) ns:Debug("bind: " .. msg) end
local function step() return ns.Engine and ns.Engine:CurrentStep() end
local function shiftHeld() return ns.Compat.IsModifierHeld and ns.Compat.IsModifierHeld() end
local function lower(s) return type(s) == "string" and string.lower(s) or nil end

-- Localized names the client may report for step s's inn: its [area=] ids, then the English place.
function B:Names(s)
    local out = {}
    local info = C_Map and C_Map.GetAreaInfo
    for _, id in ipairs(s.areas or {}) do
        local n = info and info(id)
        if type(n) == "string" and n ~= "" then out[lower(n)] = true end
    end
    if s.place then out[lower(s.place)] = true end
    return out
end

-- Whether the hearthstone is already set where step s wants it.
function B:IsBoundFor(s)
    local loc = lower(ns.Compat.GetBindLocation())
    if not (s and loc) then return false end
    if self:Names(s)[loc] then return true end
    local seen = ns.char and ns.char.bindVerified
    return seen ~= nil and s.place ~= nil and seen[s.place] == loc
end

-- NPC id of the NPC the player is interacting with ("Creature-0-x-x-x-<id>-<spawn>").
function B:NpcId()
    local guid = UnitGUID and UnitGUID("npc")
    if type(guid) ~= "string" then return nil end
    local kind, id = string.match(guid, "^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind ~= "Creature" then return nil end
    return tonumber(id)
end

-- The step's innkeeper, or another innkeeper of the same faction in the same town (within 4 map units).
function B:InnkeeperFor(s, npcId)
    if not npcId then return false, "no NPC id" end
    if npcId == s.npcId then return true end
    local n = ns.DB.GetNPCByID(npcId)
    if not n or math.floor((n.flags or 0) / 65536) % 2 == 0 then return false, "not an innkeeper" end
    for _, p in ipairs((s.z and n.spawns[s.z]) or {}) do
        if s.x and ((p[1] - s.x) ^ 2 + (p[2] - s.y) ^ 2) <= 16 then return true end
    end
    return false, "an innkeeper of another place"
end

function B:IsBinder(o) return o ~= nil and (o.type == "binder" or (o.type == nil and BINDER_ICONS[o.icon] == true)) end

-- The binder option in the open gossip, only if there is exactly one.
function B:BinderOption()
    local found
    for _, o in ipairs(ns.Assist:GossipOptions()) do
        if self:IsBinder(o) then
            if found then return nil end
            found = o
        end
    end
    return found
end

function B:Cancel(why)
    local p = self.pending
    if not p then return end
    self.pending = nil
    dbg("cancelled (" .. tostring(why) .. ")")
end

-- Whether the pending bind still belongs to the current step and setting.
function B:StillValid(p)
    if p ~= self.pending then return false, "replaced" end
    if not prof().bindAuto then return false, "setting off" end
    local E = ns.Engine
    if not (E.guide and E.guide.id == p.guide and E.current == p.index) then return false, "step changed" end
    return true
end

-- GOSSIP_SHOW. Returns true when it selected the bind option (other gossip handlers then stay out).
function B:OnGossip()
    if not prof().bindAuto or shiftHeld() then return end
    local s = step()
    if not (s and s[1] == "bind") then self:Cancel("no bind step") return end
    if self:IsBoundFor(s) then dbg("already bound to " .. tostring(s.place)) ns.Engine:Refresh() return end
    if self.pending and self.pending.picked then dbg("already waiting for the confirmation") return true end
    local npcId = self:NpcId()
    local ok, why = self:InnkeeperFor(s, npcId)
    if not ok then
        dbg("npc " .. tostring(npcId) .. ": " .. tostring(why))
        if why == "an innkeeper of another place" and not self.warned[npcId] then
            self.warned[npcId] = true
            ns:Print("This innkeeper is not at " .. tostring(s.place) .. ", so TBCGuide does not set your hearthstone here.")
        end
        return
    end
    if ns.QuestAuto and ns.QuestAuto.GossipWants and ns.QuestAuto:GossipWants() then dbg("quest automation first") return end
    local o = self:BinderOption()
    if not o then dbg("no single binder option (" .. #ns.Assist:GossipOptions() .. " options)") return end
    local E = ns.Engine
    local p = { guide = E.guide.id, index = E.current, place = s.place, npc = npcId, at = now(), picked = true }
    self.pending = p
    dbg("npc " .. npcId .. ": selecting option " .. tostring(o.id) .. " " .. tostring(o.name))
    ns.Assist:SelectGossipOption(o)
    C_Timer.After(PICK_TIMEOUT, function()
        if B.pending == p and not p.asked then B:Cancel("no confirmation") end
    end)
    return true
end

-- The function that confirms the binder interaction on this client, or nil.
function B:ConfirmFn()
    local PIM = C_PlayerInteractionManager
    local T = Enum and Enum.PlayerInteractionType
    if PIM and PIM.ConfirmationInteraction and T and T.Binder then
        return function()
            PIM.ConfirmationInteraction(T.Binder)
            if PIM.ClearInteraction then PIM.ClearInteraction(T.Binder) end
        end
    end
    return ConfirmBinder
end

-- CONFIRM_BINDER(areaName): confirms only our own pending bind, only for the expected area.
function B:OnConfirm(area)
    local p = self.pending
    if not p then dbg("confirmation without a pending bind: left to the player") return end
    p.asked = true
    local valid, why = self:StillValid(p)
    if not valid or shiftHeld() then self:Cancel(why or "shift held") return end
    local s = step()
    if not (s and s[1] == "bind") then self:Cancel("no bind step") return end
    local want = self:Names(s)
    if type(area) ~= "string" or not want[lower(area)] then
        self:Cancel("area " .. tostring(area))
        ns:Print("This inn would set your hearthstone to " .. tostring(area) .. ", not " .. tostring(s.place)
            .. ". TBCGuide did not confirm it; choose Yes or No yourself.")
        return
    end
    p.area = area
    local confirm = self:ConfirmFn()
    if not confirm then
        ns:Print("Click Yes to set your hearthstone to " .. area .. " (this client does not let add-ons confirm it).")
        return
    end
    C_Timer.After(0, function()
        local ok, why2 = B:StillValid(p)
        if not ok then B:Cancel(why2) return end
        dbg("confirming " .. area)
        p.confirmed = true
        confirm()
        C_Timer.After(BOUND_TIMEOUT, function()
            if B.pending ~= p then return end
            B:Cancel("not bound in time")
            ns:Print("Your hearthstone was not confirmed as set to " .. area .. ". Talk to the innkeeper again, or click the step if it is set.")
        end)
    end)
end

-- The player answered the bind dialog themselves.
function B:OnDeclined() if self.pending then self:Cancel("declined") end end
function B:OnBlocked() if self.pending and self.pending.confirmed then
    ns:Print("The game needs you to click Yes on the hearthstone dialog yourself.")
    self.pending.confirmed = nil
end end

-- HEARTHSTONE_BOUND: verify against GetBindLocation, then let the engine complete the step.
function B:OnBound(retry)
    local p = self.pending
    local loc = ns.Compat.GetBindLocation()
    if p then
        local s = step()
        local fits = s and s[1] == "bind" and (self:Names(s)[lower(loc)] or (p.area and lower(loc) == lower(p.area)))
        if fits and self:StillValid(p) then
            self.pending = nil
            ns.char.bindVerified = ns.char.bindVerified or {}
            ns.char.bindVerified[p.place] = lower(loc)
            if StaticPopup_Hide then StaticPopup_Hide("CONFIRM_BINDER") end
            ns:Print("Hearthstone set to " .. tostring(loc) .. ".")
            dbg("verified " .. tostring(loc))
        elseif not retry then
            C_Timer.After(1, function() B:OnBound(true) end) -- the location may update a moment later
            return
        else
            self:Cancel("bound to " .. tostring(loc))
            ns:Print("Your hearthstone is now set to " .. tostring(loc) .. ". TBCGuide could not confirm that is "
                .. tostring(p.place) .. "; click the step if it is.")
        end
    end
    ns.Engine:Refresh()
end

function B:Init()
    ns:On("CONFIRM_BINDER", function(_, area) B:OnConfirm(area) end)
    ns:On("HEARTHSTONE_BOUND", function() B:OnBound() end)
    ns:On("GOSSIP_CLOSED", function()
        local p = B.pending
        if p and not p.asked then
            C_Timer.After(2, function() if B.pending == p and not p.asked then B:Cancel("gossip closed") end end)
        end
    end)
    ns:On("ADDON_ACTION_BLOCKED", function(_, addon) if addon == "TBCGuide" then B:OnBlocked() end end)
    ns:On("ADDON_ACTION_FORBIDDEN", function(_, addon) if addon == "TBCGuide" then B:OnBlocked() end end)
    ns:Listen("TBCG_STEP_CHANGED", function() if B.pending and not B:StillValid(B.pending) then B:Cancel("step changed") end end)
    ns:Listen("TBCG_GUIDE_CHANGED", function() B:Cancel("guide changed") end)
    local d = StaticPopupDialogs and StaticPopupDialogs.CONFIRM_BINDER
    if d and hooksecurefunc and d.OnCancel then hooksecurefunc(d, "OnCancel", function() B:OnDeclined() end) end
end
