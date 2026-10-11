--[[
	Builds the whole map from code, so the game is playable straight from `rojo build`.
	Swap any of this for hand-built models later - services only care about:
	  - crystals passed to Crystals.Register
	  - egg / gate / house prompts wired up in Main
	  - the board parts in workspace.World.Hub (TrophyBoard, EssenceBoard, HouseBoard, SurgeObelisk)

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
local Houses = require(Shared.Houses)
local Format = require(Shared.Format)

local WorldBuilder = {}

local WIDTH = 100
local HUB_START, HUB_END = -60, 50
local ZONE_LENGTH = 130
local CRYSTALS_PER_ZONE = 10

local rng = Random.new(2024) -- fixed seed = same layout every server

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.TextStrokeTransparency = 0.4
	l.Size = UDim2.fromScale(1, 1)
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
	b.AlwaysOnTop = false
	b.LightInfluence = 0
	b.MaxDistance = maxDistance or 120
	b.Adornee = adornee
	b.Parent = adornee
	return b
end

local function zoneStartZ(index: number): number
	return HUB_END + (index - 1) * ZONE_LENGTH
end

local function makeBoard(parent: Instance, name: string, title: string, position: Vector3, color: Color3)
	local board = part({
		Name = name,
		Size = Vector3.new(18, 20, 1),
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.pi, 0), -- front face looks toward spawn (+Z)
		Color = Color3.fromRGB(35, 25, 60),
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(360, 400)
	gui.LightInfluence = 0
	gui.Parent = board
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
	board.Parent = parent
end

local function makeEggStand(parent: Instance, eggId: string, position: Vector3)
	local egg = Eggs.Get(eggId) :: Eggs.EggDef
	local model = Instance.new("Model")
	model.Name = eggId
	part({
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 10, 10),
		CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 50, 90),
		Material = Enum.Material.Slate,
		Parent = model,
	})
	local eggPart = part({
		Name = "Egg",
		Size = Vector3.new(5, 7, 5),
		Position = position + Vector3.new(0, 5.5, 0),
		Color = egg.Color,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = eggPart
	local light = Instance.new("PointLight")
	light.Color = egg.Color
	light.Range = 14
	light.Parent = eggPart

	-- Name, price and odds (transparent odds = trust)
	local gui =
		billboard(eggPart, UDim2.fromOffset(220, 60 + #egg.Drops * 22), Vector3.new(0, 7 + #egg.Drops * 0.5, 0), 60)
	local layout = Instance.new("UIListLayout")
	layout.Parent = gui
	label(gui, { Text = egg.Name, Size = UDim2.new(1, 0, 0, 32), TextColor3 = egg.Color, LayoutOrder = 0 })
	label(gui, {
		Text = `{Format.Number(egg.Cost)} {egg.Currency}`,
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = Color3.fromRGB(255, 230, 120),
		LayoutOrder = 1,
	})
	local odds = Eggs.GetOdds(egg, 1)
	for i, drop in egg.Drops do
		local def = Creatures.Get(drop.Creature) :: Creatures.CreatureDef
		label(gui, {
			Text = `{def.Name}  {Format.Percent(odds[i])}`,
			Size = UDim2.new(1, 0, 0, 20),
			TextColor3 = Creatures.Rarities[def.Rarity].Color,
			LayoutOrder = 1 + i,
		})
	end

	local one = Instance.new("ProximityPrompt")
	one.Name = "Hatch1"
	one.ActionText = "Hatch x1"
	one.ObjectText = egg.Name
	one.KeyboardKeyCode = Enum.KeyCode.E
	one.HoldDuration = 0
	one.MaxActivationDistance = 12
	one.RequiresLineOfSight = false
	one.Parent = eggPart
	local three = one:Clone()
	three.Name = "Hatch3"
	three.ActionText = "Hatch x3"
	three.KeyboardKeyCode = Enum.KeyCode.R
	three.UIOffset = Vector2.new(0, 80)
	three.Parent = eggPart

	model:SetAttribute("EggId", eggId)
	model.Parent = parent
	return model
end

local function makeCrystal(parent: Instance, zone: Zones.ZoneDef, position: Vector3): Part
	local crystal = part({
		Name = "Crystal",
		Size = Vector3.new(3.5, 6, 3.5),
		CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-10, 10))),
		Color = zone.CrystalColor,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = zone.CrystalColor
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = crystal

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Enabled = false
	burst.Color = ColorSequence.new(zone.CrystalColor)
	burst.LightEmission = 1
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Speed = NumberRange.new(12, 20)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Lifetime = NumberRange.new(0.4, 0.8)
	burst.Parent = crystal

	local gui = billboard(crystal, UDim2.fromOffset(110, 22), Vector3.new(0, 4.5, 0), 70)
	gui.Name = "HealthGui"
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0.5, 0)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = zone.CrystalColor
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	label(back, { Name = "Amount", Text = "", ZIndex = 2 })
	return crystal
end

local function decorate(parent: Instance, zone: Zones.ZoneDef, z0: number)
	for _ = 1, 14 do
		local x = rng:NextNumber(-WIDTH / 2 + 4, WIDTH / 2 - 4)
		if math.abs(x) < 14 then
			x += if x < 0 then -14 else 14 -- keep the centre path clear
		end
		local z = rng:NextNumber(z0 + 10, z0 + ZONE_LENGTH - 10)
		local height = rng:NextNumber(6, 14)
		part({
			Name = "Trunk",
			Size = Vector3.new(1.5, height, 1.5),
			Position = Vector3.new(x, height / 2, z),
			Color = zone.GroundColor:Lerp(Color3.new(0, 0, 0), 0.5),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		part({
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(6, 10),
			Position = Vector3.new(x, height + 2, z),
			Color = zone.DecorColor,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
			CanCollide = false,
			Parent = parent,
		})
	end
end

export type BuiltWorld = {
	Crystals: { { Part: BasePart, Zone: number } },
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

	local world = Instance.new("Folder")
	world.Name = "World"
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world

	-- Lighting
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 180)
	Lighting.Ambient = Color3.fromRGB(80, 70, 110)

	-- Hub ------------------------------------------------------------------------
	part({
		Name = "HubFloor",
		Size = Vector3.new(WIDTH, 2, HUB_END - HUB_START),
		Position = Vector3.new(0, -1, (HUB_START + HUB_END) / 2),
		Color = Color3.fromRGB(70, 60, 110),
		Material = Enum.Material.Cobblestone,
		Parent = hub,
	})
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, -30)
	spawn.Color = Color3.fromRGB(150, 110, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Parent = hub

	makeBoard(hub, "TrophyBoard", "Top Trophies", Vector3.new(-25, 11, -55), Color3.fromRGB(0, 255, 225))
	makeBoard(hub, "EssenceBoard", "Top Essence", Vector3.new(0, 11, -55), Color3.fromRGB(140, 255, 200))
	makeBoard(hub, "HouseBoard", "House War", Vector3.new(25, 11, -55), Color3.fromRGB(255, 200, 90))

	local obelisk = part({
		Name = "SurgeObelisk",
		Size = Vector3.new(5, 16, 5),
		Position = Vector3.new(0, 8, 5),
		Color = Color3.fromRGB(170, 110, 255),
		Material = Enum.Material.Neon,
		Parent = hub,
	})
	local surgeGui = billboard(obelisk, UDim2.fromOffset(260, 90), Vector3.new(0, 11, 0), 200)
	surgeGui.Name = "SurgeGui"
	label(surgeGui, { Name = "Text", Text = "Mana Surge" })

	-- Houses
	for i, id in Houses.Order do
		local house = Houses.List[id]
		local pedestal = part({
			Name = id,
			Size = Vector3.new(6, 3, 6),
			Position = Vector3.new(-30 + (i - 1) * 30, 1.5, 30),
			Color = house.Color,
			Material = Enum.Material.Neon,
			Parent = hub,
		})
		local banner = part({
			Name = "Banner",
			Size = Vector3.new(5, 8, 0.4),
			Position = pedestal.Position + Vector3.new(0, 7, 0),
			Color = house.Color,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = pedestal,
		})
		local gui = billboard(banner, UDim2.fromOffset(200, 60), Vector3.new(0, 6, 0), 80)
		label(gui, { Text = `{house.Name}\n"{house.Motto}"`, TextColor3 = house.Color })
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Join House"
		prompt.ObjectText = house.Name
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = pedestal
		pedestal:SetAttribute("HouseId", id)
		table.insert(result.HousePedestals, pedestal)
	end

	-- Champion Egg (bought with Trophies)
	table.insert(result.EggStands, makeEggStand(hub, "ChampionEgg", Vector3.new(-38, 0, -15)))

	-- Wandering Merchant (client opens the shop when the prompt is triggered)
	local stall = part({
		Name = "Merchant",
		Size = Vector3.new(10, 5, 5),
		Position = Vector3.new(38, 2.5, -15),
		Color = Color3.fromRGB(130, 85, 50),
		Material = Enum.Material.WoodPlanks,
		Parent = hub,
	})
	part({
		Name = "Awning",
		Size = Vector3.new(12, 0.5, 7),
		Position = stall.Position + Vector3.new(0, 5, 0),
		Color = Color3.fromRGB(170, 60, 200),
		Material = Enum.Material.Fabric,
		Parent = stall,
	})
	local merchantGui = billboard(stall, UDim2.fromOffset(220, 50), Vector3.new(0, 7, 0), 80)
	label(merchantGui, { Text = "Wandering Merchant", TextColor3 = Color3.fromRGB(255, 200, 120) })
	local merchantPrompt = Instance.new("ProximityPrompt")
	merchantPrompt.Name = "MerchantPrompt"
	merchantPrompt.ActionText = "Browse"
	merchantPrompt.ObjectText = "Wandering Merchant"
	merchantPrompt.HoldDuration = 0
	merchantPrompt.MaxActivationDistance = 12
	merchantPrompt.RequiresLineOfSight = false
	merchantPrompt.Parent = stall

	-- Zones ----------------------------------------------------------------------
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

		local sign = part({
			Name = "Sign",
			Size = Vector3.new(1, 1, 1),
			Position = Vector3.new(0, 18, z0 + 12),
			Transparency = 1,
			CanCollide = false,
			Parent = folder,
		})
		local signGui = billboard(sign, UDim2.fromOffset(320, 60), Vector3.zero, 150)
		label(signGui, { Text = zone.Name, TextColor3 = zone.CrystalColor })

		decorate(folder, zone, z0)

		-- Crystals spread over the zone (grid with jitter)
		local crystalFolder = Instance.new("Folder")
		crystalFolder.Name = "Crystals"
		crystalFolder.Parent = folder
		for i = 1, CRYSTALS_PER_ZONE do
			local col = (i - 1) % 5
			local row = (i - 1) // 5
			local x = -32 + col * 16 + rng:NextNumber(-3, 3)
			local z = z0 + 45 + row * 40 + rng:NextNumber(-6, 6)
			local crystal = makeCrystal(crystalFolder, zone, Vector3.new(x, 0, z))
			table.insert(result.Crystals, { Part = crystal, Zone = zone.Index })
		end

		table.insert(result.EggStands, makeEggStand(folder, zone.EggId, Vector3.new(-38, 0, z0 + 22)))

		-- Gate into this zone (zone 1 is open from the hub)
		if zone.UnlockCost > 0 then
			local gate = part({
				Name = "Gate",
				Size = Vector3.new(WIDTH, 30, 1.5),
				Position = Vector3.new(0, 15, z0),
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
					Text = `{zone.Name}\n{Format.Number(zone.UnlockCost)} Essence`,
					Size = UDim2.fromScale(0.5, 0.5),
					Position = UDim2.fromScale(0.25, 0.25),
				})
			end
			local terminal = part({
				Name = "GateTerminal",
				Size = Vector3.new(4, 4, 4),
				Position = Vector3.new(0, 2, z0 - 4),
				Color = zone.CrystalColor,
				Material = Enum.Material.Neon,
				Shape = Enum.PartType.Ball,
				Parent = gate,
			})
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = `Unlock ({Format.Number(zone.UnlockCost)} Essence)`
			prompt.ObjectText = zone.Name
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = terminal
			table.insert(result.Gates, gate)
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
