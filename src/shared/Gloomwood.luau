--[[
	The Gloomwood: a huge, foggy forest reached through the gate in the hub's Portal Plaza (needs
	Frostpeak). Explore it for Gloom Crystals, mine them with your pickaxe, and send them home to your
	Sanctuary's Crystal Vault at a Courier Lantern before the Gloom meter fills up.

	The forest is a big disc of rings (distance from its centre):
	  Edge     RingEdge..Radius      light fog, many lanterns, Moonshards
	  Midwood  RingMid..RingEdge     thicker fog, the burnt clearing, frozen pond and Deep Camp
	  Deepwood RingHeart..RingMid    very dark, cliffs and caves, few lanterns, the Gloom fills fast
	  The Heart ..RingHeart           the stone circle where the Prismheart grows, guarded by the Gloom Treant
	Map Fragments hidden around the forest fill in your map (the 🗺️ button on the forest pill).
]]

local Gloomwood = {}

Gloomwood.Center = Vector3.new(-6000, 0, -6000) -- far from the hub (and the islands) so it can't be seen from there
Gloomwood.Radius = 600
Gloomwood.RingEdge = 420 -- Edge is outside this, Midwood inside
Gloomwood.RingMid = 220 -- the Deepwood wall (with openings at Gloomwood.WallGaps)
Gloomwood.RingHeart = 70 -- the Heart
Gloomwood.WallGaps = { -0.35, 1.7, 3.0, 4.6 } -- angles of the openings in the thorn wall
Gloomwood.GapWidth = 0.14 -- radians (about 30 studs)
Gloomwood.UnlockZone = 3 -- Frostpeak must be unlocked

Gloomwood.SatchelSize = 20 -- crystals you can carry before sending them home
Gloomwood.LanternRadius = 12 -- stand this close to a lantern to send your satchel home
Gloomwood.Gloom = {
	Max = 100,
	Edge = 0.12, -- per second (about 14 minutes to fill)
	Midwood = 0.35, -- about 5 minutes
	Deepwood = 0.7, -- about 2.5 minutes
	Heart = 1.4, -- about 70 seconds
	Lantern = -4, -- standing by a lantern
	Outside = -10,
	Warn = 75, -- "the gloom is getting thick" warning
}

-- Where landmarks sit: angle (radians, 0 = the gate side) and distance from the centre
Gloomwood.Places = {
	Gate = { Angle = 0, Distance = 590 },
	DeepCamp = { Angle = 0.9, Distance = 300 },
	BurntClearing = { Angle = 2.2, Distance = 310 },
	FrozenPond = { Angle = -2.0, Distance = 330 },
	DeadTree = { Angle = math.pi, Distance = 480 },
	Watchtower = { Angle = -1.0, Distance = 500 },
}

-- Gloom Crystals. Hits = pickaxe swings to mine one (fewer with a better pickaxe). Sell = Essence
-- worth this many crystals of your best realm. Spots = how many hiding places, Active = how many
-- are out at once, Regrow = seconds before a mined one grows back somewhere else.
-- Near = only grows around that landmark.
Gloomwood.Crystals = {
	{
		Id = "Moonshard",
		Name = "Moonshard",
		Rarity = "Common",
		Color = Color3.fromRGB(170, 190, 255),
		Hits = 4,
		Sell = 3,
		Spots = 70,
		Active = 32,
		Regrow = 45,
	},
	{
		Id = "Emberheart",
		Name = "Emberheart",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(255, 120, 60),
		Hits = 8,
		Sell = 10,
		Spots = 16,
		Active = 5,
		Regrow = 90,
		Near = "BurntClearing",
	},
	{
		Id = "Frostglass",
		Name = "Frostglass",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(120, 230, 255),
		Hits = 8,
		Sell = 10,
		Spots = 16,
		Active = 5,
		Regrow = 90,
		Near = "FrozenPond",
	},
	{
		Id = "Stormquartz",
		Name = "Stormquartz",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 240, 120),
		Hits = 12,
		Sell = 40,
		Spots = 12, -- on top of the Deepwood cliffs (GloomwoodBuilder puts the spots there)
		Active = 4,
		Regrow = 150,
		Where = "Ledge",
	},
	{
		Id = "Voidstone",
		Name = "Voidstone",
		Rarity = "Epic",
		Color = Color3.fromRGB(150, 80, 255),
		Hits = 16,
		Sell = 120,
		Spots = 10, -- inside the Deepwood caves
		Active = 3,
		Regrow = 240,
		Where = "Cave",
	},
	{
		Id = "Prismheart",
		Name = "Prismheart",
		Rarity = "Legendary",
		Color = Color3.fromRGB(255, 255, 255),
		Hits = 30,
		Sell = 1000,
		Spots = 6, -- in the Heart; one grows at a time and the whole server hears about it
		Active = 1,
		Regrow = 600,
		Where = "Heart",
		Announce = true,
	},
}
-- Where the Map Fragments hide (angle, distance): finding one marks that part of the map
Gloomwood.Fragments = {
	{ Angle = 0.9, Distance = 300, Reveals = "DeepCamp" },
	{ Angle = 2.2, Distance = 345, Reveals = "BurntClearing" },
	{ Angle = -2.0, Distance = 365, Reveals = "FrozenPond" },
	{ Angle = math.pi, Distance = 500, Reveals = "DeadTree" },
	{ Angle = -1.0, Distance = 520, Reveals = "Watchtower" },
	{ Angle = 1.7, Distance = 150, Reveals = "Cliffs" },
	{ Angle = 4.6, Distance = 140, Reveals = "Caves" },
	{ Angle = 0.5, Distance = 40, Reveals = "Heart" },
}
Gloomwood.MapLanternsAt = 4 -- find this many fragments and the map shows every lantern

-- Forest animals. "Hostile" ones roam their ring and chase anyone who comes close (but never go
-- near a lantern: lanterns are safe). "Guardian" ones sleep next to a crystal (Chance = how many
-- crystals of the kinds in Guards get one) and only wake up when someone starts mining it.
-- A hit adds Gloom (and Steal = the chance to knock a crystal out of your satchel). You and your pets
-- can fight back: HP = pickaxe swings to beat one (your pets help). Leash = how far from where they
-- started they'll chase you. Drop = a crystal for everyone who helped beat it.
Gloomwood.Beasts = {
	{
		Id = "ShadowWolf",
		Name = "Shadow Wolf",
		Icon = "🐺",
		Kind = "Hostile",
		Ring = "Midwood",
		Count = 8,
		HP = 6,
		Speed = 13, -- a bit slower than you, so you can run
		Aggro = 32,
		Leash = 70,
		Reach = 4,
		Gloom = 8,
		Steal = 0.25,
		Cooldown = 1.6,
		XP = 15,
		Drop = "Moonshard",
		Respawn = 60,
	},
	{
		Id = "DuskBat",
		Name = "Dusk Bat",
		Icon = "🦇",
		Kind = "Hostile",
		Ring = "Edge",
		Count = 6,
		HP = 2,
		Speed = 15,
		Aggro = 22,
		Leash = 45,
		Reach = 4,
		Gloom = 3,
		Steal = 0,
		Cooldown = 1.3,
		XP = 6,
		Respawn = 45,
	},
	{
		Id = "CinderFox",
		Name = "Cinder Fox",
		Icon = "🦊",
		Kind = "Hostile",
		Ring = "Midwood",
		Near = "BurntClearing", -- lives round the Burnt Clearing
		Count = 4,
		HP = 4,
		Speed = 14,
		Aggro = 28,
		Leash = 55,
		Reach = 4,
		Gloom = 5,
		Steal = 0.5, -- sneaky: often snatches a crystal
		Cooldown = 1.4,
		XP = 12,
		Drop = "Emberheart",
		Respawn = 75,
	},
	{
		Id = "BrambleBoar",
		Name = "Bramble Boar",
		Icon = "🐗",
		Kind = "Guardian",
		Guards = { "Moonshard" },
		Chance = 0.2,
		HP = 5,
		Speed = 12,
		Leash = 40,
		Reach = 4,
		Gloom = 6,
		Steal = 0,
		Cooldown = 1.8,
		XP = 10,
	},
	{
		Id = "MossBear",
		Name = "Moss Bear",
		Icon = "🐻",
		Kind = "Guardian",
		Guards = { "Emberheart", "Frostglass" },
		Chance = 0.45,
		HP = 12,
		Speed = 11,
		Leash = 45,
		Reach = 6,
		Gloom = 12,
		Steal = 0,
		Cooldown = 2.2,
		XP = 30,
	},
	{
		Id = "ThicketSpider",
		Name = "Thicket Spider",
		Icon = "🕷️",
		Kind = "Guardian",
		Guards = { "Moonshard" },
		Chance = 0.15,
		HP = 3,
		Speed = 14,
		Leash = 35,
		Reach = 4,
		Gloom = 5,
		Steal = 0.15,
		Cooldown = 1.5,
		XP = 8,
	},
	{
		Id = "ShadowWisp",
		Name = "Shadow Wisp",
		Icon = "👻",
		Kind = "Hostile",
		Ring = "Deepwood",
		Count = 7,
		HP = 3,
		Speed = 14,
		Aggro = 30,
		Leash = 60,
		Reach = 4,
		Gloom = 2,
		Steal = 1, -- every touch drains a crystal from your satchel
		Cooldown = 1.2,
		XP = 10,
		Drop = "Moonshard",
		Respawn = 50,
	},
	{
		Id = "GloomTreant",
		Name = "Gloom Treant",
		Icon = "🌳",
		Kind = "Guardian",
		Guards = { "Prismheart" },
		Chance = 1,
		HP = 60, -- a boss: bring your pets
		Speed = 10,
		Leash = 90,
		Reach = 9,
		Gloom = 20,
		Steal = 0,
		Cooldown = 2.5,
		XP = 150,
		Drop = "Voidstone",
		Announce = true,
	},
	{
		Id = "FrostStag",
		Name = "Frost Stag",
		Icon = "🦌",
		Kind = "Guardian",
		Guards = { "Frostglass" },
		Chance = 0.4,
		HP = 9,
		Speed = 13,
		Leash = 45,
		Reach = 5,
		Gloom = 10,
		Steal = 0,
		Cooldown = 2,
		XP = 22,
	},
}
-- Beat this many animals (in total) for each Owl Eye Potion: see much further in the fog
Gloomwood.VisionPotionEvery = 5
Gloomwood.PetBeastDamage = 0.3 -- hits per second each equipped pet does to an animal
Gloomwood.PetBeastDamageMax = 2

function Gloomwood.GetBeast(id: string): any
	for _, beast in Gloomwood.Beasts do
		if beast.Id == id then
			return beast
		end
	end
	return nil
end

function Gloomwood.Get(id: string): any
	for _, crystal in Gloomwood.Crystals do
		if crystal.Id == id then
			return crystal
		end
	end
	return nil
end

-- A spot in the forest from an angle and distance
function Gloomwood.At(angle: number, distance: number, y: number?): Vector3
	return Gloomwood.Center + Vector3.new(math.sin(angle) * distance, y or 0, math.cos(angle) * distance)
end

function Gloomwood.Place(name: string, y: number?): Vector3
	local place = Gloomwood.Places[name]
	return Gloomwood.At(place.Angle, place.Distance, y)
end

-- Which ring a position is in: "Edge", "Midwood", "Deepwood" or nil (not in the forest)
function Gloomwood.RingAt(position: Vector3): string?
	local flat = (position - Gloomwood.Center) * Vector3.new(1, 0, 1)
	local d = flat.Magnitude
	if d > Gloomwood.Radius + 20 or position.Y > 120 or position.Y < -40 then
		return nil
	elseif d >= Gloomwood.RingEdge then
		return "Edge"
	elseif d >= Gloomwood.RingMid then
		return "Midwood"
	elseif d >= Gloomwood.RingHeart then
		return "Deepwood"
	end
	return "Heart"
end

-- Is this angle in one of the thorn wall's openings?
function Gloomwood.InGap(angle: number): boolean
	for _, gap in Gloomwood.WallGaps do
		local diff = math.abs((angle - gap + math.pi) % (math.pi * 2) - math.pi)
		if diff <= Gloomwood.GapWidth then
			return true
		end
	end
	return false
end

-- The nearest opening in the wall to a position
function Gloomwood.NearestGap(position: Vector3): Vector3
	local flat = (position - Gloomwood.Center) * Vector3.new(1, 0, 1)
	local angle = math.atan2(flat.X, flat.Z)
	local best, bestDiff = Gloomwood.WallGaps[1], math.huge
	for _, gap in Gloomwood.WallGaps do
		local diff = math.abs((angle - gap + math.pi) % (math.pi * 2) - math.pi)
		if diff < bestDiff then
			best, bestDiff = gap, diff
		end
	end
	return Gloomwood.At(best, Gloomwood.RingMid, 3)
end

-- How deep into the forest a position is: 0 at the outer edge, 1 at the very centre (the Heart).
-- The screen gets darker and foggier the deeper you go.
function Gloomwood.Depth(position: Vector3): number
	local d = ((position - Gloomwood.Center) * Vector3.new(1, 0, 1)).Magnitude
	return math.clamp(1 - d / Gloomwood.Radius, 0, 1)
end

-- Pickaxe damage per swing on a Gloom Crystal (a better pickaxe needs fewer swings)
function Gloomwood.SwingDamage(pickaxeTier: number, golden: boolean, goldenDamage: number): number
	return (1 + (math.max(pickaxeTier, 1) - 1) * 0.25) * (if golden then goldenDamage else 1)
end

function Gloomwood.SatchelCount(satchel: { [string]: number }?): number
	local n = 0
	for _, count in satchel or {} do
		n += count
	end
	return n
end

return Gloomwood
