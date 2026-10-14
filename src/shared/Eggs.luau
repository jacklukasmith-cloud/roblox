--[[
	Eggs and their drop tables. Chances are relative weights (they don't have to add up to 100).
	Odds are shown on a billboard above every egg - transparency keeps players (and Roblox's
	paid random item rules) happy.
]]

local Creatures = require(script.Parent.Creatures)

export type Drop = { Creature: string, Chance: number }
export type EggDef = {
	Id: string,
	Name: string,
	Zone: number, -- 0 = hub
	Cost: number,
	Currency: "Essence" | "Trophies",
	Color: Color3,
	Drops: { Drop },
}

local rgb = Color3.fromRGB

local Eggs = {}

Eggs.Order = { "MeadowEgg", "EmberEgg", "FrostEgg", "SkyEgg", "ChampionEgg" }

Eggs.List = {
	MeadowEgg = {
		Id = "MeadowEgg",
		Name = "Meadow Egg",
		Zone = 1,
		Cost = 60,
		Currency = "Essence",
		Color = rgb(160, 255, 170),
		Drops = {
			{ Creature = "GlowSprite", Chance = 55 },
			{ Creature = "MossToad", Chance = 30 },
			{ Creature = "PixieMoth", Chance = 12 },
			{ Creature = "MoonRabbit", Chance = 2.7 },
			{ Creature = "FaeDragonling", Chance = 0.3 },
		},
	},
	EmberEgg = {
		Id = "EmberEgg",
		Name = "Ember Egg",
		Zone = 2,
		Cost = 1500,
		Currency = "Essence",
		Color = rgb(255, 110, 40),
		Drops = {
			{ Creature = "CinderImp", Chance = 50 },
			{ Creature = "LavaSalamander", Chance = 32 },
			{ Creature = "EmberFox", Chance = 14 },
			{ Creature = "FlameDrake", Chance = 3.7 },
			{ Creature = "Phoenix", Chance = 0.3 },
		},
	},
	FrostEgg = {
		Id = "FrostEgg",
		Name = "Frost Egg",
		Zone = 3,
		Cost = 35000,
		Currency = "Essence",
		Color = rgb(150, 215, 255),
		Drops = {
			{ Creature = "FrostPup", Chance = 50 },
			{ Creature = "IceWisp", Chance = 32 },
			{ Creature = "CrystalStag", Chance = 14 },
			{ Creature = "FrostWyrm", Chance = 3.6 },
			{ Creature = "GlacialGriffin", Chance = 0.38 },
			{ Creature = "AuroraKirin", Chance = 0.02 },
		},
	},
	SkyEgg = {
		Id = "SkyEgg",
		Name = "Sky Egg",
		Zone = 4,
		Cost = 900000,
		Currency = "Essence",
		Color = rgb(255, 235, 150),
		Drops = {
			{ Creature = "StormOwl", Chance = 50 },
			{ Creature = "CloudSerpent", Chance = 32 },
			{ Creature = "ThunderGriffin", Chance = 14 },
			{ Creature = "CelestialPegasus", Chance = 3.6 },
			{ Creature = "StarDragon", Chance = 0.38 },
			{ Creature = "VoidLeviathan", Chance = 0.02 },
		},
	},
	ChampionEgg = {
		Id = "ChampionEgg",
		Name = "Champion Egg",
		Zone = 0,
		Cost = 15,
		Currency = "Trophies",
		Color = rgb(0, 255, 225),
		Drops = {
			{ Creature = "ArenaBasilisk", Chance = 70 },
			{ Creature = "GladiatorManticore", Chance = 25 },
			{ Creature = "TitanUnicorn", Chance = 5 },
		},
	},
} :: { [string]: EggDef }

function Eggs.Get(id: string): EggDef?
	return Eggs.List[id]
end

-- Weights after luck is applied. Luck multiplies the weight of Rare-and-above drops.
function Eggs.GetWeights(egg: EggDef, luck: number): ({ number }, number)
	local weights = {}
	local total = 0
	for i, drop in egg.Drops do
		local w = drop.Chance
		if Creatures.RarityOrder(drop.Creature) >= Creatures.LuckyRarityOrder then
			w *= luck
		end
		weights[i] = w
		total += w
	end
	return weights, total
end

-- Returns chance (0-1) of each drop for display, with luck applied.
function Eggs.GetOdds(egg: EggDef, luck: number): { number }
	local weights, total = Eggs.GetWeights(egg, luck)
	local odds = {}
	for i, w in weights do
		odds[i] = w / total
	end
	return odds
end

-- minRarityOrder lets merchant "Mystic" hatches guarantee a Rare or better.
function Eggs.Roll(egg: EggDef, luck: number, rng: Random, minRarityOrder: number?): string
	local weights, total = Eggs.GetWeights(egg, luck)
	if minRarityOrder then
		total = 0
		for i, drop in egg.Drops do
			if Creatures.RarityOrder(drop.Creature) < minRarityOrder then
				weights[i] = 0
			end
			total += weights[i]
		end
	end
	local roll = rng:NextNumber() * total
	for i, w in weights do
		roll -= w
		if roll <= 0 and w > 0 then
			return egg.Drops[i].Creature
		end
	end
	return egg.Drops[#egg.Drops].Creature
end

-- The egg a creature hatches from (first match), for showing the right egg colour
function Eggs.EggFor(creatureId: string): string
	for _, id in Eggs.Order do
		local egg = Eggs.Get(id)
		if egg then
			for _, drop in egg.Drops do
				if drop.Creature == creatureId then
					return id
				end
			end
		end
	end
	return Eggs.Order[1]
end

return Eggs
