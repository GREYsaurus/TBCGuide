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

-- 1) Coverage: every spec profile maps to a valid build or says "no plan" ---------------------------
local specs, mapped, missingSpecs = {}, 0, {}
for _, p in ipairs(ns.Gear:Profiles()) do
    if p.spec then
        local key = p.class .. "/" .. p.spec
        if not specs[key] then
            specs[key] = true
            local b, why = Talents:BuildForProfile(p, 20)
            if b then
                mapped = mapped + 1
                local seq, errors = Talents:Expand(b)
                check(#errors == 0 and #seq >= 41 and #seq <= 61, key .. ": plan " .. b.id .. " passes rank/tier/prerequisite checks (" .. #seq .. " points)")
                check(b.class == p.class, key .. ": plan is for the same class")
            else
                missingSpecs[#missingSpecs + 1] = key
                check(why == "no plan", key .. ": marked as no plan")
            end
        end
    end
end
for class, m in pairs(PB.specs) do
    for spec, e in pairs(m) do
        for _, id in pairs(e) do check(Talents.builds[id] ~= nil, class .. "/" .. spec .. ": build " .. id .. " exists") end
    end
end
table.sort(missingSpecs)
print("  talent plans: " .. mapped .. " specs mapped; no plan: " .. table.concat(missingSpecs, ", "))
check(mapped == 20 and #missingSpecs == 7, "20 spec names (21 profiles: Feral cat and bear share one) have a plan, 7 are marked no plan")

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
check(st.build and st.build.id == "warrior_arms_leveling", "Arms profile below 70 follows the Arms leveling plan")
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

-- Fury profile follows the Fury plan; Subtlety has none.
ns.char.gearProfile = "warrior_fury_raid"
check(TH:Build().id == "warrior_fury_70", "Fury profile follows the Fury plan")
MOCK.player.class = "ROGUE"
ns.char.gearProfile = "rogue_subtlety_raid"
local b, why = TH:Build()
check(b == nil and why == "no plan" and string.find(TH:PanelText(), "No talent plan", 1, true), "Subtlety: no plan, said plainly")
MOCK.player.class = "WARRIOR"
ns.char.gearProfile = "warrior_arms_raid"

local panel = TH:PanelText(TH:State())
check(string.find(panel, "Arms (leveling)", 1, true) and string.find(panel, PB.source, 1, true), "panel names the plan and its source")

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
