--[[
	Sanctuary (player bases): every player gets a floating sky island in their server. Islands sit in
	a ring high above and behind the hub's Portal Plaza. Level 1-10 (upgraded with Essence) makes the
	island bigger and unlocks the stations (see docs/EXPANSION_PLAN.md).
]]

local Sanctuary = {}

Sanctuary.Center = Vector3.new(0, 260, -460) -- middle of the ring of islands
Sanctuary.RingRadius = 270
Sanctuary.Slots = 12 -- islands per server (one per player)
Sanctuary.MaxLevel = 10

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
-- the radius). Built in later steps; for now they're marked "coming soon".
Sanctuary.Stations = {
	{ Id = "PetHabitat", Name = "Pet Habitat", Icon = "🐾", Spot = Vector2.new(-0.5, -0.45) },
	{ Id = "Cauldron", Name = "Alchemy Cauldron", Icon = "⚗️", Spot = Vector2.new(0.5, -0.45) },
	{ Id = "Hangar", Name = "Hangar", Icon = "🛹", Spot = Vector2.new(-0.5, 0.45) },
	{ Id = "Vault", Name = "Crystal Vault", Icon = "💎", Spot = Vector2.new(0.5, 0.45) },
}

return Sanctuary
