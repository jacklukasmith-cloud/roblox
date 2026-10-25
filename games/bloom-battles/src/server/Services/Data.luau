--[[
	Loads and saves player data. Live values are mirrored onto player attributes
	(Bloom, BestBloom, Rebirths, Wins, Zones) so the client can read them directly.

	In Studio without "Enable Studio Access to API Services" data is not saved.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.BloomShared.Config)
local Util = require(ReplicatedStorage.BloomShared.Util)

local Data = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[BloomBattles] DataStores unavailable, progress will not save:", result)
	end
end

local profiles = {} -- [Player] = { data = {...}, loaded = bool }

local function defaults()
	return { Bloom = 0, BestBloom = 0, Rebirths = 0, Wins = 0, Zones = 1, Version = 1 }
end

local function retry(fn)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < 3 then
			task.wait(attempt)
		else
			return false, result
		end
	end
	return false, nil
end

local function makeLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local bloom = Instance.new("StringValue")
	bloom.Name = "Bloom"
	bloom.Parent = stats
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = stats
	local replants = Instance.new("IntValue")
	replants.Name = "Replants"
	replants.Parent = stats
	stats.Parent = player
end

function Data.Get(player: Player)
	local p = profiles[player]
	return p and p.data
end

-- Copies data onto attributes + leaderstats. Call after any change.
function Data.Sync(player: Player)
	local d = Data.Get(player)
	if not d then
		return
	end
	if d.Bloom > d.BestBloom then
		d.BestBloom = d.Bloom
	end
	player:SetAttribute("Bloom", d.Bloom)
	player:SetAttribute("BestBloom", d.BestBloom)
	player:SetAttribute("Rebirths", d.Rebirths)
	player:SetAttribute("Wins", d.Wins)
	player:SetAttribute("Zones", d.Zones)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Bloom.Value = Util.Format(d.Bloom)
		stats.Wins.Value = d.Wins
		stats.Replants.Value = d.Rebirths
	end
end

function Data.Load(player: Player)
	makeLeaderstats(player)
	local data = defaults()
	local loaded = store == nil -- nothing to protect if there is no store
	if store then
		local ok, saved = retry(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if ok then
			loaded = true
			if type(saved) == "table" then
				for k, v in saved do
					data[k] = v
				end
			end
		else
			warn("[BloomBattles] Could not load data for", player.Name, "- this session will not save.")
		end
	end
	profiles[player] = { data = data, loaded = loaded and store ~= nil }
	Data.Sync(player)
	return data
end

function Data.Save(player: Player)
	local p = profiles[player]
	if not (p and p.loaded and store) then
		return
	end
	local copy = table.clone(p.data)
	retry(function()
		store:SetAsync("p_" .. player.UserId, copy)
	end)
end

function Data.Release(player: Player)
	Data.Save(player)
	profiles[player] = nil
end

function Data.Start()
	Players.PlayerRemoving:Connect(Data.Release)
	game:BindToClose(function()
		local threads = {}
		for _, player in Players:GetPlayers() do
			table.insert(threads, task.spawn(Data.Save, player))
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(Data.Save, player)
			end
		end
	end)
end

return Data
