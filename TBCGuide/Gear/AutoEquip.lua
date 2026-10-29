-- TBCGuide - automatic equipment upgrades (opt-in)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Rules, in this order (docs/AUTO_EQUIP.md):
--   1. Never equip an unbound Bind-on-Equip item, not even into an empty slot. No setting changes this.
--   2. Never equip what the character cannot use now.
--   3. Never in combat, never while the cursor holds something, a trade/merchant/bank/mail/auction
--      window is open, another equip is in progress, or the binding state is unknown.
--   4. An empty slot is filled with any usable non-BoE item (setting "Fill empty slots").
--   5. An occupied slot only gets a positive, certain upgrade under the chosen spec profile.
-- One change at a time: equip, wait for the server to confirm, then look again. Nothing is ever
-- sold, deleted or taken from anywhere but the four bags and the backpack. Bind confirmations are
-- never accepted: if one appears, the item goes back to its bag slot and is not tried again.

local _, ns = ...

local AE = { gen = 0, failed = {}, displaced = {}, windows = {}, retries = 0 }
ns.AutoEquip = AE

local function C() return ns.Compat end
local function U() return ns.Upgrade end
local function prof() return ns.db.profile end

AE.CONFIRM_TIMEOUT = 2.0   -- seconds to wait for the server to confirm an equip
AE.MAX_RETRIES = 10        -- item-data retries before waiting for the next bag/equipment event

local function now() return GetTime and GetTime() or 0 end
local function pickup(bag, slot)
    local f = C().Has("C_Container.PickupContainerItem") or C().Has("PickupContainerItem")
    if f then f(bag, slot) return true end
end
local function equippedId(slot)
    local f = C().Has("GetInventoryItemID")
    if f then return f("player", slot) end
    local l = C().Has("GetInventoryItemLink")
    l = l and l("player", slot)
    return l and tonumber(string.match(l, "item:(%d+)")) or nil
end

function AE:FreeSlots()
    local f = C().Has("C_Container.GetContainerNumFreeSlots") or C().Has("GetContainerNumFreeSlots")
    if not f then return nil end
    local n = 0
    for bag = 0, C().NUM_BAGS do n = n + (f(bag) or 0) end
    return n
end

-- Why automatic equipping cannot run right now, or nil.
function AE:Blocked()
    if C().InCombat() then return "in combat" end
    if C().CursorHasItem() then return "the cursor holds an item" end
    for w in pairs(self.windows) do return "the " .. w .. " window is open" end
    if self.busy then return "another equip is in progress" end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "dead" end
    return nil
end

-- Scheduling ---------------------------------------------------------------------------------------------

-- Debounced: event bursts (looting, sorting) collapse into one pass.
function AE:Schedule(delay)
    if not ns.db then return end
    self.gen = self.gen + 1
    local g = self.gen
    C_Timer.After(delay or 0.4, function() if g == AE.gen then AE:Run() end end)
end

-- One pass: evaluate the bags, refresh the markers, then maybe equip ONE item.
function AE:Run()
    if self.busy then return end
    local list, ctx, pending, why = U():ScanBags()
    if ns.GearMarkers then ns.GearMarkers:Update(list) end
    if pending then
        -- Missing item data: wait for it instead of scoring it as nothing.
        if self.retries < self.MAX_RETRIES then self.retries = self.retries + 1 self:Schedule(1) end
        return
    end
    self.retries = 0
    self.status = why
    if not ctx or not prof().gearEnabled or not prof().autoEquip then return end
    local blocked = self:Blocked()
    if blocked then self.deferred = blocked return end
    self.deferred = nil
    local pick = self:Choose(list)
    if pick then self:Execute(pick, ctx) end
end

-- The action to take: empty slots first (best score), then the biggest certain upgrade.
function AE:Choose(list)
    local best
    for _, e in ipairs(list) do
        local d = e.item
        local key = d.id and (d.id .. ":" .. tostring(e.target))
        local ok = e.ok and e.kind and e.bind and e.bind ~= "boe" and not d.locked
            and not self.failed[key] and not (d.id and self.displaced[d.id])
        if ok and e.kind == "empty" and not prof().autoEquipEmpty then ok = false end
        if ok and e.kind == "upgrade" and e.uncertain then ok = false end
        if ok then
            if not best then best = e
            elseif e.kind == "empty" and best.kind ~= "empty" then best = e
            elseif e.kind == best.kind then
                local a = e.kind == "empty" and e.newScore or e.delta
                local b = best.kind == "empty" and best.newScore or best.delta
                if a > b then best = e end
            end
        end
    end
    return best
end

-- Execution ------------------------------------------------------------------------------------------------

-- Equips e.item into e.target after revalidating everything. One attempt; a failure is remembered
-- for the session so it is never retried in a loop.
function AE:Execute(e, ctx)
    local d = e.item
    local key = d.id .. ":" .. e.target
    local cur = C().GetContainerItem(d.bag, d.slot)
    if not cur or cur.itemID ~= d.id or cur.locked then return self:Schedule(1) end
    -- Recheck the item in place: binding, usability, score, profile.
    local fresh = U():BagItem(d.bag, d.slot)
    local again = fresh and U():Evaluate(fresh, ctx)
    if not again or not again.ok or again.kind ~= e.kind or again.target ~= e.target or again.bind ~= e.bind
        or again.bind == "boe" or not again.bind then
        return self:Schedule(1)
    end
    -- Displaced items need room: equipping from a bag frees that bag slot for one of them.
    local free = self:FreeSlots()
    if again.displaced > 1 and (free == nil or free < again.displaced - 1) then
        self.failed[key] = true
        self.lastError = "not enough bag space to swap " .. tostring(d.link)
        return self:Schedule(0.5) -- go on with the next candidate; this one is not retried
    end
    local equip = C().Has("EquipCursorItem")
    if not equip or not pickup(d.bag, d.slot) then self.failed[key] = true return self:Schedule(0.5) end
    if not C().CursorHasItem() then self.failed[key] = true return self:Schedule(1) end
    self.busy = { e = again, key = key, id = d.id, target = again.target, bag = d.bag, slot = d.slot,
                  profile = ctx.profile, deadline = now() + self.CONFIRM_TIMEOUT }
    equip(again.target)
    if C().CursorHasItem() then
        -- Refused (or a bind confirmation is waiting): put it back where it was.
        self:Abort("the client did not equip it")
        return
    end
    C_Timer.After(0.3, function() AE:Verify() end)
    C_Timer.After(self.CONFIRM_TIMEOUT + 0.1, function() AE:Verify(true) end)
end

function AE:Abort(why)
    local b = self.busy
    if not b then return end
    if C().CursorHasItem() then
        pickup(b.bag, b.slot)
        if C().CursorHasItem() and ClearCursor then ClearCursor() end
    end
    self.failed[b.key] = true
    self.lastError = why
    self.busy = nil
    self:Schedule(1)
end

-- Success only when the server shows the item in the target slot.
function AE:Verify(final)
    local b = self.busy
    if not b then return end
    if equippedId(b.target) == b.id then
        self.busy = nil
        for _, r in ipairs(b.e.replaced or {}) do if r.id then self.displaced[r.id] = true end end
        self.failed[b.key] = true -- never move the same item into the same slot twice in a session
        if ns.GearMarkers then ns.GearMarkers:Notify(b.e, b.profile) end
        self:Schedule(0.5)
    elseif final or now() >= b.deadline then
        self:Abort("not confirmed by the server")
    end
end

-- A bind confirmation means the item was not what the evaluator thought: never accept it.
function AE:OnBindConfirm()
    if not self.busy then return end
    if StaticPopup_Hide then StaticPopup_Hide("EQUIP_BIND") StaticPopup_Hide("AUTOEQUIP_BIND") end
    self:Abort("the item asked to bind; nothing was equipped")
end

-- Settings / profile --------------------------------------------------------------------------------------

function AE:OnProfileChanged()
    U():Reset()
    self.failed, self.displaced = {}, {}
    self:Schedule(0.2)
    if ns.AHUpgrades then ns.AHUpgrades:Refresh() end -- re-score cached auctions, no rescan
    if ns.TalentHints then ns.TalentHints:Refresh() end -- the talent plan follows the spec profile
end

function AE:Status()
    local p, why = U():ActiveProfile()
    if not prof().autoEquip then return "off" end
    if not p then return "waiting: " .. why end
    if self.busy then return "equipping" end
    if self.deferred then return "waiting: " .. self.deferred end
    return "on (" .. U():ProfileName(p) .. ")"
end

function AE:Init()
    local function sched() AE:Schedule() end
    ns:On("BAG_UPDATE_DELAYED", sched)
    ns:On("BAG_UPDATE", sched)
    ns:On("PLAYER_EQUIPMENT_CHANGED", function()
        if AE.busy then C_Timer.After(0.1, function() AE:Verify() end) else sched() end
    end)
    ns:On("PLAYER_REGEN_ENABLED", sched)
    ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(1, sched) end)
    ns:On("GET_ITEM_INFO_RECEIVED", sched)
    ns:On("CHARACTER_POINTS_CHANGED", sched)
    ns:On("EQUIP_BIND_CONFIRM", function() AE:OnBindConfirm() end)
    ns:On("AUTOEQUIP_BIND_CONFIRM", function() AE:OnBindConfirm() end)
    for open, close in pairs({ MERCHANT_SHOW = "MERCHANT_CLOSED", TRADE_SHOW = "TRADE_CLOSED", BANKFRAME_OPENED = "BANKFRAME_CLOSED",
                               MAIL_SHOW = "MAIL_CLOSED", AUCTION_HOUSE_SHOW = "AUCTION_HOUSE_CLOSED" }) do
        local name = string.lower((string.gsub(string.gsub(open, "_SHOW", ""), "FRAME_OPENED", "")))
        ns:On(open, function() AE.windows[name] = true end)
        ns:On(close, function() AE.windows[name] = nil sched() end)
    end
    -- Login and zoning fire many bag events; the first pass waits until they settle.
    ns:On("PLAYER_ENTERING_WORLD", function() AE:Schedule(3) end)
    self:Schedule(3)
end
