-- TBCGuide - headless tests for the corpse waypoint (loaded by run_tests.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only

local check, ns = TEST.check, TEST.ns
local CP, Nav, E, R = ns.Corpse, ns.Nav, ns.Engine, ns.Roam
local prof = ns.db.profile

local state = { ghost = false, map = 1429, corpse = nil, instance = false, parents = { [1429] = 1415, [1415] = 947 } }
local real = { ghost = UnitIsGhost, death = C_DeathInfo, best = C_Map.GetBestMapForUnit, info = C_Map.GetMapInfo,
    inst = IsInInstance, nav = prof.corpseNav, roam = prof.roamRoutes, log = MOCK.questLog }
UnitIsGhost = function() return state.ghost end
C_Map.GetBestMapForUnit = function() return state.map end
C_Map.GetMapInfo = function(m) return { name = "map" .. m, parentMapID = state.parents[m] or 0 } end
IsInInstance = function() if state.instance then return true, "party" end return false, "none" end
local asked = {}
C_DeathInfo = { GetCorpseMapPosition = function(m)
    asked[#asked + 1] = m
    local c = state.corpse
    if c and c.map == m then return { GetXY = function() return c.x, c.y end } end
    return nil
end }
local function fire(ev) MOCK.fire(ev) end
local function printed(text)
    for i = #MOCK.printed, math.max(1, #MOCK.printed - 4), -1 do
        if string.find(MOCK.printed[i] or "", text, 1, true) then return true end
    end
end
prof.corpseNav = true
CP:Reset("test start")

E:Load("A_Human_Elwynn", { reset = true })
E:Refresh()
local stepTarget = Nav.target and Nav.target.x
check(Nav.owner == "step", "the guide owns the arrow before dying")

-- Dead, not released: nothing
fire("PLAYER_DEAD")
check(CP.deathMap == 1429 and not CP:Active() and Nav.owner == "step", "dead but not released: no corpse arrow")

-- Released with a corpse position
state.ghost = true
state.corpse = { map = 1429, x = 0.42, y = 0.65 }
fire("PLAYER_ALIVE")
check(CP:Active() and Nav.owner == "corpse" and Nav.target.mapId == 1429 and Nav.target.x == 42 and Nav.target.y == 65,
    "released: the arrow points at the corpse position from C_DeathInfo")
check(Nav.target.label == "Corpse", "labelled Corpse")
check(asked[1] == 1429, "the death map is asked first; no map is changed")
local n = #MOCK.printed
fire("PLAYER_ALIVE")
fire("PLAYER_ENTERING_WORLD")
check(#MOCK.printed == n and CP:Active(), "repeated events: no duplicate waypoint or message")

-- Guide steps and routes cannot take the arrow; the step itself can still change
E:Refresh()
Nav:FromStep(E:CurrentStep())
check(Nav.owner == "corpse" and Nav.target.x == 42, "guide refreshes do not replace the corpse arrow")
E:Skip()
check(Nav.owner == "corpse", "a step change while dead keeps the corpse arrow")

-- Cross-map run: the ghost is on another map, the corpse is still found on the death map
state.map = 1436
fire("ZONE_CHANGED_NEW_AREA")
check(Nav.target.mapId == 1429 and Nav.target.x == 42, "running across a map border keeps pointing at the corpse")
state.map = 1429

-- Resurrected (at the corpse, by a player or by a spirit healer): back to the current step
state.ghost = false
fire("PLAYER_UNGHOST")
check(not CP:Active() and Nav.owner ~= "corpse", "resurrected: corpse arrow cleared")
check(Nav.owner == "step" or Nav.owner == "route" or Nav.owner == nil, "the arrow goes back to the guide")
local curStep = E:CurrentStep()
local z, x = ns.StepText:Target(curStep)
check(not z or Nav.target and Nav.target.x == x, "restored from the current step (it changed while dead), not a stored waypoint")

-- Delayed corpse data: bounded retries, cancelled on resurrection
fire("PLAYER_DEAD")
state.ghost, state.corpse = true, nil
asked = {}
fire("PLAYER_ALIVE")
check(not CP:Active(), "no corpse position yet: no arrow, never 0,0")
MOCK.tick(2.1)
state.corpse = { map = 1429, x = 0.5, y = 0.5 }
MOCK.tick(2.1)
check(CP:Active() and Nav.target.x == 50, "the position arrives later: retried and found")
fire("PLAYER_DEAD") -- (a second death while still marked active is handled by Reset)
state.ghost, state.corpse = true, nil
fire("PLAYER_ALIVE")
local before = #asked
state.ghost = false
fire("PLAYER_UNGHOST")
MOCK.tick(25)
check(#asked == before and not CP:Active(), "resurrected before the retry: pending retries stop")
fire("PLAYER_DEAD")
state.ghost = true
fire("PLAYER_ALIVE")
MOCK.tick(25)
check(not CP:Active() and printed("not given a corpse position"), "never available: a note after the last retry, no arrow")
local tries = #asked
MOCK.tick(25)
check(#asked == tries, "retries are bounded")
state.ghost = false
fire("PLAYER_UNGHOST")

-- 0,0 is not a position
fire("PLAYER_DEAD")
state.ghost, state.corpse = true, { map = 1429, x = 0, y = 0 }
fire("PLAYER_ALIVE")
check(not CP:Active(), "a 0,0 answer is ignored")
state.ghost = false
fire("PLAYER_UNGHOST")

-- Reload/login as a ghost: no death map known, found through the current map's parents
CP:Reset("reload")
state.ghost, state.map, state.corpse = true, 1429, { map = 1415, x = 0.4, y = 0.7 }
fire("PLAYER_ENTERING_WORLD")
check(CP:Active() and Nav.target.mapId == 1415 and Nav.target.x == 40, "logged in as a ghost: found on the continent map")
state.ghost = false
fire("PLAYER_ALIVE")
check(not CP:Active(), "PLAYER_ALIVE when not a ghost (resurrected before releasing): cleared")

-- Dismiss and resume; a manual waypoint dismisses it
fire("PLAYER_DEAD")
state.ghost, state.corpse = true, { map = 1429, x = 0.3, y = 0.3 }
fire("PLAYER_ALIVE")
CP:Dismiss()
check(not CP:Active() and Nav.owner ~= "corpse", "/tbcg corpse off: back to the guide")
fire("ZONE_CHANGED_NEW_AREA")
MOCK.tick(5)
check(not CP:Active(), "dismissed: not recreated on its own")
CP:Resume()
check(CP:Active() and Nav.owner == "corpse", "/tbcg corpse on: back to the corpse")
Nav:SetTarget(12, 41.1, 65.7, "Trainer")
check(Nav.owner == "manual" and not CP:Active(), "a waypoint you ask for replaces the corpse arrow")
CP:Resume()
check(CP:Active(), "and the corpse arrow can be resumed")

-- Disabling the setting while active
prof.corpseNav = false
CP:OnSetting()
check(not CP:Active() and Nav.owner ~= "corpse", "setting off: cleared at once, normal navigation")
prof.corpseNav = true
CP:OnSetting()
check(CP:Active(), "setting on again while a ghost: corpse arrow")
state.ghost = false
fire("PLAYER_UNGHOST")

-- Instance death: no outdoor position, no arrow
state.instance = true
fire("PLAYER_DEAD")
state.instance, state.ghost, state.corpse = false, true, { map = 1429, x = 0.3, y = 0.3 }
fire("PLAYER_ALIVE")
check(not CP:Active() and printed("inside an instance"), "died in an instance: a note, no arrow")
state.ghost = false
fire("PLAYER_UNGHOST")

-- No active guide
E.guide, E.current = nil, nil
fire("PLAYER_DEAD")
state.ghost, state.corpse = true, { map = 1429, x = 0.6, y = 0.6 }
fire("PLAYER_ALIVE")
check(CP:Active() and Nav.target.x == 60, "works without a guide")
state.ghost = false
fire("PLAYER_UNGHOST")
check(not CP:Active() and Nav.target == nil, "resurrected without a guide: no arrow")

-- Hunting routes pause and resume
E:Load("A_Human_Elwynn", { reset = true })
local i7
for i, s in ipairs(E.guide.steps) do if s[1] == "complete" and s.q == 7 then i7 = i break end end
for j = 1, #E.guide.steps do E.progress.done[j] = j < i7 or nil end
prof.roamRoutes = true
MOCK.questLog = { { id = 7, title = "Q7", objectives = { { text = "Kobold Vermin slain: 0/10", done = false } } } }
ns.Tracker:Scan()
E:Refresh()
check(Nav.owner == "route", "a hunting route owns the arrow")
fire("PLAYER_DEAD")
state.ghost, state.corpse = true, { map = 1429, x = 0.3, y = 0.3 }
fire("PLAYER_ALIVE")
check(Nav.owner == "corpse", "dying hands the arrow to the corpse")
R:Next()
check(Nav.owner == "corpse", "the route's point changes do not take the arrow back")
state.ghost = false
fire("PLAYER_UNGHOST")
check(Nav.owner == "route", "resurrected: the hunting route takes the arrow again")

UnitIsGhost, C_DeathInfo, C_Map.GetBestMapForUnit, C_Map.GetMapInfo, IsInInstance = real.ghost, real.death, real.best, real.info, real.inst
prof.corpseNav, prof.roamRoutes, MOCK.questLog = real.nav, real.roam, real.log
CP:Reset("test end")
ns.Tracker:Scan()
