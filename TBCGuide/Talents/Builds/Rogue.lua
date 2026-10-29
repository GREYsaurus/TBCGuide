-- TBCGuide - Assassination Rogue talent plan (TBCGuide's own; validated against client talent data)
-- The Icy Veins TBC leveling index has no Assassination guide and its Rogue PvE builds page lists only
-- Combat builds, so this plan is the one not taken from Icy Veins (docs/TALENTS.md).
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

ns.RegisterTalentBuilds("ROGUE", {
    {
        id = "rogue_mutilate_70", name = "Mutilate (TBCGuide plan)", kind = "leveling", role = "Melee DPS",
        source = { site = "TBCGuide", order = "TBCGuide", note = "No Assassination build on Icy Veins' TBC leveling index or Rogue PvE builds page." },
        summary = "Assassination with Mutilate, Seal Fate and Find Weakness, plus Combat for Precision and Dagger Specialization. Use it when you have two good daggers.",
        notes = {
            "Mutilate builds 2+ combo points per use. Keep Slice and Dice up and use Envenom or Rupture as finishers.",
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
