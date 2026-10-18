--[[
	The 🎡 Spin Wheel panel: a wheel of slices (Shared/Spin.Slices), a pointer, and a Spin button.
	The server decides what you win; the wheel here just spins to it. A free spin every few hours,
	more from the Spin Pack in the Shop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Spin = require(Shared.Spin)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Sound = require(Modules.Sound)

local T = Ui.Theme
local rgb = Color3.fromRGB

local SpinPanel = {}

local WHEEL = 300 -- wheel diameter (px)
local COLORS = { rgb(70, 60, 120), rgb(50, 44, 92) }
local RARE = rgb(255, 196, 64)

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

function SpinPanel.Build(screen: Frame)
	local _, content = Ui.panel(screen, "Spin", "Spin Wheel", UDim2.fromOffset(560, 540), "🎡")
	local hint = Ui.text({
		Size = UDim2.new(1, 0, 0, 22),
		Text = "A free spin every 4 hours. Land on 🥚 for a Mystic Egg!",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		MaxTextSize = 14,
		Parent = content,
	})
	-- the wheel: a dark disc with the slices placed round the rim
	local wheel = Ui.new("Frame", {
		Name = "Wheel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.fromOffset(WHEEL, WHEEL),
		BackgroundColor3 = rgb(32, 28, 56),
		ClipsDescendants = true,
		Parent = content,
	}, { Ui.round(), Ui.stroke(rgb(255, 210, 120), 4) })
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(WHEEL, WHEEL), Parent = wheel })
	-- optional Higgsfield wheel art behind the slices
	if Config.Images and Config.Images.SpinWheel and Config.Images.SpinWheel ~= "" then
		Ui.new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Config.Images.SpinWheel,
			ScaleType = Enum.ScaleType.Fit,
			Parent = wheel,
		})
	end
	local n = #Spin.Slices
	local slices: { Frame } = {}
	for i, slice in Spin.Slices do
		local angle = (i - 1) / n * math.pi * 2 -- slice 1 at the top, clockwise
		local radius = WHEEL / 2 - 46
		local tile = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius),
			Size = UDim2.fromOffset(66, 66),
			BackgroundColor3 = if slice.Rare then RARE else COLORS[i % 2 + 1],
			BackgroundTransparency = if slice.Rare then 0.35 else 0.15,
			Parent = wheel,
		}, { Ui.corner(14), Ui.stroke(if slice.Rare then RARE else T.Edge, 1.5) })
		Ui.text({
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, 0, 0, 32),
			Text = slice.Icon,
			MaxTextSize = 26,
			Parent = tile,
		})
		Ui.text({
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, -4, 0, 24),
			Text = slice.Text,
			Font = T.Font,
			TextWrapped = true,
			TextColor3 = if slice.Rare then rgb(60, 40, 0) else Color3.new(1, 1, 1),
			MaxTextSize = 11,
			Parent = tile,
		})
		slices[i] = tile
	end
	-- the centre: pointer + result
	local centre = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = rgb(255, 210, 120),
		Parent = wheel,
	}, { Ui.round(), Ui.stroke(Color3.new(1, 1, 1), 3) })
	local centreText = Ui.text({
		Size = UDim2.fromScale(1, 1),
		Text = "🎡",
		MaxTextSize = 44,
		Parent = centre,
	})
	-- the pointer: a little arm from the centre that points at the lit slice
	local arm = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(8, WHEEL / 2 - 62),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = wheel,
	}, { Ui.round() })
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = rgb(255, 90, 90),
		Rotation = 45,
		Parent = arm,
	}, { Ui.corner(4) })

	local spinButton = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(260, 48),
		Text = "SPIN!",
		Variant = "Gold",
		Parent = content,
	}, function() end)
	local status = Ui.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		MaxTextSize = 14,
		Parent = content,
	})
	local more = Ui.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -30),
		Size = UDim2.fromOffset(110, 40),
		Text = "+ Spins",
		Variant = "Secondary",
		Parent = content,
	}, function()
		Ui.toggle("Shop", true)
		Ui.toast("Spin Packs are in the Shop under Boosts & Packs", T.Gold)
	end)

	local spinning = false
	local lit = 1
	local function light(index: number)
		for i, tile in slices do
			local stroke = tile:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = if i == index then 4 else 1.5
				stroke.Color = if i == index
					then Color3.new(1, 1, 1)
					else (if Spin.Slices[i].Rare then RARE else T.Edge)
			end
		end
		arm.Rotation = (index - 1) / n * 360
		lit = index
	end
	light(1)

	local function render()
		local data = State.Data
		local s = data and data.Spin
		if not s then
			return
		end
		local now = State.Now and State.Now() or os.time()
		local available = Spin.Available(s, now)
		local freeIn = (s.NextFree or 0) - now
		if spinning then
			spinButton.Text = "..."
		else
			spinButton.Text = if available > 0 then `SPIN!  ({available})` else "No spins"
			spinButton.BackgroundColor3 = if available > 0 then rgb(255, 200, 70) else T.GlassLight
			spinButton.TextColor3 = if available > 0 then rgb(40, 28, 6) else T.SubText
		end
		status.Text = if freeIn <= 0
			then "Free spin ready!"
			else `Next free spin in {clock(freeIn)}  ·  extra spins: {s.Spins or 0}`
	end

	-- the spin: light the slices faster then slower until we stop on the server's pick
	local function animateTo(index: number, done: () -> ())
		local total = Spin.SpinSeconds
		local laps = 3
		local steps = laps * n + ((index - lit) % n)
		local t0 = os.clock()
		local last = -1
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local p = math.clamp((os.clock() - t0) / total, 0, 1)
			local eased = TweenService:GetValue(p, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			local step = math.floor(eased * steps + 0.5)
			if step ~= last then
				last = step
				light(lit % n + 1)
				Sound.Play("Click", 0.6 + p * 0.6)
			end
			if p >= 1 then
				conn:Disconnect()
				light(index)
				done()
			end
		end)
	end

	spinButton.MouseButton1Click:Connect(function()
		if spinning then
			return
		end
		local data = State.Data
		if not data or not data.Spin or Spin.Available(data.Spin, State.Now and State.Now() or os.time()) <= 0 then
			Ui.toast("No spins left: get a Spin Pack or wait for the free one", T.SubText)
			return
		end
		spinning = true
		render()
		centreText.Text = "🎡"
		task.spawn(function()
			local ok, success, result, got = pcall(function()
				return Remotes.Function("SpinWheel"):InvokeServer()
			end)
			if not ok or not success then
				spinning = false
				Ui.toast(if ok and type(result) == "string" then result else "Something went wrong", T.Bad)
				render()
				return
			end
			animateTo(result, function()
				spinning = false
				local slice = Spin.Slices[result]
				centreText.Text = slice.Icon
				Sound.Play(if slice.Rare then "RareReveal" else "Reveal", 1)
				Ui.toast(`🎡 You won {got or slice.Text}!`, if slice.Rare then RARE else T.Good)
				render()
			end)
		end)
	end)

	Ui.onPanelOpen("Spin", render)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Spin") then
			render()
		end
	end)
	-- the countdown
	task.spawn(function()
		while true do
			task.wait(1)
			if Ui.isOpen("Spin") and not spinning then
				render()
			end
		end
	end)
	hint.Visible = true
	more.Visible = true
end

return SpinPanel
