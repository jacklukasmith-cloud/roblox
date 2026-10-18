--[[
	All the maths for power, multipliers, rewards and creature management,
	plus the snapshot sent to each client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local Eggs = require(Shared.Eggs)
local PetStats = require(Shared.PetStats)
local Zones = require(Shared.Zones)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Sanctuary = require(Shared.Sanctuary)

local PlayerData = require(script.Parent.PlayerData)
local Monetization = require(script.Parent.Monetization)
local WorldService = require(script.Parent.WorldService)
local HouseWar = require(script.Parent.HouseWar)
local Surge = require(script.Parent.Surge)
local FriendBoost = require(script.Parent.FriendBoost)
local DailyRewards = require(script.Parent.DailyRewards)
local SpinWheel = require(script.Parent.SpinWheel)
local Seasons = require(script.Parent.Seasons)

local Economy = {}

local notify = Remotes.Event("Notify")
local petLevelUp = Remotes.Event("PetLevelUp")
local bonuses = Config.GamePassBonuses

local function boostActive(data: PlayerData.Data, name: string): boolean
	return (data.Boosts[name] or 0) > os.time()
end

function Economy.GetEquipSlots(player: Player): number
	return Config.BaseEquipSlots + (if Monetization.Owns(player, "ExtraEquip") then bonuses.ExtraEquipSlots else 0)
end

function Economy.GetPower(data: PlayerData.Data): number
	local power = Config.BaseClickPower
	for _, entry in data.Creatures do
		if entry.Equipped then
			power += Creatures.GetPower(entry.Id, entry.Variant, entry.Level)
		end
	end
	return power
end

-- Creature damage per attack tick (before PetDamageMultiplier): each equipped creature's Power x
-- its Speed, plus every Rally ability's bonus for the whole team.
function Economy.GetTeamDamage(data: PlayerData.Data): number
	local total, rally = Config.BaseClickPower, 0
	for _, entry in data.Creatures do
		if entry.Equipped then
			total += Creatures.GetPower(entry.Id, entry.Variant, entry.Level) * PetStats.Speed(entry.Id, entry.Level)
			local ability = PetStats.Ability(entry.Id)
			if ability and ability.Kind == "Rally" then
				rally += ability.Bonus or 0
			end
		end
	end
	local potion = if boostActive(data, "Power") then Config.Boosts.Power else 1
	return total * (1 + rally) * potion
end

-- Average Speed of the equipped team (how quickly they fly over to a target)
function Economy.GetTeamSpeed(data: PlayerData.Data): number
	local sum, count = 0, 0
	for _, entry in data.Creatures do
		if entry.Equipped then
			sum += PetStats.Speed(entry.Id, entry.Level)
			count += 1
		end
	end
	return if count > 0 then sum / count else 1
end

-- Gives XP to every equipped creature (or just the uids in `only`), capped at Creatures.MaxLevel,
-- and tells the owner about any level-ups. Levels live on the creature entries (missing = level 1, 0 XP).
function Economy.GrantXP(player: Player, amount: number, only: { [string]: boolean }?)
	local data = PlayerData.Get(player)
	if not data or amount <= 0 then
		return
	end
	if boostActive(data, "XP") then
		amount *= Config.Boosts.XP
	end
	local ups = {}
	for uid, entry in data.Creatures do
		local level = entry.Level or 1
		local chosen = if only then only[uid] == true else entry.Equipped
		if chosen and level < Creatures.MaxLevel then
			local xp = (entry.XP or 0) + amount
			while level < Creatures.MaxLevel and xp >= Creatures.XPToNext(level) do
				xp -= Creatures.XPToNext(level)
				level += 1
			end
			if level >= Creatures.MaxLevel then
				xp = 0
			end
			if level ~= (entry.Level or 1) then
				table.insert(ups, { Uid = uid, Id = entry.Id, Variant = entry.Variant, Level = level })
			end
			entry.Level = level
			entry.XP = xp
		end
	end
	PlayerData.MarkChanged(player)
	if #ups > 0 then
		petLevelUp:FireClient(player, ups)
		Economy.UpdateFollowerAttribute(player)
	end
end

function Economy.GetRebirthMultiplier(data: PlayerData.Data): number
	return 1 + data.Rebirths * Config.Rebirth.MultiplierPerRebirth
end

function Economy.GetBestiaryMultiplier(data: PlayerData.Data): number
	local count = 0
	for _ in data.Bestiary do
		count += 1
	end
	local sets = 0
	for _, eggId in Eggs.Order do
		if Eggs.SetProgress(eggId, data.Bestiary) then
			sets += 1
		end
	end
	return 1 + count * Config.BestiaryBonusPerSpecies + sets * Config.IndexSetBonus
end

function Economy.GetEssenceMultiplier(player: Player, data: PlayerData.Data): number
	local m = Economy.GetRebirthMultiplier(data) * Economy.GetBestiaryMultiplier(data)
	if Monetization.Owns(player, "VIP") then
		m *= 1 + bonuses.VIPEssence
	end
	if Monetization.Owns(player, "DoubleEssence") then
		m *= bonuses.DoubleEssence
	end
	if boostActive(data, "Essence") then
		m *= Config.Boosts.Essence
	end
	m *= WorldService.GetWeatherDef().Essence
	m *= WorldService.GetEventDef().Essence
	m *= FriendBoost.Multiplier(player)
	m *= Sanctuary.EssenceBonus((data :: any).Sanctuary and (data :: any).Sanctuary.Level or 1)
	if Surge.IsActive() then
		m *= Config.Surge.EssenceMultiplier
	end
	return m
end

function Economy.GetLuck(player: Player, data: PlayerData.Data): number
	local luck = 1
	if Monetization.Owns(player, "LuckyHatch") then
		luck *= bonuses.LuckyHatchLuck
	end
	if boostActive(data, "Luck") then
		luck *= Config.Boosts.Luck
	end
	return luck * WorldService.GetWeatherDef().Luck * WorldService.GetEventDef().Luck
end

function Economy.GetShinyMultiplier(data: PlayerData.Data): number
	local m = WorldService.GetWeatherDef().Shiny * WorldService.GetEventDef().Shiny
	if boostActive(data, "Shiny") then
		m *= Config.Boosts.Shiny
	end
	return m
end

function Economy.GetRebirthCost(data: PlayerData.Data): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ data.Rebirths)
end

function Economy.AddEssence(player: Player, amount: number)
	local data = PlayerData.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.Essence += amount
	data.TotalEssence += amount
	PlayerData.MarkChanged(player)
end

-- Called when a crystal breaks. share = fraction of the crystal's HP this player dealt.
-- Returns the Essence awarded (for the orb burst on the client).
function Economy.AwardCrystal(player: Player, zoneIndex: number, share: number, rewardMultiplier: number?): number
	local data = PlayerData.Get(player)
	local zone = Zones.Get(zoneIndex)
	if not data or not zone then
		return 0
	end
	local base = zone.CrystalReward * share * (rewardMultiplier or 1)
	local amount = base * Economy.GetEssenceMultiplier(player, data)
	Economy.AddEssence(player, amount)
	data.Stats.CrystalsBroken += 1
	-- Competitive scoring ignores paid boosts on purpose.
	Surge.AddScore(player, base * Economy.GetRebirthMultiplier(data))
	Seasons.AddPoints(player, base * Economy.GetRebirthMultiplier(data))
	HouseWar.AddPoints(player, share * zoneIndex * (rewardMultiplier or 1))
	return amount
end

-- Essence for developer products: N crystals' worth from your best zone.
function Economy.GetProductEssence(player: Player, crystalRewards: number): number
	local data = PlayerData.Get(player)
	if not data then
		return 0
	end
	local zone = Zones.Get(data.ZonesUnlocked) or Zones.List[1]
	return zone.CrystalReward * crystalRewards * Economy.GetRebirthMultiplier(data)
end

function Economy.HasBoost(player: Player, name: string): boolean
	local data = PlayerData.Get(player)
	return data ~= nil and boostActive(data, name)
end

function Economy.AddBoost(player: Player, name: string, seconds: number)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local now = os.time()
	data.Boosts[name] = math.max(now, data.Boosts[name] or 0) + seconds
	PlayerData.MarkChanged(player)
end

-- Creature management ------------------------------------------------------------

function Economy.Equip(player: Player, uid: string): (boolean, string?)
	local data = PlayerData.Get(player)
	local entry = data and data.Creatures[uid]
	if not data or not entry then
		return false, "Creature not found"
	end
	local _, equipped = PlayerData.CountCreatures(data)
	if not entry.Equipped and equipped >= Economy.GetEquipSlots(player) then
		return false, "All creature slots are full"
	end
	entry.Equipped = true
	PlayerData.MarkChanged(player)
	return true
end

function Economy.Unequip(player: Player, uid: string): (boolean, string?)
	local data = PlayerData.Get(player)
	local entry = data and data.Creatures[uid]
	if not data or not entry then
		return false, "Creature not found"
	end
	entry.Equipped = false
	PlayerData.MarkChanged(player)
	return true
end

function Economy.EquipBest(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local list = {}
	for uid, entry in data.Creatures do
		entry.Equipped = false
		table.insert(list, { Uid = uid, Power = Creatures.GetPower(entry.Id, entry.Variant, entry.Level) })
	end
	table.sort(list, function(a, b)
		return a.Power > b.Power
	end)
	for i = 1, math.min(#list, Economy.GetEquipSlots(player)) do
		data.Creatures[list[i].Uid].Equipped = true
	end
	PlayerData.MarkChanged(player)
end

-- Fuses Creatures.FuseCost copies of a creature (same variant) into one of the next variant.
-- Unequipped copies are used first; the result is equipped if any copy used was.
function Economy.Fuse(player: Player, creatureId: string, variant: string): (boolean, string?, any)
	local data = PlayerData.Get(player)
	local nextVariant = Creatures.FuseNext[variant]
	if not data or not Creatures.Get(creatureId) or not nextVariant then
		return false, "Can't fuse that"
	end
	local matches = {}
	for uid, entry in data.Creatures do
		if entry.Id == creatureId and entry.Variant == variant then
			table.insert(matches, uid)
		end
	end
	if #matches < Creatures.FuseCost then
		return false, `You need {Creatures.FuseCost} to fuse (you have {#matches})`
	end
	table.sort(matches, function(a, b)
		local ea, eb = data.Creatures[a].Equipped, data.Creatures[b].Equipped
		if ea ~= eb then
			return not ea
		end
		return tonumber(a) < tonumber(b)
	end)
	local wasEquipped = false
	local bestLevel = 1
	for i = 1, Creatures.FuseCost do
		local used = data.Creatures[matches[i]]
		wasEquipped = wasEquipped or used.Equipped
		bestLevel = math.max(bestLevel, used.Level or 1)
		data.Creatures[matches[i]] = nil
	end
	local uid = PlayerData.NewCreature(data, creatureId, nextVariant)
	data.Stats.Fusions = (data.Stats.Fusions or 0) + 1
	data.Creatures[uid].Equipped = wasEquipped
	-- the fused creature keeps the best level of the copies used
	if bestLevel > 1 then
		data.Creatures[uid].Level = bestLevel
	end
	PlayerData.MarkChanged(player)
	return true, nil, { Id = creatureId, Variant = nextVariant, New = false }
end

function Economy.Release(player: Player, uids: { string }): (boolean, string?)
	local data = PlayerData.Get(player)
	if not data then
		return false, "No data"
	end
	local released = 0
	if type(uids) ~= "table" then
		return false
	end
	for _, uid in uids do
		local entry = type(uid) == "string" and data.Creatures[uid]
		-- equipped creatures can't be released (the client also blocks this; never trust it)
		if entry and not entry.Equipped then
			data.Creatures[uid] = nil
			released += 1
		end
	end
	PlayerData.MarkChanged(player)
	return true, `Released {released} creature{if released == 1 then "" else "s"}`
end

-- Rebirth: reset Essence + zones for a permanent multiplier. Creatures are kept.
-- Teleports the player's character to the hub spawn (used after rebirth, when every realm
-- past the first is locked again)
function Economy.SendToHub(player: Player)
	local character = player.Character
	local world = workspace:FindFirstChild("World")
	local spawn = world and world:FindFirstChild("HubSpawn", true)
	if not (character and spawn and spawn:IsA("BasePart")) then
		return
	end
	-- face down the hub towards the realms (+Z), standing just above the pad
	local position = spawn.Position + Vector3.new(0, 4, 0)
	character:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))
end

function Economy.Rebirth(player: Player): (boolean, string?)
	local data = PlayerData.Get(player)
	if not data then
		return false, "No data"
	end
	local cost = Economy.GetRebirthCost(data)
	if data.Essence < cost then
		return false, `You need {Format.Number(cost)} Essence to rebirth`
	end
	data.Essence = 0
	data.ZonesUnlocked = 1
	data.Rebirths += 1
	PlayerData.MarkChanged(player)
	Economy.SendToHub(player)
	notify:FireClient(
		player,
		`Reborn! Essence multiplier is now x{Economy.GetRebirthMultiplier(data)}`,
		Color3.fromRGB(255, 140, 255)
	)
	return true
end

function Economy.UnlockZone(player: Player, zoneIndex: number): (boolean, string?)
	local data = PlayerData.Get(player)
	local zone = Zones.Get(zoneIndex)
	if not data or not zone then
		return false, "Unknown zone"
	end
	if data.ZonesUnlocked >= zoneIndex then
		return false, "Already unlocked"
	end
	if data.ZonesUnlocked < zoneIndex - 1 then
		return false, "Unlock the previous zone first"
	end
	if data.Essence < zone.UnlockCost then
		return false, `You need {Format.Number(zone.UnlockCost)} Essence`
	end
	data.Essence -= zone.UnlockCost
	data.ZonesUnlocked = zoneIndex
	PlayerData.MarkChanged(player)
	notify:FireClient(player, `{zone.Name} unlocked!`, zone.CrystalColor)
	return true
end

-- Offline earnings: creatures keep gathering while you're away (idle-game hook).
function Economy.GrantOffline(player: Player)
	local data = PlayerData.Get(player)
	if not data or data.LastOnline <= 0 then
		return
	end
	local away = os.time() - data.LastOnline
	if away < Config.Offline.MinSeconds then
		return
	end
	local maxHours = if Monetization.Owns(player, "LongerOffline")
		then bonuses.LongerOfflineHours
		else Config.Offline.MaxHours
	local seconds = math.min(away, maxHours * 3600)
	local zone = Zones.Get(data.ZonesUnlocked) or Zones.List[1]
	local damagePerHit = math.min(Economy.GetTeamDamage(data), zone.CrystalHP)
	local perSecond = Config.Offline.Efficiency * damagePerHit * (zone.CrystalReward / zone.CrystalHP)
	local amount = perSecond * seconds * Economy.GetRebirthMultiplier(data)
	if amount >= 1 then
		Economy.AddEssence(player, amount)
		notify:FireClient(
			player,
			`Your creatures gathered {Format.Number(amount)} Essence while you were away ({Format.Time(seconds)})!`,
			Color3.fromRGB(150, 200, 255)
		)
	end
end

-- Snapshot sent to the client -----------------------------------------------------

function Economy.BuildSnapshot(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local total = PlayerData.CountCreatures(data)
	return {
		Essence = data.Essence,
		TotalEssence = data.TotalEssence,
		Trophies = data.Trophies,
		Rebirths = data.Rebirths,
		ZonesUnlocked = data.ZonesUnlocked,
		Creatures = data.Creatures,
		CreatureCount = total,
		Bestiary = data.Bestiary,
		Boosts = data.Boosts,
		AutoCollectEnabled = data.AutoCollectEnabled,
		House = data.House,
		HouseContribution = data.HouseContribution,
		Merchant = data.Merchant,
		Stats = data.Stats,
		Power = Economy.GetPower(data),
		EquipSlots = Economy.GetEquipSlots(player),
		MaxInventory = Config.MaxInventory,
		EssenceMultiplier = Economy.GetEssenceMultiplier(player, data),
		Luck = Economy.GetLuck(player, data),
		ShinyMultiplier = Economy.GetShinyMultiplier(data),
		RebirthCost = Economy.GetRebirthCost(data),
		RebirthMultiplier = Economy.GetRebirthMultiplier(data),
		NextRebirthMultiplier = 1 + (data.Rebirths + 1) * Config.Rebirth.MultiplierPerRebirth,
		BestiaryMultiplier = Economy.GetBestiaryMultiplier(data),
		OwnedPasses = Monetization.GetOwned(player),
		Daily = DailyRewards.Snapshot(data),
		Season = Seasons.Snapshot(player, data),
		Pickaxe = (data :: any).Pickaxe or 1,
		Missions = (data :: any).Missions,
		Items = (data :: any).Items,
		FriendBoost = FriendBoost.Count(player),
		Sanctuary = (data :: any).Sanctuary,
		SeenUpdate = (data :: any).SeenUpdate,
		Gloom = (data :: any).Gloom,
		Cauldron = (data :: any).Cauldron,
		Vehicles = (data :: any).Vehicles,
		Spin = SpinWheel.Snapshot(data),
	}
end

-- Equipped creature list as an attribute so every client can render followers.
function Economy.UpdateFollowerAttribute(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local list = {}
	for _, entry in data.Creatures do
		if entry.Equipped then
			table.insert(list, {
				Id = entry.Id,
				Variant = entry.Variant,
				Power = Creatures.GetPower(entry.Id, entry.Variant, entry.Level),
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Power > b.Power
	end)
	local parts = {}
	for _, item in list do
		table.insert(parts, item.Id .. ":" .. item.Variant)
	end
	local value = table.concat(parts, ",")
	if player:GetAttribute("Followers") ~= value then
		player:SetAttribute("Followers", value)
	end
end

return Economy
