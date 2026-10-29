-- TBCGuide - gear scoring UI: item tooltips, quest reward ranking, /tbcg gear, settings page
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Read-only: nothing here equips, buys or chooses anything. Quest rewards are still always picked
-- by the player (Core/QuestAuto.lua never chooses between several rewards).

local _, ns = ...

local W = ns.Widgets
local GUI = { hooked = {}, done = setmetatable({}, { __mode = "k" }), rankedQuest = {} }
ns.GearUI = GUI

local function prof() return ns.db.profile end
local function on(key) return prof().gearEnabled and prof()[key] end

local CONF_COLOR = { high = "|cff33ff33", medium = "|cffffd100", low = "|cffff9933" }

local function profileLabel(p, withConf)
    if not p then return "none" end
    local s = (p.spec and (p.spec .. " ") or "") .. (p.role or "") .. " - " .. (p.context or "")
    if withConf then s = s .. " " .. (CONF_COLOR[p.confidence] or "") .. "(" .. tostring(p.confidence) .. " confidence)|r" end
    return s
end
GUI.ProfileLabel = profileLabel

-- Tooltips ------------------------------------------------------------------------------------------

-- Lines of the tooltip itself mentioning effects the score cannot see.
local function hasEffects(tt)
    local name = tt.GetName and tt:GetName()
    if not name or not tt.NumLines then return false end
    for i = 2, tt:NumLines() or 0 do
        local fs = _G[name .. "TextLeft" .. i]
        local t = fs and fs.GetText and fs:GetText()
        if type(t) == "string" and (string.find(t, "^Equip:") or string.find(t, "^Use:") or string.find(t, "^Chance on hit:")
            or string.find(t, "^%(%d%) Set:")) then
            return true
        end
    end
    return false
end

function GUI:Lines(link)
    local res = ns.Gear:Compare(link)
    if not res.ok then
        if res.unusable then return { { "TBCGuide: " .. res.reason, 0.8, 0.4, 0.4 } } end
        if res.noProfile then return { { "TBCGuide gear: " .. res.reason, 0.6, 0.6, 0.6 } } end
        return nil
    end
    local lines = {}
    local s = ns.Gear:Summary(res, prof().gearShowPercent)
    local r, g, b = 1, 0.82, 0
    if res.numeric and res.delta and not res.empty and not res.same then
        if res.delta > 0 then r, g, b = 0.3, 1, 0.3 elseif res.delta < 0 then r, g, b = 1, 0.4, 0.4 end
    elseif res.verdict == "better" then r, g, b = 0.3, 1, 0.3 elseif res.verdict == "worse" then r, g, b = 1, 0.4, 0.4 end
    lines[#lines + 1] = { "TBCGuide: " .. s, r, g, b }
    if res.numeric and res.parts and #res.parts > 0 then
        local top = {}
        for i = 1, math.min(3, #res.parts) do
            local x = res.parts[i]
            top[#top + 1] = string.format("%s %.0f", ns.Gear.STAT_NAMES[x.key] or x.key, x.points)
                .. (x.used < x.amount and " (over cap)" or "")
        end
        lines[#lines + 1] = { "  from " .. table.concat(top, ", "), 0.7, 0.7, 0.7 }
    end
    lines[#lines + 1] = { "  " .. profileLabel(res.profile, prof().gearShowConfidence)
        .. (res.numeric and "" or " - priority only, no numeric score"), 0.6, 0.6, 0.6 }
    for _, n in ipairs(res.notes) do lines[#lines + 1] = { "  " .. n, 0.6, 0.6, 0.6 } end
    return lines
end

function GUI:OnTooltipSetItem(tt)
    if not on("gearTooltip") or self.done[tt] then return end
    local _, link = tt:GetItem()
    if not link then return end
    self.done[tt] = true -- one block per tooltip; cleared when the tooltip is cleared or hidden
    local ok, lines = pcall(self.Lines, self, link)
    if not ok then ns:Error("gear tooltip: " .. tostring(lines)) return end
    if not lines then return end
    if hasEffects(tt) then lines[#lines + 1] = { "  equip/use effects and set bonuses are not scored", 0.6, 0.6, 0.6 } end
    for _, l in ipairs(lines) do tt:AddLine(l[1], l[2], l[3], l[4]) end
    tt:Show()
end

function GUI:HookTooltip(tt)
    if not tt or self.hooked[tt] or not tt.HookScript then return end
    self.hooked[tt] = true
    tt:HookScript("OnTooltipSetItem", function(t) GUI:OnTooltipSetItem(t) end)
    tt:HookScript("OnTooltipCleared", function(t) GUI.done[t] = nil end)
    tt:HookScript("OnHide", function(t) GUI.done[t] = nil end)
end

-- Quest rewards ---------------------------------------------------------------------------------------

-- Reward to choose automatically (Quest auto rewards, opt-in), or nil to leave it to the player.
-- Taken only when (a) a numeric profile scores one reward strictly above every other one and as
-- an upgrade, or (b) the class can use none of the rewards: then the one worth most at a vendor.
-- Returns { index, link }, reason.
function GUI:AutoRewardChoice()
    local rows = self:RankRewards()
    if not rows or #rows < 2 then return nil end
    for _, r in ipairs(rows) do
        if not r.link or r.res.reason == "item not loaded yet" then return nil end
    end
    local best, second = rows[1], rows[2]
    if best.res.ok and best.res.numeric and best.res.delta and best.res.delta > 0 then
        local d2 = second.res.ok and second.res.numeric and second.res.delta
        if not d2 or best.res.delta > d2 then return { index = best.index, link = best.link }, "best gear score" end
        return nil
    end
    local allUnusable = true
    for _, r in ipairs(rows) do if not r.res.unusable then allUnusable = false end end
    if not allUnusable then return nil end
    local pick, value = nil, -1
    for _, r in ipairs(rows) do
        local info = ns.Compat.GetItemInfo(r.link)
        local v = info and info.sellPrice or 0
        if v > value then pick, value = r, v end
    end
    if pick and value > 0 then return { index = pick.index, link = pick.link }, "none usable; most valuable" end
end

-- Ranks the reward choices of the open quest dialog. Returns rows { index, link, res } best first,
-- or nil when there is nothing to rank. Uncached items are reported, never guessed.
function GUI:RankRewards()
    local n = GetNumQuestChoices and GetNumQuestChoices() or 0
    if type(n) ~= "number" or n < 2 or not GetQuestItemLink then return nil end
    local rows = {}
    for i = 1, n do
        local link = GetQuestItemLink("choice", i)
        rows[#rows + 1] = { index = i, link = link, res = link and ns.Gear:Compare(link) or { ok = false, reason = "item not loaded yet" } }
    end
    local function key(r)
        if not r.res.ok then return -math.huge end
        if r.res.numeric then return r.res.delta or 0 end
        return ({ better = 2, empty = 2, mixed = 1, same = 0, worse = -1 })[r.res.verdict] or 0
    end
    table.sort(rows, function(a, b) local ka, kb = key(a), key(b) if ka ~= kb then return ka > kb end return a.index < b.index end)
    return rows
end

function GUI:PrintRewards(questID)
    if not on("gearQuestRewards") then return end
    local rows = self:RankRewards()
    if not rows then return end
    local pending = false
    for _, r in ipairs(rows) do if not r.link or r.res.reason == "item not loaded yet" then pending = true end end
    if pending and not self.retried then
        self.retried = true
        return C_Timer.After(0.6, function() GUI:PrintRewards(questID) end)
    end
    self.retried = nil
    if questID and self.rankedQuest[questID] then return end
    if questID then self.rankedQuest[questID] = true end
    local p = rows[1].res.profile
    local numeric = p and p.weights ~= nil
    ns:Print("Reward comparison (" .. (p and profileLabel(p, prof().gearShowConfidence) or "no profile") .. "):"
        .. (numeric and "" or " priority only - no numeric score"))
    for rank, r in ipairs(rows) do
        local name = r.res.item and r.res.item.link or r.link or ("choice " .. r.index)
        local text = r.res.ok and ns.Gear:Summary(r.res, prof().gearShowPercent) or ("not compared: " .. tostring(r.res.reason))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  %d. %s - %s", rank, tostring(name), text))
    end
    DEFAULT_CHAT_FRAME:AddMessage("  |cff999999Relative score from TBCGuide's stat weights, not a DPS or healing guarantee. You choose the reward.|r")
end

-- /tbcg gear -------------------------------------------------------------------------------------------

function GUI:Overview()
    local G = ns.Gear
    local info = G:Context()
    local p, why = G:SelectProfile(info)
    ns:Print("Gear profile: " .. (p and profileLabel(p, true) or "none") .. " (" .. tostring(why) .. ")")
    if not p then ns:Print("Gear scores are unavailable; tooltips show nothing numeric. /tbcg gear profile <id> to pick one.") end
    local empty = {}
    for _, slot in ipairs(G.SCORED_SLOTS) do
        local d = G:EquippedData(slot)
        if not d then
            if not (slot == 17 and G:EquippedData(16) and G:EquippedData(16).equipLoc == "INVTYPE_2HWEAPON") then
                empty[#empty + 1] = G.SLOT_NAMES[slot]
            end
        elseif p and p.weights then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %s - score %.0f", G.SLOT_NAMES[slot], d.link, G:Score(d, p) or 0))
        else
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %s", G.SLOT_NAMES[slot], d.link))
        end
    end
    if #empty > 0 then ns:Print("Empty slots: " .. table.concat(empty, ", ")) end
    -- Upgrades in bags
    local ups = {}
    local Cn = ns.Compat.Has("C_Container")
    for bag = 0, 4 do
        local nslots = Cn and Cn.GetContainerNumSlots and Cn.GetContainerNumSlots(bag) or 0
        for s = 1, nslots do
            local it = Cn.GetContainerItemInfo(bag, s)
            local link = it and it.hyperlink
            if link then
                local res = G:Compare(link, info)
                if res.ok and ((res.numeric and res.delta and res.delta > 0) or res.verdict == "better" or res.verdict == "empty") then
                    ups[#ups + 1] = { link = link, res = res }
                end
            end
        end
    end
    if #ups == 0 then
        ns:Print("No upgrades found in your bags for this profile.")
    else
        ns:Print("Possible upgrades in your bags:")
        for _, u in ipairs(ups) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s (%s): %s", u.link, G.SLOT_NAMES[u.res.slot] or "?", G:Summary(u.res, prof().gearShowPercent)))
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("  |cff999999Where to get better items is not listed: the bundled quest data has no reward items.|r")
end

function GUI:ListProfiles()
    local info = ns.Gear:Context()
    ns:Print("Gear profiles for your class (current: " .. tostring(ns.char.gearProfile or "auto") .. "):")
    for _, p in ipairs(ns.Gear:ProfilesForClass(info.class)) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffd100%s|r - %s, levels %d-%d%s", p.id, profileLabel(p, true),
            p.levelMin or 1, p.levelMax or 70, p.weights and "" or ", priority only"))
    end
end

function GUI:SetProfile(id)
    if not id or id == "" or id == "auto" then
        ns.char.gearProfile = nil
        return ns:Print("Gear profile: automatic (talents and level).")
    end
    local p = ns.Gear:ProfileById(id)
    if not p or p.class ~= ns.Gear:Context().class then return ns:Print("Unknown profile for your class: " .. id .. ". /tbcg gear profiles") end
    ns.char.gearProfile = id
    ns:Print("Gear profile: " .. profileLabel(p, true)
        .. ((ns.Gear:Context().level or 1) < (p.levelMin or 1) and " |cffff9933(made for level " .. p.levelMin .. "; approximate for you)|r" or ""))
end

function GUI:Command(arg)
    local verb, rest = string.match(arg or "", "^(%S*)%s*(.-)$")
    if verb == "profiles" then return self:ListProfiles() end
    if verb == "profile" then return self:SetProfile(rest) end
    if verb == "options" then return self:Open() end
    self:Overview()
end

-- Settings page -----------------------------------------------------------------------------------------

local CHECKS = {
    { "gearEnabled", "Enable gear scoring" },
    { "gearTooltip", "Show scores on item tooltips" },
    { "gearQuestRewards", "Rank quest reward choices in chat" },
    { "gearShowPercent", "Show relative score change (%)" },
    { "gearShowConfidence", "Show profile confidence" },
}
GUI.DEFAULTS = { gearEnabled = true, gearTooltip = true, gearQuestRewards = true, gearShowPercent = true, gearShowConfidence = true }

function GUI:Create()
    self:HookTooltip(GameTooltip)
    self:HookTooltip(ItemRefTooltip)
    ns:On("QUEST_DETAIL", function() GUI:PrintRewards(GetQuestID and GetQuestID()) end)
    ns:On("QUEST_COMPLETE", function() GUI:PrintRewards(GetQuestID and GetQuestID()) end)

    local p = CreateFrame("Frame", "TBCGuideGearPanel", UIParent)
    p:Hide()
    self.panel = p
    self.checks = {}
    local title = W.Text(p, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("TBCGuide - Gear scoring")
    local y = -48
    for _, c in ipairs(CHECKS) do
        local key = c[1]
        local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        local text = W.Text(cb, "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        text:SetText(c[2])
        cb:SetScript("OnClick", function(s) prof()[key] = s:GetChecked() and true or false end)
        cb.sync = function() cb:SetChecked(prof()[key] and true or false) end
        self.checks[#self.checks + 1] = cb
        y = y - 24
    end
    self.profileText = W.Text(p, "GameFontHighlightSmall")
    self.profileText:SetPoint("TOPLEFT", 20, y - 8)
    self.profileText:SetWidth(560)
    self.profileText:SetJustifyH("LEFT")
    W.Button(p, "Next profile", 110, 22, function() GUI:CycleProfile() end):SetPoint("TOPLEFT", 20, y - 48)
    W.Button(p, "Automatic", 90, 22, function() GUI:SetProfile("auto") GUI:Sync() end):SetPoint("TOPLEFT", 136, y - 48)
    W.Button(p, "Reset gear settings", 150, 22, function() GUI:ResetSettings() end):SetPoint("TOPLEFT", 232, y - 48)
    local note = W.Text(p, "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 20, y - 84)
    note:SetWidth(560)
    note:SetJustifyH("LEFT")
    note:SetText("Scores are relative values from researched stat weights (docs/GEAR_RESEARCH.md), not a guarantee "
        .. "of more damage or healing. Profiles without published numbers compare stats in priority order only. "
        .. "Weapon DPS, sockets, equip/use effects and set bonuses are not scored. /tbcg gear lists your gear.")
    p:SetScript("OnShow", function() GUI:Sync() end)
    ns.Compat.RegisterOptionsSubPanel(p, "TBCGuide", "Gear")
end

function GUI:CycleProfile()
    local list = ns.Gear:ProfilesForClass(ns.Gear:Context().class)
    if #list == 0 then return end
    local cur, idx = ns.char.gearProfile, 0
    for i, p in ipairs(list) do if p.id == cur then idx = i end end
    local nextP = list[idx + 1]
    self:SetProfile(nextP and nextP.id or "auto")
    self:Sync()
end

function GUI:ResetSettings()
    for k, v in pairs(self.DEFAULTS) do prof()[k] = v end
    ns.char.gearProfile = nil
    self:Sync()
    ns:Print("Gear settings reset to defaults.")
end

function GUI:Sync()
    for _, cb in ipairs(self.checks or {}) do cb.sync() end
    if self.profileText then
        local p, why = ns.Gear:SelectProfile()
        self.profileText:SetText("Profile: " .. (p and profileLabel(p, true) or "none") .. " (" .. tostring(why) .. ")")
    end
end

function GUI:Open()
    if not ns.Compat.OpenOptionsPanel(self.panel) then ns:Print("Options panel unavailable; use /tbcg gear profile and /tbcg set gearTooltip on|off.") end
end
