-- TBCGuide - headless tests for tooltip locales, bag add-on adapters and first-login setup
-- (loaded by run_tests.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Locale fixtures set the client's global strings the way a German or French client defines them,
-- then classify tooltip lines written in that language. Bag add-ons are stand-ins with the same
-- entry points as the versions read for UI/BagAdapters.lua; nothing here loads the real add-ons.

local check, ns = TEST.check, TEST.ns
local TT = ns.TooltipText

-- 1) Tooltip text --------------------------------------------------------------------------------
local GLOBALS = { "ITEM_SOULBOUND", "ITEM_BIND_ON_EQUIP", "ITEM_BIND_ON_PICKUP", "ITEM_BIND_ON_USE",
    "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONPROC", "ITEM_SET_BONUS", "ITEM_SET_BONUS_GRAY" }
local saved = {}
for _, k in ipairs(GLOBALS) do saved[k] = _G[k] end
local function useStrings(t) for _, k in ipairs(GLOBALS) do _G[k] = t[k] end end
local function L(...) local out = {} for i, t in ipairs({ ... }) do out[i] = { t, 1, 1, 1 } end return out end
local function has(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

-- English (client globals absent: the English fallbacks apply).
useStrings({})
local r = TT.Classify(L("Shiny Belt", "Binds when equipped", "Equip: Increases attack power by 20."), { ITEM_MOD_ATTACK_POWER_SHORT = true }, "enUS")
check(r.boe and r.bound == false and #r.effects == 0, "enUS: unbound BoE, known stat line is no effect")
r = TT.Classify(L("Shiny Belt", "Soulbound", "Binds when equipped"), nil, "enUS")
check(r.bound == true and r.boe, "enUS: Soulbound wins over the BoE line")
r = TT.Classify(L("Cloak", "Binds when picked up", "Equip: Chance to fly away."), nil, "enGB")
check(r.bop and r.bound == nil and has(r.effects, "equip effect"), "enGB: BoP alone leaves binding unknown; unknown Equip line is an effect")
r = TT.Classify(L("Staff", "Equip: Increases damage done by Shadow spells and effects by up to 1,234."), nil, "enUS")
check(r.schoolDmg.Shadow == 1234 and #r.effects == 0, "enUS: school damage with a thousands separator")
r = TT.Classify(L("Trinket", "Use: Restores 500 mana.", "Chance on hit: Burns."), nil, "enUS")
check(has(r.effects, "use effect") and has(r.effects, "chance-on-hit effect"), "enUS: use and proc effects")
r = TT.Classify(L("Helm", "(2) Set: +10 Stamina."), nil, "enUS")
check(has(r.effects, "set bonus"), "enUS: grey set bonus line")
r = TT.Classify(L("Belt", "Binds when equipped to account"), nil, "enUS")
check(not r.boe and r.bound == nil, "enUS: similar text is not a binding line")
local red = TT.Classify({ { "Belt", 1, 1, 1 }, { "Requires Level 40", 1, 0.1, 0.1 } }, nil, "enUS")
check(red.red and not TT.Classify({ { "Belt", 1, 0.1, 0.1 } }, nil, "enUS").red, "red requirement lines (not the item name)")
r = TT.Classify(nil, nil, "enUS")
check(r.bound == nil and #r.effects == 0 and r.unexplained == 0, "missing tooltip: nothing known, nothing assumed")

-- German client.
useStrings({ ITEM_SOULBOUND = "Seelengebunden", ITEM_BIND_ON_EQUIP = "Wird beim Anlegen gebunden",
    ITEM_BIND_ON_PICKUP = "Wird beim Aufheben gebunden", ITEM_BIND_ON_USE = "Wird bei Benutzung gebunden",
    ITEM_SPELL_TRIGGER_ONUSE = "Benutzen:", ITEM_SPELL_TRIGGER_ONEQUIP = "Anlegen:", ITEM_SPELL_TRIGGER_ONPROC = "Trefferchance:",
    ITEM_SET_BONUS = "Set: %s", ITEM_SET_BONUS_GRAY = "(%d) Set: %s" })
r = TT.Classify(L("Gürtel", "Wird beim Anlegen gebunden", "Anlegen: Erhöht die Angriffskraft um 20."), { ITEM_MOD_ATTACK_POWER_SHORT = true }, "deDE")
check(r.boe and r.bound == false and #r.effects == 0 and r.unexplained == 0, "deDE: BoE from the client string; stat line explained by GetItemStats")
r = TT.Classify(L("Gürtel", "Seelengebunden", "Wird beim Anlegen gebunden"), nil, "deDE")
check(r.bound == true, "deDE: Seelengebunden is bound")
r = TT.Classify(L("Gürtel", "Binds when equipped"), nil, "deDE")
check(not r.boe and r.bound == nil, "deDE: English text is not trusted on a German client")
r = TT.Classify(L("Gürtel", "Anlegen: Erhöht die Angriffskraft um 20.", "Anlegen: Lässt Euch fliegen."), { ITEM_MOD_ATTACK_POWER_SHORT = true }, "deDE")
check(r.unexplained == 1 and has(r.effects, "equip effect not read in this client language"), "deDE: one Equip line more than the stats is an unread effect")
r = TT.Classify(L("Robe", "Anlegen: Erhöht durch Zauber und Effekte verursachte Heilung um bis zu 44 und den Schaden um bis zu 15."),
    { ITEM_MOD_SPELL_HEALING_DONE_SHORT = true, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = true }, "deDE")
check(r.unexplained == 0 and #r.effects == 0, "deDE: healing+damage is one Equip line")
r = TT.Classify(L("Schmuck", "Benutzen: Stellt 500 Mana wieder her.", "(2) Set: +10 Ausdauer."), nil, "deDE")
check(has(r.effects, "use effect") and has(r.effects, "set bonus"), "deDE: use effect and set bonus")
r = TT.Classify(L("Stab", "Anlegen: Erhöht durch Schattenzauber verursachten Schaden um bis zu 30."), nil, "deDE")
check(next(r.schoolDmg) == nil and r.unexplained == 1, "deDE: school damage is not parsed, it stays an unread effect")

-- French client.
useStrings({ ITEM_SOULBOUND = "Lié", ITEM_BIND_ON_EQUIP = "Lié quand équipé", ITEM_BIND_ON_PICKUP = "Lié quand ramassé",
    ITEM_BIND_ON_USE = "Lié quand utilisé", ITEM_SPELL_TRIGGER_ONUSE = "Utiliser :", ITEM_SPELL_TRIGGER_ONEQUIP = "Équipé :",
    ITEM_SPELL_TRIGGER_ONPROC = "Chances quand vous touchez :", ITEM_SET_BONUS = "Ensemble : %s", ITEM_SET_BONUS_GRAY = "(%d) Ensemble : %s" })
r = TT.Classify(L("Ceinture", "Lié quand équipé"), nil, "frFR")
check(r.boe and r.bound == false, "frFR: Lié quand équipé is unbound BoE (whole-line match, not the prefix Lié)")
r = TT.Classify(L("Ceinture", "Lié", "Lié quand équipé"), nil, "frFR")
check(r.bound == true, "frFR: Lié is bound")
r = TT.Classify(L("Casque", "(2) Ensemble : +10 Endurance.", "Utiliser : Rend 500 points de mana."), nil, "frFR")
check(has(r.effects, "set bonus") and has(r.effects, "use effect"), "frFR: set bonus and use effect")
r = TT.Classify(L("Bague", "Équipé : Augmente le score de coup critique de 14."), { ITEM_MOD_CRIT_RATING_SHORT = true }, "frFR")
check(r.unexplained == 0 and #r.effects == 0, "frFR: rating line explained by GetItemStats")

-- A client language nobody verified: same conservative counting.
r = TT.Classify(L("Ceinture", "Équipé : Inconnu."), nil, "xxXX")
check(not TT.IsEnglish("xxXX") and r.unexplained == 1, "unknown locale: unexplained Equip lines are counted, not guessed")

check(TT.Number("1,234") == 1234 and TT.Number("1.234") == 1234 and TT.Number("12") == 12 and TT.Number("") == nil, "number formats")
for _, k in ipairs(GLOBALS) do _G[k] = saved[k] end

-- 2) Bag add-on adapters ---------------------------------------------------------------------------
local BA, GM = ns.BagAdapters, ns.GearMarkers
local function texture()
    local t = { shown = false }
    function t:SetTexture(x) self.tex = x end
    function t:SetSize() end
    function t:SetPoint() end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end
local function button(fields)
    local b = fields or {}
    function b:CreateTexture() return texture() end
    function b:IsVisible() return true end
    return b
end
local ITEM, OTHER = 95501, 95502
MOCK.items[ITEM] = { name = "Test Belt", quality = 2, sellPrice = 100, classID = 4, bindType = 2 }
MOCK.items[OTHER] = { name = "Other Belt", quality = 2, sellPrice = 100, classID = 4, bindType = 2 }
local bag0 = {}
for k, v in pairs(MOCK.bags[0]) do bag0[k] = v end
MOCK.bags[0][3] = { itemID = ITEM }
local marksBefore, junkBefore = GM.marks, GM.junk
GM.marks = { ["0:3"] = { ok = true, bind = "boe", kind = "upgrade", item = { id = ITEM, bag = 0, slot = 3 } } }
GM.junk = {}
local realHook, realStub, realBag = hooksecurefunc, LibStub, BagBrother

-- Bagnon
local hooks = {}
hooksecurefunc = function(t, name, fn) hooks[#hooks + 1] = { t = t, name = name, fn = fn } end
BagBrother = { ContainerItem = { Update = function() end } }
BA.active = {}
check(BA:Bagnon() and #hooks == 1 and hooks[1].name == "Update" and not BA:Bagnon(), "Bagnon: one post-hook on ContainerItem:Update")
local bb = button({ bag = 0, GetID = function() return 3 end, IsCached = function() return false end })
hooks[1].fn(bb)
check(GM.external[bb] and GM.overlays[bb] and GM.overlays[bb].shown, "Bagnon: marked BoE slot shows the arrow")
MOCK.bags[0][3] = { itemID = OTHER }
GM:RefreshAll()
check(not GM.overlays[bb].shown, "Bagnon: a different item in the slot hides the stale arrow")
MOCK.bags[0][3] = { itemID = ITEM }
local cached = button({ bag = 0, GetID = function() return 3 end, IsCached = function() return true end })
hooks[1].fn(cached)
check(not (GM.overlays[cached] and GM.overlays[cached].shown), "Bagnon: offline (cached) character view shows nothing")
local bank = button({ bag = -1, GetID = function() return 3 end, IsCached = function() return false end })
hooks[1].fn(bank)
check(not (GM.overlays[bank] and GM.overlays[bank].shown) and BA.BagnonResolve(bank) == nil, "Bagnon: bank buttons are left alone")

-- AdiBags
local mod
local adi = { IsEnabled = function() return true end }
function adi:NewModule(name)
    mod = { name = name, handlers = {} }
    function mod:RegisterMessage(msg, fn) self.handlers[msg] = fn end
    function mod:Enable() self:OnEnable() end
    return mod
end
LibStub = function(lib) if lib == "AceAddon-3.0" then return { GetAddon = function(_, n) return n == "AdiBags" and adi or nil end } end end
check(BA:AdiBags() and mod.name == "TBCGuideMarkers" and mod.handlers.AdiBags_UpdateButton, "AdiBags: module created and enabled at once")
local ab = button({ bag = 0, slot = 3, IsBank = function() return false end })
mod.handlers.AdiBags_UpdateButton("AdiBags_UpdateButton", ab)
check(GM.overlays[ab] and GM.overlays[ab].shown, "AdiBags: marked slot shows the arrow")
local abank = button({ bag = 0, slot = 3, IsBank = function() return true end })
check(BA.AdiResolve(abank) == nil, "AdiBags: bank buttons are left alone")

-- Baganator
local corner, junkPlugin, refreshes = nil, nil, {}
Baganator = { API = {
    RegisterCornerWidget = function(label, id, onUpdate, onInit, pos) corner = { label = label, id = id, onUpdate = onUpdate, onInit = onInit, pos = pos } end,
    RegisterJunkPlugin = function(label, id, cb) junkPlugin = { id = id, cb = cb } end,
    RequestItemButtonsRefresh = function(r2) refreshes[#refreshes + 1] = r2 end,
}, Constants = { RefreshReason = { ItemWidgets = 7 } } }
check(BA:Baganator() and corner and corner.id == "tbcguide_boe_upgrade" and junkPlugin and junkPlugin.id == "tbcguide", "Baganator: corner widget and junk plugin registered")
local parent0 = { GetID = function() return 0 end }
local gb = button({ GetID = function() return 3 end, GetParent = function() return parent0 end })
local widget = corner.onInit(gb)
check(widget.tbcgButton == gb and GM.tipOnly[gb] == BA.BaganatorResolve, "Baganator: widget knows its button; tooltip lines enabled")
check(corner.onUpdate(widget, { itemID = ITEM }) == true and corner.onUpdate(widget, { itemID = OTHER }) == false, "Baganator: arrow only for the marked item")
local bankParent = { GetID = function() return -1 end }
local gbank = button({ GetID = function() return 3 end, GetParent = function() return bankParent end })
check(corner.onUpdate(corner.onInit(gbank), { itemID = ITEM }) == false, "Baganator: bank view shows nothing")
check(junkPlugin.cb(-1, 1, ITEM) == nil and junkPlugin.cb(0, 9, nil) == false, "Baganator junk: bank unknown, empty slot not junk")
BA:Refresh()
check(#refreshes == 1 and refreshes[1][1] == 7, "Baganator: item widget refresh requested after marks change")

-- No bag add-on: nothing happens.
BagBrother, LibStub, Baganator = nil, nil, nil
BA.active = {}
check(not BA:Bagnon() and not BA:AdiBags() and not BA:Baganator(), "no bag add-on: adapters stay off")
BA.active = {}

hooksecurefunc, LibStub, BagBrother = realHook, realStub, realBag
for k in pairs(GM.external) do GM.external[k] = nil end
for k in pairs(GM.tipOnly) do GM.tipOnly[k] = nil end
GM.marks, GM.junk = marksBefore, junkBefore
MOCK.bags[0] = bag0

-- 3) First-login setup --------------------------------------------------------------------------
local WL, c, prof = ns.Welcome, ns.char, ns.db.profile
local keep = { setupDone = c.setupDone, setupDraft = c.setupDraft, gearProfile = c.gearProfile, autoEquip = prof.autoEquip }
local guideBefore = c.activeGuide

c.setupDone, c.setupDraft = nil, nil
WL:Migrate()
check(c.setupDone == true, "existing user (guide or progress) is migrated as already set up")

c.setupDone, c.setupDraft, c.gearProfile = nil, nil, nil
local realProgress, realGuide = c.progress, c.activeGuide
c.progress, c.activeGuide = {}, nil
WL:Migrate()
check(WL:Needed(), "new character needs setup")
c.activeGuide = realGuide
local d = WL:Draft()
check(d.autoEquip == false and d.profile == false, "draft defaults: no spec profile, automatic upgrades off")
d.autoEquip = true
check(WL:Draft().autoEquip == true, "draft is kept per character (resume after reload)")

d.guide = c.activeGuide or false
WL:Finish()
check(c.setupDone and c.setupDraft == nil and prof.autoEquip == false, "opt-in without a spec profile does not turn on automatic upgrades")

c.setupDone = nil
local spec
for _, p in ipairs(ns.Gear:ProfilesForClass(ns.Compat.PlayerInfo().class)) do if p.spec and p.weights then spec = p break end end
d = WL:Draft()
d.guide, d.profile, d.autoEquip = c.activeGuide or false, spec and spec.id or false, true
WL:Finish()
check(spec == nil or (c.gearProfile == spec.id and prof.autoEquip == true), "explicit opt-in with a spec profile turns on automatic upgrades")

c.setupDone = nil
d = WL:Draft()
d.autoEquip = false
WL:Finish()
check(prof.autoEquip == false, "no opt-in: automatic upgrades stay off")

c.setupDone = nil
WL:Draft()
WL:Skip()
check(c.setupDone and c.setupDraft == nil and c.activeGuide == guideBefore, "skip: done, draft dropped, active guide untouched")

c.progress = realProgress
c.setupDone, c.setupDraft, c.gearProfile, prof.autoEquip = keep.setupDone, keep.setupDraft, keep.gearProfile, keep.autoEquip
if ns.AutoEquip then ns.AutoEquip:OnProfileChanged() end
