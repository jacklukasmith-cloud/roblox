--[[
	Mana Surge - the server-wide competitive round.

	Every few minutes a 90 second surge starts. Everyone earns double Essence, and
	"surge score" is tracked for each player. Paid boosts do NOT count toward score, so the
	competition stays fair: score = base crystal reward * rebirth multiplier.
	Top 3 win Trophies + points for their House; everyone who took part gets a Trophy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local HouseWar = require(script.Parent.HouseWar)

local Surge = {}

local active = false
local endsAt = 0
local scores: { [Player]: number } = {}
local skipWait = false

local surgeUpdate = Remotes.Event("SurgeUpdate")
local notify = Remotes.Event("Notify")

function Surge.IsActive(): boolean
	return active
end

function Surge.AddScore(player: Player, amount: number)
	if active and amount > 0 then
		scores[player] = (scores[player] or 0) + amount
	end
end

function Surge.GetState(): (boolean, number)
	return active, endsAt
end

-- Admin command: start the next surge right away.
function Surge.StartNow()
	skipWait = true
end

local function ranking(): { { Player: Player, Score: number } }
	local list = {}
	for player, score in scores do
		if player.Parent and score > 0 then
			table.insert(list, { Player = player, Score = score })
		end
	end
	table.sort(list, function(a, b)
		return a.Score > b.Score
	end)
	return list
end

local function broadcast()
	local list = ranking()
	local top = {}
	for i = 1, math.min(5, #list) do
		table.insert(
			top,
			{ Name = list[i].Player.DisplayName, Score = list[i].Score, House = list[i].Player:GetAttribute("House") }
		)
	end
	local rankOf = {}
	for i, entry in list do
		rankOf[entry.Player] = i
	end
	for _, player in Players:GetPlayers() do
		surgeUpdate:FireClient(player, {
			Active = active,
			EndsAt = endsAt,
			Top = top,
			MyScore = scores[player] or 0,
			MyRank = rankOf[player],
		})
	end
end

local function finish()
	local list = ranking()
	for i, entry in list do
		local player = entry.Player
		local data = PlayerData.Get(player)
		if data then
			local trophies = Config.Surge.TrophyRewards[i] or Config.Surge.ParticipationTrophies
			data.Trophies += trophies
			if i == 1 then
				data.Stats.SurgeWins += 1
			end
			HouseWar.AddPoints(player, Config.Surge.HousePointRewards[i] or 1)
			PlayerData.MarkChanged(player)
			local place = if i <= 3 then ({ "1st", "2nd", "3rd" })[i] .. " place! " else ""
			notify:FireClient(player, `Mana Surge over! {place}+{trophies} Trophies`, Color3.fromRGB(0, 255, 225))
		end
	end
	if list[1] then
		local winner = list[1]
		for _, player in Players:GetPlayers() do
			if player ~= winner.Player then
				notify:FireClient(
					player,
					`{winner.Player.DisplayName} won the Mana Surge with {Format.Number(winner.Score)} points!`,
					Color3.fromRGB(255, 215, 80)
				)
			end
		end
	end
end

task.spawn(function()
	while true do
		active = false
		endsAt = os.time() + Config.Surge.Interval
		skipWait = false
		while os.time() < endsAt and not skipWait do
			pcall(broadcast)
			task.wait(1)
		end
		if #Players:GetPlayers() == 0 then
			continue
		end
		scores = {}
		active = true
		endsAt = os.time() + Config.Surge.Duration
		for _, player in Players:GetPlayers() do
			notify:FireClient(player, "MANA SURGE! Double Essence - top 3 win Trophies!", Color3.fromRGB(190, 120, 255))
		end
		while os.time() < endsAt do
			pcall(broadcast)
			task.wait(1)
		end
		active = false
		-- a failure while paying out must not stop every future surge
		local ok, err = pcall(finish)
		if not ok then
			warn("[Surge] " .. tostring(err))
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	scores[player] = nil
end)

return Surge
