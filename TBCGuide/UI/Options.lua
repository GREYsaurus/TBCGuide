-- TBCGuide - options panel (Interface > AddOns > TBCGuide)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

local W = ns.Widgets
local Options = {}
ns.Options = Options

local CHECKS = {
    { "autoAdvance", "Advance automatically when a step's completion is detected" },
    { "showArrow", "Show the navigation arrow" },
    { "showMapPins", "Show the current target on the world map" },
    { "useTomTom", "Send waypoints to TomTom (if installed)" },
    { "showDungeonSteps", "Show dungeon quest steps" },
    { "showElite", "Show elite / group quest steps" },
    { "speedRoute", "Maximum-speed route: hide optional side quests" },
    { "talentHints", "Remind me to spend talent points (chat)" },
    { "locked", "Lock window positions" },
    { "debug", "Debug messages" },
}

function Options:Create()
    local p = CreateFrame("Frame", "TBCGuideOptionsPanel", UIParent)
    p:Hide()
    self.panel = p

    local title = W.Text(p, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("TBCGuide")
    local sub = W.Text(p, "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText("Free TBC leveling & talent guide (GPL-3.0). Target client: " .. ns.Target.name .. " (" .. ns.Target.interface .. ").")

    local y = -64
    self.checks = {}
    for _, c in ipairs(CHECKS) do
        local key, label = c[1], c[2]
        local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        local text = W.Text(cb, "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        text:SetText(label)
        cb:SetScript("OnClick", function(self)
            ns.db.profile[key] = self:GetChecked() and true or false
            Options:Apply()
        end)
        cb.key = key
        self.checks[#self.checks + 1] = cb
        y = y - 26
    end

    local steps = CreateFrame("Slider", "TBCGuideOptStepsShown", p, "OptionsSliderTemplate")
    steps:SetPoint("TOPLEFT", 24, y - 20)
    steps:SetWidth(200)
    steps:SetMinMaxValues(1, 8)
    steps:SetValueStep(1)
    if steps.SetObeyStepOnDrag then steps:SetObeyStepOnDrag(true) end
    steps:SetScript("OnValueChanged", function(_, v)
        ns.db.profile.stepsShown = math.floor(v + 0.5)
        _G["TBCGuideOptStepsShownText"]:SetText("Steps shown: " .. ns.db.profile.stepsShown)
        ns.MainFrame:Render()
    end)
    self.steps = steps

    local scale = CreateFrame("Slider", "TBCGuideOptScale", p, "OptionsSliderTemplate")
    scale:SetPoint("LEFT", steps, "RIGHT", 40, 0)
    scale:SetWidth(200)
    scale:SetMinMaxValues(0.6, 1.6)
    scale:SetValueStep(0.05)
    scale:SetScript("OnValueChanged", function(_, v)
        ns.db.profile.scale = ns.Round(v, 2)
        _G["TBCGuideOptScaleText"]:SetText("Window scale: " .. ns.db.profile.scale)
        if ns.MainFrame.frame then ns.MainFrame.frame:SetScale(ns.db.profile.scale) end
    end)
    self.scale = scale

    W.Button(p, "Reset window positions", 170, 22, function()
        ns.db.frames.main = { point = "RIGHT", x = -60, y = 120, w = 320, h = 230, shown = true }
        ns.db.frames.arrow = { point = "TOP", x = 0, y = -120 }
        ReloadUI()
    end):SetPoint("TOPLEFT", 16, y - 70)

    W.Button(p, "Reset current guide progress", 200, 22, function() ns.Engine:Reset() end):SetPoint("TOPLEFT", 200, y - 70)

    p:SetScript("OnShow", function() Options:Sync() end)
    ns.Compat.RegisterOptionsPanel(p, "TBCGuide")
end

function Options:Sync()
    for _, cb in ipairs(self.checks) do cb:SetChecked(ns.db.profile[cb.key] and true or false) end
    self.steps:SetValue(ns.db.profile.stepsShown or 4)
    self.scale:SetValue(ns.db.profile.scale or 1)
end

function Options:Apply()
    if ns.Nav.arrow then ns.Nav.arrow:SetShown(ns.db.profile.showArrow and ns.Nav.target ~= nil) end
    ns.Nav:UpdateMapPin()
    ns.Nav:UpdateTomTom()
    if ns.Engine.guide then ns.Engine:Refresh() end
end

function Options:Open()
    if not ns.Compat.OpenOptionsPanel(self.panel) then
        ns:Print("Options panel unavailable in this client; use /tbcg set <option> on|off.")
    end
end
