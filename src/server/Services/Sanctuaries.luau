--[[
	Sanctuaries: each player in the server gets a floating sky island (Shared/Sanctuary). It's built
	when their data loads and removed when they leave.

	Sanctuaries.Travel(player, "Home" | "Hub" | userId) moves you to your island, back to the hub, or
	to someone else's island. Sanctuaries.Upgrade(player) spends Essence on the next level (the
	Upgrade Stone on your island): the island grows and you earn a little more Essence. The Sanctuary portal in the hub's Portal Plaza takes you home, the
	glowing circle on each island takes you back, and anyone who falls off is put back on.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Sanctuary = require(Shared.Sanctuary)
local Remotes = require(Shared.Remotes)

local Format = require(Shared.Format)
local Daily = require(Shared.Daily)
local Items = require(Shared.Items)

local PlayerData = require(script.Parent.PlayerData)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Sanctuaries = {}

local rgb = Color3.fromRGB
local notify = Remotes.Event("Notify")

local slotOf: { [Player]: number } = {}
local owner: { [number]: Player } = {}
local islands: { [Player]: Model } = {}
local lastTravel: { [Player]: number } = {}
local TRAVEL_COOLDOWN = 1.5
local lastUpgrade: { [Player]: number } = {}
local islandUnder: (Vector3) -> Model? -- defined further down

local function folder(): Folder
	local f = workspace:FindFirstChild("Sanctuaries")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Sanctuaries"
		f.Parent = workspace
	end
	return f :: Folder
end

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

-- A flat (lying down) cylinder: the island's layers, pads and the like
local function slab(parent: Instance, center: Vector3, diameter: number, height: number, color: Color3, material)
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local function levelOf(player: Player): number
	local data = PlayerData.Get(player) :: any
	return math.clamp(data and data.Sanctuary and data.Sanctuary.Level or 1, 1, Sanctuary.MaxLevel)
end

-- Builds the island model for a player at their slot
local function build(player: Player, slot: number): Model
	local helpers = WorldBuilder.Helpers
	local level = levelOf(player)
	local r = Sanctuary.Radius(level)
	local c = Sanctuary.SlotPosition(slot)
	local model = Instance.new("Model")
	model.Name = `Sanctuary_{player.UserId}`
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("Level", level)
	model:SetAttribute("Habitat", Sanctuary.HabitatKey(PlayerData.Get(player)))
	-- everything is laid out facing the Sky Plaza: local -Z points down the bridge, so the path
	-- from the bridge to your home spot (x = 0) stays clear
	local toPlaza = ((Sanctuary.Center - c) * Vector3.new(1, 0, 1)).Unit
	local frame = CFrame.lookAt(c, c + toPlaza)
	local function at(x: number, y: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local rng = Random.new(player.UserId + slot)

	-- grass top + a rocky underside that narrows to a point
	local top = slab(model, c, r * 2, 3, rgb(95, 180, 90), Enum.Material.Grass)
	top.Name = "Ground"
	slab(model, c + Vector3.new(0, 1.6, 0), r * 2 - 1, 0.2, rgb(110, 200, 100), Enum.Material.Grass)
	local depthScale = r / 40
	local layers = { { 0.92, 7 }, { 0.68, 9 }, { 0.42, 10 }, { 0.18, 9 } }
	local y = c.Y - 1.5
	for i, layer in layers do
		local h = layer[2] * depthScale
		slab(
			model,
			Vector3.new(c.X, y - h / 2, c.Z),
			r * 2 * layer[1],
			h,
			rgb(110, 90, 80):Lerp(rgb(70, 55, 60), i / #layers),
			Enum.Material.Rock
		)
		y -= h
	end
	-- local angle a: 0 = the back (hub circle side), pi = the bridge side
	local function rim(a: number, inset: number, height: number): Vector3
		return at(math.sin(a) * (r - inset), height, math.cos(a) * (r - inset))
	end
	-- waterfalls pouring off three edges (away from the bridge and the hub circle), with a stream on top
	for _, a in { 1.4, 4.1, 5.2 } do
		local edge = rim(a, 1, 0)
		local face = CFrame.lookAt(edge, Vector3.new(c.X, edge.Y, c.Z))
		part({
			Name = "Waterfall",
			Size = Vector3.new(9, 34 * depthScale, 0.6),
			CFrame = face * CFrame.new(0, -16 * depthScale, 1.2),
			Color = rgb(120, 200, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.35,
			CanCollide = false,
			Parent = model,
		})
		part({
			Size = Vector3.new(7, 0.3, r * 0.3),
			CFrame = face * CFrame.new(0, 1.6, -r * 0.15),
			Color = rgb(120, 200, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			CanCollide = false,
			Parent = model,
		})
	end
	-- glowing crystals around the rim (more on bigger islands)
	local crystals = 8 + level
	for i = 0, crystals - 1 do
		local a = (i + 0.5) / crystals * math.pi * 2
		local nearPath = math.abs(math.sin(a)) < 0.2 -- the bridge (pi) and the hub circle (0)
		if not nearPath then
			local pos = rim(a, 5, 1.5)
			local color = if i % 2 == 0 then rgb(255, 120, 230) else rgb(110, 220, 255)
			for j = 0, 2 do
				part({
					Name = "Crystal",
					Size = Vector3.new(1.4, 4 + j * 1.2, 1.4),
					CFrame = CFrame.new(pos + Vector3.new(j - 1, (4 + j * 1.2) / 2, (j % 2) * 0.8))
						* CFrame.Angles(math.rad(-12 + j * 12), a, math.rad(10 - j * 10)),
					Color = color,
					Material = Enum.Material.Neon,
					Transparency = 0.15,
					Parent = model,
				})
			end
		end
	end
	-- round trees dotted about (not on the path, the stations or the Upgrade Stone)
	local busy = { Vector3.new(14, 0, 0) }
	for _, station in Sanctuary.Stations do
		table.insert(busy, Vector3.new(station.Spot.X * r, 0, station.Spot.Y * r))
	end
	local trees = 0
	for _ = 1, 80 do
		if trees >= 8 + level * 2 then
			break
		end
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.3, 0.85) * r
		local spot = Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
		local free = math.abs(spot.X) > 10
		for _, b in busy do
			if (spot - b).Magnitude < 13 then
				free = false
			end
		end
		if free then
			table.insert(busy, spot)
			trees += 1
			local base = at(spot.X, 1.5, spot.Z)
			local size = rng:NextNumber(0.9, 1.5)
			part({
				Name = "Trunk",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(7 * size, 1.4 * size, 1.4 * size),
				CFrame = CFrame.new(base + Vector3.new(0, 3.5 * size, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = rgb(115, 80, 55),
				Material = Enum.Material.Wood,
				Parent = model,
			})
			part({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 7 * size,
				Position = base + Vector3.new(0, 8.5 * size, 0),
				Color = if trees % 3 == 0 then rgb(255, 170, 210) else rgb(90, 190, 110),
				Material = Enum.Material.Grass,
				Parent = model,
			})
		end
	end
	-- the sky bridge to the Sky Plaza (every island joins it, so you can walk to anyone's)
	local deckY = c.Y + 1.2
	local from = at(0, 0, -(r - 3))
	local to = Sanctuary.Center - toPlaza * (Sanctuary.PlazaRadius - 3)
	from = Vector3.new(from.X, deckY, from.Z)
	to = Vector3.new(to.X, deckY, to.Z)
	local length = (to - from).Magnitude
	local along = CFrame.lookAt((from + to) / 2, to)
	part({
		Name = "Bridge",
		Size = Vector3.new(Sanctuary.BridgeWidth, 1, length),
		CFrame = along,
		Color = rgb(150, 110, 75),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		local x = side * (Sanctuary.BridgeWidth / 2 - 0.3)
		part({
			Name = "BridgeRail",
			Size = Vector3.new(0.4, 0.4, length),
			CFrame = along * CFrame.new(x, 3, 0),
			Color = rgb(120, 85, 55),
			Material = Enum.Material.Wood,
			Parent = model,
		})
		local posts = math.floor(length / 16)
		for i = 0, posts do
			local z = -length / 2 + i * (length / math.max(posts, 1))
			local post = part({
				Name = "BridgePost",
				Size = Vector3.new(0.6, 3.5, 0.6),
				CFrame = along * CFrame.new(x, 1.5, z),
				Color = rgb(110, 75, 50),
				Material = Enum.Material.Wood,
				Parent = model,
			})
			-- a lantern on every third post
			if i % 3 == 1 then
				local lamp = part({
					Name = "BridgeLamp",
					Size = Vector3.new(0.9, 1.1, 0.9),
					CFrame = post.CFrame * CFrame.new(0, 2.3, 0),
					Color = rgb(255, 210, 130),
					Material = Enum.Material.Neon,
					CanCollide = false,
					Parent = model,
				})
				helpers.Light(lamp, rgb(255, 200, 130), 14, 1)
			end
		end
	end
	-- a name plate where your bridge meets the plaza, so visitors can find you
	local plate = part({
		Name = "BridgeSign",
		Size = Vector3.one,
		Position = to + toPlaza * 4 + Vector3.new(0, 7, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	helpers.Label(helpers.Billboard(plate, UDim2.fromOffset(220, 34), Vector3.zero, 120), {
		Text = `🏝️ {player.DisplayName} (Lv {level})`,
		TextColor3 = rgb(255, 210, 120),
	})
	-- arrival spot in the middle, with the owner's name above it
	local home = slab(model, c + Vector3.new(0, 1.7, 0), 8, 0.2, rgb(170, 140, 255), Enum.Material.Neon)
	home.Name = "HomePad"
	home.Transparency = 0.4
	home.CanCollide = false
	local sign = part({
		Name = "OwnerSign",
		Size = Vector3.one,
		Position = c + Vector3.new(0, 13, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local gui = helpers.Billboard(sign, UDim2.fromOffset(300, 64), Vector3.zero, 220)
	helpers.Label(gui, {
		Text = `🏝️ {player.DisplayName}'s Sanctuary`,
		TextColor3 = rgb(255, 210, 120),
		Size = UDim2.fromScale(1, 0.6),
	})
	helpers.Label(gui, {
		Name = "LevelText",
		Text = `Level {level}`,
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
	})
	-- the way back: walk into this circle to return to the hub
	local back = helpers.ShopPad(model, "HubPad", at(0, 1.6, r - 10), rgb(140, 220, 255), "🌀 Back to the hub")
	back:SetAttribute("Travel", "Hub")
	-- the Upgrade Stone: hold E on your own island to level it up
	local stone = part({
		Name = "UpgradeStone",
		Size = Vector3.new(3, 5, 3),
		CFrame = CFrame.new(at(14, 4, 0)) * CFrame.Angles(0, math.pi / 4, 0),
		Color = rgb(150, 120, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		Parent = model,
	})
	local cost = Sanctuary.UpgradeCost(level)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ObjectText = "Upgrade Stone"
	prompt.ActionText = if cost then `Upgrade (💎 {Format.Number(cost)})` else "Max level!"
	prompt.Enabled = cost ~= nil
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = stone
	local info = helpers.Billboard(stone, UDim2.fromOffset(240, 50), Vector3.new(0, 5, 0), 70)
	helpers.Label(info, {
		Text = if cost then `⬆️ Level {level + 1}: 💎 {Format.Number(cost)}` else "⭐ Max level",
		Size = UDim2.fromScale(1, 0.6),
	})
	helpers.Label(info, {
		Text = `+{math.floor((Sanctuary.EssenceBonus(level) - 1) * 100 + 0.5)}% Essence`,
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
		TextColor3 = rgb(140, 230, 255),
	})
	-- the ❤️ heart sign by the home spot: visitors like your island here
	Sanctuaries.BuildLikeSign(model, player, at(0, 1.6, -11))
	-- the island chest, opposite the stone: opens once a day
	Sanctuaries.BuildChest(model, player, CFrame.lookAt(at(-14, 1.6, 0), at(0, 1.6, 0)))
	-- the stations (the ones not built yet say "coming soon")
	for _, station in Sanctuary.Stations do
		local spot = at(station.Spot.X * r, 1.75, station.Spot.Y * r)
		local plate = slab(model, spot, 12, 0.2, rgb(150, 130, 100), Enum.Material.Cobblestone)
		plate.Name = station.Id .. "Spot"
		if station.Id == "PetHabitat" then
			-- a little fenced garden with a circle: the owner steps in to choose pets
			local pad = helpers.ShopPad(
				model,
				"HabitatPad",
				spot + Vector3.new(0, 0.1, 0),
				rgb(140, 230, 160),
				`🐾 Pet Habitat ({Sanctuary.HabitatSlots(level)} pets)`
			)
			pad:SetAttribute("Owner", player.UserId)
			for i = 0, 11 do
				if i ~= 3 then -- a gap to walk in through
					local a = i / 12 * math.pi * 2
					part({
						Name = "Fence",
						Size = Vector3.new(0.5, 2, 0.5),
						Position = spot + Vector3.new(math.sin(a) * 5.6, 1.1, math.cos(a) * 5.6),
						Color = rgb(235, 220, 190),
						Material = Enum.Material.Wood,
						CanCollide = false,
						Parent = model,
					})
				end
			end
			continue
		end
		if station.Id == "Cauldron" then
			-- a big bubbling pot: step into its circle to brew potions
			helpers.ShopPad(
				model,
				"CauldronPad",
				spot + Vector3.new(0, 0.1, 0),
				rgb(150, 255, 170),
				"⚗️ Alchemy Cauldron"
			)
			local back = at(station.Spot.X * r, 0, station.Spot.Y * r - 7)
			local brewing = false
			local data = PlayerData.Get(player) :: any
			if data and data.Cauldron and data.Cauldron.Brews then
				brewing = #data.Cauldron.Brews > 0
			end
			local base = Vector3.new(back.X, c.Y + 1.7, back.Z)
			local mesh = helpers.PlaceMesh(model, "AlchemyCauldron", CFrame.new(base), 7, true, true)
			if not mesh then
				-- built-in pot: legs, a round black pot and a rim
				for i = 0, 2 do
					local a = i / 3 * math.pi * 2
					part({
						Name = "PotLeg",
						Size = Vector3.new(0.6, 1.4, 0.6),
						Position = base + Vector3.new(math.sin(a) * 1.8, 0.7, math.cos(a) * 1.8),
						Color = rgb(40, 40, 45),
						Material = Enum.Material.Metal,
						Parent = model,
					})
				end
				part({
					Name = "Pot",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(5.5, 4.5, 5.5),
					Position = base + Vector3.new(0, 3.2, 0),
					Color = rgb(35, 35, 42),
					Material = Enum.Material.Metal,
					Parent = model,
				})
				slab(model, base + Vector3.new(0, 5.2, 0), 5, 0.5, rgb(60, 60, 70), Enum.Material.Metal).Name = "PotRim"
			end
			-- the brew itself (glows and bubbles while something's brewing)
			local liquid = slab(model, base + Vector3.new(0, 5.35, 0), 4.2, 0.3, rgb(60, 70, 60), Enum.Material.Neon)
			liquid.Name = "CauldronLiquid"
			liquid.CanCollide = false
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 3
			fire.Color = rgb(120, 255, 140)
			fire.SecondaryColor = rgb(80, 200, 255)
			fire.Parent = liquid
			Sanctuaries.ShowBrewing(model, brewing)
			continue
		end
		if station.Id == "Hangar" then
			-- an open workshop: step into its circle to build and pick hoverboards
			helpers.ShopPad(model, "HangarPad", spot + Vector3.new(0, 0.1, 0), rgb(255, 190, 110), "🛹 Hangar")
			local back = at(station.Spot.X * r, 0, station.Spot.Y * r + 8)
			local base = Vector3.new(back.X, c.Y + 1.7, back.Z)
			local facing = CFrame.lookAt(base, Vector3.new(spot.X, base.Y, spot.Z))
			local mesh = helpers.PlaceMesh(model, "Hangar", facing, 12, false, true)
			if not mesh then
				-- built-in shed: two side walls, a back wall, a slanted roof and a board rack
				for _, side in { -1, 1 } do
					part({
						Name = "HangarWall",
						Size = Vector3.new(0.8, 7, 9),
						CFrame = facing * CFrame.new(side * 5.6, 3.5, 0),
						Color = rgb(150, 110, 75),
						Material = Enum.Material.WoodPlanks,
						Parent = model,
					})
				end
				part({
					Name = "HangarBack",
					Size = Vector3.new(12, 7, 0.8),
					CFrame = facing * CFrame.new(0, 3.5, 4.2),
					Color = rgb(150, 110, 75),
					Material = Enum.Material.WoodPlanks,
					Parent = model,
				})
				part({
					Name = "HangarRoof",
					Size = Vector3.new(13.5, 0.6, 11),
					CFrame = facing * CFrame.new(0, 7.3, 0.5) * CFrame.Angles(math.rad(-10), 0, 0),
					Color = rgb(90, 70, 60),
					Material = Enum.Material.Slate,
					Parent = model,
				})
				-- boards on the rack (just for show)
				for i, color in { rgb(110, 200, 110), rgb(255, 240, 120), rgb(255, 190, 255) } do
					part({
						Name = "RackBoard",
						Size = Vector3.new(2.2, 0.3, 5),
						CFrame = facing
							* CFrame.new(-3.5 + i * 1.8, 1.4 + i * 1.1, 3.4)
							* CFrame.Angles(math.rad(70), 0, 0),
						Color = color,
						Material = Enum.Material.Neon,
						CanCollide = false,
						Parent = model,
					})
				end
			end
			continue
		end
		if station.Id == "Vault" then
			-- a crystal-topped chest: step into its circle to see and sell your Gloom Crystals
			helpers.ShopPad(model, "VaultPad", spot + Vector3.new(0, 0.1, 0), rgb(150, 200, 255), "💎 Crystal Vault")
			local chest = part({
				Name = "VaultChest",
				Size = Vector3.new(4, 3, 3),
				Position = spot + Vector3.new(0, 1.6, -6),
				Color = rgb(90, 80, 120),
				Material = Enum.Material.Slate,
				Parent = model,
			})
			for i = -1, 1 do
				part({
					Name = "VaultCrystal",
					Size = Vector3.new(0.8, 2 + math.abs(i), 0.8),
					CFrame = CFrame.new(chest.Position + Vector3.new(i * 1.2, 2 + math.abs(i) / 2, 0))
						* CFrame.Angles(0, 0, i * -0.3),
					Color = if i == 0 then rgb(170, 190, 255) else rgb(120, 230, 255),
					Material = Enum.Material.Neon,
					Parent = model,
				})
			end
			continue
		end
		local tag = helpers.Billboard(plate, UDim2.fromOffset(200, 44), Vector3.new(4, 0, 0), 80)
		helpers.Label(tag, { Text = `{station.Icon} {station.Name}`, Size = UDim2.fromScale(1, 0.6) })
		helpers.Label(tag, {
			Text = "coming soon",
			Position = UDim2.fromScale(0, 0.6),
			Size = UDim2.fromScale(1, 0.4),
			TextColor3 = rgb(200, 200, 220),
		})
	end
	helpers.Light(sign, rgb(255, 220, 160), 30, 1.2)
	model.PrimaryPart = top
	model.Parent = folder()
	return model
end

-- Island chest ------------------------------------------------------------------------------

local function chestReady(data: any): boolean
	return (data.Sanctuary.ChestDay or -1) < Daily.Today()
end

-- Sets the chest's prompt and glow to open/ready
local function refreshChest(model: Model, data: any)
	local chest = model:FindFirstChild("IslandChest")
	if not chest then
		return
	end
	local ready = chestReady(data)
	chest:SetAttribute("Ready", ready)
	for _, d in chest:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.ActionText = if ready then "Open" else "Opened · back tomorrow"
			d.Enabled = ready
		elseif d:IsA("PointLight") then
			d.Enabled = ready
		elseif d.Name == "ChestGlow" and d:IsA("BasePart") then
			d.Transparency = if ready then 0.2 else 0.8
		end
	end
end

-- The chest: an imported "IslandChest" model or a wooden box with a gold band, with a prompt
function Sanctuaries.BuildChest(model: Model, player: Player, cf: CFrame)
	local helpers = WorldBuilder.Helpers
	local holder = Instance.new("Model")
	holder.Name = "IslandChest"
	local base = cf.Position
	local mesh = helpers.PlaceMesh(holder, "IslandChest", cf, 4.5, false, true)
	local body: BasePart
	if mesh then
		body = mesh.PrimaryPart or mesh:FindFirstChildWhichIsA("BasePart") :: BasePart
	else
		body = part({
			Name = "ChestBody",
			Size = Vector3.new(4, 2.4, 2.8),
			CFrame = cf * CFrame.new(0, 1.2, 0),
			Color = rgb(130, 90, 55),
			Material = Enum.Material.WoodPlanks,
			Parent = holder,
		})
		part({
			Name = "ChestLid",
			Size = Vector3.new(4.2, 1, 3),
			CFrame = cf * CFrame.new(0, 2.9, 0),
			Color = rgb(110, 75, 45),
			Material = Enum.Material.WoodPlanks,
			Parent = holder,
		})
		part({
			Name = "ChestBand",
			Size = Vector3.new(0.8, 3.5, 3.1),
			CFrame = cf * CFrame.new(0, 1.75, 0),
			Color = rgb(255, 200, 80),
			Material = Enum.Material.Metal,
			Parent = holder,
		})
	end
	part({
		Name = "ChestGlow",
		Size = Vector3.new(5, 0.2, 5),
		CFrame = CFrame.new(base + Vector3.new(0, 0.12, 0)),
		Color = rgb(255, 220, 120),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
		Parent = holder,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChestPrompt"
	prompt.ObjectText = "Island Chest (daily)"
	prompt.ActionText = "Open"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	helpers.Light(body, rgb(255, 210, 120), 10, 1)
	local tag = helpers.Billboard(body, UDim2.fromOffset(200, 40), Vector3.new(0, 3.2, 0), 60)
	helpers.Label(tag, { Text = "🧰 Island Chest · once a day", Size = UDim2.fromScale(1, 1) })
	holder.PrimaryPart = body
	holder.Parent = model
	local data = PlayerData.Get(player) :: any
	if data then
		refreshChest(model, data)
	end
end

-- ❤️ Likes ------------------------------------------------------------------------------------

function Sanctuaries.BuildLikeSign(model: Model, player: Player, position: Vector3)
	local helpers = WorldBuilder.Helpers
	local data = PlayerData.Get(player) :: any
	local likes = data and data.Stats and data.Stats.Likes or 0
	local post = part({
		Name = "LikeSign",
		Size = Vector3.new(0.6, 4, 0.6),
		Position = position + Vector3.new(0, 2, 0),
		Color = rgb(140, 100, 70),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local heart = part({
		Name = "LikeHeart",
		Size = Vector3.new(1.8, 1.8, 0.6),
		CFrame = CFrame.new(position + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, 0, math.pi / 4),
		Color = rgb(255, 90, 140),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	helpers.Light(heart, rgb(255, 120, 160), 8, 0.8)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LikePrompt"
	prompt.ObjectText = `{player.DisplayName}'s Sanctuary`
	prompt.ActionText = "❤️ Like"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = post
	local tag = helpers.Billboard(heart, UDim2.fromOffset(160, 36), Vector3.new(0, 1.8, 0), 70)
	helpers.Label(tag, { Name = "LikesText", Text = `❤️ {Format.Number(likes)}`, Size = UDim2.fromScale(1, 1) })
end

local function refreshLikes(model: Model, likes: number)
	for _, d in model:GetDescendants() do
		if d.Name == "LikesText" and d:IsA("TextLabel") then
			d.Text = `❤️ {Format.Number(likes)}`
		end
	end
end

-- A visitor likes the island they're standing on. Returns ok, message.
function Sanctuaries.Like(player: Player, model: Model?): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data then
		return false, nil
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	model = model or (root and islandUnder(root.Position))
	if not model then
		return false, nil
	end
	local ownerId = model:GetAttribute("OwnerId")
	if ownerId == player.UserId then
		return false, "That's your own island! Like your friends' islands instead"
	end
	local today = Daily.Today()
	data.Sanctuary.Liked = data.Sanctuary.Liked or {}
	local key = tostring(ownerId)
	if data.Sanctuary.Liked[key] == today then
		return false, "You've liked this island today already"
	end
	-- tidy old days out
	for k, day in data.Sanctuary.Liked do
		if day ~= today then
			data.Sanctuary.Liked[k] = nil
		end
	end
	data.Sanctuary.Liked[key] = today
	data.Stats.LikesGiven = (data.Stats.LikesGiven or 0) + 1
	local Economy = require(script.Parent.Economy) :: any
	local essence = Economy.GetProductEssence(player, Sanctuary.LikeReward)
	Economy.AddEssence(player, essence)
	PlayerData.MarkChanged(player)
	-- the owner (online: they're in this server, since their island is)
	local owner = Players:GetPlayerByUserId(ownerId)
	local ownerData = owner and PlayerData.Get(owner) :: any
	if ownerData then
		ownerData.Stats.Likes = (ownerData.Stats.Likes or 0) + 1
		PlayerData.MarkChanged(owner)
		refreshLikes(model, ownerData.Stats.Likes)
		notify:FireClient(owner, `❤️ {player.DisplayName} liked your Sanctuary!`, rgb(255, 120, 160))
	end
	return true, `❤️ Liked! +💎 {Format.Number(essence)}`
end

Sanctuaries.Rng = Random.new()

-- Open your island's chest (once a day). Returns ok, message.
function Sanctuaries.OpenChest(player: Player): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data then
		return false, nil
	end
	if not chestReady(data) then
		return false, "You've opened your chest today: it refills at midnight UTC"
	end
	local model = islands[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not model or not root or islandUnder(root.Position) ~= model then
		return false, "The chest is on your own island"
	end
	local Economy = require(script.Parent.Economy) :: any
	local Bag = require(script.Parent.Bag) :: any
	local level = math.clamp(data.Sanctuary.Level or 1, 1, Sanctuary.MaxLevel)
	local crystals, item, count = Sanctuary.ChestLoot(level, Sanctuaries.Rng:NextNumber())
	local essence = Economy.GetProductEssence(player, crystals)
	Economy.AddEssence(player, essence)
	Bag.Give(player, item, count, true)
	data.Sanctuary.ChestDay = Daily.Today()
	data.Stats.ChestsOpened = (data.Stats.ChestsOpened or 0) + 1
	PlayerData.MarkChanged(player)
	refreshChest(model, data)
	local itemName = (Items.Get(item) or { Name = item }).Name
	return true,
		`🧰 Island chest: 💎 {Format.Number(essence)} + {count}x {itemName}! Level up your island for better loot`
end

-- The Sky Plaza in the middle of the ring: every island's bridge ends here. It has a circle back to
-- the hub and a big glowing crystal to steer by.
local plazaHubPad: BasePart? = nil
local function buildPlaza(): Model
	local helpers = WorldBuilder.Helpers
	local c = Sanctuary.Center
	local r = Sanctuary.PlazaRadius
	local model = Instance.new("Model")
	model.Name = "SkyPlaza"
	local top = slab(model, c, r * 2, 3, rgb(205, 200, 225), Enum.Material.Marble)
	top.Name = "Ground"
	slab(model, c + Vector3.new(0, 1.6, 0), r * 2 - 6, 0.2, rgb(110, 200, 100), Enum.Material.Grass)
	slab(model, c + Vector3.new(0, 1.65, 0), r * 0.7, 0.2, rgb(220, 215, 235), Enum.Material.Marble)
	local y = c.Y - 1.5
	for i, layer in { { 0.9, 14 }, { 0.6, 18 }, { 0.3, 16 } } do
		local h = layer[2]
		slab(
			model,
			Vector3.new(c.X, y - h / 2, c.Z),
			r * 2 * layer[1],
			h,
			rgb(120, 110, 130):Lerp(rgb(70, 60, 80), i / 3),
			Enum.Material.Rock
		)
		y -= h
	end
	-- the big crystal in the middle
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local h = if i == 0 then 26 else 12 + i * 2
		part({
			Name = "PlazaCrystal",
			Size = Vector3.new(3, h, 3),
			CFrame = CFrame.new(
				c
					+ Vector3.new(
						if i == 0 then 0 else math.sin(a) * 4,
						1.7 + h / 2,
						if i == 0 then 0 else math.cos(a) * 4
					)
			) * CFrame.Angles(if i == 0 then 0 else math.cos(a) * 0.3, 0, if i == 0 then 0 else -math.sin(a) * 0.3),
			Color = if i % 2 == 0 then rgb(170, 140, 255) else rgb(120, 220, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.1,
			Parent = model,
		})
	end
	local sign = part({
		Name = "PlazaSign",
		Size = Vector3.one,
		Position = c + Vector3.new(0, 34, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	helpers.Label(helpers.Billboard(sign, UDim2.fromOffset(300, 50), Vector3.zero, 400), {
		Text = "☁️ Sky Plaza",
		TextColor3 = rgb(200, 230, 255),
	})
	helpers.Light(sign, rgb(190, 170, 255), 60, 2)
	-- the way back to the hub
	local back =
		helpers.ShopPad(model, "PlazaHubPad", c + Vector3.new(0, 1.7, 22), rgb(140, 220, 255), "🌀 Back to the hub")
	back:SetAttribute("Travel", "Hub")
	plazaHubPad = back
	model.PrimaryPart = top
	model.Parent = folder()
	return model
end

-- Gives a player a free spot and builds their island
function Sanctuaries.Assign(player: Player): Model?
	if islands[player] then
		return islands[player]
	end
	for slot = 1, Sanctuary.Slots do
		if not owner[slot] then
			owner[slot] = player
			slotOf[player] = slot
			local ok, model = pcall(build, player, slot)
			if ok then
				islands[player] = model
				return model
			end
			warn("[Sanctuaries] " .. tostring(model))
			owner[slot] = nil
			slotOf[player] = nil
			return nil
		end
	end
	return nil
end

function Sanctuaries.Remove(player: Player)
	local slot = slotOf[player]
	if slot then
		owner[slot] = nil
	end
	slotOf[player] = nil
	if islands[player] then
		islands[player]:Destroy()
		islands[player] = nil
	end
	lastTravel[player] = nil
	lastUpgrade[player] = nil
end

function Sanctuaries.IslandOf(player: Player): Model?
	return islands[player]
end

-- The cauldron's brew glows green and bubbles while a potion is brewing (Services/Cauldron)
function Sanctuaries.ShowBrewing(island: Model, brewing: boolean)
	local liquid = island:FindFirstChild("CauldronLiquid") :: BasePart?
	if not liquid then
		return
	end
	liquid.Color = if brewing then Color3.fromRGB(110, 255, 140) else Color3.fromRGB(60, 70, 60)
	liquid.Transparency = if brewing then 0.05 else 0.3
	local fire = liquid:FindFirstChildOfClass("Fire")
	if fire then
		fire.Enabled = brewing
	end
	island:SetAttribute("Brewing", brewing)
end

-- Spends Essence on the next island level. Returns ok, message.
function Sanctuaries.Upgrade(player: Player): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data then
		return false, nil
	end
	local now = os.clock()
	if now - (lastUpgrade[player] or 0) < 1 then
		return false, nil
	end
	lastUpgrade[player] = now
	data.Sanctuary = data.Sanctuary or { Level = 1 }
	local level = math.clamp(data.Sanctuary.Level or 1, 1, Sanctuary.MaxLevel)
	local cost = Sanctuary.UpgradeCost(level)
	if not cost then
		return false, "Your Sanctuary is already max level!"
	end
	if data.Essence < cost then
		return false, `You need 💎 {Format.Number(cost - data.Essence)} more Essence`
	end
	data.Essence -= cost
	data.Sanctuary.Level = level + 1
	PlayerData.MarkChanged(player)
	-- rebuild it bigger: the new island goes up before the old one comes down
	local slot = slotOf[player]
	local old = islands[player]
	if slot then
		local ok, model = pcall(build, player, slot)
		if ok then
			islands[player] = model
			if old then
				old:Destroy()
			end
		else
			warn("[Sanctuaries] " .. tostring(model))
		end
	end
	local bonus = math.floor((Sanctuary.EssenceBonus(level + 1) - 1) * 100 + 0.5)
	return true, `🏝️ Sanctuary level {level + 1}! Now +{bonus}% Essence`
end

local function teleport(player: Player, position: Vector3): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return false
	end
	character:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

local function hubSpawn(): Vector3
	local world = workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	local spawn = hub and hub:FindFirstChild("HubSpawn") :: BasePart?
	return if spawn then spawn.Position else Vector3.new(0, 3, 0)
end

-- "Home", "Hub" or a user id (visit their island). Returns ok, message.
function Sanctuaries.Travel(player: Player, destination: any, force: boolean?): (boolean, string?)
	local now = os.clock()
	if not force and now - (lastTravel[player] or 0) < TRAVEL_COOLDOWN then
		return false, nil
	end
	local target: Model? = nil
	if destination == "Hub" then
		lastTravel[player] = now
		return teleport(player, hubSpawn()), nil
	elseif destination == "Home" then
		target = islands[player] or Sanctuaries.Assign(player)
		if not target then
			return false, "No room for your Sanctuary on this server"
		end
	elseif type(destination) == "number" then
		local other = Players:GetPlayerByUserId(destination)
		target = other and islands[other]
		if not target then
			return false, "That Sanctuary isn't here"
		end
	else
		return false, nil
	end
	local pad = (target :: Model):FindFirstChild("HomePad") :: BasePart?
	if not pad then
		return false, nil
	end
	lastTravel[player] = now
	local ok = teleport(player, pad.Position)
	local data = PlayerData.Get(player) :: any
	if ok and data then
		data.Stats.SanctuaryVisits = (data.Stats.SanctuaryVisits or 0) + 1
		PlayerData.MarkChanged(player)
	end
	return ok, nil
end

-- Which island (if any) a position is above
function islandUnder(position: Vector3): Model?
	for _, model in islands do
		local ground = model.PrimaryPart
		if ground then
			local flat = (position - ground.Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude <= ground.Size.Y / 2 + 25 then
				return model
			end
		end
	end
	return nil
end

-- Builds the Sky Plaza once
function Sanctuaries.EnsurePlaza(): Model
	return (folder():FindFirstChild("SkyPlaza") :: Model?) or buildPlaza()
end

function Sanctuaries.Start()
	Sanctuaries.EnsurePlaza()
	-- the Upgrade Stone (only works on your own island)
	folder().DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") and d.Name == "LikePrompt" then
			d.Triggered:Connect(function(player)
				local ok, message = Sanctuaries.Like(player, d:FindFirstAncestorOfClass("Model"))
				if message then
					notify:FireClient(player, message, if ok then rgb(255, 120, 160) else rgb(255, 170, 120))
				end
			end)
		elseif d:IsA("ProximityPrompt") and d.Name == "ChestPrompt" then
			d.Triggered:Connect(function(player)
				local ok, message = Sanctuaries.OpenChest(player)
				if message then
					notify:FireClient(player, message, if ok then rgb(255, 210, 120) else rgb(255, 170, 120))
				end
			end)
		elseif d:IsA("ProximityPrompt") and d.Name == "UpgradePrompt" then
			d.Triggered:Connect(function(player)
				local model = d:FindFirstAncestorOfClass("Model")
				if not model or model:GetAttribute("OwnerId") ~= player.UserId then
					notify:FireClient(player, "Only the owner can upgrade this Sanctuary", rgb(255, 170, 120))
					return
				end
				local ok, message = Sanctuaries.Upgrade(player)
				if message then
					notify:FireClient(player, message, if ok then rgb(255, 210, 120) else rgb(255, 120, 120))
				end
			end)
		end
	end)

	PlayerData.Loaded:Connect(function(player)
		Sanctuaries.Assign(player)
	end)
	for _, player in Players:GetPlayers() do
		if PlayerData.Get(player) then
			Sanctuaries.Assign(player)
		end
	end
	Players.PlayerRemoving:Connect(Sanctuaries.Remove)

	-- the hub's Sanctuary portal takes you home
	task.spawn(function()
		local world = workspace:WaitForChild("World", 30)
		local hub = world and world:WaitForChild("Hub", 30)
		if not hub then
			return
		end
		for _, d in hub:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("PortalTo") == "Sanctuary" then
				d.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then
						Sanctuaries.Travel(player, "Home")
					end
				end)
			end
		end
	end)

	-- the circle on each island takes you back; falling off puts you back on
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local pos = root.Position
					local skyY = Sanctuary.Center.Y
					local fromCenter = ((pos - Sanctuary.Center) * Vector3.new(1, 0, 1)).Magnitude
					local inSky = fromCenter < Sanctuary.RingRadius + Sanctuary.Radius(Sanctuary.MaxLevel) + 60
					if inSky and pos.Y > skyY - 80 and pos.Y < skyY - 8 then
						-- fell off: back onto the plaza (if that's where you fell) or the island
						local island = islandUnder(pos) or islands[player]
						local pad = island and island:FindFirstChild("HomePad") :: BasePart?
						local spot = if fromCenter < Sanctuary.PlazaRadius + 25
							then Sanctuary.Center + Vector3.new(0, 2, 0)
							elseif pad then pad.Position
							else nil
						if spot then
							teleport(player, spot)
							notify:FireClient(player, "Whoops! Back up you go", rgb(140, 220, 255))
						end
					elseif inSky and pos.Y > skyY - 8 then
						local island = islandUnder(pos)
						local back = island and island:FindFirstChild("HubPad") :: BasePart?
						if not island then
							back = plazaHubPad
						end
						if back then
							local flat = (pos - back.Position) * Vector3.new(1, 0, 1)
							if flat.Magnitude <= 4.5 and math.abs(pos.Y - back.Position.Y) < 8 then
								Sanctuaries.Travel(player, "Hub")
							end
						end
					end
				end
			end
		end
	end)
end

return Sanctuaries
