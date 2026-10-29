-- TBCGuide - talent plans from the Icy Veins TBC Classic leveling guides
-- GENERATED from the guides' talent-calculator links (docs/TALENTS.md). One entry per point, in the
-- order the source's calculator records them; picks are client talent ids {talentId, points}.
-- Talent allocations: Icy Veins (https://www.icy-veins.com/tbc-classic/leveling-guides). No guide
-- text is copied; names in the comments are for reading this file only.
local _, ns = ...

ns.RegisterTalentBuilds("DRUID", {
    {
        id = "druid_balance_iv", name = "Balance (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Balance, in the source's point order (61 points: 47/0/14).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/balance-druid-leveling-guide", build = "Leveling Talent Tree & Build", order = "source" },
        picks = {
            { 762, 5 }, -- Starlight Wrath
            { 763, 2 }, -- Improved Moonfire
            { 1822, 2 }, -- Focused Starlight
            { 761, 1 }, -- Nature's Grasp
            { 788, 1 }, -- Insect Swarm
            { 764, 2 }, -- Nature's Reach
            { 782, 2 }, -- Brambles
            { 784, 3 }, -- Celestial Focus
            { 792, 2 }, -- Vengeance
            { 789, 1 }, -- Nature's Grace
            { 783, 3 }, -- Moonglow
            { 1782, 1 }, -- Lunar Guidance
            { 1783, 2 }, -- Balance of Power
            { 790, 3 }, -- Moonfury
            { 793, 1 }, -- Moonkin Form
            { 790, 2 }, -- Moonfury
            { 792, 3 }, -- Vengeance
            { 1784, 3 }, -- Dreamstate
            { 1782, 1 }, -- Lunar Guidance
            { 1787, 1 }, -- Force of Nature
            { 1782, 1 }, -- Lunar Guidance
            { 1786, 5 }, -- Wrath of Cenarius
            { 821, 5 }, -- Improved Mark of the Wild
            { 826, 3 }, -- Natural Shapeshifter
            { 824, 2 }, -- Naturalist
            { 829, 3 }, -- Intensity
            { 827, 1 }, -- Omen of Clarity
        },
    },
    {
        id = "druid_feral_iv", name = "Feral (Icy Veins leveling)", kind = "leveling", role = "Melee DPS / Tank",
        summary = "Icy Veins Feral, in the source's point order (61 points: 0/47/14).",
        notes = { "The Icy Veins index has one Feral leveling guide; TBCGuide uses it for both the cat and the bear profile." },
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/feral-druid-leveling-guide", build = "Leveling Talent Tree & Build", order = "source" },
        picks = {
            { 796, 5 }, -- Ferocity
            { 794, 3 }, -- Thick Hide
            { 797, 2 }, -- Brutal Impact
            { 807, 2 }, -- Feral Swiftness
            { 798, 3 }, -- Sharpened Claws
            { 803, 3 }, -- Predatory Strikes
            { 801, 2 }, -- Primal Fury
            { 1162, 1 }, -- Faerie Fire (Feral)
            { 805, 2 }, -- Savage Fury
            { 1792, 2 }, -- Nurturing Instinct
            { 808, 5 }, -- Heart of the Wild
            { 809, 1 }, -- Leader of the Pack
            { 1798, 2 }, -- Improved Leader of the Pack
            { 1794, 2 }, -- Survival of the Fittest
            { 1795, 5 }, -- Predatory Instincts
            { 1796, 1 }, -- Mangle
            { 822, 5 }, -- Furor
            { 824, 5 }, -- Naturalist
            { 827, 1 }, -- Omen of Clarity
            { 826, 3 }, -- Natural Shapeshifter
            { 1794, 1 }, -- Survival of the Fittest
            { 804, 1 }, -- Feral Charge
            { 802, 2 }, -- Shredding Attacks
            { 799, 2 }, -- Feral Instinct
        },
    },
    {
        id = "druid_resto_iv", name = "Restoration (Icy Veins leveling)", kind = "leveling", role = "Healer",
        summary = "Icy Veins Restoration, in the source's point order (61 points: 0/0/61).",
        notes = { "Healing build; the source suggests a damage spec for solo questing. Followed as chosen." },
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/restoration-druid-leveling-guide", build = "Leveling Talent Tree & Build", order = "source" },
        picks = {
            { 821, 5 }, -- Improved Mark of the Wild
            { 824, 5 }, -- Naturalist
            { 827, 1 }, -- Omen of Clarity
            { 829, 3 }, -- Intensity
            { 823, 1 }, -- Nature's Focus
            { 830, 3 }, -- Improved Rejuvenation
            { 843, 2 }, -- Tranquil Spirit
            { 831, 1 }, -- Nature's Swiftness
            { 828, 5 }, -- Gift of Nature
            { 825, 4 }, -- Improved Regrowth
            { 844, 1 }, -- Swiftmend
            { 825, 1 }, -- Improved Regrowth
            { 1797, 3 }, -- Living Spirit
            { 1789, 5 }, -- Empowered Rejuvenation
            { 1791, 1 }, -- Tree of Life
            { 826, 3 }, -- Natural Shapeshifter
            { 823, 4 }, -- Nature's Focus
            { 1788, 2 }, -- Empowered Touch
            { 841, 5 }, -- Subtlety
            { 843, 3 }, -- Tranquil Spirit
            { 1790, 3 }, -- Natural Perfection
        },
    },
})

ns.RegisterTalentBuilds("HUNTER", {
    {
        id = "hunter_bm_iv", name = "Beast Mastery (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Beast Mastery, in the source's point order (61 points: 47/14/0).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/beast-mastery-hunter-leveling-guide", build = "Leveling Talent Tree & Build", order = "source" },
        picks = {
            { 1382, 5 }, -- Improved Aspect of the Hawk
            { 1625, 2 }, -- Improved Revive Pet
            { 1624, 2 }, -- Focused Fire
            { 1395, 1 }, -- Thick Hide
            { 1391, 1 }, -- Bestial Swiftness
            { 1396, 5 }, -- Unleashed Fury
            { 1385, 2 }, -- Improved Mend Pet
            { 1393, 2 }, -- Ferocity
            { 1387, 1 }, -- Intimidation
            { 1393, 3 }, -- Ferocity
            { 1390, 2 }, -- Bestial Discipline
            { 1397, 4 }, -- Frenzy
            { 1386, 1 }, -- Bestial Wrath
            { 1799, 2 }, -- Animal Handler
            { 1801, 3 }, -- Catlike Reflexes
            { 1802, 4 }, -- Serpent's Swiftness
            { 1803, 1 }, -- The Beast Within
            { 1802, 1 }, -- Serpent's Swiftness
            { 1800, 3 }, -- Ferocious Inspiration
            { 1388, 2 }, -- Spirit Bond
            { 1344, 5 }, -- Lethal Shots
            { 1342, 5 }, -- Efficiency
            { 1818, 2 }, -- Go for the Throat
            { 1345, 1 }, -- Aimed Shot
            { 1819, 1 }, -- Rapid Killing
        },
    },
    {
        id = "hunter_mm_iv", name = "Marksmanship (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Marksmanship, in the source's point order (61 points: 16/45/0).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/marksmanship-hunter-leveling-guide", build = "Leveling Talents", order = "source" },
        picks = {
            { 1344, 5 }, -- Lethal Shots
            { 1342, 5 }, -- Efficiency
            { 1345, 1 }, -- Aimed Shot
            { 1818, 2 }, -- Go for the Throat
            { 1819, 2 }, -- Rapid Killing
            { 1349, 5 }, -- Mortal Shots
            { 1353, 1 }, -- Scatter Shot
            { 1347, 3 }, -- Barrage
            { 1348, 1 }, -- Improved Stings
            { 1362, 5 }, -- Ranged Weapon Specialization
            { 1361, 1 }, -- Trueshot Aura
            { 1804, 2 }, -- Combat Experience
            { 1806, 2 }, -- Careful Aim
            { 1807, 5 }, -- Master Marksman
            { 1808, 1 }, -- Silencing Shot
            { 1806, 1 }, -- Careful Aim
            { 1821, 3 }, -- Improved Barrage
            { 1382, 5 }, -- Improved Aspect of the Hawk
            { 1625, 2 }, -- Improved Revive Pet
            { 1624, 2 }, -- Focused Fire
            { 1395, 1 }, -- Thick Hide
            { 1391, 1 }, -- Bestial Swiftness
            { 1396, 5 }, -- Unleashed Fury
        },
    },
    {
        id = "hunter_sv_iv", name = "Survival (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Survival, in the source's point order (61 points: 5/12/44).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/survival-hunter-leveling-guide", build = "Leveling Talents", order = "source" },
        picks = {
            { 1820, 3 }, -- Hawk Eye
            { 1623, 3 }, -- Monster Slaying
            { 1301, 3 }, -- Humanoid Slaying
            { 1305, 1 }, -- Improved Wing Clip
            { 1308, 1 }, -- Deterrence
            { 1622, 4 }, -- Survivalist
            { 1310, 3 }, -- Surefooted
            { 1622, 1 }, -- Survivalist
            { 1305, 1 }, -- Improved Wing Clip
            { 1312, 1 }, -- Counterattack
            { 1321, 3 }, -- Killer Instinct
            { 1810, 1 }, -- Survival Instincts
            { 1303, 5 }, -- Lightning Reflexes
            { 1325, 1 }, -- Wyvern Sting
            { 1812, 3 }, -- Expose Weakness
            { 1810, 1 }, -- Survival Instincts
            { 1813, 5 }, -- Master Tactician
            { 1814, 1 }, -- Readiness
            { 1811, 3 }, -- Thrill of the Hunt
            { 1382, 5 }, -- Improved Aspect of the Hawk
            { 1344, 5 }, -- Lethal Shots
            { 1342, 5 }, -- Efficiency
            { 1818, 2 }, -- Go for the Throat
        },
    },
})

ns.RegisterTalentBuilds("MAGE", {
    {
        id = "mage_arcane_iv", name = "Arcane (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Arcane, in the source's point order (61 points: 61/0/0).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/arcane-mage-leveling-guide", build = "Talent Tree for Leveling as Arcane Mage", order = "source" },
        picks = {
            { 80, 5 }, -- Improved Arcane Missiles
            { 78, 2 }, -- Wand Specialization
            { 76, 3 }, -- Arcane Focus
            { 75, 5 }, -- Arcane Concentration
            { 1142, 3 }, -- Arcane Meditation
            { 83, 2 }, -- Improved Mana Shield
            { 86, 1 }, -- Presence of Mind
            { 85, 1 }, -- Arcane Fortitude
            { 82, 2 }, -- Magic Attunement
            { 77, 1 }, -- Arcane Mind
            { 421, 3 }, -- Arcane Instability
            { 1725, 2 }, -- Arcane Potency
            { 87, 1 }, -- Arcane Power
            { 1725, 1 }, -- Arcane Potency
            { 1826, 2 }, -- Spell Power
            { 77, 1 }, -- Arcane Mind
            { 1728, 5 }, -- Mind Mastery
            { 1729, 1 }, -- Slow
            { 1727, 3 }, -- Empowered Arcane Missiles
            { 77, 3 }, -- Arcane Mind
            { 74, 2 }, -- Arcane Subtlety
            { 76, 2 }, -- Arcane Focus
            { 81, 3 }, -- Arcane Impact
            { 1726, 2 }, -- Prismatic Cloak
            { 1650, 5 }, -- Magic Absorption
        },
    },
    {
        id = "mage_fire_iv", name = "Fire (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Fire, in the source's point order (61 points: 11/47/3).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/fire-mage-leveling-guide", build = "Talent Tree for Leveling as Fire Mage", order = "source" },
        picks = {
            { 26, 5 }, -- Improved Fireball
            { 34, 5 }, -- Ignite
            { 29, 1 }, -- Pyroblast
            { 1649, 3 }, -- Elemental Precision
            { 23, 2 }, -- Burning Soul
            { 28, 2 }, -- Flame Throwing
            { 1639, 3 }, -- Master of Elements
            { 1141, 2 }, -- Incineration
            { 33, 3 }, -- Critical Mass
            { 32, 1 }, -- Blast Wave
            { 1730, 3 }, -- Playing with Fire
            { 35, 3 }, -- Fire Power
            { 36, 1 }, -- Combustion
            { 1732, 2 }, -- Molten Fury
            { 35, 2 }, -- Fire Power
            { 74, 2 }, -- Arcane Subtlety
            { 76, 3 }, -- Arcane Focus
            { 75, 5 }, -- Arcane Concentration
            { 1733, 2 }, -- Pyromaniac
            { 1734, 5 }, -- Empowered Fireball
            { 1735, 1 }, -- Dragon's Breath
            { 1733, 1 }, -- Pyromaniac
            { 25, 3 }, -- Improved Scorch
            { 81, 1 }, -- Arcane Impact
        },
    },
    {
        id = "mage_frost_st_iv", name = "Frost single-target (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Frost single-target, in the source's point order (61 points: 10/0/51).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/frost-single-target-mage-leveling-guide", build = "Talent Tree for Leveling as Single-Target Frost Mage", order = "source" },
        picks = {
            { 37, 5 }, -- Improved Frostbolt
            { 1649, 3 }, -- Elemental Precision
            { 38, 3 }, -- Frostbite
            { 69, 1 }, -- Icy Veins
            { 62, 2 }, -- Improved Frost Nova
            { 61, 1 }, -- Piercing Ice
            { 67, 5 }, -- Shatter
            { 73, 5 }, -- Ice Shards
            { 61, 2 }, -- Piercing Ice
            { 66, 2 }, -- Frost Channeling
            { 72, 1 }, -- Cold Snap
            { 71, 1 }, -- Ice Barrier
            { 1738, 5 }, -- Arctic Winds
            { 1740, 4 }, -- Empowered Frostbolt
            { 1741, 1 }, -- Summon Water Elemental
            { 1740, 1 }, -- Empowered Frostbolt
            { 66, 1 }, -- Frost Channeling
            { 74, 2 }, -- Arcane Subtlety
            { 76, 3 }, -- Arcane Focus
            { 75, 5 }, -- Arcane Concentration
            { 741, 2 }, -- Arctic Reach
            { 68, 5 }, -- Winter's Chill
            { 1737, 1 }, -- Ice Floes
        },
    },
    {
        id = "mage_frost_aoe_iv", name = "Frost AoE (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Frost AoE, in the source's point order (61 points: 18/0/43).",
        notes = { "The page also links a short 12-point calculator; the full 61-point build is used." },
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/frost-aoe-mage-leveling-guide", build = "Talent Tree for Leveling as AoE Frost Mage", order = "source" },
        picks = {
            { 1649, 3 }, -- Elemental Precision
            { 70, 2 }, -- Frost Warding
            { 65, 3 }, -- Permafrost
            { 62, 2 }, -- Improved Frost Nova
            { 63, 3 }, -- Improved Blizzard
            { 69, 1 }, -- Icy Veins
            { 61, 1 }, -- Piercing Ice
            { 741, 2 }, -- Arctic Reach
            { 66, 3 }, -- Frost Channeling
            { 72, 1 }, -- Cold Snap
            { 61, 2 }, -- Piercing Ice
            { 64, 3 }, -- Improved Cone of Cold
            { 67, 4 }, -- Shatter
            { 71, 1 }, -- Ice Barrier
            { 1738, 5 }, -- Arctic Winds
            { 67, 1 }, -- Shatter
            { 73, 3 }, -- Ice Shards
            { 1741, 1 }, -- Summon Water Elemental
            { 73, 2 }, -- Ice Shards
            { 74, 2 }, -- Arcane Subtlety
            { 76, 3 }, -- Arcane Focus
            { 75, 5 }, -- Arcane Concentration
            { 85, 1 }, -- Arcane Fortitude
            { 1650, 5 }, -- Magic Absorption
            { 1142, 2 }, -- Arcane Meditation
        },
    },
})

ns.RegisterTalentBuilds("PALADIN", {
    {
        id = "paladin_holy_iv", name = "Holy (Icy Veins leveling)", kind = "leveling", role = "Healer",
        summary = "Icy Veins Holy, in the source's point order (61 points: 43/11/7).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/holy-paladin-leveling-guide", build = "Leveling Talent Tree & Build", order = "source" },
        picks = {
            { 1449, 5 }, -- Divine Intellect
            { 1463, 5 }, -- Improved Seal of Righteousness
            { 1444, 3 }, -- Healing Light
            { 1443, 2 }, -- Improved Lay on Hands
            { 1461, 5 }, -- Illumination
            { 1433, 1 }, -- Divine Favor
            { 1446, 2 }, -- Improved Blessing of Wisdom
            { 1465, 2 }, -- Sanctified Light
            { 1627, 5 }, -- Holy Power
            { 1502, 1 }, -- Holy Shock
            { 1745, 3 }, -- Light's Grace
            { 1465, 1 }, -- Sanctified Light
            { 1746, 5 }, -- Holy Guidance
            { 1747, 1 }, -- Divine Illumination
            { 1401, 5 }, -- Improved Blessing of Might
            { 1743, 2 }, -- Purifying Power
            { 1421, 5 }, -- Redoubt
            { 1630, 3 }, -- Precision
            { 1425, 2 }, -- Guardian's Favor
            { 1442, 1 }, -- Blessing of Kings
            { 1631, 2 }, -- Improved Judgement
        },
    },
    {
        id = "paladin_prot_iv", name = "Protection (Icy Veins leveling)", kind = "leveling", role = "Tank",
        summary = "Icy Veins Protection, in the source's point order (61 points: 11/50/0).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/protection-paladin-leveling-guide", build = "Leveling Talent Tree & Build", order = "source" },
        picks = {
            { 1421, 5 }, -- Redoubt
            { 1630, 3 }, -- Precision
            { 1423, 2 }, -- Toughness
            { 1442, 1 }, -- Blessing of Kings
            { 1424, 3 }, -- Shield Specialization
            { 1423, 3 }, -- Toughness
            { 1521, 3 }, -- Improved Hammer of Justice
            { 1431, 1 }, -- Blessing of Sanctuary
            { 1426, 5 }, -- Reckoning
            { 1429, 4 }, -- One-Handed Weapon Specialization
            { 1430, 1 }, -- Holy Shield
            { 1829, 2 }, -- Improved Holy Shield
            { 1429, 1 }, -- One-Handed Weapon Specialization
            { 1750, 2 }, -- Sacred Duty
            { 1753, 4 }, -- Combat Expertise
            { 1754, 1 }, -- Avenger's Shield
            { 1753, 1 }, -- Combat Expertise
            { 1501, 3 }, -- Improved Righteous Fury
            { 1751, 5 }, -- Ardent Defender
            { 1450, 5 }, -- Divine Strength
            { 1463, 5 }, -- Improved Seal of Righteousness
            { 1443, 1 }, -- Improved Lay on Hands
        },
    },
    {
        id = "paladin_ret_iv", name = "Retribution (Icy Veins leveling)", kind = "leveling", role = "Melee DPS",
        summary = "Icy Veins Retribution, in the source's point order (61 points: 5/10/46).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/retribution-paladin-leveling-guide", build = "Leveling Talent Tree & Build", order = "source" },
        picks = {
            { 1407, 5 }, -- Benediction
            { 1631, 2 }, -- Improved Judgement
            { 1464, 3 }, -- Improved Seal of the Crusader
            { 1481, 1 }, -- Seal of Command
            { 1634, 3 }, -- Pursuit of Justice
            { 1411, 1 }, -- Conviction
            { 1755, 3 }, -- Crusade
            { 1411, 2 }, -- Conviction
            { 1409, 1 }, -- Sanctity Aura
            { 1410, 2 }, -- Two-Handed Weapon Specialization
            { 1411, 2 }, -- Conviction
            { 1758, 3 }, -- Sanctified Judgement
            { 1410, 1 }, -- Two-Handed Weapon Specialization
            { 1402, 5 }, -- Vengeance
            { 1441, 1 }, -- Repentance
            { 1759, 5 }, -- Fanaticism
            { 1823, 1 }, -- Crusader Strike
            { 1761, 3 }, -- Sanctified Seals
            { 1756, 2 }, -- Improved Sanctity Aura
            { 1450, 5 }, -- Divine Strength
            { 1421, 5 }, -- Redoubt
            { 1630, 3 }, -- Precision
            { 1425, 2 }, -- Guardian's Favor
        },
    },
})

ns.RegisterTalentBuilds("PRIEST", {
    {
        id = "priest_disc_iv", name = "Discipline (Icy Veins leveling)", kind = "leveling", role = "Healer",
        summary = "Icy Veins Discipline, in the source's point order (61 points: 41/20/0).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/discipline-priest-leveling-guide", build = "Leveling Talents", order = "source" },
        picks = {
            { 345, 5 }, -- Wand Specialization
            { 343, 3 }, -- Improved Power Word: Shield
            { 344, 2 }, -- Improved Power Word: Fortitude
            { 347, 3 }, -- Meditation
            { 348, 1 }, -- Inner Focus
            { 1769, 1 }, -- Absolution
            { 341, 5 }, -- Mental Agility
            { 351, 1 }, -- Divine Spirit
            { 1201, 5 }, -- Mental Strength
            { 1770, 2 }, -- Improved Divine Spirit
            { 1771, 2 }, -- Focused Power
            { 322, 1 }, -- Power Infusion
            { 1773, 4 }, -- Reflective Shield
            { 1772, 5 }, -- Enlightenment
            { 1774, 1 }, -- Pain Suppression
            { 406, 3 }, -- Improved Renew
            { 401, 2 }, -- Holy Specialization
            { 1181, 5 }, -- Divine Fury
            { 442, 1 }, -- Holy Nova
            { 401, 3 }, -- Holy Specialization
            { 361, 1 }, -- Inspiration
            { 408, 3 }, -- Improved Healing
            { 361, 2 }, -- Inspiration
        },
    },
    {
        id = "priest_holy_iv", name = "Holy (Icy Veins leveling)", kind = "leveling", role = "Healer",
        summary = "Icy Veins Holy, in the source's point order (61 points: 20/41/0).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/holy-priest-leveling-guide", build = "Leveling Talents", order = "source" },
        picks = {
            { 406, 3 }, -- Improved Renew
            { 401, 2 }, -- Holy Specialization
            { 1181, 5 }, -- Divine Fury
            { 442, 1 }, -- Holy Nova
            { 401, 3 }, -- Holy Specialization
            { 361, 1 }, -- Inspiration
            { 408, 3 }, -- Improved Healing
            { 361, 2 }, -- Inspiration
            { 1561, 1 }, -- Spirit of Redemption
            { 402, 4 }, -- Spiritual Guidance
            { 404, 5 }, -- Spiritual Healing
            { 1768, 3 }, -- Holy Concentration
            { 1635, 2 }, -- Holy Reach
            { 1767, 5 }, -- Empowered Healing
            { 1815, 1 }, -- Circle of Healing
            { 345, 5 }, -- Wand Specialization
            { 343, 3 }, -- Improved Power Word: Shield
            { 344, 2 }, -- Improved Power Word: Fortitude
            { 347, 3 }, -- Meditation
            { 348, 1 }, -- Inner Focus
            { 1769, 1 }, -- Absolution
            { 341, 5 }, -- Mental Agility
        },
    },
    {
        id = "priest_shadow_iv", name = "Shadow (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Shadow, in the source's point order (61 points: 14/0/47).",
        notes = { "The page also links a 30-point Discipline-first variant; the full 61-point Shadow build is used." },
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/shadow-priest-leveling-guide", build = "Leveling Talents (first of two builds on the page)", order = "source" },
        picks = {
            { 465, 5 }, -- Spirit Tap
            { 463, 3 }, -- Shadow Focus
            { 482, 2 }, -- Improved Shadow Word: Pain
            { 501, 1 }, -- Mind Flay
            { 481, 4 }, -- Improved Mind Blast
            { 881, 2 }, -- Shadow Reach
            { 461, 3 }, -- Shadow Weaving
            { 1777, 3 }, -- Focused Mind
            { 461, 1 }, -- Shadow Weaving
            { 484, 1 }, -- Vampiric Embrace
            { 462, 5 }, -- Darkness
            { 521, 1 }, -- Shadowform
            { 461, 1 }, -- Shadow Weaving
            { 481, 1 }, -- Improved Mind Blast
            { 1778, 2 }, -- Shadow Power
            { 1816, 5 }, -- Misery
            { 1779, 1 }, -- Vampiric Touch
            { 345, 5 }, -- Wand Specialization
            { 343, 3 }, -- Improved Power Word: Shield
            { 321, 2 }, -- Martyrdom
            { 347, 3 }, -- Meditation
            { 348, 1 }, -- Inner Focus
            { 464, 5 }, -- Blackout
            { 1778, 1 }, -- Shadow Power
        },
    },
})

ns.RegisterTalentBuilds("ROGUE", {
    {
        id = "rogue_combat_iv", name = "Combat (Icy Veins leveling)", kind = "leveling", role = "Melee DPS",
        summary = "Icy Veins Combat, in the source's point order (61 points: 20/41/0).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/combat-rogue-leveling-guide", build = "Recommended Talent Setup for Combat Rogue Leveling", order = "source" },
        picks = {
            { 201, 2 }, -- Improved Sinister Strike
            { 203, 3 }, -- Improved Gouge
            { 187, 5 }, -- Deflection
            { 301, 1 }, -- Riposte
            { 181, 5 }, -- Precision
            { 1827, 3 }, -- Improved Slice and Dice
            { 221, 5 }, -- Dual Wield Specialization
            { 223, 1 }, -- Blade Flurry
            { 1703, 2 }, -- Weapon Expertise
            { 1122, 3 }, -- Aggression
            { 205, 1 }, -- Adrenaline Rush
            { 204, 2 }, -- Endurance
            { 1705, 2 }, -- Vitality
            { 1825, 5 }, -- Combat Potency
            { 1709, 1 }, -- Surprise Attacks
            { 270, 5 }, -- Malice
            { 274, 2 }, -- Murder
            { 273, 3 }, -- Ruthlessness
            { 269, 5 }, -- Lethality
            { 281, 1 }, -- Relentless Strikes
            { 682, 4 }, -- Vile Poisons
        },
    },
    {
        id = "rogue_sub_iv", name = "Subtlety (Icy Veins leveling)", kind = "leveling", role = "Melee DPS",
        summary = "Icy Veins Subtlety, in the source's point order (61 points: 20/0/41).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/subtlety-rogue-leveling-guide", build = "Recommended Talent Setup for Subtlety Rogue Leveling", order = "source" },
        picks = {
            { 241, 5 }, -- Master of Deception
            { 262, 2 }, -- Dirty Tricks
            { 244, 3 }, -- Camouflage
            { 303, 1 }, -- Ghostly Strike
            { 245, 3 }, -- Initiative
            { 244, 1 }, -- Camouflage
            { 246, 2 }, -- Setup
            { 1123, 3 }, -- Serrated Blades
            { 681, 1 }, -- Hemorrhage
            { 284, 1 }, -- Preparation
            { 265, 2 }, -- Dirty Deeds
            { 246, 1 }, -- Setup
            { 1702, 5 }, -- Deadliness
            { 381, 1 }, -- Premeditation
            { 1722, 3 }, -- Cheat Death
            { 247, 1 }, -- Elusiveness
            { 1712, 5 }, -- Sinister Calling
            { 1714, 1 }, -- Shadowstep
            { 270, 5 }, -- Malice
            { 273, 3 }, -- Ruthlessness
            { 274, 2 }, -- Murder
            { 281, 1 }, -- Relentless Strikes
            { 269, 5 }, -- Lethality
            { 682, 4 }, -- Vile Poisons
        },
    },
})

ns.RegisterTalentBuilds("SHAMAN", {
    {
        id = "shaman_ele_iv", name = "Elemental (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Elemental, in the source's point order (61 points: 41/0/20).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/elemental-shaman-leveling-guide", build = "Leveling Talent Tree & Build", order = "source" },
        picks = {
            { 564, 5 }, -- Convection
            { 563, 5 }, -- Concussion
            { 574, 1 }, -- Elemental Focus
            { 562, 5 }, -- Call of Thunder
            { 1642, 3 }, -- Eye of the Storm
            { 1640, 1 }, -- Elemental Warding
            { 565, 1 }, -- Elemental Fury
            { 1641, 2 }, -- Storm Reach
            { 1682, 2 }, -- Unrelenting Storm
            { 721, 5 }, -- Lightning Mastery
            { 573, 1 }, -- Elemental Mastery
            { 1685, 3 }, -- Elemental Precision
            { 1682, 1 }, -- Unrelenting Storm
            { 1686, 5 }, -- Lightning Overload
            { 1687, 1 }, -- Totem of Wrath
            { 593, 5 }, -- Tidal Focus
            { 589, 2 }, -- Improved Reincarnation
            { 595, 3 }, -- Totemic Focus
            { 582, 1 }, -- Totemic Mastery
            { 583, 3 }, -- Nature's Guidance
            { 595, 1 }, -- Totemic Focus
            { 594, 5 }, -- Tidal Mastery
        },
    },
    {
        id = "shaman_enh_iv", name = "Enhancement (Icy Veins leveling)", kind = "leveling", role = "Melee DPS",
        summary = "Icy Veins Enhancement, in the source's point order (61 points: 17/44/0).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/enhancement-shaman-leveling-guide", build = "Leveling Talent Tree & Build", order = "source" },
        picks = {
            { 612, 5 }, -- Shield Specialization
            { 613, 5 }, -- Thundering Strikes
            { 617, 1 }, -- Shamanistic Focus
            { 605, 2 }, -- Improved Ghost Wolf
            { 610, 2 }, -- Enhancing Totems
            { 602, 5 }, -- Flurry
            { 616, 1 }, -- Spirit Weapons
            { 611, 3 }, -- Elemental Weapons
            { 601, 1 }, -- Anticipation
            { 1643, 5 }, -- Weapon Mastery
            { 901, 1 }, -- Stormstrike
            { 1690, 1 }, -- Dual Wield
            { 1692, 3 }, -- Dual Wield Specialization
            { 1689, 5 }, -- Unleashed Rage
            { 1693, 1 }, -- Shamanistic Rage
            { 1691, 3 }, -- Mental Quickness
            { 563, 5 }, -- Concussion
            { 561, 3 }, -- Call of Flame
            { 572, 2 }, -- Earth's Grasp
            { 574, 1 }, -- Elemental Focus
            { 575, 5 }, -- Reverberation
            { 567, 1 }, -- Improved Fire Totems
        },
    },
    {
        id = "shaman_resto_iv", name = "Restoration (Icy Veins leveling)", kind = "leveling", role = "Healer",
        summary = "Icy Veins Restoration, in the source's point order (61 points: 0/5/56).",
        notes = { "Healing build; the source suggests a damage spec for solo questing. Followed as chosen." },
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/restoration-shaman-leveling-guide", build = "Leveling Talent Tree & Build", order = "source" },
        picks = {
            { 586, 5 }, -- Improved Healing Wave
            { 581, 3 }, -- Ancestral Healing
            { 595, 2 }, -- Totemic Focus
            { 582, 1 }, -- Totemic Mastery
            { 595, 3 }, -- Totemic Focus
            { 587, 1 }, -- Healing Focus
            { 594, 5 }, -- Tidal Mastery
            { 591, 1 }, -- Nature's Swiftness
            { 1648, 3 }, -- Healing Way
            { 588, 1 }, -- Restorative Totems
            { 592, 5 }, -- Purification
            { 588, 4 }, -- Restorative Totems
            { 590, 1 }, -- Mana Tide Totem
            { 1696, 3 }, -- Nature's Blessing
            { 1697, 2 }, -- Improved Chain Heal
            { 1698, 1 }, -- Earth Shield
            { 587, 4 }, -- Healing Focus
            { 589, 2 }, -- Improved Reincarnation
            { 1646, 3 }, -- Healing Grace
            { 593, 5 }, -- Tidal Focus
            { 1699, 1 }, -- Nature's Guardian
            { 614, 5 }, -- Ancestral Knowledge
        },
    },
})

ns.RegisterTalentBuilds("WARLOCK", {
    {
        id = "warlock_aff_iv", name = "Affliction (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Affliction, in the source's point order (61 points: 44/17/0).",
        notes = { "Unstable Affliction build; the page's alternative Shadow Mastery / Demonic Sacrifice build is not used." },
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/affliction-warlock-leveling-guide", build = "Leveling Talent Tree & Build (Unstable Affliction build)", order = "source" },
        picks = {
            { 1003, 5 }, -- Improved Corruption
            { 1005, 2 }, -- Suppression
            { 1007, 2 }, -- Improved Life Tap
            { 1004, 2 }, -- Soul Siphon
            { 1101, 2 }, -- Improved Drain Soul
            { 1001, 5 }, -- Fel Concentration
            { 1284, 2 }, -- Improved Curse of Agony
            { 1061, 1 }, -- Amplify Curse
            { 1764, 3 }, -- Empowered Corruption
            { 1002, 2 }, -- Nightfall
            { 1021, 2 }, -- Grim Reach
            { 1763, 1 }, -- Shadow Embrace
            { 1041, 1 }, -- Siphon Life
            { 1042, 5 }, -- Shadow Mastery
            { 1669, 5 }, -- Contagion
            { 1022, 1 }, -- Dark Pact
            { 1668, 2 }, -- Improved Howl of Terror
            { 1670, 1 }, -- Unstable Affliction
            { 1223, 5 }, -- Demonic Embrace
            { 1221, 2 }, -- Improved Healthstone
            { 1242, 3 }, -- Fel Intellect
            { 1671, 3 }, -- Demonic Aegis
            { 1241, 3 }, -- Fel Stamina
            { 1226, 1 }, -- Fel Domination
        },
    },
    {
        id = "warlock_demo_iv", name = "Demonology (Icy Veins leveling)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Demonology, in the source's point order (61 points: 20/41/0).",
        notes = { "The source labels this Felguard build 50-70 and levels as Affliction before that. TBCGuide follows this build's own point order from level 10 instead, so no respec is needed; that use from level 10 is TBCGuide's choice." },
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/demonology-warlock-leveling-guide", build = "Demonology Felguard Warlock Leveling Build (50-70)", order = "source" },
        picks = {
            { 1223, 5 }, -- Demonic Embrace
            { 1221, 2 }, -- Improved Healthstone
            { 1242, 3 }, -- Fel Intellect
            { 1671, 3 }, -- Demonic Aegis
            { 1241, 3 }, -- Fel Stamina
            { 1226, 1 }, -- Fel Domination
            { 1227, 2 }, -- Master Summoner
            { 1262, 5 }, -- Unholy Power
            { 1281, 1 }, -- Demonic Sacrifice
            { 1244, 5 }, -- Master Demonologist
            { 1681, 1 }, -- Mana Feed
            { 1282, 1 }, -- Soul Link
            { 1263, 3 }, -- Demonic Knowledge
            { 1673, 5 }, -- Demonic Tactics
            { 1672, 1 }, -- Summon Felguard
            { 1003, 5 }, -- Improved Corruption
            { 1005, 1 }, -- Suppression
            { 1007, 2 }, -- Improved Life Tap
            { 1004, 2 }, -- Soul Siphon
            { 1101, 2 }, -- Improved Drain Soul
            { 1284, 1 }, -- Improved Curse of Agony
            { 1061, 1 }, -- Amplify Curse
            { 1284, 1 }, -- Improved Curse of Agony
            { 1764, 3 }, -- Empowered Corruption
            { 1002, 2 }, -- Nightfall
        },
    },
    {
        id = "warlock_destro_iv", name = "Destruction (Icy Veins PvE build)", kind = "leveling", role = "Ranged DPS",
        summary = "Icy Veins Destruction, in the source's point order (59 points: 0/19/40).",
        notes = { "No Destruction leveling guide is linked from the Icy Veins leveling index. This is the 'Shadow and Fire Destruction' build from the Destruction PvE builds page; it spends 59 of the 61 points, so the plan ends two points short." },
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/destruction-warlock-dps-pve-spec-builds-talents", build = "Shadow and Fire Destruction (PvE build page; no Destruction leveling guide on the index)", order = "source" },
        picks = {
            { 1223, 5 }, -- Demonic Embrace
            { 944, 5 }, -- Improved Shadow Bolt
            { 1221, 2 }, -- Improved Healthstone
            { 1242, 3 }, -- Fel Intellect
            { 1671, 3 }, -- Demonic Aegis
            { 1241, 3 }, -- Fel Stamina
            { 1226, 1 }, -- Fel Domination
            { 1227, 2 }, -- Master Summoner
            { 943, 5 }, -- Bane
            { 981, 5 }, -- Devastation
            { 963, 1 }, -- Shadowburn
            { 964, 2 }, -- Destructive Reach
            { 985, 2 }, -- Intensity
            { 961, 5 }, -- Improved Immolate
            { 966, 5 }, -- Emberstorm
            { 1817, 3 }, -- Backlash
            { 968, 1 }, -- Conflagrate
            { 967, 1 }, -- Ruin
            { 1677, 5 }, -- Shadow and Flame
        },
    },
})

ns.RegisterTalentBuilds("WARRIOR", {
    {
        id = "warrior_arms_iv", name = "Arms (Icy Veins leveling)", kind = "leveling", role = "Melee DPS",
        summary = "Icy Veins Arms, in the source's point order (61 points: 35/26/0).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/arms-warrior-leveling-guide", build = "Leveling Talents", order = "source" },
        picks = {
            { 124, 3 }, -- Improved Heroic Strike
            { 130, 2 }, -- Deflection
            { 126, 2 }, -- Improved Charge
            { 128, 3 }, -- Improved Thunder Clap
            { 131, 2 }, -- Improved Overpower
            { 137, 1 }, -- Anger Management
            { 121, 2 }, -- Deep Wounds
            { 136, 5 }, -- Two-Handed Weapon Specialization
            { 133, 1 }, -- Death Wish
            { 132, 5 }, -- Poleaxe Specialization
            { 121, 1 }, -- Deep Wounds
            { 662, 2 }, -- Impale
            { 134, 1 }, -- Improved Intercept
            { 135, 1 }, -- Mortal Strike
            { 1663, 2 }, -- Second Wind
            { 1664, 2 }, -- Blood Frenzy
            { 157, 5 }, -- Cruelty
            { 159, 5 }, -- Unbridled Wrath
            { 154, 5 }, -- Commanding Presence
            { 155, 5 }, -- Enrage
            { 1543, 2 }, -- Weapon Mastery
            { 165, 1 }, -- Sweeping Strikes
            { 1542, 2 }, -- Improved Execute
            { 156, 1 }, -- Flurry
        },
    },
    {
        id = "warrior_fury_iv", name = "Fury (Icy Veins leveling)", kind = "leveling", role = "Melee DPS",
        summary = "Icy Veins Fury, in the source's point order (61 points: 18/43/0).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/fury-warrior-leveling-guide", build = "Leveling Talents", order = "source" },
        picks = {
            { 157, 5 }, -- Cruelty
            { 159, 5 }, -- Unbridled Wrath
            { 154, 4 }, -- Commanding Presence
            { 160, 1 }, -- Piercing Howl
            { 155, 5 }, -- Enrage
            { 1543, 2 }, -- Weapon Mastery
            { 1581, 2 }, -- Dual Wield Specialization
            { 165, 1 }, -- Sweeping Strikes
            { 156, 5 }, -- Flurry
            { 167, 1 }, -- Bloodthirst
            { 1657, 3 }, -- Precision
            { 1581, 3 }, -- Dual Wield Specialization
            { 661, 3 }, -- Blood Craze
            { 1659, 1 }, -- Rampage
            { 130, 5 }, -- Deflection
            { 126, 2 }, -- Improved Charge
            { 128, 3 }, -- Improved Thunder Clap
            { 131, 2 }, -- Improved Overpower
            { 137, 1 }, -- Anger Management
            { 121, 3 }, -- Deep Wounds
            { 662, 2 }, -- Impale
            { 1542, 2 }, -- Improved Execute
        },
    },
    {
        id = "warrior_prot_iv", name = "Protection (Icy Veins leveling)", kind = "leveling", role = "Tank",
        summary = "Icy Veins Protection, in the source's point order (61 points: 13/5/43).",
        source = { site = "Icy Veins", url = "https://www.icy-veins.com/tbc-classic/protection-warrior-leveling-guide", build = "Leveling Talents", order = "source" },
        picks = {
            { 138, 5 }, -- Anticipation
            { 1601, 5 }, -- Shield Specialization
            { 144, 3 }, -- Defiance
            { 153, 1 }, -- Last Stand
            { 145, 1 }, -- Improved Shield Block
            { 146, 3 }, -- Improved Sunder Armor
            { 141, 2 }, -- Tactical Mastery
            { 152, 1 }, -- Concussion Blow
            { 141, 1 }, -- Tactical Mastery
            { 140, 3 }, -- Toughness
            { 702, 5 }, -- One-Handed Weapon Specialization
            { 148, 1 }, -- Shield Slam
            { 1660, 3 }, -- Focused Rage
            { 1654, 1 }, -- Shield Mastery
            { 1653, 5 }, -- Vitality
            { 1666, 1 }, -- Devastate
            { 157, 5 }, -- Cruelty
            { 130, 5 }, -- Deflection
            { 126, 2 }, -- Improved Charge
            { 128, 3 }, -- Improved Thunder Clap
            { 131, 2 }, -- Improved Overpower
            { 137, 1 }, -- Anger Management
            { 1654, 2 }, -- Shield Mastery
        },
    },
})
