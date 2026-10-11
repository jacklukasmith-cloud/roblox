--[[
	Mythic Tamers - server entry point. Boots every service and wires up remotes & prompts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Services = script.Parent.Services
local PlayerData = require(Services.PlayerData)
local Monetization = require(Services.Monetization)
local WorldService = require(Services.WorldService)
local HouseWar = require(Services.HouseWar)
local Economy = require(Services.Economy)
local Crystals = require(Services.Crystals)
local Hatching = require(Services.Hatching)
local Leaderboards = require(Services.Leaderboards)
local Admin = require(Services.Admin)
local WorldBuilder = require(Services.WorldBuilder)

local notify = Remotes.Event("Notify")
local dataChanged = Remotes.Event("DataChanged")
local worldState = Remotes.Event("WorldState")

-- Imported creature meshes ------------------------------------------------------------
-- Models imported with Studio's "Import 3D" land in Workspace, named after their file
-- (e.g. "EmberFox"). Move any that match a creature into ReplicatedStorage.CreatureMeshes
-- so the game uses them - no manual filing needed.
do
	local Creatures = require(Shared.Creatures)
	local folder = ReplicatedStorage:FindFirstChild("CreatureMeshes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CreatureMeshes"
		folder.Parent = ReplicatedStorage
	end
	local adopted = 0
	for _, obj in workspace:GetChildren() do
		if obj:IsA("Model") or obj:IsA("MeshPart") then
			local clean = string.lower((string.gsub(obj.Name, "[^%w]", "")))
			for _, def in Creatures.Ordered do
				local id = def.Id
				if string.sub(clean, 1, #id) == string.lower(id) and not folder:FindFirstChild(id) then
					obj.Name = id
					obj.Parent = folder
					adopted += 1
					break
				end
			end
		end
	end
	if adopted > 0 then
		print(`[Mythic Tamers] Using {adopted} imported creature model(s) from Workspace`)
	end
end

-- World ----------------------------------------------------------------------------
local world = WorldBuilder.Build()

for _, crystal in world.Crystals do
	Crystals.Register(crystal.Model, crystal.Zone)
end

local function report(player: Player, ok: boolean, message: string?)
	if not ok and message then
		notify:FireClient(player, message, Color3.fromRGB(255, 120, 120))
	end
end

for _, stand in world.EggStands do
	local eggId = stand:GetAttribute("EggId") :: string
	local egg = stand:FindFirstChild("Egg", true) :: BasePart
	for name, count in { Hatch1 = 1, Hatch3 = 3 } do
		local prompt = egg:FindFirstChild(name) :: ProximityPrompt
		prompt.Triggered:Connect(function(player)
			report(player, Hatching.Hatch(player, eggId, count))
		end)
	end
end

for _, gate in world.Gates do
	local zoneIndex = gate:GetAttribute("ZoneIndex") :: number
	local prompt = gate:FindFirstChild("GateTerminal"):FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		report(player, Economy.UnlockZone(player, zoneIndex))
	end)
end

for _, pedestal in world.HousePedestals do
	local houseId = pedestal:GetAttribute("HouseId") :: string
	local prompt = pedestal:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		local ok, message = HouseWar.Choose(player, houseId)
		if ok then
			notify:FireClient(player, `Welcome to House {houseId}!`, pedestal.Color)
		else
			report(player, ok, message)
		end
	end)
end

-- Players --------------------------------------------------------------------------
local function setupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local trophies = Instance.new("IntValue")
	trophies.Name = "Trophies"
	trophies.Parent = stats
	local essence = Instance.new("StringValue")
	essence.Name = "Essence"
	essence.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player
end

local function updateLeaderstats(player: Player)
	local data = PlayerData.Get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	stats.Trophies.Value = data.Trophies
	stats.Essence.Value = Format.Number(data.Essence)
	stats.Rebirths.Value = data.Rebirths
end

local function pushSnapshot(player: Player)
	local snapshot = Economy.BuildSnapshot(player)
	if snapshot then
		dataChanged:FireClient(player, snapshot)
	end
	updateLeaderstats(player)
	Economy.UpdateFollowerAttribute(player)
end

PlayerData.Loaded:Connect(function(player)
	setupLeaderstats(player)
	Monetization.Refresh(player)
	Economy.GrantOffline(player)
	PlayerData.MarkChanged(player)
end)

PlayerData.Changed:Connect(pushSnapshot)

-- In case someone finished loading before the connections above were made
for _, player in Players:GetPlayers() do
	if PlayerData.Get(player) and not player:FindFirstChild("leaderstats") then
		setupLeaderstats(player)
		task.spawn(Monetization.Refresh, player)
	end
end

-- Boost timers expire silently, so refresh everyone's multipliers every few seconds.
task.spawn(function()
	while true do
		task.wait(5)
		for _, player in Players:GetPlayers() do
			PlayerData.MarkChanged(player)
		end
	end
end)

-- World state (weather, merchant, house war) for the HUD
task.spawn(function()
	while true do
		local state = {
			Weather = WorldService.GetWeather(),
			Merchant = WorldService.GetMerchant(),
			Houses = HouseWar.GetStandings(),
			HouseWeekEndsAt = HouseWar.WeekEndsAt(),
			ServerTime = os.time(),
		}
		worldState:FireAllClients(state)
		task.wait(2)
	end
end)

-- Remotes --------------------------------------------------------------------------
local function bind(name: string, handler: (Player, ...any) -> ...any)
	Remotes.Function(name).OnServerInvoke = function(player, ...)
		if not PlayerData.Get(player) then
			return false, "Still loading..."
		end
		return handler(player, ...)
	end
end

Remotes.Function("GetSnapshot").OnServerInvoke = function(player)
	PlayerData.WaitFor(player)
	return Economy.BuildSnapshot(player)
end

bind("Equip", function(player, uid)
	if type(uid) ~= "string" then
		return false
	end
	return Economy.Equip(player, uid)
end)

bind("Unequip", function(player, uid)
	if type(uid) ~= "string" then
		return false
	end
	return Economy.Unequip(player, uid)
end)

bind("EquipBest", function(player)
	Economy.EquipBest(player)
	return true
end)

bind("Release", function(player, uids)
	if type(uids) ~= "table" or #uids > 200 then
		return false
	end
	return Economy.Release(player, uids)
end)

bind("Rebirth", function(player)
	return Economy.Rebirth(player)
end)

bind("SetAutoCollect", function(player, enabled)
	local data = PlayerData.Get(player)
	if data and type(enabled) == "boolean" then
		data.AutoCollectEnabled = enabled
		PlayerData.MarkChanged(player)
	end
	return true
end)

bind("ChooseHouse", function(player, houseId)
	if type(houseId) ~= "string" then
		return false
	end
	return HouseWar.Choose(player, houseId)
end)

bind("BuyMerchantItem", function(player, itemId)
	if type(itemId) ~= "string" then
		return false
	end
	return Hatching.BuyMerchantItem(player, itemId)
end)

Leaderboards.Start()
Admin.Start()

print("[Mythic Tamers] Server ready")
