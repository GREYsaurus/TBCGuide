-- TBCGuide - guide recommendation for the current character
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

local Selector = {}
ns.Selector = Selector

-- The full route (ordered list of guides) a character would follow from their racial start.
function Selector:RouteFor(info)
    local start
    for _, g in ipairs(ns.Guides.list) do
        if g.start and ns.Guides:AppliesTo(g, info) and g.races and ns.Contains(g.races, info.race) then
            start = g
            break
        end
    end
    local route, seen = {}, {}
    local g = start
    while g and not seen[g.id] do
        seen[g.id] = true
        route[#route + 1] = g
        g = ns.Guides:NextFor(g, info)
    end
    return route
end

local function zoneMatches(g, zoneName)
    return zoneName and g.zoneName and string.lower(zoneName) == string.lower(g.zoneName)
end

-- Returns the recommended guide and a short reason.
function Selector:Recommend(info)
    info = info or ns.Compat.PlayerInfo()
    local level = info.level or 1
    local zoneName = ns.Compat.GetZoneText()
    local route = self:RouteFor(info)

    -- 1) On-route guide in the current zone that fits the level.
    for _, g in ipairs(route) do
        if zoneMatches(g, zoneName) and level >= g.minLevel - 1 and level <= g.maxLevel then
            return g, "on your route and in your current zone"
        end
    end
    -- 2) First on-route guide the character has not out-levelled.
    for _, g in ipairs(route) do
        if level <= g.maxLevel and level >= g.minLevel - 2 then
            return g, "next on your race's route for level " .. level
        end
    end
    -- 3) Any applicable guide for the level (e.g. boosted characters, unusual routes).
    local best, bestScore
    for _, g in ipairs(ns.Guides.list) do
        if ns.Guides:AppliesTo(g, info) and level >= g.minLevel - 1 and level <= g.maxLevel then
            local score = (zoneMatches(g, zoneName) and 10 or 0) - math.abs(level - g.minLevel)
            if not bestScore or score > bestScore then best, bestScore = g, score end
        end
    end
    if best then return best, "best level match" end
    return route[1], "start of your route"
end

-- Called when a guide finishes: returns the next guide for this character, if any.
function Selector:NextAfter(g, info)
    info = info or ns.Compat.PlayerInfo()
    local nextG = ns.Guides:NextFor(g, info)
    -- Skip guides the character has already out-levelled.
    local guard = 0
    while nextG and info.level > nextG.maxLevel and guard < 10 do
        local after = ns.Guides:NextFor(nextG, info)
        if not after then break end
        nextG = after
        guard = guard + 1
    end
    return nextG
end
