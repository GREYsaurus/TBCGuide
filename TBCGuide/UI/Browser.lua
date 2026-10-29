-- TBCGuide - guide browser
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

local W = ns.Widgets
local Browser = { rows = {}, filter = {} }
ns.Browser = Browser

local RACE_NAMES = {
    Human = "Human", Dwarf = "Dwarf", Gnome = "Gnome", NightElf = "Night Elf", Draenei = "Draenei",
    Orc = "Orc", Troll = "Troll", Tauren = "Tauren", Scourge = "Undead", BloodElf = "Blood Elf",
}
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local ROW_H = 18

local function className(c)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or c
end

function Browser:DefaultFilter()
    local p = ns.Compat.PlayerInfo()
    self.filter = { faction = p.faction, race = p.race, class = p.class, level = nil, chapter = nil, text = "", mine = true }
end

function Browser:Create()
    local f = W.Panel("TBCGuideBrowser", UIParent, 520, 420)
    self.frame = f
    f:SetFrameStrata("DIALOG")
    W.Movable(f, "browser")
    W.CloseButton(f)
    tinsert(UISpecialFrames, "TBCGuideBrowser")

    W.TitleBar(f, "TBCGuide - Guides")

    self:DefaultFilter()

    -- Filter row 1: faction / race / class
    local factionDD = W.Dropdown(f, "TBCGuideBrowserFaction", 80, function()
        return { { text = "Alliance", value = "Alliance" }, { text = "Horde", value = "Horde" } }
    end, function(v) Browser.filter.faction = v; Browser.filter.race = nil; Browser:Refresh() end,
    function() return Browser.filter.faction end)
    factionDD:SetPoint("TOPLEFT", 0, -32)

    local raceDD = W.Dropdown(f, "TBCGuideBrowserRace", 90, function()
        local items = { { text = "Any race", value = false } }
        for key, rec in pairs(ns.RaceClass and ns.RaceClass.races or {}) do
            if rec.faction == Browser.filter.faction then items[#items + 1] = { text = RACE_NAMES[key] or key, value = key } end
        end
        table.sort(items, function(a, b) return (a.value and a.text or "") < (b.value and b.text or "") end)
        return items
    end, function(v) Browser.filter.race = v or nil; Browser:Refresh() end,
    function() return Browser.filter.race and RACE_NAMES[Browser.filter.race] or "Any race" end)
    raceDD:SetPoint("LEFT", factionDD, "RIGHT", -24, 0)
    self.raceDD = raceDD

    local classDD = W.Dropdown(f, "TBCGuideBrowserClass", 90, function()
        local items = { { text = "Any class", value = false } }
        for _, c in ipairs(CLASSES) do items[#items + 1] = { text = className(c), value = c } end
        return items
    end, function(v) Browser.filter.class = v or nil; Browser:Refresh() end,
    function() return Browser.filter.class and className(Browser.filter.class) or "Any class" end)
    classDD:SetPoint("LEFT", raceDD, "RIGHT", -24, 0)

    local chapterDD = W.Dropdown(f, "TBCGuideBrowserChapter", 80, function()
        return { { text = "All", value = false }, { text = "Azeroth", value = "Azeroth" }, { text = "Outland", value = "Outland" } }
    end, function(v) Browser.filter.chapter = v or nil; Browser:Refresh() end,
    function() return Browser.filter.chapter or "All" end)
    chapterDD:SetPoint("LEFT", classDD, "RIGHT", -24, 0)

    -- Filter row 2: search, level fit
    local search = W.Input(f, "TBCGuideBrowserSearch", 160, 20)
    search:SetPoint("TOPLEFT", 14, -70)
    search:SetScript("OnTextChanged", function(self) Browser.filter.text = self:GetText(); Browser:Refresh() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local sl = W.Text(f, "GameFontHighlightSmall")
    sl:SetPoint("BOTTOMLEFT", search, "TOPLEFT", -4, 1)
    sl:SetText("Search zone / name")

    local lvl = W.Check(f, 16)
    lvl:SetPoint("LEFT", search, "RIGHT", 12, 0)
    lvl:SetScript("OnClick", function(self)
        Browser.filter.level = self:GetChecked() and (UnitLevel("player") or 1) or nil
        Browser:Refresh()
    end)
    local ll = W.Text(f, "GameFontHighlightSmall")
    ll:SetPoint("LEFT", lvl, "RIGHT", 6, 0)
    ll:SetText("Only my level")

    W.Button(f, "Recommended", 100, 20, function()
        local g, why = ns.Selector:Recommend()
        if g then
            Browser.selected = g.id
            ns:Print("Recommended: " .. g.name .. " (" .. why .. ")")
            Browser:Refresh()
        end
    end):SetPoint("TOPRIGHT", -14, -70)

    -- List
    local listBg = W.Panel(nil, f, 300, 300)
    W.Skin(listBg, "panel")
    listBg:SetPoint("TOPLEFT", 12, -98)
    listBg:SetPoint("BOTTOMLEFT", 12, 40)
    listBg:SetWidth(300)
    local scroll, content = W.Scroll(listBg, "TBCGuideBrowserScroll")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    self.content = content

    -- Detail pane
    local detail = W.Text(f, "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", listBg, "TOPRIGHT", 10, -4)
    detail:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    detail:SetHeight(270)
    self.detail = detail

    W.Button(f, "Load guide", 90, 22, function()
        if Browser.selected then ns.Engine:Load(Browser.selected); ns.MainFrame:Show() end
    end):SetPoint("BOTTOMRIGHT", -12, 12)
    W.Button(f, "Restart guide", 100, 22, function()
        if Browser.selected then ns.Engine:Load(Browser.selected, { reset = true }); ns.MainFrame:Show() end
    end):SetPoint("BOTTOMRIGHT", -108, 12)
    W.Button(f, "My route", 80, 22, function()
        Browser:DefaultFilter()
        Browser:Refresh()
    end):SetPoint("BOTTOMLEFT", 12, 12)

    f:Hide()
end

function Browser:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    local list = ns.Guides:Filter(self.filter)
    local rec = ns.Selector:Recommend()
    local current = ns.Engine.guide
    local width = self.content:GetWidth()
    for i, g in ipairs(list) do
        local r = self.rows[i]
        if not r then
            r = CreateFrame("Button", nil, self.content)
            r:SetHeight(ROW_H)
            r.hl = r:CreateTexture(nil, "BACKGROUND")
            r.hl:SetAllPoints()
            r.hl:SetColorTexture(0.2, 0.5, 1, 0.25)
            r.text = W.Text(r, "GameFontHighlightSmall")
            r.text:SetPoint("LEFT", 4, 0)
            r.text:SetPoint("RIGHT", -4, 0)
            r.text:SetWordWrap(false)
            r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            r:SetScript("OnClick", function(self) Browser.selected = self.guideId; Browser:Refresh() end)
            r:SetScript("OnDoubleClick", function(self) ns.Engine:Load(self.guideId); ns.MainFrame:Show() end)
            self.rows[i] = r
        end
        r.guideId = g.id
        r:SetWidth(width)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        local tag = ""
        if rec and rec.id == g.id then tag = " |cff55ff55(recommended)|r" end
        if current and current.id == g.id then tag = tag .. " |cffffd100(active)|r" end
        r.text:SetText(string.format("|cffaaaaaa%2d-%2d|r  %s%s", g.minLevel, g.maxLevel, g.name, tag))
        r.hl:SetShown(self.selected == g.id)
        r:Show()
    end
    for i = #list + 1, #self.rows do self.rows[i]:Hide() end
    self.content:SetHeight(math.max(#list * ROW_H, 10))

    local g = ns.Guides:Get(self.selected)
    if g then
        local lines = {
            "|cffffd100" .. g.name .. "|r",
            string.format("Levels %d-%d  -  %s  -  %s", g.minLevel, g.maxLevel, g.faction, g.chapter or ""),
        }
        if g.zoneName then lines[#lines + 1] = "Zone: " .. g.zoneName end
        if g.races then
            local rn = {}
            for _, r in ipairs(g.races) do rn[#rn + 1] = RACE_NAMES[r] or r end
            lines[#lines + 1] = "Races: " .. table.concat(rn, ", ")
        end
        if g.classes then lines[#lines + 1] = "Classes: " .. table.concat(g.classes, ", ") end
        lines[#lines + 1] = string.format("%d steps", #g.steps)
        local p = ns.char.progress[g.id]
        if p and p.step > 1 then lines[#lines + 1] = "Your progress: step " .. p.step end
        if g.desc then lines[#lines + 1] = "\n" .. g.desc end
        if g.next and g.next[1] then
            local n = ns.Guides:Get(g.next[1].id)
            if n then lines[#lines + 1] = "\nNext: " .. n.name end
        end
        self.detail:SetText(table.concat(lines, "\n"))
    else
        local hist = {}
        for i = 1, math.min(5, #ns.char.history) do
            local hg = ns.Guides:Get(ns.char.history[i])
            if hg then hist[#hist + 1] = "- " .. hg.name end
        end
        self.detail:SetText("Select a guide on the left.\nDouble-click loads it.\n\n" ..
            (#hist > 0 and ("Recent guides:\n" .. table.concat(hist, "\n")) or ""))
    end
end

function Browser:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:Refresh() end
end

function Browser:Show()
    if not self.frame then return end
    self.frame:Show()
    self:Refresh()
end
