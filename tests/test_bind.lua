-- TBCGuide - headless tests for hearthstone binding on guide bind steps (loaded by run_tests.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only

local check, ns = TEST.check, TEST.ns
local B, E = ns.Bind, ns.Engine
local prof = ns.db.profile

-- A German client: the client names areas in its own language (C_Map.GetAreaInfo).
local AREAS = { [87] = "Goldhain", [12] = "Wald von Elwynn", [69] = "Seenhain" }
local real = { GetAreaInfo = C_Map.GetAreaInfo, GetOptions = C_GossipInfo.GetOptions, SelectOption = C_GossipInfo.SelectOption,
    PIM = C_PlayerInteractionManager, ConfirmBinder = ConfirmBinder, bindAuto = prof.bindAuto, skipGossip = prof.skipGossip,
    bind = MOCK.bind, npc = MOCK.units.npc, wants = ns.QuestAuto.GossipWants }
C_Map.GetAreaInfo = function(id) return AREAS[id] end
Enum = Enum or {}
local realPIT = Enum.PlayerInteractionType
Enum.PlayerInteractionType = { Binder = 5 }
local confirms = 0
C_PlayerInteractionManager = {
    ConfirmationInteraction = function(t) if t == 5 then confirms = confirms + 1 end end,
    ClearInteraction = function() end,
}
local options, selected = {}, {}
C_GossipInfo.GetOptions = function() return options end
C_GossipInfo.SelectOption = function(id) table.insert(selected, id) end
local BINDER = { name = "Macht dieses Gasthaus zu Eurem Zuhause.", icon = 132052, gossipOptionID = 11 } -- modern: no type
local VENDOR = { name = "Ich möchte etwas kaufen.", icon = 132060, gossipOptionID = 12 }
local function npc(id) MOCK.units.npc = { guid = "Creature-0-4372-0-12-" .. id .. "-00001A2B3C", name = "Innkeeper" } end
local function printedHas(text)
    for i = #MOCK.printed, math.max(1, #MOCK.printed - 3), -1 do
        if string.find(MOCK.printed[i] or "", text, 1, true) then return true end
    end
    return false
end
local function reset() selected, confirms = {}, 0 B.pending = nil end
prof.bindAuto, prof.skipGossip = true, true
MOCK.bind = "Nordhaintal"

-- Put the Elwynn guide on its bind step.
E:Load("A_Human_Elwynn", { reset = true })
local idx
for i, s in ipairs(E.guide.steps) do if s[1] == "bind" then idx = i break end end
local bs = E.guide.steps[idx]
check(bs.place == "Goldshire" and bs.npcId == 295 and bs.areas and bs.areas[1] == 87, "the bind step carries its innkeeper id and area id")
local function toStep()
    for i = 1, idx - 1 do E.progress.done[i] = true end
    E.progress.done[idx], E.progress.skipped[idx] = nil, nil
    E:Refresh()
end
toStep()
check(E.current == idx, "the bind step is current")
options = { VENDOR, BINDER }

-- Already bound / names in the client's language
MOCK.bind = "Goldhain"
check(B:IsBoundFor(bs), "already bound: the German area name matches the step")
npc(295)
MOCK.fire("GOSSIP_SHOW")
check(#selected == 0, "already bound: nothing is selected again")
check(E.status[idx] == "done", "already bound: the step completes without rebinding")
MOCK.bind = "Nordhaintal"
toStep()
check(not B:IsBoundFor(bs) and E.current == idx, "bound elsewhere: the step stays open")

-- Wrong innkeeper (Lakeshire) and no NPC
reset()
npc(6727)
MOCK.fire("GOSSIP_SHOW")
check(#selected == 0 and B.pending == nil, "another town's innkeeper: nothing is selected")
check(printedHas("not at Goldshire"), "another town's innkeeper: says why, once")
local n = #MOCK.printed
MOCK.fire("GOSSIP_SHOW")
check(#MOCK.printed == n, "another town's innkeeper: the message is not repeated")
MOCK.units.npc = nil
MOCK.fire("GOSSIP_SHOW")
check(#selected == 0, "no NPC id: nothing is selected")

-- The right innkeeper: select, confirm only for the right area, verify
reset()
npc(295)
MOCK.fire("GOSSIP_SHOW")
check(#selected == 1 and selected[1] == 11 and B.pending ~= nil, "the step's innkeeper: the binder option (by icon) is selected")
MOCK.fire("GOSSIP_SHOW")
check(#selected == 1, "a second gossip refresh does not select it again")
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(0.1)
check(confirms == 1, "the confirmation for the step's area is accepted once")
check(E.status[idx] ~= "done", "not done when confirmed: waits for the game to report the new home")
MOCK.bind = "Goldhain"
MOCK.fire("HEARTHSTONE_BOUND")
check(E.status[idx] == "done" and B.pending == nil, "done once GetBindLocation reports the inn")
check(printedHas("Hearthstone set to Goldhain"), "success is reported after verification")
MOCK.bind = "Nordhaintal"

-- Confirmation for another area: never accepted
toStep()
reset()
MOCK.fire("GOSSIP_SHOW")
MOCK.fire("CONFIRM_BINDER", "Seenhain")
MOCK.tick(0.1)
check(confirms == 0 and B.pending == nil, "a confirmation for another area is not accepted")
check(printedHas("did not confirm"), "the player is told to answer the dialog")

-- A confirmation nobody asked for (the player chose the option): left alone
reset()
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(0.1)
check(confirms == 0, "a bind the player started is left to the player")

-- Declined, gossip closed, timeouts
reset()
MOCK.fire("GOSSIP_SHOW")
B:OnDeclined()
check(B.pending == nil, "declined: the pending bind is dropped")
MOCK.fire("GOSSIP_SHOW")
check(#selected == 2, "after a decline, talking again offers it once more (no automatic retry)")
B.pending = nil
reset()
MOCK.fire("GOSSIP_SHOW")
MOCK.fire("GOSSIP_CLOSED")
MOCK.tick(2.5)
check(B.pending == nil, "gossip closed with no confirmation: cancelled")
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(0.1)
check(confirms == 0, "a late confirmation after cancelling is not accepted")
reset()
MOCK.fire("GOSSIP_SHOW")
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(11)
check(confirms == 1 and B.pending == nil and E.status[idx] ~= "done", "confirmed but never bound: times out, step stays open")
check(printedHas("was not confirmed"), "timeout: the player is told")

-- Bound somewhere else after our confirmation (ambiguous): step stays open, manual acknowledgement offered
reset()
MOCK.fire("GOSSIP_SHOW")
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(0.1)
MOCK.bind = "Sturmwind"
MOCK.fire("HEARTHSTONE_BOUND")
MOCK.tick(1.2)
check(E.status[idx] ~= "done" and B.pending == nil, "bound to another place: not marked done")
check(printedHas("click the step"), "bound to another place: manual acknowledgement offered")
MOCK.bind = "Nordhaintal"

-- Delayed location: HEARTHSTONE_BOUND before GetBindLocation updates
reset()
MOCK.fire("GOSSIP_SHOW")
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(0.1)
MOCK.fire("HEARTHSTONE_BOUND")
MOCK.bind = "Goldhain"
MOCK.tick(1.2)
check(E.status[idx] == "done", "a location that updates a moment later is still verified")
MOCK.bind = "Nordhaintal"
toStep()

-- Setting off, Shift, step change during the interaction
reset()
MOCK.fire("GOSSIP_SHOW")
prof.bindAuto = false
B:Cancel("setting off")
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(0.1)
check(confirms == 0 and B.pending == nil, "setting turned off: the pending bind is not confirmed")
MOCK.fire("GOSSIP_SHOW")
check(#selected == 1, "setting off: nothing is selected")
prof.bindAuto = true
reset()
MOCK.shift = true
MOCK.fire("GOSSIP_SHOW")
check(#selected == 0, "Shift held: nothing is selected")
MOCK.shift = false
reset()
MOCK.fire("GOSSIP_SHOW")
E:Skip(idx)
check(B.pending == nil, "step skipped during the interaction: cancelled")
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(0.1)
check(confirms == 0, "step skipped: the confirmation is not accepted")
toStep()
reset()
MOCK.fire("GOSSIP_SHOW")
local p = B.pending
E.current = idx + 1
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(0.1)
check(confirms == 0, "step changed before the confirmation: not accepted")
toStep()

-- Other NPC automation: quest automation first; Skip Gossip never takes a lone bind option
reset()
ns.QuestAuto.GossipWants = function() return true end
MOCK.fire("GOSSIP_SHOW")
check(#selected == 0, "the innkeeper has a guide quest to hand in: quests go first")
ns.QuestAuto.GossipWants = real.wants
options = { BINDER }
npc(6727)
reset()
MOCK.fire("GOSSIP_SHOW")
check(#selected == 0, "Skip Gossip does not pick a lone bind option at another inn")
npc(295)

-- Older gossip API (type field), ambiguous menus, other steps
reset()
options = { { name = "Make this inn your home.", type = "binder", gossipOptionID = 21 }, VENDOR }
MOCK.fire("GOSSIP_SHOW")
check(selected[1] == 21, "older API: the option typed binder is selected")
reset()
options = { BINDER, { name = "Other", icon = 132052, gossipOptionID = 13 } }
MOCK.fire("GOSSIP_SHOW")
check(#selected == 0, "two binder-looking options: nothing is selected")
reset()
options = { { name = "Tell me about the town.", icon = 132053, gossipOptionID = 14 }, VENDOR }
MOCK.fire("GOSSIP_SHOW")
check(#selected == 0 and B.pending == nil, "an intermediate menu without the bind option: nothing is selected")
options = { VENDOR, BINDER }
reset()
E.progress.done[idx] = true
E:Refresh()
MOCK.fire("GOSSIP_SHOW")
check(#selected == 0, "no bind step current: the innkeeper is left alone")
toStep()

-- A client that does not let add-ons confirm: the player is asked once, nothing is forced
reset()
C_PlayerInteractionManager, ConfirmBinder = nil, nil
MOCK.fire("GOSSIP_SHOW")
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(0.1)
check(confirms == 0 and printedHas("Click Yes"), "no confirm API: the player is asked to click Yes")
MOCK.bind = "Goldhain"
MOCK.fire("HEARTHSTONE_BOUND")
check(E.status[idx] == "done", "the player's own Yes is verified and completes the step")
MOCK.bind = "Nordhaintal"

-- A blocked confirmation asks the player
toStep()
reset()
C_PlayerInteractionManager = { ConfirmationInteraction = function() confirms = confirms + 1 end }
MOCK.fire("GOSSIP_SHOW")
MOCK.fire("CONFIRM_BINDER", "Goldhain")
MOCK.tick(0.1)
MOCK.fire("ADDON_ACTION_BLOCKED", "TBCGuide", "ConfirmationInteraction")
check(printedHas("click Yes on the hearthstone dialog yourself"), "a blocked confirmation asks the player to click Yes")
B:Cancel("test")

-- Saved state never holds a pending bind
check(ns.char.bindPending == nil and type(B.pending) == "nil", "nothing pending is saved (a reload starts clean)")

-- Every bind step in every guide has an innkeeper and area ids
local missing, nBind = {}, 0
for _, g in ipairs(ns.Guides.list) do
    for i, s in ipairs(g.steps or {}) do
        if s[1] == "bind" then
            nBind = nBind + 1
            if not (s.npcId and s.areas and #s.areas > 0) then missing[#missing + 1] = g.id .. ":" .. i end
        end
    end
end
check(nBind >= 47 and #missing == 0, "all " .. nBind .. " bind steps have an innkeeper id and area ids " .. table.concat(missing, ", "))

C_Map.GetAreaInfo, C_GossipInfo.GetOptions, C_GossipInfo.SelectOption = real.GetAreaInfo, real.GetOptions, real.SelectOption
C_PlayerInteractionManager, ConfirmBinder, Enum.PlayerInteractionType = real.PIM, real.ConfirmBinder, realPIT
prof.bindAuto, prof.skipGossip, MOCK.bind, MOCK.units.npc = real.bindAuto, real.skipGossip, real.bind, real.npc
B.pending = nil
