--[[
    Chapter 13: Commit freezes declaration and checks interfaces.
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

-- to send internal setup commands into function wrappers
local lplusFunctionWrapperControlMagic = {}

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
    ["nil"] = true,
    ["number"] = true,
    ["string"] = true,
    ["boolean"] = true,
}

local nonNilPrimaryTypeSet =
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

local function argListError(iArg, memberName, needs, gets, errLevel)
    if gets == nil then
        error(([[bad argument #%d to argument list of %s (%s)]])
            :format(iArg, memberName, needs), errLevel + 1)
    else
        error(([[bad argument #%d to argument list of %s (%s expected, got %s)]])
            :format(iArg, memberName, needs, gets), errLevel + 1)
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

local function isInterface(typeTable)
    local meta = getTypeTableMeta(typeTable)
    return meta ~= nil and meta.isInterface == true
end

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

local function initValueError(fieldName, expected, got, errorLevel)
    error(([[bad initial value to field '%s' (%s expected, got %s)]])
        :format(fieldName, expected, got), errorLevel + 1)
end

local function checkValidArgType(typeValue, iParam, memberName, errLevel)
    if type(typeValue) == "string" then
        if not basicTypeSet[typeValue] then
            argListError(iParam, memberName, "vaild basic type name", '"' .. typeValue .. '"', errLevel + 1)
        end
    else
        if getTypeTableMeta(typeValue) == nil then
            argListError(iParam, memberName, "type table", type(typeValue), errLevel + 1)
        end
    end
end

local function isTypeCompatible(value, needType)
    if needType == "dynamic" then
        return true
    elseif type(needType) == "string" then
        if nonNilPrimaryTypeSet[needType] then
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

local function checkValuesCompatible(needTypes, errLevel, ...)
    local nGets = select("#", ...)
    local nNeeds = #needTypes
    local bVarlist = needTypes.bVarlist

    if nGets < nNeeds then
        local what = needTypes.format:format(needTypes.who)
        error(([[too little %s (%d expected, got %d)]])
            :format(what, nNeeds, nGets), errLevel + 1)
    end

    if not bVarlist and nGets > nNeeds then
        local what = needTypes.format:format(needTypes.who)
        error(([[too many %s (%d expected, got %d)]])
            :format(what, nNeeds, nGets), errLevel + 1)
    end

    local selfType = needTypes.selfType
    if selfType ~= nil then
        local self = ...
        if self == nil then
            local what = needTypes.ithFormat:format(1, needTypes.who)
            error(([[bad %s (%s expected, got %s)]])
                :format(what, formatTypeName(selfType), formatObjectTypeName(self)), errLevel + 1)
        end
    end

    for i = 1, nNeeds do
        local getValue = select(i, ...)
        local needType = needTypes[i]

        if needType == "varlist" then
            return
        end

        if not isTypeCompatible(getValue, needType) then
            local what = needTypes.ithFormat:format(i, needTypes.who)
            error(([[bad %s (%s expected, got %s)]])
                :format(what, formatTypeName(needType), formatObjectTypeName(getValue)), errLevel + 1)
        end
    end

    return ...
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

local function checkMethodParamAndMakeList(paramCount, paramList, methodName, errorLevel)
    local result = {}

    local bReturnPart = false
    local iSeperator = -1
    local bGotParamValist = false
    local bGotReturnValist = false

    for i = 1, paramCount do
        local inParam = paramList[i]
        if inParam == "=>" then
            bReturnPart = true
            iSeperator = i
        elseif inParam == "varlist" then
            if bReturnPart then
                bGotReturnValist = true
                result[-(i - iSeperator)] = inParam
            else
                bGotParamValist = true
                result[i] = inParam
            end
        else
            checkValidArgType(inParam, i, methodName, errorLevel + 1)
            if bReturnPart then
                if bGotReturnValist then
                    argListError(i, methodName, '"varlist" must be the last return value type', nil, errorLevel + 1)
                end
                result[-(i - iSeperator)] = inParam
            else
                if bGotParamValist then
                    argListError(i, methodName, '"varlist" must be the last param value type', nil, errorLevel + 1)
                end
                result[i] = inParam
            end
        end
    end

    return result
end

local function compareSignature(signatureLeft, signatureRight)
    local iParam = 1
    repeat
        local paramLeft = signatureLeft[iParam]
        local paramRight = signatureRight[iParam]

        if paramLeft ~= paramRight then
            return iParam
        end

        iParam = iParam + 1
    until paramLeft == nil

    local iReturn = 1
    repeat
        local returnLeft = signatureLeft[-iReturn]
        local returnRight = signatureRight[-iReturn]

        if returnLeft ~= returnRight then
            return -iReturn
        end

        iReturn = iReturn + 1
    until returnLeft == nil

    return nil
end

local function checkMethodOverrideSignature(signatureBase, signatureOverride, methodType, methodName, errLevel)
    local iDiff = compareSignature(signatureBase, signatureOverride)
    if iDiff ~= nil then
        local what
        local iWhat
        if iDiff > 0 then
            what = "param"
            iWhat = iDiff
        else
            what = "return value"
            iWhat = -iDiff
        end

        error(([[bad %s type #%d to %s '%s' (%s expected, got %s)]])
            :format(what, iWhat, methodType, methodName,
                formatTypeName(signatureBase[iDiff]),
                formatTypeName(signatureOverride[iDiff])),
            errLevel + 1)
    end
end

local function createEmptyFunctionWrapper()
    local func
    local methodName
    local tableType
    local bCheckType

    local arguments
    local returns

    return function(...)
        local magic, op = ...
        if magic == lplusFunctionWrapperControlMagic then
            if op == "set" then
                local _, methodInfo
                _, _, func, methodName, tableType, methodInfo, bCheckType = ...

                local bInstanceMethod =
                    methodInfo.style:find("s", 1, true) == nil
                    and methodInfo.style:find("f", 1, true) == nil

                local needTypes = methodInfo.valueType
                arguments =
                {
                    format = "arguments to '%s' in " .. tostring(tableType),
                    ithFormat = "argument #%d to '%s' in " .. tostring(tableType),
                    who = methodName,
                }
                returns =
                {
                    format = "return values from '%s' in " .. tostring(tableType),
                    ithFormat = "return value #%d from '%s' in " .. tostring(tableType),
                    who = methodName,
                }

                if bInstanceMethod then
                    arguments[#arguments + 1] = tableType
                    arguments.selfType = tableType
                end

                local iArg = 1
                while needTypes[iArg] do
                    local needType = needTypes[iArg]
                    if needType == "varlist" then
                        arguments.bVarlist = true
                    else
                        arguments[#arguments + 1] = needType
                    end
                    iArg = iArg + 1
                end

                local iRet = 1
                while needTypes[-iRet] do
                    local needType = needTypes[-iRet]
                    if needType == "varlist" then
                        returns.bVarlist = true
                    else
                        returns[iRet] = needType
                    end
                    iRet = iRet + 1
                end
            end

            return
        end

        if bCheckType then
            return checkValuesCompatible(returns, 1, func(checkValuesCompatible(arguments, 2, ...)))
        else
            return func(...)
        end
    end
end

local function setFunctionWrapper(wrapper, func, methodName, tableType, methodInfo, bCheckType)
    wrapper(lplusFunctionWrapperControlMagic, "set", func, methodName, tableType, methodInfo, bCheckType)
end

local function createFunctionWrapper(func, methodName, tableType, methodInfo, bCheckType)
    local wrapper = createEmptyFunctionWrapper()
    setFunctionWrapper(wrapper, func, methodName, tableType, methodInfo, bCheckType)

    return wrapper
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

local function createType(baseTypeTable, typeName, bInterface)
    local theType = {}
    local typeMeta = {}
    local bCreatingClass = true
    bInterface = bInterface == true

    if baseTypeTable ~= nil then
        local baseMeta = getTypeTableMeta(baseTypeTable)
        if baseMeta == nil then
            error("Base type should be a Lplus type table", 3)
        end

        local isBaseInterface = baseMeta.isInterface == true
        if isBaseInterface then
            bInterface = true
        end
        if isBaseInterface ~= bInterface then
            if bInterface then
                error("interface can not inherit from non-interface type", 2)
            else
                error("non-interface can not inherit from interface type", 2)
            end
        end
    end

    typeMeta.magic = lplusTypeTableMagic
    typeMeta.typeName = typeName
    typeMeta.baseTypeTable = baseTypeTable
    typeMeta.isInterface = bInterface
    typeMeta.fields = {}
    typeMeta.abstractMethods = {}
    typeMeta.methods = {}
    typeMeta.staticMembers = {}
    typeMeta.memberInfoMap = {}
    typeMeta.compatibleTypes = { [theType] = true }
    typeMeta.implementInterfaces = {}

    if baseTypeTable ~= nil then
        local baseMeta = getTypeTableMeta(baseTypeTable)

        shallowCopy(typeMeta.fields, baseMeta.fields)
        shallowCopy(typeMeta.methods, baseMeta.methods)
        shallowCopy(typeMeta.abstractMethods, baseMeta.abstractMethods)
        inheritStaticMembers(typeMeta, baseMeta)
        shallowCopy(typeMeta.compatibleTypes, baseMeta.compatibleTypes)
        inheritMemberInfo(typeMeta.memberInfoMap, baseMeta.memberInfoMap)
    end

    local typeString = (typeName or "anonymousType") .. "(" .. tostring(theType) .. ")"
    typeMeta.__tostring = function(_)
        return typeString
    end

    function theType.Implement(interfaceTypeTable)
        typeMeta.compatibleTypes[interfaceTypeTable] = true
        typeMeta.implementInterfaces[interfaceTypeTable] = true
        return theType
    end

    local function FieldInternal(style, fieldType)
        if bInterface then
            error("interface can not have field", 2)
        end
        if not bCreatingClass then
            error("bad field defining (type " .. tostring(theType) .. " is already committed)", 2)
        end

        local bConstant = (style == "c")

        return createProxy
        {
            __index = function(_, fieldName)
                error("You need to give field a default value", 2)
            end;

            __newindex = function(_, fieldName, initValue)
                if type(fieldName) ~= "string" then
                    error("Field name should be string, got: " .. type(fieldName), 2)
                end
                if typeMeta.memberInfoMap[fieldName] ~= nil then
                    error('member with name "' .. fieldName .. '" already exists', 2)
                end

                checkValidArgType(fieldType, 1, fieldName, 2)

                local memberInfo = createMemberInfo("field", style, theType, true, fieldType)

                if bConstant then
                    checkValueCompatible(initValue, fieldType, [[initial value to field '%s']], fieldName, 2)
                    typeMeta.staticMembers[fieldName] = initValue
                else
                    local initValueType = type(initValue)
                    if not primaryTypeSet[initValueType] and initValueType ~= "function" then
                        initValueError(fieldName, "number, boolean, string, nil or function", initValueType, 2)
                    end

                    if type(initValue) ~= "function" then
                        checkValueCompatible(initValue, fieldType, [[initial value to field '%s']], fieldName, 2)
                    end

                    typeMeta.fields[fieldName] = initValue
                end

                typeMeta.memberInfoMap[fieldName] = memberInfo
            end;
        }
    end

    local function Field(fieldType)
        return FieldInternal("", fieldType)
    end

    local function ConstField(fieldType)
        return FieldInternal("c", fieldType)
    end

    local function MethodInternal(style, ...)
        if not bCreatingClass then
            error("bad method defining (type " .. tostring(theType) .. " is already committed)", 2)
        end

        local paramCount = select("#", ...)
        local paramList = {...}

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

                local memberInfo = createMemberInfo(
                    "method",
                    style,
                    theType,
                    not bFinal,
                    checkMethodParamAndMakeList(paramCount, paramList, methodName, 2))

                if baseMemberInfo ~= nil then
                    checkMethodOverrideSignature(baseMemberInfo.valueType, memberInfo.valueType, "override method", methodName, 2)
                end

                functionBody = createFunctionWrapper(functionBody, methodName, theType, memberInfo, true)

                if bStatic or bFinal then
                    if bInterface then
                        error("Interface can not have static method", 2)
                    end

                    typeMeta.staticMembers[methodName] = functionBody
                else
                    if bInterface then
                        typeMeta.abstractMethods[methodName] = functionBody
                    else
                        typeMeta.methods[methodName] = functionBody
                    end
                end

                typeMeta.memberInfoMap[methodName] = memberInfo
            end;
        }
    end

    local function Method(...)
        return MethodInternal("", ...)
    end

    local function VirtualMethod(...)
        return MethodInternal("v", ...)
    end

    local function OverrideMethod(...)
        return MethodInternal("o", ...)
    end

    local function StaticMethod(...)
        return MethodInternal("s", ...)
    end

    local function FinalMethod(...)
        return MethodInternal("f", ...)
    end

    local define =
    {
        field = Field,
        const = ConstField,
        method = Method,
        virtual = VirtualMethod,
        override = OverrideMethod,
        static = StaticMethod,
        final = FinalMethod,
    }

    typeMeta.define = define
    theType.define = define

    local function commit()
        bCreatingClass = false

        theType.Implement = nil
        theType.define = nil
        theType.Commit = nil

        if not bInterface then
            local selfMembers = typeMeta.memberInfoMap

            for interface, _ in pairs(typeMeta.implementInterfaces) do
                local interfaceMeta = getTypeTableMetaNoCheck(interface)

                for methodName, methodInfo in pairs(interfaceMeta.memberInfoMap) do
                    assert(methodInfo.memberType == "method")

                    local selfMemberInfo = selfMembers[methodName]
                    if selfMemberInfo == nil or selfMemberInfo.memberType ~= "method" then
                        error(("method '%s' in interface '%s' not implemented"):format(methodName, tostring(interface)), 2)
                    end

                    checkMethodOverrideSignature(
                        methodInfo.valueType,
                        selfMemberInfo.valueType,
                        "method implemetation",
                        methodName,
                        2)
                end
            end
        end

        function typeMeta.__index(_, memberName)
            return typeMeta.staticMembers[memberName]
        end

        local objMeta =
        {
            typeTable = theType,
            magic = lplusObjectMagic,
            __index = typeMeta.methods,
        }

        function typeMeta.__call(_)
            if bInterface then
                error("interface " .. tostring(theType) .. " can not instantiate", 2)
            end

            local obj = {}

            for fieldName, initValue in pairs(typeMeta.fields) do
                local realInitValue = initValue

                if type(initValue) == "function" then
                    local bSucc, ret = pcall(initValue)
                    if not bSucc then
                        error('failed to get initial value for member "' .. fieldName .. '" :\n  ' .. ret)
                    end
                    realInitValue = ret
                end

                local memberInfo = typeMeta.memberInfoMap[fieldName]
                checkValueCompatible(realInitValue, memberInfo.valueType, [[initial value to field '%s']], fieldName, 2)

                obj[fieldName] = realInitValue
            end

            return setmetatable(obj, objMeta)
        end

        return theType
    end

    typeMeta.commit = commit
    theType.Commit = commit

    return setmetatable(theType, typeMeta)
end

function Lplus.Class(typeName)
    return createType(nil, typeName, false)
end

function Lplus.Extend(baseTypeTable, typeName)
    return createType(baseTypeTable, typeName, false)
end

function Lplus.Interface(typeName)
    return createType(nil, typeName, true)
end

function Lplus.ExtendInterface(baseTypeTable, typeName)
    return createType(baseTypeTable, typeName, true)
end

function Lplus.is(obj, typeTable)
    if getObjectMeta(obj) == nil then
        return false
    end

    return isCompatibleTypeTable(obj, typeTable)
end

local _ENV = nil    -- help to do spelling checking, compatible with lua 5.1

return Lplus
