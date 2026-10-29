-- TBCGuide - gear scoring profiles (data only; no logic)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Every number below is copied from a source recorded in docs/GEAR_RESEARCH.md (S1 = wowsims/tbc
-- commit 3301fca, MIT; S2 = Icy Veins TBC Classic stat pages, read 2026-10-28). Nothing is
-- averaged or invented. Profiles without published numbers carry only a priority order
-- (`priority`, best first) and `weights = nil`: the engine must not turn those into a numeric score.
--
-- Stat keys (per point of stat or rating): str agi sta int spi ap rap feralap sp heal hit spellhit
-- crit spellcrit haste spellhaste exp arp mp5 def dodge parry block blockvalue armor.
-- `caps` are level-70 PvE assumptions (rating), not facts about the player; see GEAR_RESEARCH.md §2.

local _, ns = ...

ns.GearProfiles = {
    researched = "2026-10-28",
    game = "TBC Classic 2.5.x (Anniversary)",
    list = {
        -- Rogue ------------------------------------------------------------------------------------
        { id = "rogue_combat_preraid", class = "ROGUE", spec = "Combat", role = "Melee DPS", context = "pve-preraid",
          levelMin = 70, levelMax = 70, confidence = "high", normalization = "AP = 1",
          weights = { agi = 2.16, ap = 1, str = 1.1, crit = 1.67, hit = 2.26, haste = 2.13, exp = 2.48, arp = 0.29 },
          caps = { hit = 142, exp = 103 },
          assumptions = "Average pre-raid gear, raid buffs. Hit cap 142 is for special attacks vs a boss; white hits keep gaining to 363.",
          sources = { "S2 icy-veins.com/tbc-classic/rogue-dps-pve-stat-priority (EP table, Pre-Raid column)",
                      "S1 agrees on order (ui/rogue/sim.ts)" } },
        { id = "rogue_combat_raid", class = "ROGUE", spec = "Combat", role = "Melee DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "high", normalization = "AP = 1",
          weights = { agi = 2.214, str = 1.1, ap = 1, hit = 2.852, crit = 1.763, haste = 2.311, arp = 0.44, exp = 3.107 },
          caps = { hit = 142, exp = 103 },
          assumptions = "wowsims Combat talents, P1 raid preset, full raid buffs.",
          sources = { "S1 ui/rogue/sim.ts epWeights", "S2 EP table (Tier 4 column) agrees within 0.5" } },

        -- Warlock ----------------------------------------------------------------------------------
        { id = "warlock_destruction_raid", class = "WARLOCK", spec = "Destruction", role = "Ranged DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "high", normalization = "SP = 1",
          weights = { sp = 1, spellcrit = 0.882, spellhit = 1.956, int = 0.261, sta = 0, spellhaste = 1.350 },
          caps = { spellhit = 202 },
          assumptions = "Shadow Destruction, T4/T5 gear. Spirit (0.094) counts only with Improved Drain Soul, so it is left out.",
          sources = { "S2 icy-veins.com/tbc-classic/destruction-warlock-dps-pve-stat-priority",
                      "S1 ui/warlock/sim.ts (P4, hit-capped) agrees on order" } },
        { id = "warlock_affliction_raid", class = "WARLOCK", spec = "Affliction", role = "Ranged DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "SP = 1",
          weights = { sp = 1, spellcrit = 0.528, spellhit = 1.930, int = 0.156, sta = 0, spellhaste = 1.362 },
          caps = { spellhit = 202 },
          assumptions = "Unstable Affliction build, T4/T5 gear, Affliction spells not capped by Suppression (1.429 if they are).",
          sources = { "S2 icy-veins.com/tbc-classic/affliction-warlock-dps-pve-stat-priority" } },
        { id = "warlock_demonology_raid", class = "WARLOCK", spec = "Demonology", role = "Ranged DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "SP = 1",
          weights = { sp = 1, spellcrit = 0.596, spellhit = 1.596, int = 0.220, sta = 0.058, spellhaste = 1.362 },
          caps = { spellhit = 202 },
          assumptions = "Felguard build, T4/T5 gear.",
          sources = { "S2 icy-veins.com/tbc-classic/demonology-warlock-dps-pve-stat-priority" } },

        -- Shaman -----------------------------------------------------------------------------------
        { id = "shaman_restoration_raid", class = "SHAMAN", spec = "Restoration", role = "Healer", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "Healing = 1",
          weights = { heal = 1, spellhaste = 1.5, mp5 = 2, spellcrit = 0.6, int = 0.5, sta = 0.2 },
          assumptions = "Source calls these an estimate; fight length changes Mp5's value a lot.",
          sources = { "S2 icy-veins.com/tbc-classic/restoration-shaman-healer-pve-stat-priority" } },
        { id = "shaman_enhancement_raid", class = "SHAMAN", spec = "Enhancement", role = "Melee DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "AP = 1",
          weights = { int = 0.078, agi = 1.317, str = 2.2, sp = 0.433, ap = 1, hit = 1.665, crit = 1.357, haste = 1.944, arp = 0.283, exp = 2.871 },
          caps = { hit = 142, exp = 103 },
          assumptions = "wowsims P1 preset, full raid buffs. S2 and S3 priorities agree; S2 cites S1, so one source.",
          sources = { "S1 ui/enhancement_shaman/sim.ts epWeights" } },
        { id = "shaman_elemental_raid", class = "SHAMAN", spec = "Elemental", role = "Ranged DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "SP = 1",
          weights = { int = 0.33, sp = 1, spellcrit = 0.78, spellhaste = 1.25, mp5 = 0.08 },
          assumptions = "wowsims P1 preset (hit-capped: spell hit is not scored).",
          sources = { "S1 ui/elemental_shaman/sim.ts epWeights" } },

        -- Druid ------------------------------------------------------------------------------------
        { id = "druid_balance_raid", class = "DRUID", spec = "Balance", role = "Ranged DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "SP = 1",
          weights = { int = 0.54, spi = 0.1, sp = 1, spellcrit = 0.84, spellhaste = 1.29 },
          assumptions = "wowsims P1 preset (hit-capped: spell hit is not scored). Guides rank SP above Haste.",
          sources = { "S1 ui/balance_druid/sim.ts epWeights" } },
        { id = "druid_feral_raid", class = "DRUID", spec = "Feral", role = "Melee DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "AP = 1",
          weights = { str = 2.266, agi = 3.5, ap = 1, feralap = 1, hit = 3.2, crit = 2.37, haste = 1.36, arp = 0.47, exp = 3.2 },
          caps = { hit = 142, exp = 103 },
          assumptions = "wowsims P4 preset, cat form.",
          sources = { "S1 ui/feral_druid/sim.ts epWeights" } },
        { id = "druid_bear_raid", class = "DRUID", spec = "Feral", role = "Tank", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "low",
          priority = { "exp", "agi", "sta", "hit", "str", "crit", "haste", "dodge", "def", "ap", "armor", "arp" },
          assumptions = "Priority only. wowsims tank EP mixes threat and survival and is not used.",
          sources = { "S2 feral-druid-tank page", "S3 wowhead feral tank page" } },
        { id = "druid_restoration_raid", class = "DRUID", spec = "Restoration", role = "Healer", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "low",
          priority = { "heal", "spellhaste", "spi", "mp5", "int", "spellcrit", "sta" },
          caps = { spellhaste = 242 },
          sources = { "S2 restoration-druid-healer page", "S3 wowhead druid healer page" } },

        -- Hunter -----------------------------------------------------------------------------------
        { id = "hunter_bm_raid", class = "HUNTER", spec = "Beast Mastery", role = "Ranged DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "RAP = 1",
          weights = { int = 0.01, agi = 2.5, str = 0.15, ap = 0.15, rap = 1, crit = 2.3, haste = 1.97, arp = 0.4 },
          caps = { hit = 142 },
          assumptions = "wowsims P1 preset (hit-capped: hit is not scored). Guides value ArP far higher in later phases.",
          sources = { "S1 ui/hunter/sim.ts epWeights" } },

        -- Mage -------------------------------------------------------------------------------------
        { id = "mage_arcane_raid", class = "MAGE", spec = "Arcane", role = "Ranged DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "SP = 1",
          weights = { int = 1.29, spi = 0.89, sp = 1, spellcrit = 0.77, spellhaste = 0.84, mp5 = 0.61 },
          assumptions = "wowsims Arcane talents, P1 preset (hit-capped: spell hit is not scored).",
          sources = { "S1 ui/mage/sim.ts epWeights" } },
        { id = "mage_fire_raid", class = "MAGE", spec = "Fire", role = "Ranged DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "low",
          priority = { "spellhit", "sp", "spellhaste", "spellcrit", "int", "sta", "spi", "mp5" },
          caps = { spellhit = 165 },
          sources = { "S2 fire-mage-dps page", "S3 wowhead mage page (puts Haste above SP)" } },
        { id = "mage_frost_raid", class = "MAGE", spec = "Frost", role = "Ranged DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "low",
          priority = { "spellhit", "sp", "spellhaste", "spellcrit", "int", "sta", "spi", "mp5" },
          caps = { spellhit = 127 },
          sources = { "S2 frost-mage-dps page" } },

        -- Priest -----------------------------------------------------------------------------------
        { id = "priest_shadow_raid", class = "PRIEST", spec = "Shadow", role = "Ranged DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "SP = 1",
          weights = { int = 0.05, spi = 0.11, sp = 1, spellcrit = 0.163, spellhaste = 1.0, mp5 = 0 },
          assumptions = "wowsims P1 preset (hit-capped); the sim file itself flags the haste value as uncertain.",
          sources = { "S1 ui/shadow_priest/sim.ts epWeights" } },
        { id = "priest_holy_raid", class = "PRIEST", spec = "Holy", role = "Healer", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "low",
          priority = { "spellhaste", "heal", "spellcrit", "spi", "int", "mp5", "sta" },
          sources = { "S2 holy-priest-healer page", "S3 wowhead priest healer page" } },

        -- Paladin ----------------------------------------------------------------------------------
        { id = "paladin_retribution_raid", class = "PALADIN", spec = "Retribution", role = "Melee DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "AP = 1",
          weights = { str = 2.42, agi = 1.88, int = 0, ap = 1, crit = 1.98, exp = 4.70, haste = 3.27, arp = 0.24, sp = 0.35 },
          caps = { hit = 142, exp = 103 },
          assumptions = "wowsims P4 preset (hit not scored). Guides rank Haste much lower than this.",
          sources = { "S1 ui/retribution_paladin/sim.ts epWeights" } },
        { id = "paladin_holy_raid", class = "PALADIN", spec = "Holy", role = "Healer", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "low",
          priority = { "heal", "mp5", "spellcrit", "int", "spellhaste", "sta" },
          sources = { "S2 holy-paladin-healer page", "S3 wowhead holy paladin page" } },
        { id = "paladin_protection_raid", class = "PALADIN", spec = "Protection", role = "Tank", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "low",
          priority = { "def", "dodge", "parry", "block", "sta", "sp", "spellhit", "exp" },
          caps = { def = 490 },
          assumptions = "Priority only. wowsims numbers rejected (copied from the warrior sim).",
          sources = { "S2 protection-paladin-tank page", "S3 wowhead paladin tank page" } },

        -- Warrior ----------------------------------------------------------------------------------
        { id = "warrior_fury_raid", class = "WARRIOR", spec = "Fury", role = "Melee DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "medium", normalization = "AP = 1",
          weights = { str = 2.17, agi = 1.4, ap = 1, exp = 3.29, crit = 1.83, haste = 2.07, arp = 0.5 },
          caps = { hit = 142, exp = 103 },
          assumptions = "wowsims P1 preset (hit-capped: hit is not scored). Guides rank Crit above Haste.",
          sources = { "S1 ui/warrior/sim.ts epWeights" } },
        { id = "warrior_arms_raid", class = "WARRIOR", spec = "Arms", role = "Melee DPS", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "low",
          priority = { "hit", "exp", "crit", "arp", "str", "ap", "agi", "haste" },
          caps = { hit = 142, exp = 103 },
          sources = { "S2 arms-warrior-dps page" } },
        { id = "warrior_protection_raid", class = "WARRIOR", spec = "Protection", role = "Tank", context = "pve-raid",
          levelMin = 70, levelMax = 70, confidence = "low",
          priority = { "sta", "armor", "def", "agi", "dodge", "parry", "blockvalue", "exp", "hit" },
          caps = { def = 490 },
          assumptions = "Priority only. wowsims numbers rejected (placeholder).",
          sources = { "S2 protection-warrior-tank page" } },

        -- Leveling (1-69): qualitative only; no source publishes numbers (GEAR_RESEARCH.md §4) ----
        { id = "rogue_leveling", class = "ROGUE", role = "Melee DPS", context = "leveling", levelMin = 1, levelMax = 69,
          confidence = "low", priority = { "hit", "agi" }, sources = { "S4 icy-veins rogue-leveling-guide" } },
        { id = "mage_leveling", class = "MAGE", role = "Ranged DPS", context = "leveling", levelMin = 1, levelMax = 69,
          confidence = "low", priority = { "int", "spi", "sp" }, sources = { "S4 icy-veins mage-leveling-guide" } },
        { id = "shaman_enh_leveling", class = "SHAMAN", spec = "Enhancement", role = "Melee DPS", context = "leveling",
          levelMin = 1, levelMax = 69, confidence = "low", priority = { "str" },
          assumptions = "The weapon matters most (slow, high damage).", sources = { "S4 icy-veins shaman-leveling-guide" } },
        { id = "druid_feral_leveling", class = "DRUID", spec = "Feral", role = "Melee DPS", context = "leveling",
          levelMin = 1, levelMax = 69, confidence = "low", priority = { "agi", "str" },
          sources = { "S4 icy-veins druid-leveling-guide" } },
    },
}
