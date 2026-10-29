-- TBCGuide - headless tests: gear scoring (profiles, engine, tooltip, quest rewards, /tbcg gear)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
-- Loaded by tests/run_tests.lua after boot; uses TEST.check and TEST.ns.

local check, ns = TEST.check, TEST.ns
local G, GUI = ns.Gear, ns.GearUI

-- Profiles: structure, provenance, no duplicates ------------------------------------------------------
local KNOWN = {}
for _, k in pairs(G.STAT_KEYS) do KNOWN[k] = true end
local CLASSES = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, PRIEST = 1, SHAMAN = 1, MAGE = 1, WARLOCK = 1, DRUID = 1 }
local CONF = { high = 1, medium = 1, low = 1 }
local seen, nNumeric, nPriority = {}, 0, 0
for _, p in ipairs(ns.GearProfiles.list) do
    local where = "profile " .. tostring(p.id)
    check(type(p.id) == "string" and not seen[p.id], where .. ": unique id")
    seen[p.id] = true
    check(CLASSES[p.class] ~= nil, where .. ": valid class")
    check(CONF[p.confidence] ~= nil, where .. ": confidence high/medium/low")
    check(type(p.context) == "string" and type(p.role) == "string", where .. ": context and role")
    check(type(p.levelMin) == "number" and type(p.levelMax) == "number" and p.levelMin <= p.levelMax, where .. ": level range")
    check(type(p.sources) == "table" and #p.sources > 0, where .. ": has sources")
    check((p.weights ~= nil) ~= (p.priority ~= nil), where .. ": either weights or a priority list, not both")
    if p.weights then
        nNumeric = nNumeric + 1
        check(type(p.normalization) == "string", where .. ": numeric profile states its normalization")
        check(p.confidence ~= "low", where .. ": numeric profiles are at least medium confidence")
        for k, v in pairs(p.weights) do check(KNOWN[k] and type(v) == "number" and v >= 0, where .. ": weight " .. tostring(k)) end
    else
        nPriority = nPriority + 1
        for _, k in ipairs(p.priority) do check(KNOWN[k], where .. ": priority stat " .. tostring(k)) end
    end
    for k, v in pairs(p.caps or {}) do check(KNOWN[k] and type(v) == "number", where .. ": cap " .. tostring(k)) end
    if p.context == "leveling" then check(p.weights == nil, where .. ": leveling profiles carry no invented numbers") end
end
check(nNumeric >= 15 and nPriority >= 10, "profile counts (" .. nNumeric .. " numeric, " .. nPriority .. " priority)")

-- Test items --------------------------------------------------------------------------------------------
local I = MOCK.items
I[90001] = { name = "Agile Boots", classID = 4, subclassID = 2, equipLoc = "INVTYPE_FEET", reqLevel = 70,
             stats = { ITEM_MOD_AGILITY_SHORT = 20, ITEM_MOD_STAMINA_SHORT = 15 } }
I[90002] = { name = "Old Boots", classID = 4, subclassID = 2, equipLoc = "INVTYPE_FEET", reqLevel = 60,
             stats = { ITEM_MOD_AGILITY_SHORT = 10 } }
I[90003] = { name = "Hit Ring", classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER",
             stats = { ITEM_MOD_HIT_RATING_SHORT = 10 } }
I[90004] = { name = "Plate Helm", classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", stats = { ITEM_MOD_STAMINA_SHORT = 30 } }
I[90005] = { name = "Big Sword", classID = 2, subclassID = 8, equipLoc = "INVTYPE_2HWEAPON",
             stats = { ITEM_MOD_STRENGTH_SHORT = 30, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 80 } }
I[90006] = { name = "Main Dagger", classID = 2, subclassID = 15, equipLoc = "INVTYPE_WEAPON", stats = { ITEM_MOD_AGILITY_SHORT = 10 } }
I[90007] = { name = "Off Dagger", classID = 2, subclassID = 15, equipLoc = "INVTYPE_WEAPON", stats = { ITEM_MOD_AGILITY_SHORT = 5 } }
I[90008] = { name = "Mail Vest", classID = 4, subclassID = 3, equipLoc = "INVTYPE_CHEST", stats = { ITEM_MOD_AGILITY_SHORT = 10 } }
I[90009] = { name = "Spell Hit Robe", classID = 4, subclassID = 1, equipLoc = "INVTYPE_ROBE",
             stats = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 30, ITEM_MOD_HIT_SPELL_RATING_SHORT = 10, EMPTY_SOCKET_RED = 1 } }
I[90010] = { name = "Shield", classID = 4, subclassID = 6, equipLoc = "INVTYPE_SHIELD", stats = { ITEM_MOD_STAMINA_SHORT = 10 } }
I[90011] = { name = "Not Loaded", uncached = true }
I[90012] = { name = "Empty Cloak", classID = 4, subclassID = 1, equipLoc = "INVTYPE_CLOAK", stats = {} }
I[90013] = { name = "Leaf Mallet", classID = 2, subclassID = 4, equipLoc = "INVTYPE_WEAPONMAINHAND", stats = { ITEM_MOD_AGILITY_SHORT = 8 } }

local function as(class, level, race)
    MOCK.player.class, MOCK.player.level, MOCK.player.race = class, level, race or "Human"
    MOCK.talents = {}
    MOCK.equipped = {}
    MOCK.ratings = {}
    ns.char.gearProfile = nil
end
local function talents(tab, points) MOCK.talents[tab] = { { name = "t", tier = 1, column = 1, rank = points, maxRank = 5 } } end

-- Item data ----------------------------------------------------------------------------------------------
local d = G:ItemData(90009)
check(d and d.stats.sp == 30 and d.stats.spellhit == 10 and d.stats.heal == nil, "spell damage and spell hit are read; no healing double count")
check(d.unscored.sockets, "sockets are reported as not scored")
check(select(2, G:ItemData(90011)) == "uncached", "uncached item is reported, not guessed")
local nd = G:ItemData(90012)
check(nd and next(nd.stats) == nil, "item without stats has an empty stat list")

-- Profile selection ------------------------------------------------------------------------------------------
as("WARRIOR", 30)
local p, why = G:SelectProfile()
check(p == nil and string.find(why, "leveling"), "level-30 warrior: no profile (no researched leveling data), says why")
as("ROGUE", 30)
p = G:SelectProfile()
check(p and p.id == "rogue_leveling" and p.weights == nil, "level-30 rogue: qualitative leveling profile, never level-70 numbers")
as("ROGUE", 70)
p = G:SelectProfile()
check(p and p.id == "rogue_combat_preraid", "level-70 rogue without talents: pre-raid Combat profile")
as("MAGE", 70) talents(2, 40)
p = G:SelectProfile()
check(p and p.id == "mage_fire_raid", "level-70 Fire mage: Fire profile (detected from talents)")
as("MAGE", 70) talents(1, 40)
check(G:SelectProfile().id == "mage_arcane_raid", "level-70 Arcane mage: Arcane profile")
as("DRUID", 70) talents(2, 41)
check(G:SelectProfile().id == "druid_feral_raid", "Feral druid defaults to the cat profile, not the bear one")
ns.char.gearProfile = "druid_bear_raid"
check(G:SelectProfile().id == "druid_bear_raid", "a chosen profile overrides detection")
ns.char.gearProfile = "rogue_combat_raid"
check(G:SelectProfile().id == "druid_feral_raid", "a chosen profile of another class is ignored")
as("MAGE", 40)
check(G:SelectProfile().id == "mage_leveling", "level-40 mage: leveling profile")

-- Scoring and caps --------------------------------------------------------------------------------------------
local raid = G:ProfileById("rogue_combat_raid")
local s = G:Score(G:ItemData(90001), raid, nil, {})
check(math.abs(s - 20 * 2.214) < 1e-6, "score = sum(stat x weight); unweighted stamina adds nothing")
local ring = G:ItemData(90003)
check(math.abs(G:Score(ring, raid, nil, { hit = 0 }) - 10 * 2.852) < 1e-6, "hit below the cap counts fully")
check(G:Score(ring, raid, nil, { hit = 142 }) == 0, "hit above the cap counts for nothing")
check(math.abs(G:Score(ring, raid, { stats = { hit = 10 } }, { hit = 142 }) - 10 * 2.852) < 1e-6,
    "swapping hit for hit at the cap stays neutral (replaced item's hit is removed first)")
check(math.abs(G:Score(ring, raid, nil, { hit = 137 }) - 5 * 2.852) < 1e-6, "partial overcap: only the hit up to the cap counts")
check(G:Score(G:ItemData(90001), G:ProfileById("rogue_leveling")) == nil, "priority-only profiles never produce a number")

-- Comparisons ---------------------------------------------------------------------------------------------------
as("ROGUE", 70)
ns.char.gearProfile = "rogue_combat_raid"
local r = G:Compare(90001)
check(r.ok and r.numeric and r.empty and r.pct == nil, "empty slot: score shown, no upgrade percentage")
MOCK.equipped[8] = 90002
r = G:Compare(90001)
check(r.ok and math.abs(r.pct - 100) < 1e-6 and r.slot == 8, "upgrade % = (new - old) / old x 100 against the same slot")
check(string.find(G:Summary(r, true), "+100% score", 1, true), "summary labels the % as a score change")
check(not string.find(G:Summary(r, false), "%", 1, true), "percentage can be hidden")
MOCK.equipped[8] = 90012 -- current item scores 0 (cloak in feet slot is fine for the test)
r = G:Compare(90001)
check(r.ok and r.pct == nil, "no percentage when the equipped item scores 0")
r = G:Compare(90011)
check(not r.ok and r.reason == "item not loaded yet", "uncached items are not compared")
r = G:Compare(90004)
check(not r.ok and r.unusable, "rogue cannot use plate")
-- Dual wield: compare with the weaker hand
MOCK.equipped[16], MOCK.equipped[17] = 90006, 90007
r = G:Compare(90006)
check(r.ok and r.slot == 17, "one-hander for a dual wielder is compared with the weaker hand")
-- Two-hander vs main hand + off hand
as("WARRIOR", 70) talents(2, 41)
MOCK.equipped[16], MOCK.equipped[17] = 90006, 90007
r = G:Compare(90005)
check(r.ok and math.abs(r.current - (15 * 1.4)) < 1e-6 and r.slot == 16, "two-hander is compared with main hand + off hand together")
local dpsNote = false
for _, n in ipairs(r.notes) do if string.find(n, "weapon DPS", 1, true) then dpsNote = true end end
check(dpsNote, "weapon DPS is listed as not scored")
MOCK.equipped[16], MOCK.equipped[17] = 90005, nil
r = G:Compare(90010)
local twoHandNote = false
for _, n in ipairs(r.notes) do if string.find(n, "two-hander", 1, true) then twoHandNote = true end end
check(r.ok and twoHandNote, "shield while wielding a two-hander notes the swap")
as("PRIEST", 70)
r = G:Compare(90007)
check(r.ok and r.slot == 16, "a priest (no dual wield) compares one-handers with the main hand only")
r = G:Compare(90010)
check(not r.ok and r.unusable, "priest cannot use a shield")
as("HUNTER", 30)
r = G:Compare(90008)
check(not r.ok and string.find(r.reason, "40", 1, true), "hunter below 40 cannot wear mail yet")
as("DRUID", 70) talents(2, 41)
MOCK.equipped[16] = 90013
r = G:Compare(90007)
check(r.ok, "druid can use a dagger")

-- Priority-only comparisons ----------------------------------------------------------------------------------
as("ROGUE", 30)
MOCK.equipped[8] = 90002
r = G:Compare(90001)
check(r.ok and not r.numeric and r.verdict == "better" and r.score == nil and r.pct == nil, "leveling rogue: better on listed stats, no number")
I[90014] = { name = "Hit Boots", classID = 4, subclassID = 2, equipLoc = "INVTYPE_FEET", stats = { ITEM_MOD_HIT_RATING_SHORT = 8 } }
r = G:Compare(90014)
check(r.verdict == "mixed" and string.find(G:Summary(r), "+8 Hit", 1, true) and string.find(G:Summary(r), "-10 Agility", 1, true),
    "mixed result lists the differences in priority order")
as("WARRIOR", 20)
r = G:Compare(90001)
check(not r.ok and r.noProfile, "no profile: no score, a reason instead")

-- Tooltip ---------------------------------------------------------------------------------------------------
as("ROGUE", 70)
ns.char.gearProfile = "rogue_combat_raid"
MOCK.equipped[8] = 90002
local tt = GameTooltip
tt.lines, tt.item = {}, 90001
local fire = tt.scripts.OnTooltipSetItem
check(type(fire) == "function", "item tooltip hook installed")
fire(tt)
local n1 = #tt.lines
fire(tt)
check(n1 >= 2 and #tt.lines == n1, "tooltip block added once (no duplicates on repeated OnTooltipSetItem)")
check(string.find(tt.lines[1], "Score", 1, true) and string.find(table.concat(tt.lines, "\n"), "confidence", 1, true), "tooltip shows score and confidence")
tt.scripts.OnTooltipCleared(tt)
tt.lines = {}
ns.db.profile.gearTooltip = false
fire(tt)
check(#tt.lines == 0, "tooltip lines can be turned off")
ns.db.profile.gearTooltip = true
tt.scripts.OnHide(tt)
tt.lines, tt.item = {}, 4242424 -- unknown item
fire(tt)
check(#tt.lines == 0, "unknown item adds nothing")

-- Quest rewards -------------------------------------------------------------------------------------------------
MOCK.calls, MOCK.printed = {}, {}
MOCK.dialog = { questID = 77001, title = "Boot Quest", choices = 2, completable = true }
MOCK.questChoices = { 90002, 90001 }
MOCK.equipped[8] = nil
MOCK.fire("QUEST_COMPLETE")
MOCK.tick(1)
local out = table.concat(MOCK.printed, "\n")
local a, b = string.find(out, "Agile Boots", 1, true), string.find(out, "Old Boots", 1, true)
check(string.find(out, "Reward comparison", 1, true) and a and b and a < b, "rewards ranked best first in chat")
check(string.find(out, "You choose the reward", 1, true), "ranking says the player chooses")
local picked = false
for _, c in ipairs(MOCK.calls) do if string.find(c, "^reward:") then picked = true end end
check(not picked, "a reward is never chosen automatically when there are several")
MOCK.printed = {}
MOCK.fire("QUEST_COMPLETE")
MOCK.tick(1)
check(not string.find(table.concat(MOCK.printed, "\n"), "Reward comparison", 1, true), "each quest's rewards are ranked once")
MOCK.dialog, MOCK.questChoices = nil, {}

-- /tbcg gear and /tbcgear ------------------------------------------------------------------------------------
MOCK.printed = {}
MOCK.bags[0][1] = { itemID = 90001, count = 1 }
MOCK.equipped[8] = 90002
local ok, err = pcall(SlashCmdList["TBCGUIDE"], "gear")
out = table.concat(MOCK.printed, "\n")
check(ok and string.find(out, "Gear profile", 1, true) and string.find(out, "Agile Boots", 1, true), "/tbcg gear lists profile and bag upgrades: " .. tostring(err))
check(string.find(out, "Empty slots", 1, true) ~= nil, "/tbcg gear lists empty slots")
check(SlashCmdList["TBCGEAR"] ~= nil and SLASH_TBCGEAR1 == "/tbcgear", "/tbcgear registered")
for _, c in ipairs({ "gear profiles", "gear profile auto", "gear profile rogue_combat_preraid", "gear profile nope", "gear options" }) do
    ok, err = pcall(SlashCmdList["TBCGUIDE"], c)
    check(ok, "/tbcg " .. c .. " -> " .. tostring(err))
end
check(ns.char.gearProfile == "rogue_combat_preraid", "/tbcg gear profile <id> saves the choice")
GUI:ResetSettings()
check(ns.char.gearProfile == nil and ns.db.profile.gearTooltip == true, "reset restores gear defaults")
MOCK.bags[0][1] = nil

-- Restore the default test character
as("WARRIOR", 1)
