-- TBCGuide - project-owned corrections applied over the imported quest database
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Use this file for fixes that are specific to the TBC Anniversary client or realm ruleset and
-- that do not belong upstream. Each entry is { questId, field, value, reason, verifiedBy }.
-- Fields use the names in ns.QDB.QUEST (Schema.lua). Entries are applied once at load.
-- Do NOT add values you have not verified in game or from a primary source.

local _, ns = ...

ns.QDB.overrides = {
    quests = {
        -- Example (kept as documentation, intentionally empty):
        -- { 9407, "REQ_LEVEL", 58, "Dark Portal level gate on Anniversary realms", "in-game 2026-xx-xx" },
    },
    npcs = {},
}

function ns.QDB:ApplyOverrides()
    local Q = ns.QDB.QUEST
    for _, o in ipairs(self.overrides.quests) do
        local rec, field = self.quests[o[1]], Q[o[2]]
        if rec and field then rec[field] = o[3] end
    end
    local N = ns.QDB.NPC
    for _, o in ipairs(self.overrides.npcs) do
        local rec, field = self.npcs[o[1]], N[o[2]]
        if rec and field then rec[field] = o[3] end
    end
end
