--!nonstrict
task.wait(3)
warn("tung tung hook .ccc")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = require(ReplicatedStorage.Shared.BufferNet)
local net = module.new()
local char = Players.LocalPlayer.Character
local humanoid = char:WaitForChild("Humanoid")

while true do
    net:FireServerUnreliable("Replication", {humanoid.RootPart.CFrame})
    print("ok garmin save video")

    task.wait()
end
