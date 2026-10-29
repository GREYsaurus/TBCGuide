-- TBCGuide - class trainer suggestions
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Which spell ranks your class trainer has for you now, from the client's own tables
-- (Classes/TrainingData.lua) checked live against your spellbook (IsSpellKnown). Setting
-- "Class Trainer Suggestions": Off / Important only / All (docs/TRAINER.md).
--   - Talent ranks are listed only once you know the rank before (that is, took the talent).
--   - Spells from class quests are listed apart and never count as a reason to visit a trainer.
--   - Race-only spells are listed only for that race.
-- Suggestions only inform. Nothing is bought here; the separate, opt-in "Auto-train" assist is the
-- only thing in TBCGuide that ever spends money at a trainer.

local _, ns = ...

local TR = { cache = {} }
ns.Trainer = TR

local PRIO_NAME = { "important", "useful", "optional" }
TR.PRIO_NAME = PRIO_NAME

local function prof() return ns.db.profile end

local function raceBit(race)
    local b = ns.QDB and ns.QDB.RACE_BITS and ns.QDB.RACE_BITS[race]
    return b or 0
end

-- The class's entries, with priority and quest notes resolved once.
function TR:Entries(class)
    if self.cache[class] then return self.cache[class] end
    local data = ns.TrainingData and ns.TrainingData.classes[class] or {}
    local notes = ns.TrainingNotes or {}
    local imp, opt = {}, {}
    for _, n in ipairs((notes.important or {})[class] or {}) do imp[n] = true end
    for _, n in ipairs((notes.optional or {})[class] or {}) do opt[n] = true end
    local quest = (notes.quest or {})[class] or {}
    local out = {}
    for _, r in ipairs(data) do
        local name = r[5]
        local prio = imp[name] and 1 or opt[name] and 3 or 2
        if prio == 2 then
            for _, pat in ipairs(notes.optionalPattern or {}) do
                if string.find(name, pat) then prio = 3 break end
            end
        end
        out[#out + 1] = { id = r[1], level = r[2], rank = r[3], prev = r[4], name = name, talent = r[6] == 1,
            race = r[7], prio = prio, quest = quest[r[1]] }
    end
    self.cache[class] = out
    return out
end

-- nil when the client cannot tell (then suggestions are not shown at all).
function TR.Known(id)
    if IsSpellKnown then return IsSpellKnown(id) and true or false end
    if IsPlayerSpell then return IsPlayerSpell(id) and true or false end
    return nil
end

function TR.CanCheck() return (IsSpellKnown or IsPlayerSpell) and true or false end

-- Localized name and rank text from the client; the English data name if the client has none.
function TR.SpellName(e)
    local n = GetSpellInfo and GetSpellInfo(e.id)
    return n or e.name
end

-- Status of one entry for this character: "ready", "later", "known", "talent" (needs the talent
-- or rank before), "quest", "race".
function TR:Status(e, level, race)
    if e.race ~= 0 and not ns.HasBit(e.race, raceBit(race)) then return "race" end
    if TR.Known(e.id) then return "known" end
    if e.quest then return "quest" end
    if e.level > level then return "later" end
    if e.talent and e.prev ~= 0 and not TR.Known(e.prev) then return "talent" end
    return "ready"
end

function TR:Mode()
    local m = prof().trainerSuggestions
    if m == "off" or m == "important" or m == "all" then return m end
    return "important"
end

-- What the trainer has for you now: { ready = {entries}, quest = {entries}, level = n }.
-- `mode` overrides the setting ("important" or "all"); deferred levels are ignored here.
function TR:Available(mode, level)
    local info = ns.Compat.PlayerInfo()
    level = level or info.level
    mode = mode or self:Mode()
    local res = { ready = {}, quest = {}, level = level }
    if mode == "off" or not TR.CanCheck() then return res end
    for _, e in ipairs(self:Entries(info.class)) do
        local st = self:Status(e, level, info.race)
        if st == "ready" and (mode == "all" or e.prio == 1) then res.ready[#res.ready + 1] = e
        elseif st == "quest" and e.level <= level then res.quest[#res.quest + 1] = e end
    end
    table.sort(res.ready, function(a, b)
        if a.prio ~= b.prio then return a.prio < b.prio end
        if a.level ~= b.level then return a.level < b.level end
        if a.name ~= b.name then return a.name < b.name end
        return a.rank < b.rank
    end)
    return res
end

-- Grouped one line per spell: "Rend (Rank 2, 3)".
function TR.Group(list)
    local out, at = {}, {}
    for _, e in ipairs(list) do
        local key = e.name
        local g = at[key]
        if not g then
            g = { name = TR.SpellName(e), prio = e.prio, ranks = {}, first = e }
            at[key] = g
            out[#out + 1] = g
        end
        if e.rank > 0 then g.ranks[#g.ranks + 1] = e.rank end
    end
    return out
end

function TR.GroupText(g)
    if #g.ranks == 0 then return g.name end
    local r = {}
    for i, n in ipairs(g.ranks) do r[i] = tostring(n) end
    return g.name .. " (Rank " .. table.concat(r, ", ") .. ")"
end

-- Deferred: hidden until you reach a higher level (or "Show trainer suggestions again").
function TR:Deferred()
    local d = ns.char.trainerDeferLevel
    return type(d) == "number" and (UnitLevel("player") or 1) <= d
end

function TR:Defer()
    self.skipCache = nil
    ns.char.trainerDeferLevel = UnitLevel("player") or 1
    ns:Fire("TBCG_TRAINER_CHANGED")
    if ns.Engine and ns.Engine.Refresh then ns.Engine:Refresh() end
end

function TR:ViewAgain()
    ns.char.trainerDeferLevel = nil
    ns:Fire("TBCG_TRAINER_CHANGED")
    if ns.Engine and ns.Engine.Refresh then ns.Engine:Refresh() end
    self:Report(true)
end

-- Route: a train step is skipped when, for the chosen setting, the trainer has nothing new.
-- Off keeps the old behaviour (train steps always shown). Unknown (no spell API) never skips.
function TR:SkipReason()
    if self:Mode() == "off" or not TR.CanCheck() then return nil end
    -- One spellbook check per refresh is enough for every train step of the guide.
    local now, key = GetTime and GetTime() or 0, self:Mode() .. (UnitLevel("player") or 1)
    local c = self.skipCache
    if not (c and c.key == key and now - c.at < 1) then
        c = { key = key, at = now, n = #self:Available().ready }
        self.skipCache = c
    end
    if c.n == 0 then
        return self:Mode() == "important" and "nothing important to train yet" or "nothing new to train yet"
    end
    return nil
end

-- Lines for a train step (and the report): the top suggestions, then quest spells.
function TR:Lines(max)
    local lines = {}
    if self:Mode() == "off" then return lines end
    if not TR.CanCheck() then
        lines[1] = "This client cannot tell which spells you know, so no trainer list is shown."
        return lines
    end
    if self:Deferred() then
        lines[1] = "Trainer suggestions hidden until your next level (/tbcg train shows them)."
        return lines
    end
    local a = self:Available()
    local groups = TR.Group(a.ready)
    max = max or 6
    for i, g in ipairs(groups) do
        if i > max then lines[#lines + 1] = "... and " .. (#groups - max) .. " more (/tbcg train)" break end
        lines[#lines + 1] = "- " .. TR.GroupText(g) .. (g.prio ~= 1 and (" |cff999999" .. PRIO_NAME[g.prio] .. "|r") or "")
    end
    for _, e in ipairs(a.quest) do lines[#lines + 1] = "- " .. TR.SpellName(e) .. " |cff999999(" .. e.quest .. ")|r" end
    return lines
end

-- Nearest class trainer of your faction: same zone first, else your capital. zone, x, y, name.
TR.CAPITALS = { Alliance = { 1519, 1537, 1657, 3557 }, Horde = { 1637, 1497, 1638, 3487 } }
function TR:NearestTrainer()
    local info = ns.Compat.PlayerInfo()
    local mapId0 = ns.Compat.GetPlayerMapPosition()
    -- The NPC scan is cached per class, faction and map (same answer until you change zone).
    local key = tostring(info.class) .. tostring(info.faction) .. tostring(mapId0)
    local c = self.nearest
    if c and c.key == key and c.t then return c.t[1], c.t[2], c.t[3], c.t[4] end
    local sub = info.class and (info.class:sub(1, 1) .. info.class:sub(2):lower() .. " Trainer")
    local side = info.faction == "Alliance" and "A" or "H"
    local N = ns.QDB.NPC
    local mapId, px, py = ns.Compat.GetPlayerMapPosition()
    local here = mapId and ns.DB.AreaForUiMap(mapId)
    local best, bestD, cap
    for id, r in pairs(ns.QDB.npcs) do
        local f = r[N.FRIENDLY]
        if r[N.SUBNAME] == sub and f and string.find(f, side, 1, true) then
            if here then
                local z, x, y = ns.DB.GetNPCPosition(id, here)
                if z == here and px then
                    local d = (x - px * 100) ^ 2 + (y - py * 100) ^ 2
                    if not bestD or d < bestD then best, bestD = { z, x, y, r[N.NAME] }, d end
                end
            end
            for rank, area in ipairs(self.CAPITALS[info.faction] or {}) do
                local z, x, y = ns.DB.GetNPCPosition(id, area)
                if z == area and (not cap or rank < cap.rank) then cap = { z, x, y, r[N.NAME], rank = rank } end
            end
        end
    end
    local t = best or cap
    self.nearest = { key = key, t = t }
    if t then return t[1], t[2], t[3], t[4] end
    return nil
end

function TR:Waypoint()
    local z, x, y, name = self:NearestTrainer()
    if z then
        ns.Nav:SetTarget(z, x, y, name)
        return true
    end
    return false
end

-- Chat report (/tbcg train): everything for the setting, plus where the route trains next.
function TR:Report(force)
    if self:Mode() == "off" and not force then return end
    local mode = self:Mode() == "off" and "all" or self:Mode()
    local a = self:Available(mode)
    local groups = TR.Group(a.ready)
    if #groups == 0 and #a.quest == 0 then
        ns:Print("Class trainer: nothing new for you at level " .. a.level .. (mode == "important" and " (important spells; set Class Trainer Suggestions to All for the rest)." or "."))
        return
    end
    local parts = {}
    for _, g in ipairs(groups) do parts[#parts + 1] = TR.GroupText(g) end
    if #parts > 0 then ns:Print("Class trainer has: " .. table.concat(parts, ", ") .. ".") end
    for _, e in ipairs(a.quest) do ns:Print("From a class quest: " .. TR.SpellName(e) .. " - " .. e.quest .. ".") end
    local nxt = self:NextTrainStep()
    if nxt then ns:Print("Your route trains next at step " .. nxt .. ".") end
end

function TR:NextTrainStep()
    local E = ns.Engine
    local g = E and E.guide
    if not g then return nil end
    for i = (E.current or 1), #g.steps do
        if g.steps[i][1] == "train" and E.status[i] ~= "na" then return i end
    end
    return nil
end

-- New level: one short line when important spells became available (never while deferred).
function TR:OnLevelUp(level)
    if self:Mode() == "off" or not TR.CanCheck() then return end
    if ns.char.trainerDeferLevel and level > ns.char.trainerDeferLevel then ns.char.trainerDeferLevel = nil end
    local a = self:Available("important", level)
    local fresh = {}
    for _, e in ipairs(a.ready) do if e.level == level then fresh[#fresh + 1] = e end end
    if #fresh == 0 then return end
    local parts = {}
    for _, g in ipairs(TR.Group(fresh)) do parts[#parts + 1] = TR.GroupText(g) end
    local nxt = self:NextTrainStep()
    ns:Print("New at your class trainer: " .. table.concat(parts, ", ") .. "."
        .. (nxt and (" Your route visits a trainer at step " .. nxt .. ".") or " /tbcg train waypoint marks the nearest trainer."))
end

function TR:Init()
    ns:On("PLAYER_LEVEL_UP", function(_, level)
        -- Spellbook updates after the event: check a moment later.
        C_Timer.After(1, function() TR:OnLevelUp(tonumber(level) or UnitLevel("player")) if ns.Engine then ns.Engine:Refresh() end end)
    end)
    ns:On("LEARNED_SPELL_IN_TAB", function() TR.skipCache = nil ns:Throttle("trainer-refresh", 0.5, function() if ns.Engine then ns.Engine:Refresh() end end) end)
end
