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

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Weather = require(Shared.Weather)
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
	local essenceSeg, essenceValue = segment(bar, 1, "💎", "Essence", T.Essence)
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
		Position = UDim2.new(0.5, 0, 0, 8),
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
	local banner = Ui.glass({ LayoutOrder = 1, Size = UDim2.fromOffset(420, 44), Parent = top }, { Ui.round() })
	local bannerDot = Ui.new("Frame", {
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		BackgroundColor3 = T.Accent,
		Parent = banner,
	}, { Ui.round() })
	local bannerText = Ui.text({
		Size = UDim2.new(1, -56, 1, -14),
		Position = UDim2.fromOffset(38, 7),
		Text = "",
		MaxTextSize = 22,
		Parent = banner,
	})
	local weatherText = Ui.text({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(420, 18),
		Font = T.FontRegular,
		Text = "",
		TextColor3 = T.SubText,
		MaxTextSize = 15,
		Parent = top,
	})
	local topList = Ui.glass({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(280, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
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
			Size = UDim2.new(1, 0, 0, 22),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
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
	local expanded = true
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
		setExpanded(not expanded)
	end)

	local tint = Ui.new("ColorCorrectionEffect", { Name = "SurgeTint", Parent = Lighting })

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
		multLabel.Visible = not c
		bottom.Position = UDim2.new(0.5, 0, 1, if c then -6 else -14)
		top.Position = UDim2.new(0.5, 0, 0, if c then 4 else 10)
		banner.Size = UDim2.fromOffset(if c then 330 else 420, if c then 38 else 44)
		weatherText.Visible = true
		weatherText.Size = UDim2.fromOffset(if c then 330 else 420, if c then 14 else 18)
		topList.Size = UDim2.fromOffset(if c then 220 else 280, 20)
		house.Size = UDim2.fromOffset(if c then 190 else 230, 40)
		house.Position = UDim2.new(1, if c then -8 else -14, if c then 0.3 else 0.5, 0)
		setExpanded(not c) -- phones start collapsed; tap the header to open
	end
	Layout.Changed:Connect(arrange)
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
		for name, chip in boostChips do
			if not seen[name] then
				(chip.Parent :: Instance):Destroy()
				boostChips[name] = nil
			end
		end
	end

	local function refreshSurge()
		local s = State.Surge
		if not s then
			bannerText.Text = "Mana Surge"
			return
		end
		local left = Format.Time(s.EndsAt - State.Now())
		if s.Active then
			local rank = if s.MyRank then `#{s.MyRank}` else "–"
			bannerText.Text = `MANA SURGE  {left}   ·   You {Format.Number(s.MyScore)} ({rank})`
			bannerText.TextColor3 = Color3.fromRGB(226, 200, 255)
			bannerDot.BackgroundColor3 = Color3.fromRGB(200, 120, 255)
			topList.Visible = #s.Top > 0
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
			bannerText.Text = `Next Mana Surge in {left}`
			bannerText.TextColor3 = T.Text
			bannerDot.BackgroundColor3 = T.Accent
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
		if weather.Id == "Clear" then
			weatherText.Text = `Clear skies  ·  {nextWeather.Name} in {Format.Time(w.Weather.NextAt - now)}`
			weatherText.TextColor3 = T.SubText
		else
			weatherText.Text = `{weather.Name}  ·  {weather.Description}  ·  {Format.Time(w.Weather.EndsAt - now)}`
			weatherText.TextColor3 = weather.SkyTint
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
