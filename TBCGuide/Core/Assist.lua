-- TBCGuide - convenience features behind the settings window (UI/Config.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Every feature here is gated by its own profile setting and does nothing when it is off:
--   frames      showAllFrames / hideWindow / autohideRaid gate the guide window and the arrow
--   NPCs        trainerAuto, flightAuto, skipGossip (hold Shift to skip once); bindAuto is Core/Bind.lua
--   targeting   targetMacro (a "TBCGuide" macro), targetNotify, maxNameplateDistance (CVar)
--   group chat  announceLevelEmote / Party / Guild on level-up
--   tips        drowning and low-health warnings, rare-mob alerts
--   junk        junk list (modifier + right-click in bags), delete cheapest junk (key binding),
--               discard junk when the bags are full, on the next click or key press (docs/SETTINGS.md)
--   misc        world map button, Lua error display (CVar), add-on conflict check
-- Nothing here equips items, spends money (except trainerAuto, which is opt-in) or acts in combat
-- where that could matter.

local _, ns = ...

local A = { notified = {}, rareSeen = {}, warned = {} }
ns.Assist = A

local C
local function prof() return ns.db.profile end
local function shiftHeld() return C and C.IsModifierHeld and C.IsModifierHeld() end
local function inCombat() return InCombatLockdown and InCombatLockdown() or false end

-- Frames ---------------------------------------------------------------------------------------------

function A:InRaid() return (IsInRaid and IsInRaid()) or false end
function A:InGroup()
    if IsInGroup then return IsInGroup() and true or false end
    return (GetNumGroupMembers and GetNumGroupMembers() or 0) > 0
end

-- Whether the guide window and the arrow may be shown at all.
function A:FramesAllowed()
    local p = prof()
    if not p.showAllFrames or p.hideWindow then return false end
    if p.autohideRaid and self:InRaid() then return false end
    return true
end

function A:ApplyFrames()
    local mf = ns.MainFrame and ns.MainFrame.frame
    if mf then mf:SetShown(ns.db.frames.main.shown ~= false and self:FramesAllowed()) end
    local nav = ns.Nav
    if nav and nav.arrow then
        ns.Widgets.Rescale(nav.arrow, "arrow", prof().arrowScale or 1)
        nav.arrow:SetShown(prof().showArrow and nav.target ~= nil and self:FramesAllowed())
    end
    if self.mapButton then self.mapButton:SetShown(prof().worldMapButton and true or false) end
end

-- NPC automation -------------------------------------------------------------------------------------

local function currentStep() return ns.Engine and ns.Engine:CurrentStep() end

-- Learns the first affordable spell the trainer offers; TRAINER_UPDATE brings the next one.
function A:TrainerStep()
    if not prof().trainerAuto or shiftHeld() then return end
    if not (GetNumTrainerServices and GetTrainerServiceInfo and BuyTrainerService) then return end
    local money = GetMoney and GetMoney() or 0
    for i = 1, GetNumTrainerServices() or 0 do
        local name, _, kind = GetTrainerServiceInfo(i)
        if kind == "available" then
            local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
            if cost <= money then
                BuyTrainerService(i)
                ns:Debug("trainer: learned " .. tostring(name))
                return true
            end
        end
    end
end

-- Flies to the current fly step's destination when the flight map opens.
function A:OnTaxiMap()
    local s = currentStep()
    if not (prof().flightAuto and s and s[1] == "fly" and s.dest) or shiftHeld() then return end
    if not (NumTaxiNodes and TaxiNodeName and TakeTaxiNode) then return end
    local want = string.lower(s.dest)
    for i = 1, NumTaxiNodes() or 0 do
        local name = TaxiNodeName(i)
        local kind = TaxiNodeGetType and TaxiNodeGetType(i)
        if type(name) == "string" and (kind == nil or kind == "REACHABLE")
            and string.find(string.lower(name), want, 1, true) then
            ns:Print("Flying to " .. name .. " (flight path automation; hold Shift to choose yourself).")
            TakeTaxiNode(i)
            return true
        end
    end
end

-- Gossip options as { {name=, type=, id=} } for both the modern and the legacy API.
function A:GossipOptions()
    local out = {}
    local get = C_GossipInfo and C_GossipInfo.GetOptions
    if get then
        for i, o in ipairs(get() or {}) do
            out[#out + 1] = { name = o.name, type = o.type, icon = o.icon, id = o.gossipOptionID or i, modern = true }
        end
        return out
    end
    if GetGossipOptions then
        local raw = { GetGossipOptions() }
        for i = 1, #raw, 2 do out[#out + 1] = { name = raw[i], type = raw[i + 1], id = (i + 1) / 2 } end
    end
    return out
end

local function selectOption(o)
    if o.modern and C_GossipInfo and C_GossipInfo.SelectOption then C_GossipInfo.SelectOption(o.id)
    elseif SelectGossipOption then SelectGossipOption(o.id) end
end
function A:SelectGossipOption(o) selectOption(o) end

local function gossipQuestCount()
    local n = 0
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
        n = #(C_GossipInfo.GetAvailableQuests() or {}) + #(C_GossipInfo.GetActiveQuests() or {})
    elseif GetNumGossipAvailableQuests then
        n = (GetNumGossipAvailableQuests() or 0) + (GetNumGossipActiveQuests and GetNumGossipActiveQuests() or 0)
    end
    return n
end

-- Hearthstone binding (Core/Bind.lua) goes first; Skip Gossip never touches a bind option or an NPC
-- with quests, and stays out while a bind is pending.
function A:OnGossip()
    if shiftHeld() then return end
    if ns.Bind:OnGossip() then return "bind" end
    local opts = self:GossipOptions()
    local only = opts[1]
    if prof().skipGossip and #opts == 1 and not ns.Bind.pending and not ns.Bind:IsBinder(only)
        and gossipQuestCount() == 0 then
        selectOption(only)
        return "skip"
    end
end

-- Targeting --------------------------------------------------------------------------------------------

-- NPC ids the current step is about: explicit [mark] NPCs, kill objectives, quest giver / finisher.
function A:StepNpcIds()
    local s = currentStep()
    local ids = {}
    if not s then return ids end
    if type(s.mark) == "table" and s.mark.npcs then for _, id in ipairs(s.mark.npcs) do ids[id] = true end end
    local q = s.q and ns.DB.GetQuestByID(s.q)
    if q then
        if s[1] == "complete" then
            for _, id in ipairs(q.objectives.creatures) do ids[id] = true end
            for _, id in ipairs(q.objectives.killCredit) do ids[id] = true end
        elseif s[1] == "accept" then
            for _, id in ipairs(q.startNpcs or {}) do ids[id] = true end
        elseif s[1] == "turnin" then
            for _, id in ipairs(q.endNpcs or {}) do ids[id] = true end
        end
    end
    return ids
end

-- "/cleartarget" plus one "/tar <name>" per NPC name, within the 255-character macro limit.
function A:MacroBody()
    local names, seen = {}, {}
    for id in pairs(self:StepNpcIds()) do
        local n = ns.DB.GetNPCName(id)
        if n and not seen[n] then seen[n] = true names[#names + 1] = n end
    end
    table.sort(names)
    local body = "/cleartarget"
    for _, n in ipairs(names) do
        local line = "\n/tar " .. n
        if #body + #line > 255 then break end
        body = body .. line
    end
    return body, #names
end

A.MACRO = "TBCGuide"

function A:UpdateMacro()
    if not prof().targetMacro or not (GetMacroIndexByName and CreateMacro and EditMacro) then return end
    if inCombat() then self.macroPending = true return end
    self.macroPending = nil
    local body, n = self:MacroBody()
    if body == self.lastBody then return end
    self.lastBody = body
    local idx = GetMacroIndexByName(self.MACRO) or 0
    if idx == 0 then
        local count = GetNumMacros and GetNumMacros() or 0
        if count >= (MAX_ACCOUNT_MACROS or 36) then return end
        CreateMacro(self.MACRO, "INV_MISC_MAP_01", body, nil)
        ns:Print("Created the 'TBCGuide' macro: it targets the current step's NPCs. Drag it from the Macros window (General tab) to an action bar.")
    else
        EditMacro(idx, nil, nil, body)
    end
    if n > 0 and prof().targetNotify then ns:Debug("targeting macro updated (" .. n .. " NPCs)") end
end

-- First sighting of a current-step NPC (nameplate or target): one chat note per NPC id per step.
function A:OnUnitSeen(unit)
    local id, guid = C.UnitNpcId(unit)
    if not id then return end
    local p = prof()
    if p.targetNotify and not self.notified[id] and self:StepNpcIds()[id] then
        self.notified[id] = true
        ns:Print("|cff66ccff" .. tostring(UnitName and UnitName(unit) or id) .. "|r from your current step is nearby.")
    end
    if p.tipsEnabled and p.trackRares and guid and not self.rareSeen[guid] then
        local npc = ns.DB.GetNPCByID(id)
        if npc and (npc.rank == 2 or npc.rank == 4) and not (p.skipKilledRares and ns.char.killedRares[id]) then
            self.rareSeen[guid] = true
            ns:Print("|cffff7744Rare:|r " .. tostring(npc.name) .. " is nearby.")
            if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING) end
        end
    end
end

function A:OnUnitDied(guid)
    if type(guid) ~= "string" then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    id = tonumber(id)
    if kind ~= "Creature" or not id then return end
    local npc = ns.DB.GetNPCByID(id)
    if npc and (npc.rank == 2 or npc.rank == 4) and self.rareSeen[guid] then ns.char.killedRares[id] = true end
end

-- Nameplates are visible out to 20 yards by default; 41 is the client maximum in TBC.
function A:ApplyNameplateDistance()
    if not (GetCVar and SetCVar) then return end
    local on = prof().maxNameplateDistance
    local cur = tonumber(GetCVar("nameplateMaxDistance"))
    if on and cur ~= 41 then
        if cur and cur ~= 41 then ns.db.nameplatePrev = cur end
        SetCVar("nameplateMaxDistance", 41)
    elseif not on and cur == 41 and ns.db.nameplatePrev then
        SetCVar("nameplateMaxDistance", ns.db.nameplatePrev)
        ns.db.nameplatePrev = nil
    end
end

function A:LuaErrors(on)
    if on == nil then return GetCVar and GetCVar("scriptErrors") == "1" end
    if SetCVar then SetCVar("scriptErrors", on and "1" or "0") end
end

-- Announcements ---------------------------------------------------------------------------------------

function A:OnLevelUp(level)
    local p = prof()
    if not SendChatMessage then return end
    local msg = "reached level " .. tostring(level) .. "!"
    if p.announceLevelEmote then SendChatMessage(msg, "EMOTE") end
    if p.announceLevelParty and self:InGroup() and not self:InRaid() then SendChatMessage("I " .. msg, "PARTY") end
    if p.announceLevelGuild and IsInGuild and IsInGuild() then SendChatMessage("I " .. msg, "GUILD") end
end

-- Warnings --------------------------------------------------------------------------------------------

local function flash()
    local f = A.flash
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetAllPoints(UIParent)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        local t = f:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetTexture("Interface\\FullScreenTextures\\LowHealth")
        t:SetBlendMode("ADD")
        f.tex = t
        f:Hide()
        A.flash = f
    end
    f.left = 1.2
    f:SetAlpha(1)
    f:Show()
    f:SetScript("OnUpdate", function(self, el)
        self.left = self.left - el
        self:SetAlpha(math.max(0, self.left / 1.2))
        if self.left <= 0 then self:Hide() self:SetScript("OnUpdate", nil) end
    end)
end

local function warn(text, sound)
    local frame = RaidWarningFrame or UIErrorsFrame
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo.RAID_WARNING)
    elseif frame and frame.AddMessage then
        frame:AddMessage(text, 1, 0.3, 0.2)
    end
    if sound and PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING) end
end

-- Breath: called while a BREATH mirror timer runs. `remaining`/`max` in milliseconds.
function A:CheckBreath(remaining, max)
    local p = prof()
    if not (p.tipsEnabled and p.drownWarn) or not remaining or not max or max <= 0 then return end
    local pct = remaining / max * 100
    if pct <= (p.drownThreshold or 20) then
        if not self.warned.breath then
            self.warned.breath = true
            warn("TBCGuide: you are running out of breath - surface now!", p.drownSound)
            if p.drownFlash then flash() end
            return true
        end
    else
        self.warned.breath = nil
    end
end

function A:CheckHealth()
    local p = prof()
    if not (p.tipsEnabled and p.lowHealthWarn) or not UnitHealth then return end
    local hp, max = UnitHealth("player"), UnitHealthMax and UnitHealthMax("player") or 0
    if not hp or max <= 0 or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return end
    local pct = hp / max * 100
    if pct <= (p.lowHealthThreshold or 20) then
        if not self.warned.health then
            self.warned.health = true
            warn("TBCGuide: low health - heal, eat, use a potion or get out!", p.lowHealthAnim)
            if p.lowHealthFlash then flash() end
            return true
        end
    elseif pct > (p.lowHealthThreshold or 20) + 10 then
        self.warned.health = nil
    end
end

function A:OnMirrorTimer(timer, value, max)
    if timer ~= "BREATH" then return end
    self.breathMax = max
    if not self.breathTicker then
        local f = CreateFrame("Frame")
        local acc = 0
        f:SetScript("OnUpdate", function(_, el)
            acc = acc + el
            if acc < 0.25 then return end
            acc = 0
            local left = GetMirrorTimerProgress and GetMirrorTimerProgress("BREATH")
            if left then A:CheckBreath(left, A.breathMax) end
        end)
        self.breathTicker = f
    end
    self.breathTicker:Show()
    self:CheckBreath(value, max)
end

function A:OnMirrorStop(timer)
    if timer == "BREATH" then
        self.warned.breath = nil
        if self.breathTicker then self.breathTicker:Hide() end
    end
end

-- Junk ------------------------------------------------------------------------------------------------

function A:FreeSlots()
    local n = 0
    for bag = 0, C.NUM_BAGS do
        local f = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
        n = n + (f and (f(bag)) or 0)
    end
    return n
end

-- Discarding junk -------------------------------------------------------------------------------------
-- The client only lets an add-on destroy an item from inside a click or key press: DeleteCursorItem
-- is restricted on every Classic-engine client (TBC 2.5 included) to a hardware event, one item per
-- event, and is refused when called from an event handler. So:
--   * "Discard junk if bag is full": when the bags are full, the junk item worth least at a vendor is
--     armed, and destroyed on the player's next click on the game world, key press or loot click
--     (hooks in A:HookInput; those are real hardware events, nothing is simulated).
--   * The "Delete cheapest junk item" key does the same on demand.
-- Junk is decided by Vendor:Classify (grey or on the junk list; never quest, quest-starting,
-- guide-needed, protected or item-data-missing items). Every attempt re-reads the slot and re-checks
-- all of that, one item per input. Failures are not retried; success is only reported once the bag
-- update confirms it.

A.discardFailed = {}   -- ["bag:slot:itemID"] = true: failed once this session; not offered again

local function junkKey(e) return e.bag .. ":" .. e.slot .. ":" .. tostring(e.itemID) end

-- Why junk cannot be touched right now, or nil.
function A:JunkBusy()
    if not prof().inventoryManager then return "the inventory manager is off" end
    if inCombat() then return "in combat" end
    local w = ns.AutoEquip and ns.AutoEquip.windows
    if w and next(w) then return "a merchant, trade, bank, mail or auction window is open" end
    if C.CursorHasItem() then return "your cursor is holding an item" end
    if self.discardPending then return "waiting for the last discard to finish" end
    return nil
end

-- The junk stack worth least at a vendor (ties: first bag slot), skipping ones that failed before.
function A:CheapestJunk()
    local list = ns.Vendor:Scan()
    table.sort(list, function(x, y)
        if x.value ~= y.value then return x.value < y.value end
        if x.bag ~= y.bag then return x.bag < y.bag end
        return x.slot < y.slot
    end)
    for _, e in ipairs(list) do
        if not self.discardFailed[junkKey(e)] then return e end
    end
    return nil
end

-- Destroys junk candidate `e`. Call only from a click or key handler (the client needs one).
function A:DiscardJunk(e)
    if not e then return false, "no junk" end
    local busy = self:JunkBusy()
    if busy then return false, busy end
    local cur = C.GetContainerItem(e.bag, e.slot)
    if not cur or cur.itemID ~= e.itemID or (cur.count or 1) ~= (e.count or 1) then return false, "the item moved" end
    if cur.locked then return false, "the item is locked" end
    if ns.Vendor:IsJunkAt(e.bag, e.slot) ~= true then return false, "no longer junk, or its item data is not loaded" end
    local pick = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
    if not (pick and DeleteCursorItem) then return false, "unsupported" end
    pick(e.bag, e.slot)
    local kind, cid
    if GetCursorInfo then kind, cid = GetCursorInfo() end
    if not C.CursorHasItem() or (GetCursorInfo and (kind ~= "item" or cid ~= e.itemID)) then
        if C.CursorHasItem() then ClearCursor() end -- only ever what this function just picked up
        self.discardFailed[junkKey(e)] = true
        return false, "could not pick up the item"
    end
    DeleteCursorItem()
    if C.CursorHasItem() then
        ClearCursor() -- refused: the item goes back to its slot
        self.discardFailed[junkKey(e)] = true
        return false, "the game refused to destroy it (it only allows this from a click or key press)"
    end
    self.discardPending = { e = e, at = GetTime and GetTime() or 0 }
    C_Timer.After(2, function() A:VerifyDiscard(true) end)
    self.discardTarget = nil
    return true
end

-- Confirms the last discard from the bag contents; reports it only then.
function A:VerifyDiscard(timeout)
    local p = self.discardPending
    if not p then return end
    local cur = C.GetContainerItem(p.e.bag, p.e.slot)
    if cur and cur.itemID == p.e.itemID then
        if not timeout then return end -- the bag update may not have arrived yet
        self.discardFailed[junkKey(p.e)] = true
        self.discardPending = nil
        ns:Print("Could not destroy " .. tostring(p.e.link) .. "; it is still in your bags.")
    else
        self.discardPending = nil
        ns:Print(string.format("Destroyed (not sold): %s x%d.", tostring(p.e.link), p.e.count or 1))
    end
    self:UpdateDiscardTarget()
end

-- Keybind / slash: destroy the cheapest junk item (one per key press).
function A:DeleteCheapestJunk(quiet)
    local busy = self:JunkBusy()
    if busy then
        if not quiet then ns:Print("Junk not destroyed: " .. busy .. ".") end
        return false, busy
    end
    local e = self:CheapestJunk()
    if not e then
        if not quiet then ns:Print("No junk to delete.") end
        return false, "no junk"
    end
    local ok, why = self:DiscardJunk(e)
    if not ok and not quiet then ns:Print("Junk not destroyed: " .. tostring(why) .. ".") end
    return ok, why
end

-- Arms the full-bags discard: the cheapest junk item, or nil when off, bags not full or a discard is
-- still being confirmed.
function A:UpdateDiscardTarget()
    local p = prof()
    local e
    if p.discardJunkFull and p.inventoryManager and not self.discardPending and self:FreeSlots() == 0 then
        e = self:CheapestJunk()
    end
    self.discardTarget = e
    return e
end

-- Called from every hooked click and key press. Cheap when nothing is armed.
function A:OnHardwareInput()
    local e = self.discardTarget
    if not e then return end
    local p = prof()
    if not (p.discardJunkFull and p.inventoryManager) or self:FreeSlots() > 0 then self.discardTarget = nil return end
    if self:JunkBusy() then return end -- stays armed for a later input
    self.discardTarget = nil
    local ok, why = self:DiscardJunk(e)
    if not ok and self.discardFailed[junkKey(e)] then ns:Print("Junk not destroyed: " .. tostring(why) .. ".") end
    return ok
end

-- Hooks the player's own input: clicks on the game world, key presses (passed on to the game
-- untouched) and loot button clicks.
function A:HookInput()
    if self.inputHooked or not CreateFrame then return end
    if inCombat() then self.inputPending = true return end
    self.inputHooked, self.inputPending = true, nil
    local run = function() A:OnHardwareInput() end
    if WorldFrame and WorldFrame.HookScript then
        WorldFrame:HookScript("OnMouseDown", run)
        WorldFrame:HookScript("OnMouseUp", run)
    end
    local f = CreateFrame("Frame", "TBCGuideJunkInput", UIParent)
    if f.SetPropagateKeyboardInput then -- without it, a key script would swallow the player's keys
        f:SetPropagateKeyboardInput(true)
        f:SetScript("OnKeyDown", run)
        f:SetScript("OnKeyUp", run)
    end
    self.inputFrame = f
    for i = 1, 10 do
        local b = _G["LootButton" .. i]
        if b and b.HookScript then b:HookScript("OnClick", run) end
    end
end

function A:OnBagsChanged()
    if self.discardPending then self:VerifyDiscard(false) end
    self:UpdateDiscardTarget()
end

local MODS = {
    CTRL = function() return IsControlKeyDown and IsControlKeyDown() end,
    ALT = function() return IsAltKeyDown and IsAltKeyDown() end,
    SHIFT = function() return IsShiftKeyDown and IsShiftKeyDown() end,
}

-- Marks or unmarks a bag item as junk (sold and deleted like grey items).
function A:ToggleJunk(itemID)
    if not itemID then return end
    local list = ns.db.junkList
    list[itemID] = not list[itemID] or nil
    local info = C.GetItemInfo(itemID)
    ns:Print((info and info.name or ("item " .. itemID)) .. (list[itemID] and " is now on your junk list." or " was removed from your junk list."))
    return list[itemID] == true
end

function A:OnBagItemClick(button, mouse)
    local p = prof()
    if mouse ~= "RightButton" or not (p.inventoryManager and p.junkModifierToggle) then return end
    local held = MODS[p.junkModifier or "CTRL"]
    if not (held and held()) then return end
    local bag, slot = button:GetParent() and button:GetParent():GetID(), button:GetID()
    local item = bag and slot and C.GetContainerItem(bag, slot)
    if item then return self:ToggleJunk(item.itemID) end
end

function A:ResetJunkList()
    wipe(ns.db.junkList)
    ns:Print("Junk list cleared.")
end

A.BINDING = "TBCGUIDE_DELETEJUNK"
function A:JunkKey() return GetBindingKey and GetBindingKey(self.BINDING) or nil end
function A:SetJunkKey(key)
    if not (SetBinding and SaveBindings) or inCombat() then return false end
    local old = self:JunkKey()
    if old then SetBinding(old) end
    if key then SetBinding(key, self.BINDING) end
    SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
    return true
end

-- World map button --------------------------------------------------------------------------------------

function A:CreateMapButton()
    if self.mapButton or not WorldMapFrame then return end
    local b = CreateFrame("Button", "TBCGuideWorldMapButton", WorldMapFrame)
    b:SetSize(28, 28)
    b:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -60, -28)
    b:SetFrameStrata("HIGH")
    b:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    b:SetScript("OnClick", function() ns.Browser:Toggle() end)
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine("TBCGuide")
        GameTooltip:AddLine("Click to open the guide browser.", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.mapButton = b
end

-- Conflicts ----------------------------------------------------------------------------------------------

A.CONFLICTS = { "RXPGuides", "ZygorGuidesViewerClassic", "ZygorGuidesViewerTBC", "TourGuide", "Guidelime", "AzerothAutoPilot" }

function A:Conflicts()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local out = {}
    if not loaded then return out end
    for _, name in ipairs(self.CONFLICTS) do
        if loaded(name) then out[#out + 1] = name end
    end
    return out
end

function A:CheckConflicts()
    if not prof().checkConflicts then return end
    local list = self:Conflicts()
    if #list > 0 then
        ns:Print("|cffff7744Other leveling guide add-ons are loaded:|r " .. table.concat(list, ", ")
            .. ". They may accept quests, mark targets or move the arrow too. Turn this check off in Advanced Settings.")
    end
end

-- Init ------------------------------------------------------------------------------------------------

function A:Init()
    C = ns.Compat
    ns:On("GROUP_ROSTER_UPDATE", function() A:ApplyFrames() end)
    ns:On("RAID_ROSTER_UPDATE", function() A:ApplyFrames() end)
    ns:On("TRAINER_SHOW", function() C_Timer.After(0.2, function() A:TrainerStep() end) end)
    ns:On("TRAINER_UPDATE", function() C_Timer.After(0.2, function() A:TrainerStep() end) end)
    ns:On("TAXIMAP_OPENED", function() A:OnTaxiMap() end)
    ns:On("GOSSIP_SHOW", function() A:OnGossip() end)
    ns:On("NAME_PLATE_UNIT_ADDED", function(_, unit) if unit then A:OnUnitSeen(unit) end end)
    ns:On("PLAYER_TARGET_CHANGED", function() A:OnUnitSeen("target") end)
    ns:On("PLAYER_LEVEL_UP", function(_, level) A:OnLevelUp(level) end)
    ns:On("UNIT_HEALTH", function(_, unit) if unit == "player" then A:CheckHealth() end end)
    ns:On("MIRROR_TIMER_START", function(_, timer, value, max) A:OnMirrorTimer(timer, value, max) end)
    ns:On("MIRROR_TIMER_STOP", function(_, timer) A:OnMirrorStop(timer) end)
    ns:On("BAG_UPDATE_DELAYED", function() ns:Throttle("junk-discard", 0.3, function() A:OnBagsChanged() end) end)
    ns:On("UI_ERROR_MESSAGE", function(_, _, msg)
        if msg and (msg == ERR_INV_FULL or msg == INVENTORY_FULL) then A:UpdateDiscardTarget() end
    end)
    ns:On("PLAYER_REGEN_ENABLED", function() if A.inputPending then A:HookInput() end end)
    ns:On("PLAYER_REGEN_ENABLED", function() if A.macroPending then A:UpdateMacro() end end)
    ns:On("COMBAT_LOG_EVENT_UNFILTERED", function()
        if not CombatLogGetCurrentEventInfo then return end
        local _, sub, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
        if sub == "UNIT_DIED" then A:OnUnitDied(destGUID) end
    end)
    ns:Listen("TBCG_STEP_CHANGED", function() wipe(A.notified) A:UpdateMacro() end)
    ns:Listen("TBCG_PROFILE_CHANGED", function() A:ApplyFrames() A:ApplyNameplateDistance() end)
    if hooksecurefunc and ContainerFrameItemButton_OnModifiedClick then
        hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(btn, mouse) A:OnBagItemClick(btn, mouse) end)
    end
    self:CreateMapButton()
    self:HookInput()
    self:ApplyFrames()
    self:ApplyNameplateDistance()
    self:CheckConflicts()
    ns:Listen("TBCG_GUIDE_CHANGED", function() A:Preload() end)
    C_Timer.After(5, function() A:Preload() end)
end

-- Pre load all data: ask the client for the item data the current guide's quests use (objective and
-- quest-starting items) and your bag items, a few per frame, so tooltips and scoring never wait.
function A:Preload()
    if not prof().preloadData then return end
    local ids, seen = {}, {}
    local function add(id) if id and not seen[id] then seen[id] = true ids[#ids + 1] = id end end
    local g = ns.Engine and ns.Engine.guide
    for _, s in ipairs(g and g.steps or {}) do
        if s.q then for _, id in ipairs(ns.DB.GetQuestItems(s.q) or {}) do add(id) end end
    end
    for bag = 0, C.NUM_BAGS do
        for slot = 1, C.GetContainerNumSlots(bag) do
            local it = C.GetContainerItem(bag, slot)
            add(it and it.itemID)
        end
    end
    local req = C.Has("C_Item.RequestLoadItemDataByID")
    local info = C.Has("C_Item.GetItemInfo") or C.Has("GetItemInfo")
    local i = 0
    local function batch()
        for _ = 1, 20 do
            i = i + 1
            local id = ids[i]
            if not id then return end
            if req then pcall(req, id) elseif info then info(id) end
        end
        C_Timer.After(0.2, batch)
    end
    batch()
    return #ids
end

-- Key binding target (Bindings.xml).
function TBCGuide_DeleteCheapestJunk() A:DeleteCheapestJunk() end
