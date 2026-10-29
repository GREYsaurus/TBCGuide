-- TBCGuide - which talent plan each spec profile follows
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Spec profile (Gear/Profiles.lua: class + spec) -> talent plan (Talents/Builds/*.lua). Every plan
-- runs from the first talent point (level 10) to 70 without a respec. Sources: the Icy Veins TBC
-- Classic leveling guides (Talents/Builds/IcyVeins.lua); Assassination has no Icy Veins build and
-- keeps TBCGuide's own plan. Mapping and source record: docs/TALENTS.md.
--   plan: the default; variants: other plans for the same spec the player may pick in the TBCGuide
--   talent window (/tbcg talents). A spec missing here has no plan and the window says so.
-- The talent plan never changes gear scoring: weights belong to the spec profile alone.

local _, ns = ...

ns.TalentProfileBuilds = {
    specs = {
        WARRIOR = { Arms = { plan = "warrior_arms_iv" }, Fury = { plan = "warrior_fury_iv" }, Protection = { plan = "warrior_prot_iv" } },
        PALADIN = { Retribution = { plan = "paladin_ret_iv" }, Holy = { plan = "paladin_holy_iv" }, Protection = { plan = "paladin_prot_iv" } },
        HUNTER = { ["Beast Mastery"] = { plan = "hunter_bm_iv" }, Marksmanship = { plan = "hunter_mm_iv" }, Survival = { plan = "hunter_sv_iv" } },
        ROGUE = { Combat = { plan = "rogue_combat_iv" }, Subtlety = { plan = "rogue_sub_iv" }, Assassination = { plan = "rogue_mutilate_70" } },
        PRIEST = { Shadow = { plan = "priest_shadow_iv" }, Holy = { plan = "priest_holy_iv" }, Discipline = { plan = "priest_disc_iv" } },
        SHAMAN = { Enhancement = { plan = "shaman_enh_iv" }, Elemental = { plan = "shaman_ele_iv" }, Restoration = { plan = "shaman_resto_iv" } },
        MAGE = { Frost = { plan = "mage_frost_aoe_iv", variants = { "mage_frost_st_iv" } }, Fire = { plan = "mage_fire_iv" }, Arcane = { plan = "mage_arcane_iv" } },
        WARLOCK = { Affliction = { plan = "warlock_aff_iv" }, Demonology = { plan = "warlock_demo_iv" }, Destruction = { plan = "warlock_destro_iv" } },
        -- Feral cat and Feral bear share the one Icy Veins Feral leveling guide.
        DRUID = { Feral = { plan = "druid_feral_iv" }, Balance = { plan = "druid_balance_iv" }, Restoration = { plan = "druid_resto_iv" } },
    },
}

-- The plan for a spec profile, or nil and why ("no spec profile" / "no plan").
-- A variant chosen in the TBCGuide talent window (ns.char.talentBuild) wins when it belongs to the spec.
function ns.Talents:BuildForProfile(profile)
    if not profile then return nil, "no spec profile" end
    local m = ns.TalentProfileBuilds.specs[profile.class]
    local e = m and m[profile.spec]
    if not e then return nil, "no plan" end
    local chosen = ns.char and ns.Talents:Get(ns.char.talentBuild)
    if chosen then
        for _, v in ipairs(e.variants or {}) do
            if self.builds[v] == chosen then return chosen end
        end
    end
    local b = self.builds[e.plan]
    if not b then return nil, "no plan" end
    return b
end

-- One line on where a plan comes from (shown in the talent window panel and the TBCGuide window).
function ns.Talents:SourceLine(b)
    local s = b and b.source
    if not s then return "Source unknown." end
    if s.site == "Icy Veins" then
        return "Talents: Icy Veins TBC Classic leveling guide (point order from its talent calculator)."
    end
    return "Talents: TBCGuide's own plan. " .. (s.note or "")
end
