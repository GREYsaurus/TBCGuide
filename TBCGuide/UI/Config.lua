-- TBCGuide - settings window: tabs, sections and widgets built from declarative page data
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Pages are lists of items (UI/ConfigOptions.lua):
--   { type = "header", text }                       gold title between two divider lines
--   { type = "toggle", key | get/set, label, invert, tip, planned }
--   { type = "range", key | get/set, label, min, max, step, percent }
--   { type = "select", key | get/set, label, values = function() return { {value, text}, ... } end }
--   { type = "button", label, func, span, red }      (UIPanelButtonTemplate is red in Classic)
--   { type = "color", key, label }
--   { type = "input", label, func(text), span }
--   { type = "keybind", label, get, set }
--   { type = "desc", text }                          full-width paragraph
--   { type = "newline" }
-- Items flow left to right in three columns. `planned = true` shows the control disabled with a
-- "not in TBCGuide yet" tooltip: nothing pretends to work that does not.

local _, ns = ...

local W = ns.Widgets
local CF = { pages = {}, built = {}, widgets = {} }
ns.Config = CF

CF.WIDTH, CF.HEIGHT = 900, 690
local COLS = 3
local PAD = 18

local function prof() return ns.db.profile end

-- Values ---------------------------------------------------------------------------------------------

local function getValue(it)
    if it.get then return it.get() end
    local v = prof()[it.key]
    if it.invert then return not v end
    return v
end

local function setValue(it, v)
    if it.set then it.set(v) else
        if it.invert then v = not v end
        prof()[it.key] = v
    end
    CF:Changed(it)
end

-- After any change: the rest of the add-on re-reads its settings.
function CF:Changed(it)
    if ns.Options and ns.Options.panel then ns.Options:Apply() end
    if ns.MinimapButton then ns.MinimapButton:Update() end
    if ns.Marker and ns.Marker.gen then ns.Marker:OnRefresh() end
    if it and it.after then it.after() end
end

-- Widgets ----------------------------------------------------------------------------------------------

local function tooltip(owner, title, text)
    owner:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title)
        if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local PLANNED = "Not in TBCGuide yet. This option is shown so you can see what is planned; it does nothing."

local function line(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    if t.SetColorTexture then t:SetColorTexture(0.75, 0.75, 0.75, 0.55) else t:SetTexture(0.75, 0.75, 0.75, 0.55) end
    return t
end

local build = {}

function build.header(page, it, x, y, w)
    local fs = W.Text(page, "GameFontNormalLarge", "CENTER")
    fs:SetPoint("TOP", page, "TOPLEFT", x + w / 2, y - 4)
    fs:SetText(it.text)
    local l, r = line(page), line(page)
    l:SetPoint("LEFT", page, "TOPLEFT", x, y - 13)
    l:SetPoint("RIGHT", fs, "LEFT", -8, 0)
    r:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    r:SetPoint("RIGHT", page, "TOPLEFT", x + w, y - 13)
    return { height = 30, sync = function() end }
end

function build.desc(page, it, x, y, w)
    local fs = W.Text(page, it.font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - 2)
    fs:SetWidth(w)
    fs:SetText(it.text)
    local h = (fs.GetStringHeight and fs:GetStringHeight() or 14) + 8
    return { height = math.max(h, 18), sync = function() end }
end

-- Text that is recomputed on every sync (e.g. "Current Profile: ...").
function build.label(page, it, x, y, w)
    local fs = W.Text(page, it.font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", page, "TOPLEFT", x + 4, y - 6)
    fs:SetWidth(w - 8)
    return { height = it.height or 30, sync = function() fs:SetText(it.text()) end, fs = fs }
end

function build.toggle(page, it, x, y, w)
    local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
    local text = W.Text(cb, "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    text:SetWidth(w - 34)
    text:SetWordWrap(false)
    text:SetText(it.label)
    cb.label = text
    if it.planned then
        cb:Disable()
        text:SetTextColor(0.5, 0.5, 0.5)
        tooltip(cb, it.label, PLANNED)
    else
        cb:SetScript("OnClick", function(s) setValue(it, s:GetChecked() and true or false) end)
        if it.tip then tooltip(cb, it.label, it.tip) end
    end
    local w2 = { height = 32, frame = cb, item = it }
    w2.sync = function()
        if it.planned then cb:SetChecked(it.default and true or false) return end
        cb:SetChecked(getValue(it) and true or false)
        if it.disabled then
            local off = it.disabled()
            if off then cb:Disable() text:SetTextColor(0.5, 0.5, 0.5) else cb:Enable() text:SetTextColor(1, 1, 1) end
        end
    end
    return w2
end

CF.sliderCount = 0
function build.range(page, it, x, y, w)
    CF.sliderCount = CF.sliderCount + 1
    local name = "TBCGuideConfigSlider" .. CF.sliderCount
    local title = W.Text(page, "GameFontNormal", "CENTER")
    title:SetPoint("TOP", page, "TOPLEFT", x + w / 2, y)
    title:SetText(it.label)
    local s = CreateFrame("Slider", name, page, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", page, "TOPLEFT", x + 6, y - 18)
    s:SetWidth(w - 24)
    s:SetMinMaxValues(it.min, it.max)
    s:SetValueStep(it.step or 1)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local function fmt(v)
        if it.percent then return math.floor(v * 100 + 0.5) .. "%" end
        return tostring(ns.Round(v, it.decimals or 0)) .. (it.suffix or "")
    end
    local low, high = _G[name .. "Low"], _G[name .. "High"]
    if low then low:SetText(fmt(it.min)) end
    if high then high:SetText(fmt(it.max)) end
    local mid = _G[name .. "Text"]
    if mid then mid:SetText("") end
    local box = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    box:SetSize(80, 18)
    box:SetPoint("TOP", s, "BOTTOM", 0, -4)
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")
    local syncing = false
    s:SetScript("OnValueChanged", function(_, v)
        local step = it.step or 1
        v = math.floor(v / step + 0.5) * step
        box:SetText(fmt(v))
        if not syncing and not it.planned then setValue(it, ns.Round(v, it.decimals or 2)) end
    end)
    box:SetScript("OnEnterPressed", function(b)
        local v = tonumber((string.gsub(b:GetText() or "", "[^%d%.%-]", "")))
        if v and it.percent then v = v / 100 end
        if v then s:SetValue(math.max(it.min, math.min(it.max, v))) end
        b:ClearFocus()
    end)
    if it.planned then
        s:Disable()
        title:SetTextColor(0.5, 0.5, 0.5)
        tooltip(s, it.label, PLANNED)
    end
    local w2 = { height = 64, frame = s, box = box, item = it }
    w2.sync = function()
        syncing = true
        local v = it.planned and (it.default or it.min) or getValue(it)
        s:SetValue(tonumber(v) or it.min)
        box:SetText(fmt(tonumber(v) or it.min))
        syncing = false
    end
    return w2
end

CF.dropCount = 0
function build.select(page, it, x, y, w)
    CF.dropCount = CF.dropCount + 1
    local title = W.Text(page, "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", x + 4, y)
    title:SetText(it.label)
    local dd = W.Dropdown(page, "TBCGuideConfigDrop" .. CF.dropCount, w - 40,
        function()
            local out = {}
            for _, v in ipairs(it.values()) do out[#out + 1] = { text = v[2], value = v[1], checked = getValue(it) == v[1] } end
            return out
        end,
        function(v) if not it.planned then setValue(it, v) end CF:SyncAll() end,
        function()
            local cur = getValue(it)
            for _, v in ipairs(it.values()) do if v[1] == cur then return v[2] end end
            return it.empty or ""
        end)
    dd:SetPoint("TOPLEFT", page, "TOPLEFT", x - 14, y - 14)
    if it.planned then title:SetTextColor(0.5, 0.5, 0.5) end
    local w2 = { height = 52, frame = dd, item = it }
    w2.sync = function()
        local cur = getValue(it)
        local label = it.empty or ""
        for _, v in ipairs(it.values()) do if v[1] == cur then label = v[2] end end
        UIDropDownMenu_SetText(dd, label)
    end
    return w2
end

function build.button(page, it, x, y, w)
    local b = W.Button(page, it.label, w - 8, 26, function() if not it.planned then it.func() CF:SyncAll() end end)
    b:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - 2)
    if it.planned then b:Disable() tooltip(b, it.label, PLANNED) elseif it.tip then tooltip(b, it.label, it.tip) end
    return { height = 34, frame = b, sync = function() if it.disabled then if it.disabled() then b:Disable() else b:Enable() end end end }
end

function build.input(page, it, x, y, w)
    local title = W.Text(page, "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", x + 4, y)
    title:SetText(it.label)
    local box = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    box:SetSize(w - 20, 22)
    box:SetPoint("TOPLEFT", page, "TOPLEFT", x + 8, y - 16)
    box:SetAutoFocus(false)
    box:SetScript("OnEnterPressed", function(b)
        local text = b:GetText()
        b:SetText("")
        b:ClearFocus()
        it.func(text)
        CF:SyncAll()
    end)
    box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
    return { height = 46, frame = box, sync = function() end }
end

function build.color(page, it, x, y, w)
    local b = CreateFrame("Button", nil, page)
    b:SetSize(22, 22)
    b:SetPoint("TOPLEFT", page, "TOPLEFT", x + 4, y - 4)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    if border.SetColorTexture then border:SetColorTexture(1, 1, 1, 1) end
    local sw = b:CreateTexture(nil, "ARTWORK")
    sw:SetPoint("TOPLEFT", 2, -2)
    sw:SetPoint("BOTTOMRIGHT", -2, 2)
    local text = W.Text(b, "GameFontHighlight")
    text:SetPoint("LEFT", b, "RIGHT", 6, 0)
    text:SetText(it.label)
    local function paint()
        local c = it.planned and (it.default or { r = 0.5, g = 0.5, b = 0.5 }) or prof()[it.key]
        if sw.SetColorTexture then sw:SetColorTexture(c.r, c.g, c.b, 1) end
    end
    if it.planned then
        text:SetTextColor(0.5, 0.5, 0.5)
        tooltip(b, it.label, PLANNED)
    else
        b:SetScript("OnClick", function() CF:PickColor(it, paint) end)
    end
    return { height = 32, frame = b, sync = paint }
end

-- ColorPickerFrame (Classic API): func / cancelFunc read the picker; previousValues restores.
function CF:PickColor(it, paint)
    local c = prof()[it.key]
    local f = ColorPickerFrame
    if not f then return end
    local function apply(r, g, b)
        prof()[it.key] = { r = r, g = g, b = b }
        paint()
        CF:Changed(it)
    end
    local old = { r = c.r, g = c.g, b = c.b }
    if f.SetupColorPickerAndShow then -- newer Classic clients
        f:SetupColorPickerAndShow({ r = c.r, g = c.g, b = c.b, hasOpacity = false,
            swatchFunc = function() apply(f:GetColorRGB()) end,
            cancelFunc = function() apply(old.r, old.g, old.b) end })
        return
    end
    f.hasOpacity = false
    f.previousValues = { old.r, old.g, old.b }
    f.func = function() apply(f:GetColorRGB()) end
    f.cancelFunc = function() apply(old.r, old.g, old.b) end
    if f.SetColorRGB then f:SetColorRGB(c.r, c.g, c.b) end
    f:Hide()
    if ShowUIPanel then ShowUIPanel(f) else f:Show() end
end

function build.keybind(page, it, x, y, w)
    local title = W.Text(page, "GameFontHighlight")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", x + 4, y)
    title:SetText(it.label)
    local b = W.Button(page, "", w - 8, 26)
    b:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - 18)
    local function label()
        b:SetText(b.waiting and "Press a key (Esc cancels)" or (it.get() or "Not Bound"))
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then it.set(nil) b.waiting = false label() return end
        b.waiting = not b.waiting
        if b.EnableKeyboard then b:EnableKeyboard(b.waiting) end
        label()
    end)
    b:SetScript("OnKeyDown", function(_, key)
        if not b.waiting then return end
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end
        b.waiting = false
        if b.EnableKeyboard then b:EnableKeyboard(false) end
        if key ~= "ESCAPE" then
            local mods = (IsAltKeyDown and IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "")
                .. (IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or "")
            it.set(mods .. key)
        end
        label()
    end)
    tooltip(b, it.label, "Click, then press a key. Right-click to unbind.")
    return { height = 50, frame = b, sync = label }
end

-- Page layout --------------------------------------------------------------------------------------------

function CF:BuildPage(id)
    local def = self.pageDefs[id]
    local page = CreateFrame("Frame", nil, self.scrollChild)
    page:SetPoint("TOPLEFT")
    page:SetWidth(self.contentWidth)
    local colW = self.contentWidth / COLS
    local col, y, rowH = 0, -6, 0
    local widgets = {}
    local function newline()
        if col > 0 then y = y - rowH col, rowH = 0, 0 end
    end
    for _, it in ipairs(def.items(self)) do
        if it.type == "newline" then
            newline()
        else
            local full = it.type == "header" or it.type == "desc" or it.full
            local span = full and COLS or (it.span or 1)
            if col + span > COLS then newline() end
            local w = build[it.type](page, it, col * colW, y, colW * span)
            widgets[#widgets + 1] = w
            rowH = math.max(rowH, w.height)
            col = col + span
            if col >= COLS then newline() end
        end
    end
    newline()
    page:SetHeight(-y + 10)
    page.widgets = widgets
    self.built[id] = page
    return page
end

function CF:SyncAll()
    for _, page in pairs(self.built) do
        for _, w in ipairs(page.widgets) do w.sync() end
    end
    if self.frame then self.title:SetText("TBCGuide - Version " .. tostring(ns.version or "dev")) end
end

function CF:Show(id)
    id = id or self.current or "general"
    if not self.frame then return end
    for pid, page in pairs(self.built) do page:SetShown(pid == id) end
    local page = self.built[id] or self:BuildPage(id)
    page:Show()
    self.scroll:SetScrollChild(page)
    if self.scroll.SetVerticalScroll then self.scroll:SetVerticalScroll(0) end
    for tid, tab in pairs(self.tabs) do
        local on = tid == id
        if on and PanelTemplates_SelectTab then PanelTemplates_SelectTab(tab)
        elseif not on and PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
        if on then tab:LockHighlight() else tab:UnlockHighlight() end
    end
    self.current = id
    for _, w in ipairs(page.widgets) do w.sync() end
    self.frame:Show()
end

function CF:Toggle(id)
    if self.frame and self.frame:IsShown() and (id == nil or id == self.current) then self.frame:Hide() return end
    self:Show(id)
end

-- Frame ----------------------------------------------------------------------------------------------------

local TAB_ROWS = {
    { "general", "guide", "targeting", "tracker", "comms", "tips", "help" },
    { "look", "advanced", "profiles" },
}

function CF:Create()
    if self.frame then return end
    self.pageDefs = ns.ConfigPages
    local f = CreateFrame("Frame", "TBCGuideConfigFrame", UIParent, ns.Compat.BackdropTemplate)
    f:SetSize(self.WIDTH, self.HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) s:StartMoving() end)
    f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    end
    f:Hide()
    self.frame = f
    tinsert(UISpecialFrames, "TBCGuideConfigFrame") -- Escape closes it

    self.title = W.Text(f, "GameFontNormalHuge")
    self.title:SetPoint("TOPLEFT", 26, -24)

    -- Round TBCGuide icon, top right
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(54, 54)
    icon:SetPoint("TOPRIGHT", -26, -18)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    if icon.SetMask then icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    local ring = f:CreateTexture(nil, "OVERLAY")
    ring:SetSize(90, 90)
    ring:SetPoint("TOPLEFT", icon, "TOPLEFT", -6, 6)
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Top buttons
    local function top(label, x, y, w, fn, tip)
        local b = W.Button(f, label, w, 28, fn)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        if tip then tooltip(b, label, tip) end
        return b
    end
    top("Guide Browser", 24, -58, 210, function() ns.Browser:Toggle() end, "Choose or restart a guide.")
    top("Talent Guide", 238, -58, 210, function() ns.TalentFrame:Toggle() end, "Talent builds and calculator.")
    top("Report an Issue", 452, -58, 210, function() CF:ShowLink() end, "Shows the link to the TBCGuide issue tracker.")
    top("Choose the Best Guide for Me", 24, -90, 300, function()
        local g, why = ns.Selector:Recommend()
        if g then ns.Engine:Load(g.id) ns.MainFrame:Show() ns:Print("Loaded " .. g.name .. " (" .. why .. ").")
        else ns:Print("No guide available for this character.") end
    end, "Loads the guide that fits your race, class and level.")

    -- Tabs (two rows)
    self.tabs = {}
    local tabY = { -128, -156 }
    for row, ids in ipairs(TAB_ROWS) do
        local x = 24
        local width = (self.WIDTH - 48) / #ids
        for _, id in ipairs(ids) do
            local ok, tab = pcall(CreateFrame, "Button", "TBCGuideConfigTab_" .. id, f, "OptionsFrameTabButtonTemplate")
            if not ok or not tab then tab = CreateFrame("Button", "TBCGuideConfigTab_" .. id, f, "UIPanelButtonTemplate") tab:SetHeight(24) end
            tab:SetText(self.pageDefs[id].title)
            tab:SetPoint("TOPLEFT", f, "TOPLEFT", x, tabY[row])
            if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0, width - 10) else tab:SetWidth(width - 10) end
            tab:SetScript("OnClick", function() CF:Show(id) end)
            self.tabs[id] = tab
            x = x + width
        end
    end

    -- Content box with a scroll frame
    local box = CreateFrame("Frame", nil, f, ns.Compat.BackdropTemplate)
    box:SetPoint("TOPLEFT", 22, -182)
    box:SetPoint("BOTTOMRIGHT", -22, 52)
    if box.SetBackdrop then
        box:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        box:SetBackdropColor(0, 0, 0, 0.45)
        box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
    local scroll = CreateFrame("ScrollFrame", "TBCGuideConfigScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    self.scroll = scroll
    self.scrollChild = CreateFrame("Frame", nil, scroll)
    self.scrollChild:SetSize(self.WIDTH - 44 - 40, 10)
    scroll:SetScrollChild(self.scrollChild)
    self.contentWidth = self.WIDTH - 44 - 50

    W.Button(f, "Close", 120, 26, function() f:Hide() end):SetPoint("BOTTOMRIGHT", -24, 18)
    W.CloseButton(f)

    ns:Listen("TBCG_PROFILE_CHANGED", function() CF:SyncAll() end)
    self:SyncAll()
end

-- Yes/No confirmation for destructive buttons.
function CF:Confirm(text, onAccept)
    if not (StaticPopupDialogs and StaticPopup_Show) then return onAccept() end
    StaticPopupDialogs.TBCGUIDE_CONFIRM = {
        text = text, button1 = YES or "Yes", button2 = NO or "No",
        OnAccept = function() onAccept() CF:SyncAll() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("TBCGUIDE_CONFIRM")
end

-- A copyable link in a small popup (no web browser access from the game).
CF.ISSUES = "https://github.com/GREYsaurus/TBCGuide/issues"
function CF:ShowLink()
    if not StaticPopupDialogs then return ns:Print("Report issues at " .. self.ISSUES) end
    StaticPopupDialogs.TBCGUIDE_LINK = StaticPopupDialogs.TBCGUIDE_LINK or {
        text = "Copy this link (Ctrl+C) and open it in your web browser:",
        button1 = CLOSE or "Close",
        hasEditBox = true,
        editBoxWidth = 320,
        OnShow = function(s) local e = s.editBox or s.EditBox if e then e:SetText(CF.ISSUES) e:HighlightText() e:SetFocus() end end,
        EditBoxOnEscapePressed = function(e) e:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("TBCGUIDE_LINK")
end
