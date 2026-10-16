--[[
	The Wandering Merchant (inspired by Grow a Garden's restocking shops).

	Stock rerolls every 5 minutes from a clock-based seed, so it is identical in every server.
	Each player can buy up to the stock amount per restock. Prices scale with the
	cost of the egg in the player's best unlocked zone so items stay relevant all game.
]]

local Eggs = require(script.Parent.Eggs)
local Zones = require(script.Parent.Zones)

-- Id is an item from Shared/Items: buying one puts it in your Bag
export type MerchantItem = {
	Id: string,
	Name: string,
	Description: string,
	PriceInEggs: number,
	Chance: number,
	MaxStock: number,
}

local Merchant = {}

Merchant.Seed = 90_210
Merchant.RestockInterval = 300

Merchant.Items = {
	{
		Id = "LuckPotion",
		Name = "Luck Potion",
		Description = "x2 Rare+ odds for 10 min",
		PriceInEggs = 3,
		Chance = 0.7,
		MaxStock = 2,
	},
	{
		Id = "EssencePotion",
		Name = "Essence Potion",
		Description = "x2 Essence for 10 min",
		PriceInEggs = 3,
		Chance = 0.7,
		MaxStock = 2,
	},
	{
		Id = "SpeedPotion",
		Name = "Speed Potion",
		Description = "+30% walk speed for 10 min",
		PriceInEggs = 2,
		Chance = 0.6,
		MaxStock = 3,
	},
	{
		Id = "XPPotion",
		Name = "XP Potion",
		Description = "x2 creature XP for 10 min",
		PriceInEggs = 3,
		Chance = 0.5,
		MaxStock = 2,
	},
	{
		Id = "PetTreat",
		Name = "Pet Treat",
		Description = "+25 XP for every equipped creature",
		PriceInEggs = 1,
		Chance = 0.6,
		MaxStock = 5,
	},
	{
		Id = "PowerPotion",
		Name = "Power Potion",
		Description = "Creatures deal +50% damage for 10 min",
		PriceInEggs = 5,
		Chance = 0.35,
		MaxStock = 1,
	},
	{
		Id = "ShinyElixir",
		Name = "Shiny Elixir",
		Description = "x3 Shiny & Rainbow odds for 10 min",
		PriceInEggs = 6,
		Chance = 0.35,
		MaxStock = 1,
	},
	{
		Id = "MysteryGift",
		Name = "Mystery Gift",
		Description = "A random item. Could be anything!",
		PriceInEggs = 4,
		Chance = 0.4,
		MaxStock = 2,
	},
	{
		Id = "MysticEgg",
		Name = "Mystic Egg",
		Description = "Hatch your best zone's egg - guaranteed Rare or better!",
		PriceInEggs = 10,
		Chance = 0.2,
		MaxStock = 1,
	},
	{
		Id = "TreasureMap",
		Name = "Treasure Map",
		Description = "Hides a Lost Treasure in one of your realms",
		PriceInEggs = 8,
		Chance = 0.1,
		MaxStock = 1,
	},
} :: { MerchantItem }

function Merchant.GetItem(id: string): MerchantItem?
	for _, item in Merchant.Items do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function Merchant.GetSlot(t: number): number
	return t // Merchant.RestockInterval
end

function Merchant.NextRestockAt(t: number): number
	return (Merchant.GetSlot(t) + 1) * Merchant.RestockInterval
end

-- Returns { [itemId] = stock } for a restock slot. Always at least one item in stock.
function Merchant.GetStock(slot: number): { [string]: number }
	local rng = Random.new(Merchant.Seed + slot * 104729)
	local stock = {}
	local any = false
	for _, item in Merchant.Items do
		if rng:NextNumber() < item.Chance then
			stock[item.Id] = rng:NextInteger(1, item.MaxStock)
			any = true
		end
	end
	if not any then
		stock[Merchant.Items[1].Id] = 1
	end
	return stock
end

function Merchant.GetPrice(item: MerchantItem, bestZone: number): number
	local zone = Zones.Get(math.clamp(bestZone, 1, #Zones.List))
	local egg = zone and Eggs.Get(zone.EggId)
	local eggCost = if egg then egg.Cost else 100
	return math.floor(item.PriceInEggs * eggCost)
end

return Merchant
