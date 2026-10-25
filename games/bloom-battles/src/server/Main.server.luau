--[[
	+1 Bloom Every Second: Bloom Battles - server entry point.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.BloomShared.Net)

local Services = script.Parent.Services
local Data = require(Services.Data)
local Growth = require(Services.Growth)
local World = require(Services.World)
local Duels = require(Services.Duels)

local arenas = World.Build()
Data.Start()
Growth.Start()
Duels.Start(arenas)

local notify = Net.Event("Notify")

local replantCooldown = {}
Net.Function("Replant").OnServerInvoke = function(player)
	local now = os.clock()
	if replantCooldown[player] and now - replantCooldown[player] < 1 then
		return false, "Slow down a little!"
	end
	replantCooldown[player] = now
	if player:GetAttribute("InDuel") then
		return false, "Finish your Bloom Battle first."
	end
	return Growth.Replant(player)
end

local function onPlayerAdded(player: Player)
	Data.Load(player)
	if player.Parent == nil then
		Data.Release(player) -- left while loading
		return
	end
	Growth.PlayerAdded(player)
	notify:FireClient(player, "Welcome! You grow +1 Bloom every second. Stand on a battle pad to duel!")
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	replantCooldown[player] = nil
end)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
