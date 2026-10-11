--[[
	Weekly House War across every server.

	Each server buffers points locally and adds them to a shared DataStore key once a
	minute (UpdateAsync, so servers never overwrite each other). When a new week starts,
	players who contributed last week get rewarded the next time they're online.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Houses = require(ReplicatedStorage.Shared.Houses)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local HouseWar = {}

local OFFSET = Config.Houses.WeekEpochOffset
local notify = Remotes.Event("Notify")

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.Houses.DataStoreName)
end)

local function emptyTotals()
	local t = {}
	for _, id in Houses.Order do
		t[id] = 0
	end
	return t
end

local pendingWeek = -1
local pending = emptyTotals()
local globalWeek = -1
local globalTotals = emptyTotals()
local resultsCache: { [number]: { [string]: number } } = {}

function HouseWar.CurrentWeek(): number
	return Houses.GetWeek(os.time(), OFFSET)
end

function HouseWar.WeekEndsAt(): number
	return Houses.WeekEndsAt(HouseWar.CurrentWeek(), OFFSET)
end

-- Global totals for this week, including points this server hasn't pushed yet.
function HouseWar.GetStandings(): { [string]: number }
	local week = HouseWar.CurrentWeek()
	local result = emptyTotals()
	for id in result do
		if globalWeek == week then
			result[id] += globalTotals[id] or 0
		end
		if pendingWeek == week then
			result[id] += pending[id] or 0
		end
	end
	return result
end

function HouseWar.AddPoints(player: Player, points: number)
	local data = PlayerData.Get(player)
	if not data or not data.House or points <= 0 then
		return
	end
	local week = HouseWar.CurrentWeek()
	if data.HouseContribution.Week ~= week then
		data.HouseContribution = { Week = week, Points = 0, House = data.House }
	end
	data.HouseContribution.Points += points
	if pendingWeek ~= week then
		-- A new week started; the old pending points were flushed (or are lost, which is fine).
		pendingWeek = week
		pending = emptyTotals()
	end
	pending[data.House] += points
end

local function flush()
	if pendingWeek < 0 then
		return
	end
	local week, toSend = pendingWeek, pending
	pending = emptyTotals()
	if not store then
		-- No DataStores (Studio): keep a local total so the board still works.
		if globalWeek ~= week then
			globalWeek, globalTotals = week, emptyTotals()
		end
		for id, pts in toSend do
			globalTotals[id] += pts
		end
		return
	end
	local ok, result = pcall(function()
		return (store :: DataStore):UpdateAsync("Week_" .. week, function(old)
			old = if type(old) == "table" then old else {}
			for id, pts in toSend do
				old[id] = (old[id] or 0) + math.floor(pts)
			end
			return old
		end)
	end)
	if ok and type(result) == "table" then
		globalWeek = week
		globalTotals = emptyTotals()
		for id in globalTotals do
			globalTotals[id] = result[id] or 0
		end
	else
		-- Put the points back and try again next flush.
		if pendingWeek == week then
			for id, pts in toSend do
				pending[id] += pts
			end
		end
	end
end

local function getResults(week: number): { [string]: number }?
	if resultsCache[week] then
		return resultsCache[week]
	end
	if not store then
		return if week == globalWeek then globalTotals else nil
	end
	local ok, result = pcall(function()
		return (store :: DataStore):GetAsync("Week_" .. week)
	end)
	if ok and type(result) == "table" then
		resultsCache[week] = result
		return result
	end
	return nil
end

function HouseWar.GetWinner(totals: { [string]: number }): string?
	local best, bestScore = nil, 0
	for _, id in Houses.Order do
		local score = totals[id] or 0
		if score > bestScore then
			best, bestScore = id, score
		end
	end
	return best
end

-- Pays out last week's rewards once per player.
function HouseWar.CheckRewards(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local lastWeek = HouseWar.CurrentWeek() - 1
	if data.HouseRewardedWeek >= lastWeek then
		return
	end
	local contribution = data.HouseContribution
	if contribution.Week ~= lastWeek or contribution.Points < Config.Houses.MinPointsForReward then
		data.HouseRewardedWeek = lastWeek
		return
	end
	local results = getResults(lastWeek)
	if not results then
		return -- try again later
	end
	data.HouseRewardedWeek = lastWeek
	local winner = HouseWar.GetWinner(results)
	local house = Houses.Get(contribution.House)
	if winner and winner == contribution.House then
		data.Trophies += Config.Houses.WinnerTrophies
		notify:FireClient(
			player,
			`{house and house.Name or "Your House"} won last week's House War! +{Config.Houses.WinnerTrophies} Trophies`,
			Color3.fromRGB(255, 215, 80)
		)
	else
		data.Trophies += Config.Houses.ParticipantTrophies
		notify:FireClient(player, `Thanks for fighting in the House War! +{Config.Houses.ParticipantTrophies} Trophies`)
	end
	PlayerData.MarkChanged(player)
end

function HouseWar.Choose(player: Player, houseId: string): (boolean, string?)
	local data = PlayerData.Get(player)
	if not data or not Houses.Get(houseId) then
		return false, "Unknown House"
	end
	if data.House == houseId then
		return false, "You're already in this House"
	end
	local week = HouseWar.CurrentWeek()
	if data.House and data.HouseJoinedWeek == week then
		return false, "You can only switch Houses once per week"
	end
	data.House = houseId
	data.HouseJoinedWeek = week
	data.HouseContribution = { Week = week, Points = 0, House = houseId }
	player:SetAttribute("House", houseId)
	PlayerData.MarkChanged(player)
	return true, nil
end

PlayerData.Loaded:Connect(function(player, data)
	player:SetAttribute("House", data.House)
	task.delay(5, HouseWar.CheckRewards, player)
end)

game:BindToClose(flush)

task.spawn(function()
	while true do
		task.wait(Config.Houses.FlushInterval)
		flush()
		for _, player in Players:GetPlayers() do
			task.spawn(HouseWar.CheckRewards, player)
		end
	end
end)

-- Load current standings on start-up so the board isn't empty.
task.spawn(function()
	local week = HouseWar.CurrentWeek()
	local results = getResults(week)
	if results and globalWeek ~= week then
		globalWeek = week
		for id in globalTotals do
			globalTotals[id] = results[id] or 0
		end
		resultsCache[week] = nil -- current week keeps changing
	end
end)

return HouseWar
