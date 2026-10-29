-- TBCGuide - auction house upgrades: a user-started scan and an "Upgrades" tab in the auction window
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- TBCGuide's own feature (ns.AHUpgrades); unrelated to the third-party "Auctioneer" add-on and
-- uses no global names besides its frames (TBCGuideAH*) and the tab the auction UI requires
-- (AuctionFrameTab<n>, the next free number).
--
-- The TBC Classic client has the legacy auction API: QueryAuctionItems (50 results per page,
-- throttled by CanSendAuctionQuery) answered by AUCTION_ITEM_LIST_UPDATE. The scan pages through
-- gear (weapons and armor) usable by this character, uncommon or better, up to your level. It never
-- bids, buys or cancels anything. A search started by you or another add-on stops the scan (the
-- results so far are kept and marked partial). docs/AUCTION.md.

local _, ns = ...

local AU = { state = "idle", items = {}, rows = {}, filter = { slot = "all", maxGold = nil, minPct = 0, sort = "pct", uncertain = false } }
ns.AHUpgrades = AU

local C = ns.Compat
local function prof() return ns.db.profile end
local function now() return GetTime and GetTime() or 0 end
local function epoch() return time and time() or 0 end

AU.PER_PAGE = 50
AU.MAX_PAGES = 120          -- 6000 listings: bounds a scan on very large auction houses
AU.MAX_ITEMS = 4000         -- distinct variants kept per auction house
AU.PAGE_TIMEOUT = 15        -- seconds to wait for one page before giving up
AU.MIN_QUALITY = 2          -- uncommon and better
AU.STALE_AFTER = 2 * 3600   -- a scan older than this is shown as stale

-- Data ---------------------------------------------------------------------------------------------

-- One dataset per realm and faction auction house. Neutral (goblin) auction houses share the
-- faction key: the client does not say which auction house is open.
function AU:Key()
    return tostring(GetRealmName and GetRealmName() or "?") .. "-" .. tostring(C.PlayerInfo().faction or "?")
end

function AU:Store()
    if type(ns.db.auctionScans) ~= "table" then ns.db.auctionScans = {} end
    return ns.db.auctionScans
end

function AU:Dataset() return self:Store()[self:Key()] end

-- "item:<id>:<enchant>:<gems x4>:<suffix>:..." -> "<id>:<suffix>", so random-suffix variants
-- ("of the Bear", "of the Monkey") are kept apart while copies of the same item are merged.
function AU.VariantKey(link)
    local s = type(link) == "string" and string.match(link, "item:([%-%d:]+)")
    if not s then return nil end
    local f = {}
    for v in string.gmatch(s .. ":", "(%-?%d*):") do f[#f + 1] = v end
    local id = tonumber(f[1])
    if not id then return nil end
    local suffix = tonumber(f[7]) or 0
    return id .. ":" .. suffix, id
end

-- Scanning -------------------------------------------------------------------------------------------

local function ahOpen() return AuctionFrame and AuctionFrame:IsShown() and true or false end

function AU:CanQuery()
    local f = C.Has("CanSendAuctionQuery")
    if not f then return false end
    return f() and true or false
end

function AU:Start()
    if not prof().auctioneer then return false, "Auctioneer is off" end
    if not ahOpen() then return false, "open the auction house first" end
    if self.state == "scanning" then return false, "a scan is already running" end
    if not C.Has("QueryAuctionItems") then return false, "this client has no auction query function" end
    self.state = "scanning"
    self.page, self.pages, self.seen = 0, nil, 0
    self.found, self.missing, self.noBuyout = {}, 0, 0
    self.startedAt = epoch()
    self.gen = (self.gen or 0) + 1
    self.status = "Starting..."
    self:Next()
    self:UpdateStatus()
    return true
end

-- Filter for the gear classes (weapons 2, armor 4); older clients ignore the argument.
local FILTER = { { classID = 2 }, { classID = 4 } }

function AU:Next()
    if self.state ~= "scanning" then return end
    if not ahOpen() then return self:Finish(false, "the auction house was closed") end
    if not self:CanQuery() then
        C_Timer.After(0.3, function() AU:Next() end)
        return
    end
    local q = C.Has("QueryAuctionItems")
    local level = UnitLevel and UnitLevel("player") or 70
    self.waiting = { page = self.page, at = now(), gen = self.gen }
    self.sending = true
    local ok = pcall(q, "", 0, level, self.page, true, self.MIN_QUALITY, false, false, FILTER)
    self.sending = false
    if not ok then return self:Finish(false, "the auction query failed") end
    local gen, page = self.gen, self.page
    C_Timer.After(self.PAGE_TIMEOUT, function()
        if AU.waiting and AU.waiting.gen == gen and AU.waiting.page == page and AU.state == "scanning" then
            AU:Finish(false, "the server did not answer (timeout)")
        end
    end)
end

-- AUCTION_ITEM_LIST_UPDATE: read the page we asked for.
function AU:OnListUpdate()
    local w = self.waiting
    if self.state ~= "scanning" or not w then return end
    local numF, infoF, linkF = C.Has("GetNumAuctionItems"), C.Has("GetAuctionItemInfo"), C.Has("GetAuctionItemLink")
    if not (numF and infoF and linkF) then return self:Finish(false, "auction list functions are missing") end
    local batch, total = numF("list")
    batch, total = batch or 0, total or 0
    -- Item details can arrive a moment after the list; give the page one more chance.
    local incomplete = false
    for i = 1, batch do
        local info = { infoF("list", i) }
        if info[18] == false or not linkF("list", i) then incomplete = true break end
    end
    if incomplete and not w.retried then
        w.retried = true
        C_Timer.After(0.6, function() if AU.waiting == w then AU:OnListUpdate() end end)
        return
    end
    self.waiting = nil
    for i = 1, batch do
        local _, _, count, _, _, _, _, _, _, buyout = infoF("list", i)
        local link = linkF("list", i)
        local key, id = AU.VariantKey(link)
        if not key then
            self.missing = self.missing + 1
        elseif not buyout or buyout <= 0 then
            self.noBuyout = self.noBuyout + 1
        else
            count = math.max(count or 1, 1)
            local unit = math.floor(buyout / count + 0.5)
            local e = self.found[key]
            if not e then
                e = { link = link, id = id, listings = 0 }
                self.found[key] = e
            end
            e.listings = e.listings + 1
            if not e.unit or unit < e.unit then e.unit, e.buyout, e.count, e.link = unit, buyout, count, link end
        end
        self.seen = self.seen + 1
    end
    self.pages = math.max(1, math.ceil(total / self.PER_PAGE))
    self.page = self.page + 1
    self.status = string.format("Scanning page %d of %d", math.min(self.page, self.pages), self.pages)
    self:UpdateStatus()
    if self.page >= self.pages then return self:Finish(true) end
    if self.page >= self.MAX_PAGES then return self:Finish(false, "stopped after " .. self.MAX_PAGES .. " pages") end
    C_Timer.After(0.1, function() AU:Next() end)
end

-- Ends a scan and saves what was collected (complete or partial).
function AU:Finish(complete, why)
    if self.state ~= "scanning" then return end
    self.state = complete and "done" or "partial"
    self.waiting = nil
    local items, n = {}, 0
    for k, e in pairs(self.found or {}) do
        if n >= self.MAX_ITEMS then break end
        items[k] = e
        n = n + 1
    end
    if n > 0 or complete then
        local store = self:Store()
        store[self:Key()] = { at = epoch(), started = self.startedAt, complete = complete and true or false,
                              pages = self.page, listings = self.seen, noBuyout = self.noBuyout, items = items, note = why }
        -- Keep the three most recent auction houses only.
        local keys = {}
        for k, d in pairs(store) do keys[#keys + 1] = { k = k, at = d.at or 0 } end
        table.sort(keys, function(a, b) return a.at > b.at end)
        for i = 4, #keys do store[keys[i].k] = nil end
    end
    self.status = complete and string.format("Scan complete: %d listings, %d items with a buyout", self.seen, n)
        or ("Scan stopped: " .. tostring(why) .. string.format(" (%d listings kept, partial)", self.seen))
    self:UpdateStatus()
    self:Refresh()
end

function AU:Cancel() if self.state == "scanning" then self:Finish(false, "cancelled") end end

-- A query we did not send (the player's search or another add-on) takes over the result list.
function AU:OnForeignQuery()
    if self.state == "scanning" and not self.sending then self:Finish(false, "another auction search was started") end
end

-- Upgrades -----------------------------------------------------------------------------------------------

function AU:Age(ds)
    if not ds or not ds.at then return nil end
    return epoch() - ds.at
end

function AU.Money(c)
    if not c then return "-" end
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return C.FormatMoney(c)
end

-- Evaluated rows { e, entry, slot } with the shared upgrade evaluator, filters applied.
-- Returns rows, why (nil, "no scan data" / profile reason).
function AU:Upgrades()
    local ds = self:Dataset()
    if not ds or not ds.items or next(ds.items) == nil then return {}, "No scan data. Press Scan to look at the auction house." end
    local ctx, why = ns.Upgrade:Context()
    if not ctx then return {}, why == "uncached" and "Loading your equipped items..." or ("Choose a spec profile first (" .. tostring(why) .. ").") end
    ctx.minPct = 0
    local f = self.filter
    local out, loading = {}, 0
    for _, entry in pairs(ds.items) do
        local d = ns.Gear:ItemData(entry.link)
        if not d then
            loading = loading + 1
        elseif ns.Gear:IsEquippable(d) then
            d.tip = ns.Upgrade:Classify(ns.Upgrade.ScanLines("link", entry.link), d)
            local e = ns.Upgrade:Evaluate(d, ctx)
            local ok = e.ok and (e.kind == "empty" or e.kind == "upgrade")
            if ok and e.uncertain and not f.uncertain then ok = false end
            if ok and f.slot ~= "all" and tostring(e.target) ~= tostring(f.slot) then ok = false end
            if ok and f.maxGold and entry.unit > f.maxGold * 10000 then ok = false end
            if ok and e.kind == "upgrade" and (f.minPct or 0) > 0 and not (e.pct and e.pct >= f.minPct) then ok = false end
            if ok then out[#out + 1] = { e = e, entry = entry, slot = e.target } end
        end
    end
    local byPct = f.sort == "pct"
    table.sort(out, function(a, b)
        if a.slot ~= b.slot then return a.slot < b.slot end
        if byPct then
            local pa = a.e.kind == "empty" and math.huge or (a.e.pct or -1)
            local pb = b.e.kind == "empty" and math.huge or (b.e.pct or -1)
            if pa ~= pb then return pa > pb end
        end
        return a.entry.unit < b.entry.unit
    end)
    self.loading = loading
    return out
end

-- UI -----------------------------------------------------------------------------------------------------

local W = ns.Widgets

function AU:StatusText()
    local ds = self:Dataset()
    local parts = {}
    if self.state == "scanning" then parts[#parts + 1] = self.status or "Scanning..." end
    if ds then
        local age = self:Age(ds) or 0
        local mins = math.floor(age / 60)
        local kind = ds.complete and "complete" or "partial"
        if age > self.STALE_AFTER then kind = kind .. ", stale" end
        parts[#parts + 1] = string.format("Last scan %s ago (%s, %d listings)", mins >= 60 and (math.floor(mins / 60) .. " h") or (mins .. " min"), kind, ds.listings or 0)
    elseif self.state ~= "scanning" then
        parts[#parts + 1] = "No scan data"
    end
    if self.state ~= "scanning" and self.status and self.state ~= "idle" then parts[#parts + 1] = self.status end
    return table.concat(parts, "  |  ")
end

function AU:UpdateStatus()
    if not self.panel then return end
    self.panel.status:SetText(self:StatusText())
    if self.state == "scanning" then self.scanBtn:Disable() self.cancelBtn:Enable() else self.scanBtn:Enable() self.cancelBtn:Disable() end
end

local function row(parent, i)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(22)
    local icon = r:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 2, 0)
    r.icon = icon
    r.name = W.Text(r, "GameFontHighlightSmall", "LEFT")
    r.name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    r.name:SetWidth(230)
    r.name:SetWordWrap(false)
    r.lvl = W.Text(r, "GameFontHighlightSmall", "CENTER")
    r.lvl:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    r.lvl:SetWidth(30)
    r.price = W.Text(r, "GameFontHighlightSmall", "RIGHT")
    r.price:SetPoint("LEFT", r.lvl, "RIGHT", 4, 0)
    r.price:SetWidth(110)
    r.pct = W.Text(r, "GameFontHighlightSmall", "RIGHT")
    r.pct:SetPoint("LEFT", r.price, "RIGHT", 6, 0)
    r.pct:SetWidth(150)
    r.cmp = W.Text(r, "GameFontDisableSmall", "LEFT")
    r.cmp:SetPoint("LEFT", r.pct, "RIGHT", 10, 0)
    r.cmp:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.cmp:SetWordWrap(false)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    W.Color(hl, W.THEME.hover, 0.5)
    r.header = W.Text(r, "GameFontNormal", "LEFT")
    r.header:SetPoint("LEFT", 4, 0)
    r.header:SetTextColor(W.THEME.accent[1], W.THEME.accent[2], W.THEME.accent[3])
    r:SetScript("OnEnter", function(s)
        if not s.link then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(s.link)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(s) if s.link then AU:SearchFor(s.itemName) end end)
    return r
end

-- Selecting a result searches the Browse tab for it (live listings; buying stays your action).
function AU:SearchFor(name)
    if not name or not BrowseName then return end
    local tab = _G["AuctionFrameTab1"]
    if tab and tab.Click then tab:Click() end
    BrowseName:SetText(name)
    if AuctionFrameBrowse_Search then AuctionFrameBrowse_Search() end
end

function AU:Refresh()
    if not (self.panel and self.panel:IsShown()) then return end
    self:UpdateStatus()
    local list, why = self:Upgrades()
    local content = self.content
    local y, n = 0, 0
    local lastSlot
    local function use()
        n = n + 1
        local r = self.rows[n] or row(content, n)
        self.rows[n] = r
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        r:Show()
        y = y + 22
        return r
    end
    local function plain(r)
        r.link, r.itemName = nil, nil
        r.icon:Hide()
        for _, k in ipairs({ "name", "lvl", "price", "pct", "cmp" }) do r[k]:SetText("") end
    end
    if why or #list == 0 then
        local r = use()
        plain(r)
        r.header:SetText(why or ("No upgrades in the last scan for " .. ns.Upgrade:ProfileName(ns.Upgrade:ActiveProfile())
            .. ((self.loading or 0) > 0 and (" (" .. self.loading .. " items still loading)") or "") .. "."))
    end
    for _, x in ipairs(list) do
        if x.slot ~= lastSlot then
            lastSlot = x.slot
            local h = use()
            plain(h)
            h.header:SetText(ns.Gear.SLOT_NAMES[x.slot] or ("Slot " .. x.slot))
        end
        local r = use()
        r.header:SetText("")
        local d = x.e.item
        r.link, r.itemName = x.entry.link, d.name
        r.icon:SetTexture(d.texture) r.icon:Show()
        r.name:SetText(tostring(x.entry.link))
        r.lvl:SetText(d.reqLevel and d.reqLevel > 0 and d.reqLevel or "")
        local price = AU.Money(x.entry.unit)
        if (x.entry.count or 1) > 1 then price = price .. " each" end
        r.price:SetText(price)
        local pct = x.e.kind == "empty" and "Empty slot" or ns.Upgrade.PctText(x.e)
        if x.e.uncertain then pct = pct .. " |cffff9933(uncertain)|r" end
        r.pct:SetText(pct)
        local names = {}
        for _, rep in ipairs(x.e.replaced or {}) do names[#names + 1] = rep.name end
        r.cmp:SetText(#names > 0 and ("vs " .. table.concat(names, " + ")) or "")
    end
    for i = n + 1, #self.rows do self.rows[i]:Hide() end
    content:SetHeight(math.max(y, 10))
end

function AU:BuildPanel()
    if self.panel or not AuctionFrame then return end
    local p = CreateFrame("Frame", "TBCGuideAHPanel", AuctionFrame, ns.Compat.BackdropTemplate)
    p:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 20, -72)
    p:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMRIGHT", -12, 36)
    W.Skin(p, "bg")
    p:SetFrameLevel((AuctionFrame:GetFrameLevel() or 1) + 5)
    p:Hide()
    self.panel = p
    self.scanBtn = W.Button(p, "Scan auction house", 140, 22, function()
        local ok, why = AU:Start()
        if not ok then ns:Print("Auction scan: " .. tostring(why)) end
    end)
    self.scanBtn:SetPoint("TOPLEFT", 8, -8)
    self.cancelBtn = W.Button(p, "Cancel", 70, 22, function() AU:Cancel() end)
    self.cancelBtn:SetPoint("LEFT", self.scanBtn, "RIGHT", 6, 0)
    p.status = W.Text(p, "GameFontHighlightSmall", "LEFT")
    p.status:SetPoint("LEFT", self.cancelBtn, "RIGHT", 10, 0)
    p.status:SetPoint("RIGHT", p, "RIGHT", -8, 0)
    p.status:SetWordWrap(false)

    -- Filters: slot, max price (gold), minimum %, sort, show uncertain.
    local slotDD = W.Dropdown(p, "TBCGuideAHSlot", 110, function()
        local items = { { text = "All slots", value = "all", checked = AU.filter.slot == "all" } }
        for _, s in ipairs(ns.Gear.SCORED_SLOTS) do items[#items + 1] = { text = ns.Gear.SLOT_NAMES[s], value = s, checked = AU.filter.slot == s } end
        return items
    end, function(v) AU.filter.slot = v AU:Refresh() end, function() return "All slots" end)
    slotDD:SetPoint("TOPLEFT", p, "TOPLEFT", -8, -36)
    local function input(label, w, x, onSet)
        local t = W.Text(p, "GameFontHighlightSmall", "LEFT")
        t:SetPoint("TOPLEFT", p, "TOPLEFT", x, -44)
        t:SetText(label)
        local e = W.Input(p, nil, w, 20)
        e:SetPoint("LEFT", t, "RIGHT", 6, 0)
        e:SetScript("OnEnterPressed", function(s) onSet(tonumber(s:GetText())) s:ClearFocus() AU:Refresh() end)
        return e
    end
    input("Max price (g)", 60, 150, function(v) AU.filter.maxGold = (v and v > 0) and v or nil end)
    input("Min upgrade %", 50, 300, function(v) AU.filter.minPct = (v and v > 0) and v or 0 end)
    local sortBtn
    sortBtn = W.Button(p, "Sort: upgrade %", 120, 20, function()
        AU.filter.sort = AU.filter.sort == "pct" and "price" or "pct"
        sortBtn:SetText(AU.filter.sort == "pct" and "Sort: upgrade %" or "Sort: price")
        AU:Refresh()
    end)
    sortBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 450, -42)
    local unc = W.Check(p, 16)
    unc:SetPoint("LEFT", sortBtn, "RIGHT", 12, 0)
    unc:SetScript("OnClick", function(s) AU.filter.uncertain = s:GetChecked() and true or false AU:Refresh() end)
    local ul = W.Text(p, "GameFontHighlightSmall", "LEFT")
    ul:SetPoint("LEFT", unc, "RIGHT", 6, 0)
    ul:SetText("Show uncertain")

    local note = W.Text(p, "GameFontDisableSmall", "LEFT")
    note:SetPoint("BOTTOMLEFT", 8, 6)
    note:SetPoint("BOTTOMRIGHT", -8, 6)
    note:SetText("Prices are the cheapest buyout seen in your last scan; listings may have sold since. Click an item to search for it. Nothing is ever bought automatically, and Bind-on-Equip items are never equipped automatically.")
    local scroll, content = W.Scroll(p, "TBCGuideAHScroll")
    scroll:SetPoint("TOPLEFT", 8, -72)
    scroll:SetPoint("BOTTOMRIGHT", -28, 24)
    self.content = content
    p:SetScript("OnShow", function() AU:Refresh() end)
end

-- Adds the "Upgrades" tab after the existing auction tabs (and other add-ons' tabs).
function AU:AddTab()
    if self.tab or not AuctionFrame then return end
    local n = (AuctionFrame.numTabs or 3) + 1
    while _G["AuctionFrameTab" .. n] do n = n + 1 end
    local ok, tab = pcall(CreateFrame, "Button", "AuctionFrameTab" .. n, AuctionFrame, "AuctionTabTemplate")
    if not ok or not tab then return end
    tab:SetID(n)
    tab:SetText("Upgrades")
    local prev = _G["AuctionFrameTab" .. (n - 1)]
    if prev then tab:SetPoint("LEFT", prev, "RIGHT", -15, 0) end
    if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(AuctionFrame, n) end
    if PanelTemplates_EnableTab then PanelTemplates_EnableTab(AuctionFrame, n) end
    self.tab, self.tabId = tab, n
    if hooksecurefunc and AuctionFrameTab_OnClick then
        hooksecurefunc("AuctionFrameTab_OnClick", function(btn)
            local id = btn and btn.GetID and btn:GetID()
            if id == AU.tabId and prof().auctioneer then AU:BuildPanel() AU.panel:Show()
            elseif AU.panel then AU.panel:Hide() end
        end)
    end
    self:ApplyEnabled()
end

-- Shows or hides our tab; never touches the native auction frames otherwise.
function AU:ApplyEnabled()
    if not self.tab then return end
    if prof().auctioneer then
        self.tab:Show()
    else
        if self.state == "scanning" then self:Cancel() end
        if self.panel and self.panel:IsShown() then
            self.panel:Hide()
            local first = _G["AuctionFrameTab1"]
            if first and first.Click then first:Click() end
        end
        self.tab:Hide()
    end
end

function AU:Update() self:ApplyEnabled() self:Refresh() end

function AU:Init()
    local function setup()
        if AuctionFrame and not AU.tab then
            AU:AddTab()
            if hooksecurefunc and QueryAuctionItems then hooksecurefunc("QueryAuctionItems", function() AU:OnForeignQuery() end) end
        end
    end
    ns:On("ADDON_LOADED", function(_, name) if name == "Blizzard_AuctionUI" then setup() end end)
    ns:On("AUCTION_HOUSE_SHOW", function() setup() AU:UpdateStatus() end)
    ns:On("AUCTION_HOUSE_CLOSED", function() if AU.state == "scanning" then AU:Finish(false, "the auction house was closed") end end)
    ns:On("AUCTION_ITEM_LIST_UPDATE", function() AU:OnListUpdate() end)
    ns:On("PLAYER_EQUIPMENT_CHANGED", function() ns:Throttle("ahrefresh", 0.5, function() AU:Refresh() end) end)
    ns:On("GET_ITEM_INFO_RECEIVED", function() if AU.loading and AU.loading > 0 then ns:Throttle("ahrefresh", 1, function() AU:Refresh() end) end end)
    setup()
end
