-- TBCGuide - Druid talent builds (original recommendations; validated against client talent data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

ns.RegisterTalentBuilds("DRUID", {
    {
        id = "druid_feral_leveling", name = "Feral (leveling, cat and bear)", kind = "leveling", role = "Solo DPS / Tank",
        summary = "Feral with Furor early for cheap shifting, Feral Charge, Leader of the Pack and Mangle. Restoration supplies Naturalist and Omen of Clarity. It works as a cat for questing and a bear for dungeons, and is a fine level-70 feral build.",
        notes = {
            "Cat Form for questing: Prowl, then Ravage or Pounce. Claw or Shred to 5 combo points, then Rip or Ferocious Bite.",
            "Furor at 5/5 gives energy or rage on every shift, so powershift when you run out.",
        },
        picks = {
            { "Ferocity", 5, "Cheaper Maul, Swipe and Claw." },
            { "Feral Instinct", 3 },
            { "Brutal Impact", 2 },
            { "Feral Swiftness", 2 },
            { "Feral Charge", 1 },
            { "Sharpened Claws", 3 },
            { "Shredding Attacks", 2 },
            { "Predatory Strikes", 3 },
            { "Primal Fury", 2 },
            { "Savage Fury", 2 },
            { "Faerie Fire (Feral)", 1 },
            { "Heart of the Wild", 5 },
            { "Survival of the Fittest", 3 },
            { "Leader of the Pack", 1 },
            { "Improved Leader of the Pack", 2 },
            { "Predatory Instincts", 5 },
            { "Mangle", 1 },
            { "Furor", 5 },
            { "Naturalist", 5 },
            { "Natural Shapeshifter", 3 },
            { "Omen of Clarity", 1 },
            { "Intensity", 3 },
            { "Improved Mark of the Wild", 1 },
        },
    },
    {
        id = "druid_balance_70", name = "Balance (level 70 DPS)", kind = "endgame", role = "Ranged DPS",
        summary = "Moonkin with Wrath of Cenarius and Force of Nature. Restoration adds Intensity and Omen of Clarity.",
        notes = { "Starfire is your main spell. Keep Insect Swarm and Moonfire up when the fight is long enough." },
        picks = {
            { "Starlight Wrath", 5 }, { "Focused Starlight", 2 }, { "Improved Moonfire", 2 }, { "Control of Nature", 3 },
            { "Insect Swarm", 1 }, { "Nature's Reach", 2 }, { "Vengeance", 5 }, { "Celestial Focus", 2 },
            { "Lunar Guidance", 3 }, { "Nature's Grace", 1 }, { "Moonglow", 1 }, { "Moonfury", 5 }, { "Balance of Power", 2 },
            { "Dreamstate", 3 }, { "Moonkin Form", 1 }, { "Improved Faerie Fire", 3 }, { "Wrath of Cenarius", 5 },
            { "Force of Nature", 1 },
            { "Improved Mark of the Wild", 5 }, { "Naturalist", 5 }, { "Intensity", 3 }, { "Omen of Clarity", 1 },
        },
    },
})
