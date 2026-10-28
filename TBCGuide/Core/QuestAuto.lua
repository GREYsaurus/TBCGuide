-- TBCGuide - automatic quest acceptance and turn-in for the active guide
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Rules (docs/AUTOMATION.md has the full list and the API evidence):
--  * Only quests with an OPEN accept / turn-in step in the active guide are handled. Other quests
--    stay manual (turn-ins of unrelated quests only if profile.turnInUnrelated is on).
--  * Escort and scripted-event quests are NEVER accepted automatically. There is no setting for
--    this. Unknown status counts as escort (DB.GetEscortStatus).
--  * A reward is NEVER chosen for the player: with more than one reward choice the reward panel
--    is left open and the player picks. Guide progress follows the game's QUEST_TURNED_IN event.
--  * Quests shared by other players, and party escort confirmations, are always left alone.
--  * Holding Shift while talking to an NPC disables automation for that interaction.
--  * Success is reported only when the game confirms it (QUEST_ACCEPTED / QUEST_TURNED_IN).

local _, ns = ...

local QA = { acceptOpen = {}, turninOpen = {}, titleToQuest = {}, attempts = {}, explained = {}, pending = {}, waitingReward = {} }
ns.QuestAuto = QA

local C -- ns.Compat
local RETRY_AFTER = 5     -- seconds before the same quest may be tried again
local CONFIRM_AFTER = 4   -- seconds to wait for the game to confirm an action

local function now() return GetTime() end
local function prof() return ns.db.profile end

local function notify(msg)
    if prof().questNotify then ns:Print(msg) end
end

local function questTitle(q, fallback)
    return (q and ns.DB.GetQuestName(q)) or fallback or ("quest " .. tostring(q))
end

-- Guide index -----------------------------------------------------------------------------------

-- Rebuilt whenever the engine refreshes: which quests the active guide still wants to accept or
-- turn in. Steps that are done, skipped or not for this character are excluded.
function QA:Rebuild()
    local acceptOpen, turninOpen, titles = {}, {}, {}
    local E = ns.Engine
    local g = E.guide
    if g then
        for i, s in ipairs(g.steps) do
            local st = E.status[i]
            if s.q and (st == "active" or st == "pending") then
                if s[1] == "accept" then
                    acceptOpen[s.q] = s
                elseif s[1] == "turnin" then
                    turninOpen[s.q] = s
                end
                local t = s.title or ns.DB.GetQuestName(s.q)
                if t then
                    -- Title fallback only for unambiguous titles (several quests share names).
                    if titles[t] == nil then titles[t] = s.q elseif titles[t] ~= s.q then titles[t] = false end
                end
            end
        end
    end
    self.acceptOpen, self.turninOpen, self.titleToQuest = acceptOpen, turninOpen, titles
end

-- Resolves a dialog entry to a quest id: the client's id if it gave one, else a unique title match.
function QA:Resolve(questID, title)
    if questID and questID > 0 then return questID end
    local q = title and self.titleToQuest[title]
    if q then return q end
    return nil
end

-- Decisions (pure; covered by tests/run_tests.lua) ----------------------------------------------

-- Returns ok, reason, onGuide. `liveText` is the offer panel text when known.
function QA:CanAccept(q, liveText)
    local p = prof()
    if not q then return false, "quest id unknown", false end
    local step = self.acceptOpen[q]
    if not step then return false, "not in the active guide", false end
    local manual, why = ns.DB.GetEscortStatus(q, liveText)
    if manual then return false, why, true end
    if not p.autoAccept then return false, "automatic acceptance is off", true end
    if step.optional and not p.autoAcceptOptional then return false, "optional quest", true end
    if (step.elite or step.group or step.dungeon) and not p.autoAcceptGroup then return false, "group/dungeon quest", true end
    if ns.Tracker:InLog(q) then return false, "already in quest log", true end
    local count, max = C.QuestLogSize()
    if count >= max then return false, "quest log full (" .. count .. "/" .. max .. ")", true end
    return true, nil, true
end

-- Returns ok, reason, onGuide.
function QA:CanTurnIn(q)
    local p = prof()
    if not q then return false, "quest id unknown", false end
    local onGuide = self.turninOpen[q] ~= nil
    if not p.autoTurnIn then return false, "automatic turn-in is off", onGuide end
    if not onGuide then
        if not p.turnInUnrelated then return false, "not in the active guide", false end
        if ns.DB.IsRepeatable(q) then return false, "repeatable quest", false end
    end
    return true, nil, onGuide
end

local function recentlyTried(q)
    local t = q and QA.attempts[q]
    return t and (now() - t) < RETRY_AFTER
end

local function markTried(q) QA.attempts[q] = now() end

local function blocked()
    if C.IsModifierHeld() then return true end
    return false
end

-- Pending confirmations ---------------------------------------------------------------------------

function QA:Expect(kind, q)
    local token = {}
    self.pending[kind .. q] = token
    C_Timer.After(CONFIRM_AFTER, function()
        if QA.pending[kind .. q] ~= token then return end
        QA.pending[kind .. q] = nil
        if kind == "accept" and not ns.Tracker:InLog(q) then
            notify("|cffff7744Could not confirm that " .. questTitle(q) .. " was accepted.|r Accept it manually if it is still offered.")
        elseif kind == "turnin" and not ns.Tracker:IsTurnedIn(q) and not QA.waitingReward[q] then
            notify("|cffff7744Turn-in of " .. questTitle(q) .. " was not confirmed.|r The guide has not advanced.")
        end
    end)
end

function QA:OnAccepted(q)
    if not q then return end
    if self.pending["accept" .. q] then
        self.pending["accept" .. q] = nil
        notify("Accepted: " .. questTitle(q))
    end
end

function QA:OnTurnedIn(q)
    if not q then return end
    if self.waitingReward[q] then
        self.waitingReward[q] = nil
        notify("Turned in: " .. questTitle(q) .. ". Guide resumes.")
    elseif self.pending["turnin" .. q] then
        notify("Turned in: " .. questTitle(q))
    end
    self.pending["turnin" .. q] = nil
end

-- Dialog handlers ---------------------------------------------------------------------------------

-- Gossip window (NPCs with a menu) and quest greeting (NPCs with only quests): turn in completed
-- guide quests first (they often unlock the next ones), then open one guide quest to accept.
-- One selection per window; the game re-shows the list afterwards and we run again.
function QA:OnQuestList(active, available, selectActive, selectAvailable)
    if blocked() then return end
    for _, a in ipairs(active) do
        local q = self:Resolve(a.questID, a.title)
        if a.isComplete and q and not recentlyTried(q) and self:CanTurnIn(q) then
            markTried(q)
            return selectActive(a)
        end
    end
    for _, a in ipairs(available) do
        local q = self:Resolve(a.questID, a.title)
        if q and not recentlyTried(q) then
            local ok, why, onGuide = self:CanAccept(q)
            if ok then
                markTried(q)
                return selectAvailable(a)
            elseif onGuide and why then
                markTried(q)
                self:Explain(q, why)
            end
        end
    end
end

function QA:OnGossipShow()
    self:OnQuestList(C.GossipActiveQuests(), C.GossipAvailableQuests(), C.GossipSelectActive, C.GossipSelectAvailable)
end

function QA:OnQuestGreeting()
    self:OnQuestList(C.GreetingActiveQuests(), C.GreetingAvailableQuests(),
        function(a) return C.GreetingSelectActive(a.index) end,
        function(a) return C.GreetingSelectAvailable(a.index) end)
end

-- Tells the player why a guide quest needs them (escort, full log, ...). Once per quest per retry window.
function QA:Explain(q, why)
    local key = q .. ":" .. tostring(why)
    local last = self.explained[key]
    if last and (now() - last) < RETRY_AFTER then return end
    self.explained[key] = now()
    local title = questTitle(q)
    local lw = string.lower(why or "")
    if string.find(lw, "escort") or string.find(lw, "event") or string.find(lw, "not in the database") then
        notify("|cffffd100" .. title .. "|r is an escort/event quest (" .. why .. "). Accept it manually when you are ready.")
    elseif string.find(lw, "quest log full") then
        notify("|cffff7744Cannot accept " .. title .. ":|r " .. why .. ". Abandon or finish a quest first.")
    end
end

function QA:OnQuestDetail()
    if blocked() or C.DialogFromPlayer() then return end
    local q = self:Resolve(C.DialogQuestID(), C.DialogTitle())
    if not q or self.pending["accept" .. q] then return end
    local ok, why, onGuide = self:CanAccept(q, C.DialogText())
    if ok then
        markTried(q)
        self:Expect("accept", q)
        AcceptQuest()
    elseif onGuide then
        self:Explain(q, why)
    end
end

function QA:OnQuestProgress()
    if blocked() then return end
    local q = C.DialogQuestID()
    if not q or not self:CanTurnIn(q) then return end
    if not (IsQuestCompletable and IsQuestCompletable()) then return end
    if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then
        return notify(questTitle(q) .. " costs money to complete; finish it manually.")
    end
    CompleteQuest()
end

function QA:OnQuestComplete()
    if blocked() then return end
    local q = C.DialogQuestID()
    if not q then return end
    local ok, _, onGuide = self:CanTurnIn(q)
    if not ok then return end
    local choices = GetNumQuestChoices and GetNumQuestChoices()
    if type(choices) ~= "number" or choices > 1 then
        -- MANDATORY: the player picks the reward. Leave the panel open; progress follows the
        -- QUEST_TURNED_IN event once they click Complete Quest.
        self.waitingReward[q] = true
        if onGuide or prof().questNotify then
            ns:Print("|cffffd100Choose your reward|r for " .. questTitle(q) .. ", then click Complete Quest.")
        end
        return
    end
    if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then return end
    self:Expect("turnin", q)
    -- 0 or 1 choice: nothing to pick (the default UI preselects a single choice). Index 1 is what
    -- the 2.5.6 client expects in both cases (same call Questie makes on this client).
    GetQuestReward(1)
end

function QA:Init()
    C = ns.Compat
    ns:Listen("TBCG_REFRESH", function() QA:Rebuild() end)
    ns:On("GOSSIP_SHOW", function() QA:OnGossipShow() end)
    ns:On("QUEST_GREETING", function() QA:OnQuestGreeting() end)
    ns:On("QUEST_DETAIL", function() QA:OnQuestDetail() end)
    ns:On("QUEST_PROGRESS", function() QA:OnQuestProgress() end)
    ns:On("QUEST_COMPLETE", function() QA:OnQuestComplete() end)
    ns:On("QUEST_ACCEPTED", function(_, a, b) QA:OnAccepted(b or a) end)
    ns:On("QUEST_TURNED_IN", function(_, q) QA:OnTurnedIn(q) end)
    self:Rebuild()
end
