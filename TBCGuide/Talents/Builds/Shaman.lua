-- TBCGuide - Shaman talent builds (original recommendations; validated against client talent data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

ns.RegisterTalentBuilds("SHAMAN", {
    {
        id = "shaman_enh_leveling", name = "Enhancement (leveling)", kind = "leveling", role = "Solo DPS",
        summary = "Enhancement with a two-hander until Dual Wield at 41, Stormstrike, Unleashed Rage and Shamanistic Rage. Elemental adds Convection and Concussion for stronger shocks.",
        notes = {
            "Use Windfury Weapon from 30 on a slow two-hander. Earth Shock interrupts casters.",
            "Shamanistic Rage removes most of your mana problems from level 50.",
        },
        picks = {
            { "Ancestral Knowledge", 5 },
            { "Thundering Strikes", 5 },
            { "Shamanistic Focus", 1 },
            { "Enhancing Totems", 2 },
            { "Improved Ghost Wolf", 2 },
            { "Flurry", 5, "Large attack speed boost after crits." },
            { "Spirit Weapons", 1 },
            { "Elemental Weapons", 3 },
            { "Toughness", 1 },
            { "Weapon Mastery", 5 },
            { "Stormstrike", 1 },
            { "Dual Wield", 1, "Available at level 40: switch to two one-handers." },
            { "Dual Wield Specialization", 3 },
            { "Unleashed Rage", 5 },
            { "Shamanistic Rage", 1 },
            { "Convection", 5 },
            { "Concussion", 5 },
            { "Call of Flame", 3 },
            { "Elemental Focus", 1 },
            { "Reverberation", 1 },
            { "Elemental Devastation", 3 },
            { "Improved Fire Totems", 2 },
        },
    },
    {
        id = "shaman_ele_70", name = "Elemental (level 70 DPS)", kind = "endgame", role = "Ranged DPS",
        summary = "Elemental with Lightning Overload and Totem of Wrath, plus Restoration for Totemic Focus and Nature's Guidance.",
        notes = { "Lightning Bolt spam. Use Chain Lightning on cooldown, and Elemental Mastery for burst." },
        picks = {
            { "Convection", 5 }, { "Concussion", 5 }, { "Call of Flame", 3 }, { "Elemental Focus", 1 }, { "Reverberation", 5 },
            { "Call of Thunder", 5 }, { "Elemental Fury", 1 }, { "Unrelenting Storm", 5 }, { "Elemental Precision", 3 },
            { "Lightning Mastery", 5 }, { "Elemental Mastery", 1 }, { "Lightning Overload", 5 }, { "Totem of Wrath", 1 },
            { "Tidal Focus", 5 }, { "Totemic Focus", 5 }, { "Nature's Guidance", 3 }, { "Totemic Mastery", 1 }, { "Healing Grace", 2 },
        },
    },
    {
        id = "shaman_resto_70", name = "Restoration (level 70 healer)", kind = "endgame", role = "Healer",
        summary = "Restoration with Mana Tide Totem, Nature's Blessing, Improved Chain Heal and Earth Shield.",
        notes = { "Chain Heal is your bread and butter. Keep Earth Shield on the tank." },
        picks = {
            { "Improved Healing Wave", 5 }, { "Tidal Focus", 5 }, { "Totemic Focus", 5 }, { "Nature's Guidance", 3 },
            { "Tidal Mastery", 5 }, { "Restorative Totems", 5 }, { "Healing Way", 3 }, { "Nature's Swiftness", 1 },
            { "Purification", 5 }, { "Mana Tide Totem", 1 }, { "Nature's Blessing", 3 }, { "Improved Chain Heal", 2 },
            { "Earth Shield", 1 },
            { "Ancestral Knowledge", 5 }, { "Guardian Totems", 2 }, { "Thundering Strikes", 3 }, { "Shamanistic Focus", 1 },
            { "Anticipation", 4 }, { "Toughness", 2 },
        },
    },
})
