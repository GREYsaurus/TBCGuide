-- TBCGuide - headless tests: 1.0 route pass (saved-progress remap, under-level pickups, notes)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
-- Loaded by tests/run_tests.lua after boot; uses TEST.check and TEST.ns.

local check, ns = TEST.check, TEST.ns
local E, G = ns.Engine, ns.Guides

-- Saved progress follows reordered steps -------------------------------------------------------------
local L = ns.GuideLayouts and ns.GuideLayouts.H_Barrens
check(L and L.layout == 2 and next(L.map), "H_Barrens has a step layout map")
local oldIdx, newIdx
for k, v in pairs(L.map) do oldIdx, newIdx = k, v break end
ns.char.progress.H_Barrens = { step = oldIdx, done = { [oldIdx] = true }, skipped = { [1] = true } }
local p = ns:GetProgress("H_Barrens")
check(p.layout == 2 and p.done[newIdx] == true and (oldIdx == newIdx or not p.done[oldIdx]), "done step moved to its new index")
check(p.step == newIdx, "current step moved too")
check(p.skipped[L.map[1] or 1] == true, "skipped steps moved")
local again = ns:GetProgress("H_Barrens")
check(again.done[newIdx] == true, "the remap runs once")
ns:ResetProgress("H_Barrens")
check(ns.char.progress.H_Barrens.layout == 2, "fresh progress records the current layout")
check(ns:GetProgress("A_Human_Elwynn").layout == (ns.GuideLayouts.A_Human_Elwynn and 2 or nil), "guides without changes keep no layout")
-- the map is a permutation of the old steps onto the new ones
for id, lay in pairs(ns.GuideLayouts) do
    local seen, ok = {}, true
    for _, v in pairs(lay.map) do if seen[v] then ok = false end seen[v] = true end
    check(ok and G.byId[id] ~= nil, id .. ": layout map is one-to-one and names a real guide")
end

-- Under-level pickups are skipped, not blocking ---------------------------------------------------------
G:Register({ id = "T_LevelGate", name = "Level gate test", faction = "Horde", minLevel = 10, maxLevel = 20, steps = {
    { "note", text = "start" },
    { "accept", q = 6563 },                 -- requires level 20 in the data
    { "note", text = "after" },
    { "note", text = "later" },
} })
MOCK.player.race, MOCK.player.class, MOCK.player.faction, MOCK.player.level = "Orc", "WARRIOR", "Horde", 15
MOCK.questLog, MOCK.completed = {}, {}
ns.Tracker.turnedIn = {}
ns.Tracker:Scan()
local req = select(2, ns.DB.GetQuestLevel(6563))
check(req and req > 15, "test quest needs more than level 15 (" .. tostring(req) .. ")")
-- prerequisite 6562 counts as done for this test
MOCK.completed[6562] = true
ns.Tracker:Scan()
E:Load("T_LevelGate", { reset = true })
E:MarkDone(1)
check(E.status[2] == "skipped" and string.find(E.autoReason[2], "needs level", 1, true), "below the required level: skipped with the reason")
check(E.current == 3, "the guide moves on instead of blocking")
MOCK.player.level = req
E:Refresh()
check(E.current == 2, "reaching the level before moving on brings the pickup back")
MOCK.player.level = 15
E:Refresh()
E:MarkDone(3)
MOCK.player.level = req
E:Refresh()
check(E.status[2] == "skipped" and string.find(E.autoReason[2], "passed", 1, true) and E.current == 4,
    "after moving on it stays skipped (no jump back)")
MOCK.completed[6562] = nil

-- Notes on imported steps ----------------------------------------------------------------------------------
local withDrop, gateNotes = 0, 0
for _, g in ipairs(G.list) do
    for _, s in ipairs(g.steps) do
        if s.text and string.find(s.text, "drops from", 1, true) then withDrop = withDrop + 1 end
        if s.text and string.find(s.text, "If you are lower, TBCGuide skips it", 1, true) then gateNotes = gateNotes + 1 end
    end
end
check(withDrop >= 50, "drop-source notes on objective steps (" .. withDrop .. ")")
check(gateNotes >= 20, "level notes on gated pickups (" .. gateNotes .. ")")

-- restore
MOCK.player.race, MOCK.player.class, MOCK.player.faction, MOCK.player.level = "Human", "WARRIOR", "Alliance", 1
E:Load("A_Human_Elwynn", { reset = true })
check(#ns.errors == 0, "no captured errors after route tests: " .. table.concat(ns.errors, " | "))
