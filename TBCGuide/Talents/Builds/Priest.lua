-- TBCGuide - Priest talent builds (original recommendations; validated against client talent data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

ns.RegisterTalentBuilds("PRIEST", {
    {
        id = "priest_shadow_leveling", name = "Shadow (leveling)", kind = "leveling", role = "Solo DPS",
        summary = "Shadow with Spirit Tap early, Mind Flay, Shadowform at 40, Misery and Vampiric Touch. Discipline gives Wand Specialization and better shields. This build is also a solid level-70 shadow build.",
        notes = {
            "Spirit Tap plus wand finishing keeps you drinking very little at low levels.",
            "Vampiric Embrace and Vampiric Touch make you and your group self-sustaining in Outland.",
        },
        picks = {
            { "Spirit Tap", 5, "Huge mana regeneration after kills." },
            { "Improved Shadow Word: Pain", 2 },
            { "Shadow Focus", 3 },
            { "Improved Mind Blast", 5 },
            { "Mind Flay", 1, "Your main filler." },
            { "Shadow Reach", 2 },
            { "Shadow Weaving", 2 },
            { "Vampiric Embrace", 1 },
            { "Improved Vampiric Embrace", 2 },
            { "Shadow Focus", 2 },
            { "Darkness", 5 },
            { "Shadowform", 1 },
            { "Shadow Power", 5 },
            { "Misery", 5 },
            { "Vampiric Touch", 1 },
            { "Wand Specialization", 5 },
            { "Improved Power Word: Shield", 3 },
            { "Martyrdom", 2 },
            { "Inner Focus", 1 },
            { "Meditation", 3 },
            { "Improved Power Word: Fortitude", 1 },
            { "Mental Agility", 4 },
        },
    },
    {
        id = "priest_holy_70", name = "Holy (level 70 healer)", kind = "endgame", role = "Healer",
        summary = "Holy with Spiritual Guidance, Empowered Healing and Circle of Healing. Discipline adds mana efficiency.",
        notes = {
            "Use Greater Heal for tanks, Circle of Healing and Prayer of Healing for groups, and Renew for movement.",
            "Shadow (the leveling build) is a strong level-70 alternative for DPS and as a mana battery.",
        },
        picks = {
            { "Improved Renew", 3 }, { "Healing Focus", 2 }, { "Divine Fury", 5 }, { "Inspiration", 3 },
            { "Holy Nova", 1 }, { "Holy Specialization", 3 }, { "Improved Healing", 3 }, { "Spiritual Guidance", 5 },
            { "Spirit of Redemption", 1 }, { "Spiritual Healing", 5 }, { "Holy Concentration", 3 },
            { "Blessed Resilience", 1 }, { "Empowered Healing", 5 }, { "Circle of Healing", 1 },
            { "Wand Specialization", 5 }, { "Improved Power Word: Fortitude", 2 }, { "Improved Power Word: Shield", 3 },
            { "Meditation", 3 }, { "Inner Focus", 1 }, { "Absolution", 1 }, { "Mental Agility", 5 },
        },
    },
})
