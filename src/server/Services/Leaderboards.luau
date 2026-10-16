--[[
	Leaderboards: global top lists kept in OrderedDataStores (categories in Shared/Boards: all-time
	Trophies, Essence, Rebirths and Index, plus weekly Crystals and Eggs Hatched), and the hub's
	in-world boards:
	  - TrophyBoard cycles through every category, with statues of the current top 3 trophy
	    holders standing on top of it
	  - EssenceBoard: this week's Season race; HouseBoard: House War; the Mana Surge obelisk
	The 🏆 Leaderboards window asks GetBoard for the top 50 (or your friends) and your own rank.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Houses = require(Shared.Houses)
local Boards = require(Shared.Boards)
local Season = require(Shared.Season)
local PlayerData = require(script.Parent.PlayerData)
local HouseWar = require(script.Parent.HouseWar)
local Surge = require(script.Parent.Surge)
local Seasons = require(script.Parent.Seasons)

local Leaderboards = {}

local cfg = Config.Leaderboards
local TOP = 50 -- rows kept per board
local FRIENDS_MAX = 25 -- friends looked up for the Friends tab
local FRIENDS_CACHE = 300 -- seconds

local nameCache: { [number]: string } = {}
local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "Player"
	return nameCache[userId]
end

local storeCache: { [string]: OrderedDataStore | false } = {}
local function storeFor(board: Boards.Board): OrderedDataStore?
	local name = if board.Weekly then board.Store .. Season.Week() else board.Store
	local cached = storeCache[name]
	if cached == nil then
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		cached = if ok then store else false
		storeCache[name] = cached
	end
	return cached or nil
end

type Entry = { UserId: number, Name: string, Value: number }
type Top = { Rows: { Entry }, At: number, Global: boolean }
local tops: { [string]: Top } = {}
local lastPushed: { [Player]: { [string]: number } } = {}

-- Score of a player (rolls their weekly counters into the current week first)
local function scoreOf(player: Player, board: Boards.Board): number?
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	Boards.RollWeek(data)
	return math.floor(board.Value(data))
end

-- Top list from the store (or this server's players if DataStores aren't available)
local function fetchTop(board: Boards.Board): Top
	local store = storeFor(board)
	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, TOP)
		end)
		if ok then
			local rows = {}
			for _, entry in pages:GetCurrentPage() do
				local userId = tonumber(entry.key) or 0
				table.insert(rows, { UserId = userId, Name = nameFor(userId), Value = entry.value })
			end
			return { Rows = rows, At = os.clock(), Global = true }
		end
	end
	local rows = {}
	for _, player in Players:GetPlayers() do
		local value = scoreOf(player, board)
		if value and value > 0 then
			table.insert(rows, { UserId = player.UserId, Name = player.DisplayName, Value = value })
		end
	end
	table.sort(rows, function(a, b)
		return a.Value > b.Value
	end)
	return { Rows = rows, At = os.clock(), Global = false }
end

local function topFor(board: Boards.Board): Top
	local top = tops[board.Id]
	if not top or os.clock() - top.At > cfg.RefreshInterval * 1.5 then
		top = fetchTop(board)
		tops[board.Id] = top
	end
	return top
end

-- Renders rows into a board built by WorldBuilder (SurfaceGui > List with Row1..RowN labels)
local function render(boardName: string, rows: { Row }, title: string?)
	local board = workspace:FindFirstChild("World")
		and workspace.World:FindFirstChild("Hub")
		and workspace.World.Hub:FindFirstChild(boardName)
	local gui = board and board:FindFirstChild("Board")
	local list = gui and gui:FindFirstChild("List")
	if not list then
		return
	end
	local titleLabel = title and gui:FindFirstChild("Title") :: TextLabel?
	if titleLabel then
		titleLabel.Text = title :: string
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

-- Saves everyone's scores (only the ones that changed, to stay inside DataStore limits)
local function pushScores()
	for _, player in Players:GetPlayers() do
		local pushed = lastPushed[player] or {}
		lastPushed[player] = pushed
		for _, board in Boards.List do
			local value = scoreOf(player, board)
			local store = storeFor(board)
			local key = board.Id .. (if board.Weekly then tostring(Season.Week()) else "")
			if value and store and value > 0 and pushed[key] ~= value then
				local ok = pcall(store.SetAsync, store, tostring(player.UserId), value)
				if ok then
					pushed[key] = value
				end
			end
		end
	end
end

-- Statues of the top 3 trophy holders standing on top of the Trophy board
local statueIds = ""
local function updateStatues(rows: { Entry })
	local hub = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Hub")
	local board = hub and hub:FindFirstChild("TrophyBoard") :: BasePart?
	if not board then
		return
	end
	local ids = {}
	for i = 1, math.min(3, #rows) do
		table.insert(ids, tostring(rows[i].UserId))
	end
	local key = table.concat(ids, ",")
	if key == statueIds then
		return
	end
	statueIds = key
	local old = hub:FindFirstChild("TopStatues")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "TopStatues"
	folder.Parent = hub
	-- #1 in the middle and a little higher, #2 left, #3 right (as you look at the board)
	local spots = { { 0, 1.2 }, { 6, 0 }, { -6, 0 } }
	local medal = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(200, 210, 225), Color3.fromRGB(205, 130, 70) }
	for i = 1, math.min(3, #rows) do
		local row = rows[i]
		local ok, model = pcall(Players.CreateHumanoidModelFromUserId, Players, row.UserId)
		if ok and model then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
			local top = board.Position.Y + 11.3 + spots[i][2]
			local spot = board.CFrame * CFrame.new(spots[i][1], 0, 0)
			local pos = Vector3.new(spot.X, top, spot.Z)
			model:PivotTo(CFrame.lookAt(pos, pos + board.CFrame.LookVector))
			local box, size = model:GetBoundingBox()
			model:PivotTo(model:GetPivot() + Vector3.new(0, top - (box.Position.Y - size.Y / 2), 0))
			model.Name = `#{i} {row.Name}`
			model.Parent = folder
			local head = model:FindFirstChild("Head") :: BasePart?
			if head then
				local tag = Instance.new("BillboardGui")
				tag.Size = UDim2.fromOffset(160, 30)
				tag.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
				tag.MaxDistance = 120
				tag.LightInfluence = 0
				tag.Parent = head
				local text = Instance.new("TextLabel")
				text.Size = UDim2.fromScale(1, 1)
				text.BackgroundTransparency = 1
				text.Font = Enum.Font.FredokaOne
				text.TextScaled = true
				text.TextColor3 = medal[i]
				text.TextStrokeTransparency = 0.3
				text.Text = `#{i} {row.Name}`
				text.Parent = tag
			end
		end
	end
end

-- The Trophy board shows a different category every few seconds
local cycleIndex = 0
local function showNextCategory()
	cycleIndex = cycleIndex % #Boards.List + 1
	local board = Boards.List[cycleIndex]
	local top = topFor(board)
	local rows = {}
	for i = 1, math.min(cfg.Size, #top.Rows) do
		table.insert(rows, { Name = top.Rows[i].Name, Value = Format.Number(top.Rows[i].Value) })
	end
	render("TrophyBoard", rows, `{board.Icon} {board.Name}`)
end

local function refreshGlobal()
	pushScores()
	for _, board in Boards.List do
		tops[board.Id] = fetchTop(board)
	end
	local trophies = tops.Trophies
	if trophies then
		pcall(updateStatues, trophies.Rows)
	end
	-- the middle board shows this week's season race
	local seasonRows = {}
	for _, row in Seasons.BoardRows() do
		table.insert(seasonRows, { Name = row.Name, Value = Format.Number(row.Points) })
	end
	render("EssenceBoard", seasonRows)
end

-- Friends tab: your Roblox friends' scores on one board (cached for a few minutes)
local friendCache: { [string]: { Rows: { Entry }, At: number } } = {}
local friendIds: { [number]: { Ids: { number }, At: number } } = {}

local function friendsOf(player: Player): { number }
	local cached = friendIds[player.UserId]
	if cached and os.clock() - cached.At < FRIENDS_CACHE then
		return cached.Ids
	end
	local ids = {}
	local ok, pages = pcall(Players.GetFriendsAsync, Players, player.UserId)
	if ok then
		for _, friend in pages:GetCurrentPage() do
			table.insert(ids, friend.Id)
			if #ids >= FRIENDS_MAX then
				break
			end
		end
	end
	friendIds[player.UserId] = { Ids = ids, At = os.clock() }
	return ids
end

local function friendRows(player: Player, board: Boards.Board): { Entry }
	local key = `{player.UserId}:{board.Id}`
	local cached = friendCache[key]
	if cached and os.clock() - cached.At < FRIENDS_CACHE then
		return cached.Rows
	end
	local rows = {}
	local store = storeFor(board)
	for _, id in friendsOf(player) do
		local online = Players:GetPlayerByUserId(id)
		local value: number? = if online then scoreOf(online, board) else nil
		if value == nil and store then
			local ok, stored = pcall(store.GetAsync, store, tostring(id))
			value = if ok then tonumber(stored) else nil
		end
		if value and value > 0 then
			table.insert(rows, { UserId = id, Name = nameFor(id), Value = value })
		end
	end
	friendCache[key] = { Rows = rows, At = os.clock() }
	return rows
end

-- For the 🏆 window: the rows plus where you stand
function Leaderboards.GetBoard(player: Player, boardId: any, scope: any): any
	local board = type(boardId) == "string" and Boards.Get(boardId)
	if not board then
		return nil
	end
	local mine = scoreOf(player, board) or 0
	local rows: { Entry }
	if scope == "Friends" then
		rows = table.clone(friendRows(player, board))
		table.insert(rows, { UserId = player.UserId, Name = player.DisplayName, Value = mine })
		table.sort(rows, function(a, b)
			return a.Value > b.Value
		end)
	else
		rows = topFor(board).Rows
	end
	local rank = nil
	for i, row in rows do
		if row.UserId == player.UserId then
			rank = i
			break
		end
	end
	-- not on the top list: how much more you need to get onto it
	local need = nil
	if not rank and #rows >= TOP then
		need = math.max(1, rows[#rows].Value - mine + 1)
	end
	local out = {}
	for i, row in rows do
		table.insert(out, { Rank = i, UserId = row.UserId, Name = row.Name, Value = row.Value })
	end
	return {
		Id = board.Id,
		Rows = out,
		Me = { Value = mine, Rank = rank, Need = need },
		Weekly = board.Weekly,
		EndsAt = if board.Weekly then Season.EndsAt(Season.Week()) else nil,
	}
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
			local ok, err = pcall(refreshGlobal)
			if not ok then
				warn("[Leaderboards] " .. tostring(err))
			end
			task.wait(cfg.RefreshInterval)
		end
	end)
	task.spawn(function()
		task.wait(3)
		while true do
			pcall(showNextCategory)
			task.wait(cfg.CycleSeconds)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPushed[player] = nil
		friendIds[player.UserId] = nil
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
