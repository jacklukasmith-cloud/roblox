--[[
	Pet Simulator-style hatch sequence:

	  1. the screen dims and the egg(s) drop in
	  2. the egg wobbles in bursts that get stronger, cracking a little more each time
	     (rare pulls wobble longer and glow in the rarity colour as a hint)
	  3. the egg swells and bursts in a flash of light
	  4. the creature pops out over spinning light rays, with its name, rarity and power

	Big pulls get a bigger moment: Rare+ adds a full-screen coloured flash and a rarity
	banner; Legendary+ (or Shiny/Rainbow) also adds screen shake and confetti.
	Click/tap anywhere to skip ahead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Eggs = require(Shared.Eggs)
local Creatures = require(Shared.Creatures)
local CreatureModels = require(Shared.CreatureModels)
local Format = require(Shared.Format)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local Layout = require(Modules.Layout)
local Sound = require(Modules.Sound)

local T = Ui.Theme
local WHITE = Color3.new(1, 1, 1)

local HatchAnim = {}

local BLEED = 160

local token = 0
local skipRequested = false

local function tween(
	inst: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- Waits, but returns early when the player taps to skip or a newer hatch starts
local function wait(seconds: number, myToken: number): boolean
	local finish = os.clock() + seconds
	while os.clock() < finish do
		if skipRequested or token ~= myToken then
			return false
		end
		task.wait()
	end
	return token == myToken
end

-- How big a moment a result deserves: rarity order, plus a bonus for Shiny/Rainbow
local function tierOf(result): number
	local def = Creatures.Get(result.Id)
	local order = if def then Creatures.Rarities[def.Rarity].Order else 1
	return order + (if result.Variant == "Rainbow" then 2 elseif result.Variant == "Shiny" then 1 else 0)
end

-- Egg in a ViewportFrame, with crack lines that can be revealed in stages ------------------
type EggView = {
	Holder: Frame,
	Scale: UIScale,
	Shake: (amount: number, t: number) -> (),
	Crack: (stage: number) -> (),
}

local function eggView(parent: Instance, color: Color3, size: number): EggView
	local holder = Ui.new("Frame", {
		Name = "Egg",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	})
	local scale = Ui.new("UIScale", { Scale = 0, Parent = holder })
	local viewport = Ui.new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(175, 175, 195),
		LightDirection = Vector3.new(-1, -1.5, -1),
		ZIndex = 3,
		Parent = holder,
	})
	local model = Instance.new("Model")
	local parts: { BasePart } = {}
	local function piece(props: { [string]: any }, mesh: boolean?): BasePart
		local p = Instance.new("Part")
		p.Anchored = true
		for k, v in props do
			(p :: any)[k] = v
		end
		if mesh then
			Instance.new("SpecialMesh", p).MeshType = Enum.MeshType.Sphere
		end
		p.Parent = model
		table.insert(parts, p)
		return p
	end
	local light = color:Lerp(WHITE, 0.55)
	piece({ Size = Vector3.new(2, 2.6, 2), Color = color, Material = Enum.Material.SmoothPlastic }, true)
	piece({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.18, 2.03, 2.03),
		CFrame = CFrame.new(0, -0.25, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = light,
		Material = Enum.Material.Neon,
	})
	for i = 0, 4 do
		local a = i * 1.25
		local y = 0.5 - (i % 2) * 0.5
		piece({
			Size = Vector3.new(0.5, 0.5, 0.14),
			CFrame = CFrame.lookAt(
				Vector3.new(math.cos(a) * 0.93, y, math.sin(a) * 0.93),
				Vector3.new(math.cos(a) * 2, y, math.sin(a) * 2)
			),
			Color = light,
		}, true)
	end
	-- Zig-zag crack across the side facing the camera
	local crack: { BasePart } = {}
	local function onShell(x: number, y: number): Vector3
		local z = -math.sqrt(math.max(0.02, 1 - x * x - (y * y) / 1.69))
		return Vector3.new(x, y, z) * 1.03
	end
	local points = {}
	for i = 0, 8 do
		local x = -0.85 + i * (1.7 / 8)
		local y = 0.35 + (if i % 2 == 0 then 0.13 else -0.13)
		table.insert(points, onShell(x, y))
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = piece({
			Size = Vector3.new(0.07, 0.07, (b - a).Magnitude + 0.04),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = Color3.fromRGB(25, 18, 30),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 1,
		})
		table.insert(crack, seg)
	end
	local base = {}
	for i, p in parts do
		base[i] = p.CFrame
	end
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	-- the crack is on the -Z side, so look at the egg from there
	camera.CFrame = CFrame.lookAt(Vector3.new(1.3, 0.9, -6.3), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	return {
		Holder = holder,
		Scale = scale,
		Shake = function(amount: number, t: number)
			local tilt = CFrame.Angles(0, 0, math.sin(t * 34) * 0.42 * amount)
				* CFrame.Angles(math.sin(t * 23) * 0.12 * amount, 0, 0)
			for i, p in parts do
				p.CFrame = tilt * base[i]
			end
		end,
		Crack = function(stage: number)
			-- stage 1 shows the middle of the crack, stage 2 all of it
			local n = #crack
			for i, seg in crack do
				local fromMiddle = math.abs(i - (n + 1) / 2)
				if stage >= 2 or fromMiddle <= n / 4 then
					seg.Transparency = 0
				end
			end
		end,
	}
end

-- Spinning light rays behind a creature
local function rays(parent: Instance, color: Color3, size: number, count: number, strength: number): Frame
	local holder = Ui.new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = parent,
	})
	for i = 1, count do
		local ray = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, math.max(10, size * 0.07), 1, 0),
			Rotation = (i - 1) * (180 / count),
			BackgroundColor3 = color:Lerp(WHITE, 0.35),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = holder,
		})
		Ui.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 1 - strength),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = ray,
		})
	end
	-- soft core glow
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - strength * 0.6,
		ZIndex = 1,
		Parent = holder,
	}, { Ui.round() })
	return holder
end

local function confetti(parent: Frame, colors: { Color3 }, myToken: number)
	local bits = {}
	for i = 1, 46 do
		local f = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(math.random(7, 12), math.random(10, 18)),
			BackgroundColor3 = colors[(i % #colors) + 1],
			BorderSizePixel = 0,
			ZIndex = 9,
			Parent = parent,
		}, { Ui.corner(2) })
		local angle = math.random() * math.pi * 2
		local speed = math.random(260, 620)
		table.insert(bits, {
			Frame = f,
			X = 0,
			Y = 0,
			VX = math.cos(angle) * speed,
			VY = math.sin(angle) * speed - 380,
			Spin = math.random(-400, 400),
			R = 0,
		})
	end
	task.spawn(function()
		local last = os.clock()
		local start = last
		while os.clock() - start < 2.2 and token == myToken do
			local now = os.clock()
			local dt = now - last
			last = now
			for _, b in bits do
				b.VY += 900 * dt
				b.X += b.VX * dt
				b.Y += b.VY * dt
				b.VX *= 0.985
				b.Frame.Position = UDim2.new(0.5, b.X, 0.42, b.Y)
				b.R += b.Spin * dt
				b.Frame.Rotation = b.R
				b.Frame.BackgroundTransparency = math.clamp((now - start - 1.4) / 0.8, 0, 1)
			end
			task.wait()
		end
		for _, b in bits do
			b.Frame:Destroy()
		end
	end)
end

local BANNER_WORDS = {
	[3] = "RARE!",
	[4] = "EPIC!",
	[5] = "LEGENDARY!",
	[6] = "MYTHIC!",
	[7] = "CHAMPION!",
}

function HatchAnim.Init(root: Frame)
	local overlay = Ui.new("TextButton", {
		Name = "HatchOverlay",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		-- reaches past the safe-area insets so the dim covers the whole screen
		Position = UDim2.fromOffset(-BLEED, -BLEED),
		Size = UDim2.new(1, BLEED * 2, 1, BLEED * 2),
		BackgroundColor3 = Color3.fromRGB(6, 6, 16),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = root,
	})
	-- Everything in the sequence sits in this frame so it can be shaken as one
	local stage = Ui.new("Frame", {
		Name = "Stage",
		Position = UDim2.fromOffset(BLEED, BLEED),
		Size = UDim2.new(1, -BLEED * 2, 1, -BLEED * 2),
		BackgroundTransparency = 1,
		ZIndex = 41,
		Parent = overlay,
	})
	local title = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromOffset(600, 34),
		Text = "",
		Font = T.FontHeavy,
		ZIndex = 45,
		MaxTextSize = 30,
		Parent = stage,
	})
	local banner = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.17),
		Size = UDim2.fromOffset(700, 70),
		Text = "",
		Font = T.FontHeavy,
		Visible = false,
		ZIndex = 46,
		MaxTextSize = 64,
		Parent = stage,
	})
	local bannerScale = Ui.new("UIScale", { Parent = banner })
	local bannerGradient = Ui.new("UIGradient", { Rotation = 0, Parent = banner })
	local hint = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(400, 20),
		Text = "Tap to skip",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		ZIndex = 45,
		MaxTextSize = 16,
		Parent = stage,
	})
	local row = Ui.new("Frame", {
		Name = "Row",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.new(1, 0, 0, 320),
		BackgroundTransparency = 1,
		ZIndex = 42,
		Parent = stage,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 24),
		}),
	})
	local screenFlash = Ui.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		ZIndex = 60,
		Parent = overlay,
	})

	overlay.Activated:Connect(function()
		skipRequested = true
	end)

	local function close(myToken: number)
		if token ~= myToken then
			return
		end
		tween(overlay, 0.25, { BackgroundTransparency = 1 })
		for _, card in row:GetChildren() do
			if card:IsA("Frame") then
				local s = card:FindFirstChildOfClass("UIScale")
				if s then
					tween(s, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				end
			end
		end
		title.Text = ""
		banner.Visible = false
		task.delay(0.26, function()
			if token == myToken then
				overlay.Visible = false
				local toasts = root:FindFirstChild("Toasts") :: GuiObject?
				if toasts then
					toasts.Visible = true
				end
				for _, card in row:GetChildren() do
					if card:IsA("Frame") then
						card:Destroy()
					end
				end
			end
		end)
	end

	local function play(eggId: string, results: { any }, opts: { Title: string? }?)
		token += 1
		local myToken = token
		skipRequested = false
		local egg = Eggs.Get(eggId)
		local eggColor = if egg then egg.Color else T.Accent

		for _, card in row:GetChildren() do
			if card:IsA("Frame") then
				card:Destroy()
			end
		end
		banner.Visible = false
		title.Text = if opts and opts.Title then opts.Title elseif egg then egg.Name else "Egg"
		title.TextColor3 = WHITE
		hint.Text = "Tap to skip"
		hint.Visible = true
		local compact = Layout.Compact
		title.Position = UDim2.fromScale(0.5, if compact then 0.05 else 0.1)
		banner.Position = UDim2.fromScale(0.5, if compact then 0.12 else 0.17)
		banner.Size = UDim2.fromOffset(700, if compact then 50 else 70)
		local rowY = if compact then 0.53 else 0.5
		row.Position = UDim2.fromScale(0.5, rowY)
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		stage.Position = UDim2.fromOffset(BLEED, BLEED)
		-- notifications would sit on top of the cards; hide them until the reveal closes
		local toasts = root:FindFirstChild("Toasts") :: GuiObject?
		if toasts then
			toasts.Visible = false
		end
		tween(overlay, 0.25, { BackgroundTransparency = 0.4 })

		local bestTier, bestResult = 0, results[1]
		for _, r in results do
			local t = tierOf(r)
			if t > bestTier then
				bestTier, bestResult = t, r
			end
		end
		local bestDef = bestResult and Creatures.Get(bestResult.Id)
		local bestColor = if bestDef then Creatures.Rarities[bestDef.Rarity].Color else WHITE

		local cardW = if Layout.Compact
			then (if #results > 1 then 118 else 150)
			else (if #results > 1 then 190 else 240)
		row.Size = UDim2.new(1, 0, 0, cardW + 90)
		-- the hint sits just under the cards
		hint.Position = UDim2.new(0.5, 0, rowY, (cardW + 90) / 2 + (if compact then 2 else 12))

		-- 1) Eggs drop in --------------------------------------------------------------
		local cards = {}
		for i, result in results do
			local def = Creatures.Get(result.Id)
			if not def then
				continue
			end
			local rarityColor = Creatures.Rarities[def.Rarity].Color
			local card = Ui.new("Frame", {
				LayoutOrder = i,
				Size = UDim2.fromOffset(cardW, cardW + 90),
				BackgroundTransparency = 1,
				ZIndex = 42,
				Parent = row,
			})
			local cardScale = Ui.new("UIScale", { Parent = card })
			local center = UDim2.new(0.5, 0, 0, cardW / 2)
			local glow = Ui.new("Frame", {
				Name = "Hint",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = center,
				Size = UDim2.fromOffset(cardW * 0.85, cardW * 0.85),
				BackgroundColor3 = rarityColor,
				BackgroundTransparency = 1,
				ZIndex = 2,
				Parent = card,
			}, { Ui.round() })
			local view = eggView(card, eggColor, cardW * 0.82)
			view.Holder.Position = center - UDim2.fromOffset(0, 60)
			tween(view.Holder, 0.45, { Position = center }, Enum.EasingStyle.Bounce)
			tween(view.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			table.insert(cards, {
				Card = card,
				CardScale = cardScale,
				Center = center,
				Glow = glow,
				View = view,
				Result = result,
				Def = def,
				Color = rarityColor,
				Tier = tierOf(result),
			})
		end
		Sound.Play("Click", 0.8, 0.8)

		-- 2) Wobble in bursts, cracking more each time ------------------------------------
		local bursts = { { 0.3, 0.3 }, { 0.32, 0.5 }, { 0.38, 0.75 } }
		if bestTier >= 3 then
			table.insert(bursts, { 0.45, 1 }) -- rare pulls keep you waiting a little longer
		end
		local skipped = not wait(0.45, myToken)
		for b, burst in bursts do
			if skipped then
				break
			end
			local duration, amount = burst[1], burst[2]
			local isLast = b == #bursts
			if isLast and bestTier >= 3 then
				-- hint: rare eggs start to glow in their rarity colour
				for _, c in cards do
					if c.Tier >= 3 then
						tween(c.Glow, duration, { BackgroundTransparency = 0.55 })
					end
				end
				if bestTier >= 5 then
					tween(overlay, duration, { BackgroundTransparency = 0.15 })
				end
			end
			local start = os.clock()
			local nextTick = 0
			while os.clock() - start < duration do
				if skipRequested or token ~= myToken then
					skipped = true
					break
				end
				local now = os.clock()
				for _, c in cards do
					c.View.Shake(amount, now)
				end
				if now >= nextTick then
					Sound.Play("EggShake", Sound.Pitch("EggShake", 0.85 + b * 0.15), 0.5 + amount * 0.6)
					nextTick = now + 0.2 - amount * 0.08
				end
				task.wait()
			end
			for _, c in cards do
				c.View.Shake(0, 0)
				if b == 1 then
					c.View.Crack(1)
				elseif b == 2 then
					c.View.Crack(2)
				end
			end
			if b < #bursts and not skipped then
				skipped = not wait(0.16, myToken)
			end
		end
		if token ~= myToken then
			return
		end
		skipRequested = false

		-- 3) Swell, then burst in a flash -------------------------------------------------
		for _, c in cards do
			tween(c.View.Scale, 0.14, { Scale = 1.2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.wait(0.14)
		if token ~= myToken then
			return
		end
		Sound.Play("Break", Sound.Pitch("Break", 1.25), 0.8)
		Sound.Reveal(bestTier)
		if bestTier >= 3 then
			screenFlash.BackgroundColor3 = bestColor:Lerp(WHITE, 0.55)
			screenFlash.BackgroundTransparency = 0
			tween(screenFlash, if bestTier >= 5 then 0.9 else 0.55, { BackgroundTransparency = 1 })
		end
		if bestTier >= 5 then
			-- screen shake
			task.spawn(function()
				local start = os.clock()
				while os.clock() - start < 0.45 and token == myToken do
					local k = 1 - (os.clock() - start) / 0.45
					stage.Position =
						UDim2.fromOffset(BLEED + math.random(-14, 14) * k, BLEED + math.random(-10, 10) * k)
					task.wait()
				end
				stage.Position = UDim2.fromOffset(BLEED, BLEED)
			end)
		end

		-- 4) Reveal --------------------------------------------------------------------
		local spinning: { Frame } = {}
		local cameras: { { Camera: Camera, Radius: number } } = {}
		for _, c in cards do
			c.View.Holder:Destroy()
			c.Glow.BackgroundTransparency = 1
			local card = c.Card
			local flash = Ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = c.Center,
				Size = UDim2.fromOffset(cardW, cardW),
				BackgroundColor3 = WHITE,
				ZIndex = 8,
				Parent = card,
			}, { Ui.round() })
			tween(flash, 0.5, { BackgroundTransparency = 1, Size = UDim2.fromOffset(cardW * 1.5, cardW * 1.5) })
			task.delay(0.5, function()
				flash:Destroy()
			end)

			local big = c.Tier >= 3
			local rayFrame = rays(card, c.Color, cardW * 1.45, if big then 12 else 8, if big then 0.75 else 0.35)
			rayFrame.Position = c.Center
			table.insert(spinning, rayFrame)

			local vp = CreatureModels.Viewport(c.Def.Id, c.Result.Variant, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = c.Center,
				Size = UDim2.fromOffset(cardW * 0.92, cardW * 0.92),
				ZIndex = 4,
			})
			vp.Parent = card
			local vpScale = Ui.new("UIScale", { Scale = 0.2, Parent = vp })
			tween(vpScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			local cam = vp.CurrentCamera
			if cam then
				table.insert(cameras, { Camera = cam, Radius = cam.CFrame.Position.Magnitude })
			end

			local nameLabel = Ui.text({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, cardW + 2),
				Size = UDim2.new(1, 20, 0, 30),
				Text = Creatures.DisplayName(c.Def.Id, c.Result.Variant),
				Font = T.FontHeavy,
				TextColor3 = WHITE,
				ZIndex = 5,
				MaxTextSize = 26,
				Parent = card,
			})
			local pill = Ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, cardW + 36),
				Size = UDim2.fromOffset(math.min(cardW, 130), 24),
				BackgroundColor3 = c.Color,
				BackgroundTransparency = 0.75,
				ZIndex = 5,
				Parent = card,
			}, { Ui.round(), Ui.stroke(c.Color, 1.5, 0.3) })
			Ui.text({
				Size = UDim2.fromScale(1, 1),
				Text = c.Def.Rarity,
				TextColor3 = c.Color:Lerp(WHITE, 0.2),
				ZIndex = 6,
				MaxTextSize = 16,
				Parent = pill,
			})
			Ui.text({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, cardW + 64),
				Size = UDim2.new(1, 0, 0, 20),
				Text = "💪 " .. Format.Number(Creatures.GetPower(c.Def.Id, c.Result.Variant)),
				Font = T.Font,
				TextColor3 = T.Power,
				ZIndex = 5,
				MaxTextSize = 17,
				Parent = card,
			})
			if c.Result.New then
				local badge = Ui.new("Frame", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -4, 0, 4),
					Size = UDim2.fromOffset(54, 24),
					BackgroundColor3 = T.Good,
					Rotation = 8,
					ZIndex = 7,
					Parent = card,
				}, { Ui.round() })
				Ui.text({
					Size = UDim2.fromScale(1, 1),
					Text = "NEW!",
					Font = T.FontHeavy,
					ZIndex = 8,
					MaxTextSize = 15,
					Parent = badge,
				})
				local badgeScale = Ui.new("UIScale", { Scale = 0, Parent = badge })
				task.delay(0.3, function()
					tween(badgeScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
				end)
			end
			nameLabel.TextTransparency = 1
			tween(nameLabel, 0.3, { TextTransparency = 0 })
		end

		-- Rarity banner + confetti for the big ones
		title.Text = ""
		if bestTier >= 3 and bestDef then
			local word = BANNER_WORDS[math.min(Creatures.Rarities[bestDef.Rarity].Order, 7)] or "WOW!"
			if bestResult.Variant == "Rainbow" then
				word = "RAINBOW " .. word
			elseif bestResult.Variant == "Shiny" then
				word = "SHINY " .. word
			end
			if Creatures.Rarities[bestDef.Rarity].Order < 3 then
				word = string.upper(Creatures.DisplayName(bestDef.Id, bestResult.Variant)) .. "!"
			end
			banner.Text = word
			banner.TextColor3 = WHITE
			bannerGradient.Color = if bestResult.Variant == "Rainbow"
				then ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 90)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 110, 255)),
				})
				else ColorSequence.new(bestColor:Lerp(WHITE, 0.5), bestColor)
			bannerGradient.Rotation = 90
			banner.Visible = true
			bannerScale.Scale = 0.2
			tween(bannerScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			title.Text = if #cards > 1 then "You hatched:" else "You hatched"
		end
		if bestTier >= 5 then
			confetti(stage, { bestColor, WHITE, bestColor:Lerp(WHITE, 0.4), T.Gold }, myToken)
		end

		-- Spin the rays and slowly orbit each creature while the reveal is on screen
		task.spawn(function()
			local start = os.clock()
			while token == myToken and overlay.Visible do
				local t = os.clock() - start
				for i, r in spinning do
					r.Rotation = t * (if i % 2 == 0 then -28 else 28)
				end
				for _, cam in cameras do
					local angle = math.sin(t * 0.9) * 0.6
					local dir = Vector3.new(math.sin(angle + 0.5), 0.35, -math.cos(angle + 0.5)).Unit
					cam.Camera.CFrame = CFrame.lookAt(dir * cam.Radius, Vector3.zero)
				end
				task.wait()
			end
		end)

		-- Hold, then close (tap to close early) ---------------------------------------
		hint.Text = "Tap to continue"
		wait(if bestTier >= 5 then 3.4 elseif bestTier >= 3 then 2.6 else 2, myToken)
		close(myToken)
	end

	Remotes.Event("HatchResult").OnClientEvent:Connect(function(eggId, results, opts)
		task.spawn(play, eggId, results, if type(opts) == "table" then opts else nil)
	end)
end

return HatchAnim
