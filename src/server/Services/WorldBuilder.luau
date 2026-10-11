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

local WIDTH = 100
local HUB_START, HUB_END = -60, 50
local ZONE_LENGTH = 130
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

local function light(parent: Instance, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1
	l.Shadows = false
	l.Parent = parent
end

local function zoneStartZ(index: number): number
	return HUB_END + (index - 1) * ZONE_LENGTH
end

-- Random spot on the zone's sides, keeping the central lane (|x| < 15) clear
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

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Enabled = false
	burst.Color = ColorSequence.new(zone.CrystalColor, WHITE)
	burst.LightEmission = 1
	burst.Size = NumberSequence.new(0.7, 0)
	burst.Speed = NumberRange.new(14, 24)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Lifetime = NumberRange.new(0.4, 0.9)
	burst.Parent = main

	local gui = billboard(main, UDim2.fromOffset(120, 24), Vector3.new(0, 4.8, 0), 70)
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
	fill.BackgroundColor3 = zone.CrystalColor
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	label(back, { Name = "Amount", Text = "", ZIndex = 2 })

	model.PrimaryPart = main
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

	-- Billboard: name, price and every possible creature with its odds, shown in 3D
	local columns = 3
	local rows = math.ceil(#egg.Drops / columns)
	local gui = billboard(eggPart, UDim2.fromOffset(270, 76 + rows * 86), Vector3.new(0, 6 + rows * 1.6, 0), 55)
	gui.Name = "OddsGui"
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = rgb(25, 18, 45)
	panel.BackgroundTransparency = 0.25
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = egg.Color
	panelStroke.Thickness = 2
	panelStroke.Parent = panel
	label(panel, { Text = egg.Name, Size = UDim2.new(1, 0, 0, 34), TextColor3 = egg.Color })
	label(panel, {
		Text = `{Format.Number(egg.Cost)} {egg.Currency}`,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = if egg.Currency == "Trophies" then rgb(0, 255, 225) else rgb(255, 230, 120),
	})
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(6, 64)
	grid.Size = UDim2.new(1, -12, 1, -68)
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(82, 82)
	layout.CellPadding = UDim2.fromOffset(4, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local odds = Eggs.GetOdds(egg, 1)
	for i, drop in egg.Drops do
		local def = Creatures.Get(drop.Creature) :: Creatures.CreatureDef
		local rarityColor = Creatures.Rarities[def.Rarity].Color
		local cell = Instance.new("Frame")
		cell.LayoutOrder = i
		cell.BackgroundColor3 = rarityColor:Lerp(BLACK, 0.6)
		cell.BackgroundTransparency = 0.2
		cell.Parent = grid
		Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 10)
		local cellStroke = Instance.new("UIStroke")
		cellStroke.Color = rarityColor
		cellStroke.Thickness = 1.5
		cellStroke.Parent = cell
		local viewport = CreatureModels.Viewport(def.Id, "Normal", { Size = UDim2.new(1, 0, 1, -18) })
		viewport.Parent = cell
		label(cell, {
			Text = Format.Percent(odds[i]),
			Position = UDim2.new(0, 0, 1, -20),
			Size = UDim2.new(1, 0, 0, 18),
			TextColor3 = rarityColor,
		})
	end

	local one = Instance.new("ProximityPrompt")
	one.Name = "Hatch1"
	one.ActionText = "Hatch x1"
	one.ObjectText = egg.Name
	one.KeyboardKeyCode = Enum.KeyCode.E
	one.HoldDuration = 0
	one.MaxActivationDistance = 13
	one.RequiresLineOfSight = false
	one.Parent = eggPart
	local three = one:Clone()
	three.Name = "Hatch3"
	three.ActionText = "Hatch x3"
	three.KeyboardKeyCode = Enum.KeyCode.R
	three.UIOffset = Vector2.new(0, 80)
	three.Parent = eggPart

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

local function makeBoard(parent: Instance, name: string, title: string, position: Vector3, color: Color3)
	local facing = CFrame.new(position) * CFrame.Angles(0, math.pi, 0) -- front face looks toward spawn (+Z)
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
			position + Vector3.new(side * 10, -position.Y, 0),
			position.Y + 11,
			2.2,
			STONE,
			Enum.Material.Slate
		)
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.8,
			Position = position + Vector3.new(side * 10, 11.8, 0),
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

local function makeHouse(parent: Instance, houseId: string, position: Vector3): BasePart
	local house = Houses.List[houseId]
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
		local pole = position + Vector3.new(side * 5.5, 0, 1.5)
		column(platform, pole, 12, 0.4, GOLD, Enum.Material.Metal)
		part({
			Size = Vector3.new(3, 5, 0.2),
			Position = pole + Vector3.new(-side * 1.6, 9, 0),
			Color = house.Color,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = platform,
		})
		part({
			ClassName = "WedgePart",
			Size = Vector3.new(3, 1.2, 0.2),
			CFrame = CFrame.new(pole + Vector3.new(-side * 1.6, 5.9, 0)) * CFrame.Angles(math.pi, 0, 0),
			Color = house.Color,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = platform,
		})
	end
	statue(parent, HOUSE_STATUES[houseId], position + Vector3.new(0, 6, 0), 2)
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
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MerchantPrompt"
	prompt.ActionText = "Browse"
	prompt.ObjectText = "Wandering Merchant"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
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

-- Build ------------------------------------------------------------------------------------------

export type BuiltWorld = {
	Crystals: { { Model: Model, Zone: number } },
	EggStands: { Model },
	Gates: { BasePart },
	HousePedestals: { BasePart },
}

function WorldBuilder.Build(): BuiltWorld
	local result: BuiltWorld = { Crystals = {}, EggStands = {}, Gates = {}, HousePedestals = {} }

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
	part({
		Name = "HubFloor",
		Size = Vector3.new(WIDTH, 2, HUB_END - HUB_START),
		Position = Vector3.new(0, -1, hubMid),
		Color = rgb(85, 75, 120),
		Material = Enum.Material.Cobblestone,
		Parent = hub,
	})
	-- Plaza + path to the realms
	disc(hub, Vector3.new(0, 0.05, 5), 46, 0.2, rgb(120, 105, 160), Enum.Material.Slate)
	disc(hub, Vector3.new(0, 0.02, 5), 48, 0.2, rgb(170, 110, 255), Enum.Material.Neon)
	part({
		Size = Vector3.new(14, 0.2, HUB_END - 28),
		Position = Vector3.new(0, 0.05, (28 + HUB_END) / 2),
		Color = rgb(120, 105, 160),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, -32)
	spawn.Color = rgb(150, 110, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Parent = hub

	makeBoard(hub, "TrophyBoard", "Top Trophies", Vector3.new(-25, 11, -55), rgb(0, 255, 225))
	makeBoard(hub, "EssenceBoard", "Top Essence", Vector3.new(0, 11, -55), rgb(140, 255, 200))
	makeBoard(hub, "HouseBoard", "House War", Vector3.new(25, 11, -55), rgb(255, 200, 90))
	makeObelisk(hub, Vector3.new(0, 0, 5))

	for _, pos in
		{
			Vector3.new(-44, 0, -45),
			Vector3.new(44, 0, -45),
			Vector3.new(-44, 0, 0),
			Vector3.new(44, 0, 0),
			Vector3.new(-44, 0, 40),
			Vector3.new(44, 0, 40),
		}
	do
		makeLamp(hub, pos, rgb(200, 160, 255))
	end

	for i, id in Houses.Order do
		table.insert(result.HousePedestals, makeHouse(hub, id, Vector3.new(-30 + (i - 1) * 30, 0, 32)))
	end

	-- Champion Egg under a golden arch, guarded by a Titan Unicorn statue
	local championPos = Vector3.new(-36, 0, -16)
	table.insert(result.EggStands, makeEggStand(hub, "ChampionEgg", championPos))
	for _, side in { -1, 1 } do
		column(hub, championPos + Vector3.new(side * 7, 0, 3), 14, 1.6, GOLD, Enum.Material.Metal)
	end
	part({
		Size = Vector3.new(16, 1.4, 1.8),
		Position = championPos + Vector3.new(0, 14.4, 3),
		Color = GOLD,
		Material = Enum.Material.Metal,
		Parent = hub,
	})
	statue(hub, "TitanUnicorn", championPos + Vector3.new(0, 18.5, 3), 1.2)

	makeMerchant(hub, Vector3.new(36, 0, -16))

	-- Zones ------------------------------------------------------------------------------------
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = world
	for _, zone in Zones.List do
		local z0 = zoneStartZ(zone.Index)
		local folder = Instance.new("Folder")
		folder.Name = zone.Name
		folder.Parent = zonesFolder

		part({
			Name = "Ground",
			Size = Vector3.new(WIDTH, 2, ZONE_LENGTH),
			Position = Vector3.new(0, -1, z0 + ZONE_LENGTH / 2),
			Color = zone.GroundColor,
			Material = zone.GroundMaterial,
			Parent = folder,
		})
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

		-- Crystals spread over the zone (grid with jitter)
		local crystalFolder = Instance.new("Folder")
		crystalFolder.Name = "Crystals"
		crystalFolder.Parent = folder
		for i = 1, CRYSTALS_PER_ZONE do
			local col = (i - 1) % 5
			local row = (i - 1) // 5
			local x = -32 + col * 16 + rng:NextNumber(-2, 2)
			local z = z0 + 48 + row * 40 + rng:NextNumber(-5, 5)
			local crystal = makeCrystal(crystalFolder, zone, Vector3.new(x, 0, z))
			table.insert(result.Crystals, { Model = crystal, Zone = zone.Index })
		end

		table.insert(result.EggStands, makeEggStand(folder, zone.EggId, Vector3.new(-32, 0, z0 + 22)))

		-- Archway at the entrance of every zone, with a locked force field for paid zones
		makeArch(folder, zone, z0)
		if zone.UnlockCost > 0 then
			table.insert(result.Gates, makeGate(folder, zone, z0))
		end
	end

	-- Invisible boundary walls so nobody walks around the gates
	local worldEnd = zoneStartZ(#Zones.List + 1)
	local length = worldEnd - HUB_START
	local midZ = (HUB_START + worldEnd) / 2
	for _, x in { -WIDTH / 2 - 0.5, WIDTH / 2 + 0.5 } do
		part({
			Name = "Wall",
			Size = Vector3.new(1, 80, length),
			Position = Vector3.new(x, 40, midZ),
			Transparency = 1,
			Parent = world,
		})
	end
	for _, z in { HUB_START - 0.5, worldEnd + 0.5 } do
		part({
			Name = "Wall",
			Size = Vector3.new(WIDTH, 80, 1),
			Position = Vector3.new(0, 40, z),
			Transparency = 1,
			Parent = world,
		})
	end

	world.Parent = workspace
	return result
end

return WorldBuilder
