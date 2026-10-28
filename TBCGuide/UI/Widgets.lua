-- TBCGuide - shared UI helpers
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Uses only stock client textures/fonts, so nothing proprietary is shipped.

local _, ns = ...

local W = {}
ns.Widgets = W

W.BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function W.Panel(name, parent, w, h)
    local f = CreateFrame("Frame", name, parent or UIParent, ns.Compat.BackdropTemplate)
    f:SetSize(w or 300, h or 200)
    if f.SetBackdrop then
        f:SetBackdrop(W.BACKDROP)
        f:SetBackdropColor(0.05, 0.05, 0.08, 0.88)
        f:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    end
    return f
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

function W.Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 60, h or 20)
    b:SetText(text)
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

function W.CloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    b:SetPoint("TOPRIGHT", 2, 2)
    b:SetScript("OnClick", onClick or function() parent:Hide() end)
    return b
end

-- Scroll frame with a content child; returns scroll, content.
function W.Scroll(parent, name)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)
    return scroll, content
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
