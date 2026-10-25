--[[
	Client-side effects: petal bursts, block shards, glowing rings, floating "+N" pops,
	soft screen flashes, camera shake and FOV punches. Everything cleans itself up.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ui = require(script.Parent.Ui)

local Effects = {}

local player = Players.LocalPlayer
local fxFolder = Instance.new("Folder")
fxFolder.Name = "BloomFx"
fxFolder.Parent = Workspace

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local screen: ScreenGui? = nil
function Effects.SetScreen(gui: ScreenGui)
	screen = gui
end

local function tween(inst: Instance, time: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
Effects.Tween = tween

local function anchorAt(pos: Vector3, life: number): (Part, Attachment)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = fxFolder
	local att = Instance.new("Attachment")
	att.Parent = p
	task.delay(life, function()
		p:Destroy()
	end)
	return p, att
end

local function emitter(att: Attachment, props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = SPARKLE
	e.LightEmission = 0.6
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = att
	return e
end

-- A flat ring that grows and fades
function Effects.Ring(pos: Vector3, color: Color3, size: number?, time: number?)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = fxFolder
	local s = size or 18
	tween(ring, time or 0.9, { Size = Vector3.new(0.05, s, s), Transparency = 1 })
	task.delay((time or 0.9) + 0.1, function()
		ring:Destroy()
	end)
end

-- Little low-poly cubes that fly out, spin and shrink
function Effects.Shards(pos: Vector3, colors: { Color3 }, count: number?, power: number?)
	local n = count or 14
	local pw = power or 1
	for i = 1, n do
		local s = math.random(30, 80) / 100 * pw
		local b = Instance.new("Part")
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CastShadow = false
		b.Material = if i % 3 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		b.Color = colors[(i % #colors) + 1]
		b.Size = Vector3.new(s, s, s)
		b.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		b.Parent = fxFolder
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.4, math.random() - 0.5).Unit
		local dist = math.random(6, 14) * pw
		local up = CFrame.new(pos + dir * dist) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		local t = math.random(60, 110) / 100
		tween(b, t, { CFrame = up }, Enum.EasingStyle.Quint)
		task.delay(t * 0.55, function()
			tween(b, t * 0.8, { Size = Vector3.zero, Transparency = 1, CFrame = up - Vector3.new(0, 3 * pw, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		task.delay(t * 1.5, function()
			b:Destroy()
		end)
	end
end

-- Sparkles + soft petals bursting from a point
function Effects.Burst(pos: Vector3, color: Color3, size: number?)
	local sz = size or 1
	local _, att = anchorAt(pos, 4)
	emitter(att, {
		Color = ColorSequence.new(color, Color3.new(1, 1, 1)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * sz), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(10 * sz, 22 * sz),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Acceleration = Vector3.new(0, -4, 0),
		RotSpeed = NumberRange.new(-200, 200),
		LightEmission = 1,
	}):Emit(math.floor(40 * sz))
	emitter(att, {
		Texture = SMOKE,
		Color = ColorSequence.new(color),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2 * sz), NumberSequenceKeypoint.new(1, 6 * sz) }),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.3,
	}):Emit(10)
end

function Effects.Confetti(pos: Vector3, colors: { Color3 })
	local _, att = anchorAt(pos + Vector3.new(0, 4, 0), 5)
	local seq = {}
	for i, c in colors do
		table.insert(seq, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), c))
	end
	emitter(att, {
		Color = ColorSequence.new(seq),
		Size = NumberSequence.new(0.35),
		Lifetime = NumberRange.new(2.5, 3.5),
		Speed = NumberRange.new(18, 30),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -14, 0),
		Drag = 1.5,
		RotSpeed = NumberRange.new(-300, 300),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 0.2,
	}):Emit(70)
end

-- Floating "+N" above a character
function Effects.Pop(adornee: BasePart, text: string, color: Color3, small: boolean?)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = if small then UDim2.fromOffset(90, 30) else UDim2.fromOffset(140, 46)
	local startOffset = Vector3.new((math.random() - 0.5) * 3, adornee.Size.Y * 1.6 + 2, 0)
	gui.StudsOffsetWorldSpace = startOffset
	local label = Ui.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		Parent = gui,
	}, { Ui.textStroke(nil, 2.5) })
	gui.Parent = player:FindFirstChildOfClass("PlayerGui") or fxFolder
	local scale = Ui.new("UIScale", { Scale = 0.4, Parent = label })
	tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(gui, 1.1, { StudsOffsetWorldSpace = startOffset + Vector3.new(0, 3.5, 0) }, Enum.EasingStyle.Sine)
	task.delay(0.6, function()
		tween(label, 0.5, { TextTransparency = 1 })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, 0.5, { Transparency = 1 })
		end
	end)
	task.delay(1.2, function()
		gui:Destroy()
	end)
end

-- Soft full-screen flash
function Effects.Flash(color: Color3, strength: number?)
	if not screen then
		return
	end
	local f = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - (strength or 0.35),
		ZIndex = 50,
		Parent = screen,
	})
	tween(f, 0.6, { BackgroundTransparency = 1 })
	task.delay(0.7, function()
		f:Destroy()
	end)
end

-- Camera shake via Humanoid.CameraOffset (plays nicely with the default camera)
local shakeUntil, shakePower = 0, 0
function Effects.Shake(power: number, time: number)
	shakePower = math.max(shakePower, power)
	shakeUntil = math.max(shakeUntil, os.clock() + time)
end

local fovBase = 70
function Effects.Punch(amount: number?)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	cam.FieldOfView = fovBase + (amount or 4)
	tween(cam, 0.35, { FieldOfView = fovBase }, Enum.EasingStyle.Quad)
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if os.clock() < shakeUntil then
		local p = shakePower
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * p, (math.random() - 0.5) * p, 0)
	elseif shakePower > 0 then
		shakePower = 0
		humanoid.CameraOffset = Vector3.zero
	end
end)

return Effects
