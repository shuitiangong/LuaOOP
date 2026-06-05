--[[
    Chapter 08: declared field types and nilable rules.
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

-- to determine value is Lplus object
local lplusObjectMagic = {}

-- to determine value is Lplus type table
local lplusTypeTableMagic = {}

local basicTypeSet =
{
    ["nil"] = true,
    ["number"] = true,
    ["string"] = true,
    ["boolean"] = true,
    ["table"] = true,
    ["function"] = true,
    ["thread"] = true,
    ["userdata"] = true,
    ["dynamic"] = true,
}

local primaryTypeSet =
{
    ["number"] = true,
    ["string"] = true,
    ["boolean"] = true,
}

local nilableTypeSet =
{
    ["nil"] = true,
    ["table"] = true,
    ["function"] = true,
    ["thread"] = true,
    ["userdata"] = true,
}

local function createProxy(metatable)
    return setmetatable({}, metatable)
end

local function shallowCopy(destTable, sourceTable)
    for k, v in pairs(sourceTable) do
        destTable[k] = v
    end
end

local function getTypeTableMeta(typeTable)
    if type(typeTable) ~= "table" then
        return nil
    end

    local meta = getmetatable(typeTable)
    if meta == nil or meta.magic ~= lplusTypeTableMagic then
        return nil
    end

    return meta
end

local getTypeTableMetaNoCheck = getmetatable

local function getObjectMeta(obj)
    if type(obj) ~= "table" then
        return nil
    end

    local meta = getmetatable(obj)
    if meta == nil or meta.magic ~= lplusObjectMagic then
        return nil
    end

    return meta
end

local getObjectMetaNoCheck = getmetatable

local function getObjectTypeTable(obj)
    return getObjectMetaNoCheck(obj).typeTable
end

local function getObjectTypeMeta(obj)
    return getTypeTableMetaNoCheck(getObjectTypeTable(obj))
end

local function formatTypeName(typeValue)
    if typeValue == nil then
        return "<none>"
    elseif type(typeValue) == "string" then
        return '"' .. typeValue .. '"'
    else
        return tostring(typeValue)
    end
end

local function formatObjectTypeName(object)
    if getObjectMeta(object) ~= nil then
        return tostring(getObjectTypeTable(object))
    else
        return '"' .. type(object) .. '"'
    end
end

local function checkValidArgType(typeValue, iParam, memberName, errLevel)
    if type(typeValue) == "string" then
        if not basicTypeSet[typeValue] then
            error('bad argument #' .. iParam .. ' to member "' .. memberName .. '" (vaild basic type name expected, got "' .. typeValue .. '")', errLevel + 1)
        end
    else
        if getTypeTableMeta(typeValue) == nil then
            error('bad argument #' .. iParam .. ' to member "' .. memberName .. '" (type table expected, got ' .. type(typeValue) .. ')', errLevel + 1)
        end
    end
end

local function isTypeCompatible(value, needType)
    if needType == "dynamic" then
        return true
    elseif type(needType) == "string" then
        if primaryTypeSet[needType] then
            return type(value) == needType
        else
            return value == nil or type(value) == needType
        end
    else
        return value == nil or Lplus.is(value, needType)
    end
end

local function checkValueCompatible(value, needType, format, who, errorLevel)
    if not isTypeCompatible(value, needType) then
        local what = format:format(who)
        error(([[bad %s (%s expected, got %s)]])
            :format(what, formatTypeName(needType), formatObjectTypeName(value)), errorLevel + 1)
    end
end

local function isCompatibleTypeTable(obj, typeTable)
    return getObjectTypeMeta(obj).compatibleTypes[typeTable] ~= nil
end

local function inheritMemberInfo(derivedMemberInfo, baseMemberInfo)
    for name, info in pairs(baseMemberInfo) do
        if info.inheritable then
            derivedMemberInfo[name] = info
        end
    end
end

local function inheritStaticMembers(derivedMeta, baseMeta)
    for name, value in pairs(baseMeta.staticMembers) do
        local memberInfo = baseMeta.memberInfoMap[name]
        if memberInfo == nil or memberInfo.inheritable then
            derivedMeta.staticMembers[name] = value
        end
    end
end

local function createMemberInfo(memberType, style, typeTable, inheritable, valueType)
    return
    {
        memberType = memberType,
        style = style,
        typeTable = typeTable,
        inheritable = inheritable,
        valueType = valueType,
    }
end

local function createType(baseTypeTable, typeName)
    local theType = {}
    local typeMeta = {}

    typeMeta.magic = lplusTypeTableMagic
    typeMeta.typeName = typeName
    typeMeta.baseTypeTable = baseTypeTable
    typeMeta.fields = {}
    typeMeta.methods = {}
    typeMeta.staticMembers = {}
    typeMeta.memberInfoMap = {}
    typeMeta.compatibleTypes = { [theType] = true }

    if baseTypeTable ~= nil then
        local baseMeta = getTypeTableMeta(baseTypeTable)
        if baseMeta == nil then
            error("Base type should be a Lplus type table", 3)
        end

        shallowCopy(typeMeta.fields, baseMeta.fields)
        shallowCopy(typeMeta.methods, baseMeta.methods)
        inheritStaticMembers(typeMeta, baseMeta)
        shallowCopy(typeMeta.compatibleTypes, baseMeta.compatibleTypes)
        inheritMemberInfo(typeMeta.memberInfoMap, baseMeta.memberInfoMap)
    end

    local typeString = (typeName or "anonymousType") .. "(" .. tostring(theType) .. ")"
    typeMeta.__tostring = function(_)
        return typeString
    end

    function typeMeta.__index(_, memberName)
        return typeMeta.staticMembers[memberName]
    end

    local function Field(fieldType)
        return createProxy
        {
            __index = function(_, fieldName)
                error('You need to give field "' .. tostring(fieldName) .. '" a default value', 2)
            end;

            __newindex = function(_, fieldName, initValue)
                if type(fieldName) ~= "string" then
                    error("Field name should be string, got: " .. type(fieldName), 2)
                end
                if typeMeta.memberInfoMap[fieldName] ~= nil then
                    error('member with name "' .. fieldName .. '" already exists', 2)
                end

                checkValidArgType(fieldType, 1, fieldName, 2)
                checkValueCompatible(initValue, fieldType, [[initial value to field '%s']], fieldName, 2)

                typeMeta.fields[fieldName] = initValue
                typeMeta.memberInfoMap[fieldName] = createMemberInfo("field", "", theType, true, fieldType)
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
                local baseMemberInfo
                local oldInfo = typeMeta.memberInfoMap[methodName]

                if oldInfo ~= nil then
                    if bOverride and oldInfo.memberType == "method" and oldInfo.typeTable ~= theType then
                        if oldInfo.style == "v" or oldInfo.style == "o" then
                            baseMemberInfo = oldInfo
                        else
                            error('Can not override non-virtual method "' .. methodName .. '"', 2)
                        end
                    else
                        error('member with name "' .. methodName .. '" already exists', 2)
                    end
                end

                if bOverride and baseMemberInfo == nil then
                    error('overrided method with name "' .. methodName .. '" not exists', 2)
                end

                if bStatic or bFinal then
                    typeMeta.staticMembers[methodName] = functionBody
                else
                    typeMeta.methods[methodName] = functionBody
                end

                typeMeta.memberInfoMap[methodName] = createMemberInfo("method", style, theType, not bFinal)
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
        magic = lplusObjectMagic,
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

function Lplus.is(obj, typeTable)
    if getObjectMeta(obj) == nil then
        return false
    end

    return isCompatibleTypeTable(obj, typeTable)
end

local _ENV = nil    -- help to do spelling checking, compatible with lua 5.1

return Lplus
