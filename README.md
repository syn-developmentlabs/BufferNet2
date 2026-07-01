# Reef 3
~~previously BufferNet~~

## Setup

**Server**
```lua
local BufferNet = require(path.to.BufferNet2)
local net = BufferNet.new(game.ReplicatedStorage)

-- create your remotes here...

net.FinishInitilaztion()
```

**Client**
```lua
local BufferNet = require(path.to.BufferNet2)
local net = BufferNet.new() -- yields until the server finishes initialization
```

---

## Creating Remotes (Server)

### CreateRemote - Event
```lua
net:CreateRemote("Event", "PlayerDamaged", function(player: Player, data: buffer)
    print(player.Name, "sent damage data")
end)
```

### CreateRemote - Function
```lua
net:CreateRemote("Function", "GetInventory", function(player: Player, data: buffer)
    return { "Sword", "Shield", "Potion" }
end)
```

### CreateRemote - With Encryption
```lua
net:CreateRemote("Event", "SecureChat", function(player: Player, data: buffer)
    print("Encrypted message received from", player.Name)
end, { IsEncrypted = true })
```

---

## Firing & Invoking from the Client

### FireServer
Fires a RemoteEvent from the client to the server.
```lua
-- send a damage value to the server
net:FireServer("PlayerDamaged", { damage = 25, weapon = "Sword" })
```

### InvokeServer
Calls a RemoteFunction from the client and waits for the server's return value.
```lua
local inventory = net:InvokeServer("GetInventory")
print("My inventory:", inventory)
```

---

## Firing Clients from the Server

### FireClient
Fires a RemoteEvent to one specific player.
```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    net:FireClient("PlayerDamaged", player, { damage = 0, weapon = "None" })
end)
```

### FireAllClients
Fires a RemoteEvent to every connected player.
```lua
net:FireAllClients("PlayerDamaged", { damage = 10, weapon = "Explosion" })
```

### FireAllClientsExcept
Fires a RemoteEvent to all players except the one(s) specified. Accepts a
single `Player` or a `{Player}` array.
```lua
-- exclude a single player
net:FireAllClientsExcept("PlayerDamaged", excludedPlayer, { damage = 10, weapon = "Explosion" })

-- exclude multiple players
net:FireAllClientsExcept("PlayerDamaged", { playerA, playerB }, { damage = 10, weapon = "Explosion" })
```

### FireClients
Fires a RemoteEvent to an explicit list of players.
```lua
local targets = { playerA, playerB, playerC }
net:FireClients("PlayerDamaged", targets, { damage = 50, weapon = "Sniper" })
```

---

## Invoking Clients from the Server

> ! `InvokeClient` and `InvokeAllClients` can **infinitely yield** if a client
> disconnects mid-invocation. Always wrap call sites in a timeout or `pcall`
> in production.

### InvokeClient
Calls a RemoteFunction on a specific player and waits for their return value.
```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    local clientData = net:InvokeClient("GetInventory", player)
    print(player.Name .. "'s inventory:", clientData)
end)
```

### InvokeAllClients
Invokes all connected players concurrently and returns a `{[Player]: any}`
table of their responses. Failed or disconnected players will return `nil`.
```lua
local allStuff = net:InvokeAllClients("getStuff")

for player, stuff in allStuff do
    if stuff then
        print(player.Name, "->", stuff)
    else
        print(player.Name, "didnt respond")
    end
end
```

---

## Listening on the Client

### OnClientEvent
Connects a callback that fires whenever the server sends to this client.
Returns an `RBXScriptConnection` so you can disconnect to avoid mem leaks
```lua
local connection = net:OnClientEvent("getCountry", function(data)
    print("hello", data.name, "from", data.country)
end)

-- disconnect when no longer neede
connection:Disconnect()
```

### OnClientInvoke
Sets the callback the server receives a return value from when it calls
`InvokeClient`. If you for some reason decide to assign it twice, it'll
replace it.
```lua
net:OnClientInvoke("X", function()
    return { "X", "Y", "Z" }
end)

-- unregister later if needed
net:OnClientInvoke("GetInventory", function() end)
```

---

## Encryption

Any remote can be created with `IsEncrypted = true`. The key is generated on
the server and synced to clients automatically via attirbutes.

```lua
-- server
net:CreateRemote("Event", "payload_thing", function(player, data)
    print("Secure data from", player.Name)
end, { IsEncrypted = true })

-- client - FireServer, InvokeServer, OnClientEvent, OnClientInvoke all
-- handle encryption/decryption
net:FireServer("payload_thing", { secret = "hello" })
```
