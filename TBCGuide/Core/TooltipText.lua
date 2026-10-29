-- TBCGuide - locale-aware reading of item tooltip lines (binding, effects, unusable)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Order of trust (docs/LOCALES.md):
--   1. Structured data, used by the callers: the bag API's per-copy isBound, GetItemInfo's bindType,
--      GetItemStats.
--   2. The client's own localized global strings: ITEM_SOULBOUND, ITEM_BIND_ON_EQUIP / _PICKUP /
--      _USE, ITEM_SPELL_TRIGGER_ONUSE / ONEQUIP / ONPROC, ITEM_SET_BONUS(_GRAY). These match the
--      tooltip text in every client language because the client itself builds the tooltip from them.
--   3. English stat-line patterns, ONLY on English clients (enUS/enGB), where they were verified.
--      Elsewhere an "Equip:" line is explained by counting: GetItemStats reports the stats the client
--      shows as "Equip:" lines; more lines than stats means an effect TBCGuide cannot score, which
--      makes the comparison uncertain. Nothing unparsed is ever treated as a confirmed zero.
-- Binding never comes from a guess: no match leaves it unknown (nil), and unknown never equips.

local _, ns = ...

local TT = {}
ns.TooltipText = TT

-- English fallbacks, used only when the client does not provide the global (tests, old builds).
local EN = {
    ITEM_SOULBOUND = "Soulbound", ITEM_BIND_ON_EQUIP = "Binds when equipped", ITEM_BIND_ON_PICKUP = "Binds when picked up",
    ITEM_BIND_ON_USE = "Binds when used", ITEM_SPELL_TRIGGER_ONUSE = "Use:", ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:",
    ITEM_SPELL_TRIGGER_ONPROC = "Chance on hit:", ITEM_SET_BONUS = "Set: %s", ITEM_SET_BONUS_GRAY = "(%d) Set: %s",
}
local function g(name) local v = _G[name] if type(v) == "string" and v ~= "" then return v end return EN[name] end
TT.G = g

function TT.Locale() return (GetLocale and GetLocale()) or "enUS" end
function TT.IsEnglish(loc) loc = loc or TT.Locale() return loc == "enUS" or loc == "enGB" end

-- Text before the first format token of a global like "(%d) Set: %s" -> "(" is too short to use,
-- so set lines are matched on the part after the count: "Set:" / "Set :" (fr) etc.
local function prefix(fmt)
    local p = string.gsub(fmt, "%%[%d%$]*[sd].*$", "")
    return p
end
local function setWord(fmt)
    -- "(%d) Set: %s" -> "Set:"; "Set: %s" -> "Set:"; keeps a localized word plus its colon.
    local s = string.gsub(fmt, "%%[%d%$]*d", "")
    s = string.gsub(s, "%%[%d%$]*s", "")
    s = string.gsub(s, "[%(%)]", "")
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function starts(text, head) return head and head ~= "" and string.sub(text, 1, #head) == head end

-- Stats the client shows as "Equip:" lines in TBC (the rest are plain "+N Stat" lines).
TT.EQUIP_KEYS = {
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = true, ITEM_MOD_SPELL_HEALING_DONE_SHORT = true, ITEM_MOD_SPELL_POWER_SHORT = true,
    ITEM_MOD_ATTACK_POWER_SHORT = true, ITEM_MOD_RANGED_ATTACK_POWER_SHORT = true, ITEM_MOD_FERAL_ATTACK_POWER_SHORT = true,
    ITEM_MOD_MANA_REGENERATION_SHORT = true, ITEM_MOD_POWER_REGEN0_SHORT = true, ITEM_MOD_HEALTH_REGEN_SHORT = true,
    ITEM_MOD_BLOCK_VALUE_SHORT = true, ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = true, ITEM_MOD_SPELL_PENETRATION_SHORT = true,
}
local function isRating(k) return string.find(k, "_RATING_SHORT$") ~= nil end

-- How many "Equip:" lines GetItemStats explains. TBC healing gear shows "+healing and +damage"
-- as ONE line, so that pair counts once.
function TT.ExplainedEquipLines(statKeys)
    local n, heal, dmg = 0, false, false
    for k in pairs(statKeys or {}) do
        if TT.EQUIP_KEYS[k] or (isRating(k) and k ~= "ITEM_MOD_RESILIENCE_RATING_SHORT") then n = n + 1 end
        if k == "ITEM_MOD_RESILIENCE_RATING_SHORT" then n = n + 1 end
        if k == "ITEM_MOD_SPELL_HEALING_DONE_SHORT" then heal = true end
        if k == "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" then dmg = true end
    end
    if heal and dmg then n = n - 1 end
    return n
end

-- English equip lines GetItemStats already reports (verified on enUS tooltips).
TT.EN_STAT_EQUIP = {
    "^Equip: Increases damage and healing done by magical spells", "^Equip: Increases healing done",
    "^Equip: Improves .- rating by %d+", "^Equip: Increases your .- rating by %d+", "^Equip: Increases defense rating",
    "^Equip: Increases attack power by %d+", "^Equip: Increases ranged attack power by %d+",
    "^Equip: Restores %d+ mana per 5 sec", "^Equip: Increases the block value of your shield",
    "^Equip: Your attacks ignore %d+ of your opponent's armor", "^Equip: Increases your spell penetration",
    "^Equip: Increases spell damage", "^Equip: Increases spell power",
}
-- English school damage ("+N Shadow damage") on enUS only; elsewhere it stays an unexplained line.
TT.EN_SCHOOL = "^Equip: Increases damage done by (%a+) spells and effects by up to ([%d,%.]+)"

local function number(s)
    s = string.gsub(s or "", "[,%.](%d%d%d)", "%1") -- 1,234 / 1.234 thousands separators
    return tonumber(s)
end
TT.Number = number

-- Classify tooltip lines { {text, r, g, b} } of an item whose GetItemStats keys are `statKeys`.
-- Returns { bound = true/false/nil, boe = bool, bop = bool, red = bool, effects = {...},
--           schoolDmg = {School = n}, equipLines = n, unexplained = n, locale = "xxXX" }
function TT.Classify(lines, statKeys, locale)
    locale = locale or TT.Locale()
    local english = TT.IsEnglish(locale)
    local r = { effects = {}, schoolDmg = {}, equipLines = 0, unexplained = 0, locale = locale }
    if not lines then return r end
    local soul, boe, bop, bou = g("ITEM_SOULBOUND"), g("ITEM_BIND_ON_EQUIP"), g("ITEM_BIND_ON_PICKUP"), g("ITEM_BIND_ON_USE")
    local use, equip, proc = g("ITEM_SPELL_TRIGGER_ONUSE"), g("ITEM_SPELL_TRIGGER_ONEQUIP"), g("ITEM_SPELL_TRIGGER_ONPROC")
    local setA, setB = setWord(g("ITEM_SET_BONUS")), setWord(g("ITEM_SET_BONUS_GRAY"))
    local unknownEquip = 0
    for i, l in ipairs(lines) do
        local t = l[1]
        if type(t) == "string" then
            -- Binding: whole-line matches of the client's own strings only.
            if t == soul then r.bound = true end
            if t == boe then r.boe = true if r.bound == nil then r.bound = false end end
            if t == bop then r.bop = true end
            if t == bou and r.bound == nil then r.bound = false end
            if i > 1 and l[2] and l[2] > 0.99 and (l[3] or 1) < 0.2 and (l[4] or 1) < 0.2 then r.red = true end
            if starts(t, use) then
                r.effects[#r.effects + 1] = "use effect"
            elseif starts(t, proc) then
                r.effects[#r.effects + 1] = "chance-on-hit effect"
            elseif (setA ~= "" and string.find(t, setA, 1, true) and string.find(t, "^%(%d+%)")) or (setA ~= "" and starts(t, setA)) or (setB ~= "" and starts(t, setB)) then
                r.effects[#r.effects + 1] = "set bonus"
            elseif starts(t, equip) then
                r.equipLines = r.equipLines + 1
                if english then
                    local sch, amt = string.match(t, TT.EN_SCHOOL)
                    if sch then
                        r.schoolDmg[sch] = (r.schoolDmg[sch] or 0) + (number(amt) or 0)
                    else
                        local known = false
                        for _, pat in ipairs(TT.EN_STAT_EQUIP) do if string.find(t, pat) then known = true break end end
                        if not known then r.effects[#r.effects + 1] = "equip effect" end
                    end
                else
                    unknownEquip = unknownEquip + 1
                end
            end
        end
    end
    if not english and unknownEquip > 0 then
        local extra = unknownEquip - TT.ExplainedEquipLines(statKeys)
        if extra > 0 then
            r.unexplained = extra
            r.effects[#r.effects + 1] = "equip effect not read in this client language"
            if ns.Debug then ns:Debug("tooltip: " .. extra .. " Equip line(s) not explained by item stats (" .. locale .. ")") end
        end
    end
    return r
end
