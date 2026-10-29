-- TBCGuide - leveling dungeons and their usual level ranges (for "Select Recommended Dungeons")
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Names match the [dungeon=...] tags in guides-src (the instance names in the bundled zone table).
-- Ranges are the commonly quoted "level to run it" bands, approximate; they only decide which
-- dungeons "Select Recommended" turns on. Faction-only dungeons say so.

local _, ns = ...

ns.Dungeons = {
    { name = "Ragefire Chasm", min = 13, max = 18, faction = "Horde" },
    { name = "Wailing Caverns", min = 17, max = 24 },
    { name = "The Deadmines", min = 17, max = 26, faction = "Alliance" },
    { name = "Shadowfang Keep", min = 22, max = 30 },
    { name = "Blackfathom Deeps", min = 24, max = 32 },
    { name = "The Stockade", min = 24, max = 32, faction = "Alliance" },
    { name = "Gnomeregan", min = 29, max = 38 },
    { name = "Razorfen Kraul", min = 29, max = 38 },
    { name = "Scarlet Monastery", min = 34, max = 45 },
    { name = "Razorfen Downs", min = 37, max = 46 },
    { name = "Uldaman", min = 41, max = 51 },
    { name = "Zul'Farrak", min = 42, max = 46 },
    { name = "Maraudon", min = 46, max = 55 },
    { name = "The Temple of Atal'Hakkar", min = 50, max = 56 },
    { name = "Blackrock Depths", min = 52, max = 60 },
    { name = "Dire Maul", min = 55, max = 60 },
    { name = "Blackrock Spire", min = 55, max = 60 },
    { name = "Scholomance", min = 58, max = 60 },
    { name = "Stratholme", min = 58, max = 60 },
    { name = "Hellfire Ramparts", min = 59, max = 62 },
    { name = "The Blood Furnace", min = 60, max = 63 },
    { name = "The Slave Pens", min = 61, max = 64 },
    { name = "The Underbog", min = 62, max = 65 },
    { name = "Mana-Tombs", min = 63, max = 66 },
    { name = "Auchenai Crypts", min = 64, max = 67 },
    { name = "Old Hillsbrad Foothills", min = 66, max = 68 },
    { name = "Sethekk Halls", min = 67, max = 69 },
    { name = "The Mechanar", min = 68, max = 70 },
    { name = "The Botanica", min = 69, max = 70 },
    { name = "The Steamvault", min = 69, max = 70 },
    { name = "Shadow Labyrinth", min = 69, max = 70 },
    { name = "The Shattered Halls", min = 69, max = 70 },
    { name = "The Arcatraz", min = 70, max = 70 },
    { name = "The Black Morass", min = 70, max = 70 },
}

-- Dungeons for a faction, in level order.
function ns.DungeonsFor(faction)
    local out = {}
    for _, d in ipairs(ns.Dungeons) do
        if not d.faction or d.faction == faction then out[#out + 1] = d end
    end
    return out
end

-- Recommended now: not outleveled, and starting within 8 levels of the character.
function ns.DungeonRecommended(d, level)
    return d.max >= level and d.min <= level + 8
end

-- Whether any guide has quests tagged for this dungeon.
function ns.DungeonHasQuests(name)
    for _, g in ipairs(ns.Guides and ns.Guides.list or {}) do
        for _, s in ipairs(g.steps) do if s.dungeon == name then return true end end
    end
    return false
end
