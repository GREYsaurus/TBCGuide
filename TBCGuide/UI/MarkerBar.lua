-- TBCGuide - raid marker bar and the "Raid markers" options page
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- The bar's buttons are SecureActionButtonTemplate macro buttons: a click runs the mark as a
-- normal player action, so it keeps working even on a client where SetRaidTarget is secure-only.
-- Secure frames cannot be shown or hidden in combat; the bar is toggled out of combat only.

local _, ns = ...

local W = ns.Widgets
local MB = {}
ns.MarkerBar = MB

local SIZE = 24

-- Same non-toggling logic as Compat.SetRaidTarget, as macro text for the secure button.
local function macroFor(i)
    if i == 0 then return "/run if GetRaidTargetIndex(\"target\") then SetRaidTarget(\"target\", 0) end" end
    return string.format("/run if GetRaidTargetIndex(\"target\") ~= %d then SetRaidTarget(\"target\", %d) end", i, i)
end

function MB:Create()
    local f = W.Panel("TBCGuideMarkerBar", UIParent, 9 * (SIZE + 2) + 10, SIZE + 10)
    f:Hide()
    W.Movable(f, "markerBar")
    self.frame = f
    for i = 0, 8 do
        local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
        b:SetSize(SIZE, SIZE)
        b:SetPoint("LEFT", 5 + i * (SIZE + 2), 0)
        b:RegisterForClicks("AnyUp")
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", macroFor(i))
        local tex = b:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        if i == 0 then
            tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        else
            tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i)
        end
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(i == 0 and "Clear your target's raid marker" or ("Mark your target: " .. ns.Marker.NAMES[i]))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    if ns.db.profile.showMarkerBar then f:Show() end
end

function MB:Toggle()
    if ns.Compat.InCombat() then return ns:Print("The marker bar can be shown or hidden only out of combat.") end
    local show = not self.frame:IsShown()
    self.frame:SetShown(show)
    ns.db.profile.showMarkerBar = show
end

-- Options page ---------------------------------------------------------------------------------

local CHECKS = {
    { "markEnabled", "Enable raid markers (commands, bar and guide marking)" },
    { "autoMark", "Mark NPCs named by the current guide step" },
    { "autoMarkObjectives", "Also mark kill objectives of steps without a marker (default icon)" },
    { "markReplace", "Allow automatic marking to replace an existing marker" },
    { "markClearOnAdvance", "Remove my automatic markers when the step changes" },
    { "markNotify", "Chat messages when marking succeeds or fails" },
}

function MB:CreateOptions()
    local p = CreateFrame("Frame", "TBCGuideMarkerPanel", UIParent)
    p:Hide()
    self.panel = p
    local title = W.Text(p, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("TBCGuide - Raid markers")
    local y = -48
    self.checks = {}
    for _, c in ipairs(CHECKS) do
        local key = c[1]
        local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        local text = W.Text(cb, "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        text:SetText(c[2])
        cb:SetScript("OnClick", function(self)
            ns.db.profile[key] = self:GetChecked() and true or false
            ns.Marker:OnStep()
        end)
        cb.key = key
        self.checks[#self.checks + 1] = cb
        y = y - 26
    end

    local label = W.Text(p, "GameFontNormal")
    label:SetPoint("TOPLEFT", 20, y - 10)
    label:SetText("Default marker:")
    local dd = W.Dropdown(p, "TBCGuideDefaultMarker", 130, function()
        local items = {}
        for i = 1, 8 do
            items[#items + 1] = { text = ns.Marker.Label(i), value = i, checked = ns.db.profile.defaultMarker == i }
        end
        return items
    end, function(v) ns.db.profile.defaultMarker = v end, function() return ns.Marker.Label(ns.db.profile.defaultMarker) end)
    dd:SetPoint("TOPLEFT", 120, y)
    self.dropdown = dd

    W.Button(p, "Show / hide marker bar", 180, 22, function() MB:Toggle() end):SetPoint("TOPLEFT", 16, y - 50)

    local help = W.Text(p, "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 20, y - 86)
    help:SetWidth(560)
    help:SetText("/tbcg mark [skull|cross|square|moon|triangle|diamond|circle|star] marks your target (default marker if none given). "
        .. "/tbcg unmark clears it. /tbcg markbar toggles the bar. Solo and in a party anyone can mark; in a raid only the leader and assistants. "
        .. "Automatic marking only marks NPCs the current guide step names, matched by NPC ID, and never overwrites a marker you or others set.")

    p:SetScript("OnShow", function()
        for _, cb in ipairs(MB.checks) do cb:SetChecked(ns.db.profile[cb.key] and true or false) end
        if UIDropDownMenu_SetText then UIDropDownMenu_SetText(MB.dropdown, ns.Marker.Label(ns.db.profile.defaultMarker)) end
    end)
    ns.Compat.RegisterOptionsSubPanel(p, "TBCGuide", "Raid markers")
end

function MB:OpenOptions()
    if not ns.Compat.OpenOptionsPanel(self.panel) then ns:Print("Options panel unavailable; use /tbcg set <option> on|off.") end
end
