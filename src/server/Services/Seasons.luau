--[[
	Weekly seasons (rules in Shared.Season).

	- Season Points are added from Economy.AwardCrystal (base Essence, no paid boosts).
	- Scores go to one OrderedDataStore per week; the hub board and Season panel show the top.
	- When a player joins after a season ended, their final rank is looked up and the reward
	  for their tier is granted once (title, creature, Trophies).
	- Each player's best title floats above their head.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Season = require(Shared.Season)
local Creatures = require(Shared.Creatures)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local Seasons = {}

local notify = Remotes.Event("Notify")
local cfg = Config.Season

type Entry = { UserId: number, Name: string, Points: number }

local stores: { [number]: OrderedDataStore | false } = {}
local function storeFor(week: number): OrderedDataStore?
	local cached = stores[week]
	if cached == nil then
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(cfg.StorePrefix .. week)
		end)
		cached = if ok then store else false
		stores[week] = cached
	end
	return cached or nil
end

local nameCache: { [number]: string } = {}
local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "Player"
	return nameCache[userId]
end

-- Top 100 of a week (global if DataStores work, otherwise this server's players)
local topCache: { [number]: { Entries: { Entry }, At: number, Global: boolean } } = {}
local function fetchTop(week: number, maxAge: number): ({ Entry }, boolean)
	local cached = topCache[week]
	if cached and os.clock() - cached.At < maxAge then
		return cached.Entries, cached.Global
	end
	local entries: { Entry } = {}
	local global = false
	local store = storeFor(week)
	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, 100)
		end)
		if ok then
			global = true
			for _, row in pages:GetCurrentPage() do
				local userId = tonumber(row.key) or 0
				table.insert(entries, { UserId = userId, Name = nameFor(userId), Points = row.value })
			end
		end
	end
	if not global then
		for _, player in Players:GetPlayers() do
			local data = PlayerData.Get(player) :: any
			if data and data.Season and data.Season.Week == week and data.Season.Points > 0 then
				table.insert(
					entries,
					{ UserId = player.UserId, Name = player.DisplayName, Points = data.Season.Points }
				)
			end
		end
		table.sort(entries, function(a, b)
			return a.Points > b.Points
		end)
	end
	topCache[week] = { Entries = entries, At = os.clock(), Global = global }
	return entries, global
end

local function seasonState(data: any)
	local week = Season.Week()
	if data.Season.Week ~= week then
		data.Season.Week = week
		data.Season.Points = 0
	end
	return data.Season
end

function Seasons.AddPoints(player: Player, points: number)
	local data = PlayerData.Get(player) :: any
	if not data or not data.Season or points <= 0 then
		return
	end
	local state = seasonState(data)
	state.Points += points
end

-- Overhead title tag -------------------------------------------------------------------
local function applyTitle(player: Player)
	local data = PlayerData.Get(player) :: any
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local tag = head:FindFirstChild("TitleTag") :: BillboardGui?
	if data.Title == "" or data.Title == nil then
		if tag then
			tag:Destroy()
		end
		return
	end
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "TitleTag"
		gui.Size = UDim2.fromOffset(220, 26)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		gui.Parent = head
		tag = gui
	end
	local label = (tag :: BillboardGui):FindFirstChild("Text") :: TextLabel
	label.Text = `👑 {data.Title}`
	label.TextColor3 = Season.TitleColor(data.Title)
end

-- Rewards -------------------------------------------------------------------------------
function Seasons.GrantReward(player: Player, rank: number, week: number): boolean
	local data = PlayerData.Get(player) :: any
	local tier = Season.TierFor(rank)
	if not data or not tier then
		return false
	end
	local title = `S{Season.Number(week)} {tier.Title}`
	if not table.find(data.Titles, title) then
		table.insert(data.Titles, title)
	end
	if data.Title == "" or Season.TitleRank(title) <= Season.TitleRank(data.Title) then
		data.Title = title
	end
	data.Trophies += tier.Trophies
	local extra = ""
	if tier.Creature and Creatures.Get(tier.Creature.Id) then
		PlayerData.NewCreature(data, tier.Creature.Id, tier.Creature.Variant)
		data.Bestiary[tier.Creature.Id] = true
		extra = ` + {Creatures.DisplayName(tier.Creature.Id, tier.Creature.Variant)}`
	end
	PlayerData.MarkChanged(player)
	applyTitle(player)
	notify:FireClient(
		player,
		`Season {Season.Number(week)} over: you finished #{rank}! "{tier.Title}" + {tier.Trophies} Trophies{extra}`,
		tier.Color
	)
	return true
end

-- On join: reward last week's finish once
local function checkReward(player: Player)
	local data = PlayerData.Get(player) :: any
	if not data or not data.Season then
		return
	end
	local lastWeek = Season.Week() - 1
	if data.Season.RewardedWeek >= lastWeek then
		return
	end
	local playedLastWeek = data.Season.Week == lastWeek and data.Season.Points > 0
	if not playedLastWeek then
		data.Season.RewardedWeek = lastWeek
		PlayerData.MarkChanged(player)
		return
	end
	local entries, global = fetchTop(lastWeek, 600)
	if not global then
		return -- can't know the real global rank (Studio / DataStore outage): try again next join
	end
	-- only marked as rewarded once the real ranking was read, so an outage can't lose a reward
	data.Season.RewardedWeek = lastWeek
	PlayerData.MarkChanged(player)
	for rank, entry in entries do
		if entry.UserId == player.UserId then
			Seasons.GrantReward(player, rank, lastWeek)
			return
		end
	end
end

-- Admin test: end the season now using this server's ranking
function Seasons.EndNowForTesting(): number
	local week = Season.Week()
	local list = {}
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player) :: any
		if data and data.Season then
			table.insert(list, { Player = player, Points = seasonState(data).Points })
		end
	end
	table.sort(list, function(a, b)
		return a.Points > b.Points
	end)
	for rank, entry in list do
		Seasons.GrantReward(entry.Player, rank, week)
	end
	return #list
end

-- Snapshot / boards -------------------------------------------------------------------------
function Seasons.Snapshot(player: Player, data: any)
	if not data.Season then
		return nil
	end
	local state = seasonState(data)
	local week = state.Week
	-- cached only (refreshed in the background) so building a snapshot never waits
	local cached = topCache[week]
	local entries = if cached then cached.Entries else {}
	local top = {}
	local rank = nil
	for i, entry in entries do
		if i <= cfg.BoardSize then
			table.insert(top, { Name = entry.Name, Points = entry.Points })
		end
		if entry.UserId == player.UserId then
			rank = i
		end
	end
	return {
		Number = Season.Number(week),
		EndsAt = Season.EndsAt(week),
		Points = state.Points,
		Rank = rank,
		Top = top,
		Title = data.Title,
		Titles = data.Titles,
	}
end

function Seasons.BoardRows(): { { Name: string, Points: number } }
	local rows = {}
	for i, entry in fetchTop(Season.Week(), 60) do
		if i > cfg.BoardSize then
			break
		end
		table.insert(rows, { Name = entry.Name, Points = entry.Points })
	end
	return rows
end

function Seasons.EquipTitle(player: Player, title: string): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data then
		return false
	end
	if title ~= "" and not table.find(data.Titles, title) then
		return false, "You don't have that title"
	end
	data.Title = title
	PlayerData.MarkChanged(player)
	applyTitle(player)
	return true
end

-- Writes one player's score now (used when they leave, so their last points aren't lost)
local function pushScore(player: Player)
	local data = PlayerData.Get(player) :: any
	local week = Season.Week()
	local store = storeFor(week)
	if store and data and data.Season and data.Season.Week == week and data.Season.Points > 0 then
		pcall(store.SetAsync, store, tostring(player.UserId), math.floor(data.Season.Points))
	end
end

local function pushScores()
	local week = Season.Week()
	local store = storeFor(week)
	if not store then
		return
	end
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player) :: any
		if data and data.Season and data.Season.Week == week and data.Season.Points > 0 then
			pcall(store.SetAsync, store, tostring(player.UserId), math.floor(data.Season.Points))
		end
	end
	topCache[week] = nil
end

function Seasons.Start()
	PlayerData.OnLeaving(pushScore)
	PlayerData.Loaded:Connect(function(player)
		task.spawn(checkReward, player)
		applyTitle(player)
	end)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			applyTitle(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	task.spawn(function()
		while true do
			task.wait(Config.Leaderboards.RefreshInterval)
			pushScores()
		end
	end)
	task.spawn(function()
		while true do
			fetchTop(Season.Week(), 0)
			task.wait(60)
		end
	end)
	game:BindToClose(pushScores)
end

return Seasons
