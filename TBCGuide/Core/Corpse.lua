-- TBCGuide - corpse waypoint while you run back as a ghost (setting: corpseNav)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Navigation only: nothing here releases, resurrects, accepts a resurrection or talks to a spirit
-- healer. The arrow (Core/Navigation.lua) gets a temporary owner, "corpse":
--   * Start: only as a ghost (UnitIsGhost) - after you release, or after a reload/login as a ghost.
--     Dead but not released shows nothing.
--   * Where: C_DeathInfo.GetCorpseMapPosition(uiMapID), asked for the map you died on, then the map
--     you are on and its parents up to the continent. The client returns nothing for maps the corpse
--     is not on; 0,0 or no answer is never used. No map is opened or changed to ask.
--   * Delayed data: up to RETRIES tries, RETRY seconds apart, then a one-time "not available" note.
--   * Instances: a corpse inside a dungeon, raid or battleground has no outdoor position. There is
--     no arrow then, only a note; no instance-entrance coordinates are guessed.
--   * While it owns the arrow, guide steps and hunting routes cannot replace it (Nav:Held). A waypoint
--     you ask for yourself (manual) replaces it and counts as dismissing it. "/tbcg corpse off|on".
--   * End: PLAYER_UNGHOST / PLAYER_ALIVE when no longer a ghost, setting off or dismissed. The arrow
--     then goes back to the current step, worked out afresh (Nav:FromStep), never a stored waypoint.

local _, ns = ...

local CP = { active = false, dismissed = false }
ns.Corpse = CP

local RETRIES, RETRY = 10, 2

local function prof() return ns.db.profile end
local function dbg(msg) ns:Debug("corpse: " .. msg) end
local function isGhost() return UnitIsGhost and UnitIsGhost("player") and true or false end
local function inInstance()
    if not IsInInstance then return false end
    local inside, kind = IsInInstance()
    return inside and kind ~= "none"
end

function CP:Active() return self.active end

-- Corpse position: uiMapID, x, y (0-100), or nil.
function CP:Locate()
    local get = C_DeathInfo and C_DeathInfo.GetCorpseMapPosition
    if not get then return nil end
    local maps, seen = {}, {}
    local function add(m) if m and not seen[m] then seen[m] = true maps[#maps + 1] = m end end
    add(self.deathMap)
    local cur = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local guard = 0
    while cur and guard < 6 do
        add(cur)
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(cur)
        cur = info and info.parentMapID ~= 0 and info.parentMapID or nil
        guard = guard + 1
    end
    for _, m in ipairs(maps) do
        local ok, pos = pcall(get, m)
        if ok and pos then
            local x, y = pos:GetXY()
            if x and y and (x > 0 or y > 0) and x <= 1 and y <= 1 then return m, x * 100, y * 100 end
        end
    end
    return nil
end

function CP:Point(map, x, y)
    self.active, self.map, self.x, self.y = true, map, x, y
    ns.Nav:SetMapTarget(map, x, y, "Corpse", "corpse")
    if not self.told then
        self.told = true
        ns:Print("Arrow points to your corpse. /tbcg corpse off returns to the guide.")
    end
end

-- Finds the corpse and takes the arrow; retries a few times when the client has no position yet.
function CP:Try(attempt)
    attempt = attempt or 1
    if not (prof().corpseNav and isGhost()) or self.dismissed then return end
    if self.instanceDeath then
        if not self.toldInstance then
            self.toldInstance = true
            ns:Print("Your corpse is inside an instance; TBCGuide has no outdoor position for it. Run back to the instance entrance.")
        end
        return
    end
    local map, x, y = self:Locate()
    if map then
        if not (self.active and self.map == map and self.x == x and self.y == y) then
            dbg(string.format("corpse at map %d %.1f,%.1f (try %d)", map, x, y, attempt))
            self:Point(map, x, y)
        end
        return
    end
    if attempt < RETRIES then
        local token = self.token
        C_Timer.After(RETRY, function() if CP.token == token then CP:Try(attempt + 1) end end)
    elseif not self.toldMissing then
        self.toldMissing = true
        ns:Print("The game has not given a corpse position yet; the arrow stays on the guide.")
    end
end

-- Hands the arrow back to the current guide step (or route), evaluated now.
function CP:Release(why)
    self.token = {}
    if not self.active then return end
    dbg("release (" .. tostring(why) .. ")")
    self.active = false
    local nav = ns.Nav
    if nav.owner == "corpse" then
        nav.owner = nil
        nav:FromStep(ns.Engine and ns.Engine:CurrentStep())
    end
end

-- Alive again: forget this death completely.
function CP:Reset(why)
    self:Release(why)
    self.dismissed, self.deathMap, self.instanceDeath = false, nil, nil
    self.told, self.toldMissing, self.toldInstance = nil, nil, nil
end

function CP:OnDead()
    self:Reset("died again")
    self.deathMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    self.instanceDeath = inInstance()
    dbg("died on map " .. tostring(self.deathMap) .. (self.instanceDeath and " (instance)" or ""))
end

-- PLAYER_ALIVE fires both on release (now a ghost) and on resurrection before releasing.
function CP:OnAliveOrWorld()
    if isGhost() then
        self.token = {}
        self:Try(1)
    else
        self:Reset("alive")
    end
end

function CP:Dismiss()
    if not isGhost() then ns:Print("You are not a ghost.") return end
    self.dismissed = true
    self:Release("dismissed")
    ns:Print("Corpse arrow off; /tbcg corpse on brings it back.")
end

function CP:Resume()
    if not isGhost() then ns:Print("You are not a ghost.") return end
    self.dismissed, self.toldMissing = false, nil
    self.token = {}
    if self.active then self:Point(self.map, self.x, self.y) else self:Try(1) end
end

-- A waypoint you chose yourself replaced the corpse arrow: treat it as dismissed.
function CP:OnManual()
    if self.active then self.dismissed = true self.active = false self.token = {} end
end

function CP:OnSetting()
    if prof().corpseNav then self:OnAliveOrWorld() else self:Release("setting off") end
end

function CP:Init()
    self.token = {}
    ns:On("PLAYER_DEAD", function() CP:OnDead() end)
    ns:On("PLAYER_ALIVE", function() CP:OnAliveOrWorld() end)
    ns:On("PLAYER_UNGHOST", function() CP:Reset("unghost") end)
    ns:On("PLAYER_ENTERING_WORLD", function() CP:OnAliveOrWorld() end)
    ns:On("ZONE_CHANGED_NEW_AREA", function() if isGhost() and not CP.dismissed then CP.token = {} CP:Try(1) end end)
end
