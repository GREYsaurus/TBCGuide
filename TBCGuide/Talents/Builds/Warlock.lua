-- TBCGuide - Warlock talent builds (original recommendations; validated against client talent data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

ns.RegisterTalentBuilds("WARLOCK", {
    {
        id = "warlock_aff_leveling", name = "Affliction (leveling)", kind = "leveling", role = "Solo DPS",
        summary = "DoT-and-drain Affliction with Siphon Life, Dark Pact and Unstable Affliction. Demonology adds pet durability and Fel Domination.",
        notes = {
            "Corruption, Curse of Agony and Siphon Life on everything, then Drain Life. Life Tap instead of drinking.",
            "Nightfall procs give instant Shadow Bolts - use them.",
        },
        picks = {
            { "Improved Corruption", 5, "Instant Corruption at 5/5." },
            { "Improved Drain Soul", 2 },
            { "Improved Life Tap", 2 },
            { "Soul Siphon", 2 },
            { "Improved Curse of Agony", 2 },
            { "Amplify Curse", 1 },
            { "Fel Concentration", 1 },
            { "Nightfall", 2 },
            { "Empowered Corruption", 3 },
            { "Siphon Life", 1 },
            { "Grim Reach", 2 },
            { "Shadow Embrace", 2 },
            { "Shadow Mastery", 5 },
            { "Dark Pact", 1 },
            { "Contagion", 5 },
            { "Malediction", 3 },
            { "Improved Howl of Terror", 1 },
            { "Unstable Affliction", 1 },
            { "Demonic Embrace", 5 },
            { "Improved Health Funnel", 2 },
            { "Fel Intellect", 3 },
            { "Fel Domination", 1 },
            { "Fel Stamina", 3 },
            { "Demonic Aegis", 1 },
            { "Master Summoner", 2 },
            { "Unholy Power", 3 },
        },
    },
    {
        id = "warlock_destro_70", name = "Destruction (level 70 raid DPS)", kind = "endgame", role = "Ranged DPS",
        summary = "Shadow-bolt Destruction with Demonic Sacrifice (sacrifice the Succubus). Shadow and Flame and Improved Shadow Bolt do the heavy lifting.",
        notes = {
            "Sacrifice your Succubus for the shadow damage buff, then spam Shadow Bolt and keep your curse up.",
            "Affliction (the leveling build) is better for solo play and some raid compositions.",
        },
        picks = {
            { "Demonic Embrace", 5 }, { "Fel Intellect", 3 }, { "Improved Health Funnel", 2 }, { "Fel Domination", 1 },
            { "Demonic Aegis", 3 }, { "Fel Stamina", 1 }, { "Master Summoner", 2 }, { "Unholy Power", 3 },
            { "Demonic Sacrifice", 1 },
            { "Improved Shadow Bolt", 5 }, { "Bane", 5 }, { "Devastation", 5 }, { "Cataclysm", 3 },
            { "Destructive Reach", 2 }, { "Ruin", 1 }, { "Intensity", 2 }, { "Pyroclasm", 2 }, { "Nether Protection", 3 },
            { "Improved Searing Pain", 2 }, { "Backlash", 3 }, { "Soul Leech", 2 }, { "Shadow and Flame", 5 },
        },
    },
})
