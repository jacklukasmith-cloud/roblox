--[[
	Egg hatching and the Wandering Merchant shop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local Eggs = require(Shared.Eggs)
local Zones = require(Shared.Zones)
local Merchant = require(Shared.Merchant)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local DailyRewards = require(script.Parent.DailyRewards)
local Monetization = require(script.Parent.Monetization)
local WorldService = require(script.Parent.WorldService)

local Hatching = {}

local rng = Random.new()
local notify = Remotes.Event("Notify")
local hatchResult = Remotes.Event("HatchResult")
local lastHatch: { [Player]: number } = {}

local function addCreature(player: Player, data: PlayerData.Data, creatureId: string)
	local variant = Creatures.RollVariant(rng, Economy.GetShinyMultiplier(data))
	local uid = PlayerData.NewCreature(data, creatureId, variant)
	local isNew = not data.Bestiary[creatureId]
	data.Bestiary[creatureId] = true
	data.Stats.CreaturesHatched += 1
	DailyRewards.Track(player, "HatchEggs", 1)
	local def = Creatures.Get(creatureId)
	if def and Creatures.Rarities[def.Rarity].Order >= 3 then
		DailyRewards.Track(player, "HatchRare", 1)
	end
	-- Auto-equip into a free slot
	local _, equipped = PlayerData.CountCreatures(data)
	if equipped < Economy.GetEquipSlots(player) then
		data.Creatures[uid].Equipped = true
	end
	return { Id = creatureId, Variant = variant, New = isNew }
end

local function announceRare(player: Player, result)
	local def = Creatures.Get(result.Id)
	if not def then
		return
	end
	local order = Creatures.Rarities[def.Rarity].Order
	if order >= 5 or result.Variant == "Rainbow" then
		-- Server-wide shout-outs for big pulls (social proof, like PS99's hatch announcements)
		for _, other in game:GetService("Players"):GetPlayers() do
			notify:FireClient(
				other,
				`{player.DisplayName} hatched a {Creatures.DisplayName(result.Id, result.Variant)}!`,
				Creatures.Rarities[def.Rarity].Color
			)
		end
	end
end

function Hatching.Hatch(player: Player, eggId: string, count: number): (boolean, string?)
	local egg = Eggs.Get(eggId)
	local data = PlayerData.Get(player)
	if not egg or not data then
		return false, "Unknown egg"
	end
	local now = os.clock()
	if now - (lastHatch[player] or 0) < 0.8 then
		return false, nil
	end
	lastHatch[player] = now
	if count == 3 and not Monetization.Owns(player, "TripleHatch") then
		Monetization.PromptPass(player, "TripleHatch")
		return false, "Triple Hatch is a game pass"
	end
	count = if count == 3 then 3 else 1
	if egg.Zone > data.ZonesUnlocked then
		return false, "Unlock this zone first"
	end
	local total = PlayerData.CountCreatures(data)
	if total + count > Config.MaxInventory then
		return false, "Your creature storage is full - release some creatures"
	end
	local cost = egg.Cost * count
	local balance = if egg.Currency == "Trophies" then data.Trophies else data.Essence
	if balance < cost then
		return false, `You need {Format.Number(cost)} {egg.Currency}`
	end
	if egg.Currency == "Trophies" then
		data.Trophies -= cost
	else
		data.Essence -= cost
	end
	local luck = Economy.GetLuck(player, data)
	local results = {}
	for _ = 1, count do
		local result = addCreature(player, data, Eggs.Roll(egg, luck, rng))
		table.insert(results, result)
		announceRare(player, result)
	end
	PlayerData.MarkChanged(player)
	hatchResult:FireClient(player, eggId, results)
	return true
end

function Hatching.BuyMerchantItem(player: Player, itemId: string): (boolean, string?)
	local data = PlayerData.Get(player)
	local item = Merchant.GetItem(itemId)
	if not data or not item then
		return false, "Unknown item"
	end
	local merchant = WorldService.GetMerchant()
	if data.Merchant.Slot ~= merchant.Slot then
		data.Merchant = { Slot = merchant.Slot, Bought = {} }
	end
	local stock = merchant.Stock[itemId] or 0
	local bought = data.Merchant.Bought[itemId] or 0
	if bought >= stock then
		return false, "Sold out! The merchant restocks soon."
	end
	local price = Merchant.GetPrice(item, data.ZonesUnlocked)
	if data.Essence < price then
		return false, `You need {Format.Number(price)} Essence`
	end
	if item.Kind == "MysticHatch" then
		local total = PlayerData.CountCreatures(data)
		if total >= Config.MaxInventory then
			return false, "Your creature storage is full"
		end
	end
	data.Essence -= price
	data.Merchant.Bought[itemId] = bought + 1
	DailyRewards.Track(player, "BuyMerchant", 1)
	if item.Kind == "Boost" then
		Economy.AddBoost(player, item.Boost :: string, item.Seconds :: number)
		notify:FireClient(player, `{item.Name} activated!`, Color3.fromRGB(120, 255, 160))
	else
		Hatching.MysticHatch(player)
	end
	PlayerData.MarkChanged(player)
	return true
end

-- Hatch your best zone's egg with a guaranteed Rare or better (Mystic Egg). Returns false if
-- storage is full.
function Hatching.MysticHatch(player: Player): boolean
	local data = PlayerData.Get(player)
	if not data or PlayerData.CountCreatures(data) >= Config.MaxInventory then
		return false
	end
	local zone = Zones.Get(data.ZonesUnlocked) or Zones.List[1]
	local egg = Eggs.Get(zone.EggId) :: Eggs.EggDef
	local creatureId = Eggs.Roll(egg, Economy.GetLuck(player, data), rng, Creatures.LuckyRarityOrder)
	local result = addCreature(player, data, creatureId)
	announceRare(player, result)
	PlayerData.MarkChanged(player)
	hatchResult:FireClient(player, egg.Id, { result })
	return true
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastHatch[player] = nil
end)

return Hatching
