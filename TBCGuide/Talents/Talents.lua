-- TBCGuide - talent engine: build expansion, validation, live talent reading
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Talent trees come from Talents/Data/TalentTrees.lua (generated from client DB2 tables).
-- Builds (Talents/Builds/*.lua) list talent picks in order, one entry per point, using talent
-- NAMES, e.g. {"Improved Heroic Strike", 3} = three points. The engine expands a build into an
-- ordered list of {talentId, rank}, checks every pick against tier gating, prerequisites and max
-- ranks, and can compare it with the character's live talents (player class only).

local _, ns = ...

local Talents = { builds = {}, buildList = {} }
ns.Talents = Talents

local POINTS_PER_TIER = 5

-- Index helpers ---------------------------------------------------------------------------------

local index -- [class] = { byName = {[name]=talent}, byId = {[id]=talent}, tabs = {...} }

local function buildIndex()
    index = {}
    for class, tabs in pairs(ns.TalentTrees or {}) do
        if type(tabs) == "table" and tabs[1] then
            local ci = { byName = {}, byId = {}, tabs = tabs }
            for tabNo, tab in ipairs(tabs) do
                for _, t in ipairs(tab.talents) do
                    t.tab = tabNo
                    ci.byId[t.id] = t
                    -- Names are unique within a class in TBC except a handful shared across trees;
                    -- builds may disambiguate with "Tree:Name".
                    local key = string.lower(t.name)
                    if ci.byName[key] then ci.byName[key] = false else ci.byName[key] = t end
                    ci.byName[string.lower(tab.name .. ":" .. t.name)] = t
                end
            end
            index[class] = ci
        end
    end
end

function Talents:Index(class)
    if not index then buildIndex() end
    return index[class]
end

function Talents:Find(class, name)
    local ci = self:Index(class)
    if not ci then return nil end
    local t = ci.byName[string.lower(name)]
    if t == false then return nil, "ambiguous talent name '" .. name .. "' (use Tree:Name)" end
    if not t then return nil, "unknown talent '" .. name .. "'" end
    return t
end

-- Registration ----------------------------------------------------------------------------------

-- build = { id=, name=, class=, role=, kind="leveling"|"endgame"|"dungeon"|"pvp", levelRange=,
--           summary=, notes={...}, picks={ {"Talent", ranks, note?}, ... }, alternatives={...} }
function ns.RegisterTalentBuilds(class, builds)
    for _, b in ipairs(builds) do
        b.class = class
        Talents.builds[b.id] = b
        Talents.buildList[#Talents.buildList + 1] = b
    end
end

function Talents:BuildsFor(class)
    local out = {}
    for _, b in ipairs(self.buildList) do if b.class == class then out[#out + 1] = b end end
    return out
end

-- Expansion + validation ------------------------------------------------------------------------

-- Returns sequence { {talent=, rank=, level=, note=} ... }, errors{}
function Talents:Expand(build)
    local errors, seq = {}, {}
    local ci = self:Index(build.class)
    if not ci then return seq, { "no talent data for class " .. tostring(build.class) } end
    local ranks, perTab = {}, { 0, 0, 0 }
    for _, pick in ipairs(build.picks or {}) do
        local name, count, note = pick[1], pick[2] or 1, pick[3]
        local t, err = self:Find(build.class, name)
        if not t then
            errors[#errors + 1] = err
        else
            for _ = 1, count do
                local cur = ranks[t.id] or 0
                local n = #seq + 1
                local level = ns.Target.firstTalentLevel + n - 1
                if cur >= t.ranks then
                    errors[#errors + 1] = string.format("point %d: %s already at max rank %d", n, t.name, t.ranks)
                elseif perTab[t.tab] < (t.tier - 1) * POINTS_PER_TIER then
                    errors[#errors + 1] = string.format("point %d: %s needs %d points in tree (has %d)", n, t.name, (t.tier - 1) * POINTS_PER_TIER, perTab[t.tab])
                elseif t.prereq and (ranks[t.prereq[1]] or 0) < t.prereq[2] then
                    local pre = ci.byId[t.prereq[1]]
                    errors[#errors + 1] = string.format("point %d: %s requires %s %d/%d", n, t.name, pre and pre.name or "?", t.prereq[2], pre and pre.ranks or 0)
                end
                ranks[t.id] = cur + 1
                perTab[t.tab] = perTab[t.tab] + 1
                seq[n] = { talent = t, rank = cur + 1, level = level, note = (cur == 0) and note or nil }
            end
        end
    end
    local maxPoints = ns.Target.talentPointsAt(ns.Target.maxLevel)
    if #seq > maxPoints then errors[#errors + 1] = string.format("%d points exceeds the %d available at level %d", #seq, maxPoints, ns.Target.maxLevel) end
    return seq, errors, perTab
end

-- Ranks a build has after `points` points.
function Talents:RanksAt(build, points)
    local seq = self:Expand(build)
    local r = {}
    for i = 1, math.min(points, #seq) do r[seq[i].talent.id] = seq[i].rank end
    return r, seq
end

-- Live talents (player class only) --------------------------------------------------------------

-- Maps the client's (tab, index) talents onto our data by tier/column (language independent).
-- Returns { [talentId] = rank }, mismatches{}
function Talents:ReadLive()
    local class = ns.Compat.PlayerInfo().class
    local ci = self:Index(class)
    local live, mismatches = {}, {}
    if not ci then return live, { "no data for " .. tostring(class) } end
    local numTabs = ns.Compat.GetNumTalentTabs()
    if numTabs == 0 then return live, { "talent API unavailable" } end
    for tab = 1, numTabs do
        local tabData = ci.tabs[tab]
        local pos = {}
        if tabData then
            for _, t in ipairs(tabData.talents) do pos[t.tier .. ":" .. t.column] = t end
        end
        for i = 1, ns.Compat.GetNumTalents(tab) do
            local info = ns.Compat.GetTalent(tab, i)
            if info then
                local t = pos[info.tier .. ":" .. info.column]
                if not t then
                    mismatches[#mismatches + 1] = string.format("client talent %s (tab %d tier %d col %d) not in data", info.name, tab, info.tier, info.column)
                else
                    if t.ranks ~= info.maxRank then
                        mismatches[#mismatches + 1] = string.format("%s: data has %d ranks, client %d", t.name, t.ranks, info.maxRank)
                    end
                    t.liveIndex = i
                    if info.rank > 0 then live[t.id] = info.rank end
                end
            end
        end
    end
    return live, mismatches
end

-- Next recommended pick for the character: first point in the build the character lacks.
function Talents:NextPick(build, live)
    local seq = self:Expand(build)
    local have = {}
    for id, r in pairs(live) do have[id] = r end
    local deviations = 0
    for i, p in ipairs(seq) do
        local id = p.talent.id
        if (have[id] or 0) >= p.rank then
            -- already have this point
        else
            return p, i, deviations
        end
    end
    for id, r in pairs(live) do
        local inBuild = 0
        for _, p in ipairs(seq) do if p.talent.id == id then inBuild = math.max(inBuild, p.rank) end end
        if r > inBuild then deviations = deviations + (r - inBuild) end
    end
    return nil, #seq + 1, deviations
end

-- Chosen build for this character: saved choice, else first leveling build for the class.
function Talents:ActiveBuild()
    local class = ns.Compat.PlayerInfo().class
    local b = ns.char.talentBuild and self.builds[ns.char.talentBuild]
    if b and b.class == class then return b end
    for _, cand in ipairs(self:BuildsFor(class)) do
        if cand.kind == "leveling" then return cand end
    end
    return self:BuildsFor(class)[1]
end

function Talents:Init()
    ns:On("CHARACTER_POINTS_CHANGED", function() ns:Fire("TBCG_TALENTS_CHANGED") end)
    ns:On("PLAYER_LEVEL_UP", function(_, newLevel)
        if not ns.db.profile.talentHints then return end
        C_Timer.After(1, function()
            local unspent = ns.Compat.GetUnspentTalentPoints()
            local b = Talents:ActiveBuild()
            if unspent > 0 and b then
                local live = Talents:ReadLive()
                local p = Talents:NextPick(b, live)
                if p then
                    ns:Print(string.format("You have %d unspent talent point(s). Next for %s: |cffffd100%s|r rank %d.",
                        unspent, b.name, p.talent.name, p.rank))
                end
            end
        end)
    end)
end
