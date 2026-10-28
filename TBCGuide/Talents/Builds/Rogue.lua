-- TBCGuide - Rogue talent builds (original recommendations; validated against client talent data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

ns.RegisterTalentBuilds("ROGUE", {
    {
        id = "rogue_combat_leveling", name = "Combat Swords (leveling)", kind = "leveling", role = "Solo DPS",
        summary = "Combat with swords: Precision, Dual Wield Specialization, Sword Specialization, Blade Flurry and Adrenaline Rush, then Combat Potency and Surprise Attacks. Assassination supplies Malice and Lethality. This build also works at 70.",
        notes = {
            "Use a slow main-hand sword and a fast off-hand. Swap Sword Specialization for Mace or Fist if your weapons demand it.",
            "Sinister Strike to build combo points, Slice and Dice always up, Eviscerate to finish low-health targets.",
        },
        picks = {
            { "Improved Sinister Strike", 2, "Cheaper Sinister Strike - your main attack." },
            { "Lightning Reflexes", 5 },
            { "Precision", 5 },
            { "Improved Slice and Dice", 3 },
            { "Dual Wield Specialization", 5 },
            { "Sword Specialization", 5 },
            { "Blade Flurry", 1 },
            { "Weapon Expertise", 2 },
            { "Aggression", 3 },
            { "Vitality", 2 },
            { "Adrenaline Rush", 1 },
            { "Endurance", 2 },
            { "Combat Potency", 5 },
            { "Surprise Attacks", 1 },
            { "Malice", 5 },
            { "Ruthlessness", 3 },
            { "Murder", 2 },
            { "Relentless Strikes", 1 },
            { "Lethality", 5 },
            { "Vile Poisons", 3 },
        },
    },
    {
        id = "rogue_mutilate_70", name = "Mutilate (level 70 dagger DPS)", kind = "endgame", role = "Melee DPS",
        summary = "Assassination with Mutilate, Seal Fate and Find Weakness, plus Combat for Precision and Dagger Specialization. Use it when you have two good daggers.",
        notes = {
            "Mutilate builds 2+ combo points per use. Keep Slice and Dice up and use Envenom or Rupture as finishers.",
            "Combat Swords (the leveling build) is the alternative if you have swords or maces.",
        },
        picks = {
            { "Malice", 5 }, { "Ruthlessness", 3 }, { "Murder", 2 }, { "Puncturing Wounds", 3 }, { "Relentless Strikes", 1 },
            { "Lethality", 5 }, { "Vile Poisons", 5 }, { "Cold Blood", 1 }, { "Quick Recovery", 2 }, { "Seal Fate", 5 },
            { "Master Poisoner", 2 }, { "Vigor", 1 }, { "Find Weakness", 5 }, { "Mutilate", 1 },
            { "Lightning Reflexes", 5 }, { "Precision", 5 }, { "Improved Slice and Dice", 3 }, { "Improved Sinister Strike", 2 },
            { "Dagger Specialization", 5 },
        },
    },
})
