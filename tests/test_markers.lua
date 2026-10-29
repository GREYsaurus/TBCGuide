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
    M.marked, M.markedNpc, M.holder, M.lastSeen = {}, {}, {}, {} -- a fresh world: no marked units remain
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
check(ns.Engine.current == idx and M.rule and M.rule.types[3281] == 8, "guide step carries a skull rule for Sarkoth")

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

-- 9) Guide advances: our icon is removed (markClearOnAdvance), others' icons stay. Objective
-- marking is off here so the next step does not name Sarkoth again (see 9b for that case).
reset()
prof.autoMarkObjectives = false
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
prof.autoMarkObjectives = true

-- 9b) The next step names the same NPC with the same icon: the icon stays, no clear-and-remark
reset()
loadStepWith("H_OrcTroll_Durotar", function(s) return s[1] == "complete" and s.q == 790 end)
local keep = MOCK.creature(3281, 23, "Sarkoth")
target(keep)
local callsBefore = MOCK.markCalls
ns.Engine:Skip()
MOCK.tick(0.6)
if M.rule and M.rule.types[3281] == 8 then
    check(iconOf(keep) == 8 and MOCK.markCalls == callsBefore, "icon still wanted by the next step is kept, not cleared and re-set")
else
    check(iconOf(keep) == nil, "icon no longer wanted is cleared")
end

-- 11) Objective marking (default on): a step without [mark] marks its kill objective by NPC id
reset()
check(prof.autoMarkObjectives == true, "objective marking is on by default")
local j = loadStepWith("A_Human_Elwynn", function(s)
    local qq = s[1] == "complete" and not s.mark and s.q and ns.DB.GetQuestByID(s.q)
    return qq and qq.objectives.creatures[1] ~= nil
end)
local q = ns.Engine.guide.steps[j].q
local objMob = ns.DB.GetQuestByID(q).objectives.creatures[1]
check(M.rule and M.rule.types[objMob] == prof.defaultMarker, "kill objective gets the default marker")
local mob = MOCK.creature(objMob, 31, "objective mob")
target(mob)
check(iconOf(mob) == prof.defaultMarker, "objective mob marked when targeted")
prof.autoMarkObjectives = false
M:OnStep()
local mob2 = MOCK.creature(objMob, 32, "objective mob")
MOCK.units.target = nil
target(mob2)
check(M.rule == nil and iconOf(mob2) == nil and string.find(M.noRuleWhy, "autoMarkObjectives", 1, true),
    "objective marking off: nothing marked, reason recorded")
prof.autoMarkObjectives = true

-- 12) A marked mob dies: the game drops its icon silently; the next mob of the step gets it
reset()
j = loadStepWith("A_Human_Elwynn", function(s)
    local qq = s[1] == "complete" and not s.mark and s.q and ns.DB.GetQuestByID(s.q)
    return qq and qq.objectives.creatures[1] ~= nil
end)
local first = MOCK.creature(objMob, 41, "objective mob")
target(first)
check(iconOf(first) == prof.defaultMarker, "first mob marked")
local second = MOCK.creature(objMob, 42, "objective mob")
MOCK.units.mouseover = second
MOCK.fire("UPDATE_MOUSEOVER_UNIT")
MOCK.tick(0.6)
check(iconOf(second) == nil, "while the first lives, the second is not marked")
MOCK.kill(first)
MOCK.units.target = nil -- corpse no longer targeted or visible
MOCK.units.mouseover = nil
target(second)
check(iconOf(second) == prof.defaultMarker and not M.stopped, "after the first dies the next mob is marked; marking is not paused")
-- dead unit still visible when an icon event fires: treated as a death, not a manual change
local third = MOCK.creature(objMob, 43, "objective mob")
MOCK.units.focus = second
MOCK.kill(second)
MOCK.fire("RAID_TARGET_UPDATE")
target(third)
check(iconOf(third) == prof.defaultMarker and not M.stopped, "visible corpse without its icon does not pause marking")
MOCK.units.focus = nil
-- holder out of sight for a long time (no death seen): released after the timeout
local fourth = MOCK.creature(objMob, 44, "objective mob")
MOCK.units.target = nil
MOCK.tick(0.1)
target(fourth)
check(iconOf(fourth) == nil, "living holder out of sight keeps the icon for a while")
MOCK.time = MOCK.time + 61
MOCK.units.target = nil
local fifth = MOCK.creature(objMob, 45, "objective mob")
target(fifth)
check(iconOf(fifth) == prof.defaultMarker, "holder unseen for over a minute: icon moves to the next mob")

-- 13) Several kill steps done together: each mob type gets its own icon
reset()
-- Dun Morogh: "complete A New Threat" (troggs 707/724) is followed by "complete The Boar Hunter" (708).
-- (Durotar's makrura parts drop from more than 3 NPC types, so they are deliberately not marked.)
loadStepWith("A_DwarfGnome_DunMorogh", function(s) return s[1] == "complete" and s.q == 170 end)
local r = M.rule
local troggIcon, boarIcon = r and r.types[707], r and r.types[708]
check(troggIcon and boarIcon and troggIcon ~= boarIcon and r.types[724] == troggIcon,
    "parallel kill steps: each mob type has its own icon; variants of one objective share it")
check(troggIcon == prof.defaultMarker, "the first kill step uses the default marker")
local count = 0
for _ in pairs(r and r.icons or {}) do count = count + 1 end
check(count <= M.MAX_TYPES, "no more than " .. M.MAX_TYPES .. " icons handed out")
local trogg = MOCK.creature(707, 51, "Rockjaw Trogg")
local boar = MOCK.creature(708, 52, "Small Crag Boar")
target(trogg)
target(boar)
check(iconOf(trogg) == troggIcon and iconOf(boar) == boarIcon, "both mob types marked with their own icons")
-- the earlier step finishes: the later step's mobs stay covered, the finished one is dropped
local idx170
for i, s in ipairs(ns.Engine.guide.steps) do if s[1] == "complete" and s.q == 170 then idx170 = i break end end
MOCK.units.nameplate1 = trogg -- still in view, so its icon can be removed
ns.Engine:MarkDone(idx170)
MOCK.tick(0.6)
check(M.rule and M.rule.types[708] == boarIcon and M.rule.types[707] == nil and iconOf(boar) == boarIcon and iconOf(trogg) == nil,
    "finishing one kill step keeps the other's icon and clears the finished one's")

-- 14) Combat and groups: marking is allowed in combat and in a party; a raid needs leader/assist
reset()
loadStepWith("H_OrcTroll_Durotar", function(s) return s[1] == "complete" and s.q == 790 end)
MOCK.combat = true
local inCombat = MOCK.creature(3281, 61, "Sarkoth")
target(inCombat)
check(iconOf(inCombat) == 8, "marks in combat (SetRaidTarget is not combat-restricted here)")
MOCK.combat = false
reset()
M:OnStep()
MOCK.inRaid = true
mark = #MOCK.printed
local raidMob = MOCK.creature(3281, 62, "Sarkoth")
target(raidMob)
check(iconOf(raidMob) == nil and MOCK.markCalls == 0 and printedSince(mark, "leader and assistants"), "raid without assist: not marked, explained once")
check(M.last and string.find(M.last.reason, "not permitted", 1, true), "diagnostics record the permission refusal")
MOCK.inRaid = false

-- 15) Disabled in settings
reset()
prof.markEnabled = false
M:OnStep()
local off = MOCK.creature(3281, 71, "Sarkoth")
target(off)
check(M.rule == nil and iconOf(off) == nil and MOCK.markCalls == 0 and string.find(M.noRuleWhy, "markEnabled", 1, true),
    "markEnabled off: nothing marked, reason recorded")
prof.markEnabled = true
prof.autoMark = false
M:OnStep()
target(off)
check(iconOf(off) == nil and string.find(M.noRuleWhy, "autoMark", 1, true), "autoMark off: nothing marked")
prof.autoMark = true
M:OnStep()

-- 16) Diagnostics
mark = #MOCK.printed
local okd, errd = slash("debug marks")
check(okd and printedSince(mark, "raid markers:") and printedSince(mark, "settings:"), "/tbcg debug marks reports rule and settings: " .. tostring(errd))

-- 17) Migration: settings saved by 0.3.x/0.4.0 (objective marking off) are switched on once
local savedDB = TBCGuideDB
TBCGuideDB = { profile = { autoMarkObjectives = false } }
ns.migrationNote = nil
ns:InitSavedVariables()
check(TBCGuideDB.profile.autoMarkObjectives == true and ns.migrationNote ~= nil, "old saved setting switched on once, with a note")
TBCGuideDB.profile.autoMarkObjectives = false -- the player turns it off again
ns.migrationNote = nil
ns:InitSavedVariables()
check(TBCGuideDB.profile.autoMarkObjectives == false and ns.migrationNote == nil, "the player's later choice is kept")
TBCGuideDB = nil
ns:InitSavedVariables()
check(TBCGuideDB.profile.autoMarkObjectives == true and ns.migrationNote == nil, "new install: on by default, no note")
TBCGuideDB = savedDB
ns:InitSavedVariables()
prof = ns.db.profile

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
