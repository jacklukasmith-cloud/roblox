--[[
	Mythic Tamers - server entry point. Boots every service and wires up remotes & prompts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Eggs = require(Shared.Eggs)
local WhatsNew = require(Shared.WhatsNew)

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
local DailyRewards = require(Services.DailyRewards)
local BossRaid = require(Services.BossRaid)
local Seasons = require(Services.Seasons)
local Celebrations = require(Services.Celebrations)
local Treasures = require(Services.Treasures)
local Pickaxe = require(Services.Pickaxe)
local Missions = require(Services.Missions)
local Bag = require(Services.Bag)
local Codes = require(Services.Codes)
local Trading = require(Services.Trading)
local FriendBoost = require(Services.FriendBoost)
local Sanctuaries = require(Services.Sanctuaries)
local Habitat = require(Services.Habitat)
local Gloomwood = require(Services.Gloomwood)
local Cauldron = require(Services.Cauldron)
local Hangar = require(Services.Hangar)

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
	print(
		`[Mythic Tamers] Creature 3D models ready: {#folder:GetChildren()} ({adopted} picked up from Workspace). `
			.. "Creatures without one use the built-in model."
	)
end

-- Imported world props (eggs, crystals, chest, merchant stall, trees): models in Workspace named
-- after WorldBuilder.MeshNames (e.g. "MeadowEgg", "FrostCrystal") move to ReplicatedStorage.WorldMeshes.
do
	local folder = ReplicatedStorage:FindFirstChild("WorldMeshes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WorldMeshes"
		folder.Parent = ReplicatedStorage
	end
	for _, obj in workspace:GetChildren() do
		if obj:IsA("Model") or obj:IsA("MeshPart") then
			local clean = string.lower((string.gsub(obj.Name, "[^%w]", "")))
			for _, name in WorldBuilder.MeshNames do
				if string.sub(clean, 1, #name) == string.lower(name) and not folder:FindFirstChild(name) then
					obj.Name = name
					obj.Parent = folder
					break
				end
			end
		end
	end
	if #folder:GetChildren() > 0 then
		print(`[Mythic Tamers] World 3D models ready: {#folder:GetChildren()}/{#WorldBuilder.MeshNames}`)
	end
end

-- Custom sounds: a Sound in Workspace named after a Config.Sounds key (e.g. "MusicMeadow")
-- is moved into ReplicatedStorage.GameSounds so every client uses it.
do
	local folder = ReplicatedStorage:FindFirstChild("GameSounds")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GameSounds"
		folder.Parent = ReplicatedStorage
	end
	for _, obj in workspace:GetDescendants() do
		if obj:IsA("Sound") and Config.Sounds[obj.Name] ~= nil and not folder:FindFirstChild(obj.Name) then
			obj.Parent = folder
		end
	end
	if #folder:GetChildren() > 0 then
		print(`[Mythic Tamers] Using {#folder:GetChildren()} custom sound(s)`)
	end
end

-- World ----------------------------------------------------------------------------
local world = WorldBuilder.Build()

for _, crystal in world.Crystals do
	Crystals.Register(crystal.Model, crystal.Zone)
end
for _, chest in world.Chests do
	Crystals.Register(chest.Model, chest.Zone, {
		HPMultiplier = Config.Chest.HPMultiplier,
		RewardMultiplier = Config.Chest.RewardMultiplier,
		RespawnTime = Config.Chest.RespawnTime,
		Kind = "Chest",
	})
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
		local prompt = egg:FindFirstChild(name, true) :: ProximityPrompt
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

PlayerData.Loaded:Connect(function(player, loaded)
	-- Brand-new players get a starter creature so they can farm straight away
	local data = PlayerData.Get(player)
	if data and loaded.NextUid == 1 and next(data.Creatures) == nil then
		local uid = PlayerData.NewCreature(data, Config.StarterCreature, "Normal")
		data.Creatures[uid].Equipped = true
		data.Bestiary[Config.StarterCreature] = true
	end
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

bind("EquipTitle", function(player, title)
	if type(title) ~= "string" then
		return false
	end
	return Seasons.EquipTitle(player, title)
end)

bind("UpgradePickaxe", function(player)
	return Pickaxe.Upgrade(player)
end)

bind("UseItem", function(player, id)
	if type(id) ~= "string" then
		return false
	end
	return Bag.Use(player, id)
end)

Remotes.Function("GetBoard").OnServerInvoke = function(player, boardId, scope)
	local data = PlayerData.Get(player) :: any
	if data then
		data.Stats.BoardsViewed = (data.Stats.BoardsViewed or 0) + 1
		PlayerData.MarkChanged(player)
	end
	return Leaderboards.GetBoard(player, boardId, scope)
end

bind("Travel", Sanctuaries.Travel)
bind("SetHabitat", Habitat.Set)
bind("SellCrystals", Gloomwood.Sell)
bind("Brew", Cauldron.Brew)
bind("BuildVehicle", Hangar.Build)
bind("Ride", Hangar.Ride)
bind("SetSkin", Hangar.SetSkin)
bind("SeenWhatsNew", function(player)
	local data = PlayerData.Get(player) :: any
	if data.SeenUpdate ~= WhatsNew.Version then
		data.SeenUpdate = WhatsNew.Version
		PlayerData.MarkChanged(player)
	end
	return true
end)
bind("TradeRequest", Trading.Request)
bind("TradeRespond", Trading.Respond)
bind("TradeSetPet", Trading.SetPet)
bind("TradeSetItem", Trading.SetItem)
bind("TradeReady", Trading.SetReady)
bind("TradeCancel", Trading.Cancel)

bind("RedeemCode", function(player, text)
	return Codes.Redeem(player, text)
end)

bind("TogglePickaxe", function(player)
	return Pickaxe.Toggle(player)
end)

bind("GoToBoss", function(player)
	return BossRaid.GoTo(player)
end)

bind("Fuse", function(player, creatureId, variant)
	if type(creatureId) ~= "string" or type(variant) ~= "string" then
		return false
	end
	local ok, message, result = Economy.Fuse(player, creatureId, variant)
	if ok then
		-- reuse the hatch reveal for a big "Fusion!" moment
		Remotes.Event("HatchResult"):FireClient(player, Eggs.EggFor(creatureId), { result }, { Title = "Fusion!" })
		Celebrations.Announce(player, result.Id, result.Variant, "fused")
	end
	return ok, message
end)

bind("ClaimDaily", function(player)
	return DailyRewards.ClaimStreak(player)
end)

bind("ClaimQuest", function(player, key)
	if type(key) ~= "string" then
		return false
	end
	return DailyRewards.ClaimQuest(player, key)
end)

bind("BuyMerchantItem", function(player, itemId)
	if type(itemId) ~= "string" then
		return false
	end
	return Hatching.BuyMerchantItem(player, itemId)
end)

Leaderboards.Start()
DailyRewards.Start()
BossRaid.Start()
Seasons.Start()
Celebrations.Start()
Treasures.Start()
Pickaxe.Start()
Missions.Start()
Bag.Start()
Trading.Start()
FriendBoost.Start()
Sanctuaries.Start()
Habitat.Start()
Gloomwood.Start()
Cauldron.Start()
Hangar.Start()
Admin.Start()

print("[Mythic Tamers] Server ready")

Players.PlayerRemoving:Connect(Codes.Forget)
