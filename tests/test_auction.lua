-- TBCGuide - headless tests: auction house upgrades (scan, cache, Upgrades tab), Window settings,
-- removed placeholder options
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
-- Loaded by tests/run_tests.lua after boot; uses TEST.check and TEST.ns.

local check, ns = TEST.check, TEST.ns
local function prof() return ns.db.profile end
local AU = ns.AHUpgrades

-- Legacy auction API mock: MOCK.ah = { list = { {link, count, buyout}, ... }, canQuery = bool }
MOCK.ah = { list = {}, canQuery = true, queries = {}, respond = true }
local bids = 0
function PlaceAuctionBid() bids = bids + 1 end
function CanSendAuctionQuery() return MOCK.ah.canQuery end
local curPage = 0
function QueryAuctionItems(name, minL, maxL, page, usable, quality, getAll)
    table.insert(MOCK.ah.queries, { page = page, usable = usable, maxL = maxL, quality = quality, getAll = getAll })
    curPage = page
    if MOCK.ah.respond then C_Timer.After(0.2, function() MOCK.fire("AUCTION_ITEM_LIST_UPDATE") end) end
end
function GetNumAuctionItems()
    local n = #MOCK.ah.list
    local first = curPage * 50 + 1
    return math.max(0, math.min(50, n - first + 1)), n
end
local function at(i) return MOCK.ah.list[curPage * 50 + i] end
function GetAuctionItemInfo(_, i)
    local x = at(i)
    if not x then return nil end
    return "name", "icon", x.count or 1, 3, true, 1, nil, 100, 10, x.buyout or 0, 0, nil, nil, "Seller", nil, 0, x.id, true
end
function GetAuctionItemLink(_, i) local x = at(i) return x and x.link end
time = function() return 1000000 + math.floor(MOCK.time) end

AuctionFrame = CreateFrame("Frame", "AuctionFrame")
AuctionFrame.numTabs = 3
for i = 1, 3 do CreateFrame("Button", "AuctionFrameTab" .. i) end
AuctionFrameTab_OnClick = function() end
AuctionFrame.shown = false

local I = MOCK.items
I[97001] = { name = "AH Helm", classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 40 } }
I[97002] = { name = "AH Bad Helm", classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 2 } }
I[97003] = { name = "AH Boots", classID = 4, subclassID = 4, equipLoc = "INVTYPE_FEET", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 5 } }
I[97004] = { name = "AH Proc Ring", classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 30 },
             tip = { { "AH Proc Ring" }, { "Chance on hit: Does something." } } }
I[97005] = { name = "Ring of the Bear", classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 12 } }
I[97010] = { name = "Worn Helm", classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 10 } }
I[97011] = { name = "Worn Ring", classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 4 } }
local function suffixLink(id, suffix) return "|cff1eff00|Hitem:" .. id .. ":0:0:0:0:0:" .. suffix .. ":0|h[" .. I[id].name .. "]|h|r" end

local realScan = ns.Upgrade.ScanLines
ns.Upgrade.ScanLines = function(kind, a)
    local id
    if kind == "link" then id = tonumber(string.match(a, "item:(%d+)")) elseif kind == "inv" then id = MOCK.equipped[a] end
    return id and I[id] and I[id].tip or {}
end

MOCK.player.class, MOCK.player.level, MOCK.player.race, MOCK.player.faction = "WARRIOR", 60, "Human", "Alliance"
MOCK.talents = {}
MOCK.equipped = { [1] = 97010, [11] = 97011, [12] = 97011 }
ns.char.gearProfile = "warrior_fury_raid"
ns.Upgrade:Reset()
prof().auctioneer = true
ns.db.auctionScans = {}

-- 120 listings over 3 pages: upgrades, a downgrade, a proc ring, two suffix variants, no-buyout ones.
local list = {}
for i = 1, 120 do list[i] = { link = MOCK.link(97002), id = 97002, buyout = 500 } end
list[3] = { link = MOCK.link(97001), id = 97001, buyout = 90000 }
list[4] = { link = MOCK.link(97001), id = 97001, buyout = 70000 }
list[60] = { link = MOCK.link(97003), id = 97003, buyout = 20000 }
list[61] = { link = MOCK.link(97004), id = 97004, buyout = 30000 }
list[101] = { link = suffixLink(97005, 1201), id = 97005, buyout = 15000 }
list[102] = { link = suffixLink(97005, 1202), id = 97005, buyout = 9000 }
list[103] = { link = MOCK.link(97001), id = 97001, buyout = 0 }
MOCK.ah.list = list

-- Start rules -----------------------------------------------------------------------------------------
local ok, why = AU:Start()
check(not ok and string.find(why, "auction house", 1, true), "no scan while the auction house is closed")
AuctionFrame.shown = true
MOCK.fire("AUCTION_HOUSE_SHOW")
check(AU.tab and AU.tab.GetID and AU.tabId == 4, "Upgrades tab added after the three auction tabs")
prof().auctioneer = false
check(not AU:Start(), "no scan while the feature is off")
AU:ApplyEnabled()
check(not AU.tab:IsShown(), "feature off: the tab is hidden")
prof().auctioneer = true
AU:ApplyEnabled()
check(AU.tab:IsShown(), "feature on: the tab is back")

-- Throttle: nothing is sent until the server allows a query.
MOCK.ah.canQuery = false
check(AU:Start(), "scan starts on request")
MOCK.tick(1)
check(#MOCK.ah.queries == 0 and AU.state == "scanning", "waits while CanSendAuctionQuery() is false")
MOCK.ah.canQuery = true
MOCK.tick(3)
check(#MOCK.ah.queries == 3, "three pages queried for 120 listings (" .. #MOCK.ah.queries .. ")")
local q = MOCK.ah.queries[1]
check(q.usable == true and q.maxL == 60 and q.quality == 2 and not q.getAll, "query: usable gear up to your level, uncommon+, no getAll")
check(AU.state == "done", "scan completes")
local ds = AU:Dataset()
check(ds and ds.complete and ds.listings == 120, "complete dataset saved with a timestamp")
check(ds.items["97001:0"] and ds.items["97001:0"].unit == 70000 and ds.items["97001:0"].listings == 2, "lowest buyout per item kept, listings counted")
check(ds.items["97005:1201"] and ds.items["97005:1202"], "random-suffix variants are kept apart")
check(ds.noBuyout == 1, "bid-only listings are counted but not priced")
check(bids == 0, "nothing was bid on or bought")

-- Upgrades tab ------------------------------------------------------------------------------------------
local rows, reason = AU:Upgrades()
local names = {}
for _, r in ipairs(rows) do names[r.e.item.name] = r end
check(reason == nil and names["AH Helm"] and not names["AH Bad Helm"], "upgrades listed, downgrades not")
check(names["AH Boots"] and names["AH Boots"].e.kind == "empty" and names["AH Boots"].e.pct == nil, "empty slot: no invented percentage")
check(not names["AH Proc Ring"], "uncertain items hidden by default")
local helm = names["AH Helm"]
local direct = ns.Upgrade:Evaluate((function() local d = ns.Gear:ItemData(helm.entry.link) d.tip = {} return d end)(), ns.Upgrade:Context())
check(math.abs(helm.e.pct - direct.pct) < 1e-9 and math.abs(helm.e.pct - 300) < 1e-6, "same score as the upgrade evaluator: +300%")
check(names["Ring of the Bear"] and names["Ring of the Bear"].e.target == 11 or names["Ring of the Bear"].e.target == 12, "rings compare against the ring slots")
AU.filter.uncertain = true
rows = AU:Upgrades()
local seen = false
for _, r in ipairs(rows) do if r.e.item.name == "AH Proc Ring" then seen = r.e.uncertain ~= nil end end
check(seen, "'Show uncertain' lists them, marked uncertain")
AU.filter.uncertain = false
AU.filter.maxGold = 5
rows = AU:Upgrades()
local over = false
for _, r in ipairs(rows) do if r.entry.unit > 50000 then over = true end end
check(not over and #rows > 0, "max price filter")
AU.filter.maxGold, AU.filter.minPct = nil, 250
rows = AU:Upgrades()
local low = false
for _, r in ipairs(rows) do if r.e.kind == "upgrade" and r.e.pct < 250 then low = true end end
check(not low, "minimum upgrade % filter")
AU.filter.minPct = 0
AU.filter.sort = "price"
rows = AU:Upgrades()
local sorted = true
for i = 2, #rows do if rows[i].slot == rows[i - 1].slot and rows[i].entry.unit < rows[i - 1].entry.unit then sorted = false end end
check(sorted, "price sort within each slot group")
AU.filter.sort = "pct"
for i = 2, #rows do check(rows[i].slot >= rows[i - 1].slot, "grouped by slot") end

-- Changing equipment or spec re-scores without rescanning.
local queriesBefore = #MOCK.ah.queries
MOCK.equipped[1] = 97001
rows = AU:Upgrades()
local stillHelm = false
for _, r in ipairs(rows) do if r.e.item.name == "AH Helm" then stillHelm = true end end
check(not stillHelm and #MOCK.ah.queries == queriesBefore, "equipping the helm removes it from the list without a rescan")
MOCK.equipped[1] = 97010
ns.char.gearProfile = nil
local r2, why2 = AU:Upgrades()
check(#r2 == 0 and string.find(why2, "spec profile", 1, true), "no spec profile: says so instead of guessing")
ns.char.gearProfile = "warrior_fury_raid"

-- The panel renders.
AU:BuildPanel()
AU.panel:Show()
AU:Refresh()
check(AU.rows[1] and AU.rows[1]:IsShown(), "Upgrades panel lists rows")
check(string.find(AU:StatusText(), "complete", 1, true), "status shows a complete scan")

-- Interruptions ---------------------------------------------------------------------------------------------
MOCK.ah.queries = {}
AU:Start()
MOCK.tick(0.5)
AU:OnForeignQuery()
check(AU.state == "partial" and AU:Dataset().complete == false, "another search stops the scan; results kept as partial")
check(string.find(AU:StatusText(), "partial", 1, true), "partial data is labelled")
AU:Start()
MOCK.tick(0.1)
AuctionFrame.shown = false
MOCK.fire("AUCTION_HOUSE_CLOSED")
check(AU.state == "partial", "closing the auction house ends the scan safely")
AuctionFrame.shown = true
MOCK.ah.respond = false
AU:Start()
MOCK.tick(AU.PAGE_TIMEOUT + 1)
check(AU.state == "partial" and string.find(AU.status, "timeout", 1, true), "no answer: the scan times out")
MOCK.ah.respond = true
AU:Start()
MOCK.tick(0.1)
AU:Cancel()
check(AU.state == "partial" and string.find(AU.status, "cancelled", 1, true), "cancel works")
-- Stale data
MOCK.ah.queries = {}
AU:Start() MOCK.tick(3)
MOCK.tick(AU.STALE_AFTER + 10)
check(string.find(AU:StatusText(), "stale", 1, true), "old data is marked stale")
check(bids == 0, "still nothing bought")
AuctionFrame.shown = false
AU.panel:Hide()

-- Window settings --------------------------------------------------------------------------------------------
local CF = ns.Config
CF:Show("general")
local function item(label) for _, w in ipairs(CF.built.general.widgets) do if w.item and w.item.label == label then return w end end end
local sc, fs, ar, rs = item("Guide Window Scale"), item("Guide Font Size"), item("Arrow Scale"), nil
for _, w in ipairs(CF.built.general.widgets) do if w.item and w.item.label == "Reset Window Settings" then rs = w end end
check(sc and fs and ar and rs, "Window section: scale, font size, arrow scale and reset")
prof().autoSellJunk = false
sc.frame:SetValue(1.4)
check(math.abs(prof().scale - 1.4) < 1e-6 and math.abs(ns.MainFrame.frame:GetScale() - 1.4) < 1e-6, "guide scale applies immediately")
fs.frame:SetValue(16)
check(prof().guideFontSize == 16, "font size saved")
ar.frame:SetValue(1.5)
check(math.abs(prof().arrowScale - 1.5) < 1e-6, "arrow scale saved")
rs.item.func()
check(prof().scale == 1 and prof().guideFontSize == 12 and prof().arrowScale == 1, "reset restores the three defaults")
check(prof().autoSellJunk == false, "...and leaves other settings alone")
prof().autoSellJunk = true
CF.frame:Hide()

-- Removed placeholders ----------------------------------------------------------------------------------------
for id, def in pairs(ns.ConfigPages) do
    for _, it in ipairs(def.items(CF)) do
        check(not it.planned, id .. ": no greyed-out placeholder (" .. tostring(it.label) .. ")")
        for _, gone in ipairs({ "Follow Party Leader Macro", "Quest Sellable Recommendation", "Always Show Total EP" }) do
            check(it.label ~= gone, id .. ": '" .. gone .. "' removed")
        end
    end
end

-- restore
ns.Upgrade.ScanLines = realScan
ns.char.gearProfile = nil
MOCK.equipped = {}
MOCK.player.level = 1
check(#ns.errors == 0, "no captured errors after auction tests: " .. table.concat(ns.errors, " | "))
