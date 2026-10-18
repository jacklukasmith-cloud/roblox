--[[
	Builds the whole map from code, so the game is playable straight from `rojo build`.
	Swap any of this for hand-built models later - services only care about:
	  - crystal models passed to Crystals.Register
	  - egg / gate / house prompts wired up in Main
	  - the board parts in workspace.World.Hub (TrophyBoard, EssenceBoard, HouseBoard, SurgeObelisk)
	Parts/models with a "Spin" (rad/s) or "Bob" (studs) attribute are animated on the client.

	Layout (top-down, +Z goes "forward"):
	  Hub (spawn, boards, Houses, Merchant, Champion Egg) -> Meadow -> Ember -> Frost -> Sky
]]

local InsertService = game:GetService("InsertService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local Eggs = require(Shared.Eggs)
local Creatures = require(Shared.Creatures)
local CreatureModels = require(Shared.CreatureModels)
local Houses = require(Shared.Houses)
local Format = require(Shared.Format)

local WorldBuilder = {}

-- The map is laid out on a 100-stud-wide plan and then spread out by SPREAD: floors and realms
-- get bigger and every placed thing moves outwards (keeping its own size), so nothing is crammed.
local SPREAD = 1.35
local function sp(x: number, y: number, z: number): Vector3
	return Vector3.new(x * SPREAD, y, z * SPREAD)
end
local WIDTH = 100 * SPREAD
-- The hub is wider than the realms (Market Row in the west wing, the House Quarter in the east)
-- and reaches back behind the spawn (Portal Plaza). The realms still start at HUB_END.
local HUB_HALF = 80 * SPREAD
local HUB_START, HUB_END = -100 * SPREAD, 50 * SPREAD
local ZONE_LENGTH = 130 * SPREAD
local CRYSTALS_PER_ZONE = 10

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = rgb(255, 205, 80)
local STONE = rgb(95, 85, 120)

local rng = Random.new(2024) -- fixed seed = same layout every server

-- Helpers -----------------------------------------------------------------------------------

local function part(props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	if props.Shape then
		(p :: any).Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Parent" and k ~= "Shape" and k ~= "ClassName" and k ~= "Ellipsoid" then
			(p :: any)[k] = v
		end
	end
	if props.Ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = parent
	return p
end

-- A cylinder standing upright (Roblox cylinders lie along X by default)
local function column(
	parent: Instance,
	base: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- A flat disc lying on the ground
local function disc(
	parent: Instance,
	center: Vector3,
	diameter: number,
	thickness: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.Size = UDim2.fromScale(1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = l
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function billboard(adornee: BasePart, size: UDim2, offset: Vector3, maxDistance: number?): BillboardGui
	local b = Instance.new("BillboardGui")
	b.Size = size
	b.StudsOffsetWorldSpace = offset
	b.LightInfluence = 0
	b.MaxDistance = maxDistance or 120
	b.Adornee = adornee
	b.Parent = adornee
	return b
end

-- Imported 3D props (ReplicatedStorage.WorldMeshes) -----------------------------------------
-- A Model or MeshPart named after a prop (see WorldBuilder.MeshNames) replaces the built-in
-- version of that prop. Missing ones just keep the procedural look.
WorldBuilder.MeshNames = {
	-- pick-axe tools (one per tier + the Golden Pickaxe pass), used by Services/Pickaxe
	"PickaxeWooden",
	"PickaxeStone",
	"PickaxeCopper",
	"PickaxeIron",
	"PickaxeFrost",
	"PickaxeEmber",
	"PickaxeCrystal",
	"PickaxeEmerald",
	"PickaxeMythic",
	"PickaxeVoid",
	"PickaxeCelestial",
	"PickaxeGolden",
	"MeadowEgg",
	"EmberEgg",
	"FrostEgg",
	"SkyEgg",
	"ChampionEgg",
	"MeadowCrystal",
	"EmberCrystal",
	"FrostCrystal",
	"SkyCrystal",
	"ManaChest",
	"MerchantStall",
	"MagicTree",
	-- decorations (only placed when the model exists)
	"HubLamp",
	"FlowerPlanter",
	"Bench",
	"HubBanner",
	"GiantMushroom",
	"FlowerBush",
	"MossRock",
	"LavaRock",
	"CharredTree",
	"FireBrazier",
	"SnowyPine",
	"IceRock",
	"Snowman",
	"FloatingIsland",
	"RuinedColumn",
	"StarLantern",
	-- Sanctuary stations (Services/Sanctuaries)
	"AlchemyCauldron",
	-- Sanctuary Hangar and its vehicles (Services/Hangar): "Vehicle<vehicle id>"
	"Hangar",
	"VehicleMossBoard",
	"VehicleCrystalBoard",
	"VehiclePrismGlider",
	-- Gloom Crystals (Services/Gloomwood): "<crystal id>Crystal"
	"MoonshardCrystal",
	"EmberheartCrystal",
	"FrostglassCrystal",
	"StormquartzCrystal",
	"VoidstoneCrystal",
	"PrismheartCrystal",
}
local CRYSTAL_MESH = { "MeadowCrystal", "EmberCrystal", "FrostCrystal", "SkyCrystal" }

local function meshTemplate(name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild("WorldMeshes")
	local template = folder and folder:FindFirstChild(name)
	if template and (template:IsA("Model") or template:IsA("BasePart")) then
		return template
	end
	return nil
end

-- Places a scaled copy of a prop so its bounding box is `size` studs on its longest side
-- (or `height` tall when byHeight) and its bottom centre sits on `base`.
local function placeMesh(
	parent: Instance,
	name: string,
	base: CFrame,
	size: number,
	byHeight: boolean?,
	collide: boolean?
): Model?
	local template = meshTemplate(name)
	if not template then
		return nil
	end
	local model: Model
	if template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		template:Clone().Parent = model
	end
	model.Name = name .. "Mesh"
	-- optional attributes on the imported model: Yaw (degrees) to turn it, Scale to resize it
	local yaw = tonumber(template:GetAttribute("Yaw")) or 0
	size *= tonumber(template:GetAttribute("Scale")) or 1
	base *= CFrame.Angles(0, math.rad(yaw), 0)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide == true
			d.CanTouch = false
			d.Massless = true
		end
	end
	local _, extents = model:GetBoundingBox()
	local measure = if byHeight then extents.Y else math.max(extents.X, extents.Y, extents.Z)
	if measure > 0.01 then
		model:ScaleTo(model:GetScale() * size / measure)
	end
	-- put the bottom centre of the bounding box on `base`
	local boxCf, box = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local bottom = boxCf.Position - Vector3.new(0, box.Y / 2, 0)
	local offset = pivot.Position - bottom
	model:PivotTo(CFrame.new(base.Position + offset) * base.Rotation * pivot.Rotation)
	model.Parent = parent
	return model
end

-- Removes the built-in parts of a prop once a mesh replaces it. `keep` parts stay as invisible
-- anchors because gameplay uses them (hitbox, prompts, health bar, lights, particles); every
-- other built-in part is deleted. Parts inside `mesh` are left alone.
local function stripParts(root: Instance, keep: { BasePart }, mesh: Instance?)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and not table.find(keep, d) and not (mesh and d:IsDescendantOf(mesh)) then
			d:Destroy()
		end
	end
	for _, p in keep do
		p.Transparency = 1
	end
end

local function light(parent: Instance, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1
	l.Shadows = false
	l.Parent = parent
end

-- An invisible anchor that holds a light (for imported props that should glow)
local function glowAt(parent: Instance, position: Vector3, color: Color3, range: number)
	local anchor = part({
		Name = "Glow",
		Size = Vector3.one,
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
	light(anchor, color, range, 1.2)
end

-- Decorations along the edges of each realm (only when their model has been imported).
-- Size = height in studs (or longest side when ByLongest); Lift raises it off the ground.
type DecorDef = {
	Name: string,
	Count: number,
	Size: number,
	ByLongest: boolean?,
	Lift: number?,
	Bob: number?,
	Glow: Color3?,
}
local ZONE_DECOR: { [number]: { DecorDef } } = {
	[1] = {
		{ Name = "GiantMushroom", Count = 6, Size = 8 },
		{ Name = "FlowerBush", Count = 10, Size = 3.5 },
		{ Name = "MossRock", Count = 6, Size = 4 },
	},
	[2] = {
		{ Name = "LavaRock", Count = 8, Size = 4.5, Glow = Color3.fromRGB(255, 120, 40) },
		{ Name = "CharredTree", Count = 6, Size = 12 },
		{ Name = "FireBrazier", Count = 4, Size = 5.5, Glow = Color3.fromRGB(255, 160, 60) },
	},
	[3] = {
		{ Name = "SnowyPine", Count = 10, Size = 14 },
		{ Name = "IceRock", Count = 6, Size = 4.5 },
		{ Name = "Snowman", Count = 2, Size = 6 },
	},
	[4] = {
		{ Name = "FloatingIsland", Count = 4, Size = 9, ByLongest = true, Lift = 12, Bob = 1.2 },
		{ Name = "RuinedColumn", Count = 6, Size = 11 },
		{ Name = "StarLantern", Count = 6, Size = 8, Glow = Color3.fromRGB(255, 220, 120) },
	},
}

local function zoneStartZ(index: number): number
	return HUB_END + (index - 1) * ZONE_LENGTH
end

-- Random spot on the zone's sides, keeping the central lane (|x| < 15) clear
-- True when every decoration model for this realm has been imported (Meadow also needs MagicTree)
local function zoneDecorReady(zoneIndex: number): boolean
	local list = ZONE_DECOR[zoneIndex]
	if not list then
		return false
	end
	for _, d in list do
		if not meshTemplate(d.Name) then
			return false
		end
	end
	return zoneIndex ~= 1 or meshTemplate("MagicTree") ~= nil
end

local function placeZoneDecor(folder: Instance, zoneIndex: number, z0: number)
	local list = ZONE_DECOR[zoneIndex]
	if not list then
		return
	end
	-- own random stream, so adding models never shifts the rest of the layout
	local drng = Random.new(4242 + zoneIndex)
	for t, d in list do
		if not meshTemplate(d.Name) then
			continue
		end
		for i = 1, d.Count do
			local side = if (i + t) % 2 == 0 then -1 else 1
			-- outer strip (|x| 39-47 on the plan) stays clear of crystals, eggs and chests
			local x = side * drng:NextNumber(39, 47) * SPREAD
			local frac = (i - 1 + t / (#list + 1)) / d.Count
			local z = z0 + 10 + frac * (ZONE_LENGTH - 20) + drng:NextNumber(-3, 3)
			local base = CFrame.new(x, d.Lift or 0, z) * CFrame.Angles(0, drng:NextNumber(0, math.pi * 2), 0)
			local m = placeMesh(folder, d.Name, base, d.Size, not d.ByLongest)
			if m then
				if d.Bob then
					m:SetAttribute("Bob", d.Bob)
				end
				if d.Glow then
					glowAt(m, Vector3.new(x, (d.Lift or 0) + d.Size * 0.7, z), d.Glow, 14)
				end
			end
		end
	end
end

local function sideSpot(z0: number, length: number): Vector3
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	return Vector3.new(side * rng:NextNumber(16, WIDTH / 2 - 4), 0, rng:NextNumber(z0 + 6, z0 + length - 6))
end

local function ambientParticles(parent: Instance, center: Vector3, size: Vector3, color: Color3, kind: string)
	local emitterPart = part({
		Name = "Ambience",
		Size = size,
		Position = center,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = 8
	e.Lifetime = NumberRange.new(6, 10)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	if kind == "Rise" then
		e.Acceleration = Vector3.new(0, 1.5, 0)
	elseif kind == "Fall" then
		e.Color = ColorSequence.new(WHITE)
		e.LightEmission = 0.3
		e.Acceleration = Vector3.new(0, -2, 0)
		e.Rate = 25
	end
	e.Parent = emitterPart
end

-- Breakables ------------------------------------------------------------------------------------

local function healthBar(main: BasePart, color: Color3, width: number, height: number)
	local gui = billboard(main, UDim2.fromOffset(width, 24), Vector3.new(0, height, 0), 80)
	gui.Name = "HealthGui"
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = rgb(20, 15, 35)
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Thickness = 1.5
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	label(back, { Name = "Amount", Text = "", ZIndex = 2 })
end

local function burstEmitter(main: BasePart, color: Color3)
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Enabled = false
	burst.Color = ColorSequence.new(color, WHITE)
	burst.LightEmission = 1
	burst.Size = NumberSequence.new(0.7, 0)
	burst.Speed = NumberRange.new(14, 24)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Lifetime = NumberRange.new(0.4, 0.9)
	burst.Parent = main
end

-- Crystal cluster ----------------------------------------------------------------------------

-- One faceted shard: a diamond-section column topped by a cube balanced on its corner.
local function shard(parent: Instance, base: CFrame, width: number, height: number, color: Color3): BasePart
	local body = part({
		Name = "Shard",
		Size = Vector3.new(width, height, width),
		CFrame = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, math.pi / 4, 0),
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = parent,
	})
	part({
		Name = "Tip",
		Size = Vector3.one * width * 0.72,
		CFrame = base * CFrame.new(0, height - width * 0.05, 0) * CFrame.Angles(0, math.pi / 4, 0) * CFrame.Angles(
			-math.atan(1 / math.sqrt(2)),
			0,
			0
		) * CFrame.Angles(0, 0, math.pi / 4),
		Color = color:Lerp(WHITE, 0.25),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = parent,
	})
	part({
		Name = "Core",
		Size = Vector3.new(width * 0.4, height * 0.8, width * 0.4),
		CFrame = base * CFrame.new(0, height * 0.45, 0) * CFrame.Angles(0, math.pi / 4, 0),
		Color = color:Lerp(WHITE, 0.4),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	return body
end

local function makeCrystal(parent: Instance, zone: Zones.ZoneDef, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Crystal"
	local base = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	part({
		Name = "Rock",
		Ellipsoid = true,
		Size = Vector3.new(6.5, 1.6, 6.5),
		CFrame = base * CFrame.new(0, 0.2, 0),
		Color = zone.GroundColor:Lerp(STONE, 0.6):Lerp(BLACK, 0.25),
		Material = Enum.Material.Slate,
		Parent = model,
	})
	local main = shard(model, base * CFrame.new(0, 0.3, 0), 2.2, 5.5, zone.CrystalColor)
	main.Name = "Main"
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local tilt = rng:NextNumber(0.3, 0.55)
		local shardBase = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.3, -1.4) * CFrame.Angles(-tilt, 0, 0)
		local tint = zone.CrystalColor:Lerp(zone.DecorColor, rng:NextNumber(0, 0.35))
		shard(model, shardBase, rng:NextNumber(1, 1.5), rng:NextNumber(2.4, 3.6), tint)
	end
	light(main, zone.CrystalColor, 12, 1.5)

	burstEmitter(main, zone.CrystalColor)

	healthBar(main, zone.CrystalColor, 120, 4.8)

	local mesh = placeMesh(model, CRYSTAL_MESH[zone.Index] or "", base, 6.5, true)
	if mesh then
		stripParts(model, { main }, mesh)
	end

	model.PrimaryPart = main
	model.Parent = parent
	return model
end

-- A big Mana Chest: lots of HP, big payout, takes a team (or a strong squad) to crack.
local function makeChest(parent: Instance, zone: Zones.ZoneDef, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "ManaChest"
	local base = CFrame.new(position) * CFrame.Angles(0, math.pi, 0)
	local wood = zone.GroundColor:Lerp(rgb(120, 75, 40), 0.6)
	local metal = GOLD
	disc(model, position + Vector3.new(0, 0.15, 0), 14, 0.3, zone.CrystalColor, Enum.Material.Neon)
	local body = part({
		Name = "Body",
		Size = Vector3.new(9, 5, 6),
		CFrame = base * CFrame.new(0, 2.5, 0),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	-- Domed lid, slightly open, with crystals glowing inside
	part({
		Name = "Lid",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9.2, 6.2, 6.2),
		CFrame = base * CFrame.new(0, 5.2, 0.6) * CFrame.Angles(-0.35, 0, 0) * CFrame.Angles(0, 0, 0),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	for i = -1, 1 do
		local crystal = part({
			Size = Vector3.new(1.2, 2.6, 1.2),
			CFrame = base * CFrame.new(i * 2.4, 5.4, -0.8) * CFrame.Angles(0.2, math.pi / 4, i * 0.3),
			Color = zone.CrystalColor,
			Material = Enum.Material.Neon,
			Parent = model,
		})
		crystal.CanCollide = false
	end
	-- Gold bands, corners and lock
	for _, x in { -3.2, 3.2 } do
		part({
			Size = Vector3.new(0.6, 5.2, 6.2),
			CFrame = base * CFrame.new(x, 2.5, 0),
			Color = metal,
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end
	part({
		Size = Vector3.new(9.2, 0.6, 6.2),
		CFrame = base * CFrame.new(0, 0.3, 0),
		Color = metal,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	part({
		Size = Vector3.new(1.6, 2, 0.6),
		CFrame = base * CFrame.new(0, 3.6, -3.2),
		Color = metal,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.7,
		CFrame = base * CFrame.new(0, 3.4, -3.55),
		Color = zone.CrystalColor,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	light(body, zone.CrystalColor, 20, 2)
	burstEmitter(body, zone.CrystalColor)
	healthBar(body, GOLD, 200, 7)
	local title = billboard(body, UDim2.fromOffset(220, 30), Vector3.new(0, 9.2, 0), 90)
	label(title, { Text = "MANA CHEST", TextColor3 = GOLD })
	local mesh = placeMesh(model, "ManaChest", base, 9.5)
	if mesh then
		stripParts(model, { body }, mesh)
	end
	model.PrimaryPart = body
	model.Parent = parent
	return model
end

-- Eggs ----------------------------------------------------------------------------------------

local function makeEggStand(parent: Instance, eggId: string, position: Vector3): Model
	local egg = Eggs.Get(eggId) :: Eggs.EggDef
	local accent = egg.Color:Lerp(WHITE, 0.55)
	local stand = Instance.new("Model")
	stand.Name = eggId

	-- Tiered pedestal with a glowing rune ring
	disc(stand, position + Vector3.new(0, 0.5, 0), 12, 1, STONE, Enum.Material.Slate)
	disc(stand, position + Vector3.new(0, 1.3, 0), 9.5, 0.8, STONE:Lerp(WHITE, 0.15), Enum.Material.Slate)
	disc(stand, position + Vector3.new(0, 1.05, 0), 10.2, 0.25, egg.Color, Enum.Material.Neon)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local p = position + Vector3.new(math.cos(a) * 5.2, 0, math.sin(a) * 5.2)
		column(stand, p, 3.2, 0.8, STONE:Lerp(WHITE, 0.1), Enum.Material.Slate)
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1,
			Position = p + Vector3.new(0, 3.6, 0),
			Color = egg.Color,
			Material = Enum.Material.Neon,
			Parent = stand,
		})
	end

	-- The egg itself spins and bobs (animated on the client)
	local visual = Instance.new("Model")
	visual.Name = "EggVisual"
	visual:SetAttribute("Spin", 0.6)
	visual:SetAttribute("Bob", 0.4)
	local center = position + Vector3.new(0, 5.6, 0)
	local eggPart = part({
		Name = "Egg",
		Ellipsoid = true,
		Size = Vector3.new(5, 6.6, 5),
		Position = center,
		Color = egg.Color,
		Material = Enum.Material.SmoothPlastic,
		Parent = visual,
	})
	-- Spots on the shell
	for i = 0, 7 do
		local theta = i * 2.4
		local phi = math.rad(-35 + (i % 4) * 22)
		local x = math.cos(phi) * math.cos(theta)
		local y = math.sin(phi)
		local z = math.cos(phi) * math.sin(theta)
		local surface = center + Vector3.new(x * 2.4, y * 3.2, z * 2.4)
		part({
			Name = "Spot",
			Ellipsoid = true,
			Size = Vector3.new(1.3, 1.3, 0.35),
			CFrame = CFrame.lookAt(surface, surface + Vector3.new(x, y * 0.7, z)),
			Color = accent,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = visual,
		})
	end
	-- Glowing band around the middle
	part({
		Name = "Band",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.45, 5.08, 5.08),
		CFrame = CFrame.new(center + Vector3.new(0, -0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = accent,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = visual,
	})
	light(eggPart, egg.Color, 14, 1.2)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(egg.Color, WHITE)
	sparkle.LightEmission = 1
	sparkle.Rate = 4
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(0.5, 1)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new(0.3, 0)
	sparkle.Parent = eggPart
	visual.PrimaryPart = eggPart
	visual.Parent = stand
	-- Imported egg model replaces the built-in shell (the invisible egg part keeps the prompts)
	if placeMesh(visual, eggId, CFrame.new(center - Vector3.new(0, 3.4, 0)), 6.8, true) then
		for _, child in visual:GetChildren() do
			if child:IsA("BasePart") and child ~= eggPart then
				child:Destroy()
			end
		end
		eggPart.Transparency = 1
	end

	-- Billboard: name, price and every possible creature with its odds. Sized in studs so it
	-- sits in the world like a sign (shrinks with distance) instead of covering the screen.
	local columns = 3
	local rows = math.ceil(#egg.Drops / columns)
	local W, PAD, GAP, HEADER, FOOTER = 9, 0.32, 0.2, 2, 0.7
	local cellSize = (W - PAD * 2 - GAP * (columns - 1)) / columns
	local gridW = W - PAD * 2
	local gridH = rows * cellSize + (rows - 1) * GAP
	local H = PAD + HEADER + GAP + gridH + GAP + FOOTER + PAD
	local function sx(studs: number): number
		return studs / W
	end
	local function sy(studs: number): number
		return studs / H
	end
	local priceColor = if egg.Currency == "Trophies" then rgb(84, 210, 255) else rgb(96, 232, 190)
	local priceIcon = if egg.Currency == "Trophies" then "🏆" else "💎"

	local gui = billboard(eggPart, UDim2.fromScale(W, H), Vector3.new(0, 3.3 + 2.2 + H / 2, 0), 70)
	gui.Name = "OddsGui"
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = rgb(16, 18, 34)
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0.06, 0)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = WHITE
	panelStroke.Transparency = 0.82
	panelStroke.Thickness = 1.5
	panelStroke.Parent = panel
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new(WHITE, rgb(200, 200, 215))
	sheen.Rotation = 90
	sheen.Parent = panel
	-- egg-coloured accent strip across the top
	local accentBar = Instance.new("Frame")
	accentBar.AnchorPoint = Vector2.new(0.5, 0)
	accentBar.Position = UDim2.fromScale(0.5, 0)
	accentBar.Size = UDim2.fromScale(0.36, sy(0.12))
	accentBar.BackgroundColor3 = egg.Color
	accentBar.BorderSizePixel = 0
	accentBar.Parent = panel
	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

	-- Header: egg name + price pill
	label(panel, {
		Text = egg.Name,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromScale(sx(PAD), sy(PAD)),
		Size = UDim2.fromScale(sx(gridW), sy(1.1)),
		TextColor3 = WHITE,
	})
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, sy(PAD + 1.25))
	pill.Size = UDim2.fromScale(sx(4.4), sy(0.8))
	pill.BackgroundColor3 = priceColor
	pill.BackgroundTransparency = 0.8
	pill.BorderSizePixel = 0
	pill.Parent = panel
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = priceColor
	pillStroke.Transparency = 0.35
	pillStroke.Thickness = 1.5
	pillStroke.Parent = pill
	local requiredZone = egg.RequiresZone and Zones.Get(egg.RequiresZone)
	label(pill, {
		Text = if requiredZone
			then `{priceIcon} {Format.Number(egg.Cost)} · needs {requiredZone.Name}`
			else `{priceIcon}  {Format.Number(egg.Cost)}`,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromScale(0.08, 0.14),
		Size = UDim2.fromScale(0.84, 0.72),
		TextColor3 = priceColor,
	})

	-- Odds grid
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromScale(sx(PAD), sy(PAD + HEADER + GAP))
	grid.Size = UDim2.fromScale(sx(gridW), sy(gridH))
	grid.Parent = panel
	-- one centred row per line, so a short last row sits in the middle
	local rowFrames = {}
	for r = 1, rows do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromScale(0, (r - 1) * (cellSize + GAP) / gridH)
		row.Size = UDim2.fromScale(1, cellSize / gridH)
		row.Parent = grid
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.Padding = UDim.new(GAP / gridW, 0)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row
		rowFrames[r] = row
	end
	local odds = Eggs.GetOdds(egg, 1)
	for i, drop in egg.Drops do
		local def = Creatures.Get(drop.Creature) :: Creatures.CreatureDef
		local rarityColor = Creatures.Rarities[def.Rarity].Color
		local cell = Instance.new("Frame")
		cell.LayoutOrder = i
		cell.Size = UDim2.fromScale(cellSize / gridW, 1)
		cell.BackgroundColor3 = rgb(34, 38, 66)
		cell.BackgroundTransparency = 0.25
		cell.BorderSizePixel = 0
		cell.Parent = rowFrames[math.ceil(i / columns)]
		Instance.new("UICorner", cell).CornerRadius = UDim.new(0.14, 0)
		local cellStroke = Instance.new("UIStroke")
		cellStroke.Color = rarityColor
		cellStroke.Transparency = 0.4
		cellStroke.Thickness = 1.5
		cellStroke.Parent = cell
		-- soft rarity glow behind the creature
		local glow = Instance.new("UIGradient")
		glow.Color = ColorSequence.new(rarityColor:Lerp(BLACK, 0.35), rgb(34, 38, 66))
		glow.Rotation = 90
		glow.Parent = cell
		-- 3D preview slot: filled in by each client (cameras made on the server don't replicate,
		-- so a server-built ViewportFrame would show up empty)
		local preview = Instance.new("Frame")
		preview.Name = "Preview"
		preview.BackgroundTransparency = 1
		preview.Position = UDim2.fromScale(0.06, 0.03)
		preview.Size = UDim2.fromScale(0.88, 0.54)
		preview:SetAttribute("CreatureId", def.Id)
		preview.Parent = cell
		label(cell, {
			Name = "CreatureName",
			Text = def.Name,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromScale(0.06, 0.57),
			Size = UDim2.fromScale(0.88, 0.13),
			TextColor3 = WHITE,
		})
		label(cell, {
			Text = Format.Percent(odds[i]),
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(0.1, 0.7),
			Size = UDim2.fromScale(0.8, 0.15),
			TextColor3 = rarityColor,
		})
		label(cell, {
			Text = def.Rarity,
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromScale(0.15, 0.85),
			Size = UDim2.fromScale(0.7, 0.11),
			TextColor3 = rarityColor:Lerp(WHITE, 0.25),
		})
	end

	-- Footer hint
	label(panel, {
		Text = "Walk up to hatch",
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromScale(sx(PAD), sy(H - PAD - FOOTER * 0.85)),
		Size = UDim2.fromScale(sx(gridW), sy(FOOTER * 0.7)),
		TextColor3 = rgb(168, 176, 210),
	})

	-- Prompts sit down on the pedestal so they don't cover the sign
	local promptPoint = Instance.new("Attachment")
	promptPoint.Name = "PromptPoint"
	promptPoint.Position = Vector3.new(0, -3.6, 0)
	promptPoint.Parent = eggPart
	local one = Instance.new("ProximityPrompt")
	one.Name = "Hatch1"
	one.ActionText = "Hatch x1"
	one.ObjectText = egg.Name
	one.KeyboardKeyCode = Enum.KeyCode.E
	one.HoldDuration = 0
	one.MaxActivationDistance = 13
	one.RequiresLineOfSight = false
	one.Parent = promptPoint
	local three = one:Clone()
	three.Name = "Hatch3"
	three.ActionText = "Hatch x3"
	three.KeyboardKeyCode = Enum.KeyCode.R
	three.UIOffset = Vector2.new(0, 80)
	three.Parent = promptPoint

	stand:SetAttribute("EggId", eggId)
	stand.Parent = parent
	return stand
end

-- Statues --------------------------------------------------------------------------------------

local function statue(parent: Instance, creatureId: string, position: Vector3, scale: number, facing: number?)
	local rig = CreatureModels.Build(creatureId, "Normal", scale)
	CreatureModels.Place(rig, CFrame.new(position) * CFrame.Angles(0, facing or 0, 0))
	rig.Model.Name = creatureId .. "Statue"
	rig.Model:SetAttribute("Bob", 0.5)
	rig.Model.Parent = parent
	return rig.Model
end

-- Hub pieces -----------------------------------------------------------------------------------

-- yaw: which way the front faces (default pi = towards the realms, +Z; -pi/2 = +X; pi/2 = -X)
local function makeBoard(parent: Instance, name: string, title: string, position: Vector3, color: Color3, yaw: number?)
	local facing = CFrame.new(position) * CFrame.Angles(0, yaw or math.pi, 0)
	local board = part({
		Name = name,
		Size = Vector3.new(18, 20, 1),
		CFrame = facing,
		Color = rgb(35, 25, 60),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	-- Stone frame with glowing trim
	for _, side in { -1, 1 } do
		column(
			board,
			facing:PointToWorldSpace(Vector3.new(side * 10, -position.Y, 0)),
			position.Y + 11,
			2.2,
			STONE,
			Enum.Material.Slate
		)
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.8,
			Position = facing:PointToWorldSpace(Vector3.new(side * 10, 11.8, 0)),
			Color = color,
			Material = Enum.Material.Neon,
			Parent = board,
		})
	end
	part({
		Size = Vector3.new(21, 1.4, 2),
		CFrame = facing * CFrame.new(0, 10.6, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
		Parent = board,
	})
	part({
		Size = Vector3.new(18.4, 0.3, 1.2),
		CFrame = facing * CFrame.new(0, 10, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = board,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(360, 400)
	gui.LightInfluence = 0
	gui.Parent = board
	local bg = Instance.new("UIGradient")
	bg.Color = ColorSequence.new(rgb(70, 45, 120), rgb(25, 18, 45))
	bg.Rotation = 90
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BorderSizePixel = 0
	backdrop.BackgroundColor3 = WHITE
	backdrop.Parent = gui
	bg.Parent = backdrop
	label(gui, { Name = "Title", Text = title, Size = UDim2.new(1, 0, 0, 50), TextColor3 = color })
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(10, 55)
	list.Size = UDim2.new(1, -20, 1, -60)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Parent = list
	for i = 1, Config.Leaderboards.Size do
		label(list, {
			Name = "Row" .. i,
			LayoutOrder = i,
			Text = "",
			Size = UDim2.new(1, 0, 0, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
end

local function makeLamp(parent: Instance, position: Vector3, color: Color3)
	column(parent, position, 9, 0.6, rgb(50, 40, 70), Enum.Material.Metal)
	part({
		Size = Vector3.new(2.2, 0.4, 2.2),
		Position = position + Vector3.new(0, 9.2, 0),
		Color = rgb(50, 40, 70),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local orb = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.6,
		Position = position + Vector3.new(0, 10.2, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	light(orb, color, 18, 1.2)
end

local HOUSE_STATUES = { Emberclaw = "Phoenix", Frostfang = "FrostPup", Stormwing = "ThunderGriffin" }

local function makeHouse(parent: Instance, houseId: string, position: Vector3, yaw: number): BasePart
	local house = Houses.List[houseId]
	-- front of the house (statue, banners) looks down the frame's -Z
	local frame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	disc(parent, position + Vector3.new(0, 0.4, 0), 12, 0.8, STONE, Enum.Material.Slate)
	disc(parent, position + Vector3.new(0, 0.35, 0), 12.6, 0.6, house.Color, Enum.Material.Neon) -- glowing rim
	local platform = part({
		Name = houseId,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 8, 8),
		CFrame = CFrame.new(position + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = house.Color:Lerp(STONE, 0.5),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	-- Banners on poles either side
	for _, side in { -1, 1 } do
		local pole = frame * CFrame.new(side * 5.5, 0, 1.5)
		column(platform, pole.Position, 12, 0.4, GOLD, Enum.Material.Metal)
		part({
			Size = Vector3.new(3, 5, 0.2),
			CFrame = pole * CFrame.new(-side * 1.6, 9, 0),
			Color = house.Color,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = platform,
		})
		part({
			ClassName = "WedgePart",
			Size = Vector3.new(3, 1.2, 0.2),
			CFrame = pole * CFrame.new(-side * 1.6, 5.9, 0) * CFrame.Angles(math.pi, 0, 0),
			Color = house.Color,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = platform,
		})
	end
	statue(parent, HOUSE_STATUES[houseId], position + Vector3.new(0, 6, 0), 2, yaw)
	local sign = part({
		Size = Vector3.one,
		Position = position + Vector3.new(0, 13, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = platform,
	})
	local gui = billboard(sign, UDim2.fromOffset(220, 64), Vector3.zero, 90)
	label(gui, { Text = `{house.Name}\n"{house.Motto}"`, TextColor3 = house.Color })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Join House"
	prompt.ObjectText = house.Name
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = platform
	platform:SetAttribute("HouseId", houseId)
	return platform
end

-- A glowing circle on the ground: walk into it and a shop window opens (client: Modules/ShopPads).
-- Used by the Blacksmith and the Wandering Merchant.
local function shopPad(parent: Instance, name: string, center: Vector3, color: Color3, text: string): BasePart
	local ring = part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 9, 9),
		CFrame = CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	part({
		Name = "PadInner",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.22, 7.6, 7.6),
		CFrame = CFrame.new(center + Vector3.new(0, 0.13, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.75),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	-- the sign's offset is in the ring's own space, and the ring is a cylinder turned on its side
	-- (its X axis points up), so "4 studs up" is +X here, not +Y
	local sign = billboard(ring, UDim2.fromOffset(200, 34), Vector3.new(4, 0, 0), 60)
	label(sign, { Text = text, TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3) })
	return ring
end

local function makeMerchant(parent: Instance, position: Vector3)
	local wood = rgb(130, 85, 50)
	local counter = part({
		Name = "Merchant",
		Size = Vector3.new(10, 3.5, 4),
		Position = position + Vector3.new(0, 1.75, 0),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	-- Wheels
	for _, x in { -3.5, 3.5 } do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 3, 3),
			CFrame = CFrame.new(position + Vector3.new(x, 1.5, 2.3)) * CFrame.Angles(0, math.pi / 2, 0),
			Color = rgb(70, 45, 25),
			Material = Enum.Material.Wood,
			Parent = counter,
		})
	end
	-- Posts + striped awning
	for _, x in { -4.6, 4.6 } do
		column(counter, position + Vector3.new(x, 3.5, -1.6), 4.5, 0.4, wood, Enum.Material.Wood)
	end
	for i = 0, 5 do
		part({
			Size = Vector3.new(11.6 / 6, 0.35, 6),
			CFrame = CFrame.new(position + Vector3.new(-5.8 + 11.6 / 12 + i * 11.6 / 6, 8.3, -0.6))
				* CFrame.Angles(math.rad(-12), 0, 0),
			Color = if i % 2 == 0 then rgb(170, 60, 200) else rgb(255, 210, 110),
			Material = Enum.Material.Fabric,
			Parent = counter,
		})
	end
	-- Wares: potions & a mystic egg on the counter
	for i, color in { rgb(90, 255, 140), rgb(255, 120, 200), rgb(120, 200, 255), rgb(255, 220, 90) } do
		local p = position + Vector3.new(-3.6 + i * 1.3, 3.5, 0)
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			Position = p + Vector3.new(0, 0.45, 0),
			Color = color,
			Material = Enum.Material.Neon,
			Parent = counter,
		})
		column(counter, p + Vector3.new(0, 0.85, 0), 0.4, 0.3, rgb(140, 100, 70), Enum.Material.Wood)
	end
	local mystic = part({
		Ellipsoid = true,
		Size = Vector3.new(1.4, 1.8, 1.4),
		Position = position + Vector3.new(3.4, 4.4, 0),
		Color = rgb(190, 120, 255),
		Material = Enum.Material.Neon,
		Parent = counter,
	})
	mystic:SetAttribute("Spin", 1.5)
	-- Hooded merchant behind the counter, with glowing eyes
	local robeColor = rgb(80, 40, 120)
	part({
		Ellipsoid = true,
		Size = Vector3.new(2.6, 5, 2.4),
		Position = position + Vector3.new(0, 2.5, -3.2),
		Color = robeColor,
		Material = Enum.Material.Fabric,
		Parent = counter,
	})
	part({
		Ellipsoid = true,
		Size = Vector3.new(2.2, 2.4, 2.2),
		Position = position + Vector3.new(0, 5.6, -3.2),
		Color = robeColor:Lerp(BLACK, 0.2),
		Material = Enum.Material.Fabric,
		Parent = counter,
	})
	part({
		Ellipsoid = true,
		Size = Vector3.new(1.5, 1.4, 0.5),
		Position = position + Vector3.new(0, 5.5, -2.25),
		Color = rgb(15, 10, 25),
		Parent = counter,
	})
	for _, x in { -0.32, 0.32 } do
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.3,
			Position = position + Vector3.new(x, 5.6, -2.05),
			Color = rgb(255, 220, 90),
			Material = Enum.Material.Neon,
			Parent = counter,
		})
	end
	-- Barrels and crates
	for i, offset in { Vector3.new(-6.5, 0, -1), Vector3.new(6.6, 0, -1.5) } do
		column(counter, position + offset, 3, 2.4, rgb(110, 70, 40), Enum.Material.Wood)
		disc(counter, position + offset + Vector3.new(0, 3.05, 0), 2.5, 0.1, rgb(60, 60, 70), Enum.Material.Metal)
		part({
			Size = Vector3.one * 2,
			CFrame = CFrame.new(position + offset + Vector3.new(if i == 1 then -0.5 else 0.5, 1, 2.4))
				* CFrame.Angles(0, 0.3 * i, 0),
			Color = wood,
			Material = Enum.Material.WoodPlanks,
			Parent = counter,
		})
	end
	local lantern = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1,
		Position = position + Vector3.new(-4.6, 7.4, 1.4),
		Color = rgb(255, 200, 110),
		Material = Enum.Material.Neon,
		Parent = counter,
	})
	light(lantern, rgb(255, 200, 110), 16, 1.5)

	local gui = billboard(counter, UDim2.fromOffset(240, 50), Vector3.new(0, 9, 0), 90)
	label(gui, { Text = "Wandering Merchant", TextColor3 = rgb(255, 200, 120) })
	local stallMesh = placeMesh(parent, "MerchantStall", CFrame.new(position), 9, true, true)
	if stallMesh then
		stripParts(counter, { counter })
	end
	-- the shop circle in front of the cart (towards the plaza), like the Blacksmith's
	shopPad(parent, "MerchantPad", position + Vector3.new(10, 0, 0), rgb(255, 200, 110), "🧙 Step in to shop")
end

local function makeObelisk(parent: Instance, position: Vector3)
	-- Fountain ring with water
	disc(parent, position + Vector3.new(0, 0.6, 0), 22, 1.2, STONE, Enum.Material.Slate)
	disc(parent, position + Vector3.new(0, 0.75, 0), 19, 1.2, rgb(90, 160, 255), Enum.Material.Glass).Transparency = 0.3
	disc(parent, position + Vector3.new(0, 0.55, 0), 22.6, 1, rgb(170, 110, 255), Enum.Material.Neon) -- glowing rim
	-- Stepped base + pillar
	part({
		Size = Vector3.new(7, 1.5, 7),
		Position = position + Vector3.new(0, 1.5, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	part({
		Size = Vector3.new(5, 1.5, 5),
		Position = position + Vector3.new(0, 3, 0),
		Color = STONE:Lerp(WHITE, 0.1),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	local obelisk = part({
		Name = "SurgeObelisk",
		Size = Vector3.new(3, 12, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 9.75, 0)) * CFrame.Angles(0, math.pi / 4, 0),
		Color = rgb(60, 40, 100),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	part({
		Size = Vector3.new(3.2, 10, 0.3),
		CFrame = obelisk.CFrame,
		Color = rgb(190, 130, 255),
		Material = Enum.Material.Neon,
		Parent = obelisk,
	})
	-- Floating, spinning mana crystal on top
	local top = Instance.new("Model")
	top.Name = "ManaCore"
	local core = part({
		Size = Vector3.one * 3.2,
		CFrame = CFrame.new(position + Vector3.new(0, 19, 0))
			* CFrame.Angles(-math.atan(1 / math.sqrt(2)), 0, 0)
			* CFrame.Angles(0, 0, math.pi / 4),
		Color = rgb(200, 140, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = top,
	})
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		part({
			Size = Vector3.new(0.8, 1.6, 0.4),
			CFrame = CFrame.new(position + Vector3.new(math.cos(a) * 4, 19, math.sin(a) * 4)) * CFrame.Angles(0, -a, 0),
			Color = rgb(255, 230, 140),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = top,
		})
	end
	light(core, rgb(200, 140, 255), 30, 2)
	top.PrimaryPart = core
	top:SetAttribute("Spin", 0.8)
	top:SetAttribute("Bob", 0.6)
	top.Parent = parent

	local surgeGui = billboard(obelisk, UDim2.fromOffset(280, 90), Vector3.new(0, 14, 0), 220)
	surgeGui.Name = "SurgeGui"
	label(surgeGui, { Name = "Text", Text = "Mana Surge" })
end

-- Zone decorations -----------------------------------------------------------------------------

local decorators: { [number]: (Instance, Zones.ZoneDef, number) -> () } = {}

decorators[1] = function(folder, zone, z0) -- Enchanted Meadow: fairy trees, mushrooms, flowers
	for _ = 1, 10 do
		local p = sideSpot(z0, ZONE_LENGTH)
		local h = rng:NextNumber(7, 11)
		local lean = rng:NextNumber(-0.25, 0.25)
		if placeMesh(folder, "MagicTree", CFrame.new(p) * CFrame.Angles(0, lean * 12, 0), h + 5, true, true) then
			continue
		end
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, 1.6, 1.6),
			CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(lean, 0, math.pi / 2),
			Color = rgb(120, 85, 60),
			Material = Enum.Material.Wood,
			Parent = folder,
		})
		local top = p + Vector3.new(0, h, -lean * h * 0.5)
		for i = 1, 3 do
			local offset = Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-0.5, 1.5), rng:NextNumber(-2, 2))
			local leaf = if i == 1
				then zone.DecorColor
				else rgb(120, 210, 120):Lerp(zone.DecorColor, rng:NextNumber(0, 0.4))
			part({
				Ellipsoid = true,
				Size = Vector3.new(rng:NextNumber(6, 8), rng:NextNumber(4, 5), rng:NextNumber(6, 8)),
				Position = top + offset,
				Color = leaf,
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = folder,
			})
		end
		for _ = 1, 3 do
			local fruit = part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.7,
				Position = top + Vector3.new(rng:NextNumber(-3, 3), -2.2, rng:NextNumber(-3, 3)),
				Color = rgb(255, 240, 150),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			fruit:SetAttribute("Bob", 0.2)
		end
	end
	for _ = 1, 6 do
		local p = sideSpot(z0, ZONE_LENGTH)
		local h = rng:NextNumber(3, 6)
		column(folder, p, h, 1.4, rgb(245, 235, 210))
		local capColor = if rng:NextNumber() < 0.5 then rgb(230, 70, 90) else rgb(170, 110, 255)
		local capPos = p + Vector3.new(0, h + 0.4, 0)
		part({
			Ellipsoid = true,
			Size = Vector3.new(h * 1.2, h * 0.5, h * 1.2),
			Position = capPos,
			Color = capColor,
			Parent = folder,
		})
		for i = 0, 4 do
			local a = i * 1.26
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.5,
				Position = capPos + Vector3.new(math.cos(a) * h * 0.32, h * 0.18, math.sin(a) * h * 0.32),
				Color = WHITE,
				Parent = folder,
			})
		end
	end
	local petals = { rgb(255, 150, 220), rgb(255, 240, 120), rgb(150, 200, 255), rgb(255, 255, 255) }
	for _ = 1, 40 do
		local p = sideSpot(z0, ZONE_LENGTH)
		column(folder, p, 1.2, 0.15, rgb(80, 160, 70)).CanCollide = false
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			Position = p + Vector3.new(0, 1.3, 0),
			Color = petals[rng:NextInteger(1, #petals)],
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
	end
	ambientParticles(
		folder,
		Vector3.new(0, 6, z0 + ZONE_LENGTH / 2),
		Vector3.new(WIDTH, 8, ZONE_LENGTH),
		rgb(255, 245, 150),
		"Float"
	)
end

decorators[2] = function(folder, zone, z0) -- Ember Rift: rock spires, lava pools, dead trees
	for _, x in { -44, 44 } do
		part({
			Size = Vector3.new(6, 0.4, ZONE_LENGTH - 4),
			Position = Vector3.new(x, 0.05, z0 + ZONE_LENGTH / 2),
			Color = rgb(255, 110, 30),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
	end
	for _ = 1, 12 do
		local p = sideSpot(z0, ZONE_LENGTH)
		local w = rng:NextNumber(3, 5)
		local h = 0
		local cf = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		for tier = 1, 3 do
			local th = rng:NextNumber(3, 6)
			local tw = w * (1 - (tier - 1) * 0.28)
			part({
				Size = Vector3.new(tw, th, tw),
				CFrame = cf
					* CFrame.new(0, h + th / 2, 0)
					* CFrame.Angles(rng:NextNumber(-0.1, 0.1), tier * 0.4, rng:NextNumber(-0.1, 0.1)),
				Color = rgb(55, 40, 40),
				Material = Enum.Material.Basalt,
				Parent = folder,
			})
			h += th * 0.9
		end
		part({
			Size = Vector3.new(0.3, h * 0.7, w * 0.6),
			CFrame = cf * CFrame.new(w * 0.45, h * 0.35, 0),
			Color = rgb(255, 120, 30),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
	end
	for _ = 1, 5 do
		local p = sideSpot(z0, ZONE_LENGTH)
		local d = rng:NextNumber(6, 10)
		disc(folder, p + Vector3.new(0, 0.2, 0), d + 1.5, 0.5, rgb(40, 30, 30), Enum.Material.Basalt)
		local lava = disc(folder, p + Vector3.new(0, 0.35, 0), d, 0.5, rgb(255, 100, 20), Enum.Material.Neon)
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 6
		fire.Color = rgb(255, 140, 40)
		fire.SecondaryColor = rgb(255, 60, 20)
		fire.Parent = lava
		light(lava, rgb(255, 120, 40), 16, 2)
	end
	for _ = 1, 6 do
		local p = sideSpot(z0, ZONE_LENGTH)
		local h = rng:NextNumber(6, 9)
		column(folder, p, h, 1, rgb(35, 30, 30), Enum.Material.Wood)
		for i = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local dir = Vector3.new(math.cos(a), 0.8, math.sin(a)).Unit
			local from = p + Vector3.new(0, h * (0.5 + i * 0.15), 0)
			local len = rng:NextNumber(2, 3.5)
			part({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(len, 0.4, 0.4),
				CFrame = CFrame.lookAt(from + dir * len / 2, from + dir * len) * CFrame.Angles(0, math.pi / 2, 0),
				Color = rgb(35, 30, 30),
				Material = Enum.Material.Wood,
				Parent = folder,
			})
		end
	end
	ambientParticles(
		folder,
		Vector3.new(0, 4, z0 + ZONE_LENGTH / 2),
		Vector3.new(WIDTH, 6, ZONE_LENGTH),
		rgb(255, 140, 40),
		"Rise"
	)
end

decorators[3] = function(folder, zone, z0) -- Frostpeak: snowy pines, ice spikes, frozen pond
	for _ = 1, 14 do
		local p = sideSpot(z0, ZONE_LENGTH)
		local s = rng:NextNumber(0.8, 1.3)
		column(folder, p, 3 * s, 1 * s, rgb(90, 60, 45), Enum.Material.Wood)
		for tier = 0, 2 do
			local w = (7 - tier * 2) * s
			local y = (3.5 + tier * 2.6) * s
			part({
				Ellipsoid = true,
				Size = Vector3.new(w, 3 * s, w),
				Position = p + Vector3.new(0, y, 0),
				Color = rgb(40, 100, 80),
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = folder,
			})
			part({
				Ellipsoid = true,
				Size = Vector3.new(w * 0.8, 1.2 * s, w * 0.8),
				Position = p + Vector3.new(0, y + 1.1 * s, 0),
				Color = WHITE,
				Material = Enum.Material.Snow,
				CanCollide = false,
				Parent = folder,
			})
		end
	end
	for _ = 1, 8 do
		local p = sideSpot(z0, ZONE_LENGTH)
		for _ = 1, 4 do
			local h = rng:NextNumber(3, 8)
			local tiltA, tiltB = rng:NextNumber(-0.35, 0.35), rng:NextNumber(-0.35, 0.35)
			part({
				Size = Vector3.new(1.2, h, 1.2),
				CFrame = CFrame.new(p + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5)))
					* CFrame.Angles(tiltA, rng:NextNumber(0, 1), tiltB)
					* CFrame.new(0, h / 2, 0)
					* CFrame.Angles(0, math.pi / 4, 0),
				Color = rgb(170, 225, 255),
				Material = Enum.Material.Ice,
				Transparency = 0.15,
				Parent = folder,
			})
		end
	end
	for _ = 1, 8 do
		local p = sideSpot(z0, ZONE_LENGTH)
		part({
			Ellipsoid = true,
			Size = Vector3.new(rng:NextNumber(5, 9), 2, rng:NextNumber(5, 9)),
			Position = p,
			Color = WHITE,
			Material = Enum.Material.Snow,
			Parent = folder,
		})
	end
	local pond = sideSpot(z0, ZONE_LENGTH)
	disc(folder, pond + Vector3.new(0, 0.1, 0), 16, 0.3, rgb(180, 230, 255), Enum.Material.Ice)
	ambientParticles(
		folder,
		Vector3.new(0, 30, z0 + ZONE_LENGTH / 2),
		Vector3.new(WIDTH, 2, ZONE_LENGTH),
		WHITE,
		"Fall"
	)
end

decorators[4] = function(folder, zone, z0) -- Sky Sanctum: marble pillars, clouds, floating islands
	for i = 0, 7 do
		local side = if i % 2 == 0 then -1 else 1
		local p = Vector3.new(side * 40, 0, z0 + 12 + (i // 2) * 32)
		local h = if rng:NextNumber() < 0.3 then rng:NextNumber(5, 9) else 16
		part({
			Size = Vector3.new(4.5, 1.2, 4.5),
			Position = p + Vector3.new(0, 0.6, 0),
			Color = rgb(240, 235, 225),
			Material = Enum.Material.Marble,
			Parent = folder,
		})
		column(folder, p + Vector3.new(0, 1.2, 0), h, 3, rgb(250, 248, 240), Enum.Material.Marble)
		if h >= 16 then
			part({
				Size = Vector3.new(4.5, 1.2, 4.5),
				Position = p + Vector3.new(0, h + 1.8, 0),
				Color = GOLD,
				Material = Enum.Material.Metal,
				Parent = folder,
			})
		end
	end
	local function cloud(center: Vector3, scale: number, float: boolean)
		local model = Instance.new("Model")
		model.Name = "Cloud"
		for _ = 1, 5 do
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * rng:NextNumber(3, 5) * scale,
				Position = center
					+ Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-0.5, 1), rng:NextNumber(-2, 2)) * scale,
				Color = WHITE,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Parent = model,
			})
		end
		if float then
			model:SetAttribute("Bob", 1.2)
		end
		model.Parent = folder
	end
	for _ = 1, 8 do
		cloud(sideSpot(z0, ZONE_LENGTH) + Vector3.new(0, 1, 0), 1, false)
	end
	for _ = 1, 6 do
		local p = sideSpot(z0, ZONE_LENGTH)
		cloud(p + Vector3.new(0, rng:NextNumber(20, 35), 0), 1.6, true)
	end
	for _ = 1, 4 do
		local p = sideSpot(z0, ZONE_LENGTH) + Vector3.new(0, rng:NextNumber(18, 28), 0)
		local island = Instance.new("Model")
		island.Name = "FloatingIsland"
		part({
			Ellipsoid = true,
			Size = Vector3.new(10, 7, 10),
			Position = p - Vector3.new(0, 2.5, 0),
			Color = rgb(150, 130, 110),
			Material = Enum.Material.Rock,
			Parent = island,
		})
		disc(island, p + Vector3.new(0, 0.6, 0), 10, 1, rgb(140, 220, 120), Enum.Material.Grass)
		column(island, p + Vector3.new(0, 1, 0), 4, 0.6, rgb(120, 90, 60), Enum.Material.Wood)
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 4,
			Position = p + Vector3.new(0, 5.5, 0),
			Color = rgb(255, 220, 150),
			Material = Enum.Material.Grass,
			Parent = island,
		})
		island:SetAttribute("Bob", 1.5)
		island.Parent = folder
	end
	ambientParticles(
		folder,
		Vector3.new(0, 8, z0 + ZONE_LENGTH / 2),
		Vector3.new(WIDTH, 10, ZONE_LENGTH),
		rgb(255, 235, 150),
		"Float"
	)
end

-- Gates ------------------------------------------------------------------------------------------

local function makeArch(folder: Instance, zone: Zones.ZoneDef, z: number)
	for _, side in { -1, 1 } do
		local base = Vector3.new(side * (WIDTH / 2 - 3), 0, z)
		part({
			Size = Vector3.new(6, 2, 6),
			Position = base + Vector3.new(0, 1, 0),
			Color = STONE,
			Material = Enum.Material.Slate,
			Parent = folder,
		})
		column(folder, base + Vector3.new(0, 2, 0), 28, 4, STONE:Lerp(WHITE, 0.15), Enum.Material.Slate)
		local orb = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3.5,
			Position = base + Vector3.new(0, 32, 0),
			Color = zone.CrystalColor,
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		light(orb, zone.CrystalColor, 24, 1.5)
	end
	local beam = part({
		Size = Vector3.new(WIDTH - 2, 3, 3),
		Position = Vector3.new(0, 31, z),
		Color = STONE,
		Material = Enum.Material.Slate,
		Parent = folder,
	})
	part({
		Size = Vector3.new(WIDTH - 6, 0.4, 3.2),
		Position = Vector3.new(0, 29.6, z),
		Color = zone.CrystalColor,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(2000, 60)
		gui.LightInfluence = 0
		gui.Parent = beam
		label(gui, { Text = zone.Name, TextColor3 = zone.CrystalColor })
	end
end

local function makeGate(folder: Instance, zone: Zones.ZoneDef, z: number): BasePart
	local gate = part({
		Name = "Gate",
		Size = Vector3.new(WIDTH - 10, 28, 1),
		Position = Vector3.new(0, 15, z),
		Color = zone.CrystalColor,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		Parent = folder,
	})
	gate:SetAttribute("ZoneIndex", zone.Index)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(1000, 300)
		gui.LightInfluence = 0
		gui.Parent = gate
		label(gui, {
			Text = `LOCKED\n{Format.Number(zone.UnlockCost)} Essence`,
			Size = UDim2.fromScale(0.5, 0.45),
			Position = UDim2.fromScale(0.25, 0.3),
		})
	end
	-- Unlock terminal: floating orb on a pedestal in front of the gate
	part({
		Name = "TerminalBase",
		Size = Vector3.new(3, 3, 3),
		Position = Vector3.new(0, 1.5, z - 5),
		Color = STONE,
		Material = Enum.Material.Slate,
		Parent = gate,
	})
	local terminal = part({
		Name = "GateTerminal",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.4,
		Position = Vector3.new(0, 4.6, z - 5),
		Color = zone.CrystalColor,
		Material = Enum.Material.Neon,
		Parent = gate,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Unlock ({Format.Number(zone.UnlockCost)} Essence)`
	prompt.ObjectText = zone.Name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = terminal
	return gate
end

-- Lighting ---------------------------------------------------------------------------------------

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = rgb(150, 140, 180)
	Lighting.Ambient = rgb(80, 70, 110)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	local function effect(className: string, props: { [string]: any })
		local existing = Lighting:FindFirstChild("Mythic" .. className)
		if existing then
			existing:Destroy()
		end
		local e = Instance.new(className)
		e.Name = "Mythic" .. className
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = Lighting
	end
	effect("BloomEffect", { Intensity = 0.6, Size = 28, Threshold = 1.1 })
	effect("SunRaysEffect", { Intensity = 0.06, Spread = 0.8 })
	effect("ColorCorrectionEffect", { Saturation = 0.12, Contrast = 0.06, Brightness = 0.02 })
end

--[[
	The Creator Hub lists two kinds of ID: an Image ID works directly, but a Decal ID only shows
	an image once it's converted (Studio does this when you paste into Properties; scripts don't).
	So each ID is loaded once: if it's a Decal, its image is used instead.
]]
local resolvedImages: { [string]: string } = {}
local function resolveImage(id: string): string
	local number = string.match(id, "%d+")
	if not number then
		return id
	end
	if resolvedImages[number] then
		return resolvedImages[number]
	end
	local image = "rbxassetid://" .. number
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(tonumber(number) :: number)
	end)
	if ok and asset then
		for _, d in asset:GetDescendants() do
			if d:IsA("Decal") and (d :: Decal).Texture ~= "" then
				image = (d :: Decal).Texture
				print(`[Mythic Tamers] Ground texture {number} is a Decal ID - using its image ({image})`)
				break
			end
		end
		asset:Destroy()
	end
	resolvedImages[number] = image
	return image
end

-- Lays a tiling image (Config.GroundTextures) over the top of a floor part
local function groundTexture(floor: BasePart, key: any)
	local id = Config.GroundTextures[key]
	if type(id) ~= "string" or id == "" then
		return
	end
	local texture = Instance.new("Texture")
	texture.Name = "GroundTexture"
	texture.Face = Enum.NormalId.Top
	texture.StudsPerTileU = Config.GroundTextures.TileStuds
	texture.StudsPerTileV = Config.GroundTextures.TileStuds
	texture.Parent = floor
	-- loading an asset waits on the network, so the world doesn't wait for it
	task.spawn(function()
		texture.Texture = resolveImage(id)
	end)
end

-- Hub districts ----------------------------------------------------------------------------------
-- A big archway to another part of the game (the Gloomwood, your Sanctuary)
-- portalTo: set when the portal works (walk in to travel; Services/Sanctuaries, Services/Gloomwood),
-- nil = coming soon. subtitle: the line under the title.
local function portal(
	parent: Instance,
	position: Vector3,
	title: string,
	color: Color3,
	portalTo: string?,
	subtitle: string?
)
	local folder = Instance.new("Model")
	folder.Name = title .. "Portal"
	for _, side in { -1, 1 } do
		column(folder, position + Vector3.new(side * 7, 0, 0), 16, 2.4, rgb(70, 60, 95), Enum.Material.Slate)
	end
	part({
		Size = Vector3.new(17, 2, 3),
		Position = position + Vector3.new(0, 17, 0),
		Color = rgb(70, 60, 95),
		Material = Enum.Material.Slate,
		Parent = folder,
	})
	-- the glowing (closed) gateway
	local glow = part({
		Name = "Gateway",
		Size = Vector3.new(11.6, 15, 0.4),
		Position = position + Vector3.new(0, 8, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = portalTo == nil,
		Parent = folder,
	})
	if portalTo then
		glow:SetAttribute("PortalTo", portalTo)
	end
	glowAt(folder, position + Vector3.new(0, 8, 2), color, 22)
	local gui = billboard(glow, UDim2.fromOffset(260, 70), Vector3.new(0, 11.5, 0), 160)
	label(gui, { Text = title, TextColor3 = color, Size = UDim2.fromScale(1, 0.6) })
	label(gui, {
		Text = subtitle or (if portalTo then "Step in!" else "Coming soon!"),
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
		TextColor3 = WHITE,
	})
	folder.Parent = parent
end

local function buildDistricts(hub: Instance)
	local wingWidth = HUB_HALF - WIDTH / 2
	-- paving so each district reads as its own area
	for _, side in { -1, 1 } do
		part({
			Name = if side < 0 then "MarketFloor" else "HouseQuarterFloor",
			Size = Vector3.new(wingWidth - 4, 0.2, HUB_END - HUB_START - 70 * SPREAD),
			Position = Vector3.new(side * (WIDTH / 2 + wingWidth / 2), 0.04, (HUB_END + -60 * SPREAD) / 2),
			Color = if side < 0 then rgb(150, 95, 70) else rgb(95, 85, 140),
			Material = Enum.Material.Brick,
			Parent = hub,
		})
		-- a low wall where the wing meets the realm gate
		part({
			Size = Vector3.new(wingWidth, 3, 2),
			Position = Vector3.new(side * (WIDTH / 2 + wingWidth / 2), 1.5, HUB_END - 1),
			Color = rgb(80, 70, 110),
			Material = Enum.Material.Slate,
			Parent = hub,
		})
	end
	part({
		Name = "PortalPlazaFloor",
		Size = Vector3.new(90 * SPREAD, 0.2, 36 * SPREAD),
		Position = sp(0, 0.04, -80),
		Color = rgb(100, 95, 150),
		Material = Enum.Material.Slate,
		Parent = hub,
	})
	-- a wide walkway from the spawn back to the Portal Plaza
	part({
		Size = Vector3.new(16, 0.2, 22 * SPREAD),
		Position = sp(0, 0.05, -60),
		Color = rgb(120, 105, 160),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	-- west wing: the Merchant and the Blacksmith (no sign)

	-- Portal Plaza (back): the ways to the Gloomwood and your Sanctuary + a fountain
	-- just floating text over the walkway (no posts or board)
	local anchor = part({
		Name = "PortalPlazaSign",
		Size = Vector3.one,
		Position = sp(0, 9, -64),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = hub,
	})
	label(billboard(anchor, UDim2.fromOffset(240, 46), Vector3.zero, 140), {
		Text = "🌀 Portal Plaza",
		TextColor3 = rgb(140, 220, 255),
	})
	portal(hub, sp(-30, 0, -90), "🌲 The Gloomwood", rgb(120, 220, 140), "Gloomwood", "Step in! (needs Frostpeak)")
	portal(hub, sp(30, 0, -90), "🏝️ Your Sanctuary", rgb(255, 170, 230), "Sanctuary", "Step in to go home!")
	disc(hub, sp(0, 0.6, -84), 18, 1.2, rgb(110, 100, 150), Enum.Material.Slate)
	disc(hub, sp(0, 1.25, -84), 15, 0.2, rgb(90, 170, 255), Enum.Material.Glass).Transparency = 0.3
	column(hub, sp(0, 1, -84), 4, 1.6, rgb(150, 140, 190), Enum.Material.Marble)
	part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.2,
		Position = sp(0, 5.6, -84),
		Color = rgb(140, 220, 255),
		Material = Enum.Material.Neon,
		Parent = hub,
	})
	glowAt(hub, sp(0, 6, -84), rgb(140, 220, 255), 16)

	-- more lamps for the new areas
	for _, pos in
		{
			sp(-74, 0, -77),
			sp(74, 0, -57),
			sp(-62, 0, 46),
			sp(62, 0, 46),
			sp(-48, 0, -96),
			sp(48, 0, -96),
		}
	do
		if placeMesh(hub, "HubLamp", CFrame.new(pos), 12, true) then
			glowAt(hub, pos + Vector3.new(0, 11, 0), rgb(200, 160, 255), 18)
		else
			makeLamp(hub, pos, rgb(200, 160, 255))
		end
	end
end

-- Build ------------------------------------------------------------------------------------------

export type BuiltWorld = {
	Crystals: { { Model: Model, Zone: number } },
	Chests: { { Model: Model, Zone: number } },
	EggStands: { Model },
	Gates: { BasePart },
	HousePedestals: { BasePart },
}

function WorldBuilder.Build(): BuiltWorld
	local result: BuiltWorld = { Crystals = {}, Chests = {}, EggStands = {}, Gates = {}, HousePedestals = {} }

	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	setupLighting()

	local world = Instance.new("Folder")
	world.Name = "World"
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world

	-- Hub ------------------------------------------------------------------------------------
	local hubMid = (HUB_START + HUB_END) / 2
	local hubFloor = part({
		Name = "HubFloor",
		Size = Vector3.new(HUB_HALF * 2, 2, HUB_END - HUB_START),
		Position = Vector3.new(0, -1, hubMid),
		Color = rgb(85, 75, 120),
		Material = Enum.Material.Cobblestone,
		Parent = hub,
	})
	groundTexture(hubFloor, "Hub")
	-- Plaza + path to the realms
	disc(hub, sp(0, 0.05, 5), 46 * SPREAD, 0.2, rgb(120, 105, 160), Enum.Material.Slate)
	disc(hub, sp(0, 0.02, 5), 48 * SPREAD, 0.2, rgb(170, 110, 255), Enum.Material.Neon)
	part({
		Size = Vector3.new(14, 0.2, HUB_END - 28 * SPREAD),
		Position = Vector3.new(0, 0.05, (28 * SPREAD + HUB_END) / 2),
		Color = rgb(120, 105, 160),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	-- invisible, and turned round so new players face the realms (+Z), not the back of the hub
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(sp(0, 0.5, -32)) * CFrame.Angles(0, math.pi, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = hub

	-- Leaderboards stand at the back of the wings facing the middle, so the way from the spawn
	-- to the Portal Plaza stays open
	makeBoard(hub, "TrophyBoard", "Top Trophies", sp(-72, 11, -44), rgb(0, 255, 225), -math.pi / 2)
	makeBoard(hub, "EssenceBoard", "Weekly Season", sp(-72, 11, -64), rgb(140, 255, 200), -math.pi / 2)
	makeBoard(hub, "HouseBoard", "House War", sp(72, 11, -44), rgb(255, 200, 90), math.pi / 2)
	makeObelisk(hub, sp(0, 0, 5))

	for _, pos in
		{
			-- the back pair stand beside the leaderboards, against the walls, not in front of them
			sp(-74, 0, -31),
			sp(74, 0, -31),
			sp(-44, 0, 0),
			sp(44, 0, 0),
			sp(-44, 0, 40),
			sp(44, 0, 40),
		}
	do
		if placeMesh(hub, "HubLamp", CFrame.new(pos), 12, true) then
			glowAt(hub, pos + Vector3.new(0, 11, 0), rgb(200, 160, 255), 18)
		else
			makeLamp(hub, pos, rgb(200, 160, 255))
		end
	end
	-- Hub decorations (only placed when their model has been imported)
	for _, pos in { sp(-44, 0, -22), sp(44, 0, -22), sp(-44, 0, 20), sp(44, 0, 20) } do
		placeMesh(hub, "FlowerPlanter", CFrame.new(pos), 5)
	end
	-- benches in front of the Trophy and House War boards, facing them
	placeMesh(hub, "Bench", CFrame.new(sp(-60, 0, -44)) * CFrame.Angles(0, -math.pi / 2, 0), 7)
	placeMesh(hub, "Bench", CFrame.new(sp(60, 0, -44)) * CFrame.Angles(0, math.pi / 2, 0), 7)
	-- banners: the pair beside the leaderboards is turned round to face the hub
	for _, pos in { sp(-42, 0, -55), sp(42, 0, -55) } do
		placeMesh(hub, "HubBanner", CFrame.new(pos) * CFrame.Angles(0, math.pi, 0), 13, true)
	end
	for _, pos in { sp(-12, 0, 47), sp(12, 0, 47) } do
		placeMesh(hub, "HubBanner", CFrame.new(pos), 13, true)
	end

	-- Houses stand in the House Quarter (east wing), facing the plaza
	for i, id in Houses.Order do
		local position = sp(64, 0, -12 + (i - 1) * 24)
		table.insert(result.HousePedestals, makeHouse(hub, id, position, math.pi / 2))
	end

	-- Champion Egg under a golden arch, guarded by a Titan Unicorn statue: in the west wing between
	-- the Merchant and the Blacksmith, facing the middle of the hub (+X)
	local championPos = sp(-64, 0, 3)
	table.insert(result.EggStands, makeEggStand(hub, "ChampionEgg", championPos))
	for _, side in { -1, 1 } do
		column(hub, championPos + Vector3.new(-3, 0, side * 7), 14, 1.6, GOLD, Enum.Material.Metal)
	end
	part({
		Size = Vector3.new(1.8, 1.4, 16),
		Position = championPos + Vector3.new(-3, 14.4, 0),
		Color = GOLD,
		Material = Enum.Material.Metal,
		Parent = hub,
	})
	statue(hub, "TitanUnicorn", championPos + Vector3.new(-3, 18.5, 0), 1.2, -math.pi / 2)

	makeMerchant(hub, sp(-64, 0, -14))
	buildDistricts(hub)

	-- Zones ------------------------------------------------------------------------------------
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = world
	for _, zone in Zones.List do
		local z0 = zoneStartZ(zone.Index)
		local folder = Instance.new("Folder")
		folder.Name = zone.Name
		folder.Parent = zonesFolder

		local ground = part({
			Name = "Ground",
			Size = Vector3.new(WIDTH, 2, ZONE_LENGTH),
			Position = Vector3.new(0, -1, z0 + ZONE_LENGTH / 2),
			Color = zone.GroundColor,
			Material = zone.GroundMaterial,
			Parent = folder,
		})
		groundTexture(ground, zone.Index)
		part({
			Name = "Path",
			Size = Vector3.new(16, 0.2, ZONE_LENGTH),
			Position = Vector3.new(0, 0.05, z0 + ZONE_LENGTH / 2),
			Color = zone.GroundColor:Lerp(WHITE, 0.25),
			Material = Enum.Material.Slate,
			Parent = folder,
		})

		local decorFolder = Instance.new("Folder")
		decorFolder.Name = "Decor"
		decorFolder.Parent = folder
		local decorate = decorators[zone.Index]
		if decorate then
			decorate(decorFolder, zone, z0)
		end
		if zoneDecorReady(zone.Index) then
			-- the realm's 3D decorations replace the old block ones (keep the ambient particles)
			for _, child in decorFolder:GetChildren() do
				if child.Name ~= "Ambience" and string.sub(child.Name, -4) ~= "Mesh" then
					child:Destroy()
				end
			end
		end
		placeZoneDecor(decorFolder, zone.Index, z0)

		-- Crystals spread over the zone (grid with jitter)
		local crystalFolder = Instance.new("Folder")
		crystalFolder.Name = "Crystals"
		crystalFolder.Parent = folder
		for i = 1, CRYSTALS_PER_ZONE do
			local col = (i - 1) % 5
			local row = (i - 1) // 5
			local x = (-32 + col * 16 + rng:NextNumber(-2, 2)) * SPREAD
			local z = z0 + (48 + row * 40 + rng:NextNumber(-5, 5)) * SPREAD
			local crystal = makeCrystal(crystalFolder, zone, Vector3.new(x, 0, z))
			table.insert(result.Crystals, { Model = crystal, Zone = zone.Index })
		end

		table.insert(result.EggStands, makeEggStand(folder, zone.EggId, Vector3.new(-32 * SPREAD, 0, z0 + 22 * SPREAD)))
		local chest = makeChest(crystalFolder, zone, Vector3.new(30 * SPREAD, 0, z0 + 22 * SPREAD))
		table.insert(result.Chests, { Model = chest, Zone = zone.Index })

		-- Archway at the entrance of every zone, with a locked force field for paid zones
		makeArch(folder, zone, z0)
		if zone.UnlockCost > 0 then
			table.insert(result.Gates, makeGate(folder, zone, z0))
		end
	end

	-- Invisible boundary walls so nobody walks around the gates. The hub is wider than the realms,
	-- so it has its own side walls plus a short wall across each wing where the realms begin.
	local worldEnd = zoneStartZ(#Zones.List + 1)
	local function wall(size: Vector3, position: Vector3)
		part({ Name = "Wall", Size = size, Position = position, Transparency = 1, Parent = world })
	end
	for _, side in { -1, 1 } do
		wall(
			Vector3.new(1, 80, HUB_END - HUB_START),
			Vector3.new(side * (HUB_HALF + 0.5), 40, (HUB_START + HUB_END) / 2)
		)
		wall(
			Vector3.new(1, 80, worldEnd - HUB_END),
			Vector3.new(side * (WIDTH / 2 + 0.5), 40, (HUB_END + worldEnd) / 2)
		)
		wall(
			Vector3.new(HUB_HALF - WIDTH / 2, 80, 1),
			Vector3.new(side * (WIDTH / 2 + HUB_HALF) / 2, 40, HUB_END + 0.5)
		)
	end
	wall(Vector3.new(HUB_HALF * 2, 80, 1), Vector3.new(0, 40, HUB_START - 0.5))
	wall(Vector3.new(WIDTH, 80, 1), Vector3.new(0, 40, worldEnd + 0.5))

	world.Parent = workspace
	return result
end

-- Shared building helpers for other services (e.g. BossRaid)
WorldBuilder.Helpers = {
	HealthBar = healthBar,
	Burst = burstEmitter,
	Billboard = billboard,
	ShopPad = shopPad,
	Label = label,
	Light = light,
	ZoneStart = zoneStartZ,
	Spread = SPREAD, -- multiply plan positions (x and z offsets) by this
	PlaceMesh = placeMesh, -- (parent, name, base CFrame, size, byHeight?, collide?) -> Model? (nil = not imported)
	MeshTemplate = meshTemplate, -- (name) -> the imported Model/MeshPart, or nil
}

return WorldBuilder
