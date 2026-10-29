-- TBCGuide - flight timers
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- No flight-time data ships with TBCGuide. Each flight you take is timed and saved (account-wide,
-- per origin -> destination), so the next time the bar counts down; the first time it counts up.

local _, ns = ...

local F = {}
ns.FlightTimer = F

local function prof() return ns.db.profile end
local function now() return GetTime and GetTime() or 0 end
local function onTaxi() return UnitOnTaxi and UnitOnTaxi("player") or false end

function F:Times()
    if type(ns.db.flightTimes) ~= "table" then ns.db.flightTimes = {} end
    return ns.db.flightTimes
end
function F.Key(from, to) return tostring(from) .. " -> " .. tostring(to) end

function F.Format(sec)
    sec = math.max(0, math.floor(sec + 0.5))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- Taxi map: remember where we are; TakeTaxiNode (hooked) tells where we go.
function F:OnTaxiMap()
    self.origin = nil
    if not (NumTaxiNodes and TaxiNodeName and TaxiNodeGetType) then return end
    for i = 1, NumTaxiNodes() or 0 do
        if TaxiNodeGetType(i) == "CURRENT" then self.origin = TaxiNodeName(i) end
    end
end

function F:OnTakeNode(i)
    if not self.origin then self:OnTaxiMap() end -- flight automation may take the node first
    if not (TaxiNodeName and self.origin) then return end
    self.pending = { from = self.origin, to = TaxiNodeName(i), at = now() }
end

-- Called when control is lost/gained: start and finish timing.
function F:Check()
    if onTaxi() then
        if not self.flight and self.pending then
            self.flight = self.pending
            self.flight.start = now()
            self.pending = nil
            local known = self:Times()[F.Key(self.flight.from, self.flight.to)]
            self.flight.known = known
            if ns.Group then
                ns.Group:Announce("Flying to " .. tostring(self.flight.to) .. (known and (", arriving in about " .. F.Format(known)) or "") .. ".", "announceFlight")
            end
            self:Show()
        end
    elseif self.flight then
        local dur = now() - self.flight.start
        -- Ignore implausible values (logouts, disconnects, dismounts).
        if dur > 5 and dur < 3600 then self:Times()[F.Key(self.flight.from, self.flight.to)] = math.floor(dur + 0.5) end
        self.flight = nil
        if self.bar then self.bar:Hide() end
    end
end

function F:Bar()
    if self.bar then return self.bar end
    local W = ns.Widgets
    local b = W.Panel("TBCGuideFlightTimer", UIParent, 220, 26)
    W.Movable(b, "flightTimer")
    if not (ns.db.frames.flightTimer and ns.db.frames.flightTimer.point) then b:ClearAllPoints() b:SetPoint("TOP", UIParent, "TOP", 0, -180) end
    local t = W.Text(b, "GameFontHighlightSmall", "CENTER")
    t:SetPoint("CENTER")
    b.text = t
    b:Hide()
    self.bar = b
    return b
end

function F:Show()
    if not prof().flightTimers or not self.flight then return end
    local b = self:Bar()
    b:Show()
    b.acc = 0
    b:SetScript("OnUpdate", function(s, el)
        s.acc = s.acc + el
        if s.acc < 0.25 then return end
        s.acc = 0
        local f = F.flight
        if not f then s:Hide() s:SetScript("OnUpdate", nil) return end
        local elapsed = now() - f.start
        if f.known then
            s.text:SetText(tostring(f.to) .. "  " .. F.Format(f.known - elapsed))
        else
            s.text:SetText(tostring(f.to) .. "  " .. F.Format(elapsed) .. " (first flight, timing it)")
        end
    end)
end

function F:Init()
    if hooksecurefunc and TakeTaxiNode then hooksecurefunc("TakeTaxiNode", function(i) F:OnTakeNode(i) end) end
    ns:On("TAXIMAP_OPENED", function() F:OnTaxiMap() end)
    ns:On("PLAYER_CONTROL_LOST", function() C_Timer.After(0.5, function() F:Check() end) end)
    ns:On("PLAYER_CONTROL_GAINED", function() F:Check() end)
end
