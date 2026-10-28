-- TBCGuide - target client and ruleset configuration
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Everything that depends on WHICH TBC client / realm ruleset we run on lives here, so a
-- future client or private-server variant is a config edit, not a code rewrite.
-- See docs/COMPATIBILITY.md for how each value was established.

local _, ns = ...

ns.Target = {
    -- TBC Classic Anniversary realms (launched 2026). Client build 2.5.6.x, TOC interface 20506.
    -- Verified: Questie bundle v12.3.1 release.json lists flavor "bcc" at interface 20506, and
    -- wago.tools lists product wow_anniversary at 2.5.6.70577 (checked 2026-10-28).
    name = "TBC Classic Anniversary",
    interface = 20506,
    clientBuild = "2.5.6.70577",
    -- Lowest/highest TOC interface the add-on will run on without warning. Older 2.5.x builds are
    -- untested; the compat layer guards every API we touch, but quests/talents could differ.
    minInterface = 20500,
    maxInterface = 20599,

    -- Ruleset ------------------------------------------------------------------------------
    maxLevel = 70,
    -- First talent point at 10, one per level => 61 points at 70.
    firstTalentLevel = 10,
    talentPointsAt = function(level)
        if not level or level < 10 then return 0 end
        return math.min(level, 70) - 9
    end,
    -- Through the Dark Portal (quest 9407/10119) requires level 58 in TBC.
    outlandMinLevel = 58,
    -- Default XP multiplier (1 = Blizzard retail-like rates). Used only for advisory "grind" notes.
    xpRate = 1,
    -- Races/classes are generated from client tables into Database/RaceClass.lua.

    -- Optional integrations (all optional; the guide works without any of them) ----------------
    integrations = {
        TomTom = true,       -- waypoints via TomTom if it is loaded
        Questie = false,     -- we never require Questie; set true to read its map icons (not implemented)
    },
}

-- Private servers / custom rulesets can override values before PLAYER_LOGIN, e.g. from a
-- separate add-on:  TBCGuide.Target.xpRate = 3
