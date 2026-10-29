-- TBCGuide - headless tests: minimap button (loaded by run_tests.lua)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only

local check, ns = TEST.check, TEST.ns
local MB = ns.MinimapButton
local b = MB.button

-- Created at login, once, on the minimap, visible by default ----------------------------------------
check(b ~= nil and _G.TBCGuideMinimapButton == b and b.parent == Minimap, "minimap button created on the minimap")
check(ns.db.profile.showMinimapButton == true and b:IsShown(), "shown by default")
MB:Create()
check(MB.button == b, "created only once")
local nButtons = 0
for _, f in ipairs(MOCK.frames) do if f == b then nButtons = nButtons + 1 end end
check(nButtons == 1, "no duplicate button frames")
check(ns.db.minimap.angle == MB.DEFAULT_ANGLE and b.point and b.point[1] == "CENTER" and b.point[2] == Minimap, "placed at the default angle")
local r = math.rad(MB.DEFAULT_ANGLE)
check(math.abs(b.point[4] - math.cos(r) * 80) < 1e-6 and math.abs(b.point[5] - math.sin(r) * 80) < 1e-6, "sits on the minimap edge (radius 70 + 10)")

-- Left-click opens settings; a second click closes them -----------------------------------------------
InterfaceOptionsFrame:Hide()
local opened = MOCK.optionsOpened
b.scripts.OnClick(b, "LeftButton")
check(MOCK.optionsOpened > opened and InterfaceOptionsFrame:IsShown(), "left-click opens the settings window")
b.scripts.OnClick(b, "LeftButton")
check(not InterfaceOptionsFrame:IsShown(), "clicking again closes it")
-- settings not created yet (clicked right after login): a message, no error
local panel = ns.Options.panel
ns.Options.panel = nil
local before = #MOCK.printed
local ok = pcall(b.scripts.OnClick, b, "LeftButton")
check(ok and #MOCK.printed > before and string.find(MOCK.printed[#MOCK.printed], "not ready", 1, true), "settings not ready: explained, no error")
ns.Options.panel = panel
InterfaceOptionsFrame:Hide()

-- Right-click toggles the guide window ----------------------------------------------------------------
local mf = ns.MainFrame.frame
local wasShown = mf and mf:IsShown()
b.scripts.OnClick(b, "RightButton")
check(mf and mf:IsShown() ~= wasShown, "right-click toggles the guide window")
b.scripts.OnClick(b, "RightButton")
check(mf and mf:IsShown() == wasShown, "right-click again restores it")
check(not InterfaceOptionsFrame:IsShown(), "right-click does not open settings")

-- Tooltip --------------------------------------------------------------------------------------------
GameTooltip.lines = {}
b.scripts.OnEnter(b)
check(GameTooltip.lines[1] == "TBCGuide" and string.find(table.concat(GameTooltip.lines, "\n"), "open TBCGuide settings", 1, true), "tooltip names the add-on and says what a click does")

-- Dragging: follows the cursor, saves once on release, release is not a click ----------------------
-- cursor straight above the minimap centre -> 90 degrees
MOCK.cursorX, MOCK.cursorY = 1000, 700
b.scripts.OnDragStart(b)
check(type(b.scripts.OnUpdate) == "function", "drag starts following the cursor")
b.scripts.OnUpdate(b, 0.05)
check(math.abs(b.point[4]) < 1e-6 and math.abs(b.point[5] - 80) < 1e-6, "button moves with the cursor")
check(ns.db.minimap.angle == MB.DEFAULT_ANGLE, "nothing is saved while dragging")
MOCK.cursorX, MOCK.cursorY = 900, 600 -- left of the centre -> 180 degrees
b.scripts.OnUpdate(b, 0.05)
b.scripts.OnDragStop(b)
check(ns.db.minimap.angle == 180 and b.scripts.OnUpdate == nil, "angle saved once when the drag ends")
opened = MOCK.optionsOpened
b.scripts.OnClick(b, "LeftButton") -- the mouse-up that ends the drag
check(MOCK.optionsOpened == opened and not InterfaceOptionsFrame:IsShown(), "releasing a drag does not open settings")
b.scripts.OnMouseDown(b)
b.scripts.OnClick(b, "LeftButton")
check(MOCK.optionsOpened > opened, "the next real click works again")
InterfaceOptionsFrame:Hide()
-- a client that sends no click after a drag must not swallow the next real click
b.scripts.OnDragStart(b)
b.scripts.OnDragStop(b)
opened = MOCK.optionsOpened
b.scripts.OnMouseDown(b)
b.scripts.OnClick(b, "LeftButton")
check(MOCK.optionsOpened > opened, "no click after a drag: the next press still opens settings")
InterfaceOptionsFrame:Hide()

-- Persistence across /reload, and invalid saved data -------------------------------------------------
ns:InitSavedVariables()
MB:Update()
check(ns.db.minimap.angle == 180 and math.abs(b.point[4] + 80) < 1e-6, "position kept after a reload")
for _, bad in ipairs({ "x", -1 / 0, 0 / 0 }) do
    TBCGuideDB.minimap = { angle = bad }
    ns:InitSavedVariables()
    check(ns.db.minimap.angle == MB.DEFAULT_ANGLE, "invalid saved angle repaired: " .. tostring(bad))
end
TBCGuideDB.minimap = "garbage"
ns:InitSavedVariables()
check(type(ns.db.minimap) == "table" and ns.db.minimap.angle == MB.DEFAULT_ANGLE, "corrupt minimap record repaired")
TBCGuideDB.minimap = { angle = 725 }
ns:InitSavedVariables()
check(ns.db.minimap.angle == 5, "angle normalised to 0-360")
local keepAuto = ns.db.profile.autoAccept
ns.db.minimap.angle = 90
check(ns.db.profile.autoAccept == keepAuto, "saving the position leaves other settings alone")

-- Square minimaps (set by minimap add-ons) -----------------------------------------------------------
function GetMinimapShape() return "SQUARE" end
MB:Place(45)
check(math.abs(b.point[4] - 80) < 1e-6 and math.abs(b.point[5] - 80) < 1e-6, "square minimap: button goes to the corner")
GetMinimapShape = nil

-- Visibility setting ---------------------------------------------------------------------------------
local cb
for _, c in ipairs(ns.Options.checks) do if c.key == "showMinimapButton" then cb = c end end
check(cb ~= nil, "options page has a 'Show the minimap button' checkbox")
cb:SetChecked(false)
cb.scripts.OnClick(cb)
check(ns.db.profile.showMinimapButton == false and not b:IsShown(), "unticking hides the button immediately")
ns:InitSavedVariables()
MB:Update()
check(ns.db.profile.showMinimapButton == false and not b:IsShown(), "hidden state survives a reload")
check(SlashCmdList["TBCGUIDE"] ~= nil and pcall(SlashCmdList["TBCGUIDE"], "options"), "settings still reachable by /tbcg options while hidden")
local okc = pcall(SlashCmdList["TBCGUIDE"], "minimap")
check(okc and ns.db.profile.showMinimapButton == true and b:IsShown(), "/tbcg minimap shows it again")
pcall(SlashCmdList["TBCGUIDE"], "set showMinimapButton off")
check(not b:IsShown(), "/tbcg set showMinimapButton off hides it")
pcall(SlashCmdList["TBCGUIDE"], "set showMinimapButton on")
check(b:IsShown(), "/tbcg set showMinimapButton on shows it")
InterfaceOptionsFrame:Hide()
ns.db.minimap.angle = MB.DEFAULT_ANGLE
MB:Update()
