-- TBCGuide - quest database adapter (internal query API over the bundled Questie-derived data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- The guide engine only talks to the database through these functions. Every function
-- tolerates missing records and returns nil/empty rather than erroring, so guides keep working
-- if the data files are trimmed or excluded from a build.

local _, ns = ...

local DB = {}
ns.DB = DB

local QDB = ns.QDB
local Q, N, O, I = QDB.QUEST, QDB.NPC, QDB.OBJECT, QDB.ITEM
local EMPTY = {}

local function rawQuest(id) return id and QDB.quests[id] end

function DB.HasData()
    return next(QDB.quests) ~= nil
end

-- Quests ---------------------------------------------------------------------------------------

function DB.GetQuestByID(questId)
    local r = rawQuest(questId)
    if not r then return nil end
    local obj = r[Q.OBJECTIVES] or EMPTY
    return {
        id = questId,
        name = r[Q.NAME],
        requiredLevel = r[Q.REQ_LEVEL] or 0,
        level = r[Q.LEVEL] or 0,
        races = r[Q.RACES] or 0,
        classes = r[Q.CLASSES] or 0,
        startNpcs = r[Q.START_NPCS] or EMPTY,
        startObjects = r[Q.START_OBJECTS] or EMPTY,
        startItems = r[Q.START_ITEMS] or EMPTY,
        endNpcs = r[Q.END_NPCS] or EMPTY,
        endObjects = r[Q.END_OBJECTS] or EMPTY,
        objectivesText = r[Q.OBJECTIVES_TEXT],
        objectives = { creatures = obj.c or EMPTY, objects = obj.o or EMPTY, items = obj.i or EMPTY,
                       killCredit = obj.k or EMPTY, reputation = obj.r },
        preGroup = r[Q.PRE_GROUP] or EMPTY,
        preSingle = r[Q.PRE_SINGLE] or EMPTY,
        zone = r[Q.ZONE] or 0,
        exclusiveTo = r[Q.EXCLUSIVE] or EMPTY,
        nextInChain = r[Q.NEXT],
        breadcrumbFor = r[Q.BREADCRUMB_FOR],
        repeatable = ns.HasBit(r[Q.SPECIAL_FLAGS] or 0, 1),
        maxLevel = r[Q.MAX_LEVEL],
        trigger = r[Q.TRIGGER],
        requiredSkill = r[Q.REQ_SKILL],
        requiredMinRep = r[Q.REQ_MIN_REP],
        sourceItem = r[Q.SOURCE_ITEM],
        parentQuest = r[Q.PARENT],
    }
end

function DB.GetQuestName(questId)
    local r = rawQuest(questId)
    return r and r[Q.NAME]
end

function DB.GetQuestLevel(questId)
    local r = rawQuest(questId)
    if not r then return nil end
    return r[Q.LEVEL], r[Q.REQ_LEVEL]
end

-- { all = {ids...}, any = {ids...} } — all of `all` and at least one of `any` must be completed.
function DB.GetQuestPrerequisites(questId)
    local r = rawQuest(questId)
    if not r then return { all = EMPTY, any = EMPTY } end
    return { all = r[Q.PRE_GROUP] or EMPTY, any = r[Q.PRE_SINGLE] or EMPTY }
end

function DB.GetQuestObjectives(questId)
    local q = DB.GetQuestByID(questId)
    if not q then return nil end
    local list = {}
    for _, id in ipairs(q.objectives.creatures) do list[#list + 1] = { kind = "npc", id = id, name = DB.GetNPCName(id) } end
    for _, id in ipairs(q.objectives.killCredit) do list[#list + 1] = { kind = "npc", id = id, name = DB.GetNPCName(id) } end
    for _, id in ipairs(q.objectives.objects) do list[#list + 1] = { kind = "object", id = id, name = DB.GetObjectName(id) } end
    for _, id in ipairs(q.objectives.items) do list[#list + 1] = { kind = "item", id = id, name = DB.GetItemName(id) } end
    if q.objectives.reputation then list[#list + 1] = { kind = "reputation", id = q.objectives.reputation[1], value = q.objectives.reputation[2] } end
    if q.trigger then list[#list + 1] = { kind = "event", text = q.trigger[1] } end
    return list, q.objectivesText
end

function DB.GetQuestStartNPCs(questId)
    local r = rawQuest(questId)
    return r and r[Q.START_NPCS] or EMPTY, r and r[Q.START_OBJECTS] or EMPTY, r and r[Q.START_ITEMS] or EMPTY
end

function DB.GetQuestEndNPCs(questId)
    local r = rawQuest(questId)
    return r and r[Q.END_NPCS] or EMPTY, r and r[Q.END_OBJECTS] or EMPTY
end

-- "Alliance", "Horde", "Both"; plus the raw race mask (0 = any race).
function DB.GetQuestFactionRestrictions(questId)
    local r = rawQuest(questId)
    if not r then return nil end
    local races = r[Q.RACES] or 0
    if races == 0 then return "Both", 0 end
    local a = bit and bit.band(races, QDB.ALLIANCE_MASK) or 1
    local h = bit and bit.band(races, QDB.HORDE_MASK) or 1
    if a ~= 0 and h ~= 0 then return "Both", races end
    if a ~= 0 then return "Alliance", races end
    return "Horde", races
end

-- Parent zone of a quest (resolves subzones like Ammen Vale -> Azuremyst Isle). nil for sorts.
function DB.GetQuestZone(questId)
    local r = rawQuest(questId)
    local z = r and r[Q.ZONE]
    if not z or z <= 0 then return nil end
    return DB.ParentZone(z)
end

-- Availability check for a character. Returns ok, reason.
-- `ctx` = { race=, class=, level=, isCompleted=function(id), inLog=function(id) }
function DB.IsQuestAvailable(questId, ctx)
    local r = rawQuest(questId)
    if not r then return true, "unknown quest (no data)" end
    local races, classes = r[Q.RACES] or 0, r[Q.CLASSES] or 0
    local rb = QDB.RACE_BITS[ctx.race or ""]
    if races ~= 0 and rb and not ns.HasBit(races, rb) then return false, "race" end
    local cb = QDB.CLASS_BITS[ctx.class or ""]
    if classes ~= 0 and cb and not ns.HasBit(classes, cb) then return false, "class" end
    if ctx.level and (r[Q.REQ_LEVEL] or 0) > ctx.level then return false, "level", r[Q.REQ_LEVEL] end
    if ctx.level and r[Q.MAX_LEVEL] and r[Q.MAX_LEVEL] > 0 and ctx.level > r[Q.MAX_LEVEL] then return false, "too high level" end
    if ctx.isCompleted then
        if ctx.isCompleted(questId) and not ns.HasBit(r[Q.SPECIAL_FLAGS] or 0, 1) then return false, "completed" end
        for _, pre in ipairs(r[Q.PRE_GROUP] or EMPTY) do
            if not ctx.isCompleted(pre) then return false, "prerequisite", pre end
        end
        local single = r[Q.PRE_SINGLE]
        if single and #single > 0 then
            local any = false
            for _, pre in ipairs(single) do if ctx.isCompleted(pre) then any = true break end end
            if not any then return false, "prerequisite", single[1] end
        end
        for _, ex in ipairs(r[Q.EXCLUSIVE] or EMPTY) do
            if ctx.isCompleted(ex) or (ctx.inLog and ctx.inLog(ex)) then return false, "exclusive", ex end
        end
    end
    return true
end

-- NPCs / objects / items -----------------------------------------------------------------------

function DB.GetNPCByID(npcId)
    local r = npcId and QDB.npcs[npcId]
    if not r then return nil end
    return {
        id = npcId, name = r[N.NAME], minLevel = r[N.MIN_LEVEL], maxLevel = r[N.MAX_LEVEL],
        rank = r[N.RANK] or 0, zone = r[N.ZONE], spawns = r[N.SPAWNS] or EMPTY,
        friendly = r[N.FRIENDLY], subName = r[N.SUBNAME], flags = r[N.FLAGS] or 0, patrols = r[N.PATROLS],
    }
end

function DB.GetNPCName(npcId)
    local r = npcId and QDB.npcs[npcId]
    return r and r[N.NAME]
end

function DB.GetObjectByID(objectId)
    local r = objectId and QDB.objects[objectId]
    if not r then return nil end
    return { id = objectId, name = r[O.NAME], zone = r[O.ZONE], spawns = r[O.SPAWNS] or EMPTY }
end

function DB.GetObjectName(objectId)
    local r = objectId and QDB.objects[objectId]
    return r and r[O.NAME]
end

function DB.GetItemByID(itemId)
    local r = itemId and QDB.items[itemId]
    if not r then return nil end
    return { id = itemId, name = r[I.NAME], npcDrops = r[I.NPC_DROPS] or EMPTY, objectDrops = r[I.OBJECT_DROPS] or EMPTY,
             startQuest = r[I.START_QUEST], vendors = r[I.VENDORS] or EMPTY }
end

function DB.GetItemName(itemId)
    local r = itemId and QDB.items[itemId]
    return r and r[I.NAME]
end

-- Picks the spawn closest to (nearX, nearY) in preferZone, else the first spawn anywhere.
local function pickSpawn(spawns, preferZone, nearX, nearY)
    if not spawns then return nil end
    local zones = {}
    if preferZone and spawns[preferZone] then zones[1] = preferZone end
    for z in pairs(spawns) do if z ~= preferZone then zones[#zones + 1] = z end end
    for _, z in ipairs(zones) do
        local pts = spawns[z]
        if pts and #pts > 0 then
            local best, bestD = pts[1], math.huge
            if nearX and z == preferZone then
                for _, p in ipairs(pts) do
                    local d = (p[1] - nearX) ^ 2 + (p[2] - nearY) ^ 2
                    if d < bestD then best, bestD = p, d end
                end
            end
            return z, best[1], best[2]
        end
    end
end

-- Returns zoneId, x, y (0-100) for an NPC.
function DB.GetNPCPosition(npcId, preferZone, nearX, nearY)
    local r = npcId and QDB.npcs[npcId]
    if not r then return nil end
    return pickSpawn(r[N.SPAWNS], preferZone or r[N.ZONE], nearX, nearY)
end

function DB.GetObjectPosition(objectId, preferZone, nearX, nearY)
    local r = objectId and QDB.objects[objectId]
    if not r then return nil end
    return pickSpawn(r[O.SPAWNS], preferZone or r[O.ZONE], nearX, nearY)
end

-- Best target for a quest objective: objective mobs, objects, item droppers, exploration trigger.
function DB.GetObjectiveLocation(questId, preferZone, nearX, nearY)
    local q = rawQuest(questId)
    if not q then return nil end
    local obj = q[Q.OBJECTIVES] or EMPTY
    for _, id in ipairs(obj.c or EMPTY) do
        local z, x, y = DB.GetNPCPosition(id, preferZone, nearX, nearY)
        if z then return z, x, y, DB.GetNPCName(id) end
    end
    for _, id in ipairs(obj.k or EMPTY) do
        local z, x, y = DB.GetNPCPosition(id, preferZone, nearX, nearY)
        if z then return z, x, y, DB.GetNPCName(id) end
    end
    for _, id in ipairs(obj.o or EMPTY) do
        local z, x, y = DB.GetObjectPosition(id, preferZone, nearX, nearY)
        if z then return z, x, y, DB.GetObjectName(id) end
    end
    for _, itemId in ipairs(obj.i or EMPTY) do
        local it = QDB.items[itemId]
        if it then
            for _, npcId in ipairs(it[I.NPC_DROPS] or EMPTY) do
                local z, x, y = DB.GetNPCPosition(npcId, preferZone, nearX, nearY)
                if z then return z, x, y, DB.GetNPCName(npcId) end
            end
            for _, objId in ipairs(it[I.OBJECT_DROPS] or EMPTY) do
                local z, x, y = DB.GetObjectPosition(objId, preferZone, nearX, nearY)
                if z then return z, x, y, DB.GetObjectName(objId) end
            end
        end
    end
    local trig = q[Q.TRIGGER]
    if trig and trig[2] then
        local z, x, y = pickSpawn(trig[2], preferZone, nearX, nearY)
        if z then return z, x, y, trig[1] end
    end
end

-- Zones ----------------------------------------------------------------------------------------

function DB.ParentZone(areaId)
    local guard = 0
    while areaId and QDB.zones.parent and QDB.zones.parent[areaId] and guard < 8 do
        areaId = QDB.zones.parent[areaId]
        guard = guard + 1
    end
    return areaId
end

function DB.ZoneUiMap(areaId)
    if not areaId then return nil end
    local m = QDB.zones.uiMap and QDB.zones.uiMap[areaId]
    if m and m > 0 then return m end
    local parent = DB.ParentZone(areaId)
    if parent ~= areaId then return DB.ZoneUiMap(parent) end
end

function DB.ZoneName(areaId)
    if not areaId then return nil end
    local n = QDB.zones.names and QDB.zones.names[areaId]
    if n then return n end
    local m = DB.ZoneUiMap(areaId)
    return m and ns.Compat.GetMapName(m) or ("zone " .. areaId)
end

-- Reverse map uiMapId -> areaId (built lazily).
local uiToArea
function DB.AreaForUiMap(uiMapId)
    if not uiToArea then
        uiToArea = {}
        for area, ui in pairs(QDB.zones.uiMap or EMPTY) do
            if not uiToArea[ui] then uiToArea[ui] = area end
        end
    end
    return uiToArea[uiMapId]
end

-- Automation safety metadata -------------------------------------------------------------------

-- Escort / scripted-event wording. Deliberately broad: a false positive only costs one click.
-- "Follow" and "Protect" count only when followed by a name ("Follow Thrall"), so that
-- "follow the road" or "Protection Totems" do not trigger it.
local ESCORT_PATTERNS = {
    "[Ee]scort", "[Aa]ccompany", "[Ss]afely", "[Ll]ead .- back to", "[Pp]rotect %u", "[Ff]ollow %u",
    "[Dd]efend %u", "[Ss]tay alive",
}

local function escortWording(text)
    if type(text) ~= "string" or text == "" then return nil end
    for _, p in ipairs(ESCORT_PATTERNS) do
        if string.find(text, p) then return p end
    end
end
DB.EscortWording = escortWording

-- Returns manual(bool), reason. manual=true means the quest must never be auto-accepted.
-- Conservative by design: any single signal is enough, and a quest we have no data for is manual.
-- `liveText` is the quest text shown by the client on the offer panel (optional).
function DB.GetEscortStatus(questId, liveText)
    if questId and ns.EscortQuests and ns.EscortQuests[questId] then return true, "known escort quest" end
    local extra = ns.db and ns.db.escortExtra
    if questId and type(extra) == "table" and extra[questId] then return true, "on your escort list" end
    if escortWording(liveText) then return true, "escort wording in quest text" end
    local r = rawQuest(questId)
    if not r then return true, "quest not in the database" end
    if ns.HasBit(r[Q.FLAGS] or 0, QDB.QUEST_FLAG_PARTY_ACCEPT) then return true, "escort/event quest (party-accept flag)" end
    if escortWording(r[Q.OBJECTIVES_TEXT]) then return true, "escort wording in objectives" end
    local trig = r[Q.TRIGGER]
    if type(trig) == "table" and escortWording(trig[1]) then return true, "escort wording in objectives" end
    return false
end

function DB.IsRepeatable(questId)
    local r = rawQuest(questId)
    return r and ns.HasBit(r[Q.SPECIAL_FLAGS] or 0, QDB.SPECIAL_FLAG_REPEATABLE) or false
end

-- Item ids a quest needs: collect objectives plus the item the giver hands out.
function DB.GetQuestItems(questId)
    local r = rawQuest(questId)
    if not r then return EMPTY end
    local out = {}
    local obj = r[Q.OBJECTIVES]
    for _, id in ipairs(obj and obj.i or EMPTY) do out[#out + 1] = id end
    local src = r[Q.SOURCE_ITEM]
    if src and src > 0 then out[#out + 1] = src end
    return out
end

-- Item starts a quest (e.g. a dropped letter). Such items are never junk. Upstream TBC item
-- records leave startQuest empty, so the index is built from the quests' START_ITEMS (lazily).
local questStarters
function DB.ItemStartsQuest(itemId)
    if not itemId then return false end
    if not questStarters then
        questStarters = {}
        for _, r in pairs(QDB.quests) do
            for _, it in ipairs(r[Q.START_ITEMS] or EMPTY) do questStarters[it] = true end
        end
    end
    if questStarters[itemId] then return true end
    local r = QDB.items[itemId]
    local s = r and r[I.START_QUEST]
    return type(s) == "number" and s > 0
end
