--[[
	The Pet Habitat on your Sanctuary island: pick unequipped pets to live there. They wander the
	island for everyone to see and earn Sanctuary.HabitatXPPerMinute XP each, online or offline
	(offline time counts up to Sanctuary.HabitatOfflineHours).

	Habitat.Set(player, uid, on) adds or removes a pet. Pets that get equipped, released or traded
	leave the habitat by themselves.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Sanctuary = require(Shared.Sanctuary)
local Creatures = require(Shared.Creatures)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Sanctuaries = require(script.Parent.Sanctuaries)

local Habitat = {}

local TICK = 60
local notify = Remotes.Event("Notify")

local function sanctuaryOf(data: any): any
	data.Sanctuary = data.Sanctuary or { Level = 1 }
	local s = data.Sanctuary
	s.Habitat = s.Habitat or {}
	s.HabitatAt = s.HabitatAt or 0
	return s
end

-- Drops pets that are gone or equipped, and any over the slot count. Returns true if it changed.
local function prune(data: any): boolean
	local s = sanctuaryOf(data)
	local slots = Sanctuary.HabitatSlots(s.Level or 1)
	local kept, seen = {}, {}
	for _, uid in s.Habitat do
		local entry = data.Creatures[uid]
		if entry and not entry.Equipped and not seen[uid] and #kept < slots then
			seen[uid] = true
			table.insert(kept, uid)
		end
	end
	if #kept ~= #s.Habitat then
		s.Habitat = kept
		return true
	end
	return false
end

-- Puts the habitat pets on the island model so every client can draw them
function Habitat.Refresh(player: Player)
	local data = PlayerData.Get(player)
	local island = Sanctuaries.IslandOf(player)
	if data and island then
		island:SetAttribute("Habitat", Sanctuary.HabitatKey(data))
	end
end

function Habitat.Set(player: Player, uid: any, on: any): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data or type(uid) ~= "string" then
		return false, nil
	end
	local entry = data.Creatures[uid]
	if not entry then
		return false, "That pet isn't yours"
	end
	local s = sanctuaryOf(data)
	local index = table.find(s.Habitat, uid)
	if on == true then
		if index then
			return true, nil
		end
		if entry.Equipped then
			return false, "Unequip it first: equipped pets follow you"
		end
		local slots = Sanctuary.HabitatSlots(s.Level or 1)
		if #s.Habitat >= slots then
			return false, `Your habitat is full ({slots} pets). Upgrade your island for more room!`
		end
		if #s.Habitat == 0 then
			s.HabitatAt = os.time() -- XP starts counting now, not from whenever it was last empty
		end
		table.insert(s.Habitat, uid)
	elseif index then
		table.remove(s.Habitat, index)
	end
	PlayerData.MarkChanged(player)
	Habitat.Refresh(player)
	return true, nil
end

-- Gives habitat XP for the minutes since the last time (offline time is capped). Returns the XP
-- each pet got.
function Habitat.Tick(player: Player, now: number): number
	local data = PlayerData.Get(player) :: any
	if not data then
		return 0
	end
	local s = sanctuaryOf(data)
	if #s.Habitat == 0 or s.HabitatAt <= 0 then
		s.HabitatAt = now
		return 0
	end
	local minutes = math.floor((now - s.HabitatAt) / 60)
	if minutes <= 0 then
		return 0
	end
	local cap = Sanctuary.HabitatOfflineHours * 60
	if minutes > cap then
		minutes = cap
		s.HabitatAt = now
	else
		s.HabitatAt += minutes * 60
	end
	local only = {}
	local anyToLevel = false
	for _, uid in s.Habitat do
		only[uid] = true
		local entry = data.Creatures[uid]
		if entry and (entry.Level or 1) < Creatures.MaxLevel then
			anyToLevel = true
		end
	end
	local xp = minutes * Sanctuary.HabitatXPPerMinute
	if anyToLevel then
		Economy.GrantXP(player, xp, only)
	end
	PlayerData.MarkChanged(player)
	return if anyToLevel then xp else 0
end

function Habitat.Start()
	-- offline XP when you join, and the island shows your pets
	PlayerData.Loaded:Connect(function(player)
		local data = PlayerData.Get(player) :: any
		if data and prune(data) then
			PlayerData.MarkChanged(player)
		end
		local xp = Habitat.Tick(player, os.time())
		Habitat.Refresh(player)
		if xp >= 10 then
			task.delay(6, function()
				if player.Parent then
					notify:FireClient(
						player,
						`🐾 Your habitat pets earned {xp} XP while you were away!`,
						Color3.fromRGB(140, 230, 160)
					)
				end
			end)
		end
	end)
	-- equipped / released / traded pets leave
	PlayerData.Changed:Connect(function(player)
		local data = PlayerData.Get(player) :: any
		if data and prune(data) then
			PlayerData.MarkChanged(player)
			Habitat.Refresh(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(Habitat.Tick, player, os.time())
				if not ok then
					warn("[Habitat] " .. tostring(err))
				end
			end
		end
	end)
end

return Habitat
