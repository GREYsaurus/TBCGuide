-- TBCGuide - talent guide and calculator window
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Modes:
--   Simulated - a sandbox allocation (saved per character, per class). Never touches real talents.
--   Character - read-only view of your actual talents (only for your own class; TBC API limit).
-- The selected build is overlaid on either mode: gold number = build rank at the chosen level.

local _, ns = ...

local W = ns.Widgets
local TF = { buttons = {}, mode = "sim", previewLevel = 70 }
ns.TalentFrame = TF

local CELL = 38
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local function className(c) return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or c end

local function spellIcon(spellId)
    if GetSpellTexture then
        local tex = GetSpellTexture(spellId)
        if tex then return tex end
    end
    if GetSpellInfo then
        local _, _, icon = GetSpellInfo(spellId)
        if icon then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Simulation state --------------------------------------------------------------------------------

function TF:Sim()
    local s = ns.char.simTalents[self.class]
    if not s then s = {}; ns.char.simTalents[self.class] = s end
    return s
end

local function tabPoints(alloc, ci, tabNo)
    local n = 0
    for _, t in ipairs(ci.tabs[tabNo].talents) do n = n + (alloc[t.id] or 0) end
    return n
end

local function totalPoints(alloc)
    local n = 0
    for _, r in pairs(alloc) do n = n + r end
    return n
end

-- Is `alloc` a legal allocation? (tier gating counted on points below each tier, prereqs, ranks)
local function isLegal(alloc, ci)
    if totalPoints(alloc) > ns.Target.talentPointsAt(ns.Target.maxLevel) then return false end
    for _, tab in ipairs(ci.tabs) do
        for _, t in ipairs(tab.talents) do
            local r = alloc[t.id] or 0
            if r > t.ranks then return false end
            if r > 0 then
                local below = 0
                for _, o in ipairs(tab.talents) do
                    if o.tier < t.tier then below = below + (alloc[o.id] or 0) end
                end
                if below < (t.tier - 1) * 5 then return false end
                if t.prereq and (alloc[t.prereq[1]] or 0) < t.prereq[2] then return false end
            end
        end
    end
    return true
end

function TF:AddPoint(t)
    if self.mode ~= "sim" then return end
    local alloc = self:Sim()
    local ci = ns.Talents:Index(self.class)
    alloc[t.id] = (alloc[t.id] or 0) + 1
    if not isLegal(alloc, ci) then
        alloc[t.id] = alloc[t.id] - 1
        if alloc[t.id] == 0 then alloc[t.id] = nil end
        return
    end
    self:Render()
end

function TF:RemovePoint(t)
    if self.mode ~= "sim" then return end
    local alloc = self:Sim()
    local ci = ns.Talents:Index(self.class)
    if not alloc[t.id] then return end
    alloc[t.id] = alloc[t.id] - 1
    if alloc[t.id] == 0 then alloc[t.id] = nil end
    if not isLegal(alloc, ci) then
        alloc[t.id] = (alloc[t.id] or 0) + 1
        return
    end
    self:Render()
end

function TF:LoadBuildIntoSim()
    if not self.build then return end
    local ranks = ns.Talents:RanksAt(self.build, ns.Target.talentPointsAt(self.previewLevel))
    ns.char.simTalents[self.class] = ranks
    self.mode = "sim"
    self:Render()
end

-- UI --------------------------------------------------------------------------------------------

local function createCell(parent)
    local b = CreateFrame("Button", nil, parent, ns.Compat.BackdropTemplate)
    b:SetSize(CELL - 6, CELL - 6)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetPoint("TOPLEFT", -3, 3)
    b.border:SetPoint("BOTTOMRIGHT", 3, -3)
    b.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.border:SetBlendMode("ADD")
    b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.rank:SetPoint("BOTTOMRIGHT", 3, -3)
    b.buildRank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.buildRank:SetPoint("TOPLEFT", -3, 3)
    b.buildRank:SetTextColor(1, 0.82, 0)
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then TF:RemovePoint(self.talent) else TF:AddPoint(self.talent) end
    end)
    b:SetScript("OnEnter", function(self) TF:ShowTooltip(self) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

function TF:ShowTooltip(btn)
    local t = btn.talent
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    local cur = btn.curRank or 0
    local spell = t.spells[math.max(1, math.min(cur > 0 and cur or 1, #t.spells))]
    ns.Compat.SetSpellTooltip(GameTooltip, spell)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format("Rank %d/%d  (tier %d)", cur, t.ranks, t.tier), 1, 1, 1)
    if t.prereq then
        local pre = ns.Talents:Index(self.class).byId[t.prereq[1]]
        GameTooltip:AddLine(string.format("Requires %d/%d %s", t.prereq[2], pre and pre.ranks or 0, pre and pre.name or "?"), 1, 0.5, 0.3)
    end
    if btn.buildRankValue and btn.buildRankValue > 0 then
        GameTooltip:AddLine(string.format("Build: %d/%d by level %d", btn.buildRankValue, t.ranks, self.previewLevel), 1, 0.82, 0)
        if btn.buildNote then GameTooltip:AddLine(btn.buildNote, 0.8, 0.8, 0.8, true) end
    end
    if self.mode == "sim" then GameTooltip:AddLine("Left-click: add point - Right-click: remove", 0.5, 0.5, 0.5) end
    GameTooltip:Show()
end

function TF:Create()
    local f = W.Panel("TBCGuideTalentFrame", UIParent, 3 * (4 * CELL + 16) + 230, 9 * CELL + 120)
    self.frame = f
    f:SetFrameStrata("DIALOG")
    W.Movable(f, "talents")
    W.CloseButton(f)
    tinsert(UISpecialFrames, "TBCGuideTalentFrame")

    W.TitleBar(f, "TBCGuide - Talents")

    self.class = ns.Compat.PlayerInfo().class

    local classDD = W.Dropdown(f, "TBCGuideTalentClass", 90, function()
        local items = {}
        for _, c in ipairs(CLASSES) do items[#items + 1] = { text = className(c), value = c } end
        return items
    end, function(v)
        TF.class = v
        TF.build = nil
        if v ~= ns.Compat.PlayerInfo().class then TF.mode = "sim" end
        TF:Render()
    end, function() return className(TF.class) end)
    classDD:SetPoint("TOPLEFT", 0, -34)
    self.classDD = classDD

    local buildDD = W.Dropdown(f, "TBCGuideTalentBuild", 170, function()
        local items = {}
        for _, b in ipairs(ns.Talents:BuildsFor(TF.class)) do
            items[#items + 1] = { text = b.name, value = b.id, checked = TF.build and TF.build.id == b.id }
        end
        return items
    end, function(v)
        TF.build = ns.Talents.builds[v]
        if TF.class == ns.Compat.PlayerInfo().class then ns.char.talentBuild = v end
        TF:Render()
    end, function() return TF.build and TF.build.name or "Choose build" end)
    buildDD:SetPoint("LEFT", classDD, "RIGHT", -24, 0)
    self.buildDD = buildDD

    self.modeBtn = W.Button(f, "Mode: Simulated", 130, 22, function()
        if TF.mode == "sim" and TF.class == ns.Compat.PlayerInfo().class then TF.mode = "live" else TF.mode = "sim" end
        TF:Render()
    end)
    self.modeBtn:SetPoint("LEFT", buildDD, "RIGHT", -6, 2)

    W.Button(f, "Reset sim", 80, 22, function()
        ns.char.simTalents[TF.class] = {}
        TF:Render()
    end):SetPoint("LEFT", self.modeBtn, "RIGHT", 4, 0)
    W.Button(f, "Apply build to sim", 130, 22, function() TF:LoadBuildIntoSim() end):SetPoint("TOPRIGHT", -30, -36)

    local slider = CreateFrame("Slider", "TBCGuideTalentLevel", f, "OptionsSliderTemplate")
    slider:SetMinMaxValues(10, ns.Target.maxLevel)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetWidth(200)
    slider:SetPoint("TOPRIGHT", -24, -78)
    slider:SetScript("OnValueChanged", function(_, v)
        TF.previewLevel = math.floor(v + 0.5)
        local label = _G["TBCGuideTalentLevelText"]
        if label then label:SetText("Show build at level " .. TF.previewLevel) end
        TF:Render()
    end)
    W.SkinSlider(slider, "TBCGuideTalentLevel")
    local low, high = _G["TBCGuideTalentLevelLow"], _G["TBCGuideTalentLevelHigh"]
    if low then low:SetText("10") end
    if high then high:SetText(tostring(ns.Target.maxLevel)) end
    self.slider = slider

    self.treeFrames = {}
    for tabNo = 1, 3 do
        local tf = W.Panel(nil, f, 4 * CELL + 10, 9 * CELL + 30)
        tf:SetPoint("TOPLEFT", 12 + (tabNo - 1) * (4 * CELL + 16), -96)
        tf.title = W.Text(tf, "GameFontNormal", "CENTER")
        tf.title:SetPoint("TOP", 0, -6)
        tf.cells = {}
        self.treeFrames[tabNo] = tf
    end

    local side = W.Text(f, "GameFontHighlightSmall")
    side:SetPoint("TOPLEFT", self.treeFrames[3], "TOPRIGHT", 10, 0)
    side:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    self.side = side

    self.status = W.Text(f, "GameFontHighlight")
    self.status:SetPoint("BOTTOMLEFT", 14, 10)

    ns:Listen("TBCG_TALENTS_CHANGED", function() if TF.frame:IsShown() then TF:Render() end end)
    slider:SetValue(70)
    f:Hide()
end

function TF:Render()
    if not self.frame then return end
    local ci = ns.Talents:Index(self.class)
    if not ci then
        self.status:SetText("No talent data for " .. tostring(self.class))
        return
    end
    if not self.build or self.build.class ~= self.class then
        if self.class == ns.Compat.PlayerInfo().class then self.build = ns.Talents:ActiveBuild() end
        if not self.build or self.build.class ~= self.class then self.build = ns.Talents:BuildsFor(self.class)[1] end
    end
    UIDropDownMenu_SetText(self.classDD, className(self.class))
    UIDropDownMenu_SetText(self.buildDD, self.build and self.build.name or "No builds")

    local isOwn = self.class == ns.Compat.PlayerInfo().class
    if self.mode == "live" and not isOwn then self.mode = "sim" end
    self.modeBtn:SetText(self.mode == "live" and "Mode: Your talents" or "Mode: Simulated")
    if isOwn then self.modeBtn:Enable() else self.modeBtn:Disable() end

    local alloc, mismatches
    if self.mode == "live" then alloc, mismatches = ns.Talents:ReadLive() else alloc = self:Sim() end

    local buildRanks, seq = {}, {}
    local buildErrors = {}
    if self.build then
        buildRanks, seq = ns.Talents:RanksAt(self.build, ns.Target.talentPointsAt(self.previewLevel))
        local _, errs = ns.Talents:Expand(self.build)
        buildErrors = errs
    end
    local notes = {}
    for _, p in ipairs(seq) do if p.note then notes[p.talent.id] = p.note end end

    for tabNo = 1, 3 do
        local tab, tf = ci.tabs[tabNo], self.treeFrames[tabNo]
        for _, c in ipairs(tf.cells) do c:Hide() end
        if tab then
            tf.title:SetText(string.format("%s (%d)", tab.name, tabPoints(alloc, ci, tabNo)))
            for n, t in ipairs(tab.talents) do
                local b = tf.cells[n] or createCell(tf)
                tf.cells[n] = b
                b.talent = t
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 8 + (t.column - 1) * CELL, -24 - (t.tier - 1) * CELL)
                b.icon:SetTexture(spellIcon(t.spells[1]))
                local r = alloc[t.id] or 0
                b.curRank = r
                b.rank:SetText(r > 0 and (r .. "/" .. t.ranks) or "")
                b.icon:SetDesaturated(r == 0)
                b.icon:SetAlpha(r == 0 and 0.6 or 1)
                local br = buildRanks[t.id] or 0
                b.buildRankValue = br
                b.buildNote = notes[t.id]
                b.buildRank:SetText(br > 0 and tostring(br) or "")
                if br > 0 and r == br then
                    b.border:SetVertexColor(0.2, 1, 0.2); b.border:Show()
                elseif br > 0 then
                    b.border:SetVertexColor(1, 0.82, 0); b.border:Show()
                elseif r > 0 then
                    b.border:SetVertexColor(1, 0.3, 0.3); b.border:Show()
                else
                    b.border:Hide()
                end
                b:Show()
            end
        end
    end

    local used = totalPoints(alloc)
    local avail = ns.Target.talentPointsAt(self.mode == "live" and (UnitLevel("player") or 1) or ns.Target.maxLevel)
    self.status:SetText(string.format("%s: %d / %d points%s", self.mode == "live" and "Your talents" or "Simulated", used, avail,
        self.mode == "live" and "" or "  |cff999999(simulation - does not change your character)|r"))

    -- Side panel: build summary and comparison
    local lines = {}
    local b = self.build
    if b then
        lines[#lines + 1] = "|cffffd100" .. b.name .. "|r"
        lines[#lines + 1] = (b.kind or "") .. (b.role and (" - " .. b.role) or "")
        if b.summary then lines[#lines + 1] = "\n" .. b.summary end
        if b.notes then
            lines[#lines + 1] = ""
            for _, n in ipairs(b.notes) do lines[#lines + 1] = "- " .. n end
        end
        local missing, extra = 0, 0
        for id, r in pairs(buildRanks) do if (alloc[id] or 0) < r then missing = missing + (r - (alloc[id] or 0)) end end
        for id, r in pairs(alloc) do if r > (buildRanks[id] or 0) then extra = extra + (r - (buildRanks[id] or 0)) end end
        lines[#lines + 1] = string.format("\nCompared with build at %d: |cffffd100%d|r missing, |cffff5555%d|r off-build", self.previewLevel, missing, extra)
        if self.mode == "live" then
            local p = ns.Talents:NextPick(b, alloc)
            if p then lines[#lines + 1] = "Next point: |cffffd100" .. p.talent.name .. "|r rank " .. p.rank end
        end
        if #buildErrors > 0 then lines[#lines + 1] = "|cffff5555Build data problem: " .. buildErrors[1] .. "|r" end
    else
        lines[#lines + 1] = "No builds for this class yet."
    end
    if mismatches and #mismatches > 0 then
        lines[#lines + 1] = "\n|cffff7744Client/data mismatch: " .. mismatches[1] .. "|r"
    end
    local advice = ns.ClassAdvice:For(self.class)
    if advice then lines[#lines + 1] = "\n|cffffd100Leveling tips|r\n" .. advice.summary .. "\n(/tbcg class for the full list)" end
    lines[#lines + 1] = "\n|cff999999Gold numbers: build ranks. Green border: matches build.|r"
    self.side:SetText(table.concat(lines, "\n"))
end

function TF:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:Render() end
end
