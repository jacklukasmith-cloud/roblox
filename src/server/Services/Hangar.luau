--[[
	The Hangar (Shared/Vehicles): build hoverboards from the Gloom Crystals in your Vault, then ride
	them. Riding = a board welded under your feet and a speed (and jump) boost. Boards work in the hub,
	the forest's Edge and Midwood and on the sky islands; they switch off by themselves in the realms
	(farming stays the same) and in the Deepwood.

	Hangar.Build(player, id)         craft a vehicle (kept forever)
	Hangar.Ride(player, id?)         hop on (or off with nil / the same one)
	Hangar.SetSkin(player, skinId)   Board Skins pass colours
	Player attribute Riding = vehicle id while riding (the Bag's speed loop and the client read it).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Vehicles = require(Shared.Vehicles)
local Gloomwood = require(Shared.Gloomwood)
local Sanctuary = require(Shared.Sanctuary)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Monetization = require(script.Parent.Monetization)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Hangar = {}

local notify = Remotes.Event("Notify")
local rgb = Color3.fromRGB
local riding: { [Player]: { Id: string, Board: Model } } = {}

local function garage(data: any): any
	data.Vehicles = data.Vehicles or {}
	data.Vehicles.Owned = data.Vehicles.Owned or {}
	data.Vehicles.Skin = data.Vehicles.Skin or "Default"
	return data.Vehicles
end

-- Where boards are allowed: not in a realm, not in the Deepwood or the Heart
function Hangar.CanRideAt(position: Vector3): boolean
	local ring = Gloomwood.RingAt(position)
	if ring then
		return ring == "Edge" or ring == "Midwood"
	end
	-- the sky islands are always fine
	local fromPlaza = ((position - Sanctuary.Center) * Vector3.new(1, 0, 1)).Magnitude
	if
		fromPlaza < Sanctuary.RingRadius + Sanctuary.Radius(Sanctuary.MaxLevel) + 80
		and position.Y > Sanctuary.Center.Y - 80
	then
		return true
	end
	-- the main map: the realms start at the first zone's z
	local halfWidth = 100 * WorldBuilder.Helpers.Spread / 2 + 20
	if math.abs(position.X) <= halfWidth and position.Z >= WorldBuilder.Helpers.ZoneStart(1) then
		return false
	end
	return true
end

-- The board under your feet: an imported model ("Vehicle<Id>") or a chunky plank with thrusters
local function buildBoard(def: any, skinColor: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "Hoverboard"
	local color = skinColor or def.Color
	local template = WorldBuilder.Helpers.MeshTemplate("Vehicle" .. def.Id)
	local deck: BasePart
	if template then
		local copy = template:Clone()
		if copy:IsA("Model") then
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = false
					d.CanCollide = false
					d.Massless = true
				end
			end
			-- scale to 6 studs long and put it in the model
			local _, size = copy:GetBoundingBox()
			local longest = math.max(size.X, size.Y, size.Z)
			if longest > 0.01 then
				copy:ScaleTo(copy:GetScale() * 6 / longest)
			end
			for _, child in copy:GetChildren() do
				child.Parent = model
			end
			copy:Destroy()
		else
			copy.Anchored = false
			copy.CanCollide = false
			copy.Massless = true
			copy.Parent = model
		end
		deck = Instance.new("Part")
		deck.Name = "Deck"
		deck.Size = Vector3.new(2.6, 0.4, 6)
		deck.Transparency = 1
		deck.CanCollide = false
		deck.Massless = true
		deck.Parent = model
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= deck then
				if skinColor then
					d.Color = skinColor
				end
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = deck
				weld.Part1 = d
				weld.Parent = d
			end
		end
	else
		deck = Instance.new("Part")
		deck.Name = "Deck"
		deck.Size = Vector3.new(2.6, 0.4, 6)
		deck.Color = color
		deck.Material = if def.Glide then Enum.Material.Glass else Enum.Material.Neon
		deck.CanCollide = false
		deck.Massless = true
		deck.Parent = model
		for _, z in { -2.2, 2.2 } do
			local thruster = Instance.new("Part")
			thruster.Name = "Thruster"
			thruster.Shape = Enum.PartType.Cylinder
			thruster.Size = Vector3.new(0.5, 1.2, 1.2)
			thruster.Color = rgb(120, 230, 255)
			thruster.Material = Enum.Material.Neon
			thruster.CanCollide = false
			thruster.Massless = true
			thruster.CFrame = deck.CFrame * CFrame.new(0, -0.5, z) * CFrame.Angles(0, 0, math.pi / 2)
			thruster.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = deck
			weld.Part1 = thruster
			weld.Parent = thruster
		end
	end
	-- karts: a mushroom cap behind the driver (when there's no imported model) and a passenger Seat
	if (def.Seats or 1) > 1 then
		if not template then
			deck.Size = Vector3.new(3.4, 0.6, 8)
			for _, corner in
				{
					Vector3.new(-1.9, -0.4, -2.6),
					Vector3.new(1.9, -0.4, -2.6),
					Vector3.new(-1.9, -0.4, 2.6),
					Vector3.new(1.9, -0.4, 2.6),
				}
			do
				local wheel = Instance.new("Part")
				wheel.Name = "Wheel"
				wheel.Shape = Enum.PartType.Cylinder
				wheel.Size = Vector3.new(0.7, 1.4, 1.4)
				wheel.Color = rgb(60, 50, 50)
				wheel.Material = Enum.Material.SmoothPlastic
				wheel.CanCollide = false
				wheel.Massless = true
				wheel.CFrame = deck.CFrame * CFrame.new(corner)
				wheel.Parent = model
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = deck
				weld.Part1 = wheel
				weld.Parent = wheel
			end
			local cap = Instance.new("Part")
			cap.Name = "Cap"
			cap.Shape = Enum.PartType.Ball
			cap.Size = Vector3.new(3.2, 3.2, 3.2)
			cap.Color = color
			cap.Material = Enum.Material.SmoothPlastic
			cap.CanCollide = false
			cap.Massless = true
			cap.CFrame = deck.CFrame * CFrame.new(0, 0.9, 3.2)
			cap.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = deck
			weld.Part1 = cap
			weld.Parent = cap
		end
		for i = 2, def.Seats do
			local seat = Instance.new("Seat")
			seat.Name = "PassengerSeat"
			seat.Size = Vector3.new(2, 0.5, 2)
			seat.Color = rgb(255, 240, 220)
			seat.Material = Enum.Material.Fabric
			seat.CanCollide = false
			seat.Massless = true
			seat.CFrame = deck.CFrame * CFrame.new(0, 2.6, 2.4 + (i - 2) * 2.2)
			seat.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = deck
			weld.Part1 = seat
			weld.Parent = seat
		end
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 1
	light.Parent = deck
	model.PrimaryPart = deck
	return model
end

function Hangar.IsRiding(player: Player): string?
	local r = riding[player]
	return r and r.Id or nil
end

-- Walk-speed and jump multipliers while riding (1 when not)
function Hangar.SpeedMultiplier(player: Player): (number, number)
	local r = riding[player]
	local def = r and Vehicles.Get(r.Id)
	return if def then def.Speed else 1, if def then def.Jump or 1 else 1
end

local function dismount(player: Player, quiet: boolean?)
	local r = riding[player]
	if not r then
		return
	end
	riding[player] = nil
	r.Board:Destroy()
	player:SetAttribute("Riding", nil)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.JumpPower = Vehicles.BaseJump
	end
	if not quiet then
		notify:FireClient(player, "🛹 Hopped off", rgb(180, 200, 220))
	end
end

-- Hop on a vehicle you own (nil, or the one you're on, hops off). Returns ok, message.
function Hangar.Ride(player: Player, id: any): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data then
		return false, nil
	end
	if id == nil or (riding[player] and riding[player].Id == id) then
		dismount(player)
		return true, nil
	end
	local def = type(id) == "string" and Vehicles.Get(id)
	if not def then
		return false, nil
	end
	local g = garage(data)
	if not g.Owned[id] then
		return false, "Build it at the Hangar on your island first"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid then
		return false, nil
	end
	if not Hangar.CanRideAt(root.Position) then
		return false,
			"🛹 No hoverboards here: they work in the hub, the forest's Edge and Midwood, and on the islands"
	end
	dismount(player, true)
	local skin = Vehicles.GetSkin(g.Skin or "Default")
	local board = buildBoard(def, skin and skin.Color)
	board:PivotTo(root.CFrame * CFrame.new(0, -3.1, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = board.PrimaryPart
	weld.Parent = board.PrimaryPart
	board.Parent = character
	riding[player] = { Id = id, Board = board }
	player:SetAttribute("Riding", id)
	humanoid.JumpPower = Vehicles.BaseJump * (def.Jump or 1)
	g.LastRidden = id
	PlayerData.MarkChanged(player)
	return true,
		if (def.Seats or 1) > 1
			then `{def.Icon} Riding the {def.Name}! A friend can sit on the back`
			else `{def.Icon} Riding the {def.Name}!`
end

-- Build a vehicle at the Hangar. Returns ok, message.
function Hangar.Build(player: Player, id: any): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	local def = type(id) == "string" and Vehicles.Get(id)
	if not data or not def then
		return false, nil
	end
	if def.ComingSoon then
		return false, "Coming soon!"
	end
	local g = garage(data)
	if g.Owned[id] then
		return false, "You already have one"
	end
	local vault = data.Gloom and data.Gloom.Vault or {}
	if not Vehicles.CanAfford(vault, def) then
		return false, "You need more Gloom Crystals in your Vault for that"
	end
	local essence = Economy.GetProductEssence(player, def.Essence)
	if data.Essence < essence then
		return false, `You need 💎 {Format.Number(essence - data.Essence)} more Essence`
	end
	data.Essence -= essence
	for cid, n in def.Cost do
		vault[cid] -= n
		if vault[cid] <= 0 then
			vault[cid] = nil
		end
	end
	g.Owned[id] = true
	g.LastRidden = g.LastRidden or id
	data.Stats.VehiclesBuilt = (data.Stats.VehiclesBuilt or 0) + 1
	PlayerData.MarkChanged(player)
	return true, `{def.Icon} You built the {def.Name}! Press 🛹 (or R) to ride it`
end

function Hangar.SetSkin(player: Player, skinId: any): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	local skin = type(skinId) == "string" and Vehicles.GetSkin(skinId)
	if not data or not skin then
		return false, nil
	end
	if skin.Color and not Monetization.Owns(player, "BoardSkins") then
		return false, "Board Skins is a game pass"
	end
	garage(data).Skin = skinId
	PlayerData.MarkChanged(player)
	-- repaint if you're riding
	local r = riding[player]
	if r then
		Hangar.Ride(player, r.Id)
		Hangar.Ride(player, r.Id)
	end
	return true, `Skin: {skin.Name}`
end

function Hangar.Start()
	Players.PlayerRemoving:Connect(function(player)
		riding[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			dismount(player, true)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterRemoving:Connect(function()
			dismount(player, true)
		end)
	end
	-- hop off by yourself where boards aren't allowed
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, r in riding do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root or not r.Board.Parent then
					dismount(player, true)
				elseif not Hangar.CanRideAt(root.Position) then
					dismount(player, true)
					notify:FireClient(player, "🛹 Hoverboards switch off here", rgb(180, 200, 220))
				end
			end
		end
	end)
end

return Hangar
