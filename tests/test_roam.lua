-- TBCGuide - headless tests for roaming hunting routes (loaded by run_tests.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only

local check, ns = TEST.check, TEST.ns
local R, E, Nav = ns.Roam, ns.Engine, ns.Nav
local prof = ns.db.profile

-- Real map sizes in yards (UiMapAssignment), so arrival radii mean what they mean in the game.
local SIZE = { [1429] = { 3470.8, 2314.6 }, [1438] = { 5091.7, 3393.8 } }
local pos = { map = 1429, x = 0.40, y = 0.60 }
local real = { best = C_Map.GetBestMapForUnit, ppos = C_Map.GetPlayerMapPosition, world = C_Map.GetWorldPosFromMapPos,
    inst = IsInInstance, log = MOCK.questLog, roam = prof.roamRoutes }
C_Map.GetBestMapForUnit = function() return pos.map end
C_Map.GetPlayerMapPosition = function()
    if not pos.x then return nil end
    return { GetXY = function() return pos.x, pos.y end }
end
C_Map.GetWorldPosFromMapPos = function(map, v)
    local s = SIZE[map]
    if not s then return nil end
    return map, { GetXY = function() return v.x * s[1], v.y * s[2] end }
end
local instance = false
IsInInstance = function() if instance then return true, "party" end return false, "none" end
local function at(x, y) pos.x, pos.y = x / 100, y / 100 end
local function tick(n) for _ = 1, n or 1 do MOCK.tick(0.55) end end
local function quest(id, objs) MOCK.questLog = { { id = id, title = "Q" .. id, objectives = objs } } ns.Tracker:Scan() end
prof.roamRoutes = true

-- Kill objective, one target (Kobold Camp Cleanup) ----------------------------------------------------
E:Load("A_Human_Elwynn", { reset = true })
local function stepFor(q)
    for i, s in ipairs(E.guide.steps) do if s[1] == "complete" and s.q == q then return i end end
end
local function goTo(i)
    for j = 1, #E.guide.steps do E.progress.done[j], E.progress.skipped[j] = j < i or nil, nil end
    E:Refresh()
end
local i7 = stepFor(7)
at(47.6, 35.8) -- standing on the first point
quest(7, { { text = "Kobold Vermin slain: 0/10", done = false } })
goTo(i7)
check(E.current == i7, "the kill step is current")
check(R.active and R.active.route.name == "Kobold Camp Cleanup: Kobold Vermin", "a kill step with a verified route starts it")
check(Nav.owner == "route", "the route owns the arrow")
check(R.active.idx == 2 and Nav.target.x == 49.6, "already at the nearest point: starts at the next one")
check(string.find(Nav.target.label, "Kobold Vermin slain: 0/10", 1, true) and string.find(Nav.target.label, "point 2 of 3", 1, true),
    "the label shows the log's objective text and the point number")
tick(10)
check(R.active.idx == 2, "standing still (fighting, looting) never advances: no timers")
at(49.6, 35.7)
tick()
check(R.active.idx == 3, "arriving at the point advances once")
tick(5)
check(R.active.idx == 3, "staying there does not advance again")
at(51.3, 37.0)
tick()
check(R.active.idx == 1, "after the last point the route loops to the first")
tick() -- still at the last point: now seen outside the first
at(47.6, 35.8)
tick()
check(R.active.idx == 2 and E.current == i7, "arriving never completes the step")
-- Hysteresis: a point only counts after the player was seen outside 1.3 x its radius.
R.active.armed = false
at(49.6, 35.7)
tick()
check(R.active.idx == 2, "inside the point without having been seen outside it: no advance")
at(48.0, 30.0)
tick()
at(49.6, 35.7)
tick()
check(R.active.idx == 3, "seen outside, then inside: counts once")
tick(5)
check(R.active.idx == 3, "no rapid cycling while standing still")

-- No position: hold the point
local held = R.active.idx
pos.x = nil
tick(3)
check(R.active.idx == held and R.active.paused and string.find(R:StatusLine(), "paused", 1, true), "no player position: pauses on the same point")
at(47.6, 35.8)

-- Manual skip
check(R:Next() and R.active.idx == held % 3 + 1 and Nav.target.x == R.active.route.pts[R.active.idx][1], "Next patrol point moves the arrow to the next point")
held = R.active.idx
check(E.current == i7, "skipping a point does not skip the quest step")

-- Partial progress and party credit
quest(7, { { text = "Kobold Vermin slain: 7/10", done = false } })
check(R.active and R.active.idx == held, "partial progress: the route keeps running from the same point")
quest(7, { { text = "Kobold Vermin slain: 10/10", done = true } })
check(R.active == nil, "objective complete (own kill or party credit): the route ends at once")
check(Nav.owner ~= "route", "and hands the arrow back")

-- Abandoned quest
quest(7, { { text = "Kobold Vermin slain: 2/10", done = false } })
goTo(i7)
check(R.active ~= nil, "route back with the quest in the log")
MOCK.questLog = {} ns.Tracker:Scan()
check(R.active == nil, "quest abandoned: route cancelled")

-- Missing or mismatched quest data: conservative fallback
quest(7, {})
goTo(i7)
check(R.active == nil, "objectives not loaded yet: no route, normal waypoint")
quest(7, { { text = "Kobold Vermin slain: 0/10", done = false, type = "item" } })
check(R.active == nil, "the log's objective type does not match the route: no route")
quest(7, { { text = "Kobold Vermin slain: 0/10", done = false } })
check(R.active ~= nil, "log data arrives: the route starts")
local realLocale = GetLocale
GetLocale = function() return "enUS" end
quest(7, { { text = "Defias Thug slain: 0/10", done = false } })
check(R.active == nil, "English client, objective text names another target: no route (log order differs from data)")
quest(7, { { text = "Kobold Vermin slain: 0/10", done = false } })
check(R.active ~= nil, "English client, matching objective text: route")
GetLocale = function() return "deDE" end
quest(7, { { text = "Koboldungeziefer getötet: 0/10", done = false } })
check(R.active ~= nil, "other languages: order and type decide")
GetLocale = realLocale
quest(7, { { text = "Kobold Vermin slain: 0/10", done = false } })

-- Manual waypoint is respected
Nav:SetTarget(12, 41.1, 65.7, "Trainer") -- e.g. /tbcg train waypoint
local idx = R.active.idx
R:Next()
check(Nav.owner == "manual" and Nav.target.x == 41.1 and R.active.idx == idx % 3 + 1, "a waypoint you chose is not replaced by the route")
quest(7, { { text = "Kobold Vermin slain: 1/10", done = false } })
check(Nav.owner == "manual", "quest updates do not replace it either")
R:Resume()
check(Nav.owner == "route", "/tbcg route on takes the arrow back")

-- Suspend / resume, settings, instance, step and guide changes
R:Suspend()
check(R.active == nil and Nav.owner == "step", "Normal objective waypoint: route off for this step")
R:Refresh()
check(R.active == nil, "it stays off while on this step")
R:Resume()
check(R.active ~= nil, "and comes back on request")
prof.roamRoutes = false
R:Refresh()
check(R.active == nil and Nav.owner == "step", "setting off: normal navigation")
prof.roamRoutes = true
R:Refresh()
check(R.active ~= nil, "setting on again: the route resumes")
instance = true
tick()
check(R.active == nil, "inside an instance: the route stops")
instance = false
R:Refresh()
check(R.active ~= nil, "back outside: resumes")
E:Skip(i7)
check(R.active == nil and Nav.owner ~= "route", "step skipped: the stale route waypoint is cleared")
goTo(i7)
check(R.active ~= nil, "back on the step: route")

-- Reload: nothing saved, rebuilt from the log and the nearest point
R.active = nil
at(51.2, 37.1)
R:Refresh()
check(R.active and R.active.idx == 1, "after a reload: revalidated and resumed after the nearest point")
local saved = false
for k in pairs(ns.char) do if string.find(string.lower(tostring(k)), "roam") or string.find(string.lower(tostring(k)), "route") then saved = true end end
check(not saved, "no route state is saved")

-- Unsupported objectives keep the normal waypoint
local i15 = nil
for i, s in ipairs(E.guide.steps) do if s[1] == "complete" and s.q and not ns.RoamRoutes[s.q] then i15 = i break end end
quest(E.guide.steps[i15].q, { { text = "x: 0/1", done = false } })
goTo(i15)
check(R.active == nil and Nav.owner ~= "route", "a quest without a verified route keeps its normal waypoint")

-- Kill-for-drop (Wolves Across the Border: Tough Wolf Meat)
local i33 = stepFor(33)
at(30, 70)
quest(33, { { text = "Tough Wolf Meat: 2/8", done = false, type = "item" } })
goTo(i33)
check(R.active and R.active.route.objs[1].kind == "drop" and #R.active.route.pts == 7, "kill-for-drop objective: the wolf route")
check(R.active.idx >= 1, "far away: starts at the nearest point")

-- Several targets, separate areas (The Balance of Nature) --------------------------------------------
E:Load("A_NightElf_Teldrassil", { reset = true })
pos.map = 1438
at(58, 45)
local i456
for i, s in ipairs(E.guide.steps) do if s[1] == "complete" and s.q == 456 then i456 = i break end end
local NS, BOAR = "Young Nightsaber slain: 0/7", "Young Thistle Boar slain: 0/4"
quest(456, { { text = NS, done = false }, { text = BOAR, done = false } })
goTo(i456)
check(R.active and R.active.route.objs[1].i == 1, "two targets: the first objective's route runs first")
quest(456, { { text = "Young Nightsaber slain: 3/7", done = false }, { text = "Young Thistle Boar slain: 2/4", done = false } })
check(R.active.route.objs[1].i == 1, "a boar kill does not switch routes (no thrashing)")
quest(456, { { text = "Young Nightsaber slain: 7/7", done = true }, { text = "Young Thistle Boar slain: 2/4", done = false } })
check(R.active and R.active.route.objs[1].i == 2, "nightsabers done: switches to the boar route")
check(string.find(Nav.target.label, "Young Thistle Boar", 1, true), "the label names only the unfinished target")
quest(456, { { text = "Young Nightsaber slain: 7/7", done = true }, { text = "Young Thistle Boar slain: 4/4", done = true } })
check(R.active == nil, "both done: no route")
quest(456, { { text = NS, done = false }, { text = "Young Thistle Boar slain: 4/4", done = true } })
check(R.active and R.active.route.objs[1].i == 1, "already partly done when starting: only the unfinished target's route")

-- Guide change clears everything
E:Load("A_Human_Elwynn", { reset = true })
check(R.active == nil, "guide change: route cleared")

-- Every compiled route: valid map and points, named objectives, one route per objective, used by a guide
local onGuide = {}
for _, g in ipairs(ns.Guides.list) do
    for _, s in ipairs(g.steps) do if s[1] == "complete" and s.q then onGuide[s.q] = true end end
end
local nRoutes, bad, dup, orphan = 0, {}, {}, {}
for q, list in pairs(ns.RoamRoutes) do
    local seenObj = {}
    if not onGuide[q] then orphan[#orphan + 1] = q end
    for _, rt in ipairs(list) do
        nRoutes = nRoutes + 1
        local ok = ns.DB.ZoneUiMap(rt.zone) ~= nil and #rt.pts >= 3 and rt.loop == true and rt.r >= 10 and rt.r <= 40
        for _, p in ipairs(rt.pts) do ok = ok and p[1] > 0 and p[1] < 100 and p[2] > 0 and p[2] < 100 end
        for _, o in ipairs(rt.objs) do
            ok = ok and (o.kind == "kill" or o.kind == "drop") and o.name and o.name ~= ""
            if seenObj[o.i] then dup[#dup + 1] = q .. ":" .. o.i end
            seenObj[o.i] = true
        end
        if not ok then bad[#bad + 1] = q .. " " .. tostring(rt.name) end
    end
end
check(nRoutes >= 100, "route data loaded: " .. nRoutes .. " routes")
check(#bad == 0, "every route has a map, 3+ points inside it, a loop, a sane radius and named objectives " .. table.concat(bad, "; "))
check(#dup == 0, "no objective has two routes " .. table.concat(dup, ", "))
check(#orphan == 0, "every route's quest has a complete step in a guide " .. table.concat(orphan, ", "))

C_Map.GetBestMapForUnit, C_Map.GetPlayerMapPosition, C_Map.GetWorldPosFromMapPos = real.best, real.ppos, real.world
IsInInstance, MOCK.questLog, prof.roamRoutes = real.inst, real.log, real.roam
ns.Tracker:Scan()
R:Stop("test end")
