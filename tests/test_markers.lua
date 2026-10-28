-- TBCGuide - headless tests for raid markers (loaded by run_tests.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Drives Core/Marker.lua through the mocked client (tests/mock_wow.lua), whose raid icons behave
-- like the real API: one icon per unit, one unit per icon, same icon again toggles it off.

local check, ns = TEST.check, TEST.ns
local M = ns.Marker
local prof = ns.db.profile

local function printedSince(mark, pattern)
    for i = mark + 1, #MOCK.printed do
        if string.find(MOCK.printed[i], pattern, 1, true) then return true end
    end
    return false
end
local function slash(cmd) return pcall(SlashCmdList["TBCGUIDE"], cmd) end
local function reset()
    MOCK.units, MOCK.icons, MOCK.markCalls, MOCK.markDenied = {}, {}, 0, false
    MOCK.inRaid, MOCK.leader, MOCK.assist, MOCK.combat = false, false, false, false
end
local function target(u) MOCK.units.target = u; MOCK.fire("PLAYER_TARGET_CHANGED"); MOCK.tick(0.6) end
local function iconOf(u) return MOCK.icons[u.guid] end

check(M.Parse("skull") == 8 and M.Parse("Star") == 1 and M.Parse("7") == 7 and M.Parse("bogus") == nil, "marker names parse")
check(prof.markEnabled and prof.autoMark and not prof.markReplace and prof.defaultMarker == 8, "documented marker defaults")

-- 1) No target ---------------------------------------------------------------------------------
reset()
local mark = #MOCK.printed
local ok = slash("mark skull")
check(ok and printedSince(mark, "no target") and MOCK.markCalls == 0, "no target: helpful message, nothing marked")

-- 2) Mark the current target; 3) clear it -------------------------------------------------------
local boar = MOCK.creature(3098, 1, "Mottled Boar")
MOCK.units.target = boar
mark = #MOCK.printed
slash("mark skull")
MOCK.tick(0.6)
check(iconOf(boar) == 8 and printedSince(mark, "Marked Mottled Boar"), "manual mark sets skull and reports it")
mark = #MOCK.printed
slash("mark skull")
check(iconOf(boar) == 8 and printedSince(mark, "already has"), "same icon again does not toggle it off")
slash("unmark")
MOCK.tick(0.6)
check(iconOf(boar) == nil, "unmark clears the icon")
mark = #MOCK.printed
slash("unmark")
check(printedSince(mark, "no raid marker"), "unmark without a marker explains")
slash("marker cross")
slash("mark")
MOCK.tick(0.6)
check(prof.defaultMarker == 7 and iconOf(boar) == 7, "default marker used when no icon is given")
prof.defaultMarker = 8

-- 4) Permissions ------------------------------------------------------------------------------
reset()
MOCK.units.target = boar
MOCK.inRaid = true
mark = #MOCK.printed
slash("mark star")
check(MOCK.markCalls == 0 and printedSince(mark, "leader and assistants"), "raid without assist: refused with reason")
MOCK.assist = true
slash("mark star")
MOCK.tick(0.6)
check(iconOf(boar) == 1, "raid assistant can mark")
reset()

-- 5) Automatic marking from a guide step --------------------------------------------------------
-- Durotar: "complete 790 Sarkoth [mark=skull]" resolves to Sarkoth (npc 3281).
local function loadStepWith(guideId, pred)
    ns.Engine:Load(guideId, { reset = true })
    local g = ns.Engine.guide
    local idx
    for i, s in ipairs(g.steps) do if pred(s) then idx = i break end end
    local p = ns.Engine.progress
    for i = 1, idx - 1 do p.done[i] = true end
    ns.Engine:Refresh()
    return idx
end
MOCK.questLog, MOCK.completed = {}, {}
ns.Tracker.turnedIn = {}
ns.Tracker:Scan()
local idx = loadStepWith("H_OrcTroll_Durotar", function(s) return s[1] == "complete" and s.q == 790 end)
check(ns.Engine.current == idx and M.rule and M.rule.icon == 8 and M.rule.npcs[3281], "guide step carries a skull rule for Sarkoth")

local sarkoth = MOCK.creature(3281, 11, "Sarkoth")
mark = #MOCK.printed
target(sarkoth)
check(iconOf(sarkoth) == 8 and printedSince(mark, "Marked Sarkoth"), "guide step marks its NPC when targeted")

-- not every frame: considering the same unit again makes no new call
local calls = MOCK.markCalls
for _ = 1, 20 do M:Consider("target") end
MOCK.fire("UPDATE_MOUSEOVER_UNIT")
check(MOCK.markCalls == calls, "no repeated marking attempts for the same unit")

-- 6) Same name, different NPC id: never marked
local impostor = MOCK.creature(99001, 1, "Sarkoth")
target(impostor)
check(iconOf(impostor) == nil, "same name but different NPC id is not marked")
local scorpid = MOCK.creature(3124, 2, "Scorpid Worker")
target(scorpid)
check(iconOf(scorpid) == nil, "unrelated mob is not marked")

-- one live unit holds the icon: a second Sarkoth spawn does not steal it
local sarkoth2 = MOCK.creature(3281, 12, "Sarkoth")
MOCK.units.mouseover = sarkoth2
MOCK.fire("UPDATE_MOUSEOVER_UNIT")
MOCK.tick(0.6)
check(iconOf(sarkoth) == 8 and iconOf(sarkoth2) == nil, "icon stays on the first live unit")

-- 8) Player changes the marker afterwards: never overwritten
MOCK.units.target = sarkoth
SetRaidTarget("target", 2) -- the player picks a circle by hand
MOCK.tick(0.6)
calls = MOCK.markCalls
target(sarkoth)
MOCK.fire("UPDATE_MOUSEOVER_UNIT")
MOCK.tick(0.6)
check(iconOf(sarkoth) == 2 and MOCK.markCalls == calls, "manual change is respected, no re-marking")

-- 7) Target that already has a marker: not replaced unless allowed
reset()
ns.Engine:Refresh()
M:OnStep()
local marked = MOCK.creature(3281, 13, "Sarkoth")
MOCK.icons[marked.guid] = 5
target(marked)
check(iconOf(marked) == 5, "existing marker is not replaced by default")
prof.markReplace = true
M:OnStep()
target(marked)
check(iconOf(marked) == 8, "existing marker replaced only when markReplace is on")
prof.markReplace = false

-- 9) Guide advances: our icon is removed (markClearOnAdvance), others' icons stay
reset()
M:OnStep()
local s1 = MOCK.creature(3281, 21, "Sarkoth")
target(s1)
check(iconOf(s1) == 8, "marked before advancing")
local other = MOCK.creature(3125, 3, "Clattering Scorpid")
MOCK.units.focus = other
MOCK.icons[other.guid] = 3 -- someone else's icon
ns.Engine:Skip()
MOCK.tick(0.6)
check(iconOf(s1) == nil and iconOf(other) == 3, "step advance clears only our own icon")
-- guide abandoned / switched: same clean-up
loadStepWith("H_OrcTroll_Durotar", function(s) return s[1] == "complete" and s.q == 790 end)
local s2 = MOCK.creature(3281, 22, "Sarkoth")
target(s2)
ns.Engine:Load("A_Human_Elwynn")
MOCK.tick(0.6)
check(iconOf(s2) == nil, "switching guide clears our icon")

-- step without a marker: nothing is marked unless the objective rule is enabled
reset()
local j = loadStepWith("A_Human_Elwynn", function(s) return s[1] == "complete" and not s.mark and s.q end)
local q = ns.Engine.guide.steps[j].q
local creatures = ns.DB.GetQuestByID(q).objectives.creatures
if creatures[1] then
    local mob = MOCK.creature(creatures[1], 31, "objective mob")
    target(mob)
    check(M.rule == nil and iconOf(mob) == nil, "unmarked step: nothing marked")
    prof.autoMarkObjectives = true
    M:OnStep()
    target(mob)
    check(iconOf(mob) == prof.defaultMarker, "opt-in objective marking uses the default marker")
    prof.autoMarkObjectives = false
else
    check(true, "unmarked step: (no kill objective in this quest)")
end

-- 10) Client denies / blocks marking ------------------------------------------------------------
reset()
loadStepWith("H_OrcTroll_Durotar", function(s) return s[1] == "complete" and s.q == 790 end)
MOCK.markDenied = true
mark = #MOCK.printed
target(MOCK.creature(3281, 41, "Sarkoth"))
target(MOCK.creature(3281, 42, "Sarkoth"))
check(printedSince(mark, "Could not mark") and not printedSince(mark, "Marked Sarkoth"), "denied marking reported, never claimed")
check(M.stopped and printedSince(mark, "paused"), "automatic marking pauses after repeated failures")
calls = MOCK.markCalls
target(MOCK.creature(3281, 43, "Sarkoth"))
check(MOCK.markCalls == calls, "no further attempts once paused")
reset()
M:OnStep()
MOCK.fire("ADDON_ACTION_BLOCKED", "TBCGuide", "SetRaidTarget()")
calls = MOCK.markCalls
target(MOCK.creature(3281, 44, "Sarkoth"))
check(M.blocked and MOCK.markCalls == calls, "blocked by the client: automatic marking stops")
M.blocked = false

-- Marker bar and settings ----------------------------------------------------------------------
MOCK.combat = true
mark = #MOCK.printed
slash("markbar")
check(printedSince(mark, "out of combat"), "marker bar is not toggled in combat")
MOCK.combat = false
slash("markbar")
check(prof.showMarkerBar == true, "marker bar toggles out of combat")
slash("markbar")
for _, cmd in ipairs({ "markers", "marker", "marker bogus", "mark bogus", "debug marks", "set autoMark off", "set autoMark on" }) do
    local okc, err = slash(cmd)
    check(okc, "/tbcg " .. cmd .. " -> " .. tostring(err))
end
TBCGuideDB.profile.defaultMarker = 42
ns:InitSavedVariables()
check(ns.db.profile.defaultMarker == 8, "invalid default marker repaired")
check(#ns.errors == 0, "no captured errors after marker tests: " .. table.concat(ns.errors, " | "))
reset()
