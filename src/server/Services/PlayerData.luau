--[[
	Loads, caches and saves player data.

	- Retries DataStore calls, and refuses to save over data it failed to load.
	- In Studio without API access, data simply isn't saved (you get a warning).
	- Other services call PlayerData.MarkChanged(player) after editing data; changes are
	  batched and sent to the client a few times per second.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerData = {}

export type CreatureEntry = { Id: string, Variant: string, Equipped: boolean }

export type Data = {
	Version: number,
	Essence: number,
	TotalEssence: number,
	Trophies: number,
	Rebirths: number,
	ZonesUnlocked: number,
	Creatures: { [string]: CreatureEntry },
	NextUid: number,
	Bestiary: { [string]: boolean },
	Boosts: { [string]: number }, -- boost name -> unix time it ends
	AutoCollectEnabled: boolean,
	House: string?,
	HouseJoinedWeek: number,
	HouseContribution: { Week: number, Points: number, House: string? },
	HouseRewardedWeek: number,
	Merchant: { Slot: number, Bought: { [string]: number } },
	LastOnline: number,
	ProcessedReceipts: { string },
	Stats: { CreaturesHatched: number, SurgeWins: number, CrystalsBroken: number },
	Daily: { Streak: number, LastClaimDay: number },
	Season: { Week: number, Points: number, RewardedWeek: number },
	Titles: { string },
	Title: string,
	Quests: { Day: number, Progress: { [string]: number }, Claimed: { [string]: boolean }, BonusClaimed: boolean },
}

local function defaultData(): Data
	return {
		Version = 1,
		Essence = 0,
		TotalEssence = 0,
		Trophies = 0,
		Rebirths = 0,
		ZonesUnlocked = 1,
		Creatures = {},
		NextUid = 1,
		Bestiary = {},
		Boosts = {},
		AutoCollectEnabled = true,
		House = nil,
		HouseJoinedWeek = -1,
		HouseContribution = { Week = -1, Points = 0 },
		HouseRewardedWeek = -1,
		Merchant = { Slot = -1, Bought = {} },
		LastOnline = 0,
		ProcessedReceipts = {},
		Stats = { CreaturesHatched = 0, SurgeWins = 0, CrystalsBroken = 0 },
		Daily = { Streak = 0, LastClaimDay = -1 },
		Season = { Week = -1, Points = 0, RewardedWeek = -1 },
		Titles = {},
		Title = "",
		Quests = { Day = -1, Progress = {}, Claimed = {}, BonusClaimed = false },
	}
end

-- Fills in any fields added in later updates, so old saves keep working.
local function reconcile(data: any, template: any)
	for key, value in template do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
end

type Profile = { Data: Data, CanSave: boolean, Dirty: boolean }

local profiles: { [Player]: Profile } = {}
local loadedEvent = Instance.new("BindableEvent")
local changedEvent = Instance.new("BindableEvent")

PlayerData.Loaded = loadedEvent.Event -- (player, data)
PlayerData.Changed = changedEvent.Event -- (player) fired when a batched change is flushed

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStores unavailable - data will not save:", result)
	end
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function retry<T>(attempts: number, fn: () -> T): (boolean, T | string)
	local lastErr
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt)
	end
	return false, lastErr
end

function PlayerData.Get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Yields until the player's data is loaded (or they leave). Used by remotes.
function PlayerData.WaitFor(player: Player, timeout: number?): Data?
	local deadline = os.clock() + (timeout or 15)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return PlayerData.Get(player)
end

function PlayerData.MarkChanged(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
	end
end

function PlayerData.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return false
	end
	profile.Data.LastOnline = os.time()
	local snapshot = profile.Data
	local ok, err = retry(3, function()
		return (store :: DataStore):UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end)
	if not ok then
		warn(`[PlayerData] Failed to save {player.Name}: {err}`)
	end
	return ok
end

local function load(player: Player)
	local data: Data
	local canSave = store ~= nil
	if store then
		local ok, result = retry(3, function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			data = if type(result) == "table" then result else defaultData()
		elseif RunService:IsStudio() then
			warn("[PlayerData] Could not load data in Studio (enable API access to save). Using fresh data.")
			data = defaultData()
			canSave = false
		else
			-- Never let someone play on fresh data that would overwrite their real save.
			player:Kick("We couldn't load your data. Please rejoin in a moment!")
			return
		end
	else
		data = defaultData()
	end
	reconcile(data, defaultData())
	if not player.Parent then
		return
	end
	profiles[player] = { Data = data, CanSave = canSave, Dirty = true }
	loadedEvent:Fire(player, data)
end

Players.PlayerAdded:Connect(load)
for _, player in Players:GetPlayers() do
	task.spawn(load, player)
end

-- Other services that need to run cleanup before the final save hook in here.
local leavingCallbacks: { (Player) -> () } = {}
function PlayerData.OnLeaving(callback: (Player) -> ())
	table.insert(leavingCallbacks, callback)
end

Players.PlayerRemoving:Connect(function(player)
	if not profiles[player] then
		return
	end
	for _, callback in leavingCallbacks do
		pcall(callback, player)
	end
	PlayerData.Save(player)
	profiles[player] = nil
end)

game:BindToClose(function()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			for _, callback in leavingCallbacks do
				pcall(callback, player)
			end
			PlayerData.Save(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.2)
	end
end)

-- Autosave loop
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for player in profiles do
			task.spawn(PlayerData.Save, player)
		end
	end
end)

-- Flush batched changes ~6 times a second
task.spawn(function()
	while true do
		task.wait(0.15)
		for player, profile in profiles do
			if profile.Dirty then
				profile.Dirty = false
				changedEvent:Fire(player)
			end
		end
	end
end)

-- Receipt bookkeeping for developer products (prevents double-granting)
function PlayerData.HasReceipt(player: Player, purchaseId: string): boolean
	local data = PlayerData.Get(player)
	return data ~= nil and table.find(data.ProcessedReceipts, purchaseId) ~= nil
end

function PlayerData.AddReceipt(player: Player, purchaseId: string)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	table.insert(data.ProcessedReceipts, purchaseId)
	while #data.ProcessedReceipts > Config.MaxReceiptHistory do
		table.remove(data.ProcessedReceipts, 1)
	end
end

function PlayerData.NewCreature(data: Data, id: string, variant: string): string
	local uid = tostring(data.NextUid)
	data.NextUid += 1
	data.Creatures[uid] = { Id = id, Variant = variant, Equipped = false }
	return uid
end

function PlayerData.CountCreatures(data: Data): (number, number)
	local total, equipped = 0, 0
	for _, entry in data.Creatures do
		total += 1
		if entry.Equipped then
			equipped += 1
		end
	end
	return total, equipped
end

return PlayerData
