-- TBCGuide - Assassination Rogue talent plan (Wowhead TBC leveling build; validated against client talent data)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Source: Wowhead, "Assassination Rogue Leveling Guide - TBC Classic"
-- (https://www.wowhead.com/tbc/guide/classes/rogue/assassination/leveling-tips), read 2026-10-29. The
-- Icy Veins leveling index has no Assassination guide; Wowhead was approved for this one profile.
--   * Levels 10-60: the source gives the level-60 build only (talent calculator rogue/
--     205323105002132501051-005-05, 41/5/5). The order of those 51 points is TBCGuide's own, chosen
--     to reach Mutilate at 50 and to keep every point legal.
--   * Levels 61-69: the source's own order (Precision 61-65, Improved Slice and Dice 66-68,
--     Improved Eviscerate 69).
--   * Level 70: the source says to respec into a level-70 build. TBCGuide never respecs; the 61st
--     point (Remorseless Attacks 1/2) is TBCGuide's choice so the plan stays continuous.
-- Picks are client talent ids {talentId, points}; names are for reading only.

local _, ns = ...

ns.RegisterTalentBuilds("ROGUE", {
    {
        id = "rogue_assassination_wh", name = "Assassination (Wowhead leveling)", kind = "leveling", role = "Melee DPS",
        summary = "Wowhead's TBC Assassination leveling build (41/5/5 at 60), then its 61-69 picks (41/13/5 plus one point at 70).",
        notes = {
            "Mutilate needs two daggers and you behind the target; slower daggers (about 1.7 speed or more) hit harder with it.",
            "Points 10-60 follow TBCGuide's order towards the source's level-60 build; the source only shows the finished build.",
            "At 70 the source suggests a respec. TBCGuide places the last point instead and never respecs for you.",
        },
        source = { site = "Wowhead", url = "https://www.wowhead.com/tbc/guide/classes/rogue/assassination/leveling-tips",
            build = "rogue/205323105002132501051-005-05 (level 60) + levels 61-69 list", order = "derived 10-60, source 61-69, derived 70" },
        picks = {
            { 270, 5 }, -- Malice (10-14)
            { 273, 3 }, -- Ruthlessness (15-17)
            { 274, 2 }, -- Murder (18-19)
            { 281, 1 }, -- Relentless Strikes (20)
            { 269, 5 }, -- Lethality (21-25)
            { 277, 3 }, -- Puncturing Wounds (26-28)
            { 276, 2 }, -- Improved Eviscerate 2/3 (29-30)
            { 280, 1 }, -- Cold Blood (31)
            { 279, 3 }, -- Improved Kidney Shot (32-34)
            { 283, 5 }, -- Seal Fate (35-39)
            { 382, 1 }, -- Vigor (40)
            { 1762, 2 }, -- Quick Recovery (41-42)
            { 1721, 2 }, -- Fleet Footed (43-44)
            { 1718, 5 }, -- Find Weakness (45-49)
            { 1719, 1 }, -- Mutilate (50)
            { 186, 5 }, -- Lightning Reflexes (51-55)
            { 261, 5 }, -- Opportunity (56-60)   -- level-60 build complete: 41/5/5
            { 181, 5 }, -- Precision (61-65)         source order
            { 1827, 3 }, -- Improved Slice and Dice (66-68)  source order
            { 276, 1 }, -- Improved Eviscerate 3/3 (69)  source order
            { 272, 1 }, -- Remorseless Attacks 1/2 (70)  TBCGuide's choice instead of the source's respec
        },
    },
})
