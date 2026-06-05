--[[
    Chapter 04: inheritance for fields, methods, and static members.
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

local function createProxy(metatable)
    return setmetatable({}, metatable)
end

local function shallowCopy(destTable, sourceTable)
    for k, v in pairs(sourceTable) do
        destTable[k] = v
    end
end

local function createType(baseTypeTable, typeName)
    local theType = {}
    local typeMeta = {}

    typeMeta.typeName = typeName
    typeMeta.baseTypeTable = baseTypeTable
    typeMeta.fields = {}
    typeMeta.methods = {}
    typeMeta.staticMembers = {}
    typeMeta.compatibleTypes = { [theType] = true }

    if baseTypeTable ~= nil then
        local baseMeta = getmetatable(baseTypeTable)
        if type(baseMeta) ~= "table" then
            error("Base type should be a Lplus type table", 3)
        end

        shallowCopy(typeMeta.fields, baseMeta.fields)
        shallowCopy(typeMeta.methods, baseMeta.methods)
        shallowCopy(typeMeta.staticMembers, baseMeta.staticMembers)
        shallowCopy(typeMeta.compatibleTypes, baseMeta.compatibleTypes)
    end

    local typeString = (typeName or "anonymousType") .. "(" .. tostring(theType) .. ")"
    typeMeta.__tostring = function(_)
        return typeString
    end

    function typeMeta.__index(_, memberName)
        return typeMeta.staticMembers[memberName]
    end

    local function Field()
        return createProxy
        {
            __index = function(_, fieldName)
                error('You need to give field "' .. tostring(fieldName) .. '" a default value', 2)
            end;

            __newindex = function(_, fieldName, initValue)
                if type(fieldName) ~= "string" then
                    error("Field name should be string, got: " .. type(fieldName), 2)
                end

                typeMeta.fields[fieldName] = initValue
            end;
        }
    end

    local function Method()
        return createProxy
        {
            __index = function(_, methodName)
                error("You need to give method a function body", 2)
            end;

            __newindex = function(_, methodName, functionBody)
                if type(methodName) ~= "string" then
                    error("Method name should be string, got: " .. type(methodName), 2)
                end
                if type(functionBody) ~= "function" then
                    error("Need function body, got: " .. type(functionBody), 2)
                end

                typeMeta.methods[methodName] = functionBody
            end;
        }
    end

    local function StaticMethod()
        return createProxy
        {
            __index = function(_, methodName)
                error("You need to give static method a function body", 2)
            end;

            __newindex = function(_, methodName, functionBody)
                if type(methodName) ~= "string" then
                    error("Method name should be string, got: " .. type(methodName), 2)
                end
                if type(functionBody) ~= "function" then
                    error("Need function body, got: " .. type(functionBody), 2)
                end

                typeMeta.staticMembers[methodName] = functionBody
            end;
        }
    end

    local define =
    {
        field = Field,
        method = Method,
        static = StaticMethod,
    }

    typeMeta.define = define
    theType.define = define

    local objMeta =
    {
        typeTable = theType,
        __index = typeMeta.methods,
    }

    function typeMeta.__call(_)
        local obj = {}

        for fieldName, initValue in pairs(typeMeta.fields) do
            obj[fieldName] = initValue
        end

        return setmetatable(obj, objMeta)
    end

    return setmetatable(theType, typeMeta)
end

function Lplus.Class(typeName)
    return createType(nil, typeName)
end

function Lplus.Extend(baseTypeTable, typeName)
    return createType(baseTypeTable, typeName)
end

local _ENV = nil    -- help to do spelling checking, compatible with lua 5.1

return Lplus
