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
        talentHints = true,       -- remind when talent points are unspent
    },
    frames = {
        main = { point = "RIGHT", x = -60, y = 120, w = 320, h = 230, minimized = false, shown = true },
        browser = { point = "CENTER", x = 0, y = 0 },
        talents = { point = "CENTER", x = 0, y = 0 },
        arrow = { point = "TOP", x = 0, y = -120 },
    },
}

local charDefaults = {
    schema = SCHEMA,
    activeGuide = nil,
    progress = {},      -- [guideId] = { step = n, done = { [stepIndex] = true }, skipped = { [stepIndex] = true } }
    history = {},       -- recently used guide ids (most recent first)
    talentBuild = nil,  -- chosen build id for this character
    simTalents = {},    -- [class] = { [talentId] = rank } simulated allocation in the calculator
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
