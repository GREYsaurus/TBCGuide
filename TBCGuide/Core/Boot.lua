-- TBCGuide - start-up sequence (loaded last)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Each stage runs in pcall so one failing module (e.g. a UI API missing in some client build)
-- cannot stop the rest; failures are listed by /tbcg debug errors.

local addonName, ns = ...

local function stage(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        ns:Error("init " .. name .. ": " .. tostring(err))
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffTBCGuide|r: |cffff5555" .. name .. " failed to initialise:|r " .. tostring(err))
    end
    return ok
end

ns:On("ADDON_LOADED", function(_, loaded)
    if loaded ~= addonName then return end
    stage("saved variables", function() ns:InitSavedVariables() end)
    ns.version = ns.Compat.GetAddOnMetadata(addonName, "Version") or "dev"
    stage("database overrides", function() ns.QDB:ApplyOverrides() end)
end)

ns:On("PLAYER_LOGIN", function()
    if not ns.db then ns:InitSavedVariables() end
    stage("commands", function() ns:RegisterCommands() end)
    stage("quest tracker", function() ns.Tracker:Init() end)
    stage("engine", function() ns.Engine:Init() end)
    stage("quest automation", function() ns.QuestAuto:Init() end)
    stage("junk selling", function() ns.Vendor:Init() end)
    stage("talents", function() ns.Talents:Init() end)
    stage("trainer suggestions", function() ns.Trainer:Init() end)
    stage("main window", function() ns.MainFrame:Create() end)
    stage("browser", function() ns.Browser:Create() end)
    stage("talent window", function() ns.TalentFrame:Create() end)
    stage("talent suggestions", function() ns.TalentHints:Init() end)
    stage("options", function() ns.Options:Create() end)
    stage("minimap button", function() ns.MinimapButton:Create() end)
    stage("automation options", function() ns.AutomationOptions:Create() end)
    stage("orphaned quests", function() ns.OrphanFrame:Create() end)
    stage("marker bar", function() ns.MarkerBar:Create() ns.MarkerBar:CreateOptions() end)
    stage("raid markers", function() ns.Marker:Init() end)
    stage("gear scoring", function() ns.GearUI:Create() end)
    stage("automatic upgrades", function() ns.GearMarkers:Init() ns.BagAdapters:Init() ns.AutoEquip:Init() end)
    stage("group features", function() ns.Group:Init() end)
    stage("flight timers", function() ns.FlightTimer:Init() end)
    stage("active items", function() ns.ActiveItems:Init() end)
    stage("active targets", function() ns.ActiveTargets:Init() end)
    stage("leveling tracker", function() ns.LevelTracker:Init() end)
    stage("map extras", function() ns.MapExtras:Init() end)
    stage("auction upgrades", function() ns.AHUpgrades:Init() end)
    stage("navigation", function() ns.Nav:Init() end)
    stage("assist", function() ns.Assist:Init() end)
    stage("settings window", function() ns.Config:Create() end)

    stage("first-login setup", function() ns.Welcome:Migrate() end)
    stage("guide selection", function()
        local active = ns.char.activeGuide
        if active and ns.Guides:Get(active) then
            ns.Engine:Load(active)
        elseif ns.db.profile.autoSelectGuide then
            local g, why = ns.Selector:Recommend()
            if g then
                ns.Engine:Load(g.id)
                ns:Print("Selected " .. g.name .. " (" .. why .. "). /tbcg guide to change.")
            end
        end
    end)
    stage("setup window", function() ns.Welcome:Init() end)

    if ns.migrationNote then
        ns:Print(ns.migrationNote)
        ns.migrationNote = nil
    end

    local iface = ns.Compat.GetInterface()
    if iface ~= 0 and (iface < ns.Target.minInterface or iface > ns.Target.maxInterface) then
        ns:Print("|cffff7744note:|r built for interface " .. ns.Target.interface .. "; this client reports " .. iface .. ". Some data may not match.")
    end
end)

-- Quest log data is only reliable after the world has loaded.
ns:On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(2, function()
        if ns.Tracker.Scan then ns.Tracker:Scan() end
        if ns.Nav.FromStep and ns.Engine.guide then ns.Nav:FromStep(ns.Engine:CurrentStep()) end
    end)
end)
