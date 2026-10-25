--[[
	The calm look of the world, all client side:
	- soft pastel lighting (bloom, haze, colour grading, sun rays, gentle depth of field)
	  that eases into each garden's mood and time of day as you walk in
	- drifting petals around the camera, fireflies at dusk and night
	- swaying leaves and flowers, bobbing lily pads, flickering lanterns, glimmering
	  crystals and slowly drifting clouds
	- garden gates that dissolve once you have unlocked them
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.BloomShared.Config)
local Util = require(ReplicatedStorage.BloomShared.Util)
local Sfx = require(script.Parent.Sfx)
local Effects = require(script.Parent.Effects)

local Atmosphere = {}

local player = Players.LocalPlayer
local zoneListeners = {}
local currentZone = 0

function Atmosphere.OnZone(fn)
	table.insert(zoneListeners, fn)
	if currentZone > 0 then
		task.spawn(fn, currentZone)
	end
end

function Atmosphere.Zone(): number
	return math.max(currentZone, 1)
end

-- Lighting -----------------------------------------------------------------------------

local function ensure(className: string, name: string, parent: Instance)
	local inst = parent:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return inst
end

Lighting.Brightness = 2.2
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.4
Lighting.ShadowSoftness = 0.45
Lighting.Ambient = Color3.fromRGB(150, 140, 160)
Lighting.OutdoorAmbient = Color3.fromRGB(170, 166, 182)
Lighting.GeographicLatitude = 30

local atmosphere = ensure("Atmosphere", "BloomAtmosphere", Lighting)
atmosphere.Density = 0.32
atmosphere.Offset = 0.2
atmosphere.Glare = 0.4
atmosphere.Haze = 1.6

local bloom = ensure("BloomEffect", "BloomGlow", Lighting)
bloom.Intensity = 0.7
bloom.Size = 30
bloom.Threshold = 1.6

local grade = ensure("ColorCorrectionEffect", "BloomGrade", Lighting)
grade.Brightness = 0.03
grade.Contrast = 0.05
grade.Saturation = -0.06

local rays = ensure("SunRaysEffect", "BloomRays", Lighting)
rays.Intensity = 0.06
rays.Spread = 0.8

local dof = ensure("DepthOfFieldEffect", "BloomFocus", Lighting)
dof.FarIntensity = 0.12
dof.FocusDistance = 40
dof.InFocusRadius = 70
dof.NearIntensity = 0

local function applyZone(zone: number)
	local info = Config.Zones[zone]
	local ti = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(Lighting, ti, { ClockTime = info.ClockTime }):Play()
	TweenService:Create(grade, ti, { TintColor = info.Tint }):Play()
	TweenService:Create(atmosphere, ti, { Color = info.Haze, Decay = info.Haze:Lerp(Color3.new(1, 1, 1), 0.3) }):Play()
	local night = info.ClockTime >= 19
	TweenService:Create(Lighting, ti, {
		OutdoorAmbient = if night then Color3.fromRGB(120, 128, 170) else Color3.fromRGB(170, 166, 182),
		Brightness = if night then 1.4 else 2.2,
	}):Play()
	TweenService:Create(bloom, ti, { Intensity = if night then 1.1 else 0.7 }):Play()
end

-- Ambient particles around the camera ---------------------------------------------------

local ambient = Instance.new("Part")
ambient.Name = "BloomAmbient"
ambient.Anchored = true
ambient.CanCollide = false
ambient.CanQuery = false
ambient.CanTouch = false
ambient.Transparency = 1
ambient.Size = Vector3.new(80, 30, 80)
ambient.Parent = Workspace

local petals = Instance.new("ParticleEmitter")
petals.Name = "DriftPetals"
petals.Texture = "rbxasset://textures/particles/sparkles_main.dds"
petals.Shape = Enum.ParticleEmitterShape.Box
petals.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
petals.Rate = 10
petals.Lifetime = NumberRange.new(6, 9)
petals.Speed = NumberRange.new(0.5, 1.5)
petals.Acceleration = Vector3.new(1.2, -0.6, 0.4)
petals.Size = NumberSequence.new(0.22)
petals.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, 0.2),
	NumberSequenceKeypoint.new(0.85, 0.2),
	NumberSequenceKeypoint.new(1, 1),
})
petals.RotSpeed = NumberRange.new(-90, 90)
petals.LightEmission = 0.3
petals.Parent = ambient

local fireflies = Instance.new("ParticleEmitter")
fireflies.Name = "Fireflies"
fireflies.Texture = "rbxasset://textures/particles/sparkles_main.dds"
fireflies.Shape = Enum.ParticleEmitterShape.Box
fireflies.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
fireflies.Rate = 0
fireflies.Lifetime = NumberRange.new(3, 6)
fireflies.Speed = NumberRange.new(0.2, 0.8)
fireflies.SpreadAngle = Vector2.new(180, 180)
fireflies.Color = ColorSequence.new(Color3.fromRGB(236, 255, 196), Color3.fromRGB(255, 236, 170))
fireflies.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.3, 0.3),
	NumberSequenceKeypoint.new(0.7, 0.2),
	NumberSequenceKeypoint.new(1, 0),
})
fireflies.LightEmission = 1
fireflies.Parent = ambient

local function zoneParticles(zone: number)
	local info = Config.Zones[zone]
	petals.Color = ColorSequence.new(info.Flower[1], info.Flower[2])
	petals.Rate = if zone == 4 then 4 else 10
	fireflies.Rate = if zone == 4 then 18 elseif zone == 3 then 8 else 0
end

-- Animated scenery ---------------------------------------------------------------------

local function tracked(tag: string)
	local set = {}
	local function add(inst)
		if inst:IsA("BasePart") then
			set[inst] = { Base = inst.CFrame, Phase = math.random() * 6.28, Base2 = (inst :: any).Transparency }
		end
	end
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		set[inst] = nil
	end)
	return set
end

local sway = tracked("Sway")
local floats = tracked("Float")
local clouds = tracked("Cloud")
local glimmers = tracked("Glimmer")
local lanterns = tracked("Lantern")

local SWAY_RANGE = 110
local parts, cframes = {}, {}
local acc = 0
local cloudOffset = 0
local WORLD_SPAN = 700

RunService.RenderStepped:Connect(function(dt)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	ambient.CFrame = CFrame.new(camPos + cam.CFrame.LookVector * 20 + Vector3.new(0, 4, 0))

	acc += dt
	if acc < 1 / 30 then
		return
	end
	local step = acc
	acc = 0
	local t = os.clock()
	table.clear(parts)
	table.clear(cframes)

	for p, info in sway do
		local pos = info.Base.Position
		if (pos - camPos).Magnitude < SWAY_RANGE then
			local a = math.sin(t * 1.3 + info.Phase + pos.X * 0.05) * 0.05
			local b = math.cos(t * 1.1 + info.Phase) * 0.035
			table.insert(parts, p)
			table.insert(cframes, info.Base * CFrame.Angles(a, 0, b))
		end
	end
	for p, info in floats do
		table.insert(parts, p)
		table.insert(cframes, info.Base + Vector3.new(0, math.sin(t * 1.5 + info.Phase) * 0.12, 0))
	end
	cloudOffset += step * 1.6
	for p, info in clouds do
		local x = info.Base.X + cloudOffset
		x = ((x + WORLD_SPAN / 2) % WORLD_SPAN) - WORLD_SPAN / 2
		local cf = info.Base
		table.insert(parts, p)
		table.insert(cframes, CFrame.new(x, cf.Y + math.sin(t * 0.3 + info.Phase), cf.Z) * cf.Rotation)
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	for p, info in glimmers do
		p.Transparency = math.clamp(info.Base2 + math.sin(t * 2 + info.Phase) * 0.12 + 0.05, 0, 0.9)
	end
	for p, info in lanterns do
		local light = p:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 1.1 + math.sin(t * 3 + info.Phase) * 0.15 + math.sin(t * 7.3 + info.Phase) * 0.08
		end
	end
end)

-- Gates --------------------------------------------------------------------------------

local openGates = {}
local function refreshGate(gate: BasePart)
	local zone = gate:GetAttribute("Zone") or 99
	local unlocked = (player:GetAttribute("Zones") or 1) >= zone
	local label = gate:FindFirstChild("Label")
	local info = Config.Zones[zone]
	if unlocked then
		gate.CanCollide = false
		if not openGates[gate] then
			openGates[gate] = true
			TweenService:Create(gate, TweenInfo.new(1.5), { Transparency = 1 }):Play()
			if label and label:FindFirstChild("Subtitle") and info then
				label.Subtitle.Text = "Open  ·  x" .. info.Multiplier .. " Bloom"
			end
			if (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) and currentZone > 0 then
				local root = player.Character.HumanoidRootPart
				if (root.Position - gate.Position).Magnitude < 200 then
					Effects.Shards(gate.Position, { gate.Color, Color3.new(1, 1, 1) }, 24, 1.4)
					Effects.Ring(gate.Position, gate.Color, 40, 1.4)
				end
			end
		end
	else
		gate.CanCollide = true
		if label and label:FindFirstChild("Subtitle") and info then
			label.Subtitle.Text = "Needs " .. Util.Format(info.Need) .. " Bloom  ·  x" .. info.Multiplier .. " Bloom"
		end
	end
end

local function refreshGates()
	for _, gate in CollectionService:GetTagged("Gate") do
		refreshGate(gate)
	end
end
CollectionService:GetInstanceAddedSignal("Gate"):Connect(refreshGate)
player:GetAttributeChangedSignal("Zones"):Connect(function()
	refreshGates()
	Sfx.Melody("Gate")
end)

-- Zone tracking ------------------------------------------------------------------------

task.spawn(function()
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local zone = Util.ZoneAt(root.Position.Z)
			if zone ~= currentZone then
				currentZone = zone
				applyZone(zone)
				zoneParticles(zone)
				for _, fn in zoneListeners do
					task.spawn(fn, zone)
				end
			end
		end
		task.wait(0.5)
	end
end)

refreshGates()

return Atmosphere
