--[[
	Friend Boost: +5% Essence for each Roblox friend in the same server (up to 3, so +15%;
	see Config.FriendBoost). Gives players a reason to bring friends along. When a friend joins,
	both of you get a message.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)

local FriendBoost = {}

local cfg = Config.FriendBoost
local notify = Remotes.Event("Notify")
local counts: { [Player]: number } = {}
local friendCache: { [string]: boolean } = {}

local function pairKey(a: Player, b: Player): string
	local x, y = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	return `{x}:{y}`
end

local function areFriends(a: Player, b: Player): boolean
	local key = pairKey(a, b)
	local cached = friendCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
	local friends = ok and result == true
	if ok then
		friendCache[key] = friends -- only cache real answers, so a failed check is tried again
	end
	return friends
end

-- How many friends count towards the boost (capped)
function FriendBoost.Count(player: Player): number
	return math.min(counts[player] or 0, cfg.MaxFriends)
end

-- The Essence multiplier from friends (1 = none)
function FriendBoost.Multiplier(player: Player): number
	return 1 + FriendBoost.Count(player) * cfg.PerFriend
end

local function recount(player: Player)
	if not player.Parent then
		return
	end
	local n = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and areFriends(player, other) then
			n += 1
		end
	end
	if counts[player] ~= n then
		counts[player] = n
		PlayerData.MarkChanged(player)
	end
end

local function percent(player: Player): string
	return `{math.floor(FriendBoost.Count(player) * cfg.PerFriend * 100 + 0.5)}%`
end

function FriendBoost.Start()
	Players.PlayerAdded:Connect(function(joiner)
		task.wait(2) -- let them load in first
		if not joiner.Parent then
			return
		end
		recount(joiner)
		for _, other in Players:GetPlayers() do
			if other ~= joiner and areFriends(joiner, other) then
				recount(other)
				notify:FireClient(
					other,
					`👥 {joiner.DisplayName} joined! Friend Boost: +{percent(other)} Essence`,
					Color3.fromRGB(120, 220, 255)
				)
			end
		end
		if FriendBoost.Count(joiner) > 0 then
			notify:FireClient(
				joiner,
				`👥 Playing with friends! Friend Boost: +{percent(joiner)} Essence`,
				Color3.fromRGB(120, 220, 255)
			)
		end
	end)
	Players.PlayerRemoving:Connect(function(leaver)
		counts[leaver] = nil
		for _, other in Players:GetPlayers() do
			if other ~= leaver then
				task.spawn(recount, other)
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(recount, player)
	end
end

return FriendBoost
