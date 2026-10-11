--[[
	Global leaderboards (OrderedDataStore) + the in-world boards in the hub:
	Top Trophies, Top Essence, House War standings and the Mana Surge obelisk.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Houses = require(Shared.Houses)
local PlayerData = require(script.Parent.PlayerData)
local HouseWar = require(script.Parent.HouseWar)
local Surge = require(script.Parent.Surge)

local Leaderboards = {}

local cfg = Config.Leaderboards
local trophyStore: OrderedDataStore? = nil
local essenceStore: OrderedDataStore? = nil
pcall(function()
	trophyStore = DataStoreService:GetOrderedDataStore(cfg.TrophiesStore)
	essenceStore = DataStoreService:GetOrderedDataStore(cfg.EssenceStore)
end)

local nameCache: { [number]: string } = {}
local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "Player"
	return nameCache[userId]
end

type Row = { Name: string, Value: string, Color: Color3? }

-- Renders rows into a board built by WorldBuilder (SurfaceGui > List with Row1..RowN labels)
local function render(boardName: string, rows: { Row })
	local board = workspace:FindFirstChild("World")
		and workspace.World:FindFirstChild("Hub")
		and workspace.World.Hub:FindFirstChild(boardName)
	local gui = board and board:FindFirstChild("Board")
	local list = gui and gui:FindFirstChild("List")
	if not list then
		return
	end
	for i = 1, cfg.Size do
		local label = list:FindFirstChild("Row" .. i) :: TextLabel?
		if label then
			local row = rows[i]
			label.Text = if row then `#{i}  {row.Name}  -  {row.Value}` else ""
			label.TextColor3 = if row and row.Color then row.Color else Color3.new(1, 1, 1)
		end
	end
end

local function fromStore(store: OrderedDataStore?, fallback: (PlayerData.Data) -> number): { Row }
	local rows = {}
	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, cfg.Size)
		end)
		if ok then
			for _, entry in pages:GetCurrentPage() do
				table.insert(rows, { Name = nameFor(tonumber(entry.key) or 0), Value = Format.Number(entry.value) })
			end
			return rows
		end
	end
	-- Studio / outage fallback: show players in this server
	local list = {}
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data then
			table.insert(list, { Name = player.DisplayName, Raw = fallback(data) })
		end
	end
	table.sort(list, function(a, b)
		return a.Raw > b.Raw
	end)
	for _, item in list do
		table.insert(rows, { Name = item.Name, Value = Format.Number(item.Raw) })
	end
	return rows
end

local function pushScores()
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data then
			local key = tostring(player.UserId)
			if trophyStore then
				pcall(trophyStore.SetAsync, trophyStore, key, math.floor(data.Trophies))
			end
			if essenceStore then
				pcall(essenceStore.SetAsync, essenceStore, key, math.floor(math.min(data.TotalEssence, 2 ^ 53)))
			end
		end
	end
end

local function refreshGlobal()
	pushScores()
	render(
		"TrophyBoard",
		fromStore(trophyStore, function(d)
			return d.Trophies
		end)
	)
	render(
		"EssenceBoard",
		fromStore(essenceStore, function(d)
			return d.TotalEssence
		end)
	)
end

local function refreshHouses()
	local standings = HouseWar.GetStandings()
	local list = {}
	for _, id in Houses.Order do
		table.insert(list, { Id = id, Points = standings[id] or 0 })
	end
	table.sort(list, function(a, b)
		return a.Points > b.Points
	end)
	local rows = {}
	for _, item in list do
		local house = Houses.List[item.Id]
		table.insert(rows, { Name = house.Name, Value = Format.Number(item.Points) .. " pts", Color = house.Color })
	end
	table.insert(rows, { Name = "Week ends in", Value = Format.Time(HouseWar.WeekEndsAt() - os.time()) })
	render("HouseBoard", rows)
end

local function refreshObelisk()
	local obelisk = workspace:FindFirstChild("World") and workspace.World.Hub:FindFirstChild("SurgeObelisk")
	local gui = obelisk and obelisk:FindFirstChild("SurgeGui")
	local label = gui and gui:FindFirstChild("Text") :: TextLabel?
	if not label then
		return
	end
	local active, endsAt = Surge.GetState()
	local left = Format.Time(endsAt - os.time())
	if active then
		label.Text = `MANA SURGE ACTIVE!\n{left} left`
		label.TextColor3 = Color3.fromRGB(220, 150, 255)
	else
		label.Text = `Next Mana Surge\n{left}`
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

function Leaderboards.Start()
	task.spawn(function()
		while true do
			refreshGlobal()
			task.wait(cfg.RefreshInterval)
		end
	end)
	task.spawn(function()
		while true do
			refreshHouses()
			refreshObelisk()
			task.wait(1)
		end
	end)
end

return Leaderboards
