-- TBCGuide - slash commands
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local _, ns = ...

local HELP = {
    { "", "toggle the guide window" },
    { "guide", "open the guide browser" },
    { "talents", "open the talent guide / calculator" },
    { "next", "mark the current step done" },
    { "prev", "go back one step" },
    { "skip", "skip the current step" },
    { "reset", "reset progress of the current guide" },
    { "auto", "load the recommended guide for this character" },
    { "nextguide", "load the next guide in your route" },
    { "load <guideId>", "load a guide by id" },
    { "class", "class leveling tips" },
    { "options", "open settings" },
    { "automation", "open quest automation / junk selling settings" },
    { "orphans", "review and abandon quests your route will never turn in" },
    { "mark [icon]", "mark your target (skull, cross, square, moon, triangle, diamond, circle, star)" },
    { "unmark", "clear your target's raid marker" },
    { "marker <icon>", "set the default marker" },
    { "markbar", "show/hide the raid marker bar" },
    { "markers", "open raid marker settings" },
    { "protect <itemID|link>", "never sell this item automatically (unprotect to undo)" },
    { "protected", "list protected items and junk-sale totals" },
    { "escort add|remove <questID>", "extra quests that must never be auto-accepted (escort list)" },
    { "set <option> on|off", "change a setting from chat" },
    { "debug [api|talents|quest <id>|escort <id>|marks|errors]", "diagnostics" },
    { "help", "this list" },
}

local function printHelp()
    ns:Print("commands (/tbcg or /tbcguide):")
    for _, h in ipairs(HELP) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffd100/tbcg %s|r - %s", h[1], h[2]))
    end
end

local commands = {}

commands[""] = function() ns.MainFrame:Toggle() end
commands.show = function() ns.MainFrame:Show() end
commands.guide = function() ns.Browser:Toggle() end
commands.guides = commands.guide
commands.browser = commands.guide
commands.talents = function() ns.TalentFrame:Toggle() end
commands.talent = commands.talents
commands.next = function() ns.Engine:Next() end
commands.prev = function() ns.Engine:Prev() end
commands.skip = function() ns.Engine:Skip() end
commands.reset = function() ns.Engine:Reset() end
commands.options = function() ns.Options:Open() end
commands.config = commands.options
commands.help = printHelp
commands.orphans = function() ns.OrphanFrame:Toggle() end

commands.mark = function(arg)
    local icon
    if arg and arg ~= "" then
        icon = ns.Marker.Parse(arg)
        if not icon then return ns:Print("Unknown marker '" .. arg .. "'. Use skull, cross, square, moon, triangle, diamond, circle, star or 1-8.") end
    end
    ns.Marker:MarkTarget(icon)
end
commands.unmark = function() ns.Marker:Unmark() end
commands.marker = function(arg)
    local icon = ns.Marker.Parse(arg)
    if not icon then return ns:Print("Default marker is " .. ns.Marker.Label(ns.db.profile.defaultMarker) .. ". Usage: /tbcg marker <icon>") end
    ns.db.profile.defaultMarker = icon
    ns:Print("Default marker: " .. ns.Marker.Label(icon))
end
commands.markbar = function() ns.MarkerBar:Toggle() end
commands.markers = function() ns.MarkerBar:OpenOptions() end
commands.orphaned = commands.orphans
commands.automation = function() ns.AutomationOptions:Open() end

commands.protect = function(arg)
    local id = ns.Vendor.ParseItem(arg)
    if not id then return ns:Print("usage: /tbcg protect <itemID or shift-clicked item link>") end
    ns.Vendor:Protect(id, true)
    ns:Print("Protected item " .. id .. ": it will never be sold automatically.")
end

commands.unprotect = function(arg)
    local id = ns.Vendor.ParseItem(arg)
    if not id then return ns:Print("usage: /tbcg unprotect <itemID or item link>") end
    ns.Vendor:Protect(id, false)
    ns:Print("Item " .. id .. " is no longer protected.")
end

commands.protected = function()
    local ids = ns.Vendor:ProtectedList()
    ns:Print(#ids .. " protected item(s): " .. (#ids > 0 and table.concat(ids, ", ") or "none"))
    local js = ns.char.junkStats
    ns:Print(string.format("Automatic junk sales: %d items, %s. Selling is %s.", js.items,
        ns.Compat.FormatMoney(js.copper), ns.db.profile.autoSellJunk and "ON" or "OFF"))
end

commands.escort = function(arg)
    local verb, id = string.match(arg or "", "^(%S+)%s+(%d+)")
    id = tonumber(id)
    if verb == "add" and id then
        ns.db.escortExtra[id] = true
        return ns:Print("Quest " .. id .. " will never be accepted automatically.")
    elseif verb == "remove" and id then
        if ns.EscortQuests[id] then return ns:Print("Quest " .. id .. " is a known escort quest and stays manual.") end
        ns.db.escortExtra[id] = nil
        return ns:Print("Quest " .. id .. " removed from your escort list.")
    end
    local ids = {}
    for q in pairs(ns.db.escortExtra) do ids[#ids + 1] = q end
    table.sort(ids)
    ns:Print("usage: /tbcg escort add|remove <questID>. Your list: " .. (#ids > 0 and table.concat(ids, ", ") or "empty"))
end

commands.auto = function()
    local g, why = ns.Selector:Recommend()
    if g then
        ns:Print("Loading " .. g.name .. " (" .. why .. ")")
        ns.Engine:Load(g.id)
        ns.MainFrame:Show()
    else
        ns:Print("No guide available for this character.")
    end
end

commands.nextguide = function()
    local g = ns.Engine.guide
    local n = g and ns.Selector:NextAfter(g)
    if n then ns.Engine:Load(n.id) else ns:Print("No next guide; use /tbcg guide.") end
end

commands.load = function(arg)
    if not arg or arg == "" then return ns:Print("usage: /tbcg load <guideId>") end
    ns.Engine:Load(arg)
end

commands.class = function()
    ns.ClassAdvice:PrintFor(ns.Compat.PlayerInfo().class)
end

commands.set = function(arg)
    local key, val = string.match(arg or "", "^(%S+)%s+(%S+)$")
    if not key or ns.db.profile[key] == nil or type(ns.db.profile[key]) ~= "boolean" then
        local keys = {}
        for k, v in pairs(ns.db.profile) do if type(v) == "boolean" then keys[#keys + 1] = k end end
        table.sort(keys)
        return ns:Print("usage: /tbcg set <option> on|off. Options: " .. table.concat(keys, ", "))
    end
    ns.db.profile[key] = (val == "on" or val == "true" or val == "1")
    ns:Print(key .. " = " .. tostring(ns.db.profile[key]))
    ns.Options:Apply()
end

commands.debug = function(arg) ns.Diagnostics:Run(arg) end

local function dispatch(msg)
    msg = msg or ""
    local cmd, rest = string.match(msg, "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")
    local fn = commands[cmd]
    if not fn then
        ns:Print("unknown command '" .. cmd .. "'. Type /tbcg help.")
        return
    end
    local ok, err = pcall(fn, rest)
    if not ok then
        ns:Print("|cffff5555command failed:|r " .. tostring(err))
        ns:Error(err)
    end
end

function ns:RegisterCommands()
    -- Only claim /tbcg and /tbcguide; warn if another add-on already registered either.
    for key, value in pairs(_G) do
        if type(key) == "string" and string.sub(key, 1, 6) == "SLASH_" and string.sub(key, 1, 14) ~= "SLASH_TBCGUIDE"
            and type(value) == "string" then
            local v = string.lower(value)
            if v == "/tbcg" or v == "/tbcguide" then
                ns:Print("warning: " .. value .. " is also registered by another add-on (" .. key .. ").")
            end
        end
    end
    SLASH_TBCGUIDE1 = "/tbcg"
    SLASH_TBCGUIDE2 = "/tbcguide"
    SlashCmdList["TBCGUIDE"] = dispatch
end
