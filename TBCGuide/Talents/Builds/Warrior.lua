-- TBCGuide - Warrior talent builds (original recommendations; validated against client talent data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Picks are in spending order: { "Talent name", points, "optional note on the first point" }.
-- The first pick is spent at level 10, then one point per level up to 61 points at 70.

local _, ns = ...

ns.RegisterTalentBuilds("WARRIOR", {
    {
        id = "warrior_arms_leveling", name = "Arms (leveling)", kind = "leveling", role = "Solo DPS",
        summary = "Two-handed Arms build for questing. Deep Wounds and Impale for burst, Mortal Strike at 40 and Endless Rage at 54. The last points go into Fury for crit and shout uptime.",
        notes = {
            "Use the slowest, highest-damage two-hander you can find.",
            "Pick the weapon specialization that matches your weapon. This build assumes axes or polearms (Poleaxe Specialization); swap for Sword or Mace if needed.",
            "Second Wind and Anger Management give you resources while questing.",
        },
        picks = {
            { "Improved Heroic Strike", 3, "Cheaper Heroic Strike - your main rage dump." },
            { "Deflection", 2 },
            { "Improved Rend", 3 },
            { "Improved Charge", 2, "More rage to open each pull." },
            { "Improved Thunder Clap", 3 },
            { "Anger Management", 1 },
            { "Deep Wounds", 3, "Big passive damage boost on crits." },
            { "Improved Overpower", 2 },
            { "Two-Handed Weapon Specialization", 5 },
            { "Impale", 2 },
            { "Poleaxe Specialization", 5 },
            { "Death Wish", 1 },
            { "Improved Intercept", 2 },
            { "Mortal Strike", 1, "Core ability from level 40." },
            { "Second Wind", 2 },
            { "Blood Frenzy", 2 },
            { "Improved Mortal Strike", 5 },
            { "Endless Rage", 1 },
            { "Cruelty", 5 },
            { "Unbridled Wrath", 5 },
            { "Commanding Presence", 5 },
            { "Blood Craze", 1 },
        },
    },
    {
        id = "warrior_fury_70", name = "Fury (level 70 raid DPS)", kind = "endgame", role = "Melee DPS",
        summary = "Standard TBC dual-wield Fury build: Arms for Impale and Deep Wounds, Fury down to Rampage.",
        notes = {
            "Respec at 70 once you have two good one-handed weapons. This build is much weaker with poor gear.",
            "Rotation priority: Bloodthirst > Whirlwind > Heroic Strike or Cleave as a rage dump. Keep Rampage up.",
        },
        picks = {
            { "Improved Heroic Strike", 3 }, { "Deflection", 2 }, { "Improved Rend", 3 }, { "Improved Charge", 2 },
            { "Anger Management", 1 }, { "Deep Wounds", 3 }, { "Iron Will", 1 }, { "Impale", 2 },
            { "Cruelty", 5 }, { "Unbridled Wrath", 5 }, { "Commanding Presence", 5 },
            { "Dual Wield Specialization", 5 }, { "Enrage", 5 },
            { "Sweeping Strikes", 1 }, { "Weapon Mastery", 2 }, { "Flurry", 5 },
            { "Precision", 3 }, { "Bloodthirst", 1 }, { "Improved Whirlwind", 1 },
            { "Improved Berserker Stance", 5 }, { "Rampage", 1 },
        },
    },
    {
        id = "warrior_prot_70", name = "Protection (level 70 tank)", kind = "endgame", role = "Tank",
        summary = "Deep Protection build with Devastate. It gives threat, avoidance and the cooldowns you need for heroics and raids.",
        notes = {
            "Use a one-handed weapon and a shield. Stack defense to 490 (the crit cap) before going into heroics.",
            "Threat rotation: Shield Slam > Revenge > Devastate. Keep Thunder Clap and Demoralizing Shout up.",
        },
        picks = {
            { "Improved Heroic Strike", 3 }, { "Deflection", 2 },
            { "Cruelty", 5 }, { "Improved Demoralizing Shout", 5 }, { "Commanding Presence", 5 },
            { "Tactical Mastery", 3 }, { "Anticipation", 5 }, { "Shield Specialization", 5 },
            { "Defiance", 3 }, { "Improved Revenge", 3 }, { "Last Stand", 1 }, { "Improved Shield Block", 1 },
            { "Improved Sunder Armor", 3 }, { "Concussion Blow", 1 }, { "Shield Mastery", 3 },
            { "One-Handed Weapon Specialization", 5 }, { "Improved Defensive Stance", 3 }, { "Shield Slam", 1 },
            { "Focused Rage", 3 }, { "Devastate", 1 },
        },
    },
})
