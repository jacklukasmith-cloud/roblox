--[[
	Builds the whole low-poly world from blocks: four gardens in a row, the path,
	trees, flowers, lanterns, gates between gardens and one Bloom Battle arena per garden.
	No meshes or uploads needed. Parts tagged "Sway" are gently animated by the client,
	and the drifting clouds live in Workspace.BloomWorld.Clouds.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.BloomShared.Config)
local Util = require(ReplicatedStorage.BloomShared.Util)

local World = {}

local rng = Random.new(20261025)
local L = Config.ZoneLength
local W = Config.ZoneHalfWidth

local root: Folder
local arenas: Folder

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or root
	return p
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function jitter(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.clamp(s + rng:NextNumber(-amount, amount), 0, 1), math.clamp(v + rng:NextNumber(-amount, amount), 0, 1))
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function zoneStart(i: number): number
	return (i - 1) * L
end

local function arenaCenter(i: number): Vector3
	return Vector3.new(-48, 0, zoneStart(i) + L / 2)
end

local function lakeCenter(): Vector3
	return Vector3.new(50, 0, zoneStart(3) + L / 2)
end

-- Is this spot free for decoration?
local function free(x: number, z: number, zone: number, margin: number): boolean
	if math.abs(x) < 16 + margin then
		return false
	end
	local zLocal = z - zoneStart(zone)
	if zLocal < 12 or zLocal > L - 12 then
		return false
	end
	local a = arenaCenter(zone)
	if (Vector2.new(x, z) - Vector2.new(a.X, a.Z)).Magnitude < 26 + margin then
		return false
	end
	if zone == 3 then
		local c = lakeCenter()
		if math.abs(x - c.X) < 32 + margin and math.abs(z - c.Z) < 52 + margin then
			return false
		end
	end
	return math.abs(x) < W - 6
end

local function randomSpot(zone: number, margin: number): (number, number)?
	for _ = 1, 30 do
		local x = rng:NextNumber(-W + 6, W - 6)
		local z = zoneStart(zone) + rng:NextNumber(12, L - 12)
		if free(x, z, zone, margin) then
			return x, z
		end
	end
	return nil
end

-- Pieces -------------------------------------------------------------------------------

local function ground(zone: number, parent: Folder)
	local info = Config.Zones[zone]
	local tile = 20 -- ZoneLength and 2 * ZoneHalfWidth are both multiples of 20
	local z0 = zoneStart(zone)
	local lc = lakeCenter()
	for z = z0 + tile / 2, z0 + L - tile / 2 + 0.01, tile do
		for x = -W + tile / 2, W - tile / 2 + 0.01, tile do
			if zone == 3 and math.abs(x - lc.X) < 30 and math.abs(z - lc.Z) < 50 then
				continue -- the lake bed goes here
			end
			local onPath = math.abs(x) < tile
			local edge = math.abs(x) > W - tile * 1.5
			local h = if onPath then 0.15 else rng:NextNumber(0, 0.6)
			if edge then
				h += rng:NextNumber(1, 4)
			end
			part({
				Name = "Ground",
				Size = Vector3.new(tile, 6, tile),
				Position = Vector3.new(x, -3 + h, z),
				Color = if onPath then jitter(info.Path, 0.02) else jitter(pick(info.Ground), 0.03),
				Parent = parent,
			})
		end
	end
	-- Low-poly hills along both edges
	for _ = 1, 14 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local size = rng:NextNumber(14, 30)
		part({
			Name = "Hill",
			Size = Vector3.new(size, size * rng:NextNumber(0.5, 0.9), size),
			CFrame = CFrame.new(side * (W - rng:NextNumber(0, 8)), 0, z0 + rng:NextNumber(0, L))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			Color = jitter(pick(info.Ground), 0.05),
			Parent = parent,
		})
	end
end

local function tree(x: number, z: number, info, parent: Folder, big: number?)
	local scale = (big or 1) * rng:NextNumber(0.8, 1.3)
	local trunkH = 7 * scale
	local model = Instance.new("Model")
	model.Name = "Tree"
	part({
		Name = "Trunk",
		Size = Vector3.new(1.4 * scale, trunkH, 1.4 * scale),
		CFrame = CFrame.new(x, trunkH / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Color = jitter(Color3.fromRGB(156, 122, 96), 0.04),
		Parent = model,
	})
	local layers = rng:NextInteger(2, 3)
	for i = 1, layers do
		local s = (7 - i * 1.4) * scale
		local leaf = part({
			Name = "Leaves",
			Size = Vector3.new(s, s * 0.8, s),
			CFrame = CFrame.new(x, trunkH + (i - 1) * s * 0.55, z)
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25)),
			Color = jitter(pick(info.Leaf), 0.04),
			Parent = model,
		})
		CollectionService:AddTag(leaf, "Sway")
	end
	model.Parent = parent
end

local function flower(x: number, z: number, info, parent: Folder, glow: boolean?)
	local h = rng:NextNumber(0.8, 1.8)
	part({
		Name = "Stem",
		Size = Vector3.new(0.18, h, 0.18),
		Position = Vector3.new(x, h / 2, z),
		Color = Color3.fromRGB(120, 168, 110),
		CastShadow = false,
		CanCollide = false,
		Parent = parent,
	})
	local head = part({
		Name = "Bloom",
		Size = Vector3.new(0.7, 0.35, 0.7),
		CFrame = CFrame.new(x, h, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Color = pick(info.Flower),
		Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		CastShadow = false,
		CanCollide = false,
		Parent = parent,
	})
	CollectionService:AddTag(head, "Sway")
end

local function rock(x: number, z: number, parent: Folder)
	local s = rng:NextNumber(1.5, 4)
	part({
		Name = "Rock",
		Size = Vector3.new(s, s * 0.7, s * rng:NextNumber(0.8, 1.3)),
		CFrame = CFrame.new(x, s * 0.2, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)),
		Color = jitter(Color3.fromRGB(196, 196, 190), 0.04),
		Parent = parent,
	})
end

local function lantern(x: number, z: number, parent: Folder, color: Color3)
	part({
		Name = "Post",
		Size = Vector3.new(0.5, 6, 0.5),
		Position = Vector3.new(x, 3, z),
		Color = Color3.fromRGB(120, 100, 88),
		Parent = parent,
	})
	local lamp = part({
		Name = "Lamp",
		Size = Vector3.new(1.3, 1.5, 1.3),
		CFrame = CFrame.new(x, 6.6, z) * CFrame.Angles(0, math.rad(45), 0),
		Color = color,
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = lamp
	CollectionService:AddTag(lamp, "Lantern")
end

local function crystal(x: number, z: number, parent: Folder, color: Color3)
	for _ = 1, rng:NextInteger(2, 4) do
		local h = rng:NextNumber(2, 6)
		local c = part({
			Name = "Crystal",
			Size = Vector3.new(h * 0.35, h, h * 0.35),
			CFrame = CFrame.new(x + rng:NextNumber(-1.5, 1.5), h * 0.4, z + rng:NextNumber(-1.5, 1.5))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)),
			Color = jitter(color, 0.05),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			CastShadow = false,
			Parent = parent,
		})
		CollectionService:AddTag(c, "Glimmer")
	end
end

local function billboard(adornee: BasePart, title: string, subtitle: string, color: Color3, size: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(size, size * 0.3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, adornee.Size.Y / 2 + 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.62)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = title
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 84, 100)
	stroke.Thickness = 2.5
	stroke.Transparency = 0.2
	stroke.Parent = t
	t.Parent = gui
	local s = Instance.new("TextLabel")
	s.Name = "Subtitle"
	s.BackgroundTransparency = 1
	s.Position = UDim2.fromScale(0, 0.62)
	s.Size = UDim2.fromScale(1, 0.38)
	s.Font = Enum.Font.FredokaOne
	s.TextScaled = true
	s.TextColor3 = Color3.fromRGB(255, 255, 255)
	s.Text = subtitle
	local stroke2 = stroke:Clone()
	stroke2.Parent = s
	s.Parent = gui
	gui.Parent = adornee
	return gui
end

local function gate(zone: number, parent: Folder)
	local info = Config.Zones[zone]
	local z = zoneStart(zone)
	local model = Instance.new("Model")
	model.Name = "Gate" .. zone
	for _, side in { -1, 1 } do
		part({
			Name = "Pillar",
			Size = Vector3.new(4, 16, 4),
			CFrame = CFrame.new(side * 16, 8, z) * CFrame.Angles(0, math.rad(45), 0),
			Color = Color3.fromRGB(236, 228, 214),
			Parent = model,
		})
		part({
			Name = "Cap",
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(side * 16, 17.5, z) * CFrame.Angles(math.rad(45), math.rad(45), 0),
			Color = info.Flower[1],
			Material = Enum.Material.Neon,
			Parent = model,
		})
		-- Hedge wall so the gate can't be walked around
		local hedgeLen = W - 18
		part({
			Name = "Hedge",
			Size = Vector3.new(hedgeLen, 12, 5),
			Position = Vector3.new(side * (18 + hedgeLen / 2), 6, z),
			Color = jitter(pick(info.Leaf), 0.03),
			Parent = model,
		})
		for i = 1, 6 do
			local s = rng:NextNumber(4, 7)
			part({
				Name = "HedgeTop",
				Size = Vector3.new(s, s, s),
				CFrame = CFrame.new(side * (18 + i / 7 * hedgeLen), 12, z) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), 0),
				Color = jitter(pick(info.Leaf), 0.05),
				Parent = model,
			})
		end
	end
	part({
		Name = "Beam",
		Size = Vector3.new(36, 2.5, 3),
		Position = Vector3.new(0, 15.5, z),
		Color = Color3.fromRGB(236, 228, 214),
		Parent = model,
	})
	local barrier = part({
		Name = "Barrier",
		Size = Vector3.new(28, 14, 1),
		Position = Vector3.new(0, 7, z),
		Color = info.Flower[1],
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CastShadow = false,
		Parent = model,
	})
	barrier:SetAttribute("Zone", zone)
	CollectionService:AddTag(barrier, "Gate")
	billboard(
		barrier,
		info.Name,
		"Needs " .. Util.Format(info.Need) .. " Bloom  ·  x" .. info.Multiplier .. " Bloom",
		info.Flower[1],
		22
	)
	model.Parent = parent
end

local function arena(zone: number, parent: Folder)
	local info = Config.Zones[zone]
	local c = arenaCenter(zone)
	local model = Instance.new("Model")
	model.Name = "Arena" .. zone
	model:SetAttribute("Zone", zone)
	for i = 0, 1 do
		part({
			Name = "Floor",
			Size = Vector3.new(34, 1.2, 34),
			CFrame = CFrame.new(c + Vector3.new(0, 0.4 + i * 0.05, 0)) * CFrame.Angles(0, math.rad(45 * i), 0),
			Color = if i == 0 then Color3.fromRGB(240, 234, 222) else Color3.fromRGB(232, 224, 212),
			Parent = model,
		})
	end
	for i, side in { -1, 1 } do
		local pad = part({
			Name = if i == 1 then "PadA" else "PadB",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 9, 9),
			CFrame = CFrame.new(c + Vector3.new(side * 12, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if i == 1 then Color3.fromRGB(244, 186, 200) else Color3.fromRGB(176, 206, 240),
			Material = Enum.Material.Neon,
			Transparency = 0.25,
			CastShadow = false,
			Parent = model,
		})
		-- Little flower posts at each corner
		for _, dz in { -14, 14 } do
			part({
				Name = "Post",
				Size = Vector3.new(1.4, 4, 1.4),
				CFrame = CFrame.new(c + Vector3.new(side * 14, 3, dz)) * CFrame.Angles(0, math.rad(45), 0),
				Color = Color3.fromRGB(236, 228, 214),
				Parent = model,
			})
			local top = part({
				Name = "PostTop",
				Size = Vector3.new(1.6, 1.6, 1.6),
				CFrame = CFrame.new(c + Vector3.new(side * 14, 5.6, dz)) * CFrame.Angles(math.rad(45), math.rad(45), 0),
				Color = pad.Color,
				Material = Enum.Material.Neon,
				Parent = model,
			})
			CollectionService:AddTag(top, "Glimmer")
		end
	end
	part({
		Name = "Rope",
		Size = Vector3.new(22, 0.35, 0.35),
		Position = c + Vector3.new(0, 3.2, 0),
		Color = Color3.fromRGB(250, 244, 232),
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	local marker = part({
		Name = "Marker",
		Size = Vector3.new(1.4, 1.4, 1.4),
		CFrame = CFrame.new(c + Vector3.new(0, 3.2, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = Color3.fromRGB(255, 236, 170),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		Position = c + Vector3.new(0, 7, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	billboard(sign, "Bloom Battle", "Stand on a pad to challenge", info.Flower[1], 18)
	model.PrimaryPart = marker
	model.Parent = parent
end

local function lake(parent: Folder)
	local c = lakeCenter()
	local water = part({
		Name = "Water",
		Size = Vector3.new(60, 1, 100),
		Position = c + Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(168, 214, 228),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Reflectance = 0.15,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
	water:SetAttribute("Water", true)
	part({
		Name = "LakeBed",
		Size = Vector3.new(60, 1, 100),
		Position = c + Vector3.new(0, -1.2, 0),
		Color = Color3.fromRGB(120, 168, 176),
		Parent = parent,
	})
	for _ = 1, 22 do
		local pad = part({
			Name = "LilyPad",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, rng:NextNumber(2, 4), rng:NextNumber(2, 4)),
			CFrame = CFrame.new(c + Vector3.new(rng:NextNumber(-26, 26), 0.75, rng:NextNumber(-46, 46))) * CFrame.Angles(0, 0, math.rad(90)),
			Color = jitter(Color3.fromRGB(140, 196, 140), 0.05),
			CanCollide = false,
			Parent = parent,
		})
		CollectionService:AddTag(pad, "Float")
	end
	for i = -3, 3 do
		part({
			Name = "SteppingStone",
			Size = Vector3.new(4, 1.2, 4),
			CFrame = CFrame.new(c + Vector3.new(i * 7, 0.5, math.sin(i) * 6)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
			Color = jitter(Color3.fromRGB(212, 210, 202), 0.03),
			Parent = parent,
		})
	end
end

local function clouds(parent: Folder)
	local f = folder("Clouds", parent)
	for _ = 1, 26 do
		local model = Instance.new("Model")
		model.Name = "Cloud"
		local base = Vector3.new(rng:NextNumber(-300, 300), rng:NextNumber(90, 140), rng:NextNumber(-100, #Config.Zones * L + 100))
		local first
		for i = 1, rng:NextInteger(3, 5) do
			local s = rng:NextNumber(10, 22)
			local p = part({
				Name = "Puff",
				Size = Vector3.new(s * 1.4, s * 0.6, s),
				Position = base + Vector3.new(i * 9 - 18, rng:NextNumber(-2, 3), rng:NextNumber(-6, 6)),
				Color = Color3.fromRGB(255, 252, 250),
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Parent = model,
			})
			CollectionService:AddTag(p, "Cloud")
			first = first or p
		end
		model.PrimaryPart = first
		model.Parent = f
	end
end

local function bounds(parent: Folder)
	local length = #Config.Zones * L
	for _, side in { -1, 1 } do
		part({
			Name = "Bound",
			Size = Vector3.new(2, 120, length + 40),
			Position = Vector3.new(side * (W + 1), 60, length / 2),
			Transparency = 1,
			Parent = parent,
		})
	end
	part({ Name = "Bound", Size = Vector3.new(W * 2, 120, 2), Position = Vector3.new(0, 60, -1), Transparency = 1, Parent = parent })
	part({ Name = "Bound", Size = Vector3.new(W * 2, 120, 2), Position = Vector3.new(0, 60, length + 1), Transparency = 1, Parent = parent })
end

-- Build --------------------------------------------------------------------------------

function World.Build()
	local old = workspace:FindFirstChild("BloomWorld")
	if old then
		old:Destroy()
	end
	-- A fresh "Baseplate" place would show its grey plate around the gardens.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	root = folder("BloomWorld", workspace)
	arenas = folder("BloomArenas", workspace)

	for zone, info in Config.Zones do
		local z = folder(info.Name, root)
		ground(zone, z)
		if zone > 1 then
			gate(zone, z)
		end
		arena(zone, arenas)

		local deco = folder("Decor", z)
		for _ = 1, 34 do
			local x, zz = randomSpot(zone, 4)
			if x then
				tree(x, zz, info, deco, if zone == 4 then 1.25 else nil)
			end
		end
		for _ = 1, 26 do
			local x, zz = randomSpot(zone, 0)
			if x then
				for _ = 1, rng:NextInteger(3, 7) do
					local fx, fz = x + rng:NextNumber(-3, 3), zz + rng:NextNumber(-3, 3)
					flower(fx, fz, info, deco, zone == 4)
				end
			end
		end
		for _ = 1, 12 do
			local x, zz = randomSpot(zone, 1)
			if x then
				rock(x, zz, deco)
			end
		end
		for i = 1, math.floor(L / 40) do
			local side = if i % 2 == 0 then -1 else 1
			lantern(side * 11, zoneStart(zone) + i * 40 - 10, deco, if zone == 4 then Color3.fromRGB(196, 210, 255) else Color3.fromRGB(255, 224, 170))
		end

		if zone == 2 then
			-- Lavender rows
			for row = 1, 8 do
				local x = 30 + row * 6
				for zz = zoneStart(zone) + 24, zoneStart(zone) + L - 24, 5 do
					local s = rng:NextNumber(1.6, 2.4)
					local bush = part({
						Name = "Lavender",
						Size = Vector3.new(s, s * 1.2, s),
						CFrame = CFrame.new(x, s * 0.5, zz) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
						Color = jitter(pick(info.Leaf), 0.05),
						CanCollide = false,
						Parent = deco,
					})
					CollectionService:AddTag(bush, "Sway")
				end
			end
		elseif zone == 3 then
			lake(deco)
		elseif zone == 4 then
			for _ = 1, 16 do
				local x, zz = randomSpot(zone, 2)
				if x then
					crystal(x, zz, deco, pick({ Color3.fromRGB(186, 200, 255), Color3.fromRGB(200, 240, 236), Color3.fromRGB(236, 210, 255) }))
				end
			end
		end
	end

	bounds(root)
	clouds(root)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.3, 16)
	spawn.Color = Color3.fromRGB(250, 236, 210)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = root

	return arenas
end

return World
