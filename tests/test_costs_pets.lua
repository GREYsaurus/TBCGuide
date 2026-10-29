-- TBCGuide - headless tests for training costs and pet/demon skill guidance (loaded by run_tests.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only

local check, ns = TEST.check, TEST.ns
local TR, PS, D = ns.Trainer, ns.PetSkills, ns.TrainingData
local prof = ns.db.profile

-- English spell names from the generated data stand in for the client's GetSpellInfo.
local names = {}
for _, list in pairs(D.classes) do for _, r in ipairs(list) do names[r[1]] = r[5] end end
for id, s in pairs(ns.PetData.hunter.skills) do names[id] = s[1] end
for _, d in pairs(ns.PetData.demons) do for _, s in ipairs(d.skills) do names[s[1]] = s[2] end end
local real = { GetSpellInfo = GetSpellInfo, IsSpellKnown = IsSpellKnown, UnitLevel = UnitLevel, GetMoney = GetMoney,
    BuyTrainerService = BuyTrainerService, UnitExists = UnitExists }
GetSpellInfo = function(id) return names[id] or "Spell", nil, "icon" end
local known = {}
IsSpellKnown = function(id) return known[id] == true end
local saveP = { MOCK.player.class, MOCK.player.level, prof.trainerSuggestions, ns.char.trainerDeferLevel, ns.char.petDeferLevel }
local bought = 0
BuyTrainerService = function() bought = bought + 1 end
TR.cache, TR.nameIndex = {}, nil

-- 1) Training costs -----------------------------------------------------------------------------------
MOCK.player.class, MOCK.player.level = "WARRIOR", 10
prof.trainerSuggestions = "all"
ns.char.trainerDeferLevel = nil
known[772] = true -- Rend 1
local services = {
    { "Rend", "Rank 2", "available", 1000 },
    { "Bloodrage", "", "available", 500 },
    { "Heroic Strike", "Rank 3", "unavailable", 1800 },
}
GetNumTrainerServices = function() return #services end
GetTrainerServiceInfo = function(i) local s = services[i] return s[1], s[2], s[3] end
GetTrainerServiceCost = function(i) return services[i][4] end
IsTradeskillTrainer = function() return false end
ns.db.trainCosts = {}
TR:ScanTrainer()
local function entry(id) for _, e in ipairs(TR:Entries("WARRIOR")) do if e.id == id then return e end end end
local c, kind = TR:Cost(entry(6546))
check(c == 1000 and kind == "current", "open trainer: Rend 2 costs 10 silver, read live")
check(ns.db.trainCosts[6546] and ns.db.trainCosts[6546].c == 1000, "price is remembered as copper for later")
local a = TR:Available()
local bill = TR:Bill(a.ready)
check(bill.total >= 1500 and not bill.complete and bill.unknown > 0, "total of known prices; unknown prices make it partial")
local txt = TR.BillText(bill, "Total")
check(string.find(txt, "partial", 1, true) and not string.find(txt, "afford", 1, true), "a partial total never claims you can afford it")
local full = TR:Bill({ entry(6546), entry(2687) })
GetMoney = function() return 1200 end
check(full.complete and full.total == 1500 and string.find(TR.BillText(full, "Total"), "short", 1, true), "complete total: says how much you are short")
GetMoney = function() return 5000 end
check(string.find(TR.BillText(full, "Total"), "can afford", 1, true), "complete total: says you can afford it")
MOCK.fire("TRAINER_CLOSED")
c, kind = TR:Cost(entry(6546))
check(c == 1000 and kind == "seen", "after closing the trainer the price is labelled as last seen")
known[6546] = true
check(not (function() for _, e in ipairs(TR:Available().ready) do if e.id == 6546 then return true end end end)(), "a learned rank leaves the bill")
local before = ns.db.trainCosts[2687] and ns.db.trainCosts[2687].c
IsTradeskillTrainer = function() return true end
services[2][4] = 99999
TR:ScanTrainer()
check((ns.db.trainCosts[2687] and ns.db.trainCosts[2687].c) == before, "profession trainers are not read as class prices")
IsTradeskillTrainer = function() return false end
local lines = TR:Lines(6)
local hasTotal = false
for _, l in ipairs(lines) do if string.find(l, "Total", 1, true) then hasTotal = true end end
check(hasTotal, "train step shows a total line")
check(bought == 0, "costs never buy anything")

-- 2) Hunter pet skills -----------------------------------------------------------------------------------
MOCK.player.class, MOCK.player.level = "HUNTER", 20
local petBook = { { "Bite", "Rank 2" }, { "Growl", "Rank 2" }, { "Furious Howl", "Rank 1" } }
UnitExists = function(u) if u == "pet" then return true end return real.UnitExists and real.UnitExists(u) end
UnitLevel = function(u) if u == "pet" then return 20 end return MOCK.player.level end
HasPetSpells = function() return #petBook end
GetSpellBookItemName = function(i) local s = petBook[i] return s and s[1], s and s[2] end
GetPetTrainingPoints = function() return 100, 40 end
local wolf
for fid, f in pairs(ns.PetData.hunter.families) do if f.name == "Wolf" then wolf = fid end end
check(PS:HunterFamily(PS:PetBook()) == wolf, "pet family recognized from its family-only skills (Furious Howl -> Wolf)")
ns.char.petSkills = nil
local adv = PS:HunterAdvice()
local function rec(list, n) for _, r in ipairs(list) do if r.name == n then return r end end end
local growl, bite = rec(adv.recs, "Growl"), rec(adv.recs, "Bite")
check(adv.tp == 60 and growl and growl.rank == 3 and bite and bite.rank == 3, "level-20 wolf: Growl 3 and Bite 3 suggested, 60 training points free")
check(string.find(growl.how, "pet trainers", 1, true) and string.find(bite.how, "tame a beast", 1, true) and string.find(bite.how, "stable", 1, true),
    "unknown ranks: Growl from a pet trainer; Bite by taming, with the stable warning")
check(adv.note ~= nil, "until Beast Training is opened, the advice says so")
-- Enchanting uses the same craft window: not read as Beast Training.
GetNumCrafts = function() return 2 end
GetCraftInfo = function(i) return ({ "Enchant Bracer - Stamina", "Enchant Boots - Agility" })[i], "", "optimal", 0, nil, 0, 0 end
PS:ScanBeastTraining()
check(next(PS.Store().beast) == nil, "an Enchanting window is not mistaken for Beast Training")
GetCraftInfo = function(i) return ({ "Bite", "Growl" })[i], "Rank 3", "optimal", 0, nil, ({ 10, 15 })[i], ({ 16, 20 })[i] end
PS:ScanBeastTraining()
bite = rec(PS:HunterAdvice().recs, "Bite")
check(bite and string.find(bite.how, "Beast Training (10 training points; you have 60)", 1, true), "known rank: teach it in Beast Training with its training-point cost")
petBook[1][2] = "Rank 3"
check(rec(PS:HunterAdvice().recs, "Bite") == nil, "a rank the pet already has is not suggested")
UnitExists = function() return false end
check(PS:HunterAdvice().state == "no pet", "no pet out: nothing is guessed")

-- 3) Warlock demons ----------------------------------------------------------------------------------------
MOCK.player.class, MOCK.player.level = "WARLOCK", 20
ns.char.petSkills = nil
known = { [688] = true } -- Summon Imp
local da = PS:DemonAdvice()
check(#da.recs == 0 and #da.unseen == 1, "imp never summoned: asks to summon it once instead of guessing")
UnitExists = function(u) return u == "pet" end
petBook = { { "Firebolt", "Rank 1" }, { "Blood Pact", "Rank 1" }, { "Fire Shield", "Rank 1" }, { "Phase Shift", "" } }
PS:ScanDemon()
MOCK.bags[0][7] = { itemID = 16316 } -- Grimoire of Firebolt (Rank 3)
da = PS:DemonAdvice()
local fb, bp = rec(da.recs, "Firebolt"), rec(da.recs, "Blood Pact")
check(fb and fb.rank == 3 and fb.item == 16316 and fb.price == 1500 and fb.owned, "Firebolt 3: its Grimoire, base price 15 silver, already in your bags")
check(bp and bp.rank == 2, "Blood Pact 2 suggested at level 20")
check(rec(da.recs, "Torment") == nil, "demons you cannot summon are not listed")
petBook[1][2] = "Rank 3"
PS:ScanDemon()
check(rec(PS:DemonAdvice().recs, "Firebolt") == nil, "after using the Grimoire, Firebolt 3 is known and drops off")
MOCK.bags[0][7] = nil
PS:Defer()
check(#PS:Lines(3) == 0, "deferred: no pet or demon lines until the next level")
ns.char.petDeferLevel = nil

-- cleanup
GetSpellInfo, IsSpellKnown, UnitLevel, GetMoney, BuyTrainerService, UnitExists = real.GetSpellInfo, real.IsSpellKnown, real.UnitLevel, real.GetMoney, real.BuyTrainerService, real.UnitExists
GetNumTrainerServices, GetTrainerServiceInfo, GetTrainerServiceCost, IsTradeskillTrainer = nil, nil, nil, nil
HasPetSpells, GetSpellBookItemName, GetPetTrainingPoints, GetNumCrafts, GetCraftInfo = nil, nil, nil, nil, nil
MOCK.player.class, MOCK.player.level, prof.trainerSuggestions, ns.char.trainerDeferLevel, ns.char.petDeferLevel = saveP[1], saveP[2], saveP[3], saveP[4], saveP[5]
ns.char.petSkills, ns.db.trainCosts, TR.cache, TR.nameIndex, TR.live, TR.trainerOpen = nil, {}, {}, nil, {}, false
