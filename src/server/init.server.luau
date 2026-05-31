local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = require(ReplicatedStorage.Shared.BufferNet)
local net = module.new(game:GetService("ReplicatedStorage"))

local myNewPart = Instance.new("Part")
myNewPart.Anchored = true
myNewPart.Parent = workspace
myNewPart.Name = "ReplicationPart"

net:CreateRemote("Unreliable", "Replication", function(a0: Player, cframe: CFrame)
    warn(cframe)
end)

net.FinishInitilaztion()