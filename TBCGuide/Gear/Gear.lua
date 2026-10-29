-- TBCGuide - gear scoring engine
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Scores items with the researched profiles in Gear/Profiles.lua (docs/GEAR_RESEARCH.md).
--   * Numeric profiles (`weights`): score = sum(stat * weight), with hit/expertise counted only up to
--     the profile's cap. Upgrade % only when both items have a valid, non-zero score.
--   * Priority-only profiles: no number at all. Items are compared stat by stat in priority order
--     and called better/worse only when one item is at least as good on every listed stat.
-- Weapon DPS, sockets, equip/use effects, set bonuses and unique-equipped limits are NOT scored;
-- callers list them as limitations instead of inventing a value.

local _, ns = ...

local Gear = {}
ns.Gear = Gear

local C -- ns.Compat, set lazily (Gear loads before Compat users run)
local function compat() C = C or ns.Compat return C end

-- GetItemStats keys -> profile stat keys. Spell damage and healing are separate keys on TBC items,
-- so `sp` and `heal` never double count. Generic hit/crit/haste rating is treated as melee/ranged;
-- spell ratings have their own keys (TBC itemisation).
Gear.STAT_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "feralap",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "sp", ITEM_MOD_SPELL_POWER_SHORT = "sp",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit", ITEM_MOD_HIT_RANGED_RATING_SHORT = "hit",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "spellhit",
    ITEM_MOD_CRIT_RATING_SHORT = "crit", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit", ITEM_MOD_CRIT_RANGED_RATING_SHORT = "crit",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "spellcrit",
    ITEM_MOD_HASTE_RATING_SHORT = "haste", ITEM_MOD_HASTE_MELEE_RATING_SHORT = "haste", ITEM_MOD_HASTE_RANGED_RATING_SHORT = "haste",
    ITEM_MOD_HASTE_SPELL_RATING_SHORT = "spellhaste",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "exp", ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "arp",
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_POWER_REGEN0_SHORT = "mp5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "def", ITEM_MOD_DODGE_RATING_SHORT = "dodge",
    ITEM_MOD_PARRY_RATING_SHORT = "parry", ITEM_MOD_BLOCK_RATING_SHORT = "block", ITEM_MOD_BLOCK_VALUE_SHORT = "blockvalue",
    RESISTANCE0_NAME = "armor",
}
-- Present on items but never scored (no researched weight); reported as limitations.
Gear.UNSCORED_KEYS = {
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "weapon DPS",
    EMPTY_SOCKET_RED = "sockets", EMPTY_SOCKET_YELLOW = "sockets", EMPTY_SOCKET_BLUE = "sockets", EMPTY_SOCKET_META = "sockets",
    ITEM_MOD_RESILIENCE_RATING_SHORT = "resilience (PvP)",
}

Gear.STAT_NAMES = {
    str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect", spi = "Spirit", ap = "Attack Power",
    rap = "Ranged AP", feralap = "Feral AP", sp = "Spell Damage", heal = "Healing", hit = "Hit", spellhit = "Spell Hit",
    crit = "Crit", spellcrit = "Spell Crit", haste = "Haste", spellhaste = "Spell Haste", exp = "Expertise",
    arp = "Armor Pen", mp5 = "Mp5", def = "Defense", dodge = "Dodge", parry = "Parry", block = "Block",
    blockvalue = "Block Value", armor = "Armor",
}

-- Combat rating indices (TBC CR_* constants) for the capped stats; used only to respect caps.
local CR = { hit = 6, spellhit = 8, exp = 24, def = 2 }

-- Equip location -> inventory slot ids (1 head .. 18 ranged/relic).
Gear.SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
Gear.SLOT_NAMES = { "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands",
    "Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged / relic" }
Gear.SCORED_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

-- What each class can equip in TBC (armor subclass ids of item class 4, weapon subclass ids of
-- item class 2). Armor is the highest type the class can learn (mail at 40 for hunters/shamans,
-- plate at 40 for warriors/paladins); weapons are the trainable skills. General game rules, not
-- per-character training state, so the engine says "your class can use", never "you can equip now".
local ARMOR = { CLOTH = 1, LEATHER = 2, MAIL = 3, PLATE = 4, SHIELD = 6, LIBRAM = 7, IDOL = 8, TOTEM = 9 }
Gear.CLASS_GEAR = {
    WARRIOR = { armor = { 1, 2, 3, 4, 6 }, armorAt = { [4] = 40 }, weapons = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }, dualWield = 20 },
    PALADIN = { armor = { 1, 2, 3, 4, 6, 7 }, armorAt = { [4] = 40 }, weapons = { 0, 1, 4, 5, 6, 7, 8 } },
    HUNTER = { armor = { 1, 2, 3 }, armorAt = { [3] = 40 }, weapons = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }, dualWield = 20 },
    ROGUE = { armor = { 1, 2 }, weapons = { 2, 3, 4, 7, 13, 15, 16, 18 }, dualWield = 10 },
    PRIEST = { armor = { 1 }, weapons = { 4, 10, 15, 19 } },
    SHAMAN = { armor = { 1, 2, 3, 6, 9 }, armorAt = { [3] = 40 }, weapons = { 0, 1, 4, 5, 10, 13, 15 }, dualWieldSpec = "Enhancement" },
    MAGE = { armor = { 1 }, weapons = { 7, 10, 15, 19 } },
    WARLOCK = { armor = { 1 }, weapons = { 7, 10, 15, 19 } },
    DRUID = { armor = { 1, 2, 8 }, weapons = { 4, 5, 10, 13, 15 } },
}
Gear.ARMOR = ARMOR

local function contains(t, v) for _, x in ipairs(t or {}) do if x == v then return true end end return false end

-- Item data -------------------------------------------------------------------------------------

-- { id, link, name, equipLoc, reqLevel, ilvl, classID, subclassID, stats = {key=n}, unscored = {label=true} }
-- or nil, "uncached" when the client has not loaded the item yet.
function Gear:ItemData(item)
    if not item then return nil end
    local getInfo = compat().Has("C_Item.GetItemInfo") or compat().Has("GetItemInfo")
    if not getInfo then return nil, "unsupported" end
    local name, link, quality, ilvl, reqLevel, _, _, _, equipLoc, texture, _, classID, subclassID, bindType = getInfo(item)
    if not name then return nil, "uncached" end
    -- bindType is the item template's binding (0 none, 1 on pickup, 2 on equip, 3 on use, 4 quest),
    -- not whether this copy is already bound; Gear/Upgrade.lua reads the instance state separately.
    local d = { name = name, link = link or item, ilvl = ilvl, reqLevel = reqLevel or 0, equipLoc = equipLoc,
                classID = classID, subclassID = subclassID, quality = quality, texture = texture, bindType = bindType,
                stats = {}, unscored = {}, statKeys = {} }
    d.id = tonumber(string.match(tostring(d.link), "item:(%d+)")) or (type(item) == "number" and item or nil)
    local getStats = compat().Has("C_Item.GetItemStats") or compat().Has("GetItemStats")
    if getStats then
        local raw = getStats(d.link)
        for k, v in pairs(raw or {}) do
            d.statKeys[k] = true
            local key = self.STAT_KEYS[k]
            if key and type(v) == "number" then
                d.stats[key] = (d.stats[key] or 0) + v
            elseif self.UNSCORED_KEYS[k] then
                d.unscored[self.UNSCORED_KEYS[k]] = true
                if k == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" and type(v) == "number" then d.dps = v end
            end
        end
    else
        d.noStats = true
    end
    return d
end

function Gear:IsEquippable(d) return d and d.equipLoc and self.SLOTS[d.equipLoc] ~= nil end

-- Whether the class can use the item at all (armor type / weapon skill), and the level it can.
-- Returns ok, reason.
function Gear:ClassCanUse(d, class, level, spec)
    local rules = self.CLASS_GEAR[class]
    if not rules or not d then return true end
    if d.classID == 4 then
        local sub = d.subclassID
        if sub == 0 then return true end -- miscellaneous: rings, necks, trinkets, cloaks, off-hands
        if sub == 5 then return true end -- cosmetic
        if not contains(rules.armor, sub) then return false, "your class cannot wear this armor type" end
        local at = rules.armorAt and rules.armorAt[sub]
        if at and (level or 1) < at then return false, "your class learns this armor type at level " .. at end
        return true
    elseif d.classID == 2 then
        if not contains(rules.weapons, d.subclassID) then return false, "your class cannot use this weapon type" end
        return true
    end
    return true
end

function Gear:CanDualWield(class, level, spec)
    local r = self.CLASS_GEAR[class]
    if not r then return false end
    if r.dualWield then return (level or 1) >= r.dualWield end
    if r.dualWieldSpec then return spec == r.dualWieldSpec and (level or 1) >= 40 end
    return false
end

-- Player context ----------------------------------------------------------------------------------

-- Main talent tree name for the player's class, or nil (no points spent / no data).
function Gear:DetectSpec(class)
    local trees = ns.TalentTrees and ns.TalentTrees[class]
    if not trees then return nil end
    local best, bestPts = nil, 0
    for tab = 1, compat().GetNumTalentTabs() do
        local pts = 0
        for i = 1, compat().GetNumTalents(tab) do
            local t = compat().GetTalent(tab, i)
            if t then pts = pts + (t.rank or 0) end
        end
        if pts > bestPts and trees[tab] then best, bestPts = trees[tab].name, pts end
    end
    if best == "Feral Combat" then best = "Feral" end
    return best
end

function Gear:Context()
    local info = compat().PlayerInfo()
    info.spec = self:DetectSpec(info.class)
    return info
end

-- Profiles ------------------------------------------------------------------------------------------

function Gear:Profiles() return ns.GearProfiles and ns.GearProfiles.list or {} end

function Gear:ProfileById(id)
    for _, p in ipairs(self:Profiles()) do if p.id == id then return p end end
end

function Gear:ProfilesForClass(class)
    local out = {}
    for _, p in ipairs(self:Profiles()) do if p.class == class then out[#out + 1] = p end end
    return out
end

local CONTEXT_ORDER = { ["pve-preraid"] = 1, ["pve-raid"] = 2 }

-- Picks the profile for a character. A saved choice (ns.char.gearProfile) wins when it belongs to
-- the class. Otherwise only profiles whose level range contains the character's level are used, so
-- level-70 weights are never applied to a leveling character automatically.
-- Returns profile or nil, plus a short reason.
function Gear:SelectProfile(info)
    info = info or self:Context()
    local chosen = ns.char and ns.char.gearProfile
    if chosen then
        local p = self:ProfileById(chosen)
        if p and p.class == info.class then return p, "chosen in settings" end
    end
    local best, bestRank
    for _, p in ipairs(self:ProfilesForClass(info.class)) do
        local lvl = info.level or 1
        if lvl >= (p.levelMin or 1) and lvl <= (p.levelMax or 70) then
            local rank
            if p.spec and info.spec and p.spec == info.spec then rank = 0
            elseif not p.spec then rank = 10
            elseif not info.spec then rank = 20
            end
            if rank then
                if p.role == "Tank" then rank = rank + 5 end -- Feral: cat unless a tank profile is chosen
                rank = rank + (CONTEXT_ORDER[p.context] or 3)
                if not bestRank or rank < bestRank then best, bestRank = p, rank end
            end
        end
    end
    if best then
        return best, (best.spec and info.spec == best.spec) and ("talents: " .. best.spec) or "class default"
    end
    if (info.level or 1) < 70 then
        return nil, "no researched leveling profile for your class"
    end
    return nil, "no researched profile for your specialization"
end

-- Scoring --------------------------------------------------------------------------------------------

local function currentRating(key)
    local idx = CR[key]
    local f = idx and compat().Has("GetCombatRating")
    if not f then return nil end
    local ok, v = pcall(f, idx)
    return ok and tonumber(v) or nil
end

-- Score of one item under a numeric profile. `replacing` is the item being swapped out: its capped
-- stats are removed from the player's current rating before the cap is applied, so a hit-capped
-- player does not see value in more hit, and swapping hit for hit stays neutral.
-- Returns score (number) or nil when the profile has no numbers, plus a breakdown { {key, amount, points} }.
function Gear:Score(d, profile, replacing, ratings)
    if not d or not profile or not profile.weights then return nil end
    local total, parts = 0, {}
    for key, amount in pairs(d.stats) do
        local w = profile.weights[key]
        if w and w ~= 0 and amount ~= 0 then
            local eff = amount
            local cap = profile.caps and profile.caps[key]
            if cap then
                local have = ratings and ratings[key]
                if have == nil then have = currentRating(key) end
                if have then
                    local base = have - ((replacing and replacing.stats[key]) or 0)
                    eff = math.max(0, math.min(amount, cap - base))
                end
            end
            local pts = eff * w
            total = total + pts
            parts[#parts + 1] = { key = key, amount = amount, used = eff, points = pts }
        end
    end
    table.sort(parts, function(a, b) return a.points > b.points end)
    return total, parts
end

-- Stat-by-stat comparison for priority-only profiles. Returns verdict "better" | "worse" | "same" |
-- "mixed" and the list of differences in priority order.
function Gear:ComparePriority(cand, cur, profile)
    local diffs, up, down = {}, false, false
    for _, key in ipairs(profile.priority or {}) do
        local a, b = cand.stats[key] or 0, cur and cur.stats[key] or 0
        if a ~= b then
            diffs[#diffs + 1] = { key = key, delta = a - b }
            if a > b then up = true else down = true end
        end
    end
    local verdict = (up and down) and "mixed" or up and "better" or down and "worse" or "same"
    return verdict, diffs
end

local function equippedData(slot)
    local f = compat().Has("GetInventoryItemLink")
    local link = f and f("player", slot)
    if not link then return nil end
    return (Gear:ItemData(link))
end
Gear.EquippedData = function(_, slot) return equippedData(slot) end

-- Compares an item with what the character has equipped. Result fields:
--   ok (false when the item cannot be compared), reason, profile, numeric (bool),
--   score, current (score of the replaced item(s)), delta, pct (only when meaningful),
--   slot, verdict / diffs (priority-only profiles), notes = { strings }, empty (slot is empty).
function Gear:Compare(item, info, equipped)
    info = info or self:Context()
    local d, why
    if type(item) == "table" then d = item else d, why = self:ItemData(item) end
    if not d then return { ok = false, reason = why == "uncached" and "item not loaded yet" or "no item data" } end
    if not self:IsEquippable(d) then return { ok = false, reason = "not equipment", item = d } end
    local res = { ok = true, item = d, notes = {} }
    local canUse, useWhy = self:ClassCanUse(d, info.class, info.level, info.spec)
    if not canUse then return { ok = false, reason = useWhy, item = d, unusable = true } end
    if (d.reqLevel or 0) > (info.level or 1) then res.notes[#res.notes + 1] = "requires level " .. d.reqLevel end
    local profile, pwhy = self:SelectProfile(info)
    res.profile, res.profileReason = profile, pwhy
    if not profile then return { ok = false, reason = pwhy, item = d, noProfile = true } end
    res.numeric = profile.weights ~= nil
    if d.noStats then res.notes[#res.notes + 1] = "item stats unavailable in this client" end
    for label in pairs(d.unscored) do res.notes[#res.notes + 1] = label .. " not scored" end

    local get = equipped or equippedData
    local slots = self.SLOTS[d.equipLoc]
    local loc = d.equipLoc

    -- Which equipped items this item would replace.
    local replaced, slot
    if loc == "INVTYPE_2HWEAPON" then
        slot = 16
        replaced = { get(16), get(17) }
    elseif loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
        slot = 17
        local mh = get(16)
        if mh and mh.equipLoc == "INVTYPE_2HWEAPON" then
            res.notes[#res.notes + 1] = "needs a one-hand weapon instead of your two-hander"
            replaced = { mh }
        else
            replaced = { get(17) }
        end
        if loc == "INVTYPE_WEAPONOFFHAND" and not self:CanDualWield(info.class, info.level, info.spec) then
            return { ok = false, reason = "your character cannot dual wield", item = d, unusable = true }
        end
    elseif loc == "INVTYPE_WEAPON" and not self:CanDualWield(info.class, info.level, info.spec) then
        slot = 16
        replaced = { get(16) }
    else
        -- Two possible slots (rings, trinkets, one-handers when dual wielding): compare with the
        -- weaker one; an empty slot is filled first.
        local best
        for _, s in ipairs(slots) do
            local cur = get(s)
            if s == 17 and loc == "INVTYPE_WEAPON" then
                local mh = get(16)
                if mh and mh.equipLoc == "INVTYPE_2HWEAPON" then cur = nil s = nil end
            end
            if s then
                local sc = cur and (res.numeric and self:Score(cur, profile) or 0) or -1
                if not best or sc < best.sc then best = { slot = s, cur = cur, sc = sc } end
            end
        end
        slot = best and best.slot or slots[1]
        replaced = { best and best.cur or nil }
        if #slots == 2 and d.id then
            local other = get(slots[1] == slot and slots[2] or slots[1])
            if other and other.id == d.id then res.notes[#res.notes + 1] = "you already wear one (unique-equipped is not checked)" end
        end
    end
    res.slot = slot
    local current = {}
    for _, r in pairs(replaced) do if r then current[#current + 1] = r end end
    res.empty = #current == 0
    if #current > 0 and current[1].id == d.id and #current == 1 then res.same = true end

    if res.numeric then
        local merged = { stats = {} }
        for _, r in ipairs(current) do for k, v in pairs(r.stats) do merged.stats[k] = (merged.stats[k] or 0) + v end end
        local s, parts = self:Score(d, profile, merged)
        local cs = 0
        for _, r in ipairs(current) do cs = cs + (self:Score(r, profile, merged) or 0) end
        res.score, res.parts, res.current = s, parts, cs
        res.delta = s - cs
        if not res.empty and cs > 0 then res.pct = (s - cs) / cs * 100 end
    else
        local merged = { stats = {} }
        for _, r in ipairs(current) do for k, v in pairs(r.stats) do merged.stats[k] = (merged.stats[k] or 0) + v end end
        res.verdict, res.diffs = self:ComparePriority(d, merged, profile)
        if res.empty then res.verdict = "empty" end
    end
    return res
end

-- Short human text for stat differences: "+12 Agility, -5 Hit".
function Gear:FormatDiffs(diffs, max)
    local out = {}
    for i, x in ipairs(diffs or {}) do
        if max and i > max then break end
        out[#out + 1] = string.format("%+d %s", x.delta, self.STAT_NAMES[x.key] or x.key)
    end
    return table.concat(out, ", ")
end

-- One-line summary used by the tooltip, quest rewards and /tbcg gear.
function Gear:Summary(res, showPct)
    if not res.ok then return nil end
    if res.numeric then
        if res.empty then return string.format("Score %.0f (empty slot)", res.score) end
        if res.same then return string.format("Score %.0f (equipped)", res.score) end
        local s = string.format("Score %.0f vs %.0f equipped", res.score, res.current)
        if showPct and res.pct then s = s .. string.format(" (%+.0f%% score)", res.pct) end
        return s
    end
    if res.verdict == "empty" then return "Fills an empty slot" end
    if res.verdict == "same" then return "Same listed stats as equipped" end
    local word = { better = "Better", worse = "Worse", mixed = "Mixed" }
    return (word[res.verdict] or "?") .. " on listed stats: " .. self:FormatDiffs(res.diffs, 4)
end
