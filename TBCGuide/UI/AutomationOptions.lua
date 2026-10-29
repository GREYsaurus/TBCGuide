-- TBCGuide - options sub-page: quest automation and junk selling
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

local W = ns.Widgets
local AO = {}
ns.AutomationOptions = AO

local QUEST_CHECKS = {
    { "autoAccept", "Accept quests from the active guide" },
    { "autoAcceptOptional", "...including optional guide quests" },
    { "autoAcceptGroup", "...including elite / group / dungeon quests" },
    { "autoTurnIn", "Turn in guide quests that have no reward choice" },
    { "turnInUnrelated", "Also turn in quests that are not in the guide" },
    { "questNotify", "Chat messages for quest automation" },
}

local JUNK_CHECKS = {
    { "autoSellJunk", "Sell junk (grey items) at vendors" },
    { "sellNotify", "Show a summary of what was sold" },
    { "sellNotifyItems", "List every item sold" },
}

local function check(p, x, y, label, get, set)
    local cb = W.Check(p)
    cb:SetPoint("TOPLEFT", x, y)
    local text = W.Text(cb, "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    text:SetText(label)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    cb.sync = function() cb:SetChecked(get() and true or false) end
    return cb
end

function AO:Create()
    local p = CreateFrame("Frame", "TBCGuideAutomationPanel", UIParent)
    p:Hide()
    self.panel = p
    self.checks = {}

    local title = W.Text(p, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("TBCGuide - Automation")

    -- Quests -------------------------------------------------------------------------------------
    local qh = W.Text(p, "GameFontNormal")
    qh:SetPoint("TOPLEFT", 16, -48)
    qh:SetText("Quests")
    local y = -64
    for _, c in ipairs(QUEST_CHECKS) do
        local key = c[1]
        self.checks[#self.checks + 1] = check(p, 16, y, c[2],
            function() return ns.db.profile[key] end,
            function(v) ns.db.profile[key] = v ns.QuestAuto:Rebuild() end)
        y = y - 24
    end
    local rule = W.Text(p, "GameFontHighlightSmall")
    rule:SetPoint("TOPLEFT", 20, y - 4)
    rule:SetWidth(290)
    rule:SetJustifyH("LEFT")
    rule:SetText("Always manual (cannot be changed): escort and scripted-event quests, choosing a reward, "
        .. "quests shared by other players. Hold Shift while talking to an NPC to skip automation once.")

    -- Junk ---------------------------------------------------------------------------------------
    local jh = W.Text(p, "GameFontNormal")
    jh:SetPoint("TOPLEFT", 330, -48)
    jh:SetText("Junk selling")
    y = -64
    for _, c in ipairs(JUNK_CHECKS) do
        local key = c[1]
        self.checks[#self.checks + 1] = check(p, 330, y, c[2],
            function() return ns.db.profile[key] end,
            function(v) ns.db.profile[key] = v end)
        y = y - 24
    end
    self.earned = W.Text(p, "GameFontHighlightSmall")
    self.earned:SetPoint("TOPLEFT", 334, y - 2)
    y = y - 22

    local ch = W.Text(p, "GameFontNormalSmall")
    ch:SetPoint("TOPLEFT", 334, y)
    ch:SetText("Never sell grey items of these kinds:")
    y = y - 14
    for i, c in ipairs(ns.Vendor.CLASSES) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local cb = check(p, 330 + col * 130, y - row * 22, c.name,
            function() return ns.Vendor:IsClassProtected(c.id) end,
            function(v) if not c.locked then ns.db.protectedClasses[c.id] = v end AO:Sync() end)
        if c.locked and cb.Disable then cb:Disable() end
        self.checks[#self.checks + 1] = cb
    end
    y = y - math.ceil(#ns.Vendor.CLASSES / 2) * 22 - 8

    -- Protected items ------------------------------------------------------------------------------
    local ph = W.Text(p, "GameFontNormalSmall")
    ph:SetPoint("TOPLEFT", 334, y)
    ph:SetText("Protected items (item ID or link):")
    local box = W.Input(p, "TBCGuideProtectBox", 200, 20)
    box:SetSize(110, 20)
    box:SetPoint("TOPLEFT", 340, y - 16)
    box:SetAutoFocus(false)
    local function edit(on)
        local id = ns.Vendor.ParseItem(box:GetText())
        if not id then return ns:Print("Enter an item ID or shift-click an item link into the box.") end
        ns.Vendor:Protect(id, on)
        box:SetText("")
        AO:Sync()
    end
    W.Button(p, "Protect", 70, 20, function() edit(true) end):SetPoint("LEFT", box, "RIGHT", 6, 0)
    W.Button(p, "Remove", 70, 20, function() edit(false) end):SetPoint("LEFT", box, "RIGHT", 80, 0)
    self.list = W.Text(p, "GameFontHighlightSmall")
    self.list:SetPoint("TOPLEFT", 336, y - 42)
    self.list:SetWidth(270)
    self.list:SetJustifyH("LEFT")

    p:SetScript("OnShow", function() AO:Sync() end)
    ns.Compat.RegisterOptionsSubPanel(p, "TBCGuide", "Automation")
end

function AO:Sync()
    for _, cb in ipairs(self.checks) do cb.sync() end
    local js = ns.char.junkStats
    self.earned:SetText(string.format("Earned so far: %s from %d items", ns.Compat.FormatMoney(js.copper), js.items))
    local ids = ns.Vendor:ProtectedList()
    local names = {}
    for i = 1, math.min(#ids, 12) do
        local info = ns.Compat.GetItemInfo(ids[i])
        names[#names + 1] = (info and info.name or "item") .. " (" .. ids[i] .. ")"
    end
    if #ids > 12 then names[#names + 1] = "... " .. (#ids - 12) .. " more (/tbcg protected)" end
    self.list:SetText(#names > 0 and table.concat(names, ", ") or "none")
end

function AO:Open()
    if not ns.Compat.OpenOptionsPanel(self.panel) then
        ns:Print("Options panel unavailable in this client; use /tbcg set <option> on|off.")
    end
end
