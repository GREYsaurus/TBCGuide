-- TBCGuide - "orphaned quests" window and its button on the quest log
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

local W = ns.Widgets
local OF = { rows = {}, selected = {} }
ns.OrphanFrame = OF

local ROWS = 25 -- the quest log holds 25 quests
local ROW_H = 18
local POPUP = "TBCGUIDE_ABANDON_ORPHANS"

function OF:Create()
    local f = W.Panel("TBCGuideOrphanFrame", UIParent, 360, 120 + ROWS * ROW_H)
    f:SetFrameStrata("DIALOG")
    f:Hide()
    W.Movable(f, "orphans")
    W.CloseButton(f)
    self.frame = f
    tinsert(UISpecialFrames, "TBCGuideOrphanFrame")

    W.TitleBar(f, "Orphaned quests")
    self.info = W.Text(f, "GameFontHighlightSmall")
    self.info:SetPoint("TOPLEFT", 12, -32)
    self.info:SetWidth(336)

    for i = 1, ROWS do
        local cb = W.Check(f, 16)
        cb:SetPoint("TOPLEFT", 10, -62 - (i - 1) * ROW_H)
        local text = W.Text(cb, "GameFontHighlightSmall")
        text:SetPoint("LEFT", cb, "RIGHT", 8, 0)
        text:SetWidth(310)
        cb.label = text
        cb:SetScript("OnClick", function(self)
            if self.questId then OF.selected[self.questId] = self:GetChecked() and true or nil end
            OF:UpdateButton()
        end)
        self.rows[i] = cb
    end

    self.button = W.Button(f, "Abandon selected", 140, 22, function() OF:Confirm() end)
    self.button:SetPoint("BOTTOMRIGHT", -12, 10)
    W.Button(f, "Refresh", 80, 22, function() OF:Refresh(true) end):SetPoint("BOTTOMLEFT", 12, 10)

    if StaticPopupDialogs then
        StaticPopupDialogs[POPUP] = {
            text = "Abandon %s? This cannot be undone. Items and progress for these quests are lost.",
            button1 = YES or "Yes", button2 = NO or "No",
            OnAccept = function() OF:DoAbandon() end,
            timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
        }
    end

    ns:Listen("TBCG_QUESTS_CHANGED", function() if f:IsShown() then OF:Refresh() end end)
    ns:Listen("TBCG_ORPHANS_CHANGED", function() OF:Refresh(true) OF:UpdateQuestLogButton() end)
    ns:Listen("TBCG_REFRESH", function() OF:UpdateQuestLogButton() end)
    self:AttachToQuestLog()
end

-- Button on the default quest log window (only if the client has that frame).
function OF:AttachToQuestLog()
    local log = _G.QuestLogFrame
    if not log or self.logButton then return end
    local b = W.Button(log, "Orphaned", 80, 20, function() OF:Toggle() end)
    b:SetPoint("TOPRIGHT", log, "TOPRIGHT", -40, -44)
    b:SetFrameLevel((log:GetFrameLevel() or 1) + 5)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Quests your guide route will never turn in.\nClick to review and abandon them.")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.logButton = b
    self:UpdateQuestLogButton()
end

function OF:UpdateQuestLogButton()
    local b = self.logButton
    if not b then return end
    local list = ns.Orphans:Find()
    local n = list and #list or 0
    b:SetText(n > 0 and ("Orphaned (" .. n .. ")") or "Orphaned")
end

function OF:Toggle()
    if self.frame:IsShown() then self.frame:Hide() else self:Refresh(true) self.frame:Show() end
end

-- `reselect` restores the default selection (everything except class/profession quests).
function OF:Refresh(reselect)
    local list, why = ns.Orphans:Find()
    self.list = list or {}
    if reselect then
        self.selected = {}
        for _, o in ipairs(self.list) do if not o.special then self.selected[o.id] = true end end
    end
    if not list then
        self.info:SetText("Cannot tell which quests are orphaned: " .. why .. ".")
    elseif #list == 0 then
        self.info:SetText("No orphaned quests. Every quest in your log is still on your guide route.")
    else
        self.info:SetText("These quests are not turned in anywhere on your route from here to level 70. "
            .. "Class and profession quests are listed but not ticked.")
    end
    for i, cb in ipairs(self.rows) do
        local o = self.list[i]
        if o then
            cb.questId = o.id
            cb:SetChecked(self.selected[o.id] and true or false)
            cb.label:SetText(string.format("[%d] %s%s%s", o.level, o.title, o.complete and " |cff55ff55(complete)|r" or "",
                o.special and (" |cffaaaaaa(" .. o.why .. ")|r") or ""))
            cb:Show()
        else
            cb.questId = nil
            cb:Hide()
        end
    end
    self:UpdateButton()
end

function OF:SelectedIds()
    local ids = {}
    for _, o in ipairs(self.list or {}) do if self.selected[o.id] then ids[#ids + 1] = o.id end end
    return ids
end

function OF:UpdateButton()
    local n = #self:SelectedIds()
    self.button:SetText(n > 0 and ("Abandon " .. n) or "Abandon selected")
end

function OF:Confirm()
    local ids = self:SelectedIds()
    if #ids == 0 then return ns:Print("No quests selected.") end
    self.pendingIds = ids
    local what = #ids == 1 and ("\"" .. (ns.DB.GetQuestName(ids[1]) or "1 quest") .. "\"") or (#ids .. " quests")
    if StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs[POPUP] then
        StaticPopup_Show(POPUP, what)
    else
        ns:Print("Confirmation dialog unavailable; nothing was abandoned.")
    end
end

-- Called only from the confirmation dialog's OnAccept.
function OF:DoAbandon()
    local ids = self.pendingIds
    self.pendingIds = nil
    if ids and #ids > 0 then ns.Orphans:Abandon(ids) end
end
