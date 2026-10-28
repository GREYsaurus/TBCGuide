-- TBCGuide - Paladin talent builds (original recommendations; validated against client talent data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

ns.RegisterTalentBuilds("PALADIN", {
    {
        id = "paladin_ret_leveling", name = "Retribution (leveling)", kind = "leveling", role = "Solo DPS",
        summary = "Two-handed Retribution: Seal of Command early, Crusader Strike at 52. The last points go into Holy for strength, intellect and a stronger Seal of Righteousness.",
        notes = {
            "Seal of Command plus a slow two-hander is the backbone of leveling as Ret.",
            "Benediction and Improved Judgement keep your mana up, which matters more than raw damage at low levels.",
        },
        picks = {
            { "Benediction", 5, "Cheaper seals and judgements: less drinking." },
            { "Improved Judgement", 2 },
            { "Deflection", 3 },
            { "Conviction", 5 },
            { "Seal of Command", 1, "Your main seal from level 20." },
            { "Crusade", 3 },
            { "Pursuit of Justice", 1 },
            { "Two-Handed Weapon Specialization", 3 },
            { "Sanctity Aura", 1 },
            { "Improved Sanctity Aura", 2 },
            { "Vengeance", 5 },
            { "Sanctified Seals", 3 },
            { "Divine Purpose", 3 },
            { "Repentance", 1 },
            { "Fanaticism", 5 },
            { "Crusader Strike", 1 },
            { "Divine Strength", 5 },
            { "Divine Intellect", 5 },
            { "Improved Seal of Righteousness", 5 },
            { "Healing Light", 2 },
        },
    },
    {
        id = "paladin_holy_70", name = "Holy (level 70 healer)", kind = "endgame", role = "Healer",
        summary = "Deep Holy with Illumination, Holy Shock and Divine Illumination. Protection supplies Blessing of Kings and Improved Concentration Aura.",
        notes = {
            "Flash of Light is your efficient main heal. Holy Light and Divine Favor are for big hits.",
            "Stack spell damage/healing, intellect and crit. Illumination refunds mana on crits.",
        },
        picks = {
            { "Divine Intellect", 5 }, { "Spiritual Focus", 5 }, { "Healing Light", 3 }, { "Improved Lay on Hands", 2 },
            { "Illumination", 5 }, { "Improved Blessing of Wisdom", 2 }, { "Divine Favor", 1 }, { "Sanctified Light", 3 },
            { "Holy Power", 5 }, { "Light's Grace", 3 }, { "Holy Shock", 1 }, { "Holy Guidance", 5 },
            { "Divine Illumination", 1 },
            { "Improved Devotion Aura", 5 }, { "Guardian's Favor", 2 }, { "Toughness", 5 }, { "Blessing of Kings", 1 },
            { "Anticipation", 2 }, { "Improved Concentration Aura", 3 }, { "Stoicism", 2 },
        },
    },
    {
        id = "paladin_prot_70", name = "Protection (level 70 tank)", kind = "endgame", role = "Tank",
        summary = "Deep Protection with Avenger's Shield, plus Holy for intellect and a stronger Seal of Righteousness. Paladins are the best multi-target tanks in TBC.",
        notes = {
            "Keep Holy Shield and Righteous Fury up. Consecration is your main AoE threat.",
            "Reach 490 defense first, then stamina and spell damage for threat.",
        },
        picks = {
            { "Redoubt", 5 }, { "Precision", 3 }, { "Toughness", 5 }, { "Blessing of Kings", 1 },
            { "Improved Righteous Fury", 3 }, { "Anticipation", 5 }, { "Stoicism", 2 }, { "Spell Warding", 2 },
            { "Blessing of Sanctuary", 1 }, { "Sacred Duty", 2 }, { "One-Handed Weapon Specialization", 5 },
            { "Holy Shield", 1 }, { "Improved Holy Shield", 2 }, { "Ardent Defender", 5 }, { "Combat Expertise", 5 },
            { "Avenger's Shield", 1 },
            { "Divine Intellect", 5 }, { "Improved Seal of Righteousness", 5 }, { "Healing Light", 3 },
        },
    },
})
