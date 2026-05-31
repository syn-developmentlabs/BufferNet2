--[=[
    @class xor-lua
    Xor encryption in lua(u)
    (i replaced the ~ xor operator with bit32.bxor)

    @author https://github.com/Braayy
]=]

local bit = bit32

local function bxor(a, b)
    if bit then
        return bit.bxor(a, b)
    end
    
    local result = 0
    local bit_val = 1
    while a > 0 or b > 0 do
        if (a % 2) ~= (b % 2) then
            result = result + bit_val
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit_val = bit_val * 2
    end
    return result
end

local function repeat_key(key, length)
    if #key >= length then
        return key:sub(1, length)
    end
    local times = math.floor(length / #key)
    local remain = length % #key
    local result = {}
    for i = 1, times do
        result[#result + 1] = key
    end
    if remain > 0 then
        result[#result + 1] = key:sub(1, remain)
    end
    return table.concat(result)
end

local function xor(message, key)
    local rkey = repeat_key(key, #message)
    local result = {}
    for i = 1, #message do
        local k_byte = rkey:byte(i)
        local m_byte = message:byte(i)
        result[i] = string.char(bxor(m_byte, k_byte))
    end
    return table.concat(result)
end

return xor