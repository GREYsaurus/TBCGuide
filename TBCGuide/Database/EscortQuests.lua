-- TBCGuide - escort / scripted-event quest safeguard list
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Quests that must NEVER be accepted automatically. This list is one of several independent
-- signals (see DB.GetEscortStatus); a quest is manual-only if ANY signal fires:
--   1. this list, plus the per-account list TBCGuideDB.escortExtra (/tbcg escort add <id>);
--   2. questFlags PARTY_ACCEPT (2) in the bundled QuestieDB data (cmangos marks escort-type
--      quests with it; it also covers some scripted "defend/wait" events, which stay manual too).
--      specialFlags NEEDS_EVENT is NOT used: reviewed 2026-10-28, all 67 TBC quests carrying only
--      that flag are exploration/area-trigger quests, none are escorts;
--   3. escort wording in the database objective / trigger text;
--   4. escort wording in the quest text the client shows on the offer panel;
--   5. the quest is not in the bundled database at all (status unknown).
--
-- Contents: every TBC quest whose QuestieDB objective or trigger text says "escort" (pinned
-- commit, see tools/upstream.json), plus escorts found by manual review whose upstream data
-- carries neither flag nor the word (2078, 4122, 10284, 10439, 10965). Add, never remove.

local _, ns = ...

ns.EscortQuests = {
    [155] = true, -- The Defias Brotherhood
    [435] = true, -- Escorting Erland
    [648] = true, -- Rescue OOX-17/TN!
    [665] = true, -- Sunken Treasure
    [836] = true, -- Rescue OOX-09/HL!
    [898] = true, -- Free From the Hold
    [938] = true, -- Mist
    [1144] = true, -- Willix the Importer
    [1222] = true, -- Stinky's Escape
    [1270] = true, -- Stinky's Escape
    [1393] = true, -- Galen's Escape
    [1440] = true, -- Return to Vahlarriel
    [2078] = true, -- Gyromast's Revenge
    [2742] = true, -- Rin'ji is Trapped!
    [2767] = true, -- Rescue OOX-22/FE!
    [2845] = true, -- Wandering Shay
    [2904] = true, -- A Fine Mess
    [3525] = true, -- Extinguishing the Idol
    [4121] = true, -- Precarious Predicament
    [4122] = true, -- Grark Lorkrub
    [4245] = true, -- Chasing A-Me 01
    [4261] = true, -- Ancient Spirit
    [4770] = true, -- Homeward Bound
    [4904] = true, -- Free at Last
    [5203] = true, -- Rescue From Jaedenar
    [5321] = true, -- The Sleeper Has Awakened
    [5821] = true, -- Bodyguard for Hire
    [5943] = true, -- Gizelton Caravan
    [5944] = true, -- In Dreams
    [6132] = true, -- Get Me Out of Here!
    [6482] = true, -- Freedom to Ruul
    [6523] = true, -- Protect Kaya
    [6544] = true, -- Torek's Assault
    [9212] = true, -- Escape from the Catacombs
    [9446] = true, -- Tomb of the Lightbringer
    [9528] = true, -- A Cry For Help
    [9729] = true, -- Fhwoor Smash!
    [9752] = true, -- Escape from Umbrafen
    [9868] = true, -- The Totem of Kar'dash
    [9879] = true, -- The Totem of Kar'dash
    [10051] = true, -- Escape from Firewing Point!
    [10052] = true, -- Escape from Firewing Point!
    [10191] = true, -- Mark V is Alive!
    [10218] = true, -- Someone Else's Hard Work Pays Off
    [10284] = true, -- Escape from Durnholde
    [10310] = true, -- Sabotage the Warp-Gate!
    [10337] = true, -- When the Cows Come Home
    [10406] = true, -- Delivering the Message
    [10425] = true, -- Escape from the Staging Grounds
    [10439] = true, -- Dimensius the All-Devouring
    [10451] = true, -- Escape from Coilskar Cistern
    [10898] = true, -- Skywing
    [10922] = true, -- Digging Through Bones
    [10965] = true, -- No Mere Dream
    [11085] = true, -- Escape from Skettis
}
