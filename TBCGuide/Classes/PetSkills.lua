-- TBCGuide - hunter pet and warlock demon skill guidance
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Data: Classes/PetData.lua (client tables). How each kind is learned differs (docs/PETS.md):
--   Hunter pets: the HUNTER first learns a skill rank (taming a beast that already knows it, or for
--     the general skills such as Growl, from a pet trainer); the PET then learns it in the Beast
--     Training window for training points. What the hunter knows and the training-point costs are
--     only visible while Beast Training is open; TBCGuide remembers them per character.
--   Warlock demons: each rank after the first is taught by a Grimoire bought from a demon trainer and
--     used while that demon is summoned. A demon's known skills are only visible while it is out;
--     TBCGuide remembers what it saw per character.
-- Advice only: nothing is bought, used, summoned, tamed, stabled or abandoned by TBCGuide.

local _, ns = ...

local PS = {}
ns.PetSkills = PS

local DEMON_SUMMON = { [23] = 688, [16] = 697, [17] = 712, [15] = 691, [29] = 30146 } -- family -> summon spell
local IMPORTANT = { Growl = true, Bite = true, Claw = true, Firebolt = true, Torment = true, ["Lash of Pain"] = true,
    ["Spell Lock"] = true, ["Devour Magic"] = true, Cleave = true, Anguish = true, ["Blood Pact"] = true }

local function char()
    local c = ns.char
    c.petSkills = type(c.petSkills) == "table" and c.petSkills or {}
    local t = c.petSkills
    t.beast = type(t.beast) == "table" and t.beast or {}   -- ["name#rank"] = { tp = n, level = n } (Beast Training)
    t.demon = type(t.demon) == "table" and t.demon or {}   -- [spellId] = true (seen on that demon)
    t.seen = type(t.seen) == "table" and t.seen or {}     -- [familyId] = true (demon summoned and read)
    return t
end
PS.Store = char

local function lname(id, fallback)
    local n = GetSpellInfo and GetSpellInfo(id)
    return n or fallback
end
local function rankNum(text) return tonumber(string.match(text or "", "(%d+)")) or 0 end

-- Pet spellbook as { ["localized name"] = highest rank }. nil when the client has no pet book API.
function PS:PetBook()
    local num = HasPetSpells and HasPetSpells()
    local nameOf = GetSpellBookItemName or GetSpellName
    if not num or not nameOf then return nil end
    local out = {}
    for i = 1, num do
        local n, sub = nameOf(i, BOOKTYPE_PET or "pet")
        if n then out[n] = math.max(out[n] or 0, rankNum(sub)) end
    end
    return out
end

-- Hunter -----------------------------------------------------------------------------------------------
-- The pet's family: by the family-only skills in its spellbook (works in every client language),
-- else by the English family name on English clients. nil = unknown.
function PS:HunterFamily(book)
    local H = ns.PetData.hunter
    local general = {}
    for _, id in ipairs(H.general) do general[id] = true end
    local best, bestN
    for fid, f in pairs(H.families) do
        local n = 0
        for _, id in ipairs(f.skills) do
            if not general[id] and book and book[lname(id, H.skills[id][1])] then n = n + 1 end
        end
        if n > 0 and (not bestN or n > bestN) then best, bestN = fid, n end
    end
    if best then return best end
    local fam = UnitCreatureFamily and UnitCreatureFamily("pet")
    if fam then for fid, f in pairs(H.families) do if f.name == fam then return fid end end end
    return nil
end

-- The craft window is Beast Training when its entries are hunter pet skills (Enchanting uses the
-- same window); recognized by content, so it works in every client language.
function PS:ScanBeastTraining()
    if ns.Compat.PlayerInfo().class ~= "HUNTER" or not (GetNumCrafts and GetCraftInfo) then return end
    local H = ns.PetData.hunter
    local petNames = {}
    for id, d in pairs(H.skills) do petNames[lname(id, d[1])] = true end
    local rows, match = {}, 0
    for i = 1, GetNumCrafts() or 0 do
        local name, sub, kind, _, _, tp, req = GetCraftInfo(i)
        if name and kind ~= "header" then
            rows[#rows + 1] = { name .. "#" .. rankNum(sub), tonumber(tp) or 0, tonumber(req) or 0 }
            if petNames[name] then match = match + 1 end
        end
    end
    if #rows == 0 or match * 2 < #rows then return end
    local store = char().beast
    for _, r in ipairs(rows) do store[r[1]] = { tp = r[2], level = r[3] } end
    self.btSeen = true
end

-- Recommendations for the active hunter pet: { name, rank, level, important, how, tp }.
function PS:HunterAdvice()
    local r = { recs = {} }
    if not (UnitExists and UnitExists("pet")) then r.state = "no pet" return r end
    local book = self:PetBook()
    if not book then r.state = "no api" return r end
    local H = ns.PetData.hunter
    local fid = self:HunterFamily(book)
    r.family = fid
    local petLevel = UnitLevel and UnitLevel("pet") or 0
    local tpTotal, tpSpent = 0, 0
    if GetPetTrainingPoints then tpTotal, tpSpent = GetPetTrainingPoints() end
    r.tp = (tonumber(tpTotal) or 0) - (tonumber(tpSpent) or 0)
    local ids = {}
    for _, id in ipairs(H.general) do ids[#ids + 1] = { id = id, general = true } end
    if fid then for _, id in ipairs(H.families[fid].skills) do ids[#ids + 1] = { id = id } end end
    local best = {} -- english name -> best rank row the pet's level allows
    local beast = char().beast
    for _, x in ipairs(ids) do
        local d = H.skills[x.id]
        if d then
            local nm, rank, lvl = d[1], d[2], d[3]
            local loc = lname(x.id, nm)
            local known = beast[loc .. "#" .. rank]
            local need = (lvl and lvl > 0) and lvl or (known and known.level) or nil
            if need and need <= petLevel and (not best[nm] or rank > best[nm].rank) then
                best[nm] = { id = x.id, name = loc, rank = rank, level = need, general = x.general, known = known }
            end
        end
    end
    for nm, b in pairs(best) do
        local have = book[b.name] or -1
        if have < b.rank and (have >= 0 or IMPORTANT[nm] or b.general) then
            local how
            if b.known then
                how = string.format("teach it in Beast Training (%d training points; you have %d)", b.known.tp, r.tp)
            elseif b.general then
                how = "you have not learned this rank yet: pet trainers teach Growl, Great Stamina, Natural Armor and the resistances; other general skills come from taming a beast that knows them"
            else
                how = "you have not learned this rank yet: tame a beast that knows it (stable your pet first so you keep it), keep the beast until you learn the skill, then teach it to your pet"
            end
            r.recs[#r.recs + 1] = { name = b.name, rank = b.rank, level = b.level, important = IMPORTANT[nm] or false, how = how, tp = b.known and b.known.tp }
        end
    end
    table.sort(r.recs, function(a, b) if a.important ~= b.important then return a.important end return a.name < b.name end)
    r.state = "ok"
    if not self.btSeen and not next(beast) then r.note = "Open Beast Training once so TBCGuide can see which skills you know and their training-point costs." end
    return r
end

-- Warlock ----------------------------------------------------------------------------------------------
function PS:ScanDemon()
    if not (UnitExists and UnitExists("pet")) then return end
    local book = self:PetBook()
    if not book then return end
    local st = char()
    for fid, d in pairs(ns.PetData.demons) do
        local hits = 0
        for _, s in ipairs(d.skills) do
            local loc = lname(s[1], s[2])
            if book[loc] and (s[3] == 0 or book[loc] >= s[3]) then st.demon[s[1]] = true hits = hits + 1 end
        end
        if hits > 0 then st.seen[fid] = true end
    end
end

local function bagItems()
    local have = {}
    local C = ns.Compat
    for bag = 0, C.NUM_BAGS do
        for slot = 1, (C.GetContainerNumSlots and C.GetContainerNumSlots(bag)) or 0 do
            local it = C.GetContainerItem(bag, slot)
            if it and it.itemID then have[it.itemID] = true end
        end
    end
    return have
end

-- Recommendations: { demon, name, rank, item, price, owned, state = "buy" | "unknown" }.
function PS:DemonAdvice()
    local r = { recs = {}, unseen = {} }
    local level = UnitLevel and UnitLevel("player") or 1
    local st, owned = char(), bagItems()
    for fid, d in pairs(ns.PetData.demons) do
        local summon = DEMON_SUMMON[fid]
        local hasDemon = summon and ns.Trainer.Known(summon)
        if hasDemon then
            if not st.seen[fid] then
                r.unseen[#r.unseen + 1] = lname(summon, d.name)
            else
                local best = {}
                for _, s in ipairs(d.skills) do
                    if s.item and (s.itemLevel or 99) <= level and not st.demon[s[1]] then
                        local b = best[s[2]]
                        if not b or s[3] > b[3] then best[s[2]] = s end
                    end
                end
                for nm, s in pairs(best) do
                    -- A higher rank already known makes this one pointless.
                    local higher = false
                    for _, o in ipairs(d.skills) do if o[2] == nm and o[3] > s[3] and st.demon[o[1]] then higher = true end end
                    if not higher then
                        r.recs[#r.recs + 1] = { demon = d.name, name = lname(s[1], s[2]), rank = s[3], item = s.item, price = s.price,
                            owned = owned[s.item] or false, important = IMPORTANT[nm] or false }
                    end
                end
            end
        end
    end
    table.sort(r.recs, function(a, b) if a.important ~= b.important then return a.important end return a.name < b.name end)
    return r
end

-- Text ---------------------------------------------------------------------------------------------------
function PS:Enabled() return ns.db.profile.trainerSuggestions ~= "off" end

function PS:Deferred()
    local d = ns.char.petDeferLevel
    return type(d) == "number" and (UnitLevel("player") or 1) <= d
end

function PS:Defer() ns.char.petDeferLevel = UnitLevel("player") or 1 end

-- Up to `max` lines for train steps; important skills first. Empty when nothing applies.
function PS:Lines(max)
    local out = {}
    if not self:Enabled() or self:Deferred() then return out end
    local class = ns.Compat.PlayerInfo().class
    local mode = ns.db.profile.trainerSuggestions
    if class == "HUNTER" then
        local a = self:HunterAdvice()
        for _, r in ipairs(a.recs) do
            if (r.important or mode == "all") and #out < (max or 3) then
                out[#out + 1] = string.format("- Pet: %s (Rank %d), pet level %d - %s.", r.name, r.rank, r.level, r.how)
            end
        end
    elseif class == "WARLOCK" then
        local a = self:DemonAdvice()
        for _, r in ipairs(a.recs) do
            if (r.important or mode == "all") and #out < (max or 3) then
                out[#out + 1] = string.format("- %s: %s (Rank %d) from a Grimoire, %s base price at a demon trainer%s; use it while the demon is summoned.",
                    r.demon, r.name, r.rank, ns.Compat.FormatMoney(r.price or 0), r.owned and " (you already have it)" or "")
            end
        end
        if #a.unseen > 0 and #out < (max or 3) then
            out[#out + 1] = "- Summon " .. table.concat(a.unseen, ", ") .. " once so TBCGuide can see which Grimoires it still needs."
        end
    end
    return out
end

function PS:Report()
    local class = ns.Compat.PlayerInfo().class
    if class == "HUNTER" then
        local a = self:HunterAdvice()
        if a.state == "no pet" then ns:Print("Pet skills: call your pet to see what it can still learn.") return end
        if a.state == "no api" then ns:Print("Pet skills: this client does not show the pet spellbook to add-ons.") return end
        if not a.family then ns:Print("Pet skills: TBCGuide could not tell your pet's family; only general skills are listed.") end
        if #a.recs == 0 then ns:Print("Pet skills: nothing new for your pet at its level.") end
        for _, r in ipairs(a.recs) do ns:Print(string.format("Pet: %s (Rank %d), pet level %d - %s.", r.name, r.rank, r.level, r.how)) end
        if a.note then ns:Print(a.note) end
        ns:Print("Training points available: " .. tostring(a.tp) .. ". TBCGuide never tames, stables or abandons pets.")
    elseif class == "WARLOCK" then
        local a = self:DemonAdvice()
        if #a.recs == 0 and #a.unseen == 0 then ns:Print("Demon skills: no Grimoire your demons still need at your level.") end
        for _, r in ipairs(a.recs) do
            ns:Print(string.format("%s: %s (Rank %d) - Grimoire, %s base price%s.", r.demon, r.name, r.rank,
                ns.Compat.FormatMoney(r.price or 0), r.owned and ", already in your bags: summon the demon and use it" or ""))
        end
        if #a.unseen > 0 then ns:Print("Summon " .. table.concat(a.unseen, ", ") .. " once so TBCGuide can see what it knows.") end
        local z, x, y, name = ns.Trainer:NearestNPC("Demon Trainer")
        if name then ns:Print("Nearest demon trainer: " .. name .. " (/tbcg pet waypoint).") end
        ns:Print("Prices are base prices; a reputation discount can lower them. TBCGuide never buys or uses Grimoires.")
    else
        ns:Print("Pet skills: only hunters and warlocks have pets that learn skills.")
    end
end

function PS:Waypoint()
    local class = ns.Compat.PlayerInfo().class
    local z, x, y, name = ns.Trainer:NearestNPC(class == "WARLOCK" and "Demon Trainer" or "Pet Trainer")
    if z then ns.Nav:SetTarget(z, x, y, name) return true end
    return false
end

function PS:Init()
    local class = ns.Compat.PlayerInfo().class
    if class ~= "HUNTER" and class ~= "WARLOCK" then return end
    ns:On("CRAFT_SHOW", function() PS:ScanBeastTraining() end)
    ns:On("CRAFT_UPDATE", function() PS:ScanBeastTraining() end)
    ns:On("UNIT_PET", function(_, unit) if unit == "player" then C_Timer.After(1, function() PS:ScanDemon() end) end end)
    ns:On("PET_BAR_UPDATE", function() ns:Throttle("pet-scan", 1, function() PS:ScanDemon() end) end)
    ns:On("PLAYER_LEVEL_UP", function(_, level)
        if ns.char.petDeferLevel and (tonumber(level) or 0) > ns.char.petDeferLevel then ns.char.petDeferLevel = nil end
    end)
end
