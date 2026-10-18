--[[
	Every creature in the game. Power = how much damage it adds to each crystal hit.
	Variants (Shiny / Rainbow / Huge) multiply power, inspired by PS99's Gold/Rainbow/Huge pets
	and Grow a Garden's mutations.
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Champion" | "Exclusive"

export type CreatureDef = {
	Id: string,
	Name: string,
	Rarity: Rarity,
	Power: number,
	Color: Color3,
	Accent: Color3,
}

local Creatures = {}

Creatures.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(205, 205, 205), Size = 1.4 },
	Uncommon = { Order = 2, Color = Color3.fromRGB(95, 225, 115), Size = 1.6 },
	Rare = { Order = 3, Color = Color3.fromRGB(70, 155, 255), Size = 1.8 },
	Epic = { Order = 4, Color = Color3.fromRGB(185, 95, 255), Size = 2.1 },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 190, 40), Size = 2.5 },
	Mythic = { Order = 6, Color = Color3.fromRGB(255, 70, 115), Size = 3 },
	Champion = { Order = 7, Color = Color3.fromRGB(0, 255, 225), Size = 2.8 },
	Exclusive = { Order = 8, Color = Color3.fromRGB(255, 95, 200), Size = 2.6 }, -- Robux only (Shop)
}

-- Luck only boosts drops at or above this rarity
Creatures.LuckyRarityOrder = 3

Creatures.Variants = {
	Normal = { Order = 0, Multiplier = 1, Chance = 0, Prefix = "" },
	Shiny = { Order = 1, Multiplier = 2, Chance = 1 / 40, Prefix = "Shiny " },
	Rainbow = { Order = 2, Multiplier = 5, Chance = 1 / 400, Prefix = "Rainbow " },
	-- HUGE: the ultra-rare giant version (Scale = how much bigger it's drawn). Can't be fused into.
	Huge = { Order = 3, Multiplier = 12, Chance = 1 / 50000, Prefix = "HUGE ", Scale = 2.4 },
}
Creatures.HugeChance = Creatures.Variants.Huge.Chance

local rgb = Color3.fromRGB
local defs: { CreatureDef } = {
	-- Enchanted Meadow
	{
		Id = "GlowSprite",
		Name = "Glow Sprite",
		Rarity = "Common",
		Power = 1,
		Color = rgb(255, 245, 160),
		Accent = rgb(255, 255, 255),
	},
	{
		Id = "MossToad",
		Name = "Moss Toad",
		Rarity = "Common",
		Power = 2,
		Color = rgb(110, 170, 80),
		Accent = rgb(60, 110, 40),
	},
	{
		Id = "PixieMoth",
		Name = "Pixie Moth",
		Rarity = "Uncommon",
		Power = 4,
		Color = rgb(255, 170, 230),
		Accent = rgb(170, 120, 255),
	},
	{
		Id = "MoonRabbit",
		Name = "Moon Rabbit",
		Rarity = "Rare",
		Power = 9,
		Color = rgb(225, 230, 255),
		Accent = rgb(140, 160, 255),
	},
	{
		Id = "FaeDragonling",
		Name = "Fae Dragonling",
		Rarity = "Epic",
		Power = 25,
		Color = rgb(120, 255, 190),
		Accent = rgb(255, 140, 220),
	},
	-- Ember Rift
	{
		Id = "CinderImp",
		Name = "Cinder Imp",
		Rarity = "Common",
		Power = 12,
		Color = rgb(150, 60, 40),
		Accent = rgb(255, 120, 40),
	},
	{
		Id = "LavaSalamander",
		Name = "Lava Salamander",
		Rarity = "Uncommon",
		Power = 20,
		Color = rgb(255, 90, 30),
		Accent = rgb(255, 210, 60),
	},
	{
		Id = "EmberFox",
		Name = "Ember Fox",
		Rarity = "Rare",
		Power = 40,
		Color = rgb(255, 130, 50),
		Accent = rgb(255, 240, 200),
	},
	{
		Id = "FlameDrake",
		Name = "Flame Drake",
		Rarity = "Epic",
		Power = 90,
		Color = rgb(220, 40, 40),
		Accent = rgb(255, 170, 0),
	},
	{
		Id = "Phoenix",
		Name = "Phoenix",
		Rarity = "Legendary",
		Power = 250,
		Color = rgb(255, 160, 20),
		Accent = rgb(255, 60, 30),
	},
	-- Frostpeak
	{
		Id = "FrostPup",
		Name = "Frost Pup",
		Rarity = "Common",
		Power = 120,
		Color = rgb(200, 235, 255),
		Accent = rgb(120, 190, 255),
	},
	{
		Id = "IceWisp",
		Name = "Ice Wisp",
		Rarity = "Uncommon",
		Power = 200,
		Color = rgb(150, 230, 255),
		Accent = rgb(255, 255, 255),
	},
	{
		Id = "CrystalStag",
		Name = "Crystal Stag",
		Rarity = "Rare",
		Power = 400,
		Color = rgb(170, 210, 255),
		Accent = rgb(90, 140, 255),
	},
	{
		Id = "FrostWyrm",
		Name = "Frost Wyrm",
		Rarity = "Epic",
		Power = 900,
		Color = rgb(80, 150, 230),
		Accent = rgb(220, 250, 255),
	},
	{
		Id = "GlacialGriffin",
		Name = "Glacial Griffin",
		Rarity = "Legendary",
		Power = 2500,
		Color = rgb(235, 245, 255),
		Accent = rgb(60, 170, 255),
	},
	{
		Id = "AuroraKirin",
		Name = "Aurora Kirin",
		Rarity = "Mythic",
		Power = 8000,
		Color = rgb(130, 255, 200),
		Accent = rgb(200, 120, 255),
	},
	-- Sky Sanctum
	{
		Id = "StormOwl",
		Name = "Storm Owl",
		Rarity = "Common",
		Power = 1200,
		Color = rgb(150, 150, 190),
		Accent = rgb(255, 255, 120),
	},
	{
		Id = "CloudSerpent",
		Name = "Cloud Serpent",
		Rarity = "Uncommon",
		Power = 2000,
		Color = rgb(240, 245, 255),
		Accent = rgb(170, 200, 255),
	},
	{
		Id = "ThunderGriffin",
		Name = "Thunder Griffin",
		Rarity = "Rare",
		Power = 4000,
		Color = rgb(255, 225, 90),
		Accent = rgb(90, 90, 160),
	},
	{
		Id = "CelestialPegasus",
		Name = "Celestial Pegasus",
		Rarity = "Epic",
		Power = 9000,
		Color = rgb(255, 250, 235),
		Accent = rgb(255, 210, 120),
	},
	{
		Id = "StarDragon",
		Name = "Star Dragon",
		Rarity = "Legendary",
		Power = 25000,
		Color = rgb(70, 60, 160),
		Accent = rgb(255, 230, 120),
	},
	{
		Id = "VoidLeviathan",
		Name = "Void Leviathan",
		Rarity = "Mythic",
		Power = 90000,
		Color = rgb(85, 35, 140),
		Accent = rgb(200, 90, 255),
	},
	-- Starfall Desert (realm 5, needs 1 Rebirth)
	{
		Id = "DuneScarab",
		Name = "Dune Scarab",
		Rarity = "Common",
		Power = 30000,
		Color = rgb(215, 170, 90),
		Accent = rgb(80, 200, 255),
	},
	{
		Id = "MirageJackal",
		Name = "Mirage Jackal",
		Rarity = "Uncommon",
		Power = 50000,
		Color = rgb(240, 215, 160),
		Accent = rgb(255, 130, 220),
	},
	{
		Id = "SandWyrm",
		Name = "Sand Wyrm",
		Rarity = "Rare",
		Power = 100000,
		Color = rgb(200, 150, 80),
		Accent = rgb(255, 230, 120),
	},
	{
		Id = "CometHawk",
		Name = "Comet Hawk",
		Rarity = "Epic",
		Power = 220000,
		Color = rgb(90, 70, 150),
		Accent = rgb(255, 170, 230),
	},
	{
		Id = "SphinxGuardian",
		Name = "Sphinx Guardian",
		Rarity = "Legendary",
		Power = 600000,
		Color = rgb(245, 205, 110),
		Accent = rgb(60, 180, 255),
	},
	{
		Id = "StarfallColossus",
		Name = "Starfall Colossus",
		Rarity = "Mythic",
		Power = 2200000,
		Color = rgb(120, 60, 170),
		Accent = rgb(255, 215, 120),
	},
	-- Void Abyss (realm 6, needs 3 Rebirths)
	{
		Id = "VoidMoth",
		Name = "Void Moth",
		Rarity = "Common",
		Power = 750000,
		Color = rgb(70, 45, 110),
		Accent = rgb(200, 120, 255),
	},
	{
		Id = "ShadowLynx",
		Name = "Shadow Lynx",
		Rarity = "Uncommon",
		Power = 1300000,
		Color = rgb(40, 35, 60),
		Accent = rgb(140, 255, 220),
	},
	{
		Id = "EclipseRaven",
		Name = "Eclipse Raven",
		Rarity = "Rare",
		Power = 2600000,
		Color = rgb(25, 20, 40),
		Accent = rgb(255, 150, 60),
	},
	{
		Id = "NetherWyvern",
		Name = "Nether Wyvern",
		Rarity = "Epic",
		Power = 5500000,
		Color = rgb(90, 20, 80),
		Accent = rgb(120, 255, 160),
	},
	{
		Id = "AbyssalKraken",
		Name = "Abyssal Kraken",
		Rarity = "Legendary",
		Power = 15000000,
		Color = rgb(30, 60, 110),
		Accent = rgb(255, 80, 200),
	},
	{
		Id = "EternityPhoenix",
		Name = "Eternity Phoenix",
		Rarity = "Mythic",
		Power = 55000000,
		Color = rgb(20, 20, 45),
		Accent = rgb(170, 110, 255),
	},
	-- Champion Egg (Trophies only - the competitive reward track)
	{
		Id = "ArenaBasilisk",
		Name = "Arena Basilisk",
		Rarity = "Champion",
		Power = 60,
		Color = rgb(60, 200, 120),
		Accent = rgb(255, 230, 80),
	},
	{
		Id = "GladiatorManticore",
		Name = "Gladiator Manticore",
		Rarity = "Champion",
		Power = 1500,
		Color = rgb(200, 120, 60),
		Accent = rgb(255, 60, 60),
	},
	{
		Id = "TitanUnicorn",
		Name = "Titan Unicorn",
		Rarity = "Champion",
		Power = 40000,
		Color = rgb(255, 255, 255),
		Accent = rgb(0, 255, 225),
	},
	-- Robux exclusive (Shop developer product, see Config.DevProducts) - never drops from eggs
	{
		Id = "NebulaKitsune",
		Name = "Nebula Kitsune",
		Rarity = "Exclusive",
		Power = 60000,
		Color = rgb(245, 238, 255),
		Accent = rgb(110, 190, 255),
	},
}

Creatures.List = {} :: { [string]: CreatureDef }
Creatures.Ordered = defs

for _, def in defs do
	Creatures.List[def.Id] = def
end

function Creatures.Get(id: string): CreatureDef?
	return Creatures.List[id]
end

function Creatures.RarityOrder(id: string): number
	local def = Creatures.List[id]
	return if def then Creatures.Rarities[def.Rarity].Order else 0
end

-- Levels: equipped creatures earn XP when crystals break; each level adds PowerPerLevel power
Creatures.MaxLevel = 25
Creatures.PowerPerLevel = 0.04

function Creatures.XPToNext(level: number): number
	return math.floor(8 * level ^ 1.5)
end

function Creatures.LevelMultiplier(level: number?): number
	return 1 + (math.clamp(level or 1, 1, Creatures.MaxLevel) - 1) * Creatures.PowerPerLevel
end

function Creatures.GetPower(id: string, variant: string?, level: number?): number
	local def = Creatures.List[id]
	if not def then
		return 0
	end
	local v = Creatures.Variants[variant or "Normal"] or Creatures.Variants.Normal
	return def.Power * v.Multiplier * Creatures.LevelMultiplier(level)
end

function Creatures.DisplayName(id: string, variant: string?): string
	local def = Creatures.List[id]
	if not def then
		return "???"
	end
	local v = Creatures.Variants[variant or "Normal"] or Creatures.Variants.Normal
	return v.Prefix .. def.Name
end

-- Fusion: this many of the same creature + variant fuse into one of the next variant
Creatures.FuseCost = 5
Creatures.FuseNext = { Normal = "Shiny", Shiny = "Rainbow" }

-- Rolls a variant. shinyMultiplier boosts both Shiny and Rainbow odds.
function Creatures.RollVariant(rng: Random, shinyMultiplier: number): string
	local roll = rng:NextNumber()
	local huge = Creatures.Variants.Huge.Chance * shinyMultiplier
	local rainbow = Creatures.Variants.Rainbow.Chance * shinyMultiplier
	local shiny = Creatures.Variants.Shiny.Chance * shinyMultiplier
	if roll < huge then
		return "Huge"
	end
	roll -= huge
	if roll < rainbow then
		return "Rainbow"
	elseif roll < rainbow + shiny then
		return "Shiny"
	end
	return "Normal"
end

return Creatures
