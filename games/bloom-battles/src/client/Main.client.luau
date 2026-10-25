--[[
	+1 Bloom Every Second: Bloom Battles - client entry point.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.BloomShared.Config)
local Net = require(ReplicatedStorage.BloomShared.Net)

local Modules = script.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local Effects = require(Modules.Effects)
require(Modules.Atmosphere)
local Hud = require(Modules.Hud)
require(Modules.DuelUi)

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)

Net.Event("Notify").OnClientEvent:Connect(function(text, color)
	Hud.Toast(text, color)
end)

local function rootOf(p: Player?): BasePart?
	local character = p and p.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function near(pos: Vector3, range: number): boolean
	local mine = rootOf(player)
	return mine ~= nil and (mine.Position - pos).Magnitude <= range
end

local effects = {}

function effects.Milestone(pos, color, extra)
	local who = extra.Player
	local root = rootOf(who)
	local at = if root then root.Position else pos
	local tier = Config.Tiers[extra.Tier]
	if who == player then
		Effects.Burst(at, color, 1.6)
		Effects.Shards(at, { color, WHITE, Color3.fromRGB(255, 226, 160) }, 26, 1.4)
		Effects.Ring(at - Vector3.new(0, 2, 0), color, 36, 1.2)
		Effects.Flash(color, 0.35)
		Effects.Shake(0.35, 0.35)
		Effects.Punch(8)
		Sfx.Melody("Milestone")
		Hud.Banner(tier.Name .. "!", "You blossomed into a new tier", color)
	elseif near(at, 150) then
		Effects.Burst(at, color, 1)
		Effects.Ring(at - Vector3.new(0, 2, 0), color, 24, 1)
		Hud.Toast(who.DisplayName .. " reached " .. tier.Name .. "!", color)
	end
end

function effects.Replant(pos, color, extra)
	local root = rootOf(extra.Player)
	local at = if root then root.Position else pos
	if not near(at, 200) then
		return
	end
	Effects.Burst(at, color, 2)
	Effects.Shards(at, { color, Color3.fromRGB(170, 220, 192), WHITE }, 30, 1.8)
	for i = 0, 2 do
		task.delay(i * 0.18, function()
			Effects.Ring(at - Vector3.new(0, 2, 0), color, 30 + i * 14, 1.2)
		end)
	end
	if extra.Player == player then
		Effects.Flash(color, 0.5)
		Effects.Punch(10)
		Sfx.Melody("Replant")
		Hud.Banner("Replanted!", "A fresh start with a stronger root", color)
	end
end

function effects.DuelStart(pos, color)
	if near(pos, 160) then
		Effects.Ring(pos + Vector3.new(0, 1.5, 0), color, 40, 1)
		Effects.Burst(pos + Vector3.new(0, 3, 0), color, 0.8)
	end
end

function effects.DuelWin(pos, color, extra)
	if near(pos, 160) then
		Effects.Burst(pos, color, 1.4)
		Effects.Shards(pos, { color, WHITE, Color3.fromRGB(255, 226, 160) }, 20, 1.2)
		Effects.Confetti(pos, { color, Color3.fromRGB(255, 226, 160), Color3.fromRGB(170, 220, 192), Color3.fromRGB(200, 184, 236) })
	end
end

function effects.Poof(pos, color)
	if near(pos, 160) then
		Effects.Burst(pos, color, 0.9)
		Effects.Shards(pos, { color, WHITE }, 10, 0.8)
	end
end

Net.Event("Effect").OnClientEvent:Connect(function(kind, pos, color, extra)
	local fn = effects[kind]
	if fn then
		fn(pos, color, extra or {})
	end
end)
