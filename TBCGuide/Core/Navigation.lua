-- TBCGuide - waypoints: built-in arrow, world map pin, optional TomTom integration
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Coordinates in guides/database are zone-map percentages keyed by AreaTable id. They are
-- converted to uiMapIDs (Zones.lua) and then to world coordinates with C_Map so distance and
-- direction can be computed. If any of those APIs are missing the arrow hides itself and the
-- step text still shows plain coordinates - navigation is an aid, never a requirement.

local _, ns = ...

local Nav = { target = nil }
ns.Nav = Nav

local C = ns.Compat
local ARRIVE_YARDS = 12

-- Target -----------------------------------------------------------------------------------------

function Nav:SetTarget(areaId, x, y, label)
    local mapId = ns.DB.ZoneUiMap(areaId)
    if not mapId then
        self:Clear()
        return
    end
    local t = self.target
    if t and t.mapId == mapId and t.x == x and t.y == y then return end
    self.target = { area = areaId, mapId = mapId, x = x, y = y, label = label or "" }
    self:UpdateTomTom()
    self:UpdateMapPin()
    if self.arrow then self.arrow:SetShown(ns.db.profile.showArrow and ns.Assist:FramesAllowed()) end
end

function Nav:Clear()
    self.target = nil
    self:UpdateTomTom()
    self:UpdateMapPin()
    if self.arrow then self.arrow:Hide() end
end

function Nav:FromStep(step)
    if not step then return self:Clear() end
    local z, x, y, label = ns.StepText:Target(step)
    if z and x and y then self:SetTarget(z, x, y, label) else self:Clear() end
end

-- Distance (yards) and relative angle (radians, 0 = straight ahead, + = to the left).
function Nav:Vector()
    local t = self.target
    if not t then return nil end
    local pMap, px, py = C.GetPlayerMapPosition()
    if not px then return nil end
    local c1, x1, y1 = C.MapToWorld(pMap, px, py)
    local c2, x2, y2 = C.MapToWorld(t.mapId, t.x, t.y)
    if not c1 or not c2 or c1 ~= c2 then return nil, "different continent" end
    local dx, dy = x2 - x1, y2 - y1 -- world X = north, world Y = west
    local dist = math.sqrt(dx * dx + dy * dy)
    local facing = C.GetPlayerFacing()
    if not facing then return dist end
    local angle = math.atan2(dy, dx) - facing
    return dist, angle
end

-- TomTom (optional) ----------------------------------------------------------------------------

function Nav:UpdateTomTom()
    if self.tomtomUid and TomTom and TomTom.RemoveWaypoint then
        pcall(TomTom.RemoveWaypoint, TomTom, self.tomtomUid)
        self.tomtomUid = nil
    end
    local t = self.target
    if not t or not ns.db.profile.useTomTom or not ns.Target.integrations.TomTom then return end
    if not (TomTom and TomTom.AddWaypoint) then return end
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, t.mapId, t.x / 100, t.y / 100,
        { title = "TBCGuide: " .. (t.label or ""), persistent = false, minimap = true, world = true })
    if ok then self.tomtomUid = uid end
end

-- World map pin --------------------------------------------------------------------------------

function Nav:UpdateMapPin()
    local pin = self.pin
    if not pin then return end
    local t = self.target
    if not t or not ns.db.profile.showMapPins or not WorldMapFrame or not WorldMapFrame:IsShown() then
        pin:Hide()
        return
    end
    local shownMap = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
    if not canvas or shownMap ~= t.mapId then pin:Hide() return end
    if pin:GetParent() ~= canvas then pin:SetParent(canvas) end
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", w * t.x / 100, -h * t.y / 100)
    local scale = 1 / (canvas:GetEffectiveScale() / UIParent:GetEffectiveScale())
    pin:SetScale(math.max(scale, 0.6))
    pin:SetFrameStrata("HIGH")
    pin:Show()
end

local function createPin()
    local pin = CreateFrame("Frame", "TBCGuideMapPin", UIParent)
    pin:SetSize(20, 20)
    local tex = pin:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon") -- stock client texture
    pin.tex = tex
    pin:EnableMouse(true)
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("TBCGuide")
        GameTooltip:AddLine(Nav.target and Nav.target.label or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:Hide()
    return pin
end

-- Arrow ---------------------------------------------------------------------------------------

local function createArrow()
    local f = CreateFrame("Button", "TBCGuideArrow", UIParent)
    f:SetSize(56, 70)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function(self) if not ns.db.profile.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        ns.db.frames.arrow = { point = point, x = x, y = y }
    end)
    local pos = ns.db.frames.arrow
    f:SetPoint(pos.point or "TOP", UIParent, pos.point or "TOP", pos.x or 0, pos.y or -120)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetSize(42, 42)
    tex:SetPoint("TOP")
    -- Stock client texture (no custom art shipped). Rotated with SetRotation.
    tex:SetTexture("Interface\\Minimap\\MinimapArrow")
    f.tex = tex

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", tex, "BOTTOM", 0, -2)
    f.label = label

    f:SetScript("OnClick", function(_, button)
        if button == "RightButton" then ns.db.profile.showArrow = false; f:Hide() end
    end)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local acc = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        acc = acc + elapsed
        local ms = ns.db.profile.arrowUpdateMs or 50
        if ns.db.profile.lowQuality then ms = math.max(ms, 150) end -- Low Quality Settings
        if acc < ms / 1000 then return end
        acc = 0
        local dist, angle = Nav:Vector()
        if not dist then
            self.tex:SetVertexColor(0.6, 0.6, 0.6)
            self.tex:SetRotation(0)
            local t = Nav.target
            self.label:SetText(t and string.format("%.1f, %.1f", t.x, t.y) or "")
            return
        end
        if dist < ARRIVE_YARDS then
            self.tex:SetVertexColor(0.3, 1, 0.3)
            self.label:SetText("Arrived")
            local s = ns.Engine:CurrentStep()
            if s and s[1] == "goto" then ns.Engine:MarkDone() end
            return
        end
        if angle then
            self.tex:SetRotation(angle)
            local a = math.abs(((angle + math.pi) % (2 * math.pi)) - math.pi)
            local g = 1 - math.min(a / math.pi, 1)
            self.tex:SetVertexColor(1 - g * 0.7, 0.4 + g * 0.6, 0.2)
        end
        self.label:SetText(string.format("%d yd", math.floor(dist + 0.5)))
    end)
    f:Hide()
    return f
end

function Nav:Init()
    self.arrow = createArrow()
    self.pin = createPin()
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() Nav:UpdateMapPin() end)
        if WorldMapFrame.OnMapChanged then
            hooksecurefunc(WorldMapFrame, "OnMapChanged", function() Nav:UpdateMapPin() end)
        end
        WorldMapFrame:HookScript("OnHide", function() if Nav.pin then Nav.pin:Hide() end end)
    end
    ns:Listen("TBCG_STEP_CHANGED", function() Nav:FromStep(ns.Engine:CurrentStep()) end)
    ns:Listen("TBCG_GUIDE_CHANGED", function() Nav:FromStep(ns.Engine:CurrentStep()) end)
    -- Complete steps track the nearest objective, so retarget as the player moves.
    local t = 0
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed
        if t < 3 then return end
        t = 0
        local s = ns.Engine:CurrentStep()
        if s and s[1] == "complete" and not s.x then Nav:FromStep(s) end
    end)
end
