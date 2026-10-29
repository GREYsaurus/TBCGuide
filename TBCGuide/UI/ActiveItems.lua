-- TBCGuide - active item window: one-click buttons for usable quest items in your bags
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Shows the usable items ("Use:" on the item) that belong to quests: quest items in your bags and
-- items the current guide's quests need. Each button is a secure item button (type "item", item
-- "item:<id>"), so a click uses the item exactly like right-clicking it in your bags: targeting,
-- range, cooldown and error messages are the client's own. Nothing is ever used without a click.
--
--   * Clicks: on the modern Classic engine a secure action button acts on the mouse-DOWN event when
--     the ActionButtonUseKeyDown CVar is on (the default) and ignores the up event, so a button
--     registered only for "AnyUp" shows the item but never uses it. Buttons register for both; the
--     template then acts once, on whichever the CVar picks. Older templates (no SecureActionButtonMixin)
--     act on every registered click, so they get "AnyUp" only.
--   * Shift-click links the item in chat and Alt-drag moves the window; neither uses the item
--     ("shift-type1"/"alt-type1" are empty, so the secure handler does nothing for them).
--   * Combat: secure attributes, the button set and the window size change only out of combat
--     (AI.pending, applied on PLAYER_REGEN_ENABLED). In combat only plain visuals update: count,
--     cooldown, and a greyed-out icon when the bound item has left your bags. The icon always shows
--     the item the button is bound to (b.itemID), never a newer one.

local _, ns = ...

local AI = { buttons = {}, max = 6 }
ns.ActiveItems = AI

local C = ns.Compat
local function prof() return ns.db.profile end

-- Item ids the current guide's quests use (objective items and quest-starting items).
function AI:GuideItems()
    local ids = {}
    local g = ns.Engine and ns.Engine.guide
    if not g then return ids end
    for _, s in ipairs(g.steps) do
        if s.q and ns.Tracker:InLog(s.q) then
            for _, id in ipairs(ns.DB.GetQuestItems(s.q) or {}) do ids[id] = true end
        end
    end
    return ids
end

local function itemSpell(id)
    local f = C.Has("C_Item.GetItemSpell") or C.Has("GetItemSpell")
    return f and f(id) or nil
end

local function bagCount(id)
    local n = 0
    for bag = 0, C.NUM_BAGS do
        for slot = 1, C.GetContainerNumSlots(bag) do
            local it = C.GetContainerItem(bag, slot)
            if it and it.itemID == id then n = n + (it.count or 1) end
        end
    end
    return n
end

-- { {itemID, count, link} } in bag order, at most AI.max. count is the total across stacks.
function AI:Collect()
    local want, out, seen = self:GuideItems(), {}, {}
    for bag = 0, C.NUM_BAGS do
        for slot = 1, C.GetContainerNumSlots(bag) do
            local it = C.GetContainerItem(bag, slot)
            local id = it and it.itemID
            if id and not seen[id] then
                local quest = want[id] or C.ContainerItemIsQuestItem(bag, slot)
                if not quest then
                    local info = C.GetItemInfo(id)
                    quest = info and info.classID == 12
                end
                if quest and itemSpell(id) then
                    seen[id] = true
                    out[#out + 1] = { itemID = id, link = it.link, count = bagCount(id) }
                    if #out >= self.max then return out end
                end
            end
        end
    end
    return out
end

function AI:Frame()
    if self.frame then return self.frame end
    local W = ns.Widgets
    local f = W.Panel("TBCGuideActiveItems", UIParent, 44, 44)
    W.Movable(f, "activeItems")
    if not (ns.db.frames.activeItems and ns.db.frames.activeItems.point) then f:ClearAllPoints() f:SetPoint("CENTER", UIParent, "CENTER", 0, -200) end
    f:Hide()
    self.frame = f
    return f
end

local function icon(id)
    local f = C.Has("C_Item.GetItemIconByID") or C.Has("GetItemIcon")
    return f and f(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function cooldown(id)
    local f = C.Has("C_Container.GetItemCooldown") or C.Has("GetItemCooldown")
    if not f then return nil end
    return f(id)
end

-- Plain visuals for a button bound to b.itemID: count, cooldown, greyed out when none are left.
-- Safe in combat (no secure attributes are touched).
function AI:Refresh(b)
    local id = b.itemID
    if not id then return end
    local n = bagCount(id)
    b.count:SetText(n > 1 and n or "")
    b.icon:SetDesaturated(n == 0)
    b.missing = n == 0
    local start, dur, enable = cooldown(id)
    if b.cooldown and b.cooldown.SetCooldown then
        if start and dur and dur > 0 and enable ~= 0 then b.cooldown:SetCooldown(start, dur) else b.cooldown:Hide() end
    end
end

function AI:RefreshAll()
    for _, b in ipairs(self.buttons) do if b:IsShown() then self:Refresh(b) end end
end

-- Buttons register for the click events the secure template will act on (see the header).
local function registerClicks(b)
    if SecureActionButtonMixin then b:RegisterForClicks("AnyUp", "AnyDown") else b:RegisterForClicks("AnyUp") end
end
AI.RegisterClicks = registerClicks

function AI:Button(i)
    local b = self.buttons[i]
    if b then return b end
    b = CreateFrame("Button", "TBCGuideActiveItem" .. i, self:Frame(), "SecureActionButtonTemplate")
    b:SetSize(36, 36)
    b:SetPoint("LEFT", self.frame, "LEFT", 4 + (i - 1) * 40, 0)
    registerClicks(b)
    b:SetAttribute("type", "item")
    b:SetAttribute("shift-type1", "") -- Shift-click: link in chat (PostClick), no use
    b:SetAttribute("alt-type1", "")   -- Alt-drag: move the window, no use
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    b.icon = t
    local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    cd:SetAllPoints()
    if cd.EnableMouse then cd:EnableMouse(false) end -- never take the item's clicks
    b.cooldown = cd
    local c = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    c:SetPoint("BOTTOMRIGHT", -2, 2)
    b.count = c
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    b:SetScript("OnEnter", function(s)
        if not s.link then return end
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetHyperlink(s.link)
        if s.missing then GameTooltip:AddLine("Not in your bags any more.", 1, 0.3, 0.3) end
        GameTooltip:AddLine("Click to use. Shift-click to link, Alt-drag to move.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("PostClick", function(s)
        if s.link and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(s.link) end
    end)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function()
        local f = AI.frame
        if f and IsAltKeyDown and IsAltKeyDown() and not prof().locked and not C.InCombat() then
            f:StartMoving()
            AI.dragging = true
        end
    end)
    b:SetScript("OnDragStop", function()
        if not AI.dragging then return end
        AI.dragging = nil
        local f = AI.frame
        local onStop = f:GetScript("OnDragStop")
        if onStop then onStop(f) else f:StopMovingOrSizing() end
    end)
    self.buttons[i] = b
    return b
end

-- Rebuilds the buttons (out of combat only). The icon and the secure item attribute are always set
-- together, so a button never shows one item and uses another.
function AI:Update()
    if not ns.db then return end
    if C.InCombat() then
        self.pending = true
        self:RefreshAll()
        return
    end
    self.pending = nil
    local f = self:Frame()
    local list = (prof().activeItems and prof().showAllFrames and not (prof().autohideRaid and ns.Assist:InRaid())) and self:Collect() or {}
    for i = 1, self.max do
        local b, e = self:Button(i), list[i]
        if e then
            if b.itemID ~= e.itemID then
                b:SetAttribute("item", "item:" .. e.itemID)
                b.itemID = e.itemID
                b.icon:SetTexture(icon(e.itemID))
            end
            b.link = e.link
            b:Show()
            self:Refresh(b)
        else
            b:SetAttribute("item", nil)
            b.itemID, b.link, b.missing = nil, nil, nil
            b:Hide()
        end
    end
    if #list > 0 then
        f:SetWidth(8 + #list * 40)
        f:SetScale(prof().activeItemScale or 1)
        f:Show()
    else
        f:Hide()
    end
end

function AI:Init()
    local function upd() ns:Throttle("activeitems", 0.5, function() AI:Update() end) end
    ns:On("BAG_UPDATE_DELAYED", upd)
    ns:On("BAG_UPDATE", upd)
    ns:On("BAG_UPDATE_COOLDOWN", function() AI:RefreshAll() end)
    ns:On("GET_ITEM_INFO_RECEIVED", function(_, id)
        for _, b in ipairs(AI.buttons) do
            if b.itemID and b.itemID == id then b.icon:SetTexture(icon(id)) end -- same bound item: safe in combat
        end
    end)
    ns:On("PLAYER_REGEN_ENABLED", function() if AI.pending then AI:Update() end end)
    ns:Listen("TBCG_QUESTS_CHANGED", upd)
    ns:Listen("TBCG_GUIDE_CHANGED", upd)
    ns:Listen("TBCG_STEP_CHANGED", upd)
    upd()
end
