-- TBCGuide - headless tests for junk selling and quest automation (loaded by run_tests.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- These drive the real event handlers through the mocked client in tests/mock_wow.lua. They
-- prove the add-on's decisions and call sequence; they cannot prove the live client accepts the
-- calls. See docs/COMPATIBILITY.md for the in-game checklist.

local check, ns = TEST.check, TEST.ns
local prof = ns.db.profile

local function printedSince(mark, pattern)
    for i = mark + 1, #MOCK.printed do
        if string.find(MOCK.printed[i], pattern, 1, true) then return true end
    end
    return false
end

local function called(name)
    for _, c in ipairs(MOCK.calls) do if c == name then return true end end
    return false
end

local function countCalls(prefix)
    local n = 0
    for _, c in ipairs(MOCK.calls) do if string.sub(c, 1, #prefix) == prefix then n = n + 1 end end
    return n
end

local function resetCalls() MOCK.calls = {} end

-- Junk selling ===================================================================================

-- Pick real ids from the bundled data so protection rules are tested against real records.
local questItemQuest, questItem
for q, r in pairs(ns.QDB.quests) do
    local obj = r[ns.QDB.QUEST.OBJECTIVES]
    if obj and obj.i and obj.i[1] then questItemQuest, questItem = q, obj.i[1] break end
end
local starterItem
for _, r in pairs(ns.QDB.quests) do
    local s = r[ns.QDB.QUEST.START_ITEMS]
    if s and s[1] and s[1] ~= questItem then starterItem = s[1] break end
end
check(questItem and starterItem, "test data: found a quest objective item and a quest-starting item")

local JUNK, JUNK2, CHEAP_WHITE, NOVALUE, QUESTCLASS, PROT, CONSUMABLE, UNCACHED, QSLOT, LOCKED, FAILS =
    900001, 900002, 900003, 900004, 900005, 900006, 900007, 900008, 900009, 900010, 900011
MOCK.items[JUNK] = { name = "Broken Sword", quality = 0, sellPrice = 25, classID = 2 }
MOCK.items[JUNK2] = { name = "Torn Cloth", quality = 0, sellPrice = 7, classID = 15 }
MOCK.items[CHEAP_WHITE] = { name = "Linen Cloth", quality = 1, sellPrice = 1, classID = 7 }
MOCK.items[NOVALUE] = { name = "Worthless Rock", quality = 0, sellPrice = 0, classID = 15 }
MOCK.items[QUESTCLASS] = { name = "Grey Quest Thing", quality = 0, sellPrice = 5, classID = 12 }
MOCK.items[PROT] = { name = "Lucky Junk", quality = 0, sellPrice = 9, classID = 15 }
MOCK.items[CONSUMABLE] = { name = "Stale Bread", quality = 0, sellPrice = 2, classID = 0 }
MOCK.items[UNCACHED] = { name = "Mystery", quality = 0, sellPrice = 3, classID = 15, uncached = true }
MOCK.items[QSLOT] = { name = "Bag Quest Junk", quality = 0, sellPrice = 4, classID = 15 }
MOCK.items[LOCKED] = { name = "Locked Junk", quality = 0, sellPrice = 4, classID = 15 }
MOCK.items[FAILS] = { name = "Unsellable Junk", quality = 0, sellPrice = 6, classID = 15 }
MOCK.items[questItem] = { name = "Guide Item", quality = 0, sellPrice = 3, classID = 15 }
MOCK.items[starterItem] = { name = "Starter", quality = 0, sellPrice = 3, classID = 15 }

local function fillBags()
    MOCK.bags = { [0] = {
        [1] = { itemID = JUNK }, [2] = { itemID = JUNK2, count = 3 }, [3] = { itemID = CHEAP_WHITE, count = 20 },
        [4] = { itemID = NOVALUE }, [5] = { itemID = QUESTCLASS }, [6] = { itemID = PROT },
        [7] = { itemID = CONSUMABLE }, [8] = { itemID = UNCACHED }, [9] = { itemID = QSLOT, questItem = true },
        [10] = { itemID = LOCKED, locked = true }, [11] = { itemID = questItem }, [12] = { itemID = starterItem },
    } }
end

local function visitMerchant(seconds)
    MOCK.merchantOpen = true
    MOCK.fire("MERCHANT_SHOW")
    MOCK.tick(seconds or 3)
end

local function closeMerchant()
    MOCK.merchantOpen = false
    MOCK.fire("MERCHANT_CLOSED")
    MOCK.tick(1)
end

-- Quest that needs `questItem` is in the log, so that item is a guide/quest requirement.
table.insert(MOCK.questLog, { id = questItemQuest, title = "Needs item", complete = false, objectives = {} })
ns.Tracker:Scan()
ns.db.protectedItems[PROT] = true

-- 1) Feature disabled (the default): nothing is touched.
check(prof.autoSellJunk == false, "junk selling is OFF by default")
fillBags()
MOCK.useCalls, MOCK.money = {}, 0
visitMerchant()
check(#MOCK.useCalls == 0 and MOCK.money == 0, "disabled: opening a merchant sells nothing")
closeMerchant()

-- 2) Enabled: only the two eligible grey items are sold.
prof.autoSellJunk = true
fillBags()
MOCK.useCalls, MOCK.money = {}, 0
local mark = #MOCK.printed
visitMerchant()
check(MOCK.bags[0][1] == nil and MOCK.bags[0][2] == nil, "eligible junk sold")
check(MOCK.money == 25 + 7 * 3, "money received equals sell price x count (" .. MOCK.money .. ")")
for slot, why in pairs({ [3] = "white trade good", [4] = "no sell value", [5] = "quest-class item", [6] = "protected id",
                         [7] = "protected category (consumable)", [8] = "item info not loaded", [9] = "quest item flag",
                         [10] = "locked item", [11] = "item needed by a quest in the log", [12] = "quest-starting item" }) do
    check(MOCK.bags[0][slot] ~= nil, "kept: " .. why)
end
check(#MOCK.useCalls == 2, "only two sell calls were made (" .. #MOCK.useCalls .. ")")
check(printedSince(mark, "Sold 2 junk items for 46c."), "sale summary reports confirmed copper")
check(ns.char.junkStats.items == 2 and ns.char.junkStats.copper == 46, "running total updated")
closeMerchant()

-- 3) A refused sale is reported, not counted, and not retried in the same visit.
MOCK.bags = { [0] = { [1] = { itemID = FAILS } } }
MOCK.sellFails[FAILS] = true
MOCK.useCalls = {}
mark = #MOCK.printed
visitMerchant(4)
check(#MOCK.useCalls == 1, "unsellable item tried exactly once")
check(printedSince(mark, "could not be sold"), "failed sale reported")
check(ns.char.junkStats.items == 2, "failed sale not counted")
closeMerchant()

-- 4) Shift suppresses selling; holding an item on the cursor suppresses selling.
fillBags()
MOCK.useCalls = {}
MOCK.shift = true
visitMerchant()
check(#MOCK.useCalls == 0, "shift held: nothing sold")
closeMerchant()
MOCK.shift, MOCK.cursor = false, true
visitMerchant()
check(#MOCK.useCalls == 0, "item on cursor: nothing sold")
closeMerchant()
MOCK.cursor = false

-- 5) Closing the merchant mid-queue stops further sales.
MOCK.bags = { [0] = {} }
for i = 1, 10 do MOCK.bags[0][i] = { itemID = JUNK } end
MOCK.useCalls = {}
MOCK.merchantOpen = true
MOCK.fire("MERCHANT_SHOW")
MOCK.tick(0.3)
closeMerchant()
MOCK.tick(3)
check(#MOCK.useCalls > 0 and #MOCK.useCalls < 10, "merchant closed: selling stopped (" .. #MOCK.useCalls .. " of 10)")
prof.autoSellJunk = false
ns.db.protectedItems[PROT] = nil
table.remove(MOCK.questLog)
ns.Tracker:Scan()

-- Classification unit checks.
local V = ns.Vendor
check(not V:Classify({ itemID = JUNK, quality = 0 }, nil, {}, false), "classify: missing item info => keep")
check(not V:Classify({ itemID = JUNK, quality = 0 }, { quality = 0, sellPrice = 5 }, {}, false), "classify: unknown class => keep")
check(V:Classify({ itemID = JUNK, quality = 0 }, { quality = 0, sellPrice = 5, classID = 2 }, {}, false), "classify: grey weapon => sell")
check(not V:Classify({ itemID = JUNK, quality = 2 }, { quality = 2, sellPrice = 500, classID = 2 }, {}, false), "classify: green weapon => keep")
check(not V:Classify({ itemID = JUNK, quality = 0 }, { quality = 0, sellPrice = 5, classID = 2, bindType = 4 }, {}, false), "classify: quest-bound => keep")
check(V.ParseItem("|cff9d9d9d|Hitem:900001::::|h[x]|h|r") == 900001 and V.ParseItem("123") == 123, "item link / id parsing")

-- Quest automation ===============================================================================
local QA = ns.QuestAuto
ns.Engine:Load("A_Human_Elwynn", { reset = true })
MOCK.questLog, MOCK.completed = {}, {}
ns.Tracker.turnedIn = {}
ns.Tracker:Scan()
MOCK.tick(0.5)

check(prof.autoAccept == true and prof.autoTurnIn == true, "quest automation on by default (guide quests only)")

-- A normal (non-escort) quest the guide still wants to accept.
local guideQ
for q in pairs(QA.acceptOpen) do
    if not ns.DB.GetEscortStatus(q) and not QA.acceptOpen[q].optional then guideQ = q break end
end
check(guideQ ~= nil, "found a non-escort guide quest to accept")
local OTHER = 9 -- "The Killing Fields": Westfall, not in the Elwynn guide
check(not QA.acceptOpen[OTHER], "test quest 9 is not in the active guide")

local function offer(q, extra)
    MOCK.dialog = { questID = q, title = ns.DB.GetQuestName(q) or "?", text = "Kill things." }
    for k, v in pairs(extra or {}) do MOCK.dialog[k] = v end
    MOCK.fire("QUEST_DETAIL")
end

-- Gossip: the guide quest is opened, the unrelated one is not.
resetCalls()
MOCK.gossip = { available = { { questID = OTHER, title = "The Killing Fields" }, { questID = guideQ, title = "x" } }, active = {} }
MOCK.fire("GOSSIP_SHOW")
check(called("select_available:" .. guideQ) and not called("select_available:" .. OTHER), "gossip: only the guide quest is selected")

-- Detail: accept, but report success only after the game confirms.
resetCalls()
mark = #MOCK.printed
offer(guideQ)
check(called("accept:" .. guideQ), "detail: guide quest accepted")
check(not printedSince(mark, "Accepted:"), "no success message before QUEST_ACCEPTED")
offer(guideQ)
check(countCalls("accept:") == 1, "same offer is not accepted twice while waiting for confirmation")
table.insert(MOCK.questLog, { id = guideQ, title = "x", complete = false, objectives = { { text = "a", done = false } } })
MOCK.fire("QUEST_ACCEPTED", 1, guideQ)
MOCK.tick(0.5)
check(printedSince(mark, "Accepted:"), "success message after QUEST_ACCEPTED")
MOCK.questLog = {}
ns.Tracker:Scan()
MOCK.tick(5)

-- Unrelated quest offer: left for the player.
resetCalls()
offer(OTHER)
check(not called("accept:" .. OTHER), "unrelated quest not accepted")

-- Unconfirmed acceptance is reported as such.
local guideQ2
for q in pairs(QA.acceptOpen) do
    if q ~= guideQ and not ns.DB.GetEscortStatus(q) and not QA.acceptOpen[q].optional then guideQ2 = q break end
end
resetCalls()
mark = #MOCK.printed
offer(guideQ2)
MOCK.tick(5)
check(called("accept:" .. guideQ2) and printedSince(mark, "Could not confirm"), "unconfirmed acceptance reported, not claimed")
check(not printedSince(mark, "Accepted:"), "no false success message")

-- ESCORT: never auto-accepted, whatever the settings, by every signal.
prof.autoAcceptOptional, prof.autoAcceptGroup = true, true
local function escortCase(q, label, extra)
    QA.acceptOpen[q] = { "accept", q = q }
    QA.attempts[q], QA.explained = nil, {}
    resetCalls()
    mark = #MOCK.printed
    offer(q, extra)
    check(not called("accept:" .. q), "escort never auto-accepted: " .. label)
    check(printedSince(mark, "Accept it manually"), "manual acceptance explained: " .. label)
    QA.acceptOpen[q] = nil
end
escortCase(309, "party-accept flag (Protecting the Shipment)")
escortCase(648, "curated list (Rescue OOX-17/TN!)")
escortCase(2078, "curated list, no upstream flag (Gyromast's Revenge)")
escortCase(guideQ2, "escort wording in live quest text", { text = "Escort Bob safely to the road." })
escortCase(99999990, "quest missing from the database")
ns.db.escortExtra[guideQ2] = true
escortCase(guideQ2, "user escort list")
ns.db.escortExtra[guideQ2] = nil
check(ns.DB.GetEscortStatus(309) and ns.DB.GetEscortStatus(4770), "known escorts classified as manual")
check(not ns.DB.GetEscortStatus(783), "ordinary quest not classified as escort (A Threat Within)")
-- Escort in a gossip list: not even opened.
QA.acceptOpen[309] = { "accept", q = 309 }
QA.attempts[309], QA.explained = nil, {}
resetCalls()
MOCK.gossip = { available = { { questID = 309, title = "Protecting the Shipment" } }, active = {} }
MOCK.fire("GOSSIP_SHOW")
check(not called("select_available:309"), "escort quest in gossip list is not opened")
QA.acceptOpen[309] = nil
-- Party escort confirmation is never answered by the add-on.
resetCalls()
MOCK.fire("QUEST_ACCEPT_CONFIRM", "Player", "Protecting the Shipment")
check(#MOCK.calls == 0, "party escort confirmation left to the player")
prof.autoAcceptOptional, prof.autoAcceptGroup = false, false

-- Shift, player shares, disabled setting, full log.
QA.attempts = {}
resetCalls()
MOCK.shift = true
offer(guideQ2)
MOCK.shift = false
check(not called("accept:" .. guideQ2), "shift held: no automatic acceptance")
offer(guideQ2, { fromPlayer = true })
check(not called("accept:" .. guideQ2), "quest shared by a player: not accepted")
prof.autoAccept = false
offer(guideQ2)
check(not called("accept:" .. guideQ2), "setting off: not accepted")
prof.autoAccept = true
for i = 1, 25 do table.insert(MOCK.questLog, { id = 800000 + i, title = "filler", complete = false, objectives = { { text = "a", done = false } } }) end
ns.Tracker:Scan()
MOCK.tick(0.5)
mark = #MOCK.printed
offer(guideQ2)
check(not called("accept:" .. guideQ2) and printedSince(mark, "quest log full"), "full quest log: not accepted, player told")
MOCK.questLog = {}
ns.Tracker:Scan()
MOCK.tick(0.5)

-- Greeting window without quest ids: unique title match from the guide.
QA.attempts = {}
resetCalls()
local title2 = QA.acceptOpen[guideQ2].title or ns.DB.GetQuestName(guideQ2)
MOCK.greeting = { available = { { title = "Something Else" }, { title = title2 } }, active = {} }
MOCK.fire("QUEST_GREETING")
check(called("greeting_available:2") and not called("greeting_available:1"), "greeting: guide quest found by title")

-- Turn-in ======================================================================================
-- First accept step of the guide is 783; the step after it is its turn-in.
local TQ = 783
table.insert(MOCK.questLog, { id = TQ, title = "A Threat Within", complete = true, objectives = {} })
ns.Tracker:Scan()
MOCK.tick(0.5)
check(QA.turninOpen[TQ] ~= nil, "guide has an open turn-in for 783")

-- Gossip: completed guide quest is selected before any available quest.
QA.attempts = {}
resetCalls()
MOCK.gossip = { available = { { questID = guideQ2, title = "x" } }, active = { { questID = TQ, title = "A Threat Within", isComplete = true } } }
MOCK.fire("GOSSIP_SHOW")
check(called("select_active:" .. TQ) and not called("select_available:" .. guideQ2), "gossip: turn-in first, one selection per window")

resetCalls()
MOCK.dialog = { questID = TQ, completable = true }
MOCK.fire("QUEST_PROGRESS")
check(called("complete:" .. TQ), "progress panel: completed")
resetCalls()
MOCK.dialog = { questID = TQ, completable = false }
MOCK.fire("QUEST_PROGRESS")
check(not called("complete:" .. TQ), "progress panel: not completable => untouched")
MOCK.dialog = { questID = TQ, completable = true, money = 100 }
MOCK.fire("QUEST_PROGRESS")
check(not called("complete:" .. TQ), "quest that costs money => manual")

-- MANDATORY: several reward choices => no reward is chosen.
resetCalls()
mark = #MOCK.printed
MOCK.dialog = { questID = TQ, choices = 3 }
MOCK.fire("QUEST_COMPLETE")
check(countCalls("reward:") == 0, "reward choice: no reward selected automatically")
check(printedSince(mark, "Choose your reward"), "reward choice: player told to choose")
MOCK.tick(5)
check(not printedSince(mark, "Turned in"), "reward choice: nothing claimed before the player acts")
check(ns.Engine:CurrentStep().q == TQ and ns.Engine:CurrentStep()[1] == "turnin", "guide waits on the turn-in step")
-- Player picks a reward; the game confirms; the guide resumes.
MOCK.questLog = {}
MOCK.completed[TQ] = true
MOCK.fire("QUEST_TURNED_IN", TQ, 100, 0)
MOCK.tick(0.5)
check(printedSince(mark, "Guide resumes"), "reward choice: guide resumes after confirmation")
check(not (ns.Engine:CurrentStep().q == TQ and ns.Engine:CurrentStep()[1] == "turnin"), "guide advanced past the turn-in")

-- No reward choice: turned in, success only after QUEST_TURNED_IN; a failure does not advance.
local TQ2
for q in pairs(QA.turninOpen) do TQ2 = q break end
check(TQ2 ~= nil, "found another open guide turn-in")
table.insert(MOCK.questLog, { id = TQ2, title = "t", complete = true, objectives = {} })
ns.Tracker:Scan()
MOCK.tick(0.5)
resetCalls()
mark = #MOCK.printed
MOCK.dialog = { questID = TQ2, choices = 0 }
MOCK.fire("QUEST_COMPLETE")
check(called("reward:" .. TQ2 .. ":1"), "no choice: turned in")
MOCK.tick(5)
check(printedSince(mark, "was not confirmed") and not ns.Tracker:IsTurnedIn(TQ2), "failed turn-in reported, guide not advanced")
QA.attempts = {}
resetCalls()
MOCK.dialog = { questID = TQ2, choices = 1 }
MOCK.fire("QUEST_COMPLETE")
check(called("reward:" .. TQ2 .. ":1"), "single fixed reward: turned in")
MOCK.questLog = {}
MOCK.completed[TQ2] = true
MOCK.fire("QUEST_TURNED_IN", TQ2, 100, 0)
MOCK.tick(0.5)
check(printedSince(mark, "Turned in:"), "turn-in success reported after confirmation")

-- Unrelated quests: manual unless configured; repeatable unrelated quests always manual.
resetCalls()
MOCK.dialog = { questID = OTHER, choices = 0, completable = true }
MOCK.fire("QUEST_PROGRESS")
MOCK.fire("QUEST_COMPLETE")
check(not called("complete:" .. OTHER) and countCalls("reward:") == 0, "unrelated quest turn-in left manual")
prof.turnInUnrelated = true
MOCK.fire("QUEST_PROGRESS")
check(called("complete:" .. OTHER), "unrelated turn-in when enabled")
local REP
for q, r in pairs(ns.QDB.quests) do if ns.HasBit(r[ns.QDB.QUEST.SPECIAL_FLAGS] or 0, 1) then REP = q break end end
resetCalls()
MOCK.dialog = { questID = REP, choices = 0, completable = true }
MOCK.fire("QUEST_PROGRESS")
check(not called("complete:" .. REP), "repeatable unrelated quest stays manual")
prof.turnInUnrelated = false
prof.autoTurnIn = false
resetCalls()
MOCK.dialog = { questID = TQ2, choices = 0, completable = true }
MOCK.fire("QUEST_PROGRESS")
check(#MOCK.calls == 0, "turn-in setting off: nothing done")
prof.autoTurnIn = true
MOCK.dialog = nil
MOCK.gossip = { available = {}, active = {} }
MOCK.greeting = { available = {}, active = {} }

-- Orphaned quests ==============================================================================
ns.Engine:Load("A_Human_Elwynn")
MOCK.questLog, MOCK.calls, MOCK.popups = {}, {}, {}
local onRoute = guideQ2                       -- still an open accept step in the active guide
local CLASSQ
for q, r in pairs(ns.QDB.quests) do
    if (r[ns.QDB.QUEST.CLASSES] or 0) ~= 0 then CLASSQ = q break end
end
local logEntries = { { id = onRoute, title = "On route" }, { id = OTHER, title = "The Killing Fields" },
                     { id = 99999991, title = "Unknown old quest" }, { id = CLASSQ, title = "Class quest" } }
for _, e in ipairs(logEntries) do
    table.insert(MOCK.questLog, { id = e.id, title = e.title, complete = false, objectives = { { text = "a", done = false } } })
end
ns.Tracker:Scan()
MOCK.tick(0.5)
local list = ns.Orphans:Find()
local found = {}
for _, o in ipairs(list) do found[o.id] = o end
check(not found[onRoute], "quest still on the route is not orphaned")
-- Quest 9 is turned in later on the human route (Westfall), so it is NOT orphaned either.
check(not found[OTHER], "quest turned in by a LATER guide on the route is not orphaned")
check(found[99999991] ~= nil, "quest no guide on the route touches is orphaned")
check(found[CLASSQ] and found[CLASSQ].special, "class quest listed but flagged as special")

local OF = ns.OrphanFrame
OF:Refresh(true)
check(OF.selected[99999991] and not OF.selected[CLASSQ], "default selection: orphan ticked, class quest not")
-- Abandoning needs the confirmation dialog: Confirm only shows it.
OF:Confirm()
check(#MOCK.popups == 1 and countCalls("abandon") == 0, "abandon asks for confirmation first")
OF:DoAbandon() -- the dialog's OnAccept
MOCK.tick(2)
check(countCalls("abandon") == 1, "exactly the selected quest was abandoned")
ns.Tracker:Scan()
check(not ns.Tracker:InLog(99999991) and ns.Tracker:InLog(onRoute) and ns.Tracker:InLog(CLASSQ), "only the orphan left the log")
-- Index safety: a quest log that shifted under us never abandons the wrong quest.
check(ns.Compat.AbandonQuestAt(1, 123456) == false and countCalls("abandon") == 1, "mismatched log index refuses to abandon")
-- No guide loaded => no verdict.
local saved = ns.Engine.guide
ns.Engine.guide = nil
check(ns.Orphans:Find() == nil, "no guide loaded: nothing is called orphaned")
ns.Engine.guide = saved
MOCK.questLog = {}
ns.Tracker:Scan()
MOCK.tick(0.5)

-- Engine: an optional turn-in for a quest from an earlier guide is skipped when it is not in the log.
local fake = { "turnin", q = 99999992, optional = true }
check(ns.Engine:AutoSkipReason(fake, ns.Tracker:Context()) == "not in your quest log", "optional cross-guide turn-in skipped when not in log")
fake.optional = nil
check(ns.Engine:AutoSkipReason(fake, ns.Tracker:Context()) == nil, "required cross-guide turn-in is never auto-skipped")

-- Maximum-speed route hides optional steps (and the automation stops seeing them).
local function countNA()
    local n = 0
    for i = 1, #ns.Engine.guide.steps do if ns.Engine.status[i] == "na" then n = n + 1 end end
    return n
end
ns.Engine:Load("A_Westfall")
local naBefore = countNA()
prof.speedRoute = true
ns.Engine:Refresh()
local optionalOpen = false
for q, st in pairs(QA.acceptOpen) do if st.optional then optionalOpen = true end end
check(countNA() > naBefore and not optionalOpen, "speed route hides optional steps from guide and automation")
prof.speedRoute = false
ns.Engine:Refresh()
check(countNA() == naBefore, "speed route off restores optional steps")
ns.Engine:Load("A_Human_Elwynn")

-- Settings / saved variables --------------------------------------------------------------------
TBCGuideDB.protectedItems = "garbage"
TBCGuideCharDB.junkStats = { items = "x" }
ns:InitSavedVariables()
check(type(ns.db.protectedItems) == "table" and ns.char.junkStats.items == 0, "corrupt automation settings repaired")
for _, cmd in ipairs({ "automation", "orphans", "orphans", "protect 6948", "protected", "unprotect 6948", "escort", "escort add 123",
                       "escort remove 123", "escort remove 309", "debug escort 309", "set autoSellJunk on", "set autoSellJunk off" }) do
    local ok, err = pcall(SlashCmdList["TBCGUIDE"], cmd)
    check(ok, "/tbcg " .. cmd .. " -> " .. tostring(err))
end
check(#ns.errors == 0, "no captured errors after automation tests: " .. table.concat(ns.errors, " | "))
