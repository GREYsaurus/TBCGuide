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
    check(#seq == 61, "build " .. b.id .. " uses 61 points (" .. #seq .. ")")
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

-- Automation (junk selling, quest accept / turn-in) and raid markers -----------------------------
TEST = { check = check, ns = ns }
dofile("tests/test_automation.lua")
dofile("tests/test_markers.lua")

print(string.format("%d passed, %d failed", passes, failures))
os.exit(failures == 0 and 0 or 1)
