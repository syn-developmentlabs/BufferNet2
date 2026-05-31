--[=[
    @class TypeSerializers
    Type serializers for BufferNet

    @author https://github.com/syn-devleopmentlabs
]=]

local TypeSerializers = {}
TypeSerializers.__index = TypeSerializers

local HttpService = game:GetService("HttpService")

local serializers = {
    ["CFrame"] = function(a0: CFrame)
        return `<CFrame>({tostring(a0)})`
    end,
    ["Vector3"] = function(a0: Vector3)
        return `<Vector3>({tostring(a0)})` 
    end
}

local deserializers = {
    ["CFrame"] = function(a0: string)
        local _a0 = a0:match("%(.*%)")
        if not _a0 then return; end
        local a0 = (((_a0:gsub("%(", "")):gsub("%)", "")):gsub(" ","")):split(",")
        for i,v in next, a0 do a0[i] = tonumber(v) end
        return CFrame.new(unpack(a0))
    end,
    ["Vector3"] = function(a0: string)
        local _a0 = a0:match("%(.*%)")
        if not _a0 then return; end
        local a0 = (((_a0:gsub("%(", "")):gsub("%)", "")):gsub(" ","")):split(",")
        for i,v in next, a0 do a0[i] = tonumber(v) end
        return Vector3.new(unpack(a0))
    end,
    ["string"] = function(a0: string)
        local _a0 = a0:match("%(.*%)")
        if not _a0 then return; end
        local a0 = ((_a0:gsub("%(", "")):gsub("%)", ""))
        return a0
    end,
    ["number"] = function(a0: string)
        local _a0 = a0:match("%(.*%)")
        if not _a0 then return; end
        local a0 = ((_a0:gsub("%(", "")):gsub("%)", ""))
        return tonumber(a0)
    end,
}

--[=[
    @function serializeTable
    Serialize tables with roblox types into json-compatible tables

    @param table {[any]: any} -- Table to serialize
]=]
local function serializeTable(table: {[any]: any}): {[any]: any}
    local newTable = {}

    -- / @ TODO: KEY SERIALIZATON
    -- / @ iterate through every key and value
    for key, value in next, table do
        local valueType = typeof(value)

        -- / @ if the value is a table, recursively call the serializeTable function to serialize it
        if valueType == "table" then
            newTable[key] = serializeTable(value)
            continue
        end
        
        -- / @ check if our type serializer can serialize the value's type
        local currentTypeSerializer: (any) -> (string) = serializers[valueType]
        if currentTypeSerializer then
            newTable[key] = currentTypeSerializer(value)
        else -- / @ if not, just tostring it (wityh the type annotation)
            newTable[key] = `<{valueType}>({tostring(value)})`
        end
    end
 
    return newTable
end

--[=[
    @function deserializeTable
    Parse given table with type annotations to a table which actually works
]=]

function deserializeTable(table: {[any]: any})
    local newTable = {}

    for key, value: string in next, table do
        -- / @ if type type annotation is not found, it should be a table
        if typeof(value) == "table" then
            newTable[key] = deserializeTable(value)
            continue
        end

        -- / @ parse value type
        local _valueType = value:match("<.*>")
        local valueType = ((_valueType:gsub("<", "")):gsub(">", ""))

        -- / @ deserialize
        local currentDeserializer = deserializers[valueType]
        if currentDeserializer then
            newTable[key] = currentDeserializer(value)
        else
            newTable[key] = tostring(value) 
        end
    end

    return newTable
end

--[=[
    @method Serialize
    Serialize given table and return a string

    @param table {[any]: any} -- The table to serialize
    @return string
]=]
function TypeSerializers:Serialize(table: {[any]: any}): string
    return HttpService:JSONEncode(serializeTable(table))
end

--[=[
    @method Deserialize
    Deserialize given JSON string into a luau table
    
    @param table string -- The table to deserialize
    @return {[any]: any}
]=]
function TypeSerializers:Deserialize(table: string): {[any]: any}
    return deserializeTable(HttpService:JSONDecode(table))
end

return TypeSerializers