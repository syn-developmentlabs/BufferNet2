--!strict
--[=[
	@class BufferNet2
	Networking with buffers on roblox

	@author https://github.com/syn-developmentlabs
]=]

local BufferNet   = {}
BufferNet.__index = BufferNet

local ANONYMIZE_REMOTE_EVENTS = false
local ANONYMIZED_REMOTE_NAMES = "" -- / @ requires the thing above to be on

local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local utils           = require("@self/Utilities")
local types           = require("@self/d.types")
local tunnel          = require("@self/Tunnel")
local typeSerializers = require("@self/TypeSerializers")
local encryption      = require("@self/Encryption")

--[=[
	@method new
	@yields
	Intialize BufferNet on the client or server (based on calling context)

    @param @server path Instance -- The path to put the Communications folder in (server only)
]=]
function BufferNet.new(path: Instance?)
	local self = setmetatable({}, BufferNet)
    
    -- / @ important stuff
    self.Remotes = {} :: {[string]: types.Remote}
    self.Initialized = false

	-- / @ check if the client or server is initializing
	if RunService:IsClient() then
		-- / @ wait until the server has initalized communications
        local communicationsFolder: Instance?;
		while true do
            communicationsFolder = CollectionService:GetTagged("_BufferNetCommunication")[1]
            
            if communicationsFolder and communicationsFolder:GetAttribute("HasInitialized") then
                self.Communications = communicationsFolder
                break
            end
            
            task.wait(1/10)
        end

        if communicationsFolder then
            -- / @ iterate through each remote so we can index them on the client
            for _, instance: Instance in communicationsFolder:GetDescendants() do
                local i = instance -- / @ the strict typechecking in question:
                if not instance:IsA("RemoteEvent") and not instance:IsA("RemoteFunction") then
                    continue
                end
                
                -- / @ insert
                self.Remotes[tostring(instance)] = {
                    Type = (instance.ClassName:lower():gsub("remote", "")) :: "event" | "function", 
                    Instance = instance :: RemoteEvent | RemoteFunction,
                    Alias = tostring(instance),
                    Options = instance:GetAttributes() :: types.Options
                }

                -- / @ anonymization
                if ANONYMIZE_REMOTE_EVENTS then
                    i.Name = ANONYMIZED_REMOTE_NAMES
                end
            end
        end
    else
        -- / @ create the communications folder
        local communications = Instance.new("Folder")
        communications.Name = "Communications"
        communications.Parent = path or ReplicatedStorage
        communications:AddTag("_BufferNetCommunication")

        -- / @ crate Events & Functions subdirectories
        local events = Instance.new("Folder")
        events.Name = "Events"
        events.Parent = communications
        
        local functions = Instance.new("Folder")
        functions.Name = "Functions"
        functions.Parent = communications

        -- / @ exclusively to the server, return a method so the server can finish initialization any time
        function self.FinishInitilaztion()
            -- / @ succesfully initialized
            communications:SetAttribute("HasInitialized", true)
        end
        self.Communications = communications
	end

    self.Initialized = true
	return self
end

--[=[
	@method CreateRemote
	Create a Remote(Event or Function)
	
	@param type* "Event" | "Function" | "event" | "function" -- The remote type, determines if it'll be a 
									 -- RemoteEvent or RemoteFunction.
	@param callback (any) -> (any)?   -- Function to call with the recieved args from
									 -- the client
]=]
function BufferNet:CreateRemote(
    type: "Event" | "Function" | "event" | "function", 
    alias: string, 
    callback: (any) -> (any)?,
    options: types.Options?
)
    -- / @ check function caller runcontext
    if not RunService:IsServer() then
        error("This method can only be called from the Server context", 2)
    end

    -- / @ check if the current buffernet instance has initialized yet
    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    -- / @ typechecking
    utils.assertTypes({"event", "function", "Event", "Function"}, type, 1)
    utils.assertTypes("string", alias, 2)

    -- / @ handle both cases which type == "Event" or type == "Function"
    if type:lower() == "event" then
        -- / @ actually create the remote event & parent it
        local remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = alias
        remoteEvent.Parent = self.Communications:FindFirstChild("Events")

        -- / @ add it to the server's remote index
        local remote = {
            Type = "Event",
            Alias = alias,
            Instance = remoteEvent,
            Callback = callback,
            Options = options or {}
        } :: types.Remote

        -- / @ set up encryption (if applicable)
        local connection;
        if options and options.IsEncrypted then
            remote.EncryptionInformation = {
                TunnelStartupTick = workspace:GetServerTimeNow(),
                EncryptionMasterKey = utils.generateRandomString(4)
            } :: types.EncryptionInformation

            for i: string, v: any in next, remote.EncryptionInformation :: {[string]: any} do
                remoteEvent:SetAttribute(i, v)
            end

            -- / @ callback time
            connection = tunnel:Initialize(remoteEvent, callback, options.IsEncrypted, remote.EncryptionInformation)
        end

        -- / @ apply attributes
        if options then
            for i: string, v: any in next, options :: {[string]: any} do
                remoteEvent:SetAttribute(i, v)
            end
        else
            connection = tunnel:Initialize(remoteEvent, callback)
        end

        remote.Connection = connection
        self.Remotes[alias] = remote
    elseif type:lower() == "function" then
        -- / @ create & parent the remotefunction
        local remoteFunction = Instance.new("RemoteFunction")
        remoteFunction.Name = alias
        remoteFunction.Parent = self.Communications:FindFirstChild("Functions")

        -- / @ add it to the servers remote index
        local remote = {
            Type = "Function",
            Alias = alias,
            Instance = remoteFunction,
            Callback = callback,
            Options = options or {}
        } :: types.Remote

        -- / @ apply encryption (if applicable)
        if options and options.IsEncrypted then
            remote.EncryptionInformation = {
                TunnelStartupTick = workspace:GetServerTimeNow(),
                EncryptionMasterKey = utils.generateRandomString(4)
            } :: types.EncryptionInformation

            for i: string, v: any in next, remote.EncryptionInformation :: {[string]: any} do
                remoteFunction:SetAttribute(i, v)
            end

            -- / @ callback time
            tunnel:Initialize(remoteFunction, callback, options.IsEncrypted, remote.EncryptionInformation)
        end

        -- / @ apply attributes
        if options then
            for i: string, v: any in next, options :: {[string]: any} do
                remoteFunction:SetAttribute(i, v)
            end
        else
            tunnel:Initialize(remoteFunction, callback)
        end

        self.Remotes[alias] = remote
    end
end
--[=[
    @method FireServer
    Call :FireServer on a RemoteEvent

    @param alias string -- Remote to fire's alias
    @param ... -- Arguments to fireserver with
]=]
function BufferNet:FireServer(alias: string, ...)
    -- / @ check function caller runcontext
    if not RunService:IsClient() then
        error("This method can only be called from the Client context", 2)
    end

    -- / @ check if the current buffernet instance has initialized yet
    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    -- / @ check if the remote actually exists
    local remote = self.Remotes[alias] :: types.Remote
    if not remote then
        error(`RemoteEvent "{alias}" doesn't exist`, 2)
    end

    -- / @ check if the remote is actually a remote event
    if remote.Type:lower() ~= "event" then
        error(`"{alias}" is not a RemoteEvent`)
    end

    -- / @ serialize the args
    local args = {...}
    local serializedArgs = typeSerializers:Serialize(args)

    -- / @ encryption
    local options = remote.Options
    if options and options.IsEncrypted and options.EncryptionMasterKey then
        local xorResult = encryption:Encrypt(serializedArgs, options.EncryptionMasterKey)

        if not xorResult then
            error("BufferNet: an error occoured", 2)
        end

        serializedArgs = xorResult
    end
    
    -- / @ allocate memory for the serialized arguments
    local argumentsBuffer = buffer.create(serializedArgs:len())
    buffer.writestring(argumentsBuffer, 0, serializedArgs)

    -- / @ fire the server with our buffer
    local remoteEvent = remote.Instance :: RemoteEvent -- / @ un-morph into re
    remoteEvent:FireServer(argumentsBuffer)
end 

--[=[
    @method InvokeServer
    Calls the :InvokeServer method with given arguments on a RemoteFunction
    
    @param alias string -- "alias" of the RemoteFunction
    @param ... -- args
]=]
function BufferNet:InvokeServer(alias: string, ...)
    -- / @ check function caller runcontext
    if not RunService:IsClient() then
        error("This method can only be called from the Client context", 2)
    end

    -- / @ check if the current buffernet instance has initialized yet
    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    -- / @ check if the remote actually exists
    local remote = self.Remotes[alias] :: types.Remote
    if not remote then
        error(`RemoteFunction "{alias}" doesn't exist`, 2)
    end

    -- / @ check if the remote is actually a remote function
    if remote.Type:lower() ~= "function" then
        error(`"{alias}" is not a RemoteFunction`)
    end

    -- / @ serialize the args
    local args = {...}
    local serializedArgs = typeSerializers:Serialize(args)

    -- / @ encryption
    local options = remote.Options
    if options and options.IsEncrypted and options.EncryptionMasterKey then
        local xorResult = encryption:Encrypt(serializedArgs, options.EncryptionMasterKey)

        if not xorResult then
            error("BufferNet: an error occoured", 2)
        end

        serializedArgs = xorResult
    end

    -- / @ allocate memory for the serialized arguments
    local argumentsBuffer = buffer.create(serializedArgs:len())
    buffer.writestring(argumentsBuffer, 0, serializedArgs)

    -- / @ ~~fire~~ invoke the server with our buffer
    local remoteEvent = remote.Instance :: RemoteFunction -- / @ un-morph into re
    return remoteEvent:InvokeServer(argumentsBuffer)
end

--[=[
    @method FireClient
    Fires a RemoteEvent to a specific client

    @param alias string -- Remote to fire's alias
    @param player Player -- The player to fire to
    @param ... -- Arguments to send
]=]
function BufferNet:FireClient(alias: string, player: Player, ...)
    if not RunService:IsServer() then
        error("This method can only be called from the Server context", 2)
    end

    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    local remote = self.Remotes[alias] :: types.Remote
    if not remote then
        error(`RemoteEvent "{alias}" doesn't exist`, 2)
    end

    if remote.Type:lower() ~= "event" then
        error(`"{alias}" is not a RemoteEvent`, 2)
    end

    local args = {...}
    local serializedArgs = typeSerializers:Serialize(args)

    local options = remote.Options
    if options and options.IsEncrypted and remote.EncryptionInformation then
        local xorResult = encryption:Encrypt(serializedArgs, remote.EncryptionInformation.EncryptionMasterKey)
        if not xorResult then
            error("BufferNet: an error occured", 2)
        end
        serializedArgs = xorResult
    end

    local argumentsBuffer = buffer.create(serializedArgs:len())
    buffer.writestring(argumentsBuffer, 0, serializedArgs)

    local remoteEvent = remote.Instance :: RemoteEvent
    remoteEvent:FireClient(player, argumentsBuffer)
end

--[=[
    @method FireAllClients
    Fires a RemoteEvent to every connected player

    @param alias string -- Remote to fire's alias
    @param ... -- Arguments to send
]=]
function BufferNet:FireAllClients(alias: string, ...)
    if not RunService:IsServer() then
        error("This method can only be called from the Server context", 2)
    end

    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    local remote = self.Remotes[alias] :: types.Remote
    if not remote then
        error(`RemoteEvent "{alias}" doesn't exist`, 2)
    end

    if remote.Type:lower() ~= "event" then
        error(`"{alias}" is not a RemoteEvent`, 2)
    end

    local args = {...}
    local serializedArgs = typeSerializers:Serialize(args)

    local options = remote.Options
    if options and options.IsEncrypted and remote.EncryptionInformation then
        local xorResult = encryption:Encrypt(serializedArgs, remote.EncryptionInformation.EncryptionMasterKey)
        if not xorResult then
            error("BufferNet: an error occured", 2)
        end
        serializedArgs = xorResult
    end

    local argumentsBuffer = buffer.create(serializedArgs:len())
    buffer.writestring(argumentsBuffer, 0, serializedArgs)

    local remoteEvent = remote.Instance :: RemoteEvent
    remoteEvent:FireAllClients(argumentsBuffer)
end

--[=[
    @method FireAllClientsExcept
    Fires a RemoteEvent to all players except the one(s) specified

    @param alias string -- Remote to fire's alias
    @param excluded Player | {Player} -- Player or list of players to skip
    @param ... -- Arguments to send
]=]
function BufferNet:FireAllClientsExcept(alias: string, excluded: Player | {Player}, ...)
    if not RunService:IsServer() then
        error("This method can only be called from the Server context", 2)
    end

    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    local remote = self.Remotes[alias] :: types.Remote
    if not remote then
        error(`RemoteEvent "{alias}" doesn't exist`, 2)
    end

    if remote.Type:lower() ~= "event" then
        error(`"{alias}" is not a RemoteEvent`, 2)
    end

    -- / @ normalize excluded into a set for O(1) lookup
    local excludedSet: {[Player]: boolean} = {}
    if typeof(excluded) == "Instance" then
        excludedSet[excluded :: Player] = true
    else
        for _, p in excluded :: {Player} do
            excludedSet[p] = true
        end
    end

    local args = {...}
    local serializedArgs = typeSerializers:Serialize(args)

    local options = remote.Options
    if options and options.IsEncrypted and remote.EncryptionInformation then
        local xorResult = encryption:Encrypt(serializedArgs, remote.EncryptionInformation.EncryptionMasterKey)
        if not xorResult then
            error("BufferNet: an error occured", 2)
        end
        serializedArgs = xorResult
    end

    -- / @ serialize once, reuse the same buffer for every eligible player
    local argumentsBuffer = buffer.create(serializedArgs:len())
    buffer.writestring(argumentsBuffer, 0, serializedArgs)

    local remoteEvent = remote.Instance :: RemoteEvent
    for _, player in game:GetService("Players"):GetPlayers() do
        if not excludedSet[player] then
            remoteEvent:FireClient(player, argumentsBuffer)
        end
    end
end

--[=[
    @method FireClients
    Fires a RemoteEvent to an explicit list of players

    @param alias string -- Remote to fire's alias
    @param players {Player} -- The players to fire to
    @param ... -- Arguments to send
]=]
function BufferNet:FireClients(alias: string, players: {Player}, ...)
    if not RunService:IsServer() then
        error("This method can only be called from the Server context", 2)
    end

    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    local remote = self.Remotes[alias] :: types.Remote
    if not remote then
        error(`RemoteEvent "{alias}" doesn't exist`, 2)
    end

    if remote.Type:lower() ~= "event" then
        error(`"{alias}" is not a RemoteEvent`, 2)
    end

    local args = {...}
    local serializedArgs = typeSerializers:Serialize(args)

    local options = remote.Options
    if options and options.IsEncrypted and remote.EncryptionInformation then
        local xorResult = encryption:Encrypt(serializedArgs, remote.EncryptionInformation.EncryptionMasterKey)
        if not xorResult then
            error("BufferNet: an error occured", 2)
        end
        serializedArgs = xorResult
    end

    local argumentsBuffer = buffer.create(serializedArgs:len())
    buffer.writestring(argumentsBuffer, 0, serializedArgs)

    local remoteEvent = remote.Instance :: RemoteEvent
    for _, player in players do
        remoteEvent:FireClient(player, argumentsBuffer)
    end
end

--[=[
    @method InvokeClient
    Calls :InvokeClient on a RemoteFunction for a specific player

    @param alias string -- Remote to invoke's alias
    @param player Player -- The player to invoke
    @param ... -- Arguments to send
    @return any -- Whatever the client returns
]=]
function BufferNet:InvokeClient(alias: string, player: Player, ...)
    -- / @ check context
    if not RunService:IsServer() then
        error("This method can only be called from the Server context", 2)
    end

    -- / @ check if buffernet has initialized yet
    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    -- / @ check if the remote function exists
    local remote = self.Remotes[alias] :: types.Remote
    if not remote then
        error(`RemoteFunction "{alias}" doesn't exist`, 2)
    end

    -- / @ check if the remote is a function
    if remote.Type:lower() ~= "function" then
        error(`"{alias}" is not a RemoteFunction`, 2)
    end

    -- / @ serialize args
    local args = {...}
    local serializedArgs = typeSerializers:Serialize(args)

    local options = remote.Options
    if options and options.IsEncrypted and remote.EncryptionInformation then
        local xorResult = encryption:Encrypt(serializedArgs, remote.EncryptionInformation.EncryptionMasterKey)
        if not xorResult then
            error("BufferNet: an error occured", 2)
        end
        serializedArgs = xorResult
    end

    local argumentsBuffer = buffer.create(serializedArgs:len())
    buffer.writestring(argumentsBuffer, 0, serializedArgs)

    local remoteFunction = remote.Instance :: RemoteFunction
    return remoteFunction:InvokeClient(player, argumentsBuffer)
end

--[=[
    @method InvokeAllClients
    Invokes all connected players in parallel and collects their return values.
    Returns a dictionary keyed by Player.

    @param alias string -- Remote to invoke's alias
    @param ... -- Arguments to send
    @return {[Player]: any}
]=]
function BufferNet:InvokeAllClients(alias: string, ...)
    if not RunService:IsServer() then
        error("This method can only be called from the Server context", 2)
    end

    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    local remote = self.Remotes[alias] :: types.Remote
    if not remote then
        error(`RemoteFunction "{alias}" doesn't exist`, 2)
    end

    if remote.Type:lower() ~= "function" then
        error(`"{alias}" is not a RemoteFunction`, 2)
    end

    local args = {...}
    local serializedArgs = typeSerializers:Serialize(args)

    local options = remote.Options
    if options and options.IsEncrypted and remote.EncryptionInformation then
        local xorResult = encryption:Encrypt(serializedArgs, remote.EncryptionInformation.EncryptionMasterKey)
        if not xorResult then
            error("BufferNet: an error occured", 2)
        end
        serializedArgs = xorResult
    end

    local argumentsBuffer = buffer.create(serializedArgs:len())
    buffer.writestring(argumentsBuffer, 0, serializedArgs)

    local remoteFunction = remote.Instance :: RemoteFunction
    local results: {[Player]: any} = {}
    local threads: {thread} = {}

    -- / @ invoke each player concurrently so one slow client doesn't block the rest
    for _, player in game:GetService("Players"):GetPlayers() do
        local t = task.spawn(function()
            local ok, result = pcall(function()
                return remoteFunction:InvokeClient(player, argumentsBuffer)
            end)
            results[player] = ok and result or nil
        end)
        table.insert(threads, t)
    end

    -- / @ wait for all spawned threads to finish
    for _, t in threads do
        task.wait() -- / @ yield briefly; threads resolve on next heartbeat
    end

    return results
end

--[=[
    @method OnClientEvent
    Connects a callback to a RemoteEvent on the client side

    @param alias string -- The remote's alias to listen to
    @param callback (any) -> () -- Function to call when the event fires
    @return RBXScriptConnection
]=]
function BufferNet:OnClientEvent(alias: string, callback: (any) -> ())
    if not RunService:IsClient() then
        error("This method can only be called from the Client context", 2)
    end

    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    local remote = self.Remotes[alias] :: types.Remote
    if not remote then
        error(`RemoteEvent "{alias}" doesn't exist`, 2)
    end

    if remote.Type:lower() ~= "event" then
        error(`"{alias}" is not a RemoteEvent`, 2)
    end

    local remoteEvent = remote.Instance :: RemoteEvent
    local options = remote.Options

    return remoteEvent.OnClientEvent:Connect(function(argumentsBuffer: buffer)
        local serializedArgs = buffer.readstring(argumentsBuffer, 0, buffer.len(argumentsBuffer))

        -- / @ decrypt if applicable
        if options and options.IsEncrypted and options.EncryptionMasterKey then
            local decrypted = encryption:Decrypt(serializedArgs, options.EncryptionMasterKey)
            if not decrypted then
                error("BufferNet: decryption failed", 2)
            end
            serializedArgs = decrypted
        end

        local deserializedArgs = typeSerializers:Deserialize(serializedArgs)
        callback(unpack(deserializedArgs or {}))
    end)
end

--[=[
    @method OnClientInvoke
    Sets the callback for a RemoteFunction on the client side.
    The return value of the callback is sent back to the server.

    @param alias string -- The remote's alias to listen to
    @param callback (any) -> (any) -- Function to call when the function is invoked
]=]
function BufferNet:OnClientInvoke(alias: string, callback: (any) -> (any))
    if not RunService:IsClient() then
        error("This method can only be called from the Client context", 2)
    end

    if not self.Initialized or not self.Communications then
        error("BufferNet hasn't initialized yet", 2)
    end

    local remote = self.Remotes[alias] :: types.Remote
    if not remote then
        error(`RemoteFunction "{alias}" doesn't exist`, 2)
    end

    if remote.Type:lower() ~= "function" then
        error(`"{alias}" is not a RemoteFunction`, 2)
    end

    local remoteFunction = remote.Instance :: RemoteFunction
    local options = remote.Options

    remoteFunction.OnClientInvoke = function(argumentsBuffer: buffer)
        local serializedArgs = buffer.readstring(argumentsBuffer, 0, buffer.len(argumentsBuffer))

        -- / @ decrypt if applicable
        if options and options.IsEncrypted and options.EncryptionMasterKey then
            local decrypted = encryption:Decrypt(serializedArgs, options.EncryptionMasterKey)
            if not decrypted then
                error("BufferNet: decryption failed", 2)
            end
            serializedArgs = decrypted
        end

        local deserializedArgs = typeSerializers:Deserialize(serializedArgs)
        return callback(unpack(deserializedArgs or {}))
    end
end

return BufferNet