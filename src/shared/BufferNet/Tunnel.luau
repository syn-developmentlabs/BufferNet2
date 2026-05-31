--[=[
    @class Tunnel
    Communication handling for BufferNet

    @author https://github.com/syn-developmentlabs
]=]

local Tunnel   = {}
Tunnel.__index = Tunnel

local utils          = require("./Utilities")
local types          = require("./d.types")
local typeSerializer = require("./TypeSerializers")
local encryption     = require("./Encryption")

--[=[
    @method Initialize
    Initialize a new communications tunnel

    @param instance RemoteEvent
]=]
function Tunnel:Initialize(
    instance: RemoteEvent | RemoteFunction, 
    callback: (any) -> (any?), 
    isEncrypted: boolean?, 
    encryptionDetails: types.EncryptionInformation?
): RBXScriptConnection?
    utils.assertTypes("Instance", instance, 1)
    callback = callback or function() end

    -- / @ TODO: add unreliable remote event support
    -- / @ check if the instance is an event or a function
    if instance:IsA("RemoteEvent") then
         -- / @ connect the OnServerEvent
        return instance.OnServerEvent:Connect(function(a0: Player, dataBuffer: buffer)
            assert(typeof(dataBuffer) == "buffer", "BufferNet: error in network tunnel, must send a buffer.")
            
            -- / @ covnert buffer into string
            local stringifiedBuffer: string = buffer.tostring(dataBuffer)

            -- / @ encrypt if applicable
            if isEncrypted and encryptionDetails then
                local decryptionResult = encryption:Decrypt(stringifiedBuffer, encryptionDetails.EncryptionMasterKey, a0:GetNetworkPing())
                if not decryptionResult then return; end
                stringifiedBuffer = decryptionResult
            end

            -- / @ deseralize & unpack
            local deserialized = typeSerializer:Deserialize(stringifiedBuffer)
            coroutine.wrap(callback)(a0, unpack(deserialized or {}))
        end)
    else
        -- / @ set up onserverinvoke
        instance.OnServerInvoke = function(a0: Player, dataBuffer: buffer)
            assert(typeof(dataBuffer) == "buffer", "BufferNet: error in network tunnel, must send a buffer.")
            
            -- / @ covnert buffer into string
            local stringifiedBuffer: string = buffer.tostring(dataBuffer)

            -- / @ encrypt if applicable
            if isEncrypted and encryptionDetails then
                local decryptionResult = encryption:Decrypt(stringifiedBuffer, encryptionDetails.EncryptionMasterKey, a0:GetNetworkPing())
                if not decryptionResult then return; end
                stringifiedBuffer = decryptionResult
            end

            --[[
                            -- / @ check if the callback returns without errors
            local success, response = pcall(callback, a0, unpack(deserialized))
            if not success then
                return error("BufferNet: server errored with: ".. response)
            end

            print(success,response)

            return response
            ]]

            -- / @ deseralize & unpack
            local deserialized = typeSerializer:Deserialize(stringifiedBuffer)
            return coroutine.wrap(callback)(a0, unpack(deserialized or {}))
        end
    end

    return
end

return Tunnel