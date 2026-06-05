--[[
    Chapter 05: virtual, override, and final method semantics.
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

local function inheritStaticMembers(derivedMeta, baseMeta)
    for name, value in pairs(baseMeta.staticMembers) do
        if baseMeta.staticStyles[name] ~= "f" then
            derivedMeta.staticMembers[name] = value
            derivedMeta.staticStyles[name] = baseMeta.staticStyles[name]
        end
    end
end

local function createType(baseTypeTable, typeName)
    local theType = {}
    local typeMeta = {}

    typeMeta.typeName = typeName
    typeMeta.baseTypeTable = baseTypeTable
    typeMeta.fields = {}
    typeMeta.methods = {}
    typeMeta.methodStyles = {}
    typeMeta.methodOwners = {}
    typeMeta.staticMembers = {}
    typeMeta.staticStyles = {}
    typeMeta.compatibleTypes = { [theType] = true }

    if baseTypeTable ~= nil then
        local baseMeta = getmetatable(baseTypeTable)
        if type(baseMeta) ~= "table" then
            error("Base type should be a Lplus type table", 3)
        end

        shallowCopy(typeMeta.fields, baseMeta.fields)
        shallowCopy(typeMeta.methods, baseMeta.methods)
        shallowCopy(typeMeta.methodStyles, baseMeta.methodStyles)
        shallowCopy(typeMeta.methodOwners, baseMeta.methodOwners)
        inheritStaticMembers(typeMeta, baseMeta)
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

    local function MethodInternal(style)
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

                local bStatic = (style == "s")
                local bFinal = (style == "f")
                local bOverride = (style == "o")

                if bOverride then
                    local inheritedStyle = typeMeta.methodStyles[methodName]
                    local inheritedOwner = typeMeta.methodOwners[methodName]
                    if inheritedStyle == nil or inheritedOwner == theType then
                        error('overrided method with name "' .. methodName .. '" not exists', 2)
                    end
                    if inheritedStyle ~= "v" and inheritedStyle ~= "o" then
                        error('Can not override non-virtual method "' .. methodName .. '"', 2)
                    end
                elseif typeMeta.methodOwners[methodName] ~= nil and typeMeta.methodOwners[methodName] ~= theType then
                    error('member with name "' .. methodName .. '" already exists, use override for virtual methods', 2)
                end

                if bStatic or bFinal then
                    typeMeta.staticMembers[methodName] = functionBody
                    typeMeta.staticStyles[methodName] = style
                else
                    typeMeta.methods[methodName] = functionBody
                    typeMeta.methodStyles[methodName] = style
                    typeMeta.methodOwners[methodName] = theType
                end
            end;
        }
    end

    local function Method()
        return MethodInternal("")
    end

    local function VirtualMethod()
        return MethodInternal("v")
    end

    local function OverrideMethod()
        return MethodInternal("o")
    end

    local function StaticMethod()
        return MethodInternal("s")
    end

    local function FinalMethod()
        return MethodInternal("f")
    end

    local define =
    {
        field = Field,
        method = Method,
        virtual = VirtualMethod,
        override = OverrideMethod,
        static = StaticMethod,
        final = FinalMethod,
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
