--[[
	Builds the Gloomwood forest (Shared/Gloomwood) from parts: dark ground, winding trails, twisted
	trees, glowing mushrooms, landmarks, Courier Lanterns, the Deep Camp and the thorn wall in front
	of the Deepwood. The same seed gives the same forest every time.

	GloomwoodBuilder.Build(parent) returns the layout Services/Gloomwood needs: where you arrive,
	the lanterns, and the hiding spots for each kind of crystal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gloomwood = require(ReplicatedStorage.Shared.Gloomwood)

local WorldBuilder = require(script.Parent.WorldBuilder)

local GloomwoodBuilder = {}

export type Layout = {
	Folder: Model,
	Arrival: Vector3,
	CampArrival: Vector3,
	Lanterns: { Vector3 },
	Spots: { [string]: { Vector3 } },
	Trails: { { Vector3 } },
}

local rgb = Color3.fromRGB
local SEED = 7
local TRAIL_WIDTH = 10
local TREE_SPACING = 25

local function part(props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function disc(parent: Instance, center: Vector3, diameter: number, height: number, color: Color3, material)
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local function folderIn(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Distance from p to the segment a-b, on the ground plane
local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = (b - a) * Vector3.new(1, 0, 1)
	local ap = (p - a) * Vector3.new(1, 0, 1)
	local len2 = ab:Dot(ab)
	local t = if len2 > 0 then math.clamp(ap:Dot(ab) / len2, 0, 1) else 0
	return (ap - ab * t).Magnitude
end

local function trailDistance(p: Vector3, trails: { { Vector3 } }): number
	local best = math.huge
	for _, trail in trails do
		for i = 1, #trail - 1 do
			best = math.min(best, segmentDistance(p, trail[i], trail[i + 1]))
		end
	end
	return best
end

-- A wobbly line between two (angle, distance) points
local function wander(rng: Random, a0: number, r0: number, a1: number, r1: number, steps: number): { Vector3 }
	local points = {}
	for i = 0, steps do
		local t = i / steps
		local wobble = if i == 0 or i == steps then 0 else rng:NextNumber(-0.04, 0.04)
		table.insert(points, Gloomwood.At(a0 + (a1 - a0) * t + wobble, r0 + (r1 - r0) * t + rng:NextNumber(-6, 6)))
	end
	return points
end

-- A wobbly loop all the way round at about distance r
local function loop(rng: Random, r: number, steps: number): { Vector3 }
	local points = {}
	local phase = rng:NextNumber(0, math.pi * 2)
	for i = 0, steps do
		local a = i / steps * math.pi * 2
		local radius = r + math.sin(a * 5 + phase) * 22 + math.sin(a * 2) * 10
		table.insert(points, Gloomwood.At(a, radius))
	end
	return points
end

local function buildTrail(parent: Instance, points: { Vector3 })
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		if len > 0.1 then
			part({
				Name = "Trail",
				Size = Vector3.new(TRAIL_WIDTH, 0.3, len + TRAIL_WIDTH * 0.6),
				CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.12, 0), b + Vector3.new(0, 0.12, 0)),
				Color = rgb(85, 70, 60),
				Material = Enum.Material.Ground,
				CanCollide = false,
				Parent = parent,
			})
		end
	end
end

local function tree(parent: Instance, rng: Random, pos: Vector3)
	local height = rng:NextNumber(18, 30)
	local lean = CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.12, 0.12))
	local base = CFrame.new(pos) * lean
	part({
		Name = "Trunk",
		Size = Vector3.new(2.6, height, 2.6),
		CFrame = base * CFrame.new(0, height / 2, 0),
		Color = rgb(60, 45, 50):Lerp(rgb(40, 35, 45), rng:NextNumber()),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local leaf = rgb(40, 70, 55):Lerp(rgb(60, 45, 85), rng:NextNumber() ^ 2)
	for i = 1, 2 do
		local size = rng:NextNumber(11, 16) - i * 2
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = base * CFrame.new(rng:NextNumber(-2, 2), height - 2 + i * 4, rng:NextNumber(-2, 2)),
			Color = leaf,
			Material = Enum.Material.Grass,
			CanCollide = false,
			CastShadow = false,
			Parent = parent,
		})
	end
end

local function mushroom(parent: Instance, rng: Random, pos: Vector3)
	local h = rng:NextNumber(0.8, 1.8)
	part({
		Name = "Stem",
		Size = Vector3.new(0.4, h, 0.4),
		Position = pos + Vector3.new(0, h / 2, 0),
		Color = rgb(220, 210, 190),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = parent,
	})
	part({
		Name = "Cap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 0.7, 1.4) * rng:NextNumber(0.8, 1.4),
		Position = pos + Vector3.new(0, h, 0),
		Color = if rng:NextNumber() < 0.5 then rgb(110, 240, 220) else rgb(200, 120, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
end

local function lantern(parent: Instance, pos: Vector3): Model
	local helpers = WorldBuilder.Helpers
	local model = Instance.new("Model")
	model.Name = "CourierLantern"
	part({
		Name = "Post",
		Size = Vector3.new(0.6, 8, 0.6),
		Position = pos + Vector3.new(0, 4, 0),
		Color = rgb(50, 40, 35),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local light = part({
		Name = "Glow",
		Size = Vector3.new(1.6, 1.8, 1.6),
		Position = pos + Vector3.new(0, 8.6, 0),
		Color = rgb(255, 200, 110),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	-- a soft circle on the ground: stand in it to send your satchel home
	local ring = disc(
		model,
		pos + Vector3.new(0, 0.15, 0),
		Gloomwood.LanternRadius * 2,
		0.1,
		rgb(255, 210, 120),
		Enum.Material.Neon
	)
	ring.Name = "Circle"
	ring.Transparency = 0.85
	ring.CanCollide = false
	ring.CanQuery = false
	helpers.Light(light, rgb(255, 200, 120), 22, 1.6)
	model.PrimaryPart = light
	model.Parent = parent
	return model
end

local function sign(parent: Instance, pos: Vector3, text: string, color: Color3, distance: number?)
	local helpers = WorldBuilder.Helpers
	local anchor = part({
		Name = "Sign",
		Size = Vector3.one,
		Position = pos,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
	helpers.Label(helpers.Billboard(anchor, UDim2.fromOffset(260, 44), Vector3.zero, distance or 90), {
		Text = text,
		TextColor3 = color,
	})
	return anchor
end

local function gate(parent: Instance, layout: any)
	local helpers = WorldBuilder.Helpers
	local g = Gloomwood.Place("Gate")
	local outward = (g - Gloomwood.Center).Unit
	-- the archway you came through (step back in to go to the hub)
	local face = CFrame.lookAt(g + outward * 4, g + outward * 10)
	for _, side in { -1, 1 } do
		part({
			Name = "GatePillar",
			Size = Vector3.new(3, 18, 3),
			CFrame = face * CFrame.new(side * 8, 9, 0),
			Color = rgb(55, 50, 70),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	part({
		Name = "GateTop",
		Size = Vector3.new(19, 2.5, 3),
		CFrame = face * CFrame.new(0, 19, 0),
		Color = rgb(55, 50, 70),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	local way = part({
		Name = "ExitGateway",
		Size = Vector3.new(13, 16, 0.4),
		CFrame = face * CFrame.new(0, 8, 0),
		Color = rgb(140, 220, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		Parent = parent,
	})
	way:SetAttribute("PortalTo", "Hub")
	sign(parent, g + outward * 4 + Vector3.new(0, 24, 0), "🌲 The Gloomwood", rgb(150, 230, 170), 160)
	helpers.Label(helpers.Billboard(way, UDim2.fromOffset(200, 30), Vector3.new(0, 10, 0), 60), {
		Text = "🌀 Back to the hub",
		TextColor3 = rgb(170, 230, 255),
	})
	layout.Arrival = g - outward * 12 + Vector3.new(0, 3, 0)
	-- the Deep Camp shortcut (works once you've found the camp)
	local side = outward:Cross(Vector3.yAxis).Unit
	helpers.ShopPad(parent, "CampPad", g - outward * 6 + side * 16, rgb(255, 190, 110), "⛺ To the Deep Camp")
	table.insert(layout.Lanterns, lantern(parent, g - outward * 6 - side * 16).PrimaryPart.Position)
end

local function deepCamp(parent: Instance, layout: any)
	local helpers = WorldBuilder.Helpers
	local c = Gloomwood.Place("DeepCamp")
	local camp = part({
		Name = "DeepCamp",
		Size = Vector3.new(30, 0.2, 30),
		Position = c + Vector3.new(0, 0.1, 0),
		Color = rgb(95, 80, 60),
		Material = Enum.Material.Ground,
		CanCollide = false,
		Parent = parent,
	})
	sign(parent, c + Vector3.new(0, 14, 0), "⛺ Deep Camp", rgb(255, 200, 120), 120)
	-- campfire
	local fire = part({
		Name = "Campfire",
		Size = Vector3.new(2, 1.4, 2),
		Position = c + Vector3.new(0, 0.7, 0),
		Color = rgb(255, 140, 50),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	Instance.new("Fire").Parent = fire
	helpers.Light(fire, rgb(255, 150, 70), 26, 2)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		part({
			Name = "Stone",
			Size = Vector3.new(1, 0.8, 1),
			Position = c + Vector3.new(math.sin(a) * 1.8, 0.4, math.cos(a) * 1.8),
			Color = rgb(110, 105, 115),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	-- two tents
	for _, a in { 2.2, 4.0 } do
		local spot = c + Vector3.new(math.sin(a) * 9, 0, math.cos(a) * 9)
		part({
			ClassName = "WedgePart",
			Name = "Tent",
			Size = Vector3.new(6, 4, 6),
			CFrame = CFrame.lookAt(spot + Vector3.new(0, 2, 0), c + Vector3.new(0, 2, 0)),
			Color = if a > 3 then rgb(170, 90, 70) else rgb(80, 120, 150),
			Material = Enum.Material.Fabric,
			Parent = parent,
		})
	end
	camp:SetAttribute("Discover", 25)
	local inward = (Gloomwood.Center - c) * Vector3.new(1, 0, 1)
	inward = inward.Unit
	local side = inward:Cross(Vector3.yAxis).Unit
	helpers.ShopPad(parent, "GatePad", c - side * 11, rgb(140, 220, 255), "🌲 Back to the gate")
	table.insert(layout.Lanterns, lantern(parent, c + side * 11).PrimaryPart.Position)
	layout.CampArrival = c + inward * 6 + Vector3.new(0, 3, 0)
end

local function burntClearing(parent: Instance, rng: Random)
	local c = Gloomwood.Place("BurntClearing")
	disc(parent, c + Vector3.new(0, 0.08, 0), 80, 0.15, rgb(35, 30, 30), Enum.Material.Slate).CanCollide = false
	for _ = 1, 9 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(8, 34)
		local h = rng:NextNumber(2, 6)
		part({
			Name = "BurntStump",
			Size = Vector3.new(2.4, h, 2.4),
			CFrame = CFrame.new(c + Vector3.new(math.sin(a) * d, h / 2, math.cos(a) * d))
				* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)),
			Color = rgb(30, 25, 25),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
	end
	for _ = 1, 6 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(4, 30)
		part({
			Name = "Ember",
			Size = Vector3.new(0.8, 0.3, 0.8),
			Position = c + Vector3.new(math.sin(a) * d, 0.25, math.cos(a) * d),
			Color = rgb(255, 110, 40),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = parent,
		})
	end
	sign(parent, c + Vector3.new(0, 10, 0), "🔥 The Burnt Clearing", rgb(255, 150, 90))
end

local function frozenPond(parent: Instance)
	local c = Gloomwood.Place("FrozenPond")
	disc(parent, c + Vector3.new(0, 0.1, 0), 84, 0.3, rgb(225, 235, 245), Enum.Material.Snow).CanCollide = false
	local ice = disc(parent, c + Vector3.new(0, 0.3, 0), 60, 0.3, rgb(150, 210, 240), Enum.Material.Ice)
	ice.Name = "Ice"
	ice.Transparency = 0.15
	sign(parent, c + Vector3.new(0, 10, 0), "❄️ The Frozen Pond", rgb(160, 230, 255))
end

local function deadTree(parent: Instance)
	local c = Gloomwood.Place("DeadTree")
	part({
		Name = "GiantDeadTree",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(60, 8, 8),
		CFrame = CFrame.new(c + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = rgb(70, 60, 60),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	for i, a in { 0.4, 2.1, 3.8, 5.2 } do
		local length = 18 - i * 2
		part({
			Name = "Branch",
			Size = Vector3.new(2, 2, length),
			CFrame = CFrame.new(c + Vector3.new(0, 36 + i * 5, 0))
				* CFrame.Angles(0, a, 0)
				* CFrame.Angles(math.rad(30), 0, 0)
				* CFrame.new(0, 0, -length / 2),
			Color = rgb(70, 60, 60),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
	end
	sign(parent, c + Vector3.new(0, 66, 0), "🌳 The Old Dead Tree", rgb(210, 200, 190), 200)
end

local function watchtower(parent: Instance)
	local c = Gloomwood.Place("Watchtower")
	for _, offset in { Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) } do
		part({
			Name = "TowerLeg",
			Size = Vector3.new(1.2, 22, 1.2),
			Position = c + offset + Vector3.new(0, 11, 0),
			Color = rgb(95, 75, 55),
			Material = Enum.Material.WoodPlanks,
			Parent = parent,
		})
	end
	-- the broken, tilted platform
	part({
		Name = "TowerFloor",
		Size = Vector3.new(11, 1, 11),
		CFrame = CFrame.new(c + Vector3.new(0, 22, 0)) * CFrame.Angles(math.rad(8), 0, math.rad(-12)),
		Color = rgb(110, 85, 60),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	part({
		Name = "FallenPlank",
		Size = Vector3.new(1, 0.6, 9),
		CFrame = CFrame.new(c + Vector3.new(7, 0.4, 3)) * CFrame.Angles(0, 0.7, 0),
		Color = rgb(110, 85, 60),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	sign(parent, c + Vector3.new(0, 30, 0), "🗼 The Broken Watchtower", rgb(220, 200, 160), 160)
end

-- The thorn wall in front of the Deepwood (opens in the next update)
local function deepwoodWall(parent: Instance, signAngle: number)
	local r = Gloomwood.RingMid
	local steps = 72
	for i = 0, steps - 1 do
		local a = i / steps * math.pi * 2
		local pos = Gloomwood.At(a, r)
		local len = 2 * math.pi * r / steps + 1
		local face = CFrame.lookAt(pos, Gloomwood.Center)
		part({
			Name = "ThornWall",
			Size = Vector3.new(len, 14, 4),
			CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)) * face.Rotation,
			Color = rgb(35, 25, 40),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		part({
			Name = "Thorns",
			ClassName = "WedgePart",
			Size = Vector3.new(len, 4, 3),
			CFrame = CFrame.new(pos + Vector3.new(0, 16, 0)) * face.Rotation,
			Color = rgb(60, 30, 70),
			Material = Enum.Material.Wood,
			CanCollide = false,
			Parent = parent,
		})
	end
	sign(parent, Gloomwood.At(signAngle, r + 8, 18), "🌑 The Deepwood: coming soon", rgb(200, 150, 255), 120)
end

-- Invisible wall round the outside so nobody walks off the edge
local function outerWall(parent: Instance)
	local r = Gloomwood.Radius + 6
	local steps = 96
	for i = 0, steps - 1 do
		local a = i / steps * math.pi * 2
		local pos = Gloomwood.At(a, r, 30)
		part({
			Name = "EdgeWall",
			Size = Vector3.new(2 * math.pi * r / steps + 2, 60, 2),
			CFrame = CFrame.lookAt(pos, Gloomwood.Center + Vector3.new(0, 30, 0)),
			Transparency = 1,
			CanQuery = false,
			Parent = parent,
		})
	end
end

local CLEARINGS = { Gate = 45, DeepCamp = 32, BurntClearing = 44, FrozenPond = 46, DeadTree = 16, Watchtower = 14 }

local function inClearing(p: Vector3, extra: number): boolean
	for name, radius in CLEARINGS do
		if ((p - Gloomwood.Place(name)) * Vector3.new(1, 0, 1)).Magnitude < radius + extra then
			return true
		end
	end
	return false
end

function GloomwoodBuilder.Build(parent: Instance): Layout
	local rng = Random.new(SEED)
	local model = Instance.new("Model")
	model.Name = "Gloomwood"
	local layout = {
		Folder = model,
		Arrival = Vector3.zero,
		CampArrival = Vector3.zero,
		Lanterns = {},
		Spots = {},
		Trails = {},
	} :: any

	-- ground: Edge, a darker Midwood, and a black floor behind the Deepwood wall
	local c = Gloomwood.Center
	local ground =
		disc(model, c - Vector3.new(0, 2, 0), Gloomwood.Radius * 2 + 40, 4, rgb(50, 66, 48), Enum.Material.Grass)
	ground.Name = "Ground"
	disc(model, c + Vector3.new(0, 0.02, 0), Gloomwood.RingEdge * 2, 0.1, rgb(40, 52, 42), Enum.Material.Grass).CanCollide =
		false
	disc(model, c + Vector3.new(0, 0.04, 0), Gloomwood.RingMid * 2, 0.1, rgb(25, 22, 30), Enum.Material.Slate).CanCollide =
		false

	-- trails: gate -> Deep Camp, a loop through the Edge, a loop through the Midwood, spurs to the
	-- landmarks and one up to the Deepwood wall
	local p = Gloomwood.Places
	local trails = {
		wander(rng, p.Gate.Angle, p.Gate.Distance - 10, p.DeepCamp.Angle, p.DeepCamp.Distance, 14),
		loop(rng, 520, 64),
		loop(rng, 325, 48),
		wander(rng, p.DeadTree.Angle, 520, p.DeadTree.Angle, p.DeadTree.Distance + 12, 3),
		wander(rng, p.Watchtower.Angle, 520, p.Watchtower.Angle, p.Watchtower.Distance + 10, 3),
		wander(rng, -0.35, 325, -0.35, Gloomwood.RingMid + 10, 5),
		wander(rng, 2.6, 520, 2.4, 325, 8),
		wander(rng, -2.6, 520, -2.3, 325, 8),
	}
	layout.Trails = trails
	local trailFolder = folderIn(model, "Trails")
	for _, trail in trails do
		buildTrail(trailFolder, trail)
	end

	-- landmarks
	local landmarks = folderIn(model, "Landmarks")
	gate(landmarks, layout)
	deepCamp(landmarks, layout)
	burntClearing(landmarks, rng)
	frozenPond(landmarks)
	deadTree(landmarks)
	watchtower(landmarks)
	deepwoodWall(landmarks, -0.35)
	outerWall(landmarks)

	-- Courier Lanterns along the trails: close together in the Edge, further apart in the Midwood
	local lanternFolder = folderIn(model, "Lanterns")
	local sinceLast = 0
	for _, trail in trails do
		for i = 1, #trail - 1 do
			local a, b = trail[i], trail[i + 1]
			sinceLast += (b - a).Magnitude
			local ring = Gloomwood.RingAt(b)
			local gap = if ring == "Edge" then 110 else 160
			if sinceLast >= gap and not inClearing(b, 0) then
				sinceLast = 0
				local side = ((b - a) * Vector3.new(1, 0, 1)).Unit:Cross(Vector3.yAxis)
				local lamp = lantern(lanternFolder, b + side * (TRAIL_WIDTH / 2 + 3))
				table.insert(layout.Lanterns, lamp.PrimaryPart.Position)
			end
		end
	end

	-- trees everywhere except on trails and in clearings
	local trees = folderIn(model, "Trees")
	local treeSpots = {}
	local half = Gloomwood.Radius
	for x = -half, half, TREE_SPACING do
		for z = -half, half, TREE_SPACING do
			local pos = c + Vector3.new(x + rng:NextNumber(-11, 11), 0, z + rng:NextNumber(-11, 11))
			local d = ((pos - c) * Vector3.new(1, 0, 1)).Magnitude
			if
				d > Gloomwood.RingMid + 8
				and d < Gloomwood.Radius - 2
				and trailDistance(pos, trails) > TRAIL_WIDTH / 2 + 4
				and not inClearing(pos, 0)
			then
				tree(trees, rng, pos)
				table.insert(treeSpots, pos)
			end
		end
	end

	-- glowing mushrooms
	local shrooms = folderIn(model, "Mushrooms")
	for _ = 1, 260 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(Gloomwood.RingMid + 10, Gloomwood.Radius - 10)
		local pos = Gloomwood.At(a, d)
		if trailDistance(pos, trails) > TRAIL_WIDTH / 2 + 1 then
			mushroom(shrooms, rng, pos)
		end
	end

	-- hiding spots for each kind of crystal: off the trail (so you have to look), not on a tree
	local function freeSpot(pos: Vector3): boolean
		local d = ((pos - c) * Vector3.new(1, 0, 1)).Magnitude
		if d < Gloomwood.RingMid + 10 or d > Gloomwood.Radius - 10 or inClearing(pos, -12) then
			return false
		end
		local fromTrail = trailDistance(pos, trails)
		if fromTrail < TRAIL_WIDTH / 2 + 4 or fromTrail > 45 then
			return false
		end
		for _, t in treeSpots do
			if ((t - pos) * Vector3.new(1, 0, 1)).Magnitude < 4 then
				return false
			end
		end
		return true
	end
	for _, crystal in Gloomwood.Crystals do
		local spots = {}
		local tries = 0
		while #spots < crystal.Spots and tries < crystal.Spots * 60 do
			tries += 1
			local pos
			if crystal.Near then
				local place = Gloomwood.Place(crystal.Near)
				local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(20, 75)
				pos = place + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
				-- the clearings themselves are fine for their own crystals
				local fromPlace = ((pos - place) * Vector3.new(1, 0, 1)).Magnitude
				if fromPlace < CLEARINGS[crystal.Near] then
					table.insert(spots, pos)
					continue
				end
			else
				pos = Gloomwood.At(
					rng:NextNumber(0, math.pi * 2),
					rng:NextNumber(Gloomwood.RingMid + 15, Gloomwood.Radius - 15)
				)
			end
			if freeSpot(pos) then
				table.insert(spots, pos)
			end
		end
		layout.Spots[crystal.Id] = spots
	end

	model.PrimaryPart = ground
	model.Parent = parent
	return layout
end

return GloomwoodBuilder
