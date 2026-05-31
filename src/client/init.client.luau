task.wait(.5)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = require(ReplicatedStorage.Shared.BufferNet)
warn("oka")
local net = module.new()
-- listen for client event
net:OnClientEvent("Pong", function()
    print("got pong from server")
end)

-- start ts off
net:FireServer("Ping")
print("sent to server")