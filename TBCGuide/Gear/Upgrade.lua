-- TBCGuide - upgrade evaluation for automatic equipping, bag markers, tooltips and notifications
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- One evaluator, used by everything that says "upgrade": Gear/AutoEquip.lua, the BoE bag markers
-- and the bag tooltip lines (UI/GearMarkers.lua). It never equips anything itself.
--
-- An evaluation compares complete equipment configurations: the slots a candidate would change,
-- before and after (a two-hander against main hand + off hand together; rings and trinkets against
-- each of their two slots). Scores use the player's CHOSEN spec profile only (ns.char.gearProfile),
-- with the heuristic layer in Gear/Profiles.lua for priority-only profiles, weapon DPS and school
-- damage. Results are estimates of a spec score, never of DPS or healing. docs/AUTO_EQUIP.md.

local _, ns = ...

local U = { weightsCache = {}, last = {} }
ns.Upgrade = U

local function C() return ns.Compat end
local function G() return ns.Gear end
local function prof() return ns.db.profile end

local EPS = 1e-6

-- Exclusions (per character) -------------------------------------------------------------------------

function U:Exclusions()
    local e = ns.char.gearExclude
    if type(e) ~= "table" then e = {} ns.char.gearExclude = e end
    if type(e.items) ~= "table" then e.items = {} end
    if type(e.slots) ~= "table" then e.slots = {} end
    return e
end
function U:ItemExcluded(id) return id ~= nil and self:Exclusions().items[id] == true end
function U:SlotExcluded(slot) return self:Exclusions().slots[slot] == true end

-- Profile --------------------------------------------------------------------------------------------

-- The profile automatic upgrades use: only one the player chose for this character, of their class
-- and with a spec. Returns profile or nil, reason.
function U:ActiveProfile()
    local id = ns.char and ns.char.gearProfile
    if not id then return nil, "choose your spec profile first" end
    local p = G():ProfileById(id)
    if not p then return nil, "the saved profile no longer exists; choose your spec again" end
    if p.class ~= C().PlayerInfo().class then return nil, "the chosen profile is for another class" end
    if not p.spec then return nil, "choose a spec profile (leveling profiles are for tooltips only)" end
    return p
end

function U:ProfileName(p)
    if not p then return "?" end
    if p.role == "Tank" and p.spec == "Feral" then return "Feral Tank" end
    if p.spec == "Feral" then return "Feral DPS" end
    return p.spec or p.role or p.id
end

-- Weights for a profile: the sourced numbers when there are any, otherwise derived from the
-- priority order (heuristic). Plus heuristic weapon DPS and school damage values.
function U:Weights(p)
    local w = self.weightsCache[p.id]
    if w then return w end
    local H = ns.GearProfiles.heuristic
    w = { stats = {}, heuristic = {}, schools = {} }
    if p.weights then
        for k, v in pairs(p.weights) do w.stats[k] = v end
    else
        local list, seen = {}, {}
        for _, k in ipairs(p.priority or {}) do if not seen[k] then seen[k] = true list[#list + 1] = k end end
        local n = #list
        for i, k in ipairs(list) do
            local f = n > 1 and (H.rankTop - (H.rankTop - H.rankBottom) * (i - 1) / (n - 1)) or H.rankTop
            w.stats[k] = (H.budget[k] or 1) * f
        end
        w.heuristic[#w.heuristic + 1] = "stat weights estimated from the priority order"
    end
    -- Druid weapons only matter through Feral AP, which is already a stat.
    w.meleeDps = p.class == "DRUID" and 0 or (w.stats.ap or 0) * H.weaponDpsPerAp
    w.rangedDps = p.class == "HUNTER" and (w.stats.rap or 0) * H.weaponDpsPerAp or 0
    if w.meleeDps > 0 or w.rangedDps > 0 then w.heuristic[#w.heuristic + 1] = "weapon DPS estimated from attack power" end
    if p.schools and #p.schools > 0 then
        local sp = w.stats.sp or 0
        for _, sch in ipairs(p.schools) do w.schools[sch] = sp / #p.schools end
    end
    self.weightsCache[p.id] = w
    return w
end

-- Tooltip scan ----------------------------------------------------------------------------------------
-- A hidden tooltip shows what GetItemStats cannot: this copy's binding, red "cannot use" lines,
-- school damage and effects (use, chance on hit, unusual equip effects, set bonuses).

local function scanner()
    if U.tip then return U.tip end
    if not CreateFrame then return nil end
    local ok, t = pcall(CreateFrame, "GameTooltip", "TBCGuideScanTooltip", nil, "GameTooltipTemplate")
    if not ok or not t then return nil end
    if t.SetOwner then t:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE") end
    U.tip = t
    return t
end

-- Lines { text, r, g, b } of a bag item ("bag", bag, slot), a merchant item ("merchant", index),
-- an item link ("link", link) or an equipped item ("inv", slot).
function U.ScanLines(kind, a, b)
    local t = scanner()
    if not t or not t.ClearLines then return nil end
    t:ClearLines()
    local ok
    if kind == "bag" then
        local f = t.SetBagItem
        ok = f and pcall(f, t, a, b)
    elseif kind == "link" then
        local f = t.SetHyperlink
        ok = f and pcall(f, t, a)
    elseif kind == "merchant" then
        local f = t.SetMerchantItem
        ok = f and pcall(f, t, a)
    else
        local f = t.SetInventoryItem
        ok = f and pcall(f, t, "player", a)
    end
    if not ok then return nil end
    local name = t.GetName and t:GetName()
    local n = t.NumLines and t:NumLines() or 0
    local out = {}
    for i = 1, n do
        local fs = name and _G[name .. "TextLeft" .. i]
        local text = fs and fs.GetText and fs:GetText()
        if type(text) == "string" then
            local r, g, bl = 1, 1, 1
            if fs.GetTextColor then r, g, bl = fs:GetTextColor() end
            out[#out + 1] = { text, r or 1, g or 1, bl or 1 }
        end
    end
    return out
end

-- Facts from tooltip lines (Core/TooltipText.lua; locale-aware). `d` supplies GetItemStats keys so
-- non-English clients can tell stat lines from effects.
function U:Classify(lines, d)
    return ns.TooltipText.Classify(lines, d and d.statKeys)
end

-- Item records -----------------------------------------------------------------------------------------

-- Bag item with everything the evaluator needs, or nil, why ("empty" | "uncached" | "not equipment").
function U:BagItem(bag, slot)
    local c = C().GetContainerItem(bag, slot)
    if not c or not c.itemID then return nil, "empty" end
    local d, why = G():ItemData(c.link or c.itemID)
    if not d then return nil, why or "uncached" end
    if not G():IsEquippable(d) then return nil, "not equipment" end
    d.bag, d.slot, d.locked, d.boundFlag = bag, slot, c.locked, c.bound
    d.tip = self:Classify(self.ScanLines("bag", bag, slot), d)
    return d
end

-- Equipped item record for a slot: nil (empty), or d; second value "uncached" while loading.
function U:EquippedItem(slot)
    local f = C().Has("GetInventoryItemLink")
    local link = f and f("player", slot)
    if not link then return nil end
    local d, why = G():ItemData(link)
    if not d then return nil, why or "uncached" end
    d.invSlot = slot
    d.tip = self:Classify(self.ScanLines("inv", slot), d)
    return d
end

-- Binding of this copy: "bound" | "boe" (unbound, binds when equipped) | "nobind" | nil (unknown).
-- The instance state wins over the template; when neither the client flag nor the tooltip says,
-- the answer is nil and nothing is equipped automatically.
function U:BindState(d)
    if d.boundFlag == true or (d.tip and d.tip.bound == true) then return "bound" end
    local bt = d.bindType
    if bt == nil then return nil end
    if bt == 0 or bt == 3 or bt == 4 then return "nobind" end -- none, on use, quest: equipping never binds
    if bt == 2 then
        if d.boundFlag == false or (d.tip and d.tip.boe) then return "boe" end
        return nil
    end
    return nil -- bind on pickup but not reported bound: unknown, do not touch
end

-- Usability now: class rules, level, dual wield, and the client's red "cannot use" tooltip text.
function U:CanEquipNow(d, info)
    local ok, why = G():ClassCanUse(d, info.class, info.level, info.spec)
    if not ok then return false, why end
    if (d.reqLevel or 0) > (info.level or 1) then return false, "requires level " .. d.reqLevel end
    if d.tip and d.tip.red then return false, "the client marks it as unusable" end
    local f = C().Has("IsEquippableItem")
    if f and d.link and f(d.link) == false then return false, "not equippable" end
    return true
end

-- Scoring ----------------------------------------------------------------------------------------------

local CR = { hit = 6, spellhit = 8, exp = 24, def = 2 }

local function ratingNow(key)
    local f = C().Has("GetCombatRating")
    if not f or not CR[key] then return nil end
    local ok, v = pcall(f, CR[key])
    return ok and tonumber(v) or nil
end

-- Score of a set of items { [slot] = d }. `base` = rating the player has WITHOUT the slots being
-- compared (shared by both sides), so caps are consumed consistently; caps only at level 70, where
-- the profile's level-70 cap assumptions apply.
function U:ScoreSet(set, p, w, base)
    local H = ns.GearProfiles.heuristic
    local used = {}
    for k, v in pairs(base or {}) do used[k] = v end
    local total = 0
    local slots = {}
    for s in pairs(set) do slots[#slots + 1] = s end
    table.sort(slots)
    for _, s in ipairs(slots) do
        local d = set[s]
        for k, amt in pairs(d.stats or {}) do
            local wt = w.stats[k]
            if wt and wt ~= 0 and amt ~= 0 then
                local eff = amt
                local cap = p.caps and p.caps[k]
                if cap and used[k] then
                    eff = math.max(0, math.min(amt, cap - used[k]))
                    used[k] = used[k] + eff
                end
                total = total + eff * wt
            end
        end
        if d.dps then
            if s == 18 then total = total + d.dps * w.rangedDps
            elseif s == 16 then total = total + d.dps * w.meleeDps
            elseif s == 17 then total = total + d.dps * w.meleeDps * H.offHandFactor end
        end
        for sch, amt in pairs(d.tip and d.tip.schoolDmg or {}) do total = total + amt * (w.schools[sch] or 0) end
    end
    return total
end

-- Percentage text shared by markers, tooltips and notifications.
function U.PctText(e)
    if e.kind == "empty" then return "Empty slot filled" end
    local pct = e.pct
    if not pct or pct ~= pct or pct == math.huge or pct == -math.huge then return "Upgrade - percentage unavailable" end
    return string.format("%+.1f%% estimated spec score", pct)
end

-- Candidate options ----------------------------------------------------------------------------------------

-- Which slots a candidate can go to, as { target=, affected={slots} } options; nil, why when none
-- is valid (e.g. it would break a two-hander setup).
function U:Options(d, info, eq)
    local loc = d.equipLoc
    local mh = eq[16]
    local mh2h = mh and mh.equipLoc == "INVTYPE_2HWEAPON"
    local dw = G():CanDualWield(info.class, info.level, info.spec)
    if loc == "INVTYPE_2HWEAPON" then return { { target = 16, affected = { 16, 17 } } } end
    if loc == "INVTYPE_WEAPONMAINHAND" or (loc == "INVTYPE_WEAPON" and not dw) then
        return { { target = 16, affected = { 16 } } }
    end
    if loc == "INVTYPE_WEAPON" then
        local o = { { target = 16, affected = { 16 } } }
        if mh and not mh2h then o[#o + 1] = { target = 17, affected = { 17 } } end
        return o
    end
    if loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
        if loc == "INVTYPE_WEAPONOFFHAND" and not dw then return nil, "your character cannot dual wield" end
        if mh2h then return nil, "would leave the two-hander's slot empty" end
        return { { target = 17, affected = { 17 } } }
    end
    local o = {}
    for _, s in ipairs(G().SLOTS[loc] or {}) do o[#o + 1] = { target = s, affected = { s } } end
    return o
end

-- Evaluation ---------------------------------------------------------------------------------------------

-- Evaluates bag item d against what is equipped. `ctx` = { info, profile, weights, eq, base }.
-- Returns e = { ok, kind = "empty" | "upgrade" | nil, target, replaced = {d...}, pct, delta,
--   newScore, oldScore, uncertain = reason|nil, displaced = n, bind, reason, heuristic = {...} }
function U:Evaluate(d, ctx)
    local e = { ok = false, item = d, bind = self:BindState(d), heuristic = ctx.weights.heuristic }
    if self:ItemExcluded(d.id) then e.reason = "excluded from automatic upgrades" return e end
    local can, why = self:CanEquipNow(d, ctx.info)
    if not can then e.reason = why return e end
    local opts, owhy = self:Options(d, ctx.info, ctx.eq)
    if not opts or #opts == 0 then e.reason = owhy or "no valid slot" return e end
    local best
    for _, o in ipairs(opts) do
        local before, after, blocked, effects = {}, {}, nil, {}
        local displaced = 0
        for _, s in ipairs(o.affected) do
            if self:SlotExcluded(s) then blocked = "slot " .. (G().SLOT_NAMES[s] or s) .. " is protected" end
            local cur = ctx.eq[s]
            if cur then
                before[s] = cur
                displaced = displaced + 1
                if self:ItemExcluded(cur.id) then blocked = "the equipped item is protected" end
                for _, x in ipairs(cur.tip and cur.tip.effects or {}) do effects[#effects + 1] = "equipped item has a " .. x end
            end
        end
        after[o.target] = d
        if not blocked then
            local x = { option = o, target = o.target, displaced = displaced, replaced = {} }
            for _, s in ipairs(o.affected) do if before[s] then x.replaced[#x.replaced + 1] = before[s] end end
            x.empty = displaced == 0
            local base = ctx.base and {} or nil
            if base then
                for k, v in pairs(ctx.base) do
                    local minus = 0
                    for _, s in ipairs(o.affected) do
                        local cur = before[s]
                        if cur and cur.stats[k] then minus = minus + cur.stats[k] end
                    end
                    base[k] = v - minus
                end
            end
            x.oldScore = self:ScoreSet(before, ctx.profile, ctx.weights, base)
            x.newScore = self:ScoreSet(after, ctx.profile, ctx.weights, base)
            x.delta = x.newScore - x.oldScore
            for _, y in ipairs(d.tip and d.tip.effects or {}) do effects[#effects + 1] = "has a " .. y end
            if o.target == 11 or o.target == 12 or o.target == 13 or o.target == 14 then
                local other = ctx.eq[(o.target % 2 == 1) and o.target + 1 or o.target - 1]
                if other and other.id == d.id then effects[#effects + 1] = "unique-equipped is not checked" end
            end
            x.uncertain = effects[1]
            if not x.empty and x.oldScore > EPS then x.pct = x.delta / x.oldScore * 100 end
            -- Prefer an empty slot; otherwise the option with the biggest gain.
            if not best or (x.empty and not best.empty) or (x.empty == best.empty and x.delta > best.delta + EPS) then best = x end
        elseif not e.reason then
            e.reason = blocked
        end
    end
    if not best then return e end
    e.ok = true
    for k, v in pairs(best) do if k ~= "option" then e[k] = v end end
    if best.empty then
        e.kind = "empty"
    elseif best.delta > EPS and best.newScore > EPS then
        -- ctx.minPct lets a caller with its own filter (the auction Upgrades tab) see every upgrade.
        local minPct = tonumber(ctx.minPct or prof().autoEquipMinPct) or 0
        if best.pct then
            if best.pct >= minPct and best.pct > EPS then e.kind = "upgrade" else e.reason = "below your minimum upgrade" end
        elseif minPct <= 0 then
            e.kind = "upgrade" -- baseline 0: an improvement, but no percentage
        else
            e.reason = "percentage unavailable, minimum upgrade not checked"
        end
    else
        e.reason = (math.abs(best.delta) <= EPS) and "same score as equipped" or "not an upgrade"
    end
    return e
end

-- Context for one pass: profile, weights, equipped items and rating base. Returns ctx or nil, why
-- (why = "uncached" when an equipped item is still loading: wait instead of scoring it as 0).
function U:Context()
    local p, why = self:ActiveProfile()
    if not p then return nil, why end
    local info = C().PlayerInfo()
    info.spec = G():DetectSpec(info.class)
    local ctx = { profile = p, weights = self:Weights(p), info = info, eq = {} }
    for _, s in ipairs(G().SCORED_SLOTS) do
        local d, w = self:EquippedItem(s)
        if w == "uncached" then return nil, "uncached" end
        ctx.eq[s] = d
    end
    if (info.level or 1) >= 70 then
        ctx.base = {}
        for k in pairs(CR) do
            local v = ratingNow(k)
            if v then ctx.base[k] = v else ctx.base = nil break end
        end
    end
    return ctx
end

-- Evaluates every equippable bag item. Returns list of e (with bag/slot on e.item), ctx, pending
-- (true when some bag item is not loaded yet). Stores the results for tooltips.
function U:ScanBags()
    local ctx, why = self:Context()
    self.last = {}
    if not ctx then return {}, nil, why == "uncached", why end
    local out, pending = {}, false
    for bag = 0, C().NUM_BAGS do
        for slot = 1, C().GetContainerNumSlots(bag) do
            local d, dwhy = self:BagItem(bag, slot)
            if d then
                local e = self:Evaluate(d, ctx)
                out[#out + 1] = e
                self.last[bag .. ":" .. slot] = e
            elseif dwhy == "uncached" then
                pending = true
            end
        end
    end
    return out, ctx, pending
end

-- Cleared whenever the chosen profile changes (weights depend on it).
function U:Reset()
    self.weightsCache = {}
    self.last = {}
end
