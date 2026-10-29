-- TBCGuide - automatic junk selling at vendors
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Off by default (profile.autoSellJunk). When on, opening a merchant sells bag items the game
-- itself classifies as junk: quality 0 ("Poor", grey names). Nothing else is ever a candidate,
-- however cheap. An item is left alone unless EVERY check passes (see Vendor:Classify):
-- item info must be loaded, it must have a sell price, it must not be a quest item, quest
-- starter, guide/quest-log requirement, protected id or protected category.
--
-- Selling = using the item while the merchant window is open (not a protected action in
-- Classic). Items go one at a time with a short gap so the server keeps up; each slot is tried
-- once per visit. Gold is counted only for sales confirmed by the slot actually emptying.

local _, ns = ...

local Vendor = { session = nil }
ns.Vendor = Vendor

local POOR = 0
local SELL_INTERVAL = 0.2    -- seconds between sales
local CONFIRM_DELAY = 0.6    -- seconds before a sale is checked

-- Item classes (GetItemInfo classID) and their default protection. Junk-quality items of these
-- classes are kept by default because they can be useful even when grey.
Vendor.CLASSES = {
    { id = 0, name = "Consumable", protect = true },
    { id = 1, name = "Container", protect = true },
    { id = 2, name = "Weapon", protect = false },
    { id = 4, name = "Armor", protect = false },
    { id = 5, name = "Reagent", protect = true },
    { id = 7, name = "Trade Goods", protect = true },
    { id = 9, name = "Recipe", protect = true },
    { id = 12, name = "Quest", protect = true, locked = true }, -- always protected
    { id = 13, name = "Key", protect = true, locked = true },   -- always protected
    { id = 15, name = "Miscellaneous", protect = false },
}

local QUEST_BIND = 4 -- GetItemInfo bindType: quest item

function Vendor:Init()
    ns:On("MERCHANT_SHOW", function() Vendor:OnMerchantShow() end)
    ns:On("MERCHANT_CLOSED", function() Vendor:Finish() end)
end

function Vendor:IsClassProtected(classID)
    local prot = ns.db.protectedClasses
    for _, c in ipairs(self.CLASSES) do
        if c.id == classID then
            if c.locked then return true end
            if prot[classID] ~= nil then return prot[classID] and true or false end
            return c.protect
        end
    end
    return false
end

-- Item ids needed by the active guide's open quest steps or by quests in the log.
function Vendor:GuideItems()
    local need = {}
    local function addQuest(q)
        for _, id in ipairs(ns.DB.GetQuestItems(q)) do need[id] = true end
    end
    for q in pairs(ns.Tracker.log) do addQuest(q) end
    local E = ns.Engine
    if E.guide then
        for i, s in ipairs(E.guide.steps) do
            local st = E.status[i]
            if s.q and (st == "active" or st == "pending") then addQuest(s.q) end
            if s.item and (st == "active" or st == "pending") then need[s.item] = true end
        end
    end
    return need
end

-- Returns sell(bool), reason. Unknown => keep. Pure function of its inputs (tested headless).
function Vendor:Classify(item, info, guideItems, isQuestSlot)
    if not item or not item.itemID then return false, "no item id" end
    local listed = ns.db.junkList and ns.db.junkList[item.itemID]
    if item.quality ~= POOR and not listed then return false, "not junk quality" end
    if ns.db.protectedItems[item.itemID] then return false, "protected item" end
    if guideItems and guideItems[item.itemID] then return false, "needed by a quest" end
    if isQuestSlot then return false, "quest item" end
    if ns.DB.ItemStartsQuest(item.itemID) then return false, "starts a quest" end
    if not info then return false, "item info not loaded" end
    if info.quality ~= nil and info.quality ~= POOR and not listed then return false, "not junk quality" end
    if info.bindType == QUEST_BIND then return false, "quest item" end
    if info.classID == nil then return false, "unknown item class" end
    if self:IsClassProtected(info.classID) then return false, "protected category" end
    if item.noValue or not info.sellPrice or info.sellPrice <= 0 then return false, "no sell value" end
    if item.locked then return false, "locked" end
    return true
end

-- Whether the item in a player-bag slot is junk by TBCGuide's rules (grey or on the junk list, and
-- not a quest, guide-needed or protected item). Used by the bag markers and bag add-on plugins.
function Vendor:IsJunkAt(bag, slot)
    local C = ns.Compat
    local item = C.GetContainerItem(bag, slot)
    if not item or not item.itemID then return false end
    local info = C.GetItemInfo(item.itemID or item.link)
    if not info then return nil end -- not loaded yet: unknown, not "not junk"
    return (self:Classify(item, info, self:GuideItems(), C.ContainerItemIsQuestItem(bag, slot))) and true or false
end

-- Builds the list of bag slots to sell now.
function Vendor:Scan()
    local C = ns.Compat
    local guideItems = self:GuideItems()
    local list = {}
    for bag = 0, C.NUM_BAGS do
        for slot = 1, C.GetContainerNumSlots(bag) do
            local item = C.GetContainerItem(bag, slot)
            if item and (item.quality == POOR or (ns.db.junkList and ns.db.junkList[item.itemID])) then
                local info = C.GetItemInfo(item.itemID or item.link)
                local ok = self:Classify(item, info, guideItems, C.ContainerItemIsQuestItem(bag, slot))
                if ok then
                    list[#list + 1] = { bag = bag, slot = slot, itemID = item.itemID, count = item.count,
                                        value = info.sellPrice * (item.count or 1), link = item.link or info.name }
                end
            end
        end
    end
    return list
end

function Vendor:OnMerchantShow()
    if not (ns.db.profile.autoSellJunk and ns.db.profile.inventoryManager) then return end
    if ns.Compat.IsModifierHeld() then
        if ns.db.profile.sellNotify then ns:Print("Shift held: junk not sold this time.") end
        return
    end
    if ns.Compat.CursorHasItem() then return end
    local queue = self:Scan()
    if #queue == 0 then return end
    self.session = { queue = queue, pos = 1, tried = {}, sold = 0, earned = 0, failed = {}, pending = 0, open = true }
    self:Step()
end

local function slotKey(e) return e.bag .. ":" .. e.slot end

function Vendor:Step()
    local s = self.session
    if not s or not s.open then return end
    local e = s.queue[s.pos]
    if not e then return self:MaybeReport(s) end
    s.pos = s.pos + 1
    local key = slotKey(e)
    if not s.tried[key] then
        s.tried[key] = true
        -- Re-check the slot right before selling: the player may have moved or used the item.
        local cur = ns.Compat.GetContainerItem(e.bag, e.slot)
        if cur and cur.itemID == e.itemID and not cur.locked and not ns.Compat.CursorHasItem()
            and ns.Compat.UseContainerItem(e.bag, e.slot) then
            s.pending = s.pending + 1
            C_Timer.After(CONFIRM_DELAY, function() Vendor:Confirm(s, e) end)
        end
    end
    if s.queue[s.pos] then
        C_Timer.After(SELL_INTERVAL, function() Vendor:Step() end)
    else
        self:MaybeReport(s)
    end
end

-- A sale counts only once the slot no longer holds that item.
function Vendor:Confirm(s, e)
    s.pending = s.pending - 1
    local cur = ns.Compat.GetContainerItem(e.bag, e.slot)
    if not cur or cur.itemID ~= e.itemID then
        s.sold = s.sold + 1
        s.earned = s.earned + e.value
        if ns.db.profile.sellNotify and ns.db.profile.sellNotifyItems then ns:Print("Sold " .. tostring(e.link)) end
    else
        s.failed[#s.failed + 1] = e
    end
    self:MaybeReport(s)
end

function Vendor:MaybeReport(s)
    if s.pending > 0 then return end
    if s.open and s.queue[s.pos] then return end
    self:Report(s)
end

function Vendor:Report(s)
    if not s or s.reported then return end
    s.reported = true
    if s.sold > 0 then
        local stats = ns.char.junkStats
        stats.items = stats.items + s.sold
        stats.copper = stats.copper + s.earned
        if ns.db.profile.sellNotify then
            ns:Print(string.format("Sold %d junk item%s for %s.", s.sold, s.sold == 1 and "" or "s",
                ns.Compat.FormatMoney(s.earned)))
        end
    end
    if #s.failed > 0 and ns.db.profile.sellNotify then
        ns:Print(#s.failed .. " junk item(s) could not be sold this visit and were left in your bags.")
    end
end

function Vendor:Finish()
    local s = self.session
    if not s then return end
    s.open = false
    self.session = nil
    -- Sales already sent still get confirmed (that only reads bag state), then reported.
    self:MaybeReport(s)
end

-- Protection list helpers (used by /tbcg protect and the options panel) ----------------------

function Vendor.ParseItem(arg)
    if type(arg) == "number" then return arg end
    if type(arg) ~= "string" then return nil end
    return tonumber(string.match(arg, "item:(%d+)")) or tonumber(string.match(arg, "^%s*(%d+)%s*$"))
end

function Vendor:Protect(itemID, on)
    if not itemID then return false end
    ns.db.protectedItems[itemID] = on and true or nil
    return true
end

function Vendor:ProtectedList()
    local out = {}
    for id in pairs(ns.db.protectedItems) do out[#out + 1] = id end
    table.sort(out)
    return out
end
