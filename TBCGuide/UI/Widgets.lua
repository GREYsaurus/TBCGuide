-- TBCGuide - shared UI helpers and the TBCGuide look (flat, dark, one accent colour)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Uses only stock client textures/fonts, so nothing proprietary is shipped. Every TBCGuide window
-- is built from these helpers, so the theme below is the one place to change colours.

local _, ns = ...

local W = {}
ns.Widgets = W

W.FLAT = "Interface\\Buttons\\WHITE8x8"

W.THEME = {
    bg       = { 0.055, 0.063, 0.078, 0.94 }, -- window background
    panel    = { 0.090, 0.100, 0.122, 0.96 }, -- inner boxes, title bars
    raised   = { 0.140, 0.152, 0.180, 1 },    -- buttons, inputs
    hover    = { 0.180, 0.196, 0.235, 1 },
    border   = { 0.200, 0.220, 0.265, 1 },
    accent   = { 0.300, 0.720, 0.980, 1 },    -- headers, selected tab, checks
    text     = { 0.920, 0.930, 0.950, 1 },
    muted    = { 0.600, 0.630, 0.680, 1 },
    disabled = { 0.400, 0.420, 0.460, 1 },
}
local T = W.THEME

W.BACKDROP = {
    bgFile = W.FLAT, edgeFile = W.FLAT, tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function color(tex, c, a)
    if tex.SetColorTexture then tex:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1)
    else tex:SetTexture(c[1], c[2], c[3], a or c[4] or 1) end
end
W.Color = color

-- Flat background + 1 px border. `bg` and `border` are theme keys (default "bg" / "border").
function W.Skin(f, bg, border)
    if not f.SetBackdrop then return f end
    f:SetBackdrop(W.BACKDROP)
    local b, e = T[bg or "bg"], T[border or "border"]
    f:SetBackdropColor(b[1], b[2], b[3], b[4])
    f:SetBackdropBorderColor(e[1], e[2], e[3], e[4])
    return f
end

function W.Panel(name, parent, w, h)
    local f = CreateFrame("Frame", name, parent or UIParent, ns.Compat.BackdropTemplate)
    f:SetSize(w or 300, h or 200)
    W.Skin(f)
    return f
end

-- Title strip across the top of a window: slightly lighter, accent line underneath, title text.
-- Returns the title font string (its height is W.TITLE_H).
W.TITLE_H = 26
function W.TitleBar(f, text)
    local bar = f:CreateTexture(nil, "BORDER")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(W.TITLE_H)
    color(bar, T.panel)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
    line:SetHeight(1)
    color(line, T.accent, 0.8)
    local fs = W.Text(f, "GameFontNormal", "LEFT")
    fs:SetPoint("LEFT", bar, "LEFT", 10, 0)
    fs:SetJustifyV("MIDDLE")
    fs:SetTextColor(T.text[1], T.text[2], T.text[3])
    fs:SetText(text or "")
    f.titleBar, f.titleText = bar, fs
    return fs
end

-- Makes a frame draggable and persists its position in ns.db.frames[key].
function W.Movable(f, key, handle)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    handle = handle or f
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() if not ns.db.profile.locked then f:StartMoving() end end)
    handle:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint()
        local rec = ns.db.frames[key] or {}
        rec.point, rec.x, rec.y = point, x, y
        ns.db.frames[key] = rec
    end)
    local pos = ns.db.frames[key]
    f:ClearAllPoints()
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER")
    end
end

-- Hover/press feedback through HookScript, so callers can still set their own OnEnter tooltips.
local function hoverBorder(f)
    f:HookScript("OnEnter", function(s)
        if s.IsEnabled and not s:IsEnabled() then return end
        if s.SetBackdropBorderColor then s:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 1) end
    end)
    f:HookScript("OnLeave", function(s)
        if s.SetBackdropBorderColor then s:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1) end
    end)
end

-- Flat button. Same API as a template button (SetText, Enable/Disable, OnClick).
function W.Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, ns.Compat.BackdropTemplate)
    b:SetSize(w or 60, h or 20)
    W.Skin(b, "raised")
    b:SetNormalFontObject("GameFontHighlightSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    color(hl, T.hover, 0.6)
    b:SetText(text)
    hoverBorder(b)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- Small square icon button using a stock texture path.
function W.IconButton(parent, texture, size, tooltip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 16, size or 16)
    b:SetNormalTexture(texture)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    if onClick then b:SetScript("OnClick", onClick) end
    if tooltip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end

function W.Text(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetJustifyV("TOP")
    return fs
end

-- Flat "x" close button in the top-right corner (inside a title bar when there is one).
function W.CloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(22, 22)
    b:SetPoint("TOPRIGHT", -3, -3)
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("CENTER", 0, 1)
    t:SetText("x")
    t:SetTextColor(T.muted[1], T.muted[2], T.muted[3])
    b:SetScript("OnEnter", function() t:SetTextColor(1, 0.35, 0.3) end)
    b:SetScript("OnLeave", function() t:SetTextColor(T.muted[1], T.muted[2], T.muted[3]) end)
    b:SetScript("OnClick", onClick or function() parent:Hide() end)
    return b
end

-- Flat checkbox: a bordered square with an accent fill when checked. Same API as
-- UICheckButtonTemplate for SetChecked/GetChecked/Enable/Disable/OnClick.
function W.Check(parent, size)
    size = size or 18
    local cb = CreateFrame("CheckButton", nil, parent, ns.Compat.BackdropTemplate)
    cb:SetSize(size, size)
    W.Skin(cb, "raised")
    local function inset(layer, c, a)
        local t = cb:CreateTexture(nil, layer)
        t:SetPoint("TOPLEFT", 4, -4)
        t:SetPoint("BOTTOMRIGHT", -4, 4)
        color(t, c, a)
        return t
    end
    cb:SetCheckedTexture(inset("ARTWORK", T.accent))
    cb:SetDisabledCheckedTexture(inset("ARTWORK", T.disabled))
    cb:SetHighlightTexture(inset("HIGHLIGHT", T.hover, 0.8))
    hoverBorder(cb)
    return cb
end

-- Flat single-line input.
function W.Input(parent, name, w, h)
    local e = CreateFrame("EditBox", name, parent, ns.Compat.BackdropTemplate)
    e:SetSize(w or 120, h or 20)
    W.Skin(e, "raised")
    e:SetFontObject("GameFontHighlightSmall")
    e:SetTextInsets(6, 6, 0, 0)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    e:HookScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 1) end)
    e:HookScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1) end)
    return e
end

-- Restyles an OptionsSliderTemplate slider: thin flat track, accent thumb, muted end labels.
function W.SkinSlider(s, name)
    if s.SetBackdrop then
        s:SetBackdrop({ bgFile = W.FLAT, edgeFile = W.FLAT, edgeSize = 1, insets = { left = 0, right = 0, top = 6, bottom = 6 } })
        s:SetBackdropColor(T.raised[1], T.raised[2], T.raised[3], 1)
        s:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if s.SetThumbTexture then
        s:SetThumbTexture(W.FLAT)
        local th = s.GetThumbTexture and s:GetThumbTexture()
        if th then th:SetSize(10, 16) color(th, T.accent) end
    end
    for _, suffix in ipairs({ "Low", "High" }) do
        local fs = name and _G[name .. suffix]
        if fs and fs.SetTextColor then fs:SetTextColor(T.muted[1], T.muted[2], T.muted[3]) end
    end
end

-- Flat tab: text plus an accent underline when selected (tab:SetSelected(bool)).
function W.Tab(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 90, h or 26)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER", 0, 1)
    fs:SetText(text)
    b.label = fs
    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 6, 0)
    line:SetPoint("BOTTOMRIGHT", -6, 0)
    line:SetHeight(2)
    color(line, T.accent)
    b.underline = line
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    color(hl, T.hover, 0.5)
    function b:SetSelected(on)
        self.selected = on and true or false
        if on then self.underline:Show() self.label:SetTextColor(T.accent[1], T.accent[2], T.accent[3])
        else self.underline:Hide() self.label:SetTextColor(T.muted[1], T.muted[2], T.muted[3]) end
    end
    b:SetSelected(false)
    return b
end

-- Section header: accent text, left aligned, with a thin line to the right.
function W.Section(parent, text)
    local fs = W.Text(parent, "GameFontNormal", "LEFT")
    fs:SetText(text)
    fs:SetTextColor(T.accent[1], T.accent[2], T.accent[3])
    local l = parent:CreateTexture(nil, "ARTWORK")
    l:SetHeight(1)
    color(l, T.border)
    l:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    return fs, l
end

-- Scroll frame with a content child; returns scroll, content.
function W.Scroll(parent, name)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)
    W.SkinScroll(scroll, name)
    return scroll, content
end

-- Thin accent thumb on a UIPanelScrollFrameTemplate scroll bar (the arrow buttons stay).
function W.SkinScroll(scroll, name)
    local bar = scroll.ScrollBar
    if type(bar) ~= "table" then bar = name and _G[name .. "ScrollBar"] end
    if type(bar) ~= "table" then return end
    local thumb = bar.ThumbTexture
    if type(thumb) ~= "table" then thumb = name and _G[name .. "ScrollBarThumbTexture"] end
    if type(thumb) == "table" and thumb.SetTexture then
        thumb:SetTexture(W.FLAT)
        if thumb.SetSize then thumb:SetSize(6, 28) end
        color(thumb, T.accent, 0.8)
    end
end

function W.Dropdown(parent, name, width, getItems, onSelect, getLabel)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, width or 120)
    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, item in ipairs(getItems()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.checked = item.checked
            info.func = function()
                onSelect(item.value)
                UIDropDownMenu_SetText(dd, item.text)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    if getLabel then UIDropDownMenu_SetText(dd, getLabel()) end
    return dd
end
