--[[
	Daily login streak + daily quests (rules and reward lists live in Shared.Daily).

	Other services report progress with DailyRewards.Track(player, stat, amount).
	Players claim rewards through the ClaimDaily / ClaimQuest remotes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Daily = require(ReplicatedStorage.Shared.Daily)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local DailyRewards = {}

local notify = Remotes.Event("Notify")
local GOOD = Color3.fromRGB(120, 255, 160)

-- Today's quest progress, reset when the day changes
local function questState(data: any)
	local today = Daily.Today()
	if data.Quests.Day ~= today then
		data.Quests = { Day = today, Progress = {}, Claimed = {}, BonusClaimed = false }
	end
	return data.Quests
end

-- Gives one reward; returns a short description for the toast
local function grant(player: Player, data: any, reward: Daily.Reward): string
	-- required here (not at the top) because Economy and Hatching report progress to us
	local Economy = require(script.Parent.Economy) :: any
	if reward.Kind == "Essence" then
		local amount = Economy.GetProductEssence(player, reward.Amount or 0)
		Economy.AddEssence(player, amount)
		return `{Format.Number(amount)} Essence`
	elseif reward.Kind == "Trophies" then
		data.Trophies += reward.Amount or 0
		return `{reward.Amount} Trophies`
	elseif reward.Kind == "Boost" then
		Economy.AddBoost(player, reward.Boost :: string, reward.Seconds :: number)
		return reward.Text
	elseif reward.Kind == "Item" then
		local Bag = require(script.Parent.Bag) :: any
		Bag.Give(player, reward.Item :: string, reward.Amount or 1, true)
		return `{reward.Text} (in your Bag)`
	elseif reward.Kind == "MysticEgg" then
		local Hatching = require(script.Parent.Hatching) :: any
		if Hatching.MysticHatch(player) then
			return reward.Text
		end
		-- storage full: give Essence instead so the reward isn't lost
		local amount = Economy.GetProductEssence(player, 150)
		Economy.AddEssence(player, amount)
		return `{Format.Number(amount)} Essence (storage full)`
	end
	return reward.Text
end

function DailyRewards.Track(player: Player, stat: string, amount: number?)
	local data = PlayerData.Get(player) :: any
	if not data or not data.Quests then
		return
	end
	local state = questState(data)
	local changed = false
	for _, quest in Daily.QuestsFor(state.Day) do
		if quest.Stat == stat then
			local before = state.Progress[quest.Key] or 0
			if before < quest.Goal then
				local after = math.min(quest.Goal, before + (amount or 1))
				state.Progress[quest.Key] = after
				changed = true
				if after >= quest.Goal then
					notify:FireClient(player, `Quest complete: {quest.Text}! Claim it in Daily.`, GOOD)
				end
			end
		end
	end
	if changed then
		PlayerData.MarkChanged(player)
	end
end

function DailyRewards.CanClaimStreak(data: any): boolean
	return data.Daily.LastClaimDay < Daily.Today()
end

function DailyRewards.ClaimStreak(player: Player): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data then
		return false, "Still loading..."
	end
	local today = Daily.Today()
	if data.Daily.LastClaimDay >= today then
		return false, "Already claimed today - come back tomorrow!"
	end
	local streak = Daily.NextStreak(data.Daily.Streak, data.Daily.LastClaimDay, today)
	data.Daily.Streak = streak
	data.Daily.LastClaimDay = today
	local day = Daily.CycleDay(streak)
	local got = {}
	for _, reward in Daily.StreakRewards[day] do
		table.insert(got, grant(player, data, reward))
	end
	PlayerData.MarkChanged(player)
	notify:FireClient(player, `Day {day} reward: {table.concat(got, " + ")}`, GOOD)
	return true
end

function DailyRewards.ClaimQuest(player: Player, key: string): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data then
		return false, "Still loading..."
	end
	local state = questState(data)
	local todays = Daily.QuestsFor(state.Day)
	if key == "Bonus" then
		if state.BonusClaimed then
			return false, "Already claimed"
		end
		for _, quest in todays do
			if not state.Claimed[quest.Key] then
				return false, "Finish and claim all of today's quests first"
			end
		end
		state.BonusClaimed = true
		local got = grant(player, data, Daily.BonusReward)
		PlayerData.MarkChanged(player)
		notify:FireClient(player, `All quests done! Bonus: {got}`, GOOD)
		return true
	end
	for _, quest in todays do
		if quest.Key == key then
			if state.Claimed[key] then
				return false, "Already claimed"
			end
			if (state.Progress[key] or 0) < quest.Goal then
				return false, "Not finished yet"
			end
			state.Claimed[key] = true
			local got = grant(player, data, Daily.QuestReward)
			PlayerData.MarkChanged(player)
			notify:FireClient(player, `Quest reward: {got}`, GOOD)
			return true
		end
	end
	return false, "That quest isn't active today"
end

-- What the client needs to draw the Daily panel
function DailyRewards.Snapshot(data: any)
	local state = questState(data)
	local today = Daily.Today()
	local canClaim = data.Daily.LastClaimDay < today
	-- the day you'd get if you claimed now, or the day you already got today
	local shownStreak = if canClaim
		then Daily.NextStreak(data.Daily.Streak, data.Daily.LastClaimDay, today)
		else data.Daily.Streak
	local quests = {}
	local ready = 0
	for _, quest in Daily.QuestsFor(state.Day) do
		local progress = state.Progress[quest.Key] or 0
		local claimed = state.Claimed[quest.Key] == true
		if progress >= quest.Goal and not claimed then
			ready += 1
		end
		table.insert(quests, { Key = quest.Key, Progress = progress, Claimed = claimed })
	end
	return {
		Streak = shownStreak,
		CycleDay = Daily.CycleDay(shownStreak),
		CanClaim = canClaim,
		StreakLost = canClaim and data.Daily.Streak > 0 and shownStreak == 1,
		Day = state.Day,
		NextReset = Daily.NextReset(),
		Quests = quests,
		BonusClaimed = state.BonusClaimed,
		ReadyCount = ready + (if canClaim then 1 else 0),
	}
end

function DailyRewards.Start()
	-- "Play for N minutes" quests
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				DailyRewards.Track(player, "PlayMinutes", 1)
			end
		end
	end)
end

return DailyRewards
