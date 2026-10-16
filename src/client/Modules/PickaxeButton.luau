--[[
	The ⛏ button (and Q on keyboards / X on controllers): takes your pickaxe out or puts it away.
	Roblox's hotbar is hidden in this game, so this is how you hold it. Lights up while held.

	Also the pickaxe's feel on this side: hold the mouse / finger down to keep swinging, sparks and
	a clink where you hit (a kick on crits), the mining-streak counter, a "get closer" hint and a
	dot on the button when you can afford the next pickaxe.
]]

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local Layout = require(Modules.Layout)
local Sound = require(Modules.Sound)
local State = require(Modules.State)

local cfg = Config.Pickaxe

-- Sparks + crystal chips where the pickaxe landed
local function sparks(model: Model, crit: boolean)
	local main = model.PrimaryPart
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not main or State.PotatoMode then
		return
	end
	-- the side of the target facing you, about chest height
	local toward = if root then (root.Position - main.Position) * Vector3.new(1, 0, 1) else Vector3.zero
	local half = math.max(main.Size.X, main.Size.Z) / 2
	local offset = if toward.Magnitude > 0.1 then toward.Unit * math.min(half, toward.Magnitude) else Vector3.zero
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = main.Position + offset + Vector3.new(0, 1, 0)
	anchor.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Enabled = false
	emitter.LightEmission = 1
	emitter.Color =
		ColorSequence.new(if crit then Color3.fromRGB(255, 215, 80) else Color3.fromRGB(255, 245, 210), main.Color)
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = anchor
	emitter:Emit(if crit then 26 else 12)
	Debris:AddItem(anchor, 1)
end

local function cameraKick(strength: number)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or State.PotatoMode then
		return
	end
	task.spawn(function()
		for i = 1, 5 do
			local k = strength * (1 - i / 6)
			humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
			task.wait(1 / 60)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

local T = Ui.Theme

local PickaxeButton = {}

function PickaxeButton.Build(root: Frame)
	local player = Players.LocalPlayer
	local busy = false
	local button: TextButton
	local function holding(): boolean
		local character = player.Character
		local tool = character and character:FindFirstChild("Pickaxe")
		return tool ~= nil and tool:IsA("Tool")
	end
	local shownSide = "Pick"
	local function refresh()
		local held = holding()
		button.BackgroundColor3 = if held then T.Gold else T.Glass
		button.BackgroundTransparency = if held then 0.05 else 0.18
		-- the server turns it round to the axe side near a boss
		local character = player.Character
		local tool = character and character:FindFirstChild("Pickaxe")
		local side = if held and tool and tool:GetAttribute("Side") == "Axe" then "Axe" else "Pick"
		button.Text = if side == "Axe" then "🪓" else "⛏"
		if side ~= shownSide then
			shownSide = side
			if held then
				Sound.Play("Click", if side == "Axe" then 0.7 else 1.4, 0.8)
				Ui.toast(
					if side == "Axe" then "🪓 Axe side! +50% damage to bosses" else "⛏ Back to the pick side",
					T.Gold
				)
			end
		end
	end
	local function toggle()
		if busy then
			return
		end
		busy = true
		Sound.Play("Click", 1.2)
		local wasHeld = holding()
		local ok, held = pcall(function()
			return Remotes.Function("TogglePickaxe"):InvokeServer()
		end)
		busy = false
		refresh()
		if not wasHeld and not (ok and held) then
			Ui.toast("Couldn't get your pickaxe out - try again in a moment", T.Bad)
		end
	end
	button = Ui.button({
		Name = "PickaxeButton",
		Text = "⛏",
		AnchorPoint = Vector2.new(1, 1),
		Variant = "Secondary",
		Parent = root,
	}, toggle)
	local hint = Ui.text({
		Name = "KeyHint",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(16, 14),
		Text = "Q",
		Font = T.FontHeavy,
		TextColor3 = T.SubText,
		MaxTextSize = 12,
		Parent = button,
	})
	-- upgrade-ready dot
	local dot = Ui.new("Frame", {
		Name = "UpgradeDot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 4, 0, 4),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = T.Good,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { Ui.round(), Ui.stroke(Color3.new(1, 1, 1), 1.5, 0.2) })
	-- mining-streak counter just above the button
	local streakLabel = Ui.text({
		Name = "Streak",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(80, 22),
		Text = "",
		Font = T.FontHeavy,
		TextColor3 = T.Gold,
		Visible = false,
		MaxTextSize = 18,
		Parent = button,
	})
	local streakScale = Ui.new("UIScale", { Parent = streakLabel })
	local streakToken = 0

	local function arrange()
		local touch = Layout.Touch or Layout.Compact
		local size = if Layout.Compact then 46 else 54
		button.Size = UDim2.fromOffset(size, size)
		-- phones/tablets: above the jump button; PC: bottom-right corner
		button.Position = if touch then UDim2.new(1, -24, 1, -205) else UDim2.new(1, -20, 1, -20)
		hint.Visible = not Layout.Touch and not Layout.Gamepad
	end
	Layout.Changed:Connect(arrange)
	arrange()

	ContextActionService:BindAction("MythicPickaxe", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(toggle)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)

	-- Hold to keep swinging (the first click swings by itself; this repeats while held)
	local holdingDown = false
	UserInputService.InputBegan:Connect(function(input, processed)
		local kind = input.UserInputType
		if processed or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
			return
		end
		if holdingDown or not holding() then
			return
		end
		holdingDown = true
		task.spawn(function()
			while holdingDown do
				local data = State.Data
				local golden = data and data.OwnedPasses and data.OwnedPasses.GoldenPickaxe
				task.wait(cfg.Cooldown * (if golden then cfg.GoldenSpeed else 1) + 0.03)
				local character = player.Character
				local tool = character and character:FindFirstChild("Pickaxe")
				if not holdingDown or not tool or not tool:IsA("Tool") then
					break
				end
				tool:Activate()
			end
		end)
	end)
	UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			holdingDown = false
		end
	end)

	-- What a swing did: sparks / clink / kick, the streak counter, or "get closer"
	local lastTooFar = 0
	Remotes.Event("PickaxeHit").OnClientEvent:Connect(function(model, crit, streak, near)
		if typeof(model) == "Instance" and model:IsA("Model") then
			sparks(model, crit == true)
			Sound.Play("Hit", if crit then 0.85 else 1.3 + math.random() * 0.15, if crit then 1 else 0.7)
			cameraKick(if crit then 0.25 else 0.08)
			if type(streak) == "number" and streak >= 2 then
				streakToken += 1
				local token = streakToken
				streakLabel.Text = if streak >= cfg.StreakMax then `⛏ MAX` else `⛏ x{streak}`
				streakLabel.TextColor3 = if streak >= cfg.StreakMax then Color3.fromRGB(255, 120, 90) else T.Gold
				streakLabel.Visible = true
				streakScale.Scale = 1.35
				TweenService:Create(streakScale, TweenInfo.new(0.15), { Scale = 1 }):Play()
				task.delay(cfg.StreakWindow, function()
					if token == streakToken then
						streakLabel.Visible = false
					end
				end)
			end
		elseif near and os.clock() - lastTooFar > 3 then
			lastTooFar = os.clock()
			Ui.toast("Get closer to swing!", T.SubText)
		end
	end)

	-- Dot (and a one-time hint per tier) when you can afford the next pickaxe
	local hinted = 0
	local function checkUpgrade()
		local d = State.Data
		local tier = d and d.Pickaxe or 1
		local nextTier = cfg.Tiers[tier + 1]
		local affordable = d ~= nil and nextTier ~= nil and d.Essence >= nextTier.Cost
		dot.Visible = affordable
		if affordable and hinted < tier + 1 then
			hinted = tier + 1
			Ui.toast(
				`⛏ You can afford the {nextTier.Name} ({Format.Number(nextTier.Cost)})! Visit the Blacksmith in the hub`,
				T.Gold
			)
		end
	end
	State.Changed:Connect(function(key)
		if key == "Data" then
			checkUpgrade()
		end
	end)
	checkUpgrade()

	-- keep the button in sync when the tool comes and goes (respawn, upgrades)
	local watchedTools = setmetatable({}, { __mode = "k" }) :: { [Instance]: boolean }
	local function watchTool(child: Instance)
		if child:IsA("Tool") and not watchedTools[child] then
			watchedTools[child] = true
			child.AttributeChanged:Connect(refresh)
		end
	end
	local function watch(character: Model)
		character.ChildAdded:Connect(function(child)
			watchTool(child)
			refresh()
		end)
		character.ChildRemoved:Connect(refresh)
		for _, child in character:GetChildren() do
			watchTool(child)
		end
		refresh()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

return PickaxeButton
