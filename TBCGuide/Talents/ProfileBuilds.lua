-- TBCGuide - which talent build each spec profile follows
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Spec profile (Gear/Profiles.lua: class + spec) -> talent build (Talents/Builds/*.lua). A spec
-- with no entry has NO plan: the talent window then says so instead of guessing (docs/TALENTS.md).
--   leveling: followed below level 70; endgame: followed at 70 (and below when there is no
--   leveling build for the spec, since its point order also runs from level 10 upwards).
-- Source of every build: TBCGuide's own recommendations, written for this project and checked
-- point by point against the client's talent data (ranks, tiers, prerequisites). They were NOT
-- taken from Icy Veins or Wowhead, so no external attribution is claimed.

local _, ns = ...

ns.TalentProfileBuilds = {
    source = "TBCGuide's own build, checked against the client's talent data (not taken from Icy Veins or Wowhead).",
    specs = {
        WARRIOR = { Arms = { leveling = "warrior_arms_leveling" }, Fury = { endgame = "warrior_fury_70" },
            Protection = { endgame = "warrior_prot_70" } },
        PALADIN = { Retribution = { leveling = "paladin_ret_leveling" }, Holy = { endgame = "paladin_holy_70" },
            Protection = { endgame = "paladin_prot_70" } },
        HUNTER = { ["Beast Mastery"] = { leveling = "hunter_bm_leveling", endgame = "hunter_bm_70" } },
        ROGUE = { Combat = { leveling = "rogue_combat_leveling" }, Assassination = { endgame = "rogue_mutilate_70" } },
        PRIEST = { Shadow = { leveling = "priest_shadow_leveling" }, Holy = { endgame = "priest_holy_70" } },
        SHAMAN = { Enhancement = { leveling = "shaman_enh_leveling" }, Elemental = { endgame = "shaman_ele_70" },
            Restoration = { endgame = "shaman_resto_70" } },
        MAGE = { Frost = { leveling = "mage_frost_leveling" }, Fire = { endgame = "mage_fire_70" } },
        WARLOCK = { Affliction = { leveling = "warlock_aff_leveling" }, Destruction = { endgame = "warlock_destro_70" } },
        DRUID = { Feral = { leveling = "druid_feral_leveling" }, Balance = { endgame = "druid_balance_70" } },
    },
}

-- The build for a spec profile at `level`, or nil, "no plan" when the spec has none.
function ns.Talents:BuildForProfile(profile, level)
    if not profile then return nil, "no spec profile" end
    local m = ns.TalentProfileBuilds.specs[profile.class]
    local e = m and m[profile.spec]
    if not e then return nil, "no plan" end
    local id
    if (level or 1) >= 70 then id = e.endgame or e.leveling else id = e.leveling or e.endgame end
    local b = id and self.builds[id]
    if not b then return nil, "no plan" end
    return b
end
