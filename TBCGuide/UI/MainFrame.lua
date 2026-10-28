-- TBCGuide - main guide window
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Left-click a step: mark it done (manual confirmation). Right-click: skip it.
-- Header buttons: previous / next / guide browser / talents / minimise.

local _, ns = ...

local W = ns.Widgets
local Main = { rows = {} }
ns.MainFrame = Main

local ROW_PAD = 4
Main.EMPTY_TEXT = "No guide selected.\nType |cffffd100/tbcg guide|r to pick one, or |cffffd100/tbcg auto|r for a recommendation."

local function stepIcon(s, status)
    if status == "done" then return "Interface\\RaidFrame\\ReadyCheck-Ready" end
    if status == "skipped" then return "Interface\\RaidFrame\\ReadyCheck-NotReady" end
    local k = s[1]
    if k == "accept" then return "Interface\\GossipFrame\\AvailableQuestIcon" end
    if k == "turnin" then return "Interface\\GossipFrame\\ActiveQuestIcon" end
    if k == "complete" then return "Interface\\Icons\\INV_Sword_04" end
    if k == "fp" or k == "fly" then return "Interface\\GossipFrame\\TaxiGossipIcon" end
    if k == "train" then return "Interface\\GossipFrame\\TrainerGossipIcon" end
    if k == "hs" or k == "bind" then return "Interface\\Icons\\INV_Misc_Rune_01" end
    if k == "level" then return "Interface\\Icons\\Spell_Holy_SurgeOfLight" end
    return "Interface\\GossipFrame\\GossipGossipIcon"
end

local function createRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.82, 0, 0.12)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("TOPLEFT", 2, -2)
    r.title = W.Text(r, "GameFontHighlight")
    r.title:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 4, 1)
    r.title:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.detail = W.Text(r, "GameFontHighlightSmall")
    r.detail:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -2)
    r.detail:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r:SetScript("OnClick", function(self, button)
        if not self.stepIndex then return end
        if button == "RightButton" then ns.Engine:Skip(self.stepIndex) else ns.Engine:MarkDone(self.stepIndex) end
    end)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Left-click: mark done", 1, 1, 1)
        GameTooltip:AddLine("Right-click: skip step", 1, 1, 1)
        local s = self.step
        if s and s.q then
            GameTooltip:AddLine("Quest ID " .. s.q, 0.6, 0.6, 0.6)
            local lvl, req = ns.DB.GetQuestLevel(s.q)
            if lvl then GameTooltip:AddLine(string.format("Quest level %d (requires %d)", lvl, req or 0), 0.6, 0.6, 0.6) end
        end
        local why = self.stepIndex and ns.Engine.autoReason[self.stepIndex]
        if why then GameTooltip:AddLine("Auto-skipped: " .. why, 1, 0.5, 0.3) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

function Main:Create()
    local pos = ns.db.frames.main
    local f = W.Panel("TBCGuideMainFrame", UIParent, pos.w or 320, pos.h or 230)
    self.frame = f
    W.Movable(f, "main")
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(240, 120, 600, 700) elseif f.SetMinResize then f:SetMinResize(240, 120); f:SetMaxResize(600, 700) end
    f:SetScale(ns.db.profile.scale or 1)
    f:SetFrameStrata("MEDIUM")

    -- Header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", -6, -6)
    header:SetHeight(34)
    W.Movable(f, "main", header)
    self.header = header

    self.guideName = W.Text(header, "GameFontNormal")
    self.guideName:SetPoint("TOPLEFT", 0, 0)
    self.guideName:SetPoint("RIGHT", header, "RIGHT", -96, 0)
    self.guideName:SetWordWrap(false)

    self.subline = W.Text(header, "GameFontHighlightSmall")
    self.subline:SetPoint("TOPLEFT", self.guideName, "BOTTOMLEFT", 0, -2)
    self.subline:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    self.subline:SetWordWrap(false)

    local x = 0
    local function hdrBtn(tex, tip, fn)
        local b = W.IconButton(header, tex, 16, tip, fn)
        b:SetPoint("TOPRIGHT", header, "TOPRIGHT", -x, 0)
        x = x + 18
        return b
    end
    self.minBtn = hdrBtn("Interface\\Buttons\\UI-MinusButton-Up", "Minimise / restore", function() Main:ToggleMinimized() end)
    hdrBtn("Interface\\Icons\\Ability_Marksmanship", "Talent guide (/tbcg talents)", function() ns.TalentFrame:Toggle() end)
    hdrBtn("Interface\\Icons\\INV_Misc_Book_09", "Guide browser (/tbcg guide)", function() ns.Browser:Toggle() end)
    hdrBtn("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", "Next step (/tbcg next)", function() ns.Engine:Next() end)
    hdrBtn("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", "Previous step (/tbcg prev)", function() ns.Engine:Prev() end)

    -- Progress bar
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
    bar:SetHeight(8)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.7, 1)
    bar:SetMinMaxValues(0, 1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    bar.text = W.Text(bar, "GameFontHighlightSmall", "CENTER")
    bar.text:SetPoint("CENTER", 0, 0)
    bar.text:SetFont(bar.text:GetFont(), 9)
    self.bar = bar

    -- Body
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
    body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
    self.body = body

    self.empty = W.Text(body, "GameFontHighlight")
    self.empty:SetPoint("TOPLEFT", 4, -4)
    self.empty:SetPoint("RIGHT", body, "RIGHT", -4, 0)
    self.empty:SetText(Main.EMPTY_TEXT)

    -- Resize grip
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function() if not ns.db.profile.locked then f:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        ns.db.frames.main.w, ns.db.frames.main.h = f:GetWidth(), f:GetHeight()
        Main:Render()
    end)
    self.grip = grip

    f:SetScript("OnSizeChanged", function() ns:Throttle("mainresize", 0.05, function() Main:Render() end) end)

    ns:Listen("TBCG_REFRESH", function() Main:Render() end)
    ns:Listen("TBCG_GUIDE_CHANGED", function() Main:Render() end)
    ns:On("PLAYER_LEVEL_UP", function() Main:Render() end)
    ns:On("ZONE_CHANGED_NEW_AREA", function() Main:Render() end)

    if ns.db.frames.main.minimized then self:SetMinimized(true) end
    f:SetShown(ns.db.frames.main.shown ~= false)
    self:Render()
end

function Main:SetMinimized(m)
    ns.db.frames.main.minimized = m
    self.body:SetShown(not m)
    self.bar:SetShown(not m)
    self.grip:SetShown(not m)
    if m then
        self.frame:SetHeight(46)
        self.minBtn:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    else
        self.frame:SetHeight(ns.db.frames.main.h or 230)
        self.minBtn:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    end
end

function Main:ToggleMinimized() self:SetMinimized(not ns.db.frames.main.minimized) end

function Main:Toggle()
    if not self.frame then return end
    local show = not self.frame:IsShown()
    self.frame:SetShown(show)
    ns.db.frames.main.shown = show
end

function Main:Show()
    if not self.frame then return end
    self.frame:Show()
    ns.db.frames.main.shown = true
end

function Main:Render()
    if not self.frame then return end
    local E = ns.Engine
    local g = E.guide
    local level = UnitLevel("player") or 1
    local zone = ns.Compat.GetZoneText()
    if not g then
        self.guideName:SetText("TBCGuide")
        self.subline:SetText(string.format("Level %d - %s", level, zone))
        self.bar:SetValue(0)
        self.bar.text:SetText("")
        self.empty:SetText(Main.EMPTY_TEXT)
        self.empty:Show()
        for _, r in ipairs(self.rows) do r:Hide() end
        return
    end
    self.empty:Hide()
    local color = (level < g.minLevel and "|cffff7744") or (level > g.maxLevel + 1 and "|cff999999") or "|cff55ff55"
    self.guideName:SetText(g.name)
    self.subline:SetText(string.format("%sLv %d|r  -  guide %d-%d  -  %s", color, level, g.minLevel, g.maxLevel, zone))
    local done, total = E:Counts()
    self.bar:SetValue(total > 0 and done / total or 0)
    self.bar.text:SetText(string.format("%d / %d steps (%d%%)", done, total, total > 0 and math.floor(done / total * 100) or 0))

    if ns.db.frames.main.minimized then return end

    local items = E:Upcoming(ns.db.profile.stepsShown or 4)
    if #items == 0 then
        local nextG = ns.Selector:NextAfter(g, ns.Compat.PlayerInfo())
        self.empty:SetText("Guide finished!" .. (nextG and ("\nNext: |cffffd100" .. nextG.name .. "|r (/tbcg nextguide)") or "\nOpen /tbcg guide to continue."))
        self.empty:Show()
    end
    local y = 0
    local width = self.body:GetWidth()
    local maxH = self.body:GetHeight()
    for n, idx in ipairs(items) do
        local r = self.rows[n] or createRow(self.body)
        self.rows[n] = r
        local s = g.steps[idx]
        r.step, r.stepIndex = s, idx
        r:SetWidth(width)
        r.icon:SetTexture(stepIcon(s, E.status[idx]))
        r.title:SetText(ns.StepText:Title(s))
        local details = (n == 1) and ns.StepText:Details(s) or {}
        r.detail:SetText(table.concat(details, "\n"))
        r.detail:SetShown(#details > 0)
        r.title:SetAlpha(n == 1 and 1 or 0.75)
        r.hl:SetShown(n == 1)
        local h = r.title:GetStringHeight() + (#details > 0 and (r.detail:GetStringHeight() + 4) or 0) + ROW_PAD
        r:SetHeight(h)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -y)
        y = y + h + 2
        r:SetShown(y <= maxH + h * 0.5 or n == 1)
    end
    for n = #items + 1, #self.rows do self.rows[n]:Hide() end
end
