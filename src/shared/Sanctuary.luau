--[[
	Sanctuary (player bases): every player gets a floating sky island in their server. Islands sit in
	a ring high above and behind the hub's Portal Plaza. Level 1-10 (upgraded with Essence) makes the
	island bigger and unlocks the stations (see docs/EXPANSION_PLAN.md).
]]

local Sanctuary = {}

Sanctuary.Center = Vector3.new(0, 260, -460) -- middle of the ring of islands
Sanctuary.RingRadius = 200
Sanctuary.Slots = 8 -- islands per server (one per player; set the place's Max Players to 8 to match)
Sanctuary.MaxLevel = 10

-- Upgrading is meant to be a long goal: each level costs 10x the one before
Sanctuary.BaseCost = 2000 -- Essence for level 2
Sanctuary.CostGrowth = 10
Sanctuary.EssencePerLevel = 0.02 -- +2% Essence for every level above 1 (+18% at level 10)

-- Essence to go from level to level + 1 (nil at max level)
function Sanctuary.UpgradeCost(level: number): number?
	if level >= Sanctuary.MaxLevel then
		return nil
	end
	return Sanctuary.BaseCost * Sanctuary.CostGrowth ^ (math.max(level, 1) - 1)
end

-- Essence multiplier from the island's level
function Sanctuary.EssenceBonus(level: number): number
	return 1 + Sanctuary.EssencePerLevel * (math.clamp(level, 1, Sanctuary.MaxLevel) - 1)
end

-- Pet Habitat: unequipped pets you put here wander your island and earn XP, even while you're away
Sanctuary.HabitatXPPerMinute = 2
Sanctuary.HabitatOfflineHours = 8 -- the most XP time you can bank while offline

-- How many pets the habitat holds: 2, then one more every 2 levels (6 at level 9)
function Sanctuary.HabitatSlots(level: number): number
	return 2 + math.floor((math.clamp(level, 1, Sanctuary.MaxLevel) - 1) / 2)
end

-- "Id:Variant,Id:Variant" for the habitat pets in a save (the island model carries it so every
-- client can draw them)
function Sanctuary.HabitatKey(data: any): string
	local parts = {}
	local sanctuary = data and data.Sanctuary
	for _, uid in sanctuary and sanctuary.Habitat or {} do
		local entry = data.Creatures and data.Creatures[uid]
		if entry then
			table.insert(parts, `{entry.Id}:{entry.Variant or "Normal"}`)
		end
	end
	return table.concat(parts, ",")
end

-- Crystal Vault: holds the Gloom Crystals you send home from the Gloomwood
function Sanctuary.VaultCapacity(level: number): number
	return 200 + 100 * (math.clamp(level, 1, Sanctuary.MaxLevel) - 1)
end

-- Island size by level (studs, radius of the grass top)
function Sanctuary.Radius(level: number): number
	return 30 + 3 * (math.clamp(level, 1, Sanctuary.MaxLevel) - 1)
end

-- Where island number slot (1..Slots) floats
function Sanctuary.SlotPosition(slot: number): Vector3
	local angle = (slot - 1) / Sanctuary.Slots * math.pi * 2
	return Sanctuary.Center
		+ Vector3.new(math.sin(angle) * Sanctuary.RingRadius, 0, math.cos(angle) * Sanctuary.RingRadius)
end

-- The four stations and the spots they'll stand on (offsets from the island centre, as a fraction of
-- the radius). The Pet Habitat and Crystal Vault are built; the others are marked "coming soon" for now.
Sanctuary.Stations = {
	{ Id = "PetHabitat", Name = "Pet Habitat", Icon = "🐾", Spot = Vector2.new(-0.5, -0.45) },
	{ Id = "Cauldron", Name = "Alchemy Cauldron", Icon = "⚗️", Spot = Vector2.new(0.5, -0.45) },
	{ Id = "Hangar", Name = "Hangar", Icon = "🛹", Spot = Vector2.new(-0.5, 0.45) },
	{ Id = "Vault", Name = "Crystal Vault", Icon = "💎", Spot = Vector2.new(0.5, 0.45) },
}

return Sanctuary
