-- TBCGuide - headless test runner (Lua 5.1). Run from the repository root:
--     lua5.1 tests/run_tests.lua
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Runs under any Lua 5.1 interpreter (verified with the Lua 5.1 runtime bundled in Python's
-- `lupa` package; see docs/DEVELOPER.md).

dofile("tests/mock_wow.lua")

local ADDON = "TBCGuide"
local root = "TBCGuide/"
local ns = {}
local failures, passes = 0, 0

local function check(cond, msg)
    if cond then passes = passes + 1 else failures = failures + 1; print("FAIL: " .. msg) end
end

-- Load files in TOC order (expanding XML <Script file=...> includes).
local function loadFile(path)
    local chunk, err = loadfile(path)
    if not chunk then error("load " .. path .. ": " .. tostring(err)) end
    chunk(ADDON, ns)
end

local function loadXml(path, dir)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    for file in string.gmatch(text, '<Script%s+file="([^"]+)"') do
        loadFile(dir .. file:gsub("\\", "/"))
    end
end

local toc = assert(io.open(root .. "TBCGuide.toc", "r"))
for line in toc:lines() do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then
        local rel = line:gsub("\\", "/")
        if rel:match("%.xml$") then
            loadXml(root .. rel, root .. rel:match("^(.*/)"))
        else
            loadFile(root .. rel)
        end
    end
end
toc:close()

-- Boot ------------------------------------------------------------------------------------------
MOCK.fire("ADDON_LOADED", ADDON)
MOCK.fire("PLAYER_LOGIN")
MOCK.tick(0.5)

check(type(ns.db) == "table" and type(ns.char) == "table", "saved variables initialised")
check(#ns.errors == 0, "no captured errors after boot: " .. table.concat(ns.errors, " | "))
check(#ns.Guides.list >= 50, "guides registered (" .. #ns.Guides.list .. ")")
check(#ns.Guides.rejected == 0, "no rejected guides")
check(ns.Engine.guide ~= nil and ns.Engine.guide.id == "A_Human_Elwynn", "human warrior gets the Elwynn start guide")
check(SlashCmdList["TBCGUIDE"] ~= nil, "slash command registered")

-- Database adapter --------------------------------------------------------------------------------
local q = ns.DB.GetQuestByID(783)
check(q and q.name == "A Threat Within", "quest 783 lookup")
check(ns.DB.GetQuestFactionRestrictions(783) == "Alliance", "quest 783 is Alliance")
local z, x, y = ns.DB.GetNPCPosition(823)
check(z == 12 and x and y, "Deputy Willem position")
check(ns.DB.GetQuestByID(99999999) == nil, "missing quest returns nil")

-- Progression: accept the first quest ---------------------------------------------------------------
local first = ns.Engine:CurrentStep()
check(first and first[1] == "accept" and first.q == 783, "first step is accept 783")
table.insert(MOCK.questLog, { id = 783, title = "A Threat Within", complete = true, objectives = {} })
MOCK.fire("QUEST_ACCEPTED", 1, 783)
MOCK.tick(0.5)
local second = ns.Engine:CurrentStep()
check(second and second[1] == "turnin" and second.q == 783, "advances to turn-in after accepting")

-- Turn in
table.remove(MOCK.questLog, 1)
MOCK.completed[783] = true
MOCK.fire("QUEST_TURNED_IN", 783, 0, 0)
MOCK.tick(0.5)
check(ns.Engine:CurrentStep().q ~= 783, "advances past turn-in")

-- Manual controls
local before = ns.Engine.current
ns.Engine:Skip()
check(ns.Engine.current ~= before, "skip advances")
ns.Engine:Prev()
check(ns.Engine.current == before, "prev reopens skipped step")

-- Saved variables survive a "reload"
local saved = TBCGuideCharDB
TBCGuideCharDB = saved
ns:InitSavedVariables()
check(ns.char.activeGuide == "A_Human_Elwynn", "active guide persisted")
-- Corrupt progress is repaired, not fatal
TBCGuideCharDB.progress["A_Human_Elwynn"] = "garbage"
ns:InitSavedVariables()
check(type(ns.char.progress["A_Human_Elwynn"]) ~= "string", "corrupt progress record removed")

-- Talents ------------------------------------------------------------------------------------------
for _, b in ipairs(ns.Talents.buildList) do
    local seq, errors = ns.Talents:Expand(b)
    check(#errors == 0, "build " .. b.id .. " valid: " .. table.concat(errors, "; "))
    -- Exception: the Icy Veins Destruction build spends 59 points (docs/TALENTS.md); nothing is invented.
    local want = b.id == "warlock_destro_iv" and 59 or 61
    check(#seq == want, "build " .. b.id .. " uses " .. want .. " points (" .. #seq .. ")")
end

-- Selector for every race/class at level 1 and at 60
for raceKey, rec in pairs(ns.RaceClass.races) do
    for _, cls in ipairs(rec.classes) do
        local info = { race = raceKey, class = cls, faction = rec.faction, level = 1 }
        local g = ns.Selector:Recommend(info)
        check(g and g.start, "start guide for " .. raceKey .. " " .. cls)
        local route = ns.Selector:RouteFor(info)
        check(#route > 0 and route[#route].maxLevel == 70, "route to 70 for " .. raceKey .. " " .. cls)
    end
end

-- Commands do not error
for _, cmd in ipairs({ "", "help", "guide", "talents", "debug", "debug api", "debug talents", "debug quest 783", "class", "bogus" }) do
    local ok, err = pcall(SlashCmdList["TBCGUIDE"], cmd)
    check(ok, "/tbcg " .. cmd .. " -> " .. tostring(err))
end

-- Grind steps -------------------------------------------------------------------------------------
-- Registered in memory only (no guide file). Completion must follow the player's LEVEL, never XP.
local G = ns.Guides
local nRejected, nErrors = #G.rejected, #ns.errors
G:Register({ id = "T_GrindNoLevel", name = "t", faction = "Alliance", steps = { { "grind", mobs = { "X" } } } })
check(G.byId["T_GrindNoLevel"] == nil and #G.rejected == nRejected + 1, "registry rejects a grind step without a level")
table.remove(G.rejected) -- the deliberate rejection above is not a real error
while #ns.errors > nErrors do table.remove(ns.errors) end
G:Register({ id = "T_Grind", name = "Grind test", faction = "Alliance", minLevel = 3, maxLevel = 5, steps = {
    { "note", text = "before" },
    { "grind", level = 5, mobs = { "Riverpaw Outrunner", "Riverpaw Runt" }, location = "south of Westbrook Garrison",
      z = 12, x = 27.8, y = 81.2, text = "Kill gnolls until 5." },
    { "note", text = "after" },
} })
check(G.byId["T_Grind"] ~= nil, "registry accepts a valid grind step")
MOCK.player.level = 3
ns.Engine:Load("T_Grind", { reset = true })
ns.Engine:MarkDone(1)
check(ns.Engine.current == 2 and ns.Engine.status[2] == "active", "grind step becomes the current step")
for _ = 1, 3 do ns.Engine:Refresh() end
MOCK.fire("PLAYER_XP_UPDATE")
MOCK.tick(1)
check(ns.Engine.current == 2, "grind step stays active below the target level (XP into the level does not complete it)")
local gs = ns.Engine:CurrentStep()
check(string.find(ns.StepText:Title(gs), "Grind Riverpaw Outrunner, Riverpaw Runt at south of Westbrook Garrison until level 5", 1, true),
    "title names the mobs, the place and the target level")
local det = table.concat(ns.StepText:Details(gs), "\n")
check(string.find(det, "Level 3", 1, true) and string.find(det, "Kill gnolls until 5.", 1, true), "details show level progress and the guide note")
local tz, tx, ty, tlabel = ns.StepText:Target(gs)
check(tz == 12 and tx == 27.8 and ty == 81.2 and tlabel == "south of Westbrook Garrison", "navigation target is the grind spot")
check(pcall(function() ns.MainFrame:Render() end), "main window renders a grind step")
MOCK.player.level = 4
MOCK.fire("PLAYER_LEVEL_UP", 4)
MOCK.tick(1)
check(ns.Engine.current == 2, "one level short: still grinding")
MOCK.player.level = 5
MOCK.fire("PLAYER_LEVEL_UP", 5)
MOCK.tick(1)
check(ns.Engine.current == 3 and ns.Engine.status[2] == "done", "reaching the target level completes it and the guide advances")
check(ns.Engine.progress.done[2] == true, "completion is remembered like a level step")
-- The shipped example: Elwynn's level-10 gate is a grind step on database-verified gnolls.
local elw, found = G.byId["A_Human_Elwynn"], nil
for _, s in ipairs(elw.steps) do if s[1] == "grind" then found = s end end
check(found and found.level == 10 and found.mobs[1] == "Riverpaw Outrunner" and found.location, "Elwynn ships one grind step (level 10, Riverpaw gnolls)")
MOCK.player.level = 1
ns.Engine:Load("A_Human_Elwynn")

-- Class quests in the starting guides -------------------------------------------------------------
-- Every level-1 class quest in the database that a starting guide's races can take, whose giver
-- stands in the guide's zone and whose prerequisite the guide hands in, must be in that guide
-- (accept and turn-in) exactly once.
local QD = ns.QDB.QUEST
local function stepsFor(g, kind, q)
    local out = {}
    for i, s in ipairs(g.steps) do if s[1] == kind and s.q == q then out[#out + 1] = i end end
    return out
end
for _, g in ipairs(G.list) do
    if g.start and g.races then
        local mask, turnedIn = 0, {}
        for _, r in ipairs(g.races) do mask = mask + (ns.QDB.RACE_BITS[r] or 0) end
        for _, s in ipairs(g.steps) do if s[1] == "turnin" and s.q then turnedIn[s.q] = true end end
        for id, r in pairs(ns.QDB.quests) do
            local races, pre = r[QD.RACES] or 0, r[QD.PRE_SINGLE]
            local giver = r[QD.START_NPCS] and ns.QDB.npcs[r[QD.START_NPCS][1]]
            local unlocked = pre == nil
            for _, p in ipairs(pre or {}) do if turnedIn[p] then unlocked = true end end
            local reachable = unlocked and giver ~= nil and giver[ns.QDB.NPC.ZONE] == g.zone
            if (r[QD.CLASSES] or 0) ~= 0 and r[QD.REQ_LEVEL] == 1 and races ~= 0 and races % (2 * mask) >= 1 and reachable then
                local fits = false
                for _, rn in ipairs(g.races) do local b = ns.QDB.RACE_BITS[rn]; if races % (2 * b) >= b then fits = true end end
                if fits then
                    check(#stepsFor(g, "accept", id) == 1 and #stepsFor(g, "turnin", id) == 1,
                        g.id .. " has class quest " .. id .. " " .. tostring(r[QD.NAME]) .. " once (accept + turn-in)")
                end
            end
        end
    end
end
-- The reported bug: Verdant Note (3094) for tauren druids, after The Hunt Begins (747).
local mul = G.byId["H_Tauren_Mulgore"]
local va, vt, hb = stepsFor(mul, "accept", 3094)[1], stepsFor(mul, "turnin", 3094)[1], stepsFor(mul, "turnin", 747)[1]
check(va and vt and hb and hb < va and va < vt, "Verdant Note is accepted after The Hunt Begins and turned in later")
check(G:StepApplies(mul.steps[va], { race = "Tauren", class = "DRUID", faction = "Horde" })
    and not G:StepApplies(mul.steps[va], { race = "Tauren", class = "WARRIOR", faction = "Horde" }), "Verdant Note applies to druids only")
MOCK.player.race, MOCK.player.class, MOCK.player.faction = "Tauren", "DRUID", "Horde"
ns.Engine:Load("H_Tauren_Mulgore", { reset = true })
MOCK.completed[747] = true
for i = 1, va - 1 do if ns.Engine.status[i] ~= "na" then ns.Engine.progress.done[i] = true end end
ns.Engine:Refresh()
check(ns.Engine.current == va and ns.Engine:CurrentStep().q == 3094, "tauren druid reaches the Verdant Note step")
table.insert(MOCK.questLog, { id = 3094, title = "Verdant Note", complete = true, objectives = {} })
MOCK.fire("QUEST_ACCEPTED", 1, 3094)
MOCK.tick(0.5)
check(ns.Engine.status[va] == "done", "accepting Verdant Note completes its step")
table.remove(MOCK.questLog)
MOCK.completed[3094] = true
MOCK.fire("QUEST_TURNED_IN", 3094, 0, 0)
MOCK.tick(0.5)
check(ns.Engine.status[vt] == "done", "turning in Verdant Note completes its turn-in step")
MOCK.completed[747], MOCK.completed[3094] = nil, nil
MOCK.player.race, MOCK.player.class, MOCK.player.faction = "Human", "WARRIOR", "Alliance"
ns.Engine:Load("A_Human_Elwynn")

-- Automation (junk selling, quest accept / turn-in) and raid markers -----------------------------
TEST = { check = check, ns = ns }
dofile("tests/test_automation.lua")
dofile("tests/test_markers.lua")
dofile("tests/test_gear.lua")
dofile("tests/test_minimap.lua")
dofile("tests/test_config.lua")
dofile("tests/test_dungeons.lua")
dofile("tests/test_autoequip.lua")
dofile("tests/test_features.lua")
dofile("tests/test_auction.lua")
dofile("tests/test_routes10.lua")
dofile("tests/test_locales_bags_setup.lua")
dofile("tests/test_trainer.lua")
dofile("tests/test_talent_hints.lua")

print(string.format("%d passed, %d failed", passes, failures))
os.exit(failures == 0 and 0 or 1)
