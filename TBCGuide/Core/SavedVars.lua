-- TBCGuide - saved variables, defaults and migrations
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- TBCGuideDB      (account-wide): UI/profile settings
-- TBCGuideCharDB  (per character): active guide, per-guide progress, simulated talents
-- Both are validated on load; anything malformed is reset field-by-field, never wholesale.

local _, ns = ...

local SCHEMA = 1

local accountDefaults = {
    schema = SCHEMA,
    profile = {
        debug = false,
        autoAdvance = true,       -- move to the next step when a reliable completion signal arrives
        autoSelectGuide = true,   -- pick a guide automatically on first login
        showArrow = true,
        showMapPins = true,
        useTomTom = true,
        stepsShown = 4,           -- current step + upcoming
        scale = 1,
        locked = false,
        hideCompletedOptional = false,
        showDungeonSteps = true,
        showElite = true,
        speedRoute = false,       -- maximum-speed route: hide [optional] side quests (documented default: off)
        talentHints = true,       -- remind when talent points are unspent
        -- Automation (docs/AUTOMATION.md). Quest automation only ever touches quests that have an
        -- open step in the active guide; escort quests and reward choices are always manual.
        autoAccept = true,          -- accept guide quests when their offer panel opens
        autoAcceptOptional = false, -- ...including steps marked [optional]
        autoAcceptGroup = false,    -- ...including [elite]/[group]/[dungeon] steps
        autoTurnIn = true,          -- turn in guide quests that need no reward choice
        turnInUnrelated = false,    -- also turn in completed quests that are not in the guide
        questNotify = true,         -- chat messages for accepted / turned-in / manual quests
        autoSellJunk = false,       -- OFF by default: sell grey (Poor) items when a vendor opens
        sellNotify = true,          -- chat summary of junk sales
        sellNotifyItems = false,    -- one chat line per item sold
        grindEnabled = true,        -- enable grinding steps
        grindAutoComplete = true,   -- automatically complete grinding steps when XP target is reached
        grindEstimates = false,     -- show estimated kills or time remaining
        -- Raid markers (docs/RAID_MARKERS.md)
        markEnabled = true,         -- /tbcg mark, the marker bar and guide marking
        autoMark = true,            -- mark NPCs the current guide step names with [mark=...]
        autoMarkObjectives = false, -- also mark kill objectives of unmarked steps (default icon)
        markReplace = false,        -- automatic marking may replace an existing icon
        markClearOnAdvance = true,  -- remove our automatic icons when the step changes
        markNotify = true,          -- chat messages for marking results
        defaultMarker = 8,          -- 1 star .. 8 skull
        showMarkerBar = false,
    },
    protectedItems = {},    -- [itemID] = true: never sold automatically
    protectedClasses = {},  -- [itemClassID] = true/false: overrides Vendor.CLASSES defaults
    escortExtra = {},       -- [questID] = true: extra quests that must never be auto-accepted
    frames = {
        main = { point = "RIGHT", x = -60, y = 120, w = 320, h = 230, minimized = false, shown = true },
        browser = { point = "CENTER", x = 0, y = 0 },
        talents = { point = "CENTER", x = 0, y = 0 },
        arrow = { point = "TOP", x = 0, y = -120 },
        orphans = { point = "CENTER", x = 0, y = 0 },
        markerBar = { point = "TOP", x = 0, y = -200 },
    },
}

local charDefaults = {
    schema = SCHEMA,
    activeGuide = nil,
    progress = {},      -- [guideId] = { step = n, done = { [stepIndex] = true }, skipped = { [stepIndex] = true } }
    history = {},       -- recently used guide ids (most recent first)
    talentBuild = nil,  -- chosen build id for this character
    simTalents = {},    -- [class] = { [talentId] = rank } simulated allocation in the calculator
    junkStats = { items = 0, copper = 0 }, -- confirmed automatic junk sales (all time)
}

local function sanitizeProgress(p)
    if type(p) ~= "table" then return {} end
    for guideId, rec in pairs(p) do
        if type(guideId) ~= "string" or type(rec) ~= "table" then
            p[guideId] = nil
        else
            if type(rec.step) ~= "number" or rec.step < 1 then rec.step = 1 end
            if type(rec.done) ~= "table" then rec.done = {} end
            if type(rec.skipped) ~= "table" then rec.skipped = {} end
        end
    end
    return p
end

function ns:InitSavedVariables()
    if type(TBCGuideDB) ~= "table" then TBCGuideDB = {} end
    if type(TBCGuideCharDB) ~= "table" then TBCGuideCharDB = {} end
    ns.Merge(TBCGuideDB, accountDefaults)
    ns.Merge(TBCGuideCharDB, charDefaults)
    TBCGuideCharDB.progress = sanitizeProgress(TBCGuideCharDB.progress)
    if type(TBCGuideCharDB.history) ~= "table" then TBCGuideCharDB.history = {} end
    if type(TBCGuideCharDB.simTalents) ~= "table" then TBCGuideCharDB.simTalents = {} end
    for _, key in ipairs({ "protectedItems", "protectedClasses", "escortExtra" }) do
        if type(TBCGuideDB[key]) ~= "table" then TBCGuideDB[key] = {} end
    end
    local dm = TBCGuideDB.profile.defaultMarker
    if type(dm) ~= "number" or dm < 1 or dm > 8 then TBCGuideDB.profile.defaultMarker = 8 end
    local js = TBCGuideCharDB.junkStats
    if type(js) ~= "table" or type(js.items) ~= "number" or type(js.copper) ~= "number" then
        TBCGuideCharDB.junkStats = { items = 0, copper = 0 }
    end
    if TBCGuideCharDB.activeGuide ~= nil and type(TBCGuideCharDB.activeGuide) ~= "string" then
        TBCGuideCharDB.activeGuide = nil
    end
    -- Future migrations: if TBCGuideDB.schema < N then ... end
    TBCGuideDB.schema = SCHEMA
    TBCGuideCharDB.schema = SCHEMA
    ns.db = TBCGuideDB
    ns.char = TBCGuideCharDB
end

function ns:GetProgress(guideId)
    local p = ns.char.progress[guideId]
    if not p then
        p = { step = 1, done = {}, skipped = {} }
        ns.char.progress[guideId] = p
    end
    return p
end

function ns:ResetProgress(guideId)
    ns.char.progress[guideId] = { step = 1, done = {}, skipped = {} }
end

function ns:ResetSettings()
    TBCGuideDB = nil
    ns:InitSavedVariables()
end
