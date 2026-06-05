--[[
    Chapter 01: minimal Lplus class and construction.
]]

local Lplus = {}

----------------------------------------
--
-- external functions
--
----------------------------------------

local rawget = rawget
local type = type
local pairs = pairs
local setmetatable = setmetatable
local getmetatable = getmetatable
local tostring = tostring
local error = error
local select = select
local assert = assert
local require = require
local pcall = pcall
local debug = debug

-- debug
local _G = _G
--~ local _error = error
--~ local function error (what)
--~     return _error(what, 2)
--~ end

local function createType(typeName)
    local theType = {}
    local typeMeta = {}

    typeMeta.typeName = typeName

    local typeString = (typeName or "anonymousType") .. "(" .. tostring(theType) .. ")"
    typeMeta.__tostring = function(_)
        return typeString
    end

    function typeMeta.__call(_)
        local objMeta =
        {
            typeTable = theType,
        }

        local obj = {}
        return setmetatable(obj, objMeta)
    end

    return setmetatable(theType, typeMeta)
end

function Lplus.Class(typeName)
    return createType(typeName)
end

local _ENV = nil    -- help to do spelling checking, compatible with lua 5.1

return Lplus
