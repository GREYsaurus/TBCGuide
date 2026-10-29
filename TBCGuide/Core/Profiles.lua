-- TBCGuide - settings profiles: create, switch, copy, delete, reset, set default
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Profiles hold the settings (ns.db.profile). Guide progress, talents and junk-sale totals are
-- per character (ns.char) and never change with the profile. Storage: Core/SavedVars.lua.

local _, ns = ...

local P = {}
ns.Profiles = P

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end
P.Copy = copy

local function all() return TBCGuideDB.profiles end

function P:Current() return ns.db.profileName end

-- Sorted profile names.
function P:List()
    local out = {}
    for name in pairs(all()) do out[#out + 1] = name end
    table.sort(out)
    return out
end

local function valid(name)
    return type(name) == "string" and string.match(name, "%S") ~= nil and #name <= 48
end

-- Settings changed under every module's feet: let them re-read ns.db.profile.
function P:Changed()
    ns:Fire("TBCG_PROFILE_CHANGED", self:Current())
    if ns.Options and ns.Options.panel then ns.Options:Apply() end
end

-- Switches this character to `name`, creating it from defaults if it does not exist.
function P:Set(name)
    if not valid(name) then return false, "enter a profile name" end
    name = string.gsub(name, "^%s+", ""):gsub("%s+$", "")
    local profiles = all()
    if not profiles[name] then profiles[name] = ns.FixProfile({}) end
    TBCGuideDB.profileKeys[ns.CharKey()] = name
    ns:SetActiveProfile(name)
    self:Changed()
    return true
end

-- Copies every setting of `from` into the active profile.
function P:CopyFrom(from)
    local src = all()[from]
    if not src then return false, "no profile named " .. tostring(from) end
    if from == self:Current() then return false, "that is the active profile" end
    local dst = ns.db.profile
    for k in pairs(dst) do dst[k] = nil end
    for k, v in pairs(copy(src)) do dst[k] = v end
    ns.FixProfile(dst)
    self:Changed()
    return true
end

-- Deletes an unused profile (never the active or the default one).
function P:Delete(name)
    local profiles = all()
    if not profiles[name] then return false, "no profile named " .. tostring(name) end
    if name == self:Current() then return false, "you cannot delete the active profile" end
    if name == TBCGuideDB.defaultProfile then return false, "you cannot delete the default profile" end
    profiles[name] = nil
    for char, p in pairs(TBCGuideDB.profileKeys) do
        if p == name then TBCGuideDB.profileKeys[char] = TBCGuideDB.defaultProfile end
    end
    return true
end

-- Puts the active profile back to the default settings.
function P:Reset()
    local dst = ns.db.profile
    for k in pairs(dst) do dst[k] = nil end
    ns.FixProfile(dst)
    self:Changed()
    return true
end

-- New characters (and characters whose profile was deleted) start with the active profile.
function P:SetDefault()
    TBCGuideDB.defaultProfile = self:Current()
    return true
end

function P:Default() return TBCGuideDB.defaultProfile end
