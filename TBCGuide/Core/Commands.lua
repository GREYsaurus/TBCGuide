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
    { "set <option> on|off", "change a setting from chat" },
    { "debug [api|talents|quest <id>|errors]", "diagnostics" },
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
