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

	-- grass top + a rocky underside that narrows to a point
	local top = slab(model, c, r * 2, 3, rgb(95, 180, 90), Enum.Material.Grass)
	top.Name = "Ground"
	slab(model, c + Vector3.new(0, 1.6, 0), r * 2 - 1, 0.2, rgb(110, 200, 100), Enum.Material.Grass)
	local layers = { { 0.92, 7 }, { 0.68, 9 }, { 0.42, 10 }, { 0.18, 9 } }
	local y = c.Y - 1.5
	for i, layer in layers do
		local h = layer[2]
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
	-- waterfalls pouring off three edges, with a little stream on top
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + 0.6
		local edge = c + Vector3.new(math.sin(a) * (r - 1), 0, math.cos(a) * (r - 1))
		local face = CFrame.lookAt(edge, Vector3.new(c.X, edge.Y, c.Z))
		part({
			Name = "Waterfall",
			Size = Vector3.new(7, 34, 0.6),
			CFrame = face * CFrame.new(0, -16, 1.2),
			Color = rgb(120, 200, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.35,
			CanCollide = false,
			Parent = model,
		})
		part({
			Size = Vector3.new(7, 0.3, r * 0.45),
			CFrame = face * CFrame.new(0, 1.6, -r * 0.22),
			Color = rgb(120, 200, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			CanCollide = false,
			Parent = model,
		})
	end
	-- glowing crystals around the rim
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local pos = c + Vector3.new(math.sin(a) * (r - 4), 1.5, math.cos(a) * (r - 4))
		local color = if i % 2 == 0 then rgb(255, 120, 230) else rgb(110, 220, 255)
		for j = 0, 2 do
			part({
				Name = "Crystal",
				Size = Vector3.new(1.2, 3.5 + j, 1.2),
				CFrame = CFrame.new(pos + Vector3.new(j - 1, (3.5 + j) / 2, (j % 2) * 0.8))
					* CFrame.Angles(math.rad(-12 + j * 12), a, math.rad(10 - j * 10)),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
				Parent = model,
			})
		end
	end
	-- a few round trees in the gaps between the station spots (not on the way back to the hub)
	for i, a in { math.pi / 2, math.pi, math.pi * 1.5 } do
		local base = c + Vector3.new(math.sin(a) * r * 0.78, 1.5, math.cos(a) * r * 0.78)
		part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 1.2, 1.2),
			CFrame = CFrame.new(base + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = rgb(115, 80, 55),
			Material = Enum.Material.Wood,
			Parent = model,
		})
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 6,
			Position = base + Vector3.new(0, 7.5, 0),
			Color = if i == 2 then rgb(255, 170, 210) else rgb(90, 190, 110),
			Material = Enum.Material.Grass,
			Parent = model,
		})
	end
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
	local back =
		helpers.ShopPad(model, "HubPad", c + Vector3.new(0, 1.6, r - 8), rgb(140, 220, 255), "🌀 Back to the hub")
	back:SetAttribute("Travel", "Hub")
	-- the Upgrade Stone: hold E on your own island to level it up
	local stone = part({
		Name = "UpgradeStone",
		Size = Vector3.new(3, 5, 3),
		CFrame = CFrame.new(c + Vector3.new(0, 4, -10)) * CFrame.Angles(0, math.pi / 4, 0),
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
	-- the stations (the ones not built yet say "coming soon")
	for _, station in Sanctuary.Stations do
		local spot = c + Vector3.new(station.Spot.X * r, 1.75, station.Spot.Y * r)
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
function Sanctuaries.Travel(player: Player, destination: any): (boolean, string?)
	local now = os.clock()
	if now - (lastTravel[player] or 0) < TRAVEL_COOLDOWN then
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
local function islandUnder(position: Vector3): Model?
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

function Sanctuaries.Start()
	-- the Upgrade Stone (only works on your own island)
	folder().DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") and d.Name == "UpgradePrompt" then
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
					if pos.Y > skyY - 60 and pos.Y < skyY - 8 then
						-- fell off an island: back onto it
						local island = islandUnder(pos) or islands[player]
						local pad = island and island:FindFirstChild("HomePad") :: BasePart?
						if pad then
							teleport(player, pad.Position)
							notify:FireClient(player, "Whoops! Back onto the island", rgb(140, 220, 255))
						end
					elseif pos.Y > skyY - 8 then
						local island = islandUnder(pos)
						local back = island and island:FindFirstChild("HubPad") :: BasePart?
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
