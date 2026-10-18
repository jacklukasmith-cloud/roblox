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

export type CreatureEntry = { Id: string, Variant: string, Equipped: boolean, Level: number?, XP: number? }

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
	Stats: {
		CreaturesHatched: number,
		SurgeWins: number,
		CrystalsBroken: number,
		HatchMilestones: number,
		PickaxeHits: number,
		Fusions: number,
		BossesDefeated: number,
		TreasuresFound: number,
		ItemsUsed: number,
		SanctuaryVisits: number,
		CodesRedeemed: number,
		BoardsViewed: number,
		GloomwoodVisits: number,
		GloomMined: number,
		GloomBanked: number,
		BeastsDefeated: number,
		PotionsBrewed: number,
		GloomRare: number,
		Prismhearts: number,
		MapFragments: number,
		VehiclesBuilt: number,
	},
	Items: { [string]: number }, -- the Bag (Shared/Items): item id -> count
	RedeemedCodes: { [string]: boolean }, -- codes already used (Services/Codes)
	TradeLog: { any }, -- last 20 trades (Services/Trading)
	Sanctuary: { Level: number, Habitat: { string }, HabitatAt: number }, -- your island (Shared/Sanctuary, Services/Sanctuaries); Habitat = creature uids, HabitatAt = last XP time
	WeekStats: { Week: number, Base: { [string]: number } }?, -- totals at the start of the week (weekly leaderboards)
	Missions: { Index: number, Baseline: number?, Id: string?, V: number? }, -- place in the mission chain (Shared/Missions)
	Gloom: { Satchel: { [string]: number }, Vault: { [string]: number }, CampFound: boolean, Map: { [number]: boolean } }, -- the Gloomwood (Shared/Gloomwood): crystals carried, crystals in your island's Vault
	Vehicles: { Owned: { [string]: boolean }, Skin: string, LastRidden: string? }, -- the Hangar (Shared/Vehicles)
	Cauldron: { Brews: { { Recipe: string, StartedAt: number, DoneAt: number } } }, -- the Alchemy Cauldron (Shared/Alchemy)
	SeenUpdate: number, -- the last "What's New" the player has seen (Shared/WhatsNew)
	Daily: { Streak: number, LastClaimDay: number },
	Season: { Week: number, Points: number, RewardedWeek: number },
	Titles: { string },
	Title: string,
	Pickaxe: number, -- pickaxe tier (Config.Pickaxe.Tiers)
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
		Stats = {
			CreaturesHatched = 0,
			SurgeWins = 0,
			CrystalsBroken = 0,
			HatchMilestones = 0,
			PickaxeHits = 0,
			Fusions = 0,
			BossesDefeated = 0,
			TreasuresFound = 0,
			ItemsUsed = 0,
			SanctuaryVisits = 0,
			CodesRedeemed = 0,
			BoardsViewed = 0,
			GloomwoodVisits = 0,
			GloomMined = 0,
			GloomBanked = 0,
			BeastsDefeated = 0,
			PotionsBrewed = 0,
			GloomRare = 0,
			Prismhearts = 0,
			MapFragments = 0,
			VehiclesBuilt = 0,
		},
		Items = {},
		RedeemedCodes = {},
		TradeLog = {},
		Sanctuary = { Level = 1, Habitat = {}, HabitatAt = 0 },
		Missions = { Index = 1 },
		SeenUpdate = 0,
		Gloom = { Satchel = {}, Vault = {}, CampFound = false, Map = {} },
		Cauldron = { Brews = {} },
		Vehicles = { Owned = {}, Skin = "Default" },
		Daily = { Streak = 0, LastClaimDay = -1 },
		Season = { Week = -1, Points = 0, RewardedWeek = -1 },
		Titles = {},
		Title = "",
		Pickaxe = 1,
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

type Profile = { Data: Data, CanSave: boolean, Dirty: boolean, Leaving: boolean? }

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

--[[
	Session lock: the save holds { JobId, Time } of the server that's using it. Another server
	won't load it while it's held (it waits for the final save, which releases it), and a server
	never overwrites a save another server has taken over. A lock older than SESSION_STALE (a
	crashed server) is ignored.
]]
local SESSION_STALE = Config.AutosaveInterval * 2.5
local LOCK_WAIT_TRIES, LOCK_WAIT_SECONDS = 10, 2

local function lockedElsewhere(record: any): boolean
	local session = type(record) == "table" and record._Session
	return type(session) == "table"
		and session.JobId ~= game.JobId
		and os.time() - (tonumber(session.Time) or 0) < SESSION_STALE
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

-- Wipes a player's progress back to a brand-new save (keeps the purchase receipts so Robux
-- products are never granted twice). Changes the table in place so nothing holds a stale copy.
function PlayerData.Reset(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local data = profile.Data :: any
	local receipts = data.ProcessedReceipts
	for key in data do
		data[key] = nil
	end
	for key, value in defaultData() :: any do
		data[key] = value
	end
	data.ProcessedReceipts = receipts or {}
	profile.Dirty = true
	return true
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
	local snapshot = profile.Data :: any
	local release = profile.Leaving == true
	local takenOver = false
	local ok, err = retry(3, function()
		return (store :: DataStore):UpdateAsync(keyFor(player), function(old)
			if lockedElsewhere(old) then
				takenOver = true
				return nil -- another server owns this save now: never overwrite it
			end
			snapshot._Session = if release then nil else { JobId = game.JobId, Time = os.time() }
			return snapshot
		end)
	end)
	if not ok then
		warn(`[PlayerData] Failed to save {player.Name}: {err}`)
	elseif takenOver then
		warn(`[PlayerData] {player.Name}'s save is in use by another server; not overwriting it`)
		return false
	end
	return ok
end

local function load(player: Player)
	local data: Data
	local canSave = store ~= nil
	if store then
		-- claim the save (session lock); if another server still has it (the player just
		-- hopped servers), wait for its final save, then take over
		local ok, result
		for attempt = 1, LOCK_WAIT_TRIES + 1 do
			local locked = false
			local force = attempt > LOCK_WAIT_TRIES
			ok, result = retry(3, function()
				return (store :: DataStore):UpdateAsync(keyFor(player), function(old)
					if not force and lockedElsewhere(old) then
						locked = true
						return nil
					end
					local record = if type(old) == "table" then old else {}
					record._Session = { JobId = game.JobId, Time = os.time() }
					return record
				end)
			end)
			if not ok or not locked or not player.Parent then
				break
			end
			task.wait(LOCK_WAIT_SECONDS)
		end
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

-- Final save, exactly once per player (leaving and server shutdown can both ask for it;
-- saving the same key twice in a row only queues the second request)
local function finalSave(player: Player)
	local profile = profiles[player]
	if not profile or profile.Leaving then
		return
	end
	profile.Leaving = true
	for _, callback in leavingCallbacks do
		pcall(callback, player)
	end
	PlayerData.Save(player)
	profiles[player] = nil
end

Players.PlayerRemoving:Connect(finalSave)

game:BindToClose(function()
	for player in profiles do
		task.spawn(finalSave, player)
	end
	-- wait for every final save (including ones PlayerRemoving already started)
	local deadline = os.clock() + 25
	while next(profiles) ~= nil and os.clock() < deadline do
		task.wait(0.2)
	end
end)

-- Autosave loop
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for player, profile in profiles do
			if not profile.Leaving then -- their final save is already running
				task.spawn(PlayerData.Save, player)
			end
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
