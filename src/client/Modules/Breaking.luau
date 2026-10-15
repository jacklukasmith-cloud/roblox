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
local Followers = require(script.Parent.Followers)

local Breaking = {}

local Config = require(ReplicatedStorage.Shared.Config)

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

-- Small camera kick for crits (skipped in Potato Mode)
local function cameraKick(strength: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or State.PotatoMode then
		return
	end
	task.spawn(function()
		for i = 1, 6 do
			local k = strength * (1 - i / 7)
			humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
			task.wait(1 / 60)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- Combo meter (right side of the screen) -----------------------------------------------
local comboGui: ScreenGui? = nil
local comboLabel: TextLabel? = nil
local comboSub: TextLabel? = nil
local comboFill: Frame? = nil
local comboScale: UIScale? = nil
local comboEndsAt = 0
local comboWindow = 1

local function buildComboMeter()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ComboMeter"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.2)
	frame.Size = UDim2.fromOffset(170, 74)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 40)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Text = ""
	label.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Parent = label
	local sub = label:Clone()
	sub.Position = UDim2.fromOffset(0, 40)
	sub.Size = UDim2.new(1, 0, 0, 18)
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.Parent = frame
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.new(0.5, 0, 0, 62)
	back.Size = UDim2.new(0.8, 0, 0, 6)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Parent = frame
	Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = GOLD
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	comboGui, comboLabel, comboSub, comboFill, comboScale = gui, label, sub, fill, scale
end

local function showCombo(count: number, window: number)
	if not comboGui then
		buildComboMeter()
	end
	comboEndsAt = os.clock() + window
	comboWindow = window
	if count < 2 then
		return -- a single break isn't a combo yet
	end
	local bonus = math.round((count - 1) * Config.Combo.Step * 100)
	local heat = math.clamp((count - 2) / (Config.Combo.Max - 2), 0, 1)
	local color = GOLD:Lerp(Color3.fromRGB(255, 80, 60), heat)
	local gui, label, sub, fill, scale =
		comboGui :: ScreenGui, comboLabel :: TextLabel, comboSub :: TextLabel, comboFill :: Frame, comboScale :: UIScale
	gui.Enabled = true
	label.Text = if count >= Config.Combo.Max then `MAX COMBO x{count}!` else `COMBO x{count}`
	label.TextColor3 = color
	sub.Text = `+{bonus}% Essence`
	fill.BackgroundColor3 = color
	scale.Scale = 1.35
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- a rising chime every 5 combo steps
	if count % 5 == 0 then
		Sound.Play("Click", 1 + count / 20, 1)
	end
end

local function stepCombo()
	if not comboGui or not comboGui.Enabled then
		return
	end
	local left = comboEndsAt - os.clock()
	if left <= 0 then
		comboGui.Enabled = false
		return
	end
	(comboFill :: Frame).Size = UDim2.fromScale(math.clamp(left / comboWindow, 0, 1), 1)
end

-- Creature abilities: the ability's name pops up over the creature that used it, with a flash
-- on whatever it hit
local ABILITY_FX = {
	FireBurst = { Text = "🔥 Fire Burst!", Color = Color3.fromRGB(255, 130, 50) },
	SpiritFlame = { Text = "🌌 Spirit Flame!", Color = Color3.fromRGB(150, 195, 255) },
	FrostShatter = { Text = "❄️ Shatter!", Color = Color3.fromRGB(170, 225, 255) },
	StormStrike = { Text = "⚡ Storm Strike!", Color = Color3.fromRGB(255, 240, 120) },
	LuckyFind = { Text = "🍀 Lucky! x2", Color = Color3.fromRGB(120, 255, 140) },
}

local function abilityFlash(target: BasePart, color: Color3)
	if State.PotatoMode then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 6
	light.Parent = target
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	task.delay(0.6, function()
		light:Destroy()
	end)
	local burst = target:FindFirstChild("Burst") :: ParticleEmitter?
	if burst then
		burst:Emit(12)
	end
end

local function onAbility(id: any, kind: any, model: any)
	local fx = ABILITY_FX[kind]
	if not fx then
		return
	end
	local target = if typeof(model) == "Instance" and model:IsA("Model") then model.PrimaryPart else nil
	local rig = if type(id) == "string" then Followers.ModelFor(player, id) else nil
	local anchor = (rig and rig.PrimaryPart) or target
	if anchor then
		floatText(anchor, fx.Text, fx.Color, 7, Vector3.new(0, 3, 0))
	end
	if target and kind ~= "LuckyFind" then
		abilityFlash(target, fx.Color)
	end
	Sound.Play("Chime", if kind == "LuckyFind" then 1.7 else 1.1, 0.45, 0.15)
end

function Breaking.Start()
	Remotes.Event("PetAbility").OnClientEvent:Connect(onAbility)
	task.spawn(watchTarget)

	Remotes.Event("CrystalHit").OnClientEvent:Connect(function(model, dealt, crit)
		if typeof(model) ~= "Instance" or not model:IsA("Model") then
			return
		end
		local main = mainPart(model)
		if not main then
			return
		end
		squish(model)
		if crit then
			-- big gold number, deeper hit sound and a small camera kick
			Sound.Play("Hit", Sound.Pitch("Hit", 0.9), 1.3)
			local jitter = Vector3.new(math.random(-10, 10) / 10, 4.5, math.random(-10, 10) / 10)
			floatText(main, `CRIT! {Format.Number(dealt)}`, GOLD, 9, jitter)
			cameraKick(0.35)
		else
			Sound.Play("Hit", Sound.Pitch("Hit", 1.3 + math.random() * 0.5), 1, 0.07)
			if not State.PotatoMode then
				local jitter =
					Vector3.new(math.random(-15, 15) / 10, 3 + math.random() * 1.5, math.random(-15, 15) / 10)
				floatText(main, Format.Number(dealt), Color3.new(1, 1, 1), 5, jitter)
			end
		end
	end)

	Remotes.Event("CrystalBroken").OnClientEvent:Connect(function(model, earned, count, combo, window)
		if type(combo) == "number" and type(window) == "number" then
			showCombo(combo, window)
		end
		if typeof(model) ~= "Instance" or not model:IsA("Model") then
			return
		end
		local chest = model:GetAttribute("Breakable") == "Chest"
		local key = if chest then "ChestBreak" else "Break"
		Sound.Play(key, Sound.Pitch(key, if chest then 0.65 else 0.95 + math.random() * 0.15))
		if model:GetAttribute("Golden") and model.PrimaryPart then
			floatText(model.PrimaryPart, "GOLDEN!", Color3.fromRGB(255, 215, 80), 10, Vector3.new(0, 7, 0))
			Sound.Play("Chime", 1.4, 0.7)
		end
		spawnOrbs(model, earned, if State.PotatoMode then math.min(count, 3) else count)
	end)

	RunService.RenderStepped:Connect(function(dt)
		stepOrbs(dt)
		stepCombo()
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
