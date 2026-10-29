-- TBCGuide - headless tests for talent suggestions in the default talent window
-- (loaded by run_tests.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- The client's talents are mocked from the generated talent data (TalentTrees.lua), the way
-- GetTalentInfo reports them: per tab, name / tier / column / rank / max rank.

local check, ns = TEST.check, TEST.ns
local TH, Talents, PB = ns.TalentHints, ns.Talents, ns.TalentProfileBuilds
local prof = ns.db.profile

-- 1) Coverage: every spec profile maps to a valid plan that runs from level 10 to 70 ----------------------
local specs, mapped, missingSpecs, ivPlans = {}, 0, {}, 0
for _, p in ipairs(ns.Gear:Profiles()) do
    if p.spec then
        local key = p.class .. "/" .. p.spec
        if not specs[key] then
            specs[key] = true
            local b, why = Talents:BuildForProfile(p)
            if b then
                mapped = mapped + 1
                if b.source and b.source.site == "Icy Veins" then ivPlans = ivPlans + 1 end
                local seq, errors = Talents:Expand(b)
                -- every point, in order: rank cap, 5 points per tier, prerequisites (Talents:Expand)
                check(#errors == 0 and #seq >= 59 and #seq <= 61 and seq[1].level == 10, key .. ": plan " .. b.id .. " is legal point by point from level 10 (" .. #seq .. " points)")
                check(b.class == p.class and b.kind == "leveling", key .. ": a leveling plan for the same class")
            else
                missingSpecs[#missingSpecs + 1] = key
            end
        end
    end
end
for class, m in pairs(PB.specs) do
    for spec, e in pairs(m) do
        check(Talents.builds[e.plan] ~= nil, class .. "/" .. spec .. ": plan " .. tostring(e.plan) .. " exists")
        for _, v in ipairs(e.variants or {}) do check(Talents.builds[v] and #(select(2, Talents:Expand(Talents.builds[v]))) == 0, class .. "/" .. spec .. ": variant " .. v .. " is legal") end
    end
end
print("  talent plans: " .. mapped .. " spec names mapped (" .. ivPlans .. " from Icy Veins); no plan: " .. (#missingSpecs > 0 and table.concat(missingSpecs, ", ") or "none"))
check(mapped == 27 and #missingSpecs == 0 and ivPlans == 26, "all 27 spec names (28 profiles; Feral cat and bear share one) have a plan; 26 from Icy Veins, Assassination from Wowhead")
local ass = Talents:BuildForProfile(ns.Gear:ProfileById("rogue_assassination_raid"))
local aseq = Talents:Expand(ass)
check(ass.id == "rogue_assassination_wh" and ass.source.site == "Wowhead" and #aseq == 61, "Assassination follows the Wowhead plan, 61 points")
local at60 = Talents:RanksAt(ass, 51)
check(at60[1719] == 1 and at60[270] == 5 and at60[186] == 5 and at60[261] == 5 and aseq[41].talent.id == 1719, "level 60 matches the source build (Mutilate at 50, 41/5/5)")
check(aseq[52].talent.id == 181 and aseq[57].talent.id == 1827 and aseq[60].talent.id == 276, "levels 61-69 follow the source's order")
local saveTB2 = ns.char.talentBuild
ns.char.talentBuild = "rogue_mutilate_70"
check(Talents:Get(ns.char.talentBuild).id == "rogue_assassination_wh", "the old Mutilate build id resolves to the new plan")
ns.char.talentBuild = saveTB2
check(#(Talents:Expand(Talents.builds.warlock_destro_iv)) == 59, "Destruction: the source build spends 59 points and the plan says so (no invented points)")
local demo = Talents:Expand(Talents.builds.warlock_demo_iv)
check(demo[1].talent.tab == 2 and demo[1].level == 10, "Demonology plan starts in Demonology at level 10 (no Affliction-first respec)")
local u, why0 = Talents:BuildForProfile({ class = "ROGUE", spec = "Nonexistent" })
check(u == nil and why0 == "no plan", "a spec with no mapping says no plan")
check(string.find(TH:PanelText({ why = "no plan", profile = ns.Gear:ProfileById("rogue_subtlety_raid"), next = {}, deviations = 0 }), "No talent plan", 1, true), "no plan is said plainly in the panel")

-- 2) Live state for a warrior -------------------------------------------------------------------------
local save = { MOCK.player.class, MOCK.player.level, ns.char.gearProfile, MOCK.talents, prof.showTalentSuggestions }
MOCK.player.class, MOCK.player.level = "WARRIOR", 20
local function mockTalents(ranks)
    MOCK.talents = {}
    for tabNo, tab in ipairs(ns.TalentTrees.WARRIOR) do
        MOCK.talents[tabNo] = {}
        for i, t in ipairs(tab.talents) do
            MOCK.talents[tabNo][i] = { name = "T" .. t.id, tier = t.tier, column = t.column, rank = ranks[t.name] or 0, maxRank = t.ranks }
        end
    end
end
local learned = 0
local realLearn = LearnTalent
LearnTalent = function() learned = learned + 1 end

ns.char.gearProfile = "warrior_arms_raid"
mockTalents({})
local st = TH:State()
check(st.build and st.build.id == "warrior_arms_iv", "Arms profile follows the Icy Veins Arms plan")
check(st.next[1] and st.next[1].talent.name == "Improved Heroic Strike" and st.next[1].rank == 1, "first suggestion: Improved Heroic Strike 1")
check(#st.next == 3 and st.next[2].talent.name ~= st.next[1].talent.name, "three distinct next picks are marked")
check(st.deviations == 0 and not st.blocked, "no deviation, nothing blocked")

mockTalents({ ["Improved Heroic Strike"] = 3 })
st = TH:State()
check(st.next[1].talent.name == "Deflection", "after Improved Heroic Strike 3/3 the next pick is Deflection")

mockTalents({ ["Improved Heroic Strike"] = 3, ["Iron Will"] = 2 })
st = TH:State()
check(st.deviations == 2 and st.next[1].talent.name == "Deflection", "two off-plan points: deviation counted, suggestions continue")
check(string.find(TH:PanelText(st), "differ from this plan by 2", 1, true), "panel explains the deviation")

-- Blocked picks (tier gating) are explained, not hidden.
local ci = Talents:Index("WARRIOR")
local deep
for _, t in pairs(ci.byId) do if t.tier == 3 then deep = t break end end
check(TH:Blocked(deep, {}, ci) == "needs 10 points in its tree first", "a tier-3 pick without points says what it needs")

-- Profile switch: the plan follows the spec profile; old saved build ids still resolve.
ns.char.gearProfile = "warrior_fury_raid"
check(TH:Build().id == "warrior_fury_iv", "Fury profile follows the Fury plan")
MOCK.player.class = "ROGUE"
ns.char.gearProfile = "rogue_subtlety_raid"
check(TH:Build().id == "rogue_sub_iv", "Subtlety now has a plan")
MOCK.player.class = "MAGE"
ns.char.gearProfile = "mage_frost_raid"
local saveTB = ns.char.talentBuild
local w0 = ns.Upgrade:ActiveProfile()
check(TH:Build().id == "mage_frost_aoe_iv", "Frost profile: AoE plan by default")
ns.char.talentBuild = "mage_frost_st_iv"
check(TH:Build().id == "mage_frost_st_iv", "Frost profile: the single-target variant when chosen")
check(ns.Upgrade:ActiveProfile() == w0, "choosing a talent plan does not change the gear-scoring profile")
ns.char.talentBuild = "mage_fire_iv"
check(TH:Build().id == "mage_frost_aoe_iv", "a plan of another spec does not override the profile's plan")
ns.char.gearProfile = nil
MOCK.player.class = "WARRIOR"
ns.char.talentBuild = "warrior_arms_leveling"
check(Talents:ActiveBuild().id == "warrior_arms_iv", "a build id saved before the Icy Veins plans resolves to its replacement")
ns.char.talentBuild = saveTB
ns.char.gearProfile = "warrior_arms_raid"

local panel = TH:PanelText(TH:State())
check(string.find(panel, "Arms (Icy Veins leveling)", 1, true) and string.find(panel, "Icy Veins", 1, true), "panel names the plan and its source")

-- 3) Tooltip and markers ----------------------------------------------------------------------------------
mockTalents({})
local ihs = Talents:Find("WARRIOR", "Improved Heroic Strike")
TH:State() -- ReadLive fills liveIndex
local line, isNext = TH:TooltipLine(ihs.tab, ihs.liveIndex)
check(line and string.find(line, "pick 1", 1, true) and isNext, "tooltip: Improved Heroic Strike is pick 1")
local iw = Talents:Find("WARRIOR", "Iron Will")
check(string.find(TH:TooltipLine(iw.tab, iw.liveIndex) or "", "not in your plan", 1, true), "tooltip: Iron Will is not in the plan")

local function stub()
    local o = { shown = false }
    function o:SetPoint() end function o:SetTexture() end function o:SetBlendMode() end function o:SetSize() end
    function o:SetText(t) self.text = t end function o:Show() self.shown = true end function o:Hide() self.shown = false end
    return o
end
local buttons = {}
for i = 1, 25 do
    local b = { id = i }
    function b:GetID() return self.id end
    function b:IsShown() return true end
    function b:CreateFontString() return stub() end
    function b:CreateTexture() return stub() end
    buttons[i] = b
    _G["PlayerTalentFrameTalent" .. i] = b
end
local realSel = PanelTemplates_GetSelectedTab
PanelTemplates_GetSelectedTab = function() return 1 end
PlayerTalentFrame = CreateFrame("Frame", "PlayerTalentFrame")
TH.panel, TH.markers = nil, {}
TH:Refresh()
local m = TH.markers[buttons[ihs.liveIndex]]
check(m and m.text.shown and m.text.text == "1" and m.glow.shown, "marker 1 with a glow on Improved Heroic Strike")
local marked = 0
for _, mk in pairs(TH.markers) do if mk.text.shown then marked = marked + 1 end end
check(marked >= 1 and marked <= 3, "at most three markers on the tab")

prof.showTalentSuggestions = false
TH:Refresh()
local any = false
for _, mk in pairs(TH.markers) do if mk.text.shown then any = true end end
check(not any and TH:TooltipLine(ihs.tab, ihs.liveIndex) == nil, "setting off: no markers, no tooltip line")
prof.showTalentSuggestions = true

check(learned == 0, "no talent point is ever spent")

-- cleanup
for i = 1, 25 do _G["PlayerTalentFrameTalent" .. i] = nil end
PlayerTalentFrame, PanelTemplates_GetSelectedTab, LearnTalent = nil, realSel, realLearn
TH.panel, TH.markers = nil, {}
MOCK.player.class, MOCK.player.level, ns.char.gearProfile, MOCK.talents, prof.showTalentSuggestions = save[1], save[2], save[3], save[4], save[5]
