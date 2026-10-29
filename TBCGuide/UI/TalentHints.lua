-- TBCGuide - talent suggestions inside the Blizzard talent window
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Setting "Show Talent Suggestions". In the default talent window (Blizzard_TalentUI, loaded on
-- demand) this adds, for the build of your spec profile (Talents/ProfileBuilds.lua):
--   - numbered markers on the next picks (1 = next point) on the tab you are looking at,
--   - a small panel: the build, the next picks, deviations, and the source,
--   - a tooltip line on every talent the build uses.
-- Talents are matched by tier and column, never by name, so any client language works.
-- Nothing here spends a talent point: there is no call to LearnTalent anywhere in TBCGuide.
-- Everything is post-hooked (hooksecurefunc) or added on top; Blizzard's frames are not replaced.

local _, ns = ...

local TH = { markers = {} }
ns.TalentHints = TH

local MAX_MARKS = 3
local function prof() return ns.db.profile end

function TH:Enabled() return prof().showTalentSuggestions ~= false end

-- The build to follow: the spec profile's plan; without a spec profile, the build chosen in the
-- TBCGuide talent window (or the class's leveling build).
function TH:Build()
    local info = ns.Compat.PlayerInfo()
    local p = ns.char.gearProfile and ns.Gear:ProfileById(ns.char.gearProfile)
    if p and p.class == info.class then
        local b, why = ns.Talents:BuildForProfile(p)
        return b, why, p
    end
    return ns.Talents:ActiveBuild(), nil, nil
end

-- Points per tree from live ranks, and whether `t` can take its next rank now.
local function treePoints(live, ci)
    local per = { 0, 0, 0 }
    for id, r in pairs(live) do
        local t = ci.byId[id]
        if t then per[t.tab] = per[t.tab] + r end
    end
    return per
end

function TH:Blocked(t, live, ci)
    local per = treePoints(live, ci)
    if per[t.tab] < (t.tier - 1) * 5 then return string.format("needs %d points in its tree first", (t.tier - 1) * 5) end
    if t.prereq and (live[t.prereq[1]] or 0) < t.prereq[2] then
        local pre = ci.byId[t.prereq[1]]
        return "needs " .. (pre and pre.name or "its prerequisite") .. " first"
    end
    return nil
end

-- The suggestion state: { build, next = {picks}, deviations, blocked, unspent, why, profile }.
function TH:State()
    local b, why, p = self:Build()
    local st = { build = b, why = why, profile = p, next = {}, deviations = 0 }
    if not b then return st end
    local live, mismatches = ns.Talents:ReadLive()
    st.mismatches = mismatches
    local ci = ns.Talents:Index(b.class)
    local seq = ns.Talents:Expand(b)
    local _, idx = ns.Talents:NextPick(b, live)
    -- Deviations: points above what the plan ever puts into that talent.
    local want = {}
    for _, s in ipairs(seq) do want[s.talent.id] = math.max(want[s.talent.id] or 0, s.rank) end
    for id, r in pairs(live) do
        if r > (want[id] or 0) then st.deviations = st.deviations + r - (want[id] or 0) end
    end
    st.unspent = ns.Compat.GetUnspentTalentPoints()
    -- Next picks: the plan's missing points in order (a later rank of the same talent counts once).
    local seen = {}
    for i = idx, #seq do
        local s = seq[i]
        if (live[s.talent.id] or 0) < s.rank and not seen[s.talent.id] then
            seen[s.talent.id] = true
            st.next[#st.next + 1] = { talent = s.talent, rank = s.rank, level = s.level, index = i }
            if #st.next >= MAX_MARKS then break end
        end
    end
    if st.next[1] and ci then st.blocked = self:Blocked(st.next[1].talent, live, ci) end
    st.live, st.ci = live, ci
    return st
end

-- Blizzard talent window --------------------------------------------------------------------------
local function selectedTab()
    local f = _G.PlayerTalentFrame
    if not f then return nil end
    if PanelTemplates_GetSelectedTab then
        local t = PanelTemplates_GetSelectedTab(f)
        if t then return t end
    end
    return f.selectedTab or f.currentSelectedTab
end

local function talentButton(i) return _G["PlayerTalentFrameTalent" .. i] end

local function marker(b)
    local m = TH.markers[b]
    if not m and b.CreateFontString then
        m = { text = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge"), glow = b:CreateTexture(nil, "OVERLAY") }
        m.text:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4)
        m.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        m.glow:SetBlendMode("ADD")
        m.glow:SetSize(64, 64)
        m.glow:SetPoint("CENTER", b, "CENTER", 0, 0)
        TH.markers[b] = m
    end
    return m
end

function TH:HideMarkers()
    for _, m in pairs(self.markers) do m.text:Hide() m.glow:Hide() end
end

function TH:Panel()
    if self.panel or not _G.PlayerTalentFrame then return self.panel end
    local f = CreateFrame("Frame", "TBCGuideTalentHints", _G.PlayerTalentFrame, ns.Compat.BackdropTemplate)
    f:SetSize(220, 150)
    f:SetPoint("TOPLEFT", _G.PlayerTalentFrame, "TOPRIGHT", -30, -12)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
    end
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT", 10, -10)
    f.text:SetWidth(200)
    f.text:SetJustifyH("LEFT")
    self.panel = f
    return f
end

-- Text of the panel (also used by the tests).
function TH:PanelText(st)
    st = st or self:State()
    local L = {}
    if not st.build then
        L[1] = "|cffffd100TBCGuide talents|r"
        if st.why == "no plan" and st.profile then
            L[2] = "No talent plan for " .. ns.Upgrade:ProfileName(st.profile) .. " yet. Pick another spec profile, or spend points your own way."
        else
            L[2] = "Choose a spec profile (Settings, Tips) for talent suggestions."
        end
        return table.concat(L, "\n")
    end
    L[#L + 1] = "|cffffd100" .. st.build.name .. "|r"
    if #st.next == 0 then
        L[#L + 1] = "Plan complete."
    else
        for i, p in ipairs(st.next) do
            local tree = st.ci and st.ci.tabs[p.talent.tab] and st.ci.tabs[p.talent.tab].name or ""
            L[#L + 1] = string.format("%d. %s %d/%d |cff999999(%s, level %d)|r", i, p.talent.name, p.rank, p.talent.ranks, tree, p.level)
        end
        if st.blocked then L[#L + 1] = "|cffff7777Next pick " .. st.blocked .. ".|r" end
    end
    if st.deviations > 0 then
        L[#L + 1] = string.format("|cffffaa55Your talents differ from this plan by %d point(s). Suggestions continue with the plan's next missing pick; matching the plan exactly would need a respec (TBCGuide never resets talents).|r", st.deviations)
    end
    if st.unspent and st.unspent > 0 then L[#L + 1] = st.unspent .. " point(s) to spend - click the talent yourself." end
    L[#L + 1] = "|cff999999" .. ns.Talents:SourceLine(st.build) .. "|r"
    return table.concat(L, "\n")
end

function TH:Refresh()
    if not _G.PlayerTalentFrame then return end
    self:HideMarkers()
    local panel = self:Panel()
    if not self:Enabled() then if panel then panel:Hide() end return end
    local st = self:State()
    if panel then panel.text:SetText(self:PanelText(st)) panel:SetHeight((tonumber(panel.text:GetStringHeight()) or 120) + 20) panel:Show() end
    local tab = selectedTab()
    if not tab or not st.ci then return end
    for n, p in ipairs(st.next) do
        if p.talent.tab == tab and p.talent.liveIndex then
            for i = 1, (MAX_NUM_TALENTS or 40) do
                local b = talentButton(i)
                if not b then break end
                if b.GetID and b:GetID() == p.talent.liveIndex and (not b.IsShown or b:IsShown()) then
                    local m = marker(b)
                    if m then
                        m.text:SetText(tostring(n))
                        m.text:Show()
                        if n == 1 then m.glow:Show() end
                    end
                end
            end
        end
    end
end

-- Tooltip line for (tab, index): where the talent sits in the plan.
function TH:TooltipLine(tab, index)
    if not self:Enabled() then return nil end
    local st = self:State()
    if not st.build or not st.ci then return nil end
    local t
    for _, x in ipairs(st.ci.tabs[tab] and st.ci.tabs[tab].talents or {}) do if x.liveIndex == index then t = x break end end
    if not t then return nil end
    for n, p in ipairs(st.next) do
        if p.talent.id == t.id then
            return string.format("TBCGuide: pick %d of your plan (rank %d at level %d)", n, p.rank, p.level), n == 1
        end
    end
    local want = 0
    for _, s in ipairs((ns.Talents:Expand(st.build))) do if s.talent.id == t.id then want = math.max(want, s.rank) end end
    if want == 0 then return "TBCGuide: not in your plan (" .. st.build.name .. ")" end
    return string.format("TBCGuide: your plan takes %d/%d", want, t.ranks)
end

function TH:Hook()
    if self.hooked or not _G.PlayerTalentFrame then return end
    self.hooked = true
    if type(_G.PlayerTalentFrame_Update) == "function" then
        hooksecurefunc("PlayerTalentFrame_Update", function() TH:Refresh() end)
    end
    _G.PlayerTalentFrame:HookScript("OnShow", function() TH:Refresh() end)
    for i = 1, 3 do
        local tabButton = _G["PlayerTalentFrameTab" .. i]
        if tabButton and tabButton.HookScript then tabButton:HookScript("OnClick", function() TH:Refresh() end) end
    end
end

function TH:Init()
    if GameTooltip and GameTooltip.SetTalent then
        hooksecurefunc(GameTooltip, "SetTalent", function(tt, tab, index)
            local line, isNext = TH:TooltipLine(tab, index)
            if line then
                if isNext then tt:AddLine(line, 0.3, 1, 0.3) else tt:AddLine(line, 0.6, 0.8, 1) end
                tt:Show()
            end
        end)
    end
    self:Hook()
    ns:On("ADDON_LOADED", function(_, name) if name == "Blizzard_TalentUI" then TH:Hook() end end)
    ns:Listen("TBCG_TALENTS_CHANGED", function() TH:Refresh() end)
end
