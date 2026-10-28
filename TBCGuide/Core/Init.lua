-- TBCGuide - namespace, event bus and shared helpers
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.

local addonName, ns = ...

ns.name = addonName
ns.QDB = { quests = {}, npcs = {}, objects = {}, items = {}, zones = {} }
ns.modules = {}

-- Public handle for other add-ons and for /dump debugging. Data lives in ns.
TBCGuide = ns

local eventFrame = CreateFrame("Frame")
local handlers = {}

-- Register fn(event, ...) for an event. Multiple listeners per event are allowed.
function ns:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        if not ok then
            ns:Debug("event not available in this client: " .. event)
        end
    end
    table.insert(handlers[event], fn)
end

-- Internal (non-game) events, fired with ns:Fire("TBCG_STEP_CHANGED", ...)
local internal = {}
function ns:Listen(event, fn)
    internal[event] = internal[event] or {}
    table.insert(internal[event], fn)
end

function ns:Fire(event, ...)
    local list = internal[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then ns:Error(event .. ": " .. tostring(err)) end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then ns:Error(event .. ": " .. tostring(err)) end
    end
end)

-- Throttled callbacks: ns:Throttle("key", 0.2, fn) runs fn at most once per interval.
local pending = {}
local throttleFrame = CreateFrame("Frame")
throttleFrame:Hide()
throttleFrame:SetScript("OnUpdate", function(self, elapsed)
    local any = false
    for key, job in pairs(pending) do
        job.left = job.left - elapsed
        if job.left <= 0 then
            pending[key] = nil
            local ok, err = pcall(job.fn)
            if not ok then ns:Error(key .. ": " .. tostring(err)) end
        else
            any = true
        end
    end
    if not any and not next(pending) then self:Hide() end
end)

function ns:Throttle(key, delay, fn)
    if pending[key] then return end
    pending[key] = { left = delay, fn = fn }
    throttleFrame:Show()
end

local PREFIX = "|cff33ccffTBCGuide|r: "

function ns:Print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

ns.errors = {}
function ns:Error(msg)
    table.insert(ns.errors, msg)
    if #ns.errors > 50 then table.remove(ns.errors, 1) end
    if ns.db and ns.db.profile and ns.db.profile.debug then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "|cffff5555" .. tostring(msg) .. "|r")
    end
end

function ns:Debug(msg)
    if ns.db and ns.db.profile and ns.db.profile.debug then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "|cff999999" .. tostring(msg) .. "|r")
    end
end

-- Small table helpers --------------------------------------------------------

function ns.Contains(list, value)
    if not list then return false end
    for i = 1, #list do if list[i] == value then return true end end
    return false
end

function ns.Copy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = ns.Copy(v) end
    return r
end

-- Fill missing keys of `dst` from `defaults` (recursive). Never overwrites user values.
function ns.Merge(dst, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ns.Merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- Bitmask test that works with the 32-bit bit library and plain Lua numbers.
function ns.HasBit(mask, bitValue)
    if not mask or mask == 0 then return false end
    if bit and bit.band then return bit.band(mask, bitValue) ~= 0 end
    return math.floor(mask / bitValue) % 2 == 1
end

function ns.Round(v, places)
    local m = 10 ^ (places or 0)
    return math.floor(v * m + 0.5) / m
end
