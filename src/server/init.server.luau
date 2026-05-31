local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = require(ReplicatedStorage.Shared.BufferNet)

local net = module.new(game:GetService("ReplicatedStorage"))
net:CreateRemote("Event", "Pong")
net:CreateRemote("Event", "Ping", function(player: Player)
    print(`got ping: {player.Name}, sending pong...`)
    warn(net)
    net:FireClient("Pong", player)
end)


net.FinishInitilaztion()