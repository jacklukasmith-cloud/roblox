--[[
	Big-pull celebrations: when anyone pulls something rare (BigPull from the server) everyone
	sees a banner at the top of the screen, and fireworks burst over that player's head.
	Your own pulls skip the banner (you get the full hatch reveal) but still get fireworks.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Creatures)
local CreatureModels = require(Shared.CreatureModels)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local Layout = require(Modules.Layout)
local Sound = require(Modules.Sound)

local T = Ui.Theme
local GOLD = Color3.fromRGB(255, 215, 80)
local RAINBOW = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(90, 230, 120),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(200, 100, 255),
}
local SHOW_SECONDS = 4.5
local MAX_QUEUE = 4

local Celebrate = {}

-- Fireworks ------------------------------------------------------------------------------------
local function burst(position: Vector3, colors: { Color3 })
	local anchor = Instance.new("Part")
	anchor.Name = "Firework"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace
	local sequence = {}
	for i, color in colors do
		table.insert(sequence, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), color))
	end
	if #sequence == 1 then
		table.insert(sequence, ColorSequenceKeypoint.new(1, colors[1]))
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Enabled = false
	sparks.Color = ColorSequence.new(sequence)
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.9, 1.5)
	sparks.Speed = NumberRange.new(14, 22)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 3
	sparks.Acceleration = Vector3.new(0, -6, 0)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) })
	sparks.Parent = anchor
	local light = Instance.new("PointLight")
	light.Color = colors[1]
	light.Range = 22
	light.Brightness = 5
	light.Parent = anchor
	sparks:Emit(70)
	TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0 }):Play()
	Debris:AddItem(anchor, 2.5)
end

local function fireworks(userId: number, colors: { Color3 })
	local target = Players:GetPlayerByUserId(userId)
	local character = target and target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for i = 0, 2 do
		task.delay(i * 0.35, function()
			if root.Parent then
				local offset = Vector3.new(math.random(-30, 30) / 10, 7 + i * 1.5, math.random(-30, 30) / 10)
				burst(root.Position + offset, { colors[(i % #colors) + 1], colors[((i + 1) % #colors) + 1] })
			end
		end)
	end
end

-- Banner -----------------------------------------------------------------------------------------
function Celebrate.Build(root: Frame)
	local player = Players.LocalPlayer
	local banner = Ui.glass({
		Name = "BigPullBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(440, 60),
		Visible = false,
		ZIndex = 25,
		Parent = root,
	}, { Ui.corner(16) })
	local edge = banner:FindFirstChildOfClass("UIStroke")
	local scale = Ui.new("UIScale", { Parent = banner })
	local iconHolder = Ui.new("Frame", {
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 26,
		Parent = banner,
	}, { Ui.corner(12) })
	local iconGradient = Ui.new("UIGradient", { Rotation = 90, Parent = iconHolder })
	local who = Ui.text({
		Position = UDim2.fromOffset(64, 7),
		Size = UDim2.new(1, -170, 0, 20),
		Text = "",
		Font = T.Font,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 26,
		MaxTextSize = 15,
		Parent = banner,
	})
	local what = Ui.text({
		Position = UDim2.fromOffset(64, 28),
		Size = UDim2.new(1, -170, 0, 26),
		Text = "",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 26,
		MaxTextSize = 22,
		Parent = banner,
	})
	local tag = Ui.text({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(96, 40),
		Text = "",
		Font = T.FontHeavy,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 26,
		MaxTextSize = 14,
		Parent = banner,
	})

	local function arrange()
		local c = Layout.Compact
		banner.Size = UDim2.fromOffset(if c then 360 else 440, if c then 52 else 60)
		-- under the boss bar / boss countdown
		banner.Position = UDim2.new(0.5, 0, 0, if c then 114 else 152)
	end
	Layout.Changed:Connect(arrange)
	arrange()

	local queue = {}
	local showing = false

	local function show(pull)
		local def = Creatures.Get(pull.Id)
		if not def then
			return
		end
		local rarityColor = Creatures.Rarities[def.Rarity].Color
		local rainbow = pull.Variant == "Rainbow"
		who.Text = `{if pull.Global then "🌍" else "✨"} {pull.Name} {pull.Verb} a`
		what.Text = Creatures.DisplayName(pull.Id, pull.Variant)
		what.TextColor3 = if rainbow then RAINBOW[1] else rarityColor
		tag.Text = if pull.Global then `{string.upper(def.Rarity)}\nanother server` else string.upper(def.Rarity)
		tag.TextColor3 = rarityColor
		iconGradient.Color =
			ColorSequence.new(rarityColor:Lerp(Color3.new(1, 1, 1), 0.35), rarityColor:Lerp(Color3.new(0, 0, 0), 0.55))
		for _, child in iconHolder:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		CreatureModels.Viewport(pull.Id, pull.Variant, { Size = UDim2.fromScale(1, 1), ZIndex = 27 }).Parent =
			iconHolder
		if edge then
			edge.Color = rarityColor
			edge.Transparency = 0.1
			edge.Thickness = 2
		end
		banner.Visible = true
		scale.Scale = 0.5
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		Sound.Play("Chime", if pull.Global then 1.5 else 1.25, 0.7)
		-- rainbow pulls cycle their colours while shown
		local started = os.clock()
		while os.clock() - started < SHOW_SECONDS do
			if rainbow then
				local i = math.floor((os.clock() - started) * 4) % #RAINBOW + 1
				what.TextColor3 = RAINBOW[i]
				if edge then
					edge.Color = RAINBOW[i]
				end
			end
			task.wait(0.1)
		end
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0.01 }):Play()
		task.wait(0.22)
		banner.Visible = false
	end

	local function pump()
		if showing then
			return
		end
		showing = true
		task.spawn(function()
			while #queue > 0 do
				-- wait while your own hatch reveal is on screen (it hides the toasts)
				local toasts = root:FindFirstChild("Toasts") :: GuiObject?
				while toasts and toasts.Visible == false do
					task.wait(0.25)
				end
				local ok, err = pcall(show, table.remove(queue, 1))
				if not ok then
					banner.Visible = false
					warn("[Celebrate] " .. tostring(err))
				end
				task.wait(0.15)
			end
			showing = false
		end)
	end

	Remotes.Event("BigPull").OnClientEvent:Connect(function(pull)
		if type(pull) ~= "table" or type(pull.Id) ~= "string" then
			return
		end
		local def = Creatures.Get(pull.Id)
		if not def then
			return
		end
		local colors = if pull.Variant == "Rainbow" then RAINBOW else { Creatures.Rarities[def.Rarity].Color, GOLD }
		local mine = pull.UserId == player.UserId
		if pull.UserId ~= 0 then
			-- your own fireworks wait until the hatch reveal has had its moment
			task.delay(if mine then 3 else 0, fireworks, pull.UserId, colors)
		end
		if not mine or pull.Preview then
			table.insert(queue, pull)
			while #queue > MAX_QUEUE do
				table.remove(queue, 1)
			end
			pump()
		end
	end)
end

return Celebrate
