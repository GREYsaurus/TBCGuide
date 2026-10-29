-- TBCGuide - minimap button: left-click opens settings, right-click toggles the guide window
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Native implementation (no LibDBIcon/LibDataBroker). The position is one angle around the
-- minimap in ns.db.minimap.angle, written once when a drag ends. Visibility is the profile
-- setting showMinimapButton (options page, /tbcg minimap, /tbcg set showMinimapButton on|off).

local _, ns = ...

local MB = {}
ns.MinimapButton = MB

MB.DEFAULT_ANGLE = 220 -- lower left, clear of the default minimap buttons
local ICON = "Interface\\Icons\\INV_Misc_Map_01" -- built-in client icon; the add-on ships no art

-- Saved angle in degrees (0-360); anything invalid falls back to the default.
function MB:Angle()
    local m = ns.db.minimap
    local a = type(m) == "table" and tonumber(m.angle)
    if not a or a ~= a or a == math.huge or a == -math.huge then return self.DEFAULT_ANGLE end
    return a % 360
end

-- Places the button on the minimap edge at `angle`. Square minimaps (GetMinimapShape, set by
-- minimap add-ons) push the button out to the corners instead of a circle.
function MB:Place(angle)
    local b = self.button
    if not b then return end
    local rad = math.rad(angle)
    local x, y = math.cos(rad), math.sin(rad)
    local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
    local w = (Minimap.GetWidth and Minimap:GetWidth() or 140) / 2 + 10
    if square then
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
    end
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", x * w, y * w)
end

-- Angle from the minimap centre to the cursor, in degrees.
function MB:CursorAngle()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not (mx and my and cx and cy and scale and scale > 0) then return nil end
    return math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
end

-- Left-click toggles the TBCGuide settings window (UI/Config.lua).
function MB:OnClick(button)
    if self.dragged then self.dragged = false return end -- releasing a drag is not a click
    if button == "RightButton" then
        if ns.MainFrame and ns.MainFrame.Toggle then ns.MainFrame:Toggle() end
        return
    end
    if not (ns.Config and ns.Config.frame) then
        return ns:Print("Settings are not ready yet. Try again in a moment, or type /tbcg options.")
    end
    ns.Config:Toggle()
end

function MB:ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("TBCGuide")
    GameTooltip:AddLine("Click to open TBCGuide settings.", 1, 1, 1)
    GameTooltip:AddLine("Right-click to show or hide the guide window.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move. /tbcg minimap hides this button.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function MB:Create()
    if self.button or not Minimap then return end
    local b = CreateFrame("Button", "TBCGuideMinimapButton", Minimap)
    self.button = b
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER", 0, 1)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    self.icon = icon
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    b:SetScript("OnClick", function(_, button) MB:OnClick(button) end)
    b:SetScript("OnEnter", function(s) MB:ShowTooltip(s) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnMouseDown", function()
        MB.dragged = false -- every press starts clean, whether or not the client clicked after the last drag
        icon:SetPoint("CENTER", 1, 0)
    end)
    b:SetScript("OnMouseUp", function() icon:SetPoint("CENTER", 0, 1) end)
    b:SetScript("OnDragStart", function(s)
        MB.dragged = true
        GameTooltip:Hide()
        s:SetScript("OnUpdate", function()
            local a = MB:CursorAngle()
            if a then MB.dragAngle = a MB:Place(a) end
        end)
    end)
    b:SetScript("OnDragStop", function(s)
        s:SetScript("OnUpdate", nil)
        icon:SetPoint("CENTER", 0, 1)
        if MB.dragAngle then
            ns.db.minimap.angle = ns.Round(MB.dragAngle, 1) -- saved once, when the drag ends
            MB.dragAngle = nil
        end
    end)
    self:Update()
end

-- Applies the saved angle and the visibility setting (called on load and from the options page).
function MB:Update()
    if not self.button then return end
    self:Place(self:Angle())
    if ns.db.profile.showMinimapButton then self.button:Show() else self.button:Hide() end
end

function MB:Toggle()
    ns.db.profile.showMinimapButton = not ns.db.profile.showMinimapButton
    self:Update()
    ns:Print(ns.db.profile.showMinimapButton and "Minimap button shown."
        or "Minimap button hidden. /tbcg minimap shows it again; /tbcg options opens settings.")
    if ns.Options and ns.Options.panel and ns.Options.panel:IsShown() then ns.Options:Sync() end
end
