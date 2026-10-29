-- TBCGuide - bag add-on adapters for the BoE upgrade and junk markers
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Each adapter only tells UI/GearMarkers.lua which buttons belong to the player's bags and which
-- bag/slot each one shows; evaluation, junk rules and drawing stay in one place. Optional: an
-- adapter does nothing unless its add-on is loaded. Hooks are post-hooks (hooksecurefunc) or the
-- add-on's own module messages; nothing of theirs is replaced.
--
--   Bagnon 12.1.7 (BagBrother core; TOC lists interface 20506): post-hook on the shared item class
--     BagBrother.ContainerItem:Update. Read from the installed add-on's source.
--   AdiBags 1.10.29 (read from the release; its TBC TOC says interface 20504, so on a 20506 client it
--     may need "Load out of date AddOns"): an AdiBags module listening to the "AdiBags_UpdateButton"
--     message its own modules use (buttons carry .bag/.slot and :IsBank()).
--   Baganator 839 (read from the release; TOC lists 20506): its public plugin API -
--     RegisterCornerWidget for the BoE upgrade arrow (the widget knows its button: bag =
--     button:GetParent():GetID(), slot = button:GetID()) and RegisterJunkPlugin, which hands us
--     bag/slot/itemID, for its own junk coin. RequestItemButtonsRefresh after our marks change.

local _, ns = ...

local BA = { active = {} }
ns.BagAdapters = BA

local function own(bag) return type(bag) == "number" and bag >= 0 and bag <= ns.Compat.NUM_BAGS end

-- Bagnon ---------------------------------------------------------------------------------------------
-- Buttons: b.bag (bag id), b:GetID() (slot), b:IsCached() (true for offline characters).
function BA.BagnonResolve(b)
    local bag = b.bag
    if not own(bag) then return nil end
    if b.IsCached and b:IsCached() then return nil end
    return bag, b:GetID()
end

function BA:Bagnon()
    local core = _G.BagBrother
    local cls = type(core) == "table" and core.ContainerItem
    if self.active.Bagnon or type(cls) ~= "table" or type(cls.Update) ~= "function" or not hooksecurefunc then return false end
    hooksecurefunc(cls, "Update", function(b) ns.GearMarkers:RegisterButton(b, BA.BagnonResolve) end)
    self.active.Bagnon = true
    return true
end

-- AdiBags ---------------------------------------------------------------------------------------------
-- Buttons: b.bag, b.slot; bank buttons answer b:IsBank().
function BA.AdiResolve(b)
    if b.IsBank and b:IsBank() then return nil end
    if not own(b.bag) then return nil end
    return b.bag, b.slot
end

function BA:AdiBags()
    if self.active.AdiBags then return false end
    local ace = LibStub and LibStub("AceAddon-3.0", true)
    local adi = ace and ace:GetAddon("AdiBags", true)
    if not (adi and adi.NewModule) then return false end
    local ok, mod = pcall(adi.NewModule, adi, "TBCGuideMarkers", "ABEvent-1.0")
    if not ok or not mod then return false end
    mod.uiName = "TBCGuide markers"
    mod.uiDesc = "BoE upgrade and junk markers from TBCGuide."
    function mod:OnEnable()
        self:RegisterMessage("AdiBags_UpdateButton", function(_, b) ns.GearMarkers:RegisterButton(b, BA.AdiResolve) end)
    end
    -- Created after AdiBags enabled its modules: enable ours now.
    if adi.IsEnabled and adi:IsEnabled() and mod.Enable then pcall(mod.Enable, mod) end
    self.active.AdiBags = true
    return true
end

-- Baganator -------------------------------------------------------------------------------------------
-- Live bag buttons: bag = parent:GetID(), slot = button:GetID(). Bank and other characters' views
-- use other bag ids or another character's items; the item id check in GearMarkers covers the rest.
function BA.BaganatorResolve(b)
    local parent = b.GetParent and b:GetParent()
    local bag = parent and parent.GetID and parent:GetID()
    if not own(bag) then return nil end
    return bag, b:GetID()
end

function BA:Baganator()
    local B = _G.Baganator
    local api = type(B) == "table" and B.API
    if self.active.Baganator or type(api) ~= "table" or type(api.RegisterCornerWidget) ~= "function" then return false end
    local ok = pcall(api.RegisterCornerWidget, "TBCGuide: BoE upgrade", "tbcguide_boe_upgrade",
        -- true = show, false = hide, nil = not known yet (Baganator asks again later)
        function(widget, details)
            local b = widget.tbcgButton
            local parent = b and b.GetParent and b:GetParent()
            local bag = parent and parent.GetID and parent:GetID()
            local slot = b and b.GetID and b:GetID()
            if not (type(bag) == "number" and bag >= 0 and bag <= ns.Compat.NUM_BAGS and slot) then return false end
            local e = ns.GearMarkers.marks[bag .. ":" .. slot]
            if not e then return false end
            return e.item.id == (details and details.itemID) and ns.GearMarkers:Qualifies(e)
        end,
        function(itemButton)
            ns.GearMarkers.tipOnly[itemButton] = BA.BaganatorResolve
            local t = itemButton:CreateTexture(nil, "OVERLAY")
            t:SetTexture(ns.GearMarkers.ICON)
            t:SetSize(14, 14)
            t.tbcgButton = itemButton
            return t
        end,
        { corner = "top_left", priority = 1 })
    if type(api.RegisterJunkPlugin) == "function" then
        pcall(api.RegisterJunkPlugin, "TBCGuide", "tbcguide", function(bag, slot)
            if not (type(bag) == "number" and bag >= 0 and bag <= ns.Compat.NUM_BAGS) then return nil end
            return ns.Vendor:IsJunkAt(bag, slot)
        end)
    end
    self.active.Baganator = ok and true or nil
    return ok
end

-- Ask bag add-ons that cache their own button state to redraw after our marks changed.
function BA:Refresh()
    local B = _G.Baganator
    if self.active.Baganator and type(B) == "table" and B.API and B.API.RequestItemButtonsRefresh then
        local reason = B.Constants and B.Constants.RefreshReason and B.Constants.RefreshReason.ItemWidgets
        pcall(B.API.RequestItemButtonsRefresh, reason and { reason } or nil)
    end
end

function BA:TryAll()
    self:Bagnon()
    self:AdiBags()
    self:Baganator()
end

function BA:Init()
    self:TryAll()
    ns:On("ADDON_LOADED", function(_, name)
        if name == "BagBrother" or name == "Bagnon" or name == "AdiBags" or name == "Baganator" then BA:TryAll() end
    end)
end
