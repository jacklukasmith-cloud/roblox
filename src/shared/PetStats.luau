--[[
	Creature combat stats beyond Power:

	Speed: how fast a creature attacks (and flies to its target). From its rarity, +2% per level.
	  Team damage per tick = sum of (Power x Speed); travel time = base / the team's average Speed.

	Abilities: every creature has one, from the realm its egg is in. Rarer creatures get stronger
	versions (Strength grows with rarity order).
	  LuckyFind    (Meadow)    chance per break to double that break's Essence
	  FireBurst    (Ember)     every Cooldown s: a burst of Mult x its Power
	  FrostShatter (Frost)     every Cooldown s: the target takes +Bonus damage from everyone for Duration s
	  StormStrike  (Sky)       every Cooldown s: lightning hits up to 2 other nearby crystals for Mult x Power
	  Rally        (Champion)  always: +Bonus damage for your whole team
	  SpiritFlame  (Exclusive) every Cooldown s: a big burst of Mult x its Power
]]

local Shared = script.Parent
local Creatures = require(Shared.Creatures)
local Eggs = require(Shared.Eggs)

local PetStats = {}

PetStats.RaritySpeed = {
	Common = 1,
	Uncommon = 1.1,
	Rare = 1.2,
	Epic = 1.35,
	Legendary = 1.5,
	Mythic = 1.7,
	Champion = 1.6,
	Exclusive = 1.8,
}
PetStats.SpeedPerLevel = 0.02

export type Ability = {
	Kind: string,
	Name: string,
	Icon: string,
	Cooldown: number?, -- seconds (nil = passive)
	Mult: number?, -- x the creature's Power
	Bonus: number?, -- fraction (0.3 = +30%)
	Chance: number?,
	Duration: number?,
	Description: string,
	Short: string, -- fits one line on the stats card
}

local BY_EGG = {
	MeadowEgg = "LuckyFind",
	EmberEgg = "FireBurst",
	FrostEgg = "FrostShatter",
	SkyEgg = "StormStrike",
	ChampionEgg = "Rally",
}

function PetStats.Speed(id: string, level: number?): number
	local def = Creatures.Get(id)
	if not def then
		return 1
	end
	local base = PetStats.RaritySpeed[def.Rarity] or 1
	return base * (1 + (math.max(level or 1, 1) - 1) * PetStats.SpeedPerLevel)
end

local function fmt(n: number): string
	return tostring(math.floor(n * 10 + 0.5) / 10)
end

local cache: { [string]: Ability | false } = {}

local function build(id: string): Ability?
	local def = Creatures.Get(id)
	if not def then
		return nil
	end
	local order = Creatures.Rarities[def.Rarity].Order
	local kind = if def.Rarity == "Exclusive" then "SpiritFlame" else BY_EGG[Eggs.EggFor(id)]
	if kind == "LuckyFind" then
		local chance = 0.06 + 0.02 * order
		return {
			Kind = kind,
			Name = "Lucky Find",
			Icon = "🍀",
			Chance = chance,
			Description = `{math.floor(chance * 100 + 0.5)}% chance to double a break's Essence`,
			Short = `{math.floor(chance * 100 + 0.5)}% chance of x2 Essence`,
		}
	elseif kind == "FireBurst" then
		local mult = 2.5 + 0.5 * order
		return {
			Kind = kind,
			Name = "Fire Burst",
			Icon = "🔥",
			Cooldown = 9,
			Mult = mult,
			Description = `Every 9s: a burst of {fmt(mult)}x its Power`,
			Short = `{fmt(mult)}x burst every 9s`,
		}
	elseif kind == "FrostShatter" then
		local bonus = 0.2 + 0.03 * order
		return {
			Kind = kind,
			Name = "Frost Shatter",
			Icon = "❄️",
			Cooldown = 12,
			Bonus = bonus,
			Duration = 4,
			Description = `Every 12s: the target takes +{math.floor(bonus * 100 + 0.5)}% damage for 4s`,
			Short = `target takes +{math.floor(bonus * 100 + 0.5)}% dmg, every 12s`,
		}
	elseif kind == "StormStrike" then
		local mult = 1.5 + 0.3 * order
		return {
			Kind = kind,
			Name = "Storm Strike",
			Icon = "⚡",
			Cooldown = 8,
			Mult = mult,
			Description = `Every 8s: lightning hits 2 nearby crystals for {fmt(mult)}x its Power`,
			Short = `{fmt(mult)}x to 2 nearby, every 8s`,
		}
	elseif kind == "Rally" then
		local bonus = 0.04 + 0.01 * order
		return {
			Kind = kind,
			Name = "Rally",
			Icon = "🏆",
			Bonus = bonus,
			Description = `Always: +{math.floor(bonus * 100 + 0.5)}% damage for your whole team`,
			Short = `+{math.floor(bonus * 100 + 0.5)}% team damage`,
		}
	elseif kind == "SpiritFlame" then
		return {
			Kind = kind,
			Name = "Spirit Flame",
			Icon = "🌌",
			Cooldown = 6,
			Mult = 8,
			Description = "Every 6s: a spirit-flame burst of 8x its Power",
			Short = "8x burst every 6s",
		}
	end
	return nil
end

function PetStats.Ability(id: string): Ability?
	local cached = cache[id]
	if cached == nil then
		cached = build(id) or false
		cache[id] = cached
	end
	return cached or nil
end

return PetStats
