-- TBCGuide - first-login setup: starting guide, spec profile, automatic upgrades (explicit choice)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Shown once per character (ns.char.setupDone). Characters that already use TBCGuide (a guide,
-- progress or a spec profile) are marked done silently. Choices are kept in ns.char.setupDraft until
-- Finish, so closing the window or logging out loses nothing; nothing is applied before Finish.
-- Automatic upgrades use the real setting (profile autoEquip) and stay off unless ticked.

local _, ns = ...

local WL = {}
ns.Welcome = WL

local W = ns.Widgets
local function prof() return ns.db.profile end

-- Existing users are never interrupted: runs before the first-login guide is picked, so a guide,
-- progress or spec profile here means the character already used TBCGuide.
function WL:Migrate()
    local c = ns.char
    if c.setupDone then return end
    if c.activeGuide or c.gearProfile or (type(c.progress) == "table" and next(c.progress)) then c.setupDone = true end
end

function WL:Needed() return not ns.char.setupDone end

function WL:Draft()
    if type(ns.char.setupDraft) ~= "table" then ns.char.setupDraft = {} end
    local d = ns.char.setupDraft
    if d.guide == nil then
        -- The guide picked at first login (if any) is the default; otherwise the recommendation.
        local g = ns.char.activeGuide and ns.Guides:Get(ns.char.activeGuide) or ns.Selector:Recommend()
        d.guide = g and g.id or false
    end
    if d.profile == nil then d.profile = ns.char.gearProfile or false end
    if d.autoEquip == nil then d.autoEquip = false end
    return d
end

-- Guides for this character (faction, race, class), sorted by level.
function WL:GuideChoices()
    local info = ns.Compat.PlayerInfo()
    local out = {}
    for _, g in ipairs(ns.Guides:Filter({ faction = info.faction, race = info.race, class = info.class })) do
        out[#out + 1] = { g.id, string.format("%s (%d-%d)", g.name, g.minLevel or 1, g.maxLevel or 70) }
    end
    return out
end

function WL:ProfileChoices()
    local out = { { false, "Choose later" } }
    for _, p in ipairs(ns.Gear:ProfilesForClass(ns.Compat.PlayerInfo().class)) do
        if p.spec then
            out[#out + 1] = { p.id, ns.Upgrade:ProfileName(p) .. (p.context == "pve-preraid" and " (pre-raid)" or "") .. (p.weights and "" or " *") }
        end
    end
    return out
end

-- Applies the draft. Guide: loaded with its existing progress (never reset). Automatic upgrades only
-- when ticked AND a spec profile is chosen; the normal safety checks then decide what may happen.
function WL:Finish()
    local d = self:Draft()
    if d.guide and ns.Guides:Get(d.guide) then
        if ns.char.activeGuide ~= d.guide then ns.Engine:Load(d.guide) end
        if ns.MainFrame then ns.MainFrame:Show() end
    end
    if d.profile and ns.Gear:ProfileById(d.profile) then
        ns.char.gearProfile = d.profile
    end
    -- The real setting (it belongs to the settings profile, like every other option).
    prof().autoEquip = (d.autoEquip and ns.Upgrade:ActiveProfile()) and true or false
    ns.char.setupDone = true
    ns.char.setupDraft = nil
    if ns.AutoEquip then ns.AutoEquip:OnProfileChanged() end
    if self.frame then self.frame:Hide() end
    ns:Print("Setup saved. Reopen it any time: Settings, General, Open setup.")
end

-- Skip: no automation, the recommended guide as before (only when no guide is active yet).
function WL:Skip()
    ns.char.setupDone = true
    ns.char.setupDraft = nil
    if not ns.char.activeGuide and prof().autoSelectGuide then
        local g = ns.Selector:Recommend()
        if g then ns.Engine:Load(g.id) end
    end
    if self.frame then self.frame:Hide() end
end

local function dropdown(parent, name, w, values, get, set)
    return W.Dropdown(parent, name, w, function()
        local out = {}
        for _, v in ipairs(values()) do out[#out + 1] = { text = v[2], value = v[1], checked = get() == v[1] } end
        return out
    end, function(v) set(v) end, function()
        for _, v in ipairs(values()) do if v[1] == get() then return v[2] end end
        return "-"
    end)
end

function WL:Build()
    if self.frame then return self.frame end
    local f = W.Panel("TBCGuideWelcome", UIParent, 460, 360)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    W.TitleBar(f, "Welcome to TBCGuide")
    W.CloseButton(f) -- closing keeps the draft; setup shows again next login
    local y = -40
    local function text(t, font, h)
        local fs = W.Text(f, font or "GameFontHighlightSmall", "LEFT")
        fs:SetPoint("TOPLEFT", 16, y)
        fs:SetWidth(428)
        fs:SetText(t)
        y = y - (h or 16)
        return fs
    end
    local function section(t)
        local fs = W.Section(f, t)
        fs:SetPoint("TOPLEFT", 16, y)
        y = y - 20
    end
    text("Three quick choices for this character. You can change all of them later in the settings.", nil, 26)
    section("1. Starting guide")
    local gdd = dropdown(f, "TBCGuideWelcomeGuide", 300, function() return WL:GuideChoices() end,
        function() return WL:Draft().guide end, function(v) WL:Draft().guide = v end)
    gdd:SetPoint("TOPLEFT", 0, y)
    y = y - 34
    text("Suggested from your race, class, level and zone. Progress you already have in a guide is kept.", nil, 26)
    section("2. Spec profile")
    local pdd = dropdown(f, "TBCGuideWelcomeProfile", 300, function() return WL:ProfileChoices() end,
        function() return WL:Draft().profile end, function(v) WL:Draft().profile = v WL:Sync() end)
    pdd:SetPoint("TOPLEFT", 0, y)
    y = y - 34
    text("Used for gear recommendations (tooltips, quest rewards, bag markers) and talent suggestions. * = estimated weights.", nil, 26)
    section("3. Automatic upgrades")
    local cb = W.Check(f)
    cb:SetPoint("TOPLEFT", 20, y)
    local cl = W.Text(f, "GameFontHighlight", "LEFT")
    cl:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    cl:SetText("Equip upgrades from my bags automatically")
    cb:SetScript("OnClick", function(s) WL:Draft().autoEquip = s:GetChecked() and true or false end)
    self.check = cb
    y = y - 26
    text("Off unless you tick it, and only with a spec profile. Empty slots are filled with usable items (setting: Fill empty gear slots); filled slots only get a higher estimated spec score, not a guaranteed DPS or healing gain. Never in combat, and unbound Bind-on-Equip items are never equipped automatically. This switch is part of your settings profile.", nil, 54)
    W.Button(f, "Finish", 110, 24, function() WL:Finish() end):SetPoint("BOTTOMRIGHT", -16, 14)
    W.Button(f, "Skip for now", 110, 24, function() WL:Skip() end):SetPoint("RIGHT", f, "BOTTOMRIGHT", -132, 26)
    self.frame = f
    f:Hide()
    return f
end

function WL:Sync()
    if not self.frame then return end
    local d = self:Draft()
    self.check:SetChecked(d.autoEquip and true or false)
    if d.profile then self.check:Enable() else self.check:SetChecked(false) d.autoEquip = false self.check:Disable() end
end

function WL:Open()
    self:Build()
    self:Sync()
    self.frame:Show()
end

function WL:Init()
    self:Migrate()
    if self:Needed() then
        C_Timer.After(2, function()
            if WL:Needed() and not ns.Compat.InCombat() then WL:Open() end
        end)
    end
end
