-- TBCGuide - minimal World of Warcraft API mocks for headless tests (Lua 5.1)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Only what the add-on touches is mocked. Frames accept any method call (returning nil)
-- so UI construction runs; behaviour that matters for tests (events, OnUpdate, quest log,
-- player info, talents) is modelled explicitly and controllable through MOCK.

MOCK = {
    time = 0,
    frames = {},
    player = { race = "Human", class = "WARRIOR", faction = "Alliance", level = 1, name = "Tester" },
    questLog = {},        -- array of { id=, title=, complete=bool, objectives={ {text=, done=} } }
    completed = {},       -- [questId] = true
    bind = "Northshire Abbey",
    zone = "Elwynn Forest",
    talents = {},         -- [tab] = { {name=, tier=, column=, rank=, maxRank=}, ... }
    printed = {},
}

local frameMeta
local function newObject(kind)
    local o = { __kind = kind, scripts = {}, events = {}, shown = true, children = {} }
    return setmetatable(o, frameMeta)
end

frameMeta = {
    __index = function(self, key)
        local special = {
            SetScript = function(s, name, fn) s.scripts[name] = fn end,
            GetScript = function(s, name) return s.scripts[name] end,
            HookScript = function(s, name, fn)
                local old = s.scripts[name]
                s.scripts[name] = function(...) if old then old(...) end fn(...) end
            end,
            RegisterEvent = function(s, ev) s.events[ev] = true end,
            UnregisterEvent = function(s, ev) s.events[ev] = nil end,
            Show = function(s) s.shown = true end,
            Hide = function(s) s.shown = false end,
            SetShown = function(s, v) s.shown = v and true or false end,
            IsShown = function(s) return s.shown end,
            IsVisible = function(s) return s.shown end,
            CreateTexture = function() return newObject("Texture") end,
            CreateFontString = function()
                local fs = newObject("FontString")
                fs.text = ""
                fs.SetText = function(f, t) f.text = t end
                fs.GetText = function(f) return f.text end
                fs.GetStringHeight = function() return 12 end
                fs.GetFont = function() return "Fonts\\FRIZQT__.TTF", 12 end
                return fs
            end,
            GetWidth = function() return 300 end,
            GetHeight = function() return 200 end,
            GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
            GetEffectiveScale = function() return 1 end,
            GetChecked = function(s) return s.checked end,
            SetChecked = function(s, v) s.checked = v end,
            GetText = function(s) return s.text or "" end,
            SetText = function(s, t) s.text = t end,
            GetParent = function(s) return s.parent end,
            SetParent = function(s, p) s.parent = p end,
            GetValue = function(s) return s.value or 0 end,
            SetValue = function(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end,
        }
        if special[key] then return special[key] end
        return function() return nil end
    end,
}

function CreateFrame(kind, name, parent)
    local f = newObject(kind)
    f.parent = parent
    table.insert(MOCK.frames, f)
    if name then _G[name] = f end
    return f
end

UIParent = newObject("Frame")
WorldMapFrame = newObject("Frame")
GameTooltip = newObject("GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(MOCK.printed, msg) end }
UISpecialFrames = {}
SlashCmdList = {}
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", MAGE = "Mage" }
ERR_NEWTAXIPATH = "New flight path discovered!"
BackdropTemplateMixin = {}

function MOCK.fire(event, ...)
    for _, f in ipairs(MOCK.frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

function MOCK.tick(seconds)
    local step = 0.05
    local t = 0
    while t < seconds do
        MOCK.time = MOCK.time + step
        t = t + step
        for _, f in ipairs(MOCK.frames) do
            if f.scripts.OnUpdate and f.shown then f.scripts.OnUpdate(f, step) end
        end
        local due = {}
        for i = #MOCK.timers, 1, -1 do
            if MOCK.timers[i].at <= MOCK.time then table.insert(due, table.remove(MOCK.timers, i)) end
        end
        for _, d in ipairs(due) do d.fn() end
    end
end

MOCK.timers = {}
C_Timer = { After = function(sec, fn) table.insert(MOCK.timers, { at = MOCK.time + sec, fn = fn }) end }

function GetTime() return MOCK.time end
function GetBuildInfo() return "2.5.6", "70577", "Oct 1 2026", 20506 end
C_AddOns = { GetAddOnMetadata = function(_, field) if field == "Version" then return "test" end end, IsAddOnLoaded = function() return false end }

function UnitRace() return MOCK.player.race, MOCK.player.race end
function UnitClass() return MOCK.player.class, MOCK.player.class end
function UnitFactionGroup() return MOCK.player.faction end
function UnitLevel() return MOCK.player.level end
function UnitName() return MOCK.player.name end
function UnitXP() return 50 end
function UnitXPMax() return 100 end
function GetRealZoneText() return MOCK.zone end
function GetZoneText() return MOCK.zone end
function GetSubZoneText() return "" end
function GetBindLocation() return MOCK.bind end
function GetPlayerFacing() return 0 end

C_QuestLog = { IsQuestFlaggedCompleted = function(id) return MOCK.completed[id] == true end }
function GetNumQuestLogEntries() return #MOCK.questLog end
function GetQuestLogTitle(i)
    local q = MOCK.questLog[i]
    if not q then return nil end
    return q.title, 1, nil, false, false, q.complete and 1 or nil, nil, q.id
end
function GetNumQuestLeaderBoards(i) return #(MOCK.questLog[i].objectives or {}) end
function GetQuestLogLeaderBoard(o, i)
    local ob = MOCK.questLog[i].objectives[o]
    return ob.text, "monster", ob.done
end

C_Map = {
    GetBestMapForUnit = function() return 1429 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.48, 0.42 end } end,
    GetWorldPosFromMapPos = function(_, v) return 0, { GetXY = function() return v.x * 1000, v.y * 1000 end } end,
    GetMapInfo = function() return { name = "Elwynn Forest" } end,
}
function CreateVector2D(x, y) return { x = x, y = y } end

function GetNumTalentTabs() return 3 end
function GetTalentTabInfo(tab) return "Tab" .. tab end
function GetNumTalents(tab) return #(MOCK.talents[tab] or {}) end
function GetTalentInfo(tab, i)
    local t = MOCK.talents[tab] and MOCK.talents[tab][i]
    if not t then return nil end
    return t.name, "icon", t.tier, t.column, t.rank, t.maxRank
end
function UnitCharacterPoints() return 0 end
function GetSpellTexture() return "icon" end
function GetSpellInfo() return "Spell", nil, "icon" end

function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_Initialize() end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton() end
function UIDropDownMenu_SetText() end
function CloseDropDownMenus() end
function InterfaceOptions_AddCategory() end
function InterfaceOptionsFrame_OpenToCategory() end
function ReloadUI() end
function hooksecurefunc() end

bit = bit or {
    band = function(a, b)
        local r, m = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then r = r + m end
            a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
        end
        return r
    end,
}
