-- TBCGuide - BoE upgrade markers on bag buttons, upgrade lines on bag tooltips, equip notifications
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Everything shown here comes from Gear/Upgrade.lua's evaluation, the same one automatic
-- equipping uses. Bag support: the default bag frames (ContainerFrame1..N). Other bag add-ons are
-- not supported; docs/AUTO_EQUIP.md lists what is known.

local _, ns = ...

-- Overlay textures by button, kept outside the button table (bag buttons belong to Blizzard's UI).
-- external: buttons of bag add-ons (UI/BagAdapters.lua) -> function returning bag, slot (or nil
-- when the button shows something other than the player's own bags: bank, offline characters).
local M = { marks = {}, junk = {}, queue = {}, overlays = setmetatable({}, { __mode = "k" }),
            coins = setmetatable({}, { __mode = "k" }), vendor = {}, external = setmetatable({}, { __mode = "k" }),
            tipOnly = setmetatable({}, { __mode = "k" }) } -- buttons whose add-on draws the marker itself (Baganator)
ns.GearMarkers = M

local function prof() return ns.db.profile end

M.ICON = "Interface\\Buttons\\UI-MicroStream-Green" -- small green arrow
M.COIN = "Interface\\Buttons\\UI-GroupLoot-Coin-Up" -- junk (sold or deleted by the inventory manager)
M.MAX_FRAMES = 13

-- A marker means: unbound BoE, usable now, and a certain upgrade or an empty-slot fill.
function M:Qualifies(e)
    return e and e.ok and e.bind == "boe" and (e.kind == "empty" or (e.kind == "upgrade" and not e.uncertain))
end

function M:Update(list)
    self.marks = {}
    if prof().gearEnabled and prof().boeMarkers then
        for _, e in ipairs(list or {}) do
            if self:Qualifies(e) then self.marks[e.item.bag .. ":" .. e.item.slot] = e end
        end
    end
    -- Junk indicator: the same items the inventory manager would sell.
    self.junk = {}
    if prof().junkIndicator and prof().inventoryManager and ns.Vendor then
        for _, j in ipairs(ns.Vendor:Scan()) do self.junk[j.bag .. ":" .. j.slot] = j.itemID or true end
    end
    self:RefreshAll()
    if ns.BagAdapters then ns.BagAdapters:Refresh() end
end

local function coin(button)
    local t = M.coins[button]
    if not t and button.CreateTexture then
        t = button:CreateTexture(nil, "OVERLAY")
        t:SetTexture(M.COIN)
        t:SetSize(14, 14)
        t:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
        M.coins[button] = t
    end
    return t
end

local function overlay(button)
    local t = M.overlays[button]
    if not t and button.CreateTexture then
        t = button:CreateTexture(nil, "OVERLAY")
        t:SetTexture(M.ICON)
        t:SetSize(14, 14)
        t:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        M.overlays[button] = t
    end
    return t
end

-- The one place markers are drawn, for the default bags and every bag add-on. `bag`/`slot` = the
-- player-bag slot the button shows, or nil (bank, offline character, empty): then nothing is shown.
-- A mark only shows while the slot still holds the item it was computed for, so a moved or
-- recycled button never keeps a stale icon. Both markers can show at once (arrow top left, coin
-- bottom left); neither hides the other.
function M:Decorate(b, bag, slot, shown)
    local key = (bag and slot) and (bag .. ":" .. slot) or nil
    local e = key and self.marks[key]
    local j = key and self.junk[key]
    if (e or j) and key then
        local cur = ns.Compat.GetContainerItem(bag, slot)
        local id = cur and cur.itemID
        if e and e.item.id ~= id then e = nil end
        if j and j ~= true and j ~= id then j = nil end
    end
    if j and shown ~= false then
        local c = coin(b)
        if c then c:Show() end
    elseif self.coins[b] then
        self.coins[b]:Hide()
    end
    if e and shown ~= false then
        local t = overlay(b)
        if t then t:Show() end
    elseif self.overlays[b] then
        self.overlays[b]:Hide()
    end
end

-- Default bag frames.
function M:RefreshFrame(frame)
    if not frame or not frame.GetID or not frame.GetName then return end
    local name, bag = frame:GetName(), frame:GetID()
    if not name or not bag then return end
    local shown = frame.IsShown and frame:IsShown()
    local own = bag >= 0 and bag <= ns.Compat.NUM_BAGS
    for i = 1, frame.size or 36 do
        local b = _G[name .. "Item" .. i]
        if not b then break end
        self:Decorate(b, own and bag or nil, b.GetID and b:GetID() or i, shown)
    end
end

-- A bag add-on's button (adapter supplies how to read its bag/slot).
function M:RegisterButton(b, resolve)
    self.external[b] = resolve
    local ok, bag, slot = pcall(resolve, b)
    self:Decorate(b, ok and bag or nil, ok and slot or nil, b.IsVisible and b:IsVisible() or nil)
end

function M:RefreshAll()
    for i = 1, NUM_CONTAINER_FRAMES or self.MAX_FRAMES do self:RefreshFrame(_G["ContainerFrame" .. i]) end
    for b, resolve in pairs(self.external) do
        local ok, bag, slot = pcall(resolve, b)
        self:Decorate(b, ok and bag or nil, ok and slot or nil, b.IsVisible and b:IsVisible() or nil)
    end
end

-- Tooltip lines for a bag slot (marker details for BoE items, the upgrade verdict for others).
function M:TooltipLines(bag, slot, itemID)
    local e = ns.Upgrade.last[bag .. ":" .. slot]
    if not e or not e.ok or not e.kind then return nil end
    if itemID and e.item.id ~= itemID then return nil end -- the slot holds something else now
    local p = ns.Upgrade:ActiveProfile()
    if not p then return nil end
    local lines = {}
    local green = { 0.3, 1, 0.3 }
    lines[#lines + 1] = { "TBCGuide: upgrade for " .. ns.Upgrade:ProfileName(p), green }
    if e.kind == "empty" then
        lines[#lines + 1] = { "  Empty slot (" .. (ns.Gear.SLOT_NAMES[e.target] or e.target) .. ")", green }
    else
        lines[#lines + 1] = { "  " .. ns.Upgrade.PctText(e), green }
        local names = {}
        for _, r in ipairs(e.replaced or {}) do names[#names + 1] = tostring(r.link or r.name) end
        lines[#lines + 1] = { "  Replaces " .. table.concat(names, " + ") .. " (" .. (ns.Gear.SLOT_NAMES[e.target] or e.target) .. ")", { 0.8, 0.8, 0.8 } }
    end
    if e.uncertain then lines[#lines + 1] = { "  Uncertain: " .. e.uncertain .. " (not scored)", { 1, 0.6, 0.2 } } end
    if e.bind == "boe" then
        lines[#lines + 1] = { "  Bind on Equip - manual equip required.", { 1, 0.82, 0 } }
    elseif not e.bind then
        lines[#lines + 1] = { "  Binding unknown - not equipped automatically.", { 1, 0.6, 0.2 } }
    end
    if e.heuristic and #e.heuristic > 0 then lines[#lines + 1] = { "  Estimate: " .. table.concat(e.heuristic, "; "), { 0.6, 0.6, 0.6 } } end
    return lines
end

-- Called by GearUI's tooltip hook with the tooltip's owner (a bag item button).
function M:AddToTooltip(tt)
    if not prof().gearEnabled or not tt.GetOwner then return end
    local owner = tt:GetOwner()
    if not owner then return end
    local bag, slot
    local resolve = self.external[owner] or self.tipOnly[owner]
    if resolve then
        local ok, b, s = pcall(resolve, owner)
        if ok then bag, slot = b, s end
    else
        local parent = owner.GetParent and owner:GetParent()
        if not (parent and owner.GetID and parent.GetID) then return end
        local pname = parent.GetName and parent:GetName()
        if not (pname and string.find(pname, "^ContainerFrame%d+$")) then return end
        bag, slot = parent:GetID(), owner:GetID()
        if bag < 0 or bag > ns.Compat.NUM_BAGS then return end
    end
    if not (bag and slot) then return end
    local _, link = tt:GetItem()
    local lines = self:TooltipLines(bag, slot, link and tonumber(string.match(link, "item:(%d+)")))
    for _, l in ipairs(lines or {}) do tt:AddLine(l[1], l[2][1], l[2][2], l[2][3]) end
end

-- Notifications ---------------------------------------------------------------------------------------------

-- "Auto-equipped: [Item] - +8.4% estimated spec score (Frost)" / "- Empty slot filled (Head)".
function M.NotifyText(e, p)
    local d = e.item
    local tail
    if e.kind == "empty" then
        tail = "Empty slot filled (" .. (ns.Gear.SLOT_NAMES[e.target] or e.target) .. ")"
    else
        tail = ns.Upgrade.PctText(e) .. " (" .. ns.Upgrade:ProfileName(p) .. ")"
    end
    return "Auto-equipped: " .. tostring(d.link or d.name) .. " - " .. tail
end

function M:Notify(e, p)
    local text = self.NotifyText(e, p)
    if prof().equipChat then ns:Print(text) end
    if not prof().equipNotify then return end
    -- At most three toasts queued; anything beyond goes to chat so a login burst cannot spam.
    if #self.queue >= 3 then
        if not prof().equipChat then ns:Print(text) end
        return
    end
    self.queue[#self.queue + 1] = { text = text, icon = e.item.texture }
    if not self.showing then self:ShowNext() end
end

function M:Toast()
    if self.toast then return self.toast end
    local W = ns.Widgets
    local f = W.Panel("TBCGuideEquipToast", UIParent, 420, 46)
    f:SetPoint("TOP", UIParent, "TOP", 0, -140)
    f:SetFrameStrata("HIGH")
    if f.EnableMouse then f:EnableMouse(false) end
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", 8, 0)
    local text = W.Text(f, "GameFontHighlight", "LEFT")
    text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    text:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    f.icon, f.text = icon, text
    f:Hide()
    self.toast = f
    return f
end

M.TOAST_TIME = 4

function M:ShowNext()
    local item = table.remove(self.queue, 1)
    local f = self:Toast()
    if not item then self.showing = false f:Hide() return end
    self.showing = true
    f.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.text:SetText(item.text)
    f.left = self.TOAST_TIME
    f:SetAlpha(1)
    f:Show()
    f:SetScript("OnUpdate", function(s, el)
        s.left = s.left - el
        if s.left < 0.6 then s:SetAlpha(math.max(0, s.left / 0.6)) end
        if s.left <= 0 then s:SetScript("OnUpdate", nil) M:ShowNext() end
    end)
end

-- Vendor treasures ---------------------------------------------------------------------------------------
-- Items a merchant sells that are upgrades for your spec profile (same evaluation as everywhere
-- else), marked on the merchant buttons and listed once in chat when the merchant opens.

function M:ScanMerchant()
    self.vendor = {}
    local p = prof()
    if not (p.gearEnabled and p.vendorTreasures) or not (GetMerchantNumItems and GetMerchantItemLink) then return {} end
    local ctx = ns.Upgrade:Context()
    if not ctx then return {} end
    local found = {}
    for i = 1, GetMerchantNumItems() or 0 do
        local link = GetMerchantItemLink(i)
        local d = link and ns.Gear:ItemData(link)
        if d and ns.Gear:IsEquippable(d) then
            d.tip = ns.Upgrade:Classify(ns.Upgrade.ScanLines("merchant", i), d)
            local e = ns.Upgrade:Evaluate(d, ctx)
            if e.ok and (e.kind == "empty" or (e.kind == "upgrade" and not e.uncertain)) then
                self.vendor[i] = e
                found[#found + 1] = { index = i, e = e }
            end
        end
    end
    return found
end

function M:OnMerchantShow()
    local found = self:ScanMerchant()
    if #found > 0 then
        ns:Print("Vendor treasures (upgrades for " .. ns.Upgrade:ProfileName(ns.Upgrade:ActiveProfile()) .. "):")
        for _, f in ipairs(found) do
            local price = GetMerchantItemInfo and select(3, GetMerchantItemInfo(f.index))
            DEFAULT_CHAT_FRAME:AddMessage("  " .. tostring(f.e.item.link) .. " - " .. ns.Upgrade.PctText(f.e)
                .. (type(price) == "number" and price > 0 and (" (" .. ns.Compat.FormatMoney(price) .. ")") or ""))
        end
    end
    self:RefreshMerchant()
end

function M:RefreshMerchant()
    local per = MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame and MerchantFrame.page or 1
    for j = 1, per do
        local b = _G["MerchantItem" .. j .. "ItemButton"]
        if b then
            local e = self.vendor[(page - 1) * per + j]
            if e and MerchantFrame and MerchantFrame.selectedTab ~= 2 then
                local t = overlay(b)
                if t then t:Show() end
            elseif self.overlays[b] then
                self.overlays[b]:Hide()
            end
        end
    end
end

function M:Init()
    ns:On("MERCHANT_SHOW", function() C_Timer.After(0.2, function() M:OnMerchantShow() end) end)
    ns:On("MERCHANT_CLOSED", function() M.vendor = {} M:RefreshMerchant() end)
    if hooksecurefunc and MerchantFrame_UpdateMerchantInfo then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() M:RefreshMerchant() end)
    end
    if hooksecurefunc and ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", function(frame) M:RefreshFrame(frame) end)
    end
    ns:On("BAG_OPEN", function() M:RefreshAll() end)
end
