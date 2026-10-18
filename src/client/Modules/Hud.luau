--[[
	Always-on HUD (clean "frosted glass" style):
	  - bottom-centre: one glass currency bar (Essence / Trophies / Power) + boosts above it
	  - top-centre: Mana Surge banner, weather line, live surge leaderboard
	  - right: House War card with progress bars (collapsible; collapsed on phones)
	Everything re-arranges for phones via Layout.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Config = require(Shared.Config)
local Weather = require(Shared.Weather)
local Events = require(Shared.Events)
local Houses = require(Shared.Houses)
local Ui = require(script.Parent.Ui)
local Layout = require(script.Parent.Layout)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local Hud = {}

local T = Ui.Theme

-- One segment of the currency bar: small caps label over a big value, with an icon chip
local function segment(parent: Instance, order: number, icon: string, label: string, color: Color3)
	local frame = Ui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(170, 48),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local chip = Ui.new("Frame", {
		Size = UDim2.fromOffset(34, 34),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.75,
		Parent = frame,
	}, { Ui.corner(10) })
	Ui.text({ Text = icon, Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), Parent = chip })
	local caption = Ui.text({
		Text = string.upper(label),
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		Size = UDim2.new(1, -44, 0, 14),
		Position = UDim2.fromOffset(44, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		Parent = frame,
	})
	local value = Ui.text({
		Text = "0",
		Font = T.FontHeavy,
		TextColor3 = color,
		Size = UDim2.new(1, -44, 0, 26),
		Position = UDim2.fromOffset(44, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Parent = frame,
	})
	return frame, value, caption
end

local function divider(parent: Instance, order: number)
	return Ui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(1, 30),
		BackgroundColor3 = T.Edge,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

function Hud.Build(root: Frame)
	-- Bottom-centre: boosts row, multipliers, currency bar ------------------------------
	local bottom = Ui.new("Frame", {
		Name = "BottomBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(640, 110),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local boostRow = Ui.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(560, 24),
		BackgroundTransparency = 1,
		Parent = bottom,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local multLabel = Ui.text({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(420, 16),
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		Text = "",
		MaxTextSize = 15,
		Parent = bottom,
	})
	local bar = Ui.glass({
		Name = "Currency",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(600, 60),
		Parent = bottom,
	}, {
		Ui.corner(16),
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10) }),
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local essenceSeg, essenceValue, essenceCaption = segment(bar, 1, "💎", "Essence", T.Essence)
	local plus = Ui.button({
		Text = "+",
		Variant = "Success",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(32, 32),
		Parent = bar,
	}, function()
		Ui.toggle("Shop", true) -- quick route to buying more
	end)
	local div1 = divider(bar, 3)
	local trophySeg, trophyValue = segment(bar, 4, "🏆", "Trophies", T.Trophy)
	local div2 = divider(bar, 5)
	local powerSeg, powerValue = segment(bar, 6, "💪", "Power", T.Power)

	-- Top-centre: Mana Surge banner, weather, live leaderboard -------------------------
	local top = Ui.new("Frame", {
		Name = "TopCenter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(440, 100),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- Slim, low-key pill; click it to show/hide the surge leaderboard
	local banner = Ui.glass({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(300, 30),
		BackgroundTransparency = 0.4,
		Parent = top,
	}, { Ui.round() })
	local showTop = false
	local refreshSurge: () -> ()
	local bannerButton = Ui.new("TextButton", {
		Name = "Toggle",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = banner,
	})
	bannerButton.Activated:Connect(function()
		showTop = not showTop
		refreshSurge()
	end)
	local bannerDot = Ui.new("Frame", {
		Size = UDim2.fromOffset(8, 8),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		BackgroundColor3 = T.Accent,
		Parent = banner,
	}, { Ui.round() })
	local bannerText = Ui.text({
		Size = UDim2.new(1, -44, 1, -12),
		Position = UDim2.fromOffset(30, 6),
		Text = "",
		Font = T.Font,
		MaxTextSize = 16,
		Parent = banner,
	})
	local weatherText = Ui.text({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(420, 14),
		Font = T.FontRegular,
		Text = "",
		TextColor3 = T.SubText,
		TextTransparency = 0.15,
		MaxTextSize = 13,
		Parent = top,
	})
	-- weekend event line (shown while one is on; the countdown to the next one hides on phones)
	local eventText = Ui.text({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(420, 14),
		Font = T.Font,
		Text = "",
		TextColor3 = T.SubText,
		MaxTextSize = 13,
		Visible = false,
		Parent = top,
	})
	local topList = Ui.glass({
		LayoutOrder = 4,
		Size = UDim2.fromOffset(240, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.35,
		Visible = false,
		Parent = top,
	}, {
		Ui.corner(12),
		Ui.padding(8),
		Ui.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local topRows = {}
	for i = 1, 5 do
		topRows[i] = Ui.text({
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 18),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 15,
			Parent = topList,
		})
	end

	-- Right: House War card ------------------------------------------------------------
	local house = Ui.glass({
		Name = "House",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(230, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	}, {
		Ui.corner(14),
		Ui.padding(10),
		Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local expanded = false
	local userChose = false -- once the player opens/closes it, keep their choice
	local houseHeader = Ui.new("TextButton", {
		LayoutOrder = 0,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = house,
	})
	local houseTitle = Ui.text({
		Size = UDim2.fromScale(1, 1),
		Text = "House War",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = houseHeader,
	})
	local houseRows: { [string]: { Frame: Frame, Bar: Frame, Name: TextLabel, Points: TextLabel } } = {}
	for i, id in Houses.Order do
		local h = Houses.List[id]
		local row = Ui.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Parent = house,
		})
		local name = Ui.text({
			Size = UDim2.new(0.6, 0, 0, 16),
			Font = T.FontRegular,
			Text = string.gsub(h.Name, "House ", ""),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 15,
			Parent = row,
		})
		local points = Ui.text({
			Size = UDim2.new(0.4, 0, 0, 16),
			Position = UDim2.fromScale(0.6, 0),
			Text = "0",
			TextColor3 = h.Color,
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 15,
			Parent = row,
		})
		local track = Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, 6),
			Position = UDim2.fromOffset(0, 21),
			BackgroundColor3 = T.Edge,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			Parent = row,
		}, { Ui.round() })
		local fill = Ui.new(
			"Frame",
			{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = h.Color, BorderSizePixel = 0, Parent = track },
			{ Ui.round() }
		)
		houseRows[id] = { Frame = row, Bar = fill, Name = name, Points = points }
	end
	local houseHint = Ui.text({
		LayoutOrder = 9,
		Size = UDim2.new(1, 0, 0, 14),
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		Text = "",
		MaxTextSize = 13,
		Parent = house,
	})
	local function setExpanded(value: boolean)
		expanded = value
		for _, r in houseRows do
			r.Frame.Visible = value
		end
		houseHint.Visible = value
	end
	houseHeader.Activated:Connect(function()
		Sound.Play("Click", 1.1)
		userChose = true
		setExpanded(not expanded)
	end)

	local tint = Ui.new("ColorCorrectionEffect", { Name = "SurgeTint", Parent = Lighting })

	-- Height of Roblox's top bar and the free strip in its middle (empty on mobile)
	local function topbarSpace(): (number, number, number)
		local ok, rect = pcall(function()
			return GuiService.TopbarInset
		end)
		if ok and typeof(rect) == "Rect" and rect.Height > 0 then
			return rect.Height, rect.Min.X, rect.Max.X
		end
		return 0, 0, 0
	end

	-- Responsive arrangement ------------------------------------------------------------
	local function arrange()
		local c = Layout.Compact
		local segW = if c then 112 else 150
		essenceSeg.Size = UDim2.fromOffset(if c then 120 else 160, 48)
		trophySeg.Size = UDim2.fromOffset(segW - (if c then 16 else 10), 48)
		powerSeg.Size = UDim2.fromOffset(segW, 48)
		plus.Size = UDim2.fromOffset(if c then 28 else 32, if c then 28 else 32)
		bar.Size = UDim2.fromOffset(if c then 470 else 600, if c then 54 else 60)
		div1.Visible, div2.Visible = true, true
		multLabel.Visible = false -- the Essence caption shows the multiplier instead
		bottom.Position = UDim2.new(0.5, 0, 1, if c then -6 else -14)
		local bannerW, bannerH = if c then 240 else 300, if c then 26 else 30
		banner.Size = UDim2.fromOffset(bannerW, bannerH)
		top.Position = UDim2.new(0.5, 0, 0, if c then 2 else 4)
		-- Touch devices: tuck the banner up into the empty middle of Roblox's top bar
		if Layout.Touch or c then
			local barH, freeMin, freeMax = topbarSpace()
			local scale = Layout.Scale
			local screenW = Layout.Size.X * scale
			local half = bannerW * scale / 2
			if barH >= bannerH * scale and freeMin <= screenW / 2 - half and freeMax >= screenW / 2 + half then
				top.Position = UDim2.new(0.5, 0, 0, -barH / scale + (barH / scale - bannerH) / 2)
			end
		end
		weatherText.Visible = false -- refreshWorld shows it while a weather is active
		weatherText.Size = UDim2.fromOffset(420, 14)
		topList.Size = UDim2.fromOffset(if c then 200 else 240, 20)
		house.Size = UDim2.fromOffset(if c then 190 else 230, 40)
		house.Position = UDim2.new(1, if c then -8 else -14, if c then 0.3 else 0.5, 0)
		setExpanded(if userChose then expanded else false) -- starts collapsed; tap the header to open
	end
	Layout.Changed:Connect(arrange)
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(arrange)
	end)
	arrange()

	-- Updaters --------------------------------------------------------------------------
	local boostChips: { [string]: TextLabel } = {}
	local function refreshStats()
		local d = State.Data
		if not d then
			return
		end
		essenceValue.Text = Format.Number(d.Essence)
		trophyValue.Text = Format.Number(d.Trophies)
		powerValue.Text = Format.Number(d.Power)
		multLabel.Text =
			`Essence x{math.floor(d.EssenceMultiplier * 100) / 100}  ·  Luck x{math.floor(d.Luck * 100) / 100}`
		essenceCaption.Text = if d.EssenceMultiplier > 1.001
			then `ESSENCE  x{math.floor(d.EssenceMultiplier * 10 + 0.5) / 10}`
			else "ESSENCE"
		local now = State.Now()
		local seen = {}
		for name, endsAt in d.Boosts do
			if endsAt > now then
				seen[name] = true
				local chip = boostChips[name]
				if not chip then
					local frame = Ui.glass(
						{ Size = UDim2.fromOffset(Layout.pick(96, 112), 24), Parent = boostRow },
						{ Ui.round() }
					)
					Ui.new("Frame", {
						Size = UDim2.fromOffset(8, 8),
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 10, 0.5, 0),
						BackgroundColor3 = T.Good,
						Parent = frame,
					}, { Ui.round() })
					chip = Ui.text({
						Size = UDim2.new(1, -28, 1, -6),
						Position = UDim2.fromOffset(22, 3),
						Font = T.FontRegular,
						MaxTextSize = 14,
						Parent = frame,
					})
					boostChips[name] = chip
				end
				chip.Text = `{name}  {Format.Time(endsAt - now)}`
			end
		end
		-- Friend Boost chip (no timer: lasts while your friends are in the server)
		local friends = d.FriendBoost or 0
		if friends > 0 then
			seen.__friends = true
			local chip = boostChips.__friends
			if not chip then
				local frame = Ui.glass(
					{ Size = UDim2.fromOffset(Layout.pick(110, 130), 24), Parent = boostRow },
					{ Ui.round() }
				)
				chip = Ui.text({
					Size = UDim2.new(1, -12, 1, -6),
					Position = UDim2.fromOffset(6, 3),
					Font = T.FontRegular,
					TextColor3 = Color3.fromRGB(140, 215, 255),
					MaxTextSize = 14,
					Parent = frame,
				})
				boostChips.__friends = chip
			end
			chip.Text = `👥 Friends +{math.floor(friends * Config.FriendBoost.PerFriend * 100 + 0.5)}%`
		end
		for name, chip in boostChips do
			if not seen[name] then
				(chip.Parent :: Instance):Destroy()
				boostChips[name] = nil
			end
		end
	end

	function refreshSurge()
		local s = State.Surge
		if not s then
			bannerText.Text = "Mana Surge"
			return
		end
		local left = Format.Time(s.EndsAt - State.Now())
		if s.Active then
			local rank = if s.MyRank then `#{s.MyRank}` else "–"
			local arrow = if showTop then "▴" else "▾"
			bannerText.Text = `Mana Surge  {left}  ·  {rank}  {arrow}`
			bannerText.TextColor3 = Color3.fromRGB(226, 200, 255)
			bannerDot.BackgroundColor3 = Color3.fromRGB(200, 120, 255)
			banner.BackgroundTransparency = 0.3
			topList.Visible = showTop and #s.Top > 0
			for i = 1, 5 do
				local entry = s.Top[i]
				topRows[i].Visible = entry ~= nil
				topRows[i].Text = if entry then `{i}.  {entry.Name}   {Format.Number(entry.Score)}` else ""
				topRows[i].TextColor3 = if entry
						and entry.House
						and Houses.List[entry.House]
					then Houses.List[entry.House].Color
					else T.Text
			end
			tint.TintColor = Color3.fromRGB(235, 215, 255)
			tint.Saturation = 0.25
		else
			bannerText.Text = `Next surge in {left}`
			bannerText.TextColor3 = T.SubText
			bannerDot.BackgroundColor3 = T.Accent
			banner.BackgroundTransparency = 0.55
			topList.Visible = false
			tint.TintColor = Color3.new(1, 1, 1)
			tint.Saturation = 0
		end
	end

	local function refreshWorld()
		local w = State.World
		if not w then
			return
		end
		local now = State.Now()
		local weather = Weather.Types[w.Weather.Id] or Weather.Types.Clear
		local nextWeather = Weather.Types[w.Weather.NextId] or Weather.Types.Clear
		-- the weather line only shows while there's actual weather (and never on phones)
		weatherText.Visible = weather.Id ~= "Clear" and not Layout.Compact
		if weather.Id == "Clear" then
			weatherText.Text = `Clear skies  ·  {nextWeather.Name} in {Format.Time(w.Weather.NextAt - now)}`
			weatherText.TextColor3 = T.SubText
		else
			weatherText.Text = `{weather.Name}  ·  {weather.Description}  ·  {Format.Time(w.Weather.EndsAt - now)}`
			weatherText.TextColor3 = weather.SkyTint
		end
		local ev = w.Event
		if ev then
			local def = Events.Get(ev.Id)
			local nextDef = Events.Get(ev.NextId)
			if def then
				eventText.Visible = true
				eventText.Text = `{def.Icon} {def.Name}: {def.Description}  ·  {Format.Time(ev.EndsAt - now)} left`
				eventText.TextColor3 = def.Color
			elseif nextDef and not Layout.Compact then
				eventText.Visible = true
				eventText.Text = `{nextDef.Icon} {nextDef.Name} starts in {Format.Time(ev.NextAt - now)}`
				eventText.TextColor3 = T.SubText
			else
				eventText.Visible = false
			end
		end
		local d = State.Data
		local best = 1
		for _, id in Houses.Order do
			best = math.max(best, w.Houses[id] or 0)
		end
		for _, id in Houses.Order do
			local points = w.Houses[id] or 0
			local row = houseRows[id]
			local mine = d and d.House == id
			row.Name.Text = (if mine then "★ " else "") .. string.gsub(Houses.List[id].Name, "House ", "")
			row.Points.Text = Format.Number(points)
			row.Bar.Size = UDim2.fromScale(math.clamp(points / best, 0.03, 1), 1)
		end
		local leftTime = math.max(0, w.HouseWeekEndsAt - now)
		local timeText = if leftTime >= 86400
			then `{leftTime // 86400}d {(leftTime % 86400) // 3600}h`
			else Format.Time(leftTime)
		houseTitle.Text = `House War  ·  {timeText}  {if expanded then "–" else "+"}`
		houseHint.Text = if d and d.House then "Break crystals to earn points" else "Join a House in the hub"
	end

	local wasActive = false
	State.Changed:Connect(function(key)
		if key == "Surge" and State.Surge then
			if State.Surge.Active and not wasActive then
				Sound.Jingle("Surge")
			end
			wasActive = State.Surge.Active
		end
		if key == "Data" then
			refreshStats()
		elseif key == "Surge" then
			refreshSurge()
		elseif key == "World" then
			refreshWorld()
		end
	end)

	task.spawn(function()
		while true do
			refreshStats()
			refreshSurge()
			refreshWorld()
			task.wait(1)
		end
	end)

	-- Gentle pop on the Essence value when it goes up
	local lastEssence = 0
	local pulse = Ui.new("UIScale", { Parent = essenceSeg })
	State.Changed:Connect(function(key)
		local d = State.Data
		if key == "Data" and d then
			if d.Essence > lastEssence then
				pulse.Scale = 1.06
				TweenService:Create(pulse, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
			end
			lastEssence = d.Essence
		end
	end)
end

return Hud
