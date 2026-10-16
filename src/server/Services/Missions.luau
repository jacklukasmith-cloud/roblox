--[[
	Tracks each player's place in the mission chain (Shared/Missions) and pays the rewards.
	Checked whenever their data changes, so any way of making progress counts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MissionList = require(Shared.Missions)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)

local Missions = {}

local missionComplete = Remotes.Event("MissionComplete")

local function grant(player: Player, data: any, reward: { [string]: any })
	if reward.Essence then
		Economy.AddEssence(player, reward.Essence)
	end
	if reward.Trophies then
		data.Trophies += reward.Trophies
	end
	if reward.Title and not table.find(data.Titles, reward.Title) then
		table.insert(data.Titles, reward.Title)
	end
	if reward.Items then
		local Bag = require(script.Parent.Bag) :: any
		for id, count in reward.Items do
			Bag.Give(player, id, count, true)
		end
	end
end

-- Completes the current mission (and any after it that are already done) and starts the next
function Missions.Check(player: Player)
	local data = PlayerData.Get(player) :: any
	if not data then
		return
	end
	local state = data.Missions
	local changed = false
	local done: { any } = {}
	for _ = 1, #MissionList.List do
		local mission = MissionList.List[state.Index]
		if not mission then
			break
		end
		-- "do N more" missions count from when they start
		if mission.Kind == "Count" and state.Baseline == nil then
			state.Baseline = MissionList.Value(data, mission.Stat)
			changed = true
		end
		local _, progress, goal = MissionList.Current(data)
		if progress < goal then
			break
		end
		grant(player, data, mission.Reward)
		table.insert(done, mission)
		state.Index += 1
		state.Baseline = nil
		changed = true
	end
	if changed then
		PlayerData.MarkChanged(player)
	end
	-- one message, even if older progress finished several at once
	if #done > 0 then
		local nextMission = MissionList.List[state.Index]
		local title = if #done == 1 then done[1].Text else `{#done} missions complete!`
		local total = { Essence = 0, Trophies = 0 } :: any
		for _, mission in done do
			total.Essence += mission.Reward.Essence or 0
			total.Trophies += mission.Reward.Trophies or 0
			total.Title = mission.Reward.Title or total.Title
			for id, count in mission.Reward.Items or {} do
				total.Items = total.Items or {}
				total.Items[id] = (total.Items[id] or 0) + count
			end
		end
		total.Essence = if total.Essence > 0 then total.Essence else nil
		total.Trophies = if total.Trophies > 0 then total.Trophies else nil
		missionComplete:FireClient(
			player,
			title,
			MissionList.RewardText(total, Format.Number),
			nextMission and nextMission.Text
		)
	end
end

function Missions.Start()
	PlayerData.Changed:Connect(function(player)
		local ok, err = pcall(Missions.Check, player)
		if not ok then
			warn("[Missions] " .. tostring(err))
		end
	end)
end

return Missions
