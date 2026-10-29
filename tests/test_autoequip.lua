-- TBCGuide - headless tests: automatic upgrades, BoE bag markers, equip notifications
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
-- Loaded by tests/run_tests.lua after boot; uses TEST.check and TEST.ns.

local check, ns = TEST.check, TEST.ns
local U, AE, M = ns.Upgrade, ns.AutoEquip, ns.GearMarkers
local function prof() return ns.db.profile end
local I = MOCK.items

-- Tooltip lines come from MOCK.items[id].tip (the real scanner needs the client's tooltip).
local realScan = U.ScanLines
U.ScanLines = function(kind, a, b)
    local id
    if kind == "bag" then id = MOCK.bags[a] and MOCK.bags[a][b] and MOCK.bags[a][b].itemID else id = MOCK.equipped[a] end
    return id and I[id] and I[id].tip or {}
end

local function item(id, t) t.name = t.name or ("Item " .. id) I[id] = t return id end
local PLATE, CLOTH, MISC = 4, 1, 0
item(95001, { name = "Old Helm", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 10 } })
item(95002, { name = "Better Helm", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 20 } })
item(95003, { name = "Worse Helm", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 5 } })
item(95004, { name = "Stamina Necklace", classID = 4, subclassID = MISC, equipLoc = "INVTYPE_NECK", bindType = 0, stats = { ITEM_MOD_STAMINA_SHORT = 5 } })
item(95005, { name = "BoE Boots", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_FEET", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 8 } })
item(95006, { name = "Old Legs", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_LEGS", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 5 } })
item(95007, { name = "BoE Legs", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_LEGS", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 30 } })
item(95008, { name = "Mystery Bracers", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_WRIST", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 9 } })
item(95010, { name = "Ring A", classID = 4, subclassID = MISC, equipLoc = "INVTYPE_FINGER", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 10 } })
item(95011, { name = "Ring B", classID = 4, subclassID = MISC, equipLoc = "INVTYPE_FINGER", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 2 } })
item(95012, { name = "Ring C", classID = 4, subclassID = MISC, equipLoc = "INVTYPE_FINGER", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 6 } })
item(95013, { name = "Trinket Old", classID = 4, subclassID = MISC, equipLoc = "INVTYPE_TRINKET", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 5 } })
item(95014, { name = "Trinket Low", classID = 4, subclassID = MISC, equipLoc = "INVTYPE_TRINKET", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 20 } })
item(95015, { name = "Use Trinket", classID = 4, subclassID = MISC, equipLoc = "INVTYPE_TRINKET", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 30 },
              tip = { { "Use Trinket" }, { "Use: Increases attack power by 200 for 20 sec." } } })
item(95020, { name = "Sword MH", classID = 2, subclassID = 7, equipLoc = "INVTYPE_WEAPON", bindType = 1,
              stats = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 40 } })
item(95021, { name = "Sword OH", classID = 2, subclassID = 7, equipLoc = "INVTYPE_WEAPON", bindType = 1,
              stats = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 40 } })
item(95022, { name = "Greatsword", classID = 2, subclassID = 8, equipLoc = "INVTYPE_2HWEAPON", bindType = 1,
              stats = { ITEM_MOD_STRENGTH_SHORT = 30, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 70 } })
item(95023, { name = "Tower Shield", classID = 4, subclassID = 6, equipLoc = "INVTYPE_SHIELD", bindType = 1, stats = { ITEM_MOD_STAMINA_SHORT = 20 } })

local function bag(list)
    MOCK.bags = { [0] = {} }
    for i, x in ipairs(list) do MOCK.bags[0][i] = { itemID = x[1], bound = x[2] } end
end
local function equipped(id) for s, x in pairs(MOCK.equipped) do if x == id then return s end end end
local function inBags(id) for b, t in pairs(MOCK.bags) do for s, x in pairs(t) do if x.itemID == id then return b, s end end end end
local function notices()
    local n = {}
    for _, m in ipairs(MOCK.printed) do if string.find(m, "Auto-equipped:", 1, true) then n[#n + 1] = m end end
    return n
end
local function settle(sec) MOCK.tick(sec or 8) end

MOCK.player.class, MOCK.player.level, MOCK.player.race = "WARRIOR", 60, "Human"
MOCK.talents = {}
MOCK.combat, MOCK.cursor, MOCK.cursorItem = false, false, nil
MOCK.freeOverride, MOCK.equipFails = nil, false
-- Earlier tests replace these with junk-deletion stand-ins.
C_Container.PickupContainerItem = MOCK.pickupContainerItem
C_Container.GetContainerNumFreeSlots = MOCK.getContainerNumFreeSlots
MOCK.equipCalls = {}
AE.windows, AE.busy = {}, nil
MOCK.equipped = { [1] = 95001, [7] = 95006, [11] = 95010, [12] = 95011, [13] = 95013, [14] = 95014, [16] = 95020, [17] = 95021 }
bag({ { 95002, true }, { 95003, true }, { 95004 }, { 95005, false }, { 95007, false }, { 95008, nil }, { 95012, true },
      { 95015, true }, { 95022, true } })
prof().autoEquip, prof().autoEquipEmpty, prof().equipNotify, prof().equipChat, prof().boeMarkers = true, true, true, true, true
prof().autoEquipMinPct = 0
prof().gearEnabled = true
ns.char.gearExclude = { items = {}, slots = {} }

-- No spec chosen: nothing is equipped, even with the setting on ----------------------------------------------
ns.char.gearProfile = nil
AE:OnProfileChanged()
settle()
check(#MOCK.equipCalls == 0, "nothing is equipped before a spec profile is chosen")
check(string.find(AE:Status(), "choose your spec", 1, true), "status explains a spec is needed: " .. AE:Status())

-- Fury, bags reported full ------------------------------------------------------------------------------------------
local before = #notices()
ns.char.gearProfile = "warrior_fury_raid"
MOCK.freeOverride = 0
AE:OnProfileChanged()
settle(10)
check(equipped(95004) == 2, "a usable non-BoE item fills the empty neck slot even with no Fury stats")
check(equipped(95002) == 1 and inBags(95001), "a Fury upgrade replaces the helm; the old helm goes to the bags")
check(equipped(95012) == 12 and equipped(95010) == 11, "a ring replaces the weaker of the two rings")
check(equipped(95003) == nil, "a downgrade is not equipped")
check(equipped(95022) == nil and equipped(95020) == 16 and equipped(95021) == 17, "full bags: the two-hander does not displace both weapons")
check(AE.lastError and string.find(AE.lastError, "bag space", 1, true), "full bags reason recorded: " .. tostring(AE.lastError))
check(equipped(95005) == nil and inBags(95005), "an unbound BoE never fills an empty slot")
check(equipped(95007) == nil, "an unbound BoE upgrade is never equipped")
check(equipped(95008) == nil, "unknown binding state blocks equipping")
check(equipped(95015) == nil, "an item with an unscored use effect is not equipped over a filled slot")
local n = notices()
check(#n - before == 3, "one notification per confirmed equip (" .. (#n - before) .. ")")
local all = table.concat(n, "\n")
check(string.find(all, "Empty slot filled (Neck)", 1, true), "empty-slot notification text")
check(string.find(all, "+100.0% estimated spec score (Fury DPS)", 1, true) or string.find(all, "+100.0% estimated spec score (Fury)", 1, true),
    "upgrade notification shows the percentage and profile")
check(string.find(all, "+200.0% estimated spec score", 1, true), "ring: (6-2)/2 = +200.0%")
check(M.queue and #M.queue <= 3, "on-screen queue is capped")

-- No loops, no duplicates ------------------------------------------------------------------------------------------
local calls, nn = #MOCK.equipCalls, #notices()
for _ = 1, 5 do MOCK.fire("BAG_UPDATE", 0) MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 1) end
settle()
check(#MOCK.equipCalls == calls and #notices() == nn, "repeated inventory events do not re-equip or re-notify")

-- Equal score -------------------------------------------------------------------------------------------------------
item(95030, { name = "Twin Helm", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 20 } })
MOCK.bags[0][16] = { itemID = 95030, bound = true }
MOCK.fire("BAG_UPDATE", 0)
settle()
check(equipped(95030) == nil, "an equal-score item is not swapped in")
check(U.last["0:16"] and U.last["0:16"].reason == "same score as equipped", "equal score is reported as such")

-- Free bags: the remembered failure is not retried until something changes ------------------------------------------------
MOCK.freeOverride = nil
settle()
check(equipped(95022) == nil, "a failed (full-bag) attempt is not retried in a loop")
AE:OnProfileChanged()
settle(6)
check(equipped(95022) == 16 and MOCK.equipped[17] == nil, "two-hander compared with main hand + off hand and equipped when bags have room")
check(inBags(95020) and inBags(95021), "both one-handers went to the bags")
check(string.find(table.concat(notices(), "\n"), "Greatsword%].-%+18%.3%% estimated spec score"),
    "two-hander % uses the whole weapon set: (1045.1-883.4)/883.4 = +18.3%")
settle()
check(equipped(95020) == nil and equipped(95021) == nil, "the replaced one-handers are not equipped back (no oscillation)")

-- Shield and off-hand rules -----------------------------------------------------------------------------------------------
local ctx = U:Context()
local sh = U:BagItem(inBags(95023) or 0, 1)
MOCK.bags[0][15] = { itemID = 95023, bound = true }
sh = U:BagItem(0, 15)
local e = U:Evaluate(sh, ctx)
check(not e.ok and string.find(e.reason, "two-hander", 1, true), "a shield is never equipped while a two-hander is held: " .. tostring(e.reason))
local opts, why = U:Options({ equipLoc = "INVTYPE_WEAPONOFFHAND" }, { class = "MAGE", level = 70 }, {})
check(opts == nil and string.find(why, "dual wield", 1, true), "off-hand weapons need dual wield")
opts = U:Options({ equipLoc = "INVTYPE_WEAPON" }, { class = "WARRIOR", level = 60 }, { [16] = { equipLoc = "INVTYPE_WEAPON" } })
check(#opts == 2, "a one-hander for a dual wielder is checked in both hands")
MOCK.bags[0][15] = nil

-- BoE markers and tooltips ------------------------------------------------------------------------------------------------
settle()
local bb, bs = inBags(95007)
local fb, fs = inBags(95005)
check(M.marks[bb .. ":" .. bs] ~= nil, "BoE upgrade gets a bag marker")
check(M.marks[fb .. ":" .. fs] ~= nil, "BoE item for an empty slot gets a bag marker")
local mb, ms = inBags(95008)
check(M.marks[mb .. ":" .. ms] == nil, "unknown binding: no marker")
local tb, ts = inBags(95015)
check(M.marks[tb .. ":" .. ts] == nil, "uncertain items are never marked as confirmed upgrades")
local tl = M:TooltipLines(bb, bs)
local txt = ""
for _, l in ipairs(tl or {}) do txt = txt .. l[1] .. "\n" end
check(string.find(txt, "upgrade for Fury", 1, true), "tooltip names the profile")
check(string.find(txt, "+500.0% estimated spec score", 1, true), "tooltip shows the estimated upgrade (30 vs 5 Strength)")
check(string.find(txt, "Replaces", 1, true) and string.find(txt, "Old Legs", 1, true), "tooltip names the replaced item")
check(string.find(txt, "Bind on Equip - manual equip required.", 1, true), "tooltip says BoE needs a manual equip")
txt = ""
for _, l in ipairs(M:TooltipLines(fb, fs) or {}) do txt = txt .. l[1] .. "\n" end
check(string.find(txt, "Empty slot (Feet)", 1, true), "tooltip for an empty-slot BoE says so")

-- Overlay on the default bag frame: shown on marked buttons, hidden (not stale) elsewhere.
local frame = CreateFrame("Frame", "ContainerFrame1")
frame.GetID = function() return 0 end
frame.GetName = function() return "ContainerFrame1" end
frame.size = 16
frame.shown = true
for i = 1, 16 do
    local b = CreateFrame("Button", "ContainerFrame1Item" .. i)
    b.GetID = function() return i end
end
M:RefreshAll()
check(M.overlays[_G["ContainerFrame1Item" .. bs]] and M.overlays[_G["ContainerFrame1Item" .. bs]].shown, "overlay shown on the BoE upgrade's button")
check(not (M.overlays[_G["ContainerFrame1Item" .. ms]] and M.overlays[_G["ContainerFrame1Item" .. ms]].shown), "no overlay on unmarked buttons")

-- Changing the profile refreshes evaluations and clears obsolete markers -----------------------------------------------------
ns.char.gearProfile = "warrior_protection_raid"
AE:OnProfileChanged()
settle()
check(M.marks[bb .. ":" .. bs] == nil, "protection profile: the Strength legs are no longer marked")
check(not M.overlays[_G["ContainerFrame1Item" .. bs]].shown, "its overlay is hidden after the profile change")
check(M.marks[fb .. ":" .. fs] ~= nil, "the empty-slot BoE stays marked")

-- Percentages never invalid ------------------------------------------------------------------------------------------------
check(U.PctText({ kind = "empty" }) == "Empty slot filled", "empty slot text")
check(U.PctText({ kind = "upgrade", pct = nil }) == "Upgrade - percentage unavailable", "no baseline: no percentage")
check(U.PctText({ kind = "upgrade", pct = 0 / 0 }) == "Upgrade - percentage unavailable", "NaN never shown")
check(U.PctText({ kind = "upgrade", pct = math.huge }) == "Upgrade - percentage unavailable", "infinity never shown")
check(U.PctText({ kind = "upgrade", pct = 8.44 }) == "+8.4% estimated spec score", "one decimal place")
-- Zero baseline under Fury: Stamina-only necklace equipped, Strength necklace in the bag.
ns.char.gearProfile = "warrior_fury_raid"
AE:OnProfileChanged()
item(95031, { name = "Strength Necklace", classID = 4, subclassID = MISC, equipLoc = "INVTYPE_NECK", bindType = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 4 } })
MOCK.bags[0][15] = { itemID = 95031, bound = false }
settle()
local z = U.last["0:15"]
check(z and z.kind == "upgrade" and z.pct == nil and U.PctText(z) == "Upgrade - percentage unavailable", "zero baseline: upgrade without a percentage")
check(equipped(95031) == nil, "...and it is a BoE, so it is only marked")
MOCK.bags[0][15] = nil

-- Combat defers, then revalidates --------------------------------------------------------------------------------------------
item(95032, { name = "Raid Helm", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 40 } })
MOCK.combat = true
MOCK.bags[0][15] = { itemID = 95032, bound = true }
MOCK.fire("BAG_UPDATE", 0)
settle()
check(equipped(95032) == nil and string.find(AE:Status(), "combat", 1, true), "in combat: deferred, not equipped")
MOCK.combat = false
MOCK.fire("PLAYER_REGEN_ENABLED")
settle()
check(equipped(95032) == 1, "after combat the upgrade is revalidated and equipped")

-- Missing item data waits instead of scoring zero ----------------------------------------------------------------------------
item(95033, { name = "Slow Cloak", classID = 4, subclassID = CLOTH, equipLoc = "INVTYPE_CLOAK", bindType = 1, uncached = true, stats = { ITEM_MOD_STRENGTH_SHORT = 3 } })
MOCK.bags[0][14] = { itemID = 95033, bound = true }
MOCK.fire("BAG_UPDATE", 0)
settle(2)
check(equipped(95033) == nil, "uncached item is not equipped")
I[95033].uncached = false
settle(3)
check(equipped(95033) == 15, "once the item data loads, the empty back slot is filled")

-- A failed equip: no success message, item back in its bag slot, no retry loop ------------------------------------------------------
item(95034, { name = "Sticky Gloves", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_HAND", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 3 } })
MOCK.bags[0][13] = { itemID = 95034, bound = true }
MOCK.equipFails = true
nn, calls = #notices(), #MOCK.equipCalls
MOCK.fire("BAG_UPDATE", 0)
settle(4)
check(#MOCK.equipCalls == calls + 1, "one attempt")
check(#notices() == nn and equipped(95034) == nil, "a failed equip produces no success message")
check(MOCK.bags[0][13] and MOCK.bags[0][13].itemID == 95034 and not MOCK.cursorItem, "the item is put back in its bag slot")
for _ = 1, 3 do MOCK.fire("BAG_UPDATE", 0) end
settle(4)
check(#MOCK.equipCalls == calls + 1, "a failed item is not retried")
MOCK.equipFails = false

-- A bind confirmation is never accepted ------------------------------------------------------------------------------------------------
item(95035, { name = "Sneaky Belt", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_WAIST", bindType = 0, askBind = true, stats = { ITEM_MOD_STRENGTH_SHORT = 3 } })
MOCK.bags[0][12] = { itemID = 95035 }
nn = #notices()
MOCK.fire("BAG_UPDATE", 0)
settle(4)
check(equipped(95035) == nil and MOCK.bags[0][12] and MOCK.bags[0][12].itemID == 95035 and not MOCK.cursorItem,
    "bind confirmation: nothing equipped, item returned to its bag slot")
check(#notices() == nn, "no success message after a bind confirmation")

-- Exclusions -------------------------------------------------------------------------------------------------------------------------
item(95036, { name = "Shiny Helm", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 80 } })
MOCK.bags[0][11] = { itemID = 95036, bound = true }
ns.GearUI:Command("exclude 95036")
settle()
check(equipped(95036) == nil and U.last["0:11"].reason == "excluded from automatic upgrades", "an excluded item is never equipped")
ns.GearUI:Command("include 95036")
U:Exclusions().slots[1] = true
AE:Schedule()
settle()
check(equipped(95036) == nil and string.find(tostring(U.last["0:11"].reason), "protected", 1, true), "a protected slot is never changed")
U:Exclusions().slots[1] = nil
AE:Schedule()
settle()
check(equipped(95036) == 1, "allowed again once unprotected")

-- Minimum upgrade --------------------------------------------------------------------------------------------------------------------
item(95037, { name = "Slightly Better Helm", classID = 4, subclassID = PLATE, equipLoc = "INVTYPE_HEAD", bindType = 1, stats = { ITEM_MOD_STRENGTH_SHORT = 82 } })
MOCK.bags[0][10] = { itemID = 95037, bound = true }
prof().autoEquipMinPct = 5
MOCK.fire("BAG_UPDATE", 0)
settle()
check(equipped(95037) == nil and U.last["0:10"].reason == "below your minimum upgrade", "a +2.5% upgrade is skipped below a 5% minimum")
prof().autoEquipMinPct = 0

-- Settings and per-character choices survive a reload -----------------------------------------------------------------------------------
U:Exclusions().items[12345] = true
ns:InitSavedVariables()
check(ns.db.profile.autoEquip == true and ns.char.gearProfile == "warrior_fury_raid", "settings and spec profile survive a reload")
check(ns.char.gearExclude.items[12345] == true, "exclusions survive a reload")
U:Exclusions().items[12345] = nil

-- Spec coverage and the settings dropdown ------------------------------------------------------------------------------------------------
local WANT = {
    DRUID = { "Balance", "Feral DPS", "Feral Tank", "Restoration" }, HUNTER = { "Beast Mastery", "Marksmanship", "Survival" },
    MAGE = { "Arcane", "Fire", "Frost" }, PALADIN = { "Holy", "Protection", "Retribution" }, PRIEST = { "Discipline", "Holy", "Shadow" },
    ROGUE = { "Assassination", "Combat", "Subtlety" }, SHAMAN = { "Elemental", "Enhancement", "Restoration" },
    WARLOCK = { "Affliction", "Demonology", "Destruction" }, WARRIOR = { "Arms", "Fury", "Protection" },
}
for class, specs in pairs(WANT) do
    local have = {}
    for _, p in ipairs(ns.Gear:ProfilesForClass(class)) do if p.spec then have[U:ProfileName(p)] = p end end
    for _, sname in ipairs(specs) do
        local p = have[sname]
        check(p ~= nil, class .. " has a " .. sname .. " profile")
        if p then
            local w = U:Weights(p)
            local any = false
            for _, v in pairs(w.stats) do if v > 0 then any = true end end
            check(any, class .. " " .. sname .. ": usable weights" .. (p.weights and "" or " (estimated from priority)"))
            check(p.weights ~= nil or #w.heuristic > 0, class .. " " .. sname .. ": estimated weights are labelled")
        end
    end
end
check(U:ProfileName(ns.Gear:ProfileById("druid_bear_raid")) ~= U:ProfileName(ns.Gear:ProfileById("druid_feral_raid")), "cat and bear are separate profiles")

local CF = ns.Config
CF:Show("tips")
local specSel, autoT
for _, x in ipairs(CF.built.tips.widgets) do
    if x.item and x.item.label == "Spec profile" then specSel = x.item end
    if x.item and x.item.label == "Enable automatic upgrades" then autoT = x.item end
end
check(specSel ~= nil and autoT ~= nil, "settings have the spec dropdown and the automatic upgrade switch")
local onlyOwn = true
for _, v in ipairs(specSel.values()) do
    local p = ns.Gear:ProfileById(v[1])
    if p and p.class ~= "WARRIOR" then onlyOwn = false end
end
check(onlyOwn, "the dropdown lists only the player's class")
ns.char.gearProfile = nil
prof().autoEquip = false
autoT.set(true)
check(prof().autoEquip == false, "automatic upgrades cannot be switched on without a spec profile")
ns.char.gearProfile = "warrior_fury_raid"
autoT.set(true)
if StaticPopupDialogs and StaticPopupDialogs.TBCGUIDE_CONFIRM then StaticPopupDialogs.TBCGUIDE_CONFIRM.OnAccept() end
check(prof().autoEquip == true, "with a spec chosen, switching on asks first and then enables")
CF.frame:Hide()

-- Leveling characters: caps are not applied below 70 (they are level-70 assumptions) --------------------------------------------------------
check(U:Context().base == nil, "level 60: no level-70 cap assumptions")

-- restore
U.ScanLines = realScan
prof().autoEquip, prof().equipChat = false, false
ns.char.gearProfile = nil
ns.char.gearExclude = { items = {}, slots = {} }
MOCK.equipped, MOCK.bags = {}, { [0] = {} }
AE:OnProfileChanged()
settle(2)
MOCK.player.class, MOCK.player.level = "WARRIOR", 1
check(#ns.errors == 0, "no captured errors after auto-equip tests: " .. table.concat(ns.errors, " | "))
