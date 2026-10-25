--[[
	Bloom Battle screen: countdown, tug-of-war bar, timer, a big TAP button (click,
	tap, Space or gamepad A also work), combo counter and a side-on battle camera
	that always puts you on the left.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.BloomShared.Config)
local Util = require(ReplicatedStorage.BloomShared.Util)
local Net = require(ReplicatedStorage.BloomShared.Net)
local Ui = require(script.Parent.Ui)
local Sfx = require(script.Parent.Sfx)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)

local DuelUi = {}

local player = Players.LocalPlayer
local C = Ui.Colors
local tween = Effects.Tween
local gui = Hud.Gui
local duelEvent = Net.Event("Duel")
local tapEvent = Net.Event("DuelTap")

local ME = Color3.fromRGB(244, 182, 198)
local THEM = Color3.fromRGB(172, 208, 240)

local state = {
	active = false,
	fighting = false,
	you = "A",
	p = 0,
	shown = 0,
	arena = nil,
	timeLeft = 0,
	combo = 0,
	lastTap = 0,
	tapTimes = {},
}

-- Widgets ------------------------------------------------------------------------------

local waiting = Ui.new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.fromOffset(520, 40),
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	Visible = false,
	Parent = gui,
}, { Ui.textStroke(nil, 2.5) })

local panel = Ui.card({
	Name = "DuelPanel",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 124),
	Size = UDim2.fromOffset(560, 96),
	Visible = false,
	Parent = gui,
})
local youName = Ui.new("TextLabel", {
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(0.42, 0, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(214, 130, 156),
	Parent = panel,
})
local themName = Ui.new("TextLabel", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 8),
	Size = UDim2.new(0.42, 0, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(110, 156, 206),
	Parent = panel,
})
local timer = Ui.new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(70, 30),
	Text = "12",
	Parent = panel,
})
local bar = Ui.new("Frame", {
	Position = UDim2.new(0, 16, 0, 44),
	Size = UDim2.new(1, -32, 0, 28),
	BackgroundColor3 = THEM,
	ClipsDescendants = true,
	Parent = panel,
}, { Ui.corner(14), Ui.gradient(Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 235), 90) })
local fill = Ui.new("Frame", {
	Size = UDim2.fromScale(0.5, 1),
	BackgroundColor3 = ME,
	Parent = bar,
}, { Ui.gradient(Color3.new(1, 1, 1), Color3.fromRGB(235, 220, 225), 90) })
local knob = Ui.new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(40, 40),
	Text = "✿",
	TextColor3 = Color3.fromRGB(255, 226, 160),
	ZIndex = 3,
	Parent = bar,
}, { Ui.textStroke(nil, 2) })
local strengthHint = Ui.new("TextLabel", {
	Position = UDim2.new(0, 16, 1, -22),
	Size = UDim2.new(1, -32, 0, 18),
	TextColor3 = C.Soft,
	Text = "",
	Parent = panel,
})

local countdown = Ui.new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(400, 160),
	TextColor3 = Color3.fromRGB(255, 236, 196),
	Text = "",
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, { Ui.textStroke(nil, 4) })
local countdownScale = Ui.new("UIScale", { Parent = countdown })

local tapButton = Ui.new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(170, 170),
	BackgroundTransparency = 0,
	BackgroundColor3 = ME,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
	Parent = gui,
}, { Ui.corner(85), Ui.stroke(Color3.new(1, 1, 1), 4), Ui.gradient(Color3.new(1, 1, 1), Color3.fromRGB(240, 200, 214), 90) })
Ui.new("TextLabel", {
	Size = UDim2.fromScale(1, 0.5),
	Position = UDim2.fromScale(0, 0.18),
	Text = "TAP!",
	TextColor3 = Color3.new(1, 1, 1),
	Parent = tapButton,
}, { Ui.textStroke(Color3.fromRGB(200, 120, 150), 3) })
Ui.new("TextLabel", {
	Size = UDim2.fromScale(0.8, 0.14),
	Position = UDim2.fromScale(0.1, 0.66),
	Text = if UserInputService.TouchEnabled then "tap anywhere" else "click / space",
	TextColor3 = Color3.fromRGB(150, 90, 112),
	Parent = tapButton,
})
local tapScale = Ui.new("UIScale", { Parent = tapButton })
local comboLabel = Ui.new("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0.5, 96, 1, -130),
	Size = UDim2.fromOffset(140, 50),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 226, 160),
	Rotation = -8,
	Parent = gui,
}, { Ui.textStroke(nil, 3) })
local comboScale = Ui.new("UIScale", { Parent = comboLabel })

-- Camera -------------------------------------------------------------------------------

local function arenaInfo()
	local arena = state.arena
	local a = arena and arena:FindFirstChild("PadA")
	local b = arena and arena:FindFirstChild("PadB")
	if not (a and b) then
		return nil
	end
	return (a.Position + b.Position) / 2, a, b
end

local function battleCamera()
	local cam = Workspace.CurrentCamera
	local center = arenaInfo()
	if not (cam and center) then
		return
	end
	-- Camera on +Z looking -Z puts pad A (-X) on the left; flip for side B.
	local side = if state.you == "A" then 1 else -1
	local dist = 38 + Util.ScaleFor(math.max(state.aBloom or 0, state.bBloom or 0)) * 6
	local eye = center + Vector3.new(0, 12, side * dist)
	cam.CameraType = Enum.CameraType.Scriptable
	tween(cam, 1, { CFrame = CFrame.lookAt(eye, center + Vector3.new(0, 4, 0)) }, Enum.EasingStyle.Sine)
end

local function restoreCamera()
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
end

-- Tapping ------------------------------------------------------------------------------

local function ripple(pos: Vector2?)
	local at = pos or (tapButton.AbsolutePosition + tapButton.AbsoluteSize / 2)
	-- Input positions and AbsolutePosition are both relative to the HUD's origin.
	local r = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.3,
		ZIndex = 30,
		Parent = gui,
	}, { Ui.corner(200) })
	-- The HUD UIScale would scale the ripple too; undo it so it lands under the finger.
	local s = gui:FindFirstChildOfClass("UIScale")
	if s and s.Scale > 0 then
		r.Position = UDim2.fromOffset(r.Position.X.Offset / s.Scale, r.Position.Y.Offset / s.Scale)
	end
	tween(r, 0.35, { Size = UDim2.fromOffset(90, 90), BackgroundTransparency = 1 })
	task.delay(0.4, function()
		r:Destroy()
	end)
end

local function doTap(pos: Vector2?)
	if not state.fighting then
		return
	end
	local now = os.clock()
	while state.tapTimes[1] and now - state.tapTimes[1] > 1 do
		table.remove(state.tapTimes, 1)
	end
	if #state.tapTimes >= Config.Duel.MaxTapsPerSecond then
		return
	end
	table.insert(state.tapTimes, now)
	tapEvent:FireServer()

	state.combo = if now - state.lastTap < 0.45 then state.combo + 1 else 1
	state.lastTap = now
	if state.combo >= 5 then
		comboLabel.Text = "x" .. state.combo
		comboScale.Scale = 1.35
		tween(comboScale, 0.2, { Scale = 1 })
	end

	tapScale.Scale = 0.9
	tween(tapScale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	ripple(pos)
	Sfx.Play("Tap", 0.9 + math.random() * 0.3 + math.min(state.combo, 30) * 0.01)
	Effects.Punch(1.2)

	local arena = state.arena
	local marker = arena and arena:FindFirstChild("Marker")
	if marker and state.combo % 2 == 0 then
		Effects.Burst(marker.Position, ME, 0.3)
	end
	if state.combo % 10 == 0 and marker then
		Effects.Ring(marker.Position, ME, 10, 0.5)
		Effects.Shake(0.25, 0.15)
	end
end

tapButton.Activated:Connect(function()
	doTap(nil)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not state.fighting then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
		doTap(Vector2.new(input.Position.X, input.Position.Y))
	elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.ButtonR2 then
		doTap(nil)
	end
end)

-- Flow ---------------------------------------------------------------------------------

local function hide()
	state.active = false
	state.fighting = false
	panel.Visible = false
	tapButton.Visible = false
	countdown.Visible = false
	comboLabel.Text = ""
	waiting.Visible = false
end

local function showCount(text: string, color: Color3?)
	countdown.Visible = true
	countdown.Text = text
	countdown.TextColor3 = color or Color3.fromRGB(255, 236, 196)
	countdownScale.Scale = 1.8
	countdown.TextTransparency = 0
	tween(countdownScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	Sfx.Play("Burst", if text == "BLOOM!" then 1.2 else 0.8, 0.8)
end

local waitToken = 0
local handlers = {}

function handlers.Waiting(msg)
	waitToken += 1
	local token = waitToken
	waiting.Visible = true
	task.spawn(function()
		for i = msg.Wait, 1, -1 do
			if waitToken ~= token or state.active then
				return
			end
			waiting.Text = "A Garden Spirit is drifting over... " .. i
			task.wait(1)
		end
		if waitToken == token then
			waiting.Visible = false
		end
	end)
end

function handlers.Start(msg)
	waitToken += 1
	waiting.Visible = false
	state.active = true
	state.fighting = false
	state.you = msg.You
	state.arena = msg.Arena
	state.p = 0
	state.shown = 0
	state.combo = 0
	state.aBloom, state.bBloom = msg.ABloom, msg.BBloom
	state.timeLeft = msg.Length

	local mine = if msg.You == "A" then msg.ABloom else msg.BBloom
	local theirs = if msg.You == "A" then msg.BBloom else msg.ABloom
	youName.Text = "You · " .. Util.Format(mine)
	themName.Text = (if msg.You == "A" then msg.BName else msg.AName) .. " · " .. Util.Format(theirs)
	local sMine, sTheirs = Util.Strength(mine), Util.Strength(theirs)
	local share = math.floor(sMine / (sMine + sTheirs) * 100 + 0.5)
	strengthHint.Text = "Your pull: " .. share .. "%  ·  tap fast to win!"
	timer.Text = tostring(msg.Length)
	panel.Visible = true
	local ps = panel:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = panel })
	ps.Scale = 0.5
	tween(ps, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)

	battleCamera()
	task.spawn(function()
		for i = msg.Countdown, 1, -1 do
			if not state.active then
				return
			end
			showCount(tostring(i))
			task.wait(1)
		end
	end)
end

function handlers.Fight()
	if not state.active then
		return
	end
	state.fighting = true
	showCount("BLOOM!", Color3.fromRGB(244, 182, 198))
	task.delay(0.6, function()
		tween(countdown, 0.3, { TextTransparency = 1 })
		task.wait(0.3)
		if state.fighting then
			countdown.Visible = false
		end
	end)
	tapButton.Visible = true
	tapScale.Scale = 0.3
	tween(tapScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local center = arenaInfo()
	if center then
		Effects.Ring(center + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 236, 196), 34, 0.8)
	end
end

function handlers.State(msg)
	state.p = msg.P
	state.timeLeft = msg.TimeLeft
	timer.Text = tostring(math.ceil(msg.TimeLeft))
	timer.TextColor3 = if msg.TimeLeft <= 3 then Color3.fromRGB(226, 120, 140) else C.Text
end

function handlers.End(msg)
	state.p = msg.P or state.p
	state.fighting = false
	tapButton.Visible = false
	comboLabel.Text = ""
	countdown.Visible = false
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if msg.Won then
		Hud.Banner("You won!", "+" .. Util.Format(msg.Reward) .. " Bloom from " .. msg.Opponent, ME)
		Sfx.Melody("Win")
		Effects.Flash(Color3.fromRGB(255, 240, 230), 0.3)
		Effects.Shake(0.4, 0.3)
		if root then
			Effects.Confetti(root.Position, { ME, C.Butter, C.Mint, C.Lavender, C.Sky })
		end
	else
		Hud.Banner("So close!", "+" .. Util.Format(msg.Reward) .. " Bloom for a lovely try", C.Lavender)
		Sfx.Melody("Lose")
	end
	task.delay(1.6, function()
		hide()
		restoreCamera()
	end)
end

function handlers.Cancel()
	hide()
	restoreCamera()
end

duelEvent.OnClientEvent:Connect(function(msg)
	local fn = handlers[msg.Type]
	if fn then
		fn(msg)
	end
end)

-- Smooth bar ---------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt)
	if not state.active then
		return
	end
	local myP = if state.you == "A" then state.p else -state.p
	state.shown += (myP - state.shown) * math.min(1, dt * 12)
	local frac = math.clamp(0.5 + state.shown * 0.5, 0, 1)
	fill.Size = UDim2.fromScale(frac, 1)
	knob.Position = UDim2.fromScale(frac, 0.5)
	knob.Rotation = os.clock() * 90
	if state.fighting and os.clock() - state.lastTap > 0.6 and comboLabel.Text ~= "" then
		comboLabel.Text = ""
	end
end)

player.CharacterAdded:Connect(function()
	if state.active then
		hide()
		restoreCamera()
	end
end)

return DuelUi
