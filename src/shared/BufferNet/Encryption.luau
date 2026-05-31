--[=[
    @class Encryption
    Encryption for buffernet

    @author https://github.com/syn-developmentlabs
]=]

local Encryption   = {}
Encryption.__index = Encryption

local utils = require("./Utilities")
local xor = require("./xor-lua")

--[=[
    @method Encrypt
    Encrypt payload

    @param payload string -- The payload to encrypt
    @param encryptionKey string -- Encryption key
]=]
function Encryption:Encrypt(payload: string, encryptionKey: string): string?
    utils.assertTypes("string", payload, 1)
    
    -- / @ sanity checks
    local w1 = workspace:GetServerTimeNow(); task.wait(1/10); local w2 = workspace:GetServerTimeNow();
    if w1 == w2 or w2-w1 > 1 then return end;

    payload = "✅".. payload
    local modulus = math.floor(workspace:GetServerTimeNow() % 67)
    local enc_key = `{modulus + 67}{encryptionKey}{modulus}`
    
    return xor(payload, enc_key)
end 

--[=[
    @method Decrypt
    Decrypt payload

    @param payload string -- Thje string to decrypt
    @param decryptionKey string -- The decryption key
]=]
function Encryption:Decrypt(payload: string, decryptionKey: string, ping: number?): string?
    ping = ping or 0.05

    -- / @ too lazy to documentate this
    local function tryDecrypt(offset: number): string
        local workspaceTime = workspace:GetServerTimeNow() - ping
        local modulus = math.floor(workspaceTime % 67) + offset
        local enc_key = `{modulus + 67}{decryptionKey}{modulus}`

        return xor(payload, enc_key)
    end

    local function isValid(input: string): boolean
        return input:find("✅") ~= nil
    end

    local initalDecryptionResult = tryDecrypt(0)
    local decryptionResult;
    if not isValid(initalDecryptionResult) then
        for i = -5, 5 do
            local dec = tryDecrypt(i)
            
            if isValid(dec) then
                decryptionResult = dec
                break
            end
        end
    else
        decryptionResult = initalDecryptionResult
    end

    if decryptionResult == nil then
        error("BufferNet: failed to decrypt", 3)
    end
    
    return (decryptionResult:gsub("✅", ""))
end

return Encryption