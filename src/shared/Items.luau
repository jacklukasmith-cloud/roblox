--[[
	Everything that can go in a player's Bag (potions, treats, gifts...). Items are collected first
	and used later from the 🎒 Bag menu, so players choose when to drink a potion.

	Kind:
	  "Boost"    a timed boost (Config.Boosts): Boosts = { [name] = seconds }
	  "XP"       creature XP for every equipped creature right away: Amount
	  "Essence"  Essence worth CrystalRewards crystals of your best realm
	  "Mystic"   hatches your best realm's egg with a guaranteed Rare or better
	  "Gift"     opens into a random item from Loot (Pet Simulator 99's gifts)
	  "Treasure" hides a Lost Treasure in one of your realms (Treasure Map)
	  "Boss"     calls a boss right now (Boss Horn)

	Where items come from (see Config.ItemDrops and the services):
	  crystals (small chance), Mana Chests, bosses, Lost Treasures, the Wandering Merchant,
	  daily rewards, missions, hatching milestones and the shop.
]]

export type Item = {
	Id: string,
	Name: string,
	Icon: string,
	Color: Color3,
	Rarity: string, -- for the tile colour: Common / Uncommon / Rare / Epic / Legendary
	Description: string,
	Kind: string,
	Boosts: { [string]: number }?,
	Amount: number?,
	CrystalRewards: number?,
	Loot: { { Item: string, Weight: number, Count: number? } }?,
}

local rgb = Color3.fromRGB

local Items = {}

Items.MaxStack = 999

Items.List = {
	-- Potions -------------------------------------------------------------------------------
	{
		Id = "LuckPotion",
		Name = "Luck Potion",
		Icon = "🍀",
		Color = rgb(90, 220, 110),
		Rarity = "Uncommon",
		Description = "x2 chance of Rare+ creatures for 10 minutes",
		Kind = "Boost",
		Boosts = { Luck = 600 },
	},
	{
		Id = "EssencePotion",
		Name = "Essence Potion",
		Icon = "⚗️",
		Color = rgb(96, 232, 190),
		Rarity = "Uncommon",
		Description = "x2 Essence for 10 minutes",
		Kind = "Boost",
		Boosts = { Essence = 600 },
	},
	{
		Id = "ShinyElixir",
		Name = "Shiny Elixir",
		Icon = "✨",
		Color = rgb(255, 225, 110),
		Rarity = "Rare",
		Description = "x3 Shiny and Rainbow chance for 10 minutes",
		Kind = "Boost",
		Boosts = { Shiny = 600 },
	},
	{
		Id = "SpeedPotion",
		Name = "Speed Potion",
		Icon = "💨",
		Color = rgb(120, 200, 255),
		Rarity = "Common",
		Description = "+30% walk speed for 10 minutes",
		Kind = "Boost",
		Boosts = { Speed = 600 },
	},
	{
		Id = "PowerPotion",
		Name = "Power Potion",
		Icon = "💪",
		Color = rgb(255, 140, 100),
		Rarity = "Rare",
		Description = "Your creatures deal +50% damage for 10 minutes",
		Kind = "Boost",
		Boosts = { Power = 600 },
	},
	{
		Id = "XPPotion",
		Name = "XP Potion",
		Icon = "📈",
		Color = rgb(180, 140, 255),
		Rarity = "Uncommon",
		Description = "x2 creature XP for 10 minutes",
		Kind = "Boost",
		Boosts = { XP = 600 },
	},
	{
		Id = "RainbowBrew",
		Name = "Rainbow Brew",
		Icon = "🌈",
		Color = rgb(255, 120, 220),
		Rarity = "Legendary",
		Description = "Luck, Essence, Shiny and Power potions all at once, for 15 minutes",
		Kind = "Boost",
		Boosts = { Luck = 900, Essence = 900, Shiny = 900, Power = 900 },
	},
	-- Treats --------------------------------------------------------------------------------
	{
		Id = "PetTreat",
		Name = "Pet Treat",
		Icon = "🍪",
		Color = rgb(220, 170, 110),
		Rarity = "Common",
		Description = "+25 XP for each equipped creature",
		Kind = "XP",
		Amount = 25,
	},
	{
		Id = "GoldenTreat",
		Name = "Golden Treat",
		Icon = "🍯",
		Color = rgb(255, 200, 60),
		Rarity = "Epic",
		Description = "+150 XP for each equipped creature",
		Kind = "XP",
		Amount = 150,
	},
	-- Essence -------------------------------------------------------------------------------
	{
		Id = "EssenceBag",
		Name = "Essence Sack",
		Icon = "💰",
		Color = rgb(96, 232, 190),
		Rarity = "Common",
		Description = "Instant Essence (worth 30 crystals in your best realm)",
		Kind = "Essence",
		CrystalRewards = 30,
	},
	-- Eggs & gifts --------------------------------------------------------------------------
	{
		Id = "MysticEgg",
		Name = "Mystic Egg",
		Icon = "🥚",
		Color = rgb(185, 95, 255),
		Rarity = "Epic",
		Description = "Hatches your best realm's egg: guaranteed Rare or better!",
		Kind = "Mystic",
	},
	{
		Id = "MysteryGift",
		Name = "Mystery Gift",
		Icon = "🎁",
		Color = rgb(255, 110, 130),
		Rarity = "Rare",
		Description = "Open it for a random item. Could be anything!",
		Kind = "Gift",
		Loot = {
			{ Item = "PetTreat", Weight = 24, Count = 3 },
			{ Item = "EssenceBag", Weight = 20, Count = 2 },
			{ Item = "SpeedPotion", Weight = 14 },
			{ Item = "LuckPotion", Weight = 12 },
			{ Item = "EssencePotion", Weight = 12 },
			{ Item = "XPPotion", Weight = 8 },
			{ Item = "PowerPotion", Weight = 5 },
			{ Item = "ShinyElixir", Weight = 3 },
			{ Item = "GoldenTreat", Weight = 1.5 },
			{ Item = "MysticEgg", Weight = 0.4 },
			{ Item = "RainbowBrew", Weight = 0.1 },
		},
	},
	-- Special -------------------------------------------------------------------------------
	{
		Id = "TreasureMap",
		Name = "Treasure Map",
		Icon = "🗺️",
		Color = rgb(230, 190, 120),
		Rarity = "Epic",
		Description = "Hides a Lost Treasure in one of your realms right now",
		Kind = "Treasure",
	},
	{
		Id = "BossHorn",
		Name = "Boss Horn",
		Icon = "📯",
		Color = rgb(255, 90, 90),
		Rarity = "Legendary",
		Description = "Calls a boss to the server right now. Bring friends!",
		Kind = "Boss",
	},
} :: { Item }

local byId: { [string]: Item } = {}
for i, item in Items.List do
	byId[item.Id] = item;
	(item :: any).Order = i
end

function Items.Get(id: string): Item?
	return byId[id]
end

-- Picks one entry from a weighted loot table: (item id, count)
function Items.Roll(loot: { { Item: string, Weight: number, Count: number? } }, roll: number): (string, number)
	local total = 0
	for _, entry in loot do
		total += entry.Weight
	end
	local pick = roll * total
	for _, entry in loot do
		pick -= entry.Weight
		if pick <= 0 then
			return entry.Item, entry.Count or 1
		end
	end
	local last = loot[#loot]
	return last.Item, last.Count or 1
end

return Items
