-- TBCGuide - Mage talent builds (original recommendations; validated against client talent data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

ns.RegisterTalentBuilds("MAGE", {
    {
        id = "mage_frost_leveling", name = "Frost (leveling / AoE)", kind = "leveling", role = "Solo DPS",
        summary = "Frost with Improved Blizzard early for AoE grinding, Ice Barrier, Empowered Frostbolt and the Water Elemental. Arcane provides Arcane Concentration and mana regeneration.",
        notes = {
            "From around 22, gather a pack and use Frost Nova, Blizzard and Cone of Cold. This is very fast in the right spots.",
            "Single target: Frostbolt to range, Nova, back off, Frostbolt again.",
        },
        picks = {
            { "Improved Frostbolt", 5, "Faster Frostbolt casts." },
            { "Ice Shards", 5 },
            { "Piercing Ice", 3 },
            { "Improved Blizzard", 3, "Slows packs for AoE grinding." },
            { "Icy Veins", 1 },
            { "Improved Frost Nova", 2 },
            { "Frost Channeling", 3 },
            { "Cold Snap", 1 },
            { "Improved Cone of Cold", 3 },
            { "Ice Floes", 2 },
            { "Permafrost", 2 },
            { "Ice Barrier", 1 },
            { "Arctic Winds", 4 },
            { "Empowered Frostbolt", 5 },
            { "Summon Water Elemental", 1 },
            { "Arcane Subtlety", 2 },
            { "Arcane Focus", 3 },
            { "Arcane Concentration", 5 },
            { "Wand Specialization", 2 },
            { "Arcane Fortitude", 1 },
            { "Magic Attunement", 2 },
            { "Arcane Meditation", 3 },
            { "Improved Mana Shield", 2 },
        },
    },
    {
        id = "mage_fire_70", name = "Fire (level 70 raid DPS)", kind = "endgame", role = "Ranged DPS",
        summary = "Deep Fire with Empowered Fireball, Molten Fury and Dragon's Breath, plus Arcane Concentration from Arcane.",
        notes = {
            "Keep Improved Scorch stacks up if no other mage does. Fireball is your main spell.",
            "Frost (the leveling build) is better for heroics and solo play.",
        },
        picks = {
            { "Arcane Subtlety", 2 }, { "Arcane Focus", 3 }, { "Arcane Concentration", 5 },
            { "Improved Fireball", 5 }, { "Ignite", 5 }, { "Incineration", 2 }, { "Pyroblast", 1 }, { "Flame Throwing", 2 },
            { "Improved Scorch", 3 }, { "Master of Elements", 3 }, { "Playing with Fire", 3 }, { "Critical Mass", 3 },
            { "Blast Wave", 1 }, { "Fire Power", 5 }, { "Pyromaniac", 3 }, { "Combustion", 1 }, { "Molten Fury", 2 },
            { "Empowered Fireball", 5 }, { "Dragon's Breath", 1 }, { "Impact", 3 },
            { "Elemental Precision", 3 },
        },
    },
})
