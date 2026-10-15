--[[
	Lost Treasures: every few minutes a glowing treasure chest appears hidden in one of the realms
	players on this server have unlocked, marked by a tall beam of light. The first player to reach
	it and open it gets a burst of Essence, creature XP and a chance at a bonus Rare+ creature.
	If nobody finds it in time, it vanishes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Hatching = require(script.Parent.Hatching)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Treasures = {}

local notify = Remotes.Event("Notify")
local GOLD = Color3.fromRGB(255, 205, 70)
local rng = Random.new()
local cfg = Config.Treasure

local current: { Model: Model, Zone: number, ExpiresAt: number }? = nil

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

-- A small gold-trimmed chest with a light beam you can see from across the realm
local function buildChest(position: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "LostTreasure"
	local body = part({
		Name = "Body",
		Size = Vector3.new(3, 1.8, 2),
		Position = position + Vector3.new(0, 0.9, 0),
		Color = Color3.fromRGB(120, 72, 40),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	part({
		Name = "Lid",
		Size = Vector3.new(3.1, 0.6, 2.1),
		Position = position + Vector3.new(0, 2.1, 0),
		Color = GOLD,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	part({
		Name = "Lock",
		Size = Vector3.new(0.5, 0.6, 0.2),
		Position = position + Vector3.new(0, 1.5, -1.05),
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	part({
		Name = "Beam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(80, 1.4, 1.4),
		CFrame = CFrame.new(position + Vector3.new(0, 42, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = GOLD,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = model,
	})
	model.PrimaryPart = body

	local helpers = WorldBuilder.Helpers
	helpers.Light(body, GOLD, 18, 2)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
	sparkles.LightEmission = 1
	sparkles.Rate = 12
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(60, 60)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Parent = body
	local sign = helpers.Billboard(body, UDim2.fromOffset(220, 40), Vector3.new(0, 5, 0), 400)
	helpers.Label(sign, { Text = "✨ Lost Treasure", TextColor3 = GOLD })

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Lost Treasure"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	return model, body
end

local function remove()
	local treasure = current
	current = nil
	if treasure then
		treasure.Model:Destroy()
	end
end

-- Rewards the first player to open it
function Treasures.Claim(player: Player): boolean
	local treasure = current
	local data = PlayerData.Get(player)
	if not treasure or not data then
		return false
	end
	if treasure.Zone > data.ZonesUnlocked then
		local zone = Zones.Get(treasure.Zone)
		notify:FireClient(
			player,
			`Unlock {zone and zone.Name or "this realm"} to open it`,
			Color3.fromRGB(255, 120, 120)
		)
		return false
	end
	remove()
	local earned = Economy.AwardCrystal(player, treasure.Zone, 1, cfg.CrystalRewards)
	Economy.GrantXP(player, cfg.XP)
	local extra = ""
	if rng:NextNumber() < cfg.MysticChance and Hatching.MysticHatch(player, "Lost Treasure!") then
		extra = " + a bonus creature"
	end
	PlayerData.MarkChanged(player)
	notify:FireClient(player, `You found the Lost Treasure! +{Format.Number(earned)} Essence{extra}`, GOLD)
	local zone = Zones.Get(treasure.Zone)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			notify:FireClient(
				other,
				`{player.DisplayName} found the Lost Treasure in {zone and zone.Name or "a realm"}!`,
				GOLD
			)
		end
	end
	return true
end

-- Spawns one now (zoneIndex optional: otherwise a realm someone on the server has unlocked)
function Treasures.Spawn(zoneIndex: number?): boolean
	remove()
	local best = 0
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data then
			best = math.max(best, data.ZonesUnlocked)
		end
	end
	local zoneIdx = zoneIndex or (if best > 0 then rng:NextInteger(1, best) else 1)
	local zone = Zones.Get(zoneIdx)
	if not zone then
		return false
	end
	-- between the outer crystal columns and the decorations along the edges
	local side = if rng:NextInteger(0, 1) == 0 then -1 else 1
	local z0 = WorldBuilder.Helpers.ZoneStart(zoneIdx)
	local spread = WorldBuilder.Helpers.Spread
	local position = Vector3.new(side * rng:NextNumber(21, 27) * spread, 0, z0 + rng:NextNumber(20, 115) * spread)
	local model, body = buildChest(position)
	local world = workspace:FindFirstChild("World")
	model.Parent = world or workspace
	current = { Model = model, Zone = zoneIdx, ExpiresAt = os.time() + cfg.Lifetime }
	local prompt = body:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		Treasures.Claim(player)
	end)
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data and data.ZonesUnlocked >= zoneIdx then
			notify:FireClient(player, `✨ A Lost Treasure appeared somewhere in {zone.Name}! Follow the light`, GOLD)
		end
	end
	return true
end

function Treasures.Start()
	task.spawn(function()
		local nextAt = os.time() + rng:NextInteger(cfg.FirstDelay[1], cfg.FirstDelay[2])
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				local now = os.time()
				local treasure = current
				if treasure and now >= treasure.ExpiresAt then
					remove()
				end
				if not current and now >= nextAt and #Players:GetPlayers() > 0 then
					Treasures.Spawn()
					nextAt = now + cfg.Lifetime + rng:NextInteger(cfg.Interval[1], cfg.Interval[2])
				end
			end)
			if not ok then
				warn("[Treasures] " .. tostring(err))
			end
		end
	end)
end

return Treasures
