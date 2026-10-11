--[[
	Renders every player's equipped creatures floating behind them. Done on each client
	(not the server) so movement is smooth and costs the server nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local State = require(script.Parent.State)

local Followers = {}

type Follower = { Model: Model, Root: BasePart, Offset: Vector3, Phase: number }

local folder = Instance.new("Folder")
folder.Name = "Followers"
folder.Parent = workspace

local byPlayer: { [Player]: { Key: string, List: { Follower } } } = {}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- Simple stylised creature: body orb, eyes, ears/horns tinted with the accent colour.
local function build(id: string, variant: string): (Model, BasePart)
	local def = Creatures.Get(id) :: Creatures.CreatureDef
	local rarity = Creatures.Rarities[def.Rarity]
	local size = rarity.Size
	local model = Instance.new("Model")
	model.Name = id

	local bodyColor = def.Color
	if variant == "Shiny" then
		bodyColor = def.Color:Lerp(Color3.fromRGB(255, 230, 120), 0.45)
	end
	local body = makePart({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Color = bodyColor,
		Material = if rarity.Order >= 5 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		Anchored = true,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		local eye = makePart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * 0.22,
			Color = Color3.new(0.05, 0.05, 0.1),
			Material = Enum.Material.SmoothPlastic,
			CFrame = body.CFrame * CFrame.new(side * size * 0.2, size * 0.1, -size * 0.42),
			Parent = model,
		})
		weld(body, eye)
		local ear = makePart({
			Size = Vector3.new(size * 0.18, size * 0.45, size * 0.18),
			Color = def.Accent,
			Material = Enum.Material.SmoothPlastic,
			CFrame = body.CFrame * CFrame.new(side * size * 0.28, size * 0.5, 0) * CFrame.Angles(0, 0, -side * 0.35),
			Parent = model,
		})
		weld(body, ear)
	end
	if rarity.Order >= 4 then
		local light = Instance.new("PointLight")
		light.Color = def.Accent
		light.Range = 6 + rarity.Order
		light.Brightness = 1
		light.Parent = body
	end
	if variant ~= "Normal" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Rate = if variant == "Rainbow" then 14 else 6
		sparkle.Lifetime = NumberRange.new(0.6, 1.1)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.Size = NumberSequence.new(0.25, 0)
		sparkle.LightEmission = 1
		sparkle.Color = if variant == "Rainbow"
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 80)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
			})
			else ColorSequence.new(Color3.fromRGB(255, 235, 140))
		sparkle.Parent = body
	end
	model.PrimaryPart = body
	return model, body
end

local function clear(player: Player)
	local entry = byPlayer[player]
	if entry then
		for _, f in entry.List do
			f.Model:Destroy()
		end
	end
	byPlayer[player] = nil
end

local function rebuild(player: Player)
	local value = player:GetAttribute("Followers") or ""
	if State.PotatoMode then
		value = ""
	end
	local entry = byPlayer[player]
	if entry and entry.Key == value then
		return
	end
	clear(player)
	local list = {}
	local index = 0
	for _, token in string.split(value, ",") do
		local parts = string.split(token, ":")
		local id, variant = parts[1], parts[2] or "Normal"
		if Creatures.Get(id) then
			index += 1
			local model, root = build(id, variant)
			model.Parent = folder
			-- Arrange in rows of 4 behind the player
			local row = (index - 1) // 4
			local col = (index - 1) % 4
			local offset = Vector3.new((col - 1.5) * 3.2, 1.5, 4 + row * 3.2)
			table.insert(list, { Model = model, Root = root, Offset = offset, Phase = index * 0.7 })
		end
	end
	byPlayer[player] = { Key = value, List = list }
end

local function track(player: Player)
	player:GetAttributeChangedSignal("Followers"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function Followers.Start()
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(clear)
	State.Changed:Connect(function(key)
		if key == "PotatoMode" then
			for _, player in Players:GetPlayers() do
				rebuild(player)
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local alpha = 1 - math.exp(-dt * 8)
		for player, entry in byPlayer do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			for _, f in entry.List do
				if root then
					local bob = math.sin(t * 3 + f.Phase) * 0.35
					local target = root.CFrame * CFrame.new(f.Offset + Vector3.new(0, bob, 0))
					local current = f.Root.CFrame
					if (current.Position - target.Position).Magnitude > 60 then
						current = target -- teleported / respawned
					end
					local pos = current.Position:Lerp(target.Position, alpha)
					f.Root.CFrame = CFrame.lookAt(pos, pos + root.CFrame.LookVector)
				end
			end
		end
	end)
end

return Followers
