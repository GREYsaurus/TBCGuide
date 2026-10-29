-- TBCGuide - active item window: one-click buttons for usable quest items in your bags
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Shows the usable items ("Use:" on the item) that belong to quests: quest items in your bags and
-- items the current guide's quests need. Each button is a secure item button, so clicking it uses
-- the item exactly like clicking it in your bags. Secure buttons cannot be changed in combat, so
-- the list updates when combat ends.

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

-- { {itemID, count, link} } in bag order, at most AI.max.
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
                    out[#out + 1] = { itemID = id, link = it.link, count = it.count }
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

function AI:Button(i)
    local b = self.buttons[i]
    if b then return b end
    b = CreateFrame("Button", "TBCGuideActiveItem" .. i, self:Frame(), "SecureActionButtonTemplate")
    b:SetSize(36, 36)
    b:SetPoint("LEFT", self.frame, "LEFT", 4 + (i - 1) * 40, 0)
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("type", "item")
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    b.icon = t
    local c = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    c:SetPoint("BOTTOMRIGHT", -2, 2)
    b.count = c
    b:SetScript("OnEnter", function(s)
        if not s.link then return end
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetHyperlink(s.link)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.buttons[i] = b
    return b
end

-- Rebuilds the buttons (out of combat only).
function AI:Update()
    if not ns.db then return end
    if C.InCombat() then self.pending = true return end
    self.pending = nil
    local f = self:Frame()
    local list = (prof().activeItems and prof().showAllFrames and not (prof().autohideRaid and ns.Assist:InRaid())) and self:Collect() or {}
    for i = 1, self.max do
        local b, e = self:Button(i), list[i]
        if e then
            b:SetAttribute("item", "item:" .. e.itemID)
            b.link = e.link
            b.icon:SetTexture(icon(e.itemID))
            b.count:SetText((e.count or 1) > 1 and e.count or "")
            b:Show()
        else
            b:SetAttribute("item", nil)
            b.link = nil
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
    ns:On("PLAYER_REGEN_ENABLED", function() if AI.pending then AI:Update() end end)
    ns:Listen("TBCG_QUESTS_CHANGED", upd)
    ns:Listen("TBCG_GUIDE_CHANGED", upd)
    upd()
end
