local Lplus = {}

local function createProxy(metatable)
    return setmetatable({}, metatable)
end

local function createType(typeName)
    local theType = {}
    local typeMeta = {}
    typeMeta.typeName = typeName
    typeMeta.fields = {}

    local typeString = (typeName or "anonymousType") .. "(" .. tostring(theType) .. ")"
    typeMeta.__tostring = function (_)
        return typeString
    end

    local function Field()
        return createProxy({
            __index = function(_, fieldName)
                error('You need to give field "' .. tostring(fieldName) .. '" a default value', 2)
            end;

            __newindex = function(_, fieldName, initValue)
                if type(fieldName) ~= "string" then
                    error("Field name should be string, got: " .. type(fieldName), 2)
                end

                typeMeta.fields[fieldName] = initValue
            end;
        }) 
    end

    local define = {
        field = Field,
    }

    typeMeta.define = define
    theType.define = define

    function typeMeta.__call(_)
        local objMeta = {
            typeTable = theType,
        }

        local obj = {}

        for fieldName, initValue in pairs(typeMeta.fields) do
            obj[fieldName] = initValue
        end

        return setmetatable(obj, objMeta)
    end

    return setmetatable(theType, typeMeta)

end

function Lplus.Class(typeName)
    return createType(typeName)
end

return Lplus
