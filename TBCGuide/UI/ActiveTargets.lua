-- TBCGuide - active target frame: click-to-target buttons for the current step's NPCs
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Each button is a secure macro button running "/tar <name>", the same as typing it, so it works
-- only on units near you. Enemies are the step's kill targets and marked NPCs; friendly targets are
-- the quest giver or finisher. "Follow Party Leader Target" adds what your party leader targets.
-- Secure buttons cannot change in combat; the list updates when combat ends.

local _, ns = ...

local AT = { buttons = {}, max = 6 }
ns.ActiveTargets = AT

local C = ns.Compat
local function prof() return ns.db.profile end

-- { {name=, enemy=bool} } for the current step.
function AT:Entries()
    local p, out, seen = prof(), {}, {}
    local function add(name, enemy)
        if name and not seen[name] and #out < self.max then seen[name] = true out[#out + 1] = { name = name, enemy = enemy } end
    end
    for id in pairs(ns.Assist:StepNpcIds()) do
        local n = ns.DB.GetNPCByID(id)
        if n then
            local enemy = n.friendly == nil
            if (enemy and p.atEnemy) or (not enemy and p.atFriendly) then add(n.name, enemy) end
        end
    end
    if p.atLeader and p.groupFeatures and ns.Group then
        local u = ns.Group:LeaderUnit()
        local name = u and UnitName and UnitName(u .. "target")
        if name then add(name, not (UnitIsFriend and UnitIsFriend("player", u .. "target"))) end
    end
    table.sort(out, function(a, b) if a.enemy ~= b.enemy then return a.enemy end return a.name < b.name end)
    return out
end

function AT:Frame()
    if self.frame then return self.frame end
    local W = ns.Widgets
    local f = W.Panel("TBCGuideActiveTargets", UIParent, 170, 30)
    W.Movable(f, "activeTargets")
    if not (ns.db.frames.activeTargets and ns.db.frames.activeTargets.point) then f:ClearAllPoints() f:SetPoint("LEFT", UIParent, "LEFT", 40, 120) end
    local title = W.Text(f, "GameFontNormalSmall", "LEFT")
    title:SetPoint("TOPLEFT", 6, -5)
    title:SetText("Targets")
    f:Hide()
    self.frame = f
    return f
end

function AT:Button(i)
    local b = self.buttons[i]
    if b then return b end
    b = CreateFrame("Button", "TBCGuideActiveTarget" .. i, self:Frame(), "SecureActionButtonTemplate")
    b:SetSize(160, 20)
    b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 5, -18 - (i - 1) * 21)
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("type", "macro")
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", 4, 0)
    t:SetJustifyH("LEFT")
    b.text = t
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)
    self.buttons[i] = b
    return b
end

function AT:ApplyLook()
    local f = self:Frame()
    local p = prof()
    f:SetScale(p.atScale or 1)
    if f.SetBackdropColor then f:SetBackdropColor(0.05, 0.05, 0.08, p.atHideBg and 0 or 0.88) end
    if f.SetBackdropBorderColor then f:SetBackdropBorderColor(0.4, 0.4, 0.45, p.atHideBg and 0 or 1) end
end

function AT:Update()
    if not ns.db then return end
    if C.InCombat() then self.pending = true return end
    self.pending = nil
    local p = prof()
    local f = self:Frame()
    local list = (p.activeTargets and p.showAllFrames) and self:Entries() or {}
    for i = 1, self.max do
        local b, e = self:Button(i), list[i]
        if e then
            b:SetAttribute("macrotext", "/tar " .. e.name)
            b.text:SetText(e.name)
            if e.enemy then b.text:SetTextColor(1, 0.4, 0.3) else b.text:SetTextColor(0.4, 1, 0.4) end
            b:Show()
        else
            b:SetAttribute("macrotext", nil)
            b:Hide()
        end
    end
    self:ApplyLook()
    if #list > 0 then f:SetHeight(24 + #list * 21) f:Show() else f:Hide() end
end

function AT:ResetPosition()
    ns.db.frames.activeTargets = nil
    local f = self:Frame()
    f:ClearAllPoints()
    f:SetPoint("LEFT", UIParent, "LEFT", 40, 120)
end

function AT:Init()
    local function upd() ns:Throttle("activetargets", 0.3, function() AT:Update() end) end
    ns:Listen("TBCG_STEP_CHANGED", upd)
    ns:Listen("TBCG_GUIDE_CHANGED", upd)
    ns:On("PLAYER_REGEN_ENABLED", function() if AT.pending then AT:Update() end end)
    ns:On("GROUP_ROSTER_UPDATE", upd)
    ns:On("UNIT_TARGET", function(_, unit)
        if prof().atLeader and ns.Group and unit == ns.Group:LeaderUnit() then upd() end
    end)
    upd()
end
