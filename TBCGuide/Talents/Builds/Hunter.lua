-- TBCGuide - Hunter talent builds (original recommendations; validated against client talent data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

ns.RegisterTalentBuilds("HUNTER", {
    {
        id = "hunter_bm_leveling", name = "Beast Mastery (leveling)", kind = "leveling", role = "Solo DPS",
        summary = "Pet-focused Beast Mastery. Your pet tanks and deals much of your damage, and you get Bestial Wrath at 40 and The Beast Within at 54. Marksmanship fills the rest.",
        notes = {
            "Keep your pet fed and at your level. Unleashed Fury, Ferocity and Frenzy all scale its damage.",
            "Bestial Swiftness makes your pet much better at catching runners.",
        },
        picks = {
            { "Improved Aspect of the Hawk", 5, "Big ranged attack speed boost on procs." },
            { "Focused Fire", 2 },
            { "Thick Hide", 3 },
            { "Bestial Swiftness", 1 },
            { "Unleashed Fury", 5 },
            { "Improved Mend Pet", 2 },
            { "Ferocity", 5 },
            { "Spirit Bond", 2 },
            { "Intimidation", 1 },
            { "Bestial Discipline", 2 },
            { "Animal Handler", 2 },
            { "Frenzy", 5 },
            { "Ferocious Inspiration", 3 },
            { "Bestial Wrath", 1 },
            { "Serpent's Swiftness", 5 },
            { "The Beast Within", 1 },
            { "Lethal Shots", 5 },
            { "Efficiency", 5 },
            { "Go for the Throat", 2 },
            { "Aimed Shot", 1 },
            { "Rapid Killing", 2 },
            { "Mortal Shots", 1 },
        },
    },
    {
        id = "hunter_bm_70", name = "Beast Mastery (level 70 DPS)", kind = "endgame", role = "Ranged DPS",
        summary = "41/20 Beast Mastery/Marksmanship: The Beast Within and Ferocious Inspiration for the group, Mortal Shots and Go for the Throat from Marksmanship.",
        notes = {
            "Use Steady Shot weaving between auto shots. Keep Hunter's Mark and Aspect of the Hawk/Viper up.",
            "A cat or ravager pet with Bite and Claw is a strong default.",
        },
        picks = {
            { "Improved Aspect of the Hawk", 5 }, { "Focused Fire", 2 }, { "Thick Hide", 3 }, { "Bestial Swiftness", 1 },
            { "Unleashed Fury", 5 }, { "Ferocity", 5 }, { "Intimidation", 1 }, { "Bestial Discipline", 2 },
            { "Spirit Bond", 1 }, { "Animal Handler", 2 }, { "Frenzy", 5 }, { "Ferocious Inspiration", 3 },
            { "Bestial Wrath", 1 }, { "Serpent's Swiftness", 4 }, { "The Beast Within", 1 },
            { "Lethal Shots", 5 }, { "Improved Hunter's Mark", 5 }, { "Go for the Throat", 2 }, { "Aimed Shot", 1 },
            { "Rapid Killing", 2 }, { "Mortal Shots", 5 },
        },
    },
})
