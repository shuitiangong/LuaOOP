local Lplus = {}

local function createType(typeName)
    local theType = {}
    local typeMeta = {}
    typeMeta.typeName = typeName

    local typeString = (typeName or "anonymousType") .. "()" .. tostring(theType) .. ")"
    typeMeta.__tostring = function (_)
        return typeString
    end

    function typeMeta.__call(_)
        local objMeta = {
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

return Lplus
