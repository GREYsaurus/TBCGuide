-- TBCGuide - headless tests for class trainer suggestions (loaded by run_tests.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- The spellbook is a set of known spell ids behind a mocked IsSpellKnown.

local check, ns = TEST.check, TEST.ns
local TR, D, NOTES = ns.Trainer, ns.TrainingData, ns.TrainingNotes
local prof = ns.db.profile

-- 1) Generated data -------------------------------------------------------------------------------
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local byId, names = {}, {}
local sane = true
for _, c in ipairs(CLASSES) do
    local list = D.classes[c]
    check(type(list) == "table" and #list > 80, c .. ": trainer data present (" .. tostring(list and #list) .. " ranks)")
    byId[c], names[c] = {}, {}
    for _, r in ipairs(list or {}) do
        byId[c][r[1]] = r
        names[c][r[5]] = true
        if not (r[2] >= 2 and r[2] <= 70 and r[3] >= 0) then sane = false print("  bad level/rank: " .. c .. " " .. r[1]) end
        if r[6] == 1 and (r[3] < 2 or r[4] == 0) then sane = false print("  talent rank without previous rank: " .. c .. " " .. r[1]) end
    end
end
check(sane, "levels 2-70; talent ranks are rank 2+ and point at the rank before")
-- Hand notes point at real data.
local missing = {}
for c, q in pairs(NOTES.quest) do
    for id in pairs(q) do if not byId[c][id] then missing[#missing + 1] = c .. " quest spell " .. id end end
end
for _, key in ipairs({ "important", "optional" }) do
    for c, list in pairs(NOTES[key]) do
        for _, n in ipairs(list) do if not names[c][n] then missing[#missing + 1] = c .. " " .. key .. " '" .. n .. "'" end end
    end
end
for _, m in ipairs(missing) do print("  not in TrainingData: " .. m) end
check(#missing == 0, "every hand-listed spell (quest, important, optional) exists in the generated data")

-- Known values from the client tables.
local function find(c, name, rank) for _, r in ipairs(D.classes[c]) do if r[5] == name and r[3] == rank then return r end end end
local rend2 = find("WARRIOR", "Rend", 2)
check(rend2 and rend2[1] == 6546 and rend2[2] == 10 and rend2[4] == 772, "Warrior Rend rank 2: 6546 at level 10 after 772")
local ms2 = find("WARRIOR", "Mortal Strike", 2)
check(ms2 and ms2[6] == 1 and ms2[4] == 12294, "Mortal Strike rank 2 is a talent rank after the talent spell 12294")
check(find("WARRIOR", "Mortal Strike", 1) == nil, "talent rank 1 is not a trainer spell")
local star = find("PRIEST", "Starshards", 1)
check(star and star[7] == 8, "Starshards is Night Elf only (race mask 8)")

-- 2) Live suggestions ---------------------------------------------------------------------------------
local known = {}
local realKnown = IsSpellKnown
IsSpellKnown = function(id) return known[id] == true end
local saveP = { MOCK.player.class, MOCK.player.race, MOCK.player.level, MOCK.player.faction }
local saveMode, saveDefer = prof.trainerSuggestions, ns.char.trainerDeferLevel
MOCK.player.class, MOCK.player.race, MOCK.player.faction, MOCK.player.level = "WARRIOR", "Human", "Alliance", 10
ns.char.trainerDeferLevel = nil
local function ids(list) local s = {} for _, e in ipairs(list) do s[e.id] = true end return s end

known[772] = true -- Rend 1
prof.trainerSuggestions = "all"
local a = TR:Available()
local r = ids(a.ready)
check(r[6546] and r[2687] and r[100], "level 10: Rend 2, Bloodrage and Charge are ready")
check(not r[71] and ids(a.quest)[71], "Defensive Stance is listed as a class quest, not a trainer spell")
check(not r[1680], "Whirlwind (36) is not offered at 10")
known[6546] = true
check(not ids(TR:Available().ready)[6546], "a known rank is not suggested again")

MOCK.player.level = 48
check(not ids(TR:Available().ready)[21551], "Mortal Strike 2 needs the talent first")
known[12294] = true
check(ids(TR:Available().ready)[21551], "with the talent, Mortal Strike 2 is suggested")

prof.trainerSuggestions = "important"
local imp = TR:Available()
local onlyImportant = true
for _, e in ipairs(imp.ready) do if e.prio ~= 1 then onlyImportant = false end end
check(onlyImportant and #imp.ready > 0, "Important only lists important spells")
check(not ids(imp.ready)[694], "Mocking Blow (optional) is not in Important only")

-- Group text
local g = TR.Group({ { id = 1, name = "Rend", rank = 2, prio = 1 }, { id = 2, name = "Rend", rank = 3, prio = 1 } })
check(#g == 1 and TR.GroupText(g[1]) == g[1].name .. " (Rank 2, 3)" and #g[1].ranks == 2, "ranks of one spell share a line")

-- Race-only spells
MOCK.player.class, MOCK.player.race, MOCK.player.level = "PRIEST", "Human", 20
prof.trainerSuggestions = "all"
check(not ids(TR:Available().ready)[10797], "Starshards is not offered to a Human priest")
MOCK.player.race = "NightElf"
check(ids(TR:Available().ready)[10797], "Starshards is offered to a Night Elf priest")

-- Route: train steps skip when nothing is left; Off never skips.
MOCK.player.class, MOCK.player.race, MOCK.player.level = "WARRIOR", "Human", 4
for _, e in ipairs(TR:Entries("WARRIOR")) do if e.level <= 4 then known[e.id] = true end end
check(TR:SkipReason() == "nothing new to train yet", "everything known: the train step is skipped")
prof.trainerSuggestions = "important"
check(TR:SkipReason() == "nothing important to train yet", "Important only: skip reason says so")
prof.trainerSuggestions = "off"
check(TR:SkipReason() == nil and #TR:Lines() == 0, "Off: train steps behave as before, no list")
prof.trainerSuggestions = "all"
known[772] = nil
TR.skipCache = nil -- the client fires LEARNED_SPELL_IN_TAB, which clears it
check(TR:SkipReason() == nil and #TR:Lines() >= 1, "something to learn: step stays, with the list")

-- Defer and view again
TR:Defer()
check(TR:Deferred() and string.find(TR:Lines()[1], "hidden", 1, true), "deferred until the next level")
MOCK.player.level = 5
TR:OnLevelUp(5)
check(not TR:Deferred(), "a new level ends the deferral")
TR:Defer()
TR:ViewAgain()
check(not TR:Deferred(), "view again shows them at once")

-- No spell API: nothing is claimed.
IsSpellKnown = nil
local realPlayer = IsPlayerSpell
IsPlayerSpell = nil
check(not TR.CanCheck() and TR:SkipReason() == nil and #TR:Available().ready == 0, "no spell API: no skipping, no list")
IsPlayerSpell = realPlayer

-- Nothing is ever bought.
local bought = 0
local realBuy = BuyTrainerService
BuyTrainerService = function() bought = bought + 1 end
IsSpellKnown = function(id) return known[id] == true end
TR:Report(true)
TR:OnLevelUp(6)
check(bought == 0, "suggestions never buy from the trainer")
BuyTrainerService = realBuy

-- Waypoint: a class trainer of your faction.
MOCK.player.class, MOCK.player.faction = "WARRIOR", "Alliance"
local z, x, y, name = TR:NearestTrainer()
check(z and x and y and name, "nearest trainer found for an Alliance warrior (" .. tostring(name) .. ")")

IsSpellKnown = realKnown
MOCK.player.class, MOCK.player.race, MOCK.player.level, MOCK.player.faction = saveP[1], saveP[2], saveP[3], saveP[4]
prof.trainerSuggestions, ns.char.trainerDeferLevel = saveMode, saveDefer
