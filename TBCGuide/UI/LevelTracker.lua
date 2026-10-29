-- TBCGuide - leveling tracker: played time per level, a leveling report and a level splits window
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Played time comes from the server (TIME_PLAYED_MSG: total, and time at the current level), asked
-- for quietly at login; after that it is counted locally. Each level-up saves how long that level
-- took (TBCGuideCharDB.levelLog[level] = seconds played at that level). Levels finished before the
-- tracker existed are unknown and shown as such.

local _, ns = ...

local LT = { sessionXp = 0 }
ns.LevelTracker = LT

local function prof() return ns.db.profile end
local function now() return GetTime and GetTime() or 0 end

function LT:Log()
    if type(ns.char.levelLog) ~= "table" then ns.char.levelLog = {} end
    return ns.char.levelLog
end

function LT.Format(sec)
    if not sec then return "-" end
    sec = math.floor(math.max(0, sec) + 0.5)
    local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

-- Total played seconds now, or nil until the server has answered.
function LT:Played()
    if not self.base then return nil end
    return self.base + (now() - self.baseAt)
end

-- Seconds at the current level so far.
function LT:CurrentLevelTime()
    local p = self:Played()
    local start = ns.char.levelStart
    if not p or type(start) ~= "number" then return nil end
    return p - start
end

-- Played-time request without the chat lines it normally prints.
function LT:Request()
    if not RequestTimePlayed then return end
    self.quiet = true
    if not self.hooked and ChatFrame_DisplayTimePlayed then
        self.hooked = true
        local orig = ChatFrame_DisplayTimePlayed
        ChatFrame_DisplayTimePlayed = function(...)
            if LT.quiet then LT.quiet = false return end
            return orig(...)
        end
    end
    RequestTimePlayed()
end

function LT:OnTimePlayed(total, thisLevel)
    if type(total) ~= "number" then return end
    self.base, self.baseAt = total, now()
    if type(thisLevel) == "number" then ns.char.levelStart = total - thisLevel end
    ns.char.levelStartLevel = UnitLevel and UnitLevel("player") or nil
    self:Refresh()
end

function LT:OnLevelUp(newLevel)
    local p = self:Played()
    local start = ns.char.levelStart
    if p and type(start) == "number" and type(newLevel) == "number" then
        self:Log()[newLevel - 1] = math.floor(p - start + 0.5)
    end
    ns.char.levelStart = p
    ns.char.levelStartLevel = newLevel
    self.lastXp = 0
    self:Refresh()
end

function LT:OnXp()
    local xp = UnitXP and UnitXP("player") or 0
    if self.lastXp and xp > self.lastXp then self.sessionXp = self.sessionXp + (xp - self.lastXp) end
    self.lastXp = xp
end

function LT:XpPerHour()
    local t = now() - (self.sessionStart or now())
    if t < 60 or self.sessionXp <= 0 then return nil end
    return self.sessionXp / t * 3600
end

-- Report lines (also used by /tbcg tracker).
function LT:ReportLines()
    local lines = {}
    local level = UnitLevel and UnitLevel("player") or 1
    lines[#lines + 1] = "Level " .. level .. " for " .. LT.Format(self:CurrentLevelTime())
    local xph = self:XpPerHour()
    if xph then
        lines[#lines + 1] = string.format("XP per hour (this session): %d", math.floor(xph))
        local left = (UnitXPMax and UnitXPMax("player") or 0) - (UnitXP and UnitXP("player") or 0)
        if left > 0 then lines[#lines + 1] = "Next level in about " .. LT.Format(left / xph * 3600) end
    else
        lines[#lines + 1] = "XP per hour: not enough data yet this session"
    end
    lines[#lines + 1] = "Total played: " .. LT.Format(self:Played())
    local log = self:Log()
    local known, sum = 0, 0
    for _, v in pairs(log) do known = known + 1 sum = sum + v end
    if known > 0 then lines[#lines + 1] = string.format("Tracked levels: %d, average %s per level", known, LT.Format(sum / known)) end
    return lines
end

-- Splits: last N finished levels, the running level, optional total.
function LT:SplitLines()
    local p = prof()
    local log, lines = self:Log(), {}
    local level = UnitLevel and UnitLevel("player") or 1
    local first = math.max(1, level - (p.splitsHistory or 10))
    for l = first, level - 1 do
        local d = log[l]
        lines[#lines + 1] = string.format("%2d   %s", l, d and LT.Format(d) or "-")
    end
    local cur = self:CurrentLevelTime()
    local s = string.format("%2d   %s", level, LT.Format(cur))
    if p.splitsCompare and cur and log[level - 1] then
        local diff = cur - log[level - 1]
        s = s .. string.format("  (%s%s vs %d)", diff >= 0 and "+" or "-", LT.Format(math.abs(diff)), level - 1)
    end
    lines[#lines + 1] = s
    if p.splitsTotal then lines[#lines + 1] = "Total  " .. LT.Format(self:Played()) end
    return lines
end

-- Windows ---------------------------------------------------------------------------------------------

local function window(name, key, w, default)
    local W = ns.Widgets
    local f = W.Panel(name, UIParent, w, 60)
    W.Movable(f, key)
    if not (ns.db.frames[key] and ns.db.frames[key].point) then f:ClearAllPoints() f:SetPoint(unpack(default)) end
    local t = W.Text(f, "GameFontHighlightSmall", "LEFT")
    t:SetPoint("TOPLEFT", 8, -8)
    t:SetWidth(w - 16)
    f.text = t
    f:Hide()
    return f
end

function LT:ReportFrame()
    if self.report then return self.report end
    self.report = window("TBCGuideLevelReport", "levelReport", 260, { "TOPLEFT", UIParent, "TOPLEFT", 360, -120 })
    local W = ns.Widgets
    W.TitleBar(self.report, "Leveling report")
    self.report.text:ClearAllPoints()
    self.report.text:SetPoint("TOPLEFT", 10, -W.TITLE_H - 10)
    W.CloseButton(self.report, function() LT.report:Hide() end)
    return self.report
end

function LT:SplitsFrame()
    if self.splits then return self.splits end
    self.splits = window("TBCGuideLevelSplits", "levelSplits", 180, { "RIGHT", UIParent, "RIGHT", -40, -120 })
    return self.splits
end

local function fill(f, lines, font, top)
    f.text:SetText(table.concat(lines, "\n"))
    if font and f.text.GetFont and f.text.SetFont then
        local path, _, flags = f.text:GetFont()
        if path then f.text:SetFont(path, font, flags) end
    end
    local n = #lines
    f:SetHeight((top or 8) + 8 + n * ((font or 11) + 3))
end

function LT:Refresh()
    if not ns.db then return end
    local p = prof()
    local on = p.trackerEnabled
    if self.report and self.report:IsShown() then fill(self.report, self:ReportLines(), nil, ns.Widgets.TITLE_H + 10) end
    local s = (on and p.splitsEnabled) and self:SplitsFrame() or self.splits
    if s then
        if on and p.splitsEnabled then
            fill(s, self:SplitLines(), p.splitsFont or 11)
            if s.SetBackdropColor then s:SetBackdropColor(0.05, 0.05, 0.08, p.splitsHideBg and 0 or (p.splitsAlpha or 0.9)) end
            if s.SetBackdropBorderColor then s:SetBackdropBorderColor(0.4, 0.4, 0.45, p.splitsHideBg and 0 or 1) end
            s:Show()
        else
            s:Hide()
        end
    end
end

function LT:ToggleReport()
    if not prof().trackerEnabled then return ns:Print("The leveling tracker is off (Leveling Tracker tab).") end
    local f = self:ReportFrame()
    if f:IsShown() then f:Hide() else f:Show() self:Refresh() end
end

function LT:Init()
    self.sessionStart = now()
    self.lastXp = UnitXP and UnitXP("player") or 0
    ns:On("TIME_PLAYED_MSG", function(_, total, thisLevel) LT:OnTimePlayed(total, thisLevel) end)
    ns:On("PLAYER_LEVEL_UP", function(_, lvl) LT:OnLevelUp(lvl) end)
    ns:On("PLAYER_XP_UPDATE", function() LT:OnXp() end)
    if CharacterFrame and CharacterFrame.HookScript then
        CharacterFrame:HookScript("OnShow", function()
            if prof().trackerEnabled and prof().trackerWithCharacter then LT:ReportFrame():Show() LT:Refresh() end
        end)
        CharacterFrame:HookScript("OnHide", function()
            if prof().trackerWithCharacter and LT.report then LT.report:Hide() end
        end)
    end
    -- Running clock on the splits window and the open report.
    local ticker = CreateFrame("Frame")
    ticker.acc = 0
    ticker:SetScript("OnUpdate", function(s, el)
        s.acc = s.acc + el
        if s.acc >= 1 then s.acc = 0 LT:Refresh() end
    end)
    ticker:Show()
    C_Timer.After(3, function() if prof().trackerEnabled then LT:Request() end end)
end
