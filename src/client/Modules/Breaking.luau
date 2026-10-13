--[[
	Pet Simulator-style breaking feedback (client only, purely visual):
	  - a spinning ring under the crystal your creatures are attacking
	  - floating damage numbers + a squish on every hit
	  - Essence orbs that burst out of broken crystals, bounce, then fly into you
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local Breaking = {}

local player = Players.LocalPlayer
local effects = Instance.new("Folder")
effects.Name = "BreakingEffects"
effects.Parent = workspace

local GOLD = Color3.fromRGB(255, 220, 90)

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function mainPart(model: Instance): BasePart?
	if model:IsA("Model") then
		return model.PrimaryPart
	end
	return nil
end

-- Floating text that rises and fades ------------------------------------------------------
local function floatText(adornee: BasePart, text: string, color: Color3, size: number, offset: Vector3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 6, size * 1.6)
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	gui.Parent = player:FindFirstChildOfClass("PlayerGui") or effects
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService
		:Create(
			gui,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad),
			{ StudsOffsetWorldSpace = offset + Vector3.new(0, 3, 0) }
		)
		:Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.4),
		{ TextTransparency = 1 }
	):Play()
	TweenService:Create(
		stroke,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.4),
		{ Transparency = 1 }
	):Play()
	task.delay(1, function()
		gui:Destroy()
	end)
end

-- Squish the crystal model on hit -------------------------------------------------------
local squishing: { [Model]: boolean } = {}
local function squish(model: Model)
	if squishing[model] or State.PotatoMode then
		return
	end
	local ok, scale = pcall(function()
		return model:GetScale()
	end)
	if not ok then
		return
	end
	squishing[model] = true
	local value = Instance.new("NumberValue")
	value.Value = scale
	value.Changed:Connect(function(v)
		pcall(model.ScaleTo, model, v)
	end)
	local up = TweenService:Create(value, TweenInfo.new(0.05), { Value = scale * 1.08 })
	local down = TweenService:Create(value, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Value = scale })
	up.Completed:Connect(function()
		down:Play()
	end)
	down.Completed:Connect(function()
		value:Destroy()
		squishing[model] = nil
	end)
	up:Play()
end

-- Target ring ------------------------------------------------------------------------------
local ring: BasePart? = nil
local ringTarget: Model? = nil

local function makeRing(): BasePart
	local p = Instance.new("Part")
	p.Name = "TargetRing"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Transparency = 0.35
	p.Size = Vector3.new(0.15, 8, 8)
	p.Parent = effects
	local inner = p:Clone()
	inner.Name = "Inner"
	inner.Size = Vector3.new(0.18, 7, 7)
	inner.Color = Color3.fromRGB(40, 30, 60)
	inner.Transparency = 0.2
	inner.Material = Enum.Material.SmoothPlastic
	inner.Parent = p
	return p
end

local function watchTarget()
	local value = player:WaitForChild("PetTarget") :: ObjectValue
	local function update()
		local target = value.Value
		ringTarget = if target and target:IsA("Model") then target else nil
		if ringTarget and not ring then
			ring = makeRing()
		elseif not ringTarget and ring then
			ring:Destroy()
			ring = nil
		end
		if ring and ringTarget then
			local _, size = ringTarget:GetBoundingBox()
			local d = math.max(size.X, size.Z) + 2
			ring.Size = Vector3.new(0.15, d, d)
			local inner = ring:FindFirstChild("Inner") :: BasePart?
			if inner then
				inner.Size = Vector3.new(0.18, d - 1, d - 1)
			end
		end
	end
	value.Changed:Connect(update)
	update()
end

-- Essence orbs ---------------------------------------------------------------------------------
type Orb = { Part: BasePart, Velocity: Vector3, Age: number, Delay: number, Speed: number, Done: boolean }
local orbs: { Orb } = {}
local pending: { { Remaining: number, Earned: number } } = {}

local function spawnOrbs(model: Model, earned: number, count: number)
	local main = mainPart(model)
	if not main then
		return
	end
	local color = main.Color
	local origin = main.Position + Vector3.new(0, 1.5, 0)
	local batch = { Remaining = count, Earned = earned }
	table.insert(pending, batch)
	for i = 1, count do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * (if count > 10 then 0.9 else 1.1)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = if i % 3 == 0 then GOLD else color
		p.Position = origin
		p.Parent = effects
		local light = Instance.new("PointLight")
		light.Color = p.Color
		light.Range = 5
		light.Brightness = 1
		light.Parent = p
		local angle = math.random() * math.pi * 2
		local out = math.random(8, 16)
		table.insert(
			orbs,
			{
				Part = p,
				Velocity = Vector3.new(math.cos(angle) * out, math.random(18, 28), math.sin(angle) * out),
				Age = 0,
				Delay = 0.45 + math.random() * 0.35,
				Speed = 25,
				Done = false,
				Batch = batch,
			} :: any
		)
	end
end

local function collect(orb: any)
	orb.Done = true
	orb.Part:Destroy()
	local batch = orb.Batch
	batch.Collected = (batch.Collected or 0) + 1
	-- Each orb in a burst pings a little higher, like Pet Sim's coin pickups
	Sound.Play("Orb", 1 + math.min(batch.Collected, 16) * 0.06, 1, 0.03)
	batch.Remaining -= 1
	if batch.Remaining == 0 then
		local r = root()
		if r then
			floatText(r, "+" .. Format.Number(batch.Earned), Color3.fromRGB(140, 255, 200), 7, Vector3.new(0, 3.5, 0))
		end
		local i = table.find(pending, batch)
		if i then
			table.remove(pending, i)
		end
	end
end

local function stepOrbs(dt: number)
	local r = root()
	for i = #orbs, 1, -1 do
		local orb = orbs[i] :: any
		if orb.Done then
			table.remove(orbs, i)
			continue
		end
		orb.Age += dt
		local pos = orb.Part.Position
		if orb.Age < orb.Delay or not r then
			-- Burst out with gravity, bounce on the ground
			orb.Velocity += Vector3.new(0, -70 * dt, 0)
			pos += orb.Velocity * dt
			if pos.Y < 0.6 then
				pos = Vector3.new(pos.X, 0.6, pos.Z)
				orb.Velocity = Vector3.new(orb.Velocity.X * 0.5, math.abs(orb.Velocity.Y) * 0.45, orb.Velocity.Z * 0.5)
			end
			orb.Part.Position = pos
			if orb.Age > 4 then
				collect(orb)
			end
		else
			-- Magnet: accelerate into the player
			orb.Speed = math.min(orb.Speed + 120 * dt, 140)
			local target = (r :: BasePart).Position
			local delta = target - pos
			local dist = delta.Magnitude
			if dist < 1.5 then
				collect(orb)
			else
				orb.Part.Position = pos + delta.Unit * math.min(dist, orb.Speed * dt)
			end
		end
	end
end

function Breaking.Start()
	task.spawn(watchTarget)

	Remotes.Event("CrystalHit").OnClientEvent:Connect(function(model, dealt)
		if typeof(model) ~= "Instance" or not model:IsA("Model") then
			return
		end
		local main = mainPart(model)
		if not main then
			return
		end
		squish(model)
		Sound.Play("Hit", Sound.Pitch("Hit", 1.3 + math.random() * 0.5), 1, 0.07)
		if not State.PotatoMode then
			local jitter = Vector3.new(math.random(-15, 15) / 10, 3 + math.random() * 1.5, math.random(-15, 15) / 10)
			floatText(main, Format.Number(dealt), Color3.new(1, 1, 1), 5, jitter)
		end
	end)

	Remotes.Event("CrystalBroken").OnClientEvent:Connect(function(model, earned, count)
		if typeof(model) ~= "Instance" or not model:IsA("Model") then
			return
		end
		local chest = model:GetAttribute("Breakable") == "Chest"
		local key = if chest then "ChestBreak" else "Break"
		Sound.Play(key, Sound.Pitch(key, if chest then 0.65 else 0.95 + math.random() * 0.15))
		spawnOrbs(model, earned, if State.PotatoMode then math.min(count, 3) else count)
	end)

	RunService.RenderStepped:Connect(function(dt)
		stepOrbs(dt)
		if ring and ringTarget then
			local center = ringTarget:GetPivot().Position
			local _, size = ringTarget:GetBoundingBox()
			local y = center.Y - size.Y / 2 + 0.15
			ring.CFrame = CFrame.new(center.X, math.max(y, 0.12), center.Z)
				* CFrame.Angles(0, os.clock() * 1.5, 0)
				* CFrame.Angles(0, 0, math.pi / 2)
			local inner = ring:FindFirstChild("Inner") :: BasePart?
			if inner then
				inner.CFrame = ring.CFrame * CFrame.new(0.02, 0, 0)
			end
		end
	end)
end

return Breaking
