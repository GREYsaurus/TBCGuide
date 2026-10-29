-- TBCGuide - group features: version checks, party announcements, automatic quest sharing
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Addon messages (prefix "TBCGuide"): "V:<version>" announces our version to the party/raid and
-- guild; members who run TBCGuide answer once. That tells us who else uses TBCGuide, so party
-- announcements are only sent when someone else can see them (unless "Send announcements without
-- another TBCGuide user" is on). Everything in the Grouping section needs "Enable Group Settings".

local _, ns = ...

local G = { users = {}, replied = {}, told = false, lastObjective = {}, lastSent = 0, complete = {} }
ns.Group = G

G.PREFIX = "TBCGuide"

local function prof() return ns.db.profile end
local function inGroup() return (IsInGroup and IsInGroup()) or (GetNumGroupMembers and GetNumGroupMembers() > 0) or false end
local function inRaid() return IsInRaid and IsInRaid() or false end
local function myVersion() return ns.version or "0" end

-- "0.7.1" > "0.7.0"; non-numeric parts compare as 0.
function G.Newer(a, b)
    local pa, pb = {}, {}
    for n in string.gmatch(tostring(a), "%d+") do pa[#pa + 1] = tonumber(n) end
    for n in string.gmatch(tostring(b), "%d+") do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

local function send(msg, channel, target)
    local f = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
    if f then pcall(f, G.PREFIX, msg, channel, target) end
end

function G:SendVersion(channel)
    if channel == "GROUP" then
        if not inGroup() then return end
        channel = inRaid() and "RAID" or "PARTY"
    end
    send("V:" .. myVersion(), channel)
end

function G:OnAddonMessage(prefix, msg, channel, sender)
    if prefix ~= self.PREFIX or type(msg) ~= "string" then return end
    local name = sender and string.match(sender, "^([^%-]+)") or sender
    if not name or name == (UnitName and UnitName("player")) then return end
    local v = string.match(msg, "^V:(.+)$")
    if not v then return end
    self.users[name] = v
    if prof().versionCheck and not self.told and G.Newer(v, myVersion()) then
        self.told = true
        ns:Print("A newer TBCGuide (" .. v .. ") is in use by " .. name .. ". You have " .. myVersion() .. ".")
    end
    -- Answer once per sender so they learn about us too.
    if not self.replied[name] and (channel == "PARTY" or channel == "RAID" or channel == "GUILD") then
        self.replied[name] = true
        send("V:" .. myVersion(), channel)
    end
end

-- Whether another party member runs TBCGuide (as far as we have heard).
function G:OthersInGroup()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, math.max(n - 1, 0) do
        local name = UnitName and UnitName("party" .. i)
        if name and self.users[name] then return true end
    end
    return false
end

-- Party announcement, if the group settings allow it. Returns true when sent.
function G:Announce(text, kind)
    local p = prof()
    if not p.groupFeatures or not inGroup() or inRaid() then return false end
    if kind and not p[kind] then return false end
    if (kind == "announceCollect" or kind == "announceComplete") and p.announceSkipQuestie and self:QuestieLoaded() then return false end
    if not p.announceAlways and not self:OthersInGroup() then return false end
    if not SendChatMessage then return false end
    SendChatMessage("[TBCGuide] " .. text, "PARTY")
    self.lastSent = GetTime and GetTime() or 0
    return true
end

function G:QuestieLoaded()
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return f and f("Questie") and true or false
end

-- Quest objective progress ("Wolf Meat: 3/8") for a quest of the current guide.
function G:OnInfoMessage(msg)
    if type(msg) ~= "string" then return end
    local what, have, need = string.match(msg, "^(.+): (%d+)/(%d+)$")
    if not what then return end
    if not self:GuideHasObjective(what) then return end
    local key = what .. have
    if self.lastObjective[what] == key then return end
    self.lastObjective[what] = key
    self:Announce(what .. ": " .. have .. "/" .. need, "announceCollect")
end

-- Is `text` an objective of a quest in the log that the current guide uses?
function G:GuideHasObjective(text)
    local g = ns.Engine and ns.Engine.guide
    if not g then return false end
    for _, s in ipairs(g.steps) do
        local e = s.q and ns.Tracker:GetEntry(s.q)
        if e and e.objectives then
            for _, o in ipairs(e.objectives) do
                if type(o.text) == "string" and string.find(o.text, text, 1, true) then return true end
            end
        end
    end
    return false
end

-- A guide quest became complete (all objectives done).
function G:OnQuestsChanged()
    local g = ns.Engine and ns.Engine.guide
    if not g then return end
    for _, s in ipairs(g.steps) do
        if s[1] == "complete" and s.q and ns.Tracker:InLog(s.q) then
            local done = ns.Tracker:IsComplete(s.q)
            if done and self.complete[s.q] == false then
                self:Announce((s.title or ns.DB.GetQuestName(s.q) or ("quest " .. s.q)) .. " is complete.", "announceComplete")
            end
            self.complete[s.q] = done and true or false
        end
    end
end

-- Share a guide quest with the party right after accepting it.
function G:OnQuestAccepted(index, questId)
    local p = prof()
    if not (p.groupFeatures and p.autoShareQuests and inGroup()) then return end
    if not questId and index and GetQuestLogTitle then questId = select(8, GetQuestLogTitle(index)) end
    local g = ns.Engine and ns.Engine.guide
    if not (g and questId and ns.Engine.acceptIndex and ns.Engine.acceptIndex[questId]) then return end
    if GetQuestLogIndexByID then index = GetQuestLogIndexByID(questId) or index end
    if not (index and SelectQuestLogEntry and GetQuestLogPushable and QuestLogPushQuest) then return end
    C_Timer.After(0.5, function()
        SelectQuestLogEntry(index)
        if GetQuestLogPushable() then QuestLogPushQuest() end
    end)
end

-- The party leader's unit id, or nil when we lead or are not in a party.
function G:LeaderUnit()
    if not inGroup() or inRaid() then return nil end
    for i = 1, 4 do
        local u = "party" .. i
        if UnitExists and UnitExists(u) and UnitIsGroupLeader and UnitIsGroupLeader(u) then return u end
    end
end

function G:Init()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
    elseif RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(self.PREFIX) end
    ns:On("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender) G:OnAddonMessage(prefix, msg, channel, sender) end)
    ns:On("GROUP_ROSTER_UPDATE", function()
        if prof().versionCheck or prof().groupFeatures then ns:Throttle("groupversion", 5, function() G:SendVersion("GROUP") end) end
    end)
    ns:On("UI_INFO_MESSAGE", function(_, a, b) G:OnInfoMessage(type(b) == "string" and b or a) end)
    ns:On("QUEST_ACCEPTED", function(_, a, b) G:OnQuestAccepted(b and a or nil, b or a) end)
    ns:Listen("TBCG_QUESTS_CHANGED", function() G:OnQuestsChanged() end)
    C_Timer.After(10, function()
        if prof().versionCheck then
            if IsInGuild and IsInGuild() then G:SendVersion("GUILD") end
            G:SendVersion("GROUP")
        end
    end)
end
