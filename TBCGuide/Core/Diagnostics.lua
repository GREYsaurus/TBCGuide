-- TBCGuide - in-game diagnostics (/tbcg debug ...)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- These checks exist because the add-on could not be run in the real client during development.
-- They let a tester confirm API availability, talent data vs. client, and quest data quickly.

local _, ns = ...

local D = {}
ns.Diagnostics = D

local function line(msg) DEFAULT_CHAT_FRAME:AddMessage("  " .. msg) end

function D:Summary()
    local iface, build = ns.Compat.GetInterface()
    ns:Print(string.format("version %s - client %s (interface %d), target %d",
        tostring(ns.version), tostring(build), iface, ns.Target.interface))
    if iface ~= 0 and (iface < ns.Target.minInterface or iface > ns.Target.maxInterface) then
        line("|cffff7744This client is outside the tested interface range.|r")
    end
    local nq, nn = 0, 0
    for _ in pairs(ns.QDB.quests) do nq = nq + 1 end
    for _ in pairs(ns.QDB.npcs) do nn = nn + 1 end
    line(string.format("quest db: %d quests, %d npcs", nq, nn))
    line(string.format("guides: %d loaded, %d rejected", #ns.Guides.list, #ns.Guides.rejected))
    line(string.format("talent builds: %d", #ns.Talents.buildList))
    line(string.format("quest log entries tracked: %d", ns.Tracker:Count()))
    line(string.format("errors captured: %d (/tbcg debug errors)", #ns.errors))
end

function D:Api()
    local apis = {
        "C_QuestLog.IsQuestFlaggedCompleted", "IsQuestFlaggedCompleted", "GetQuestsCompleted",
        "GetQuestLogTitle", "GetNumQuestLeaderBoards", "GetQuestLogLeaderBoard",
        "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_Map.GetWorldPosFromMapPos", "C_Map.GetMapInfo",
        "GetPlayerFacing", "GetBindLocation", "GetTalentInfo", "GetTalentTabInfo", "UnitCharacterPoints",
        "C_AddOns.GetAddOnMetadata", "GetAddOnMetadata", "Settings.RegisterCanvasLayoutCategory",
        "InterfaceOptions_AddCategory", "BackdropTemplateMixin", "C_Timer.After",
        -- automation
        "C_Container.GetContainerItemInfo", "GetContainerItemInfo", "C_Container.UseContainerItem", "UseContainerItem",
        "C_Container.GetContainerItemQuestInfo", "GetContainerItemQuestInfo", "GetItemInfo", "GetMoney",
        "GetItemStats", "GetInventoryItemLink", "GetCombatRating", "GetQuestItemLink",
        "C_GossipInfo.GetAvailableQuests", "C_GossipInfo.SelectAvailableQuest", "C_GossipInfo.GetActiveQuests",
        "C_GossipInfo.SelectActiveQuest", "GetGossipAvailableQuests", "GetAvailableQuestInfo", "GetActiveQuestID",
        "GetQuestID", "AcceptQuest", "CompleteQuest", "IsQuestCompletable", "GetNumQuestChoices", "GetQuestReward",
        "GetQuestMoneyToGet", "C_QuestLog.GetMaxNumQuestsCanAccept", "Settings.RegisterCanvasLayoutSubcategory",
        -- raid markers
        "SetRaidTarget", "GetRaidTargetIndex", "UnitGUID", "IsInRaid", "UnitIsGroupLeader", "UnitIsGroupAssistant",
        "InCombatLockdown",
    }
    ns:Print("API availability:")
    for _, a in ipairs(apis) do
        line((ns.Compat.Has(a) and "|cff55ff55yes|r " or "|cffff5555no|r  ") .. a)
    end
    local m = {}
    for k in pairs(ns.Compat.missing) do m[#m + 1] = k end
    if #m > 0 then line("fallbacks used: " .. table.concat(m, ", ")) end
end

function D:TalentCheck()
    local live, mismatches = ns.Talents:ReadLive()
    local n = 0
    for _ in pairs(live) do n = n + 1 end
    ns:Print(string.format("talents: %d talents with points; %d data mismatches", n, #mismatches))
    for i = 1, math.min(#mismatches, 15) do line(mismatches[i]) end
    local b = ns.Talents:ActiveBuild()
    if b then
        local _, errs = ns.Talents:Expand(b)
        line("active build: " .. b.name .. (#errs > 0 and (" |cffff5555(" .. #errs .. " errors)|r") or " (valid)"))
    end
end

function D:Quest(id)
    id = tonumber(id)
    if not id then return ns:Print("usage: /tbcg debug quest <questId>") end
    local q = ns.DB.GetQuestByID(id)
    if not q then return ns:Print("quest " .. id .. " not in database") end
    ns:Print(string.format("%d: %s (level %d, requires %d)", id, q.name, q.level, q.requiredLevel))
    local f = ns.DB.GetQuestFactionRestrictions(id)
    line("faction: " .. tostring(f) .. ", zone: " .. tostring(ns.DB.ZoneName(ns.DB.GetQuestZone(id))))
    line("completed: " .. tostring(ns.Tracker:IsTurnedIn(id)) .. ", in log: " .. tostring(ns.Tracker:InLog(id)))
    local ok, why, extra = ns.DB.IsQuestAvailable(id, ns.Tracker:Context())
    line("available: " .. tostring(ok) .. (why and (" (" .. why .. (extra and (" " .. extra) or "") .. ")") or ""))
    local s = q.startNpcs[1]
    if s then
        local z, x, y = ns.DB.GetNPCPosition(s)
        line(string.format("start: %s %s", tostring(ns.DB.GetNPCName(s)), z and string.format("%.1f,%.1f %s", x, y, tostring(ns.DB.ZoneName(z))) or ""))
    end
end

function D:Run(arg)
    local cmd, rest = string.match(arg or "", "^(%S*)%s*(.-)$")
    if cmd == "api" then return self:Api() end
    if cmd == "talents" then return self:TalentCheck() end
    if cmd == "quest" then return self:Quest(rest) end
    if cmd == "marks" then
        local M = ns.Marker
        local r = M.rule
        ns:Print("raid markers: " .. (r and ("step marks " .. M.Label(r.icon)) or "no marker rule for this step")
            .. (M.blocked and ", BLOCKED by the client" or "") .. (M.stopped and ", paused after failures" or ""))
        local ok, why = ns.Compat.CanMark()
        line("can mark now: " .. tostring(ok) .. (why and (" (" .. why .. ")") or ""))
        if r then
            local ids = {}
            for id in pairs(r.npcs) do ids[#ids + 1] = id .. " " .. tostring(ns.DB.GetNPCName(id)) end
            line("npcs: " .. table.concat(ids, ", "))
        end
        return
    end
    if cmd == "escort" then
        local id = tonumber(rest)
        if not id then return ns:Print("usage: /tbcg debug escort <questId>") end
        local manual, why = ns.DB.GetEscortStatus(id)
        return ns:Print(string.format("%d %s: %s", id, tostring(ns.DB.GetQuestName(id)),
            manual and ("manual only (" .. why .. ")") or "may be auto-accepted when it is in the active guide"))
    end
    if cmd == "errors" then
        ns:Print(#ns.errors .. " captured errors:")
        for i = 1, #ns.errors do line(ns.errors[i]) end
        return
    end
    if cmd == "on" or cmd == "off" then
        ns.db.profile.debug = (cmd == "on")
        return ns:Print("debug " .. cmd)
    end
    self:Summary()
end
