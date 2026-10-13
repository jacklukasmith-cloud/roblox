--[[
	Always-on HUD: currency pills (top-left), Mana Surge banner + weather (top-centre),
	House War card (right side, collapsible). Everything re-arranges for phones via Layout.
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

-- A rounded "pill" with a coloured icon bubble on the left and a value on the right.
local function pill(parent: Instance, order: number, icon: string, color: Color3, width: number, height: number)
	local frame = Ui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.2,
		Parent = parent,
	}, { Ui.round(), Ui.stroke(T.Outline, 2.5) })
	local bubble = Ui.new("Frame", {
		Size = UDim2.fromOffset(height + 4, height + 4),
		Position = UDim2.fromOffset(-4, -2),
		BackgroundColor3 = color,
		Parent = frame,
	}, { Ui.round(), Ui.stroke(T.Outline, 2.5), Ui.gloss(0.35) })
	Ui.text({ Text = icon, Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), Parent = bubble })
	local value = Ui.text({
		Text = "0",
		TextColor3 = color,
		Size = UDim2.new(1, -(height + 14), 0.78, 0),
		Position = UDim2.new(0, height + 8, 0.11, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	return frame, value, bubble
end

function Hud.Build(root: Frame)
	-- Bottom-centre bar: boosts, multipliers and currency (free space on every device) -----
	local bottom = Ui.new("Frame", {
		Name = "BottomBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(620, 110),
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
	local currency = Ui.new("Frame", {
		Name = "Currency",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(620, 46),
		BackgroundTransparency = 1,
		Parent = bottom,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local essencePill, essenceValue = pill(currency, 1, "💎", T.Essence, 250, 46)
	local plus = Ui.button({
		Text = "+",
		Size = UDim2.fromOffset(34, 34),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		BackgroundColor3 = T.Good,
		Parent = essencePill,
	}, function()
		Ui.toggle("Shop", true) -- Pet Sim style: tap + to buy more
	end)
	local trophyPill, trophyValue = pill(currency, 2, "🏆", T.Trophy, 200, 40)
	local powerPill, powerValue = pill(currency, 3, "💪", T.Power, 200, 40)
	local multLabel = Ui.text({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(400, 18),
		TextColor3 = T.Gold,
		Text = "",
		MaxTextSize = 18,
		Parent = bottom,
	})
	local boostRow = Ui.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(500, 26),
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

	-- Surge banner + weather (top-centre) --------------------------------------------
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
	local banner = Ui.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(440, 50),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.15,
		Parent = top,
	}, { Ui.round(), Ui.stroke(T.Outline, 2.5) })
	local bannerStroke = Ui.new("UIStroke", { Color = T.Accent, Thickness = 2, Parent = banner })
	bannerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local bannerText =
		Ui.text({ Size = UDim2.new(1, -28, 1, -12), Position = UDim2.fromOffset(14, 6), Text = "", Parent = banner })
	local weatherPill = Ui.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(380, 28),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.35,
		Parent = top,
	}, { Ui.round() })
	local weatherText = Ui.text({
		Size = UDim2.new(1, -20, 1, -6),
		Position = UDim2.fromOffset(10, 3),
		Text = "",
		TextColor3 = T.SubText,
		MaxTextSize = 18,
		Parent = weatherPill,
	})
	local topList = Ui.new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(300, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = top,
	}, { Ui.corner(14), Ui.padding(6), Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
	local topRows = {}
	for i = 1, 5 do
		topRows[i] =
			Ui.text({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 24), Text = "", MaxTextSize = 20, Parent = topList })
	end

	-- House War card (right side, collapsible) --------------------------------------
	local house = Ui.new("Frame", {
		Name = "House",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.42, 0),
		Size = UDim2.fromOffset(230, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.2,
		Parent = root,
	}, {
		Ui.corner(14),
		Ui.stroke(T.Outline, 2.5),
		Ui.padding(6),
		Ui.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local expanded = true
	local houseHeader = Ui.new("TextButton", {
		LayoutOrder = 0,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = house,
	})
	local houseTitle = Ui.text({
		Size = UDim2.fromScale(1, 1),
		Text = "House War",
		TextColor3 = T.Gold,
		MaxTextSize = 20,
		Parent = houseHeader,
	})
	local houseRows: { [string]: { Frame: Frame, Bar: Frame, Label: TextLabel } } = {}
	for i, id in Houses.Order do
		local h = Houses.List[id]
		local row = Ui.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = T.Panel,
			Parent = house,
		}, { Ui.round() })
		local bar = Ui.new(
			"Frame",
			{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = h.Color, Parent = row },
			{ Ui.round(), Ui.gloss(0.3) }
		)
		local label = Ui.text({
			Size = UDim2.new(1, -12, 1, -4),
			Position = UDim2.fromOffset(8, 2),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 17,
			Parent = row,
		})
		houseRows[id] = { Frame = row, Bar = bar, Label = label }
	end
	local houseHint = Ui.text({
		LayoutOrder = 9,
		Size = UDim2.new(1, 0, 0, 16),
		TextColor3 = T.SubText,
		Text = "",
		MaxTextSize = 14,
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

	-- Surge screen tint
	local tint = Ui.new("ColorCorrectionEffect", { Name = "SurgeTint", Parent = Lighting })

	-- Responsive arrangement ------------------------------------------------------------
	local function arrange()
		local c = Layout.Compact
		essencePill.Size = UDim2.fromOffset(if c then 176 else 230, if c then 36 else 44)
		trophyPill.Size = UDim2.fromOffset(if c then 112 else 150, if c then 32 else 40)
		powerPill.Size = UDim2.fromOffset(if c then 124 else 160, if c then 32 else 40)
		plus.Size = UDim2.fromOffset(if c then 28 else 34, if c then 28 else 34)
		currency.Size = UDim2.fromOffset(if c then 440 else 600, if c then 40 else 46)
		multLabel.Visible = not c
		bottom.Position = UDim2.new(0.5, 0, 1, if c then -6 else -12)
		top.Position = UDim2.new(0.5, 0, 0, if c then 4 else 8)
		banner.Size = UDim2.fromOffset(if c then 340 else 440, if c then 40 else 50)
		weatherPill.Size = UDim2.fromOffset(if c then 320 else 380, if c then 22 else 28)
		topList.Size = UDim2.fromOffset(if c then 240 else 300, 20)
		house.Size = UDim2.fromOffset(if c then 190 else 230, 40)
		house.Position = UDim2.new(1, if c then -8 else -12, if c then 0.3 else 0.5, 0)
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
			`Essence x{math.floor(d.EssenceMultiplier * 100) / 100}   Luck x{math.floor(d.Luck * 100) / 100}`
		local now = State.Now()
		local seen = {}
		for name, endsAt in d.Boosts do
			if endsAt > now then
				seen[name] = true
				local chip = boostChips[name]
				if not chip then
					local frame = Ui.new("Frame", {
						Size = UDim2.fromOffset(Layout.pick(92, 104), 26),
						BackgroundColor3 = T.Good,
						Parent = boostRow,
					}, { Ui.round(), Ui.stroke(T.Outline, 2), Ui.gloss(0.3) })
					chip = Ui.text({
						Size = UDim2.new(1, -10, 1, -4),
						Position = UDim2.fromOffset(5, 2),
						MaxTextSize = 16,
						Parent = frame,
					})
					boostChips[name] = chip
				end
				chip.Text = `{name} {Format.Time(endsAt - now)}`
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
			local rank = if s.MyRank then `#{s.MyRank}` else "-"
			bannerText.Text = `⚡ MANA SURGE {left}  ·  You {Format.Number(s.MyScore)} ({rank})`
			bannerText.TextColor3 = Color3.fromRGB(235, 185, 255)
			bannerStroke.Color = Color3.fromRGB(210, 120, 255)
			topList.Visible = #s.Top > 0
			for i = 1, 5 do
				local entry = s.Top[i]
				topRows[i].Text = if entry then `{i}. {entry.Name}  {Format.Number(entry.Score)}` else ""
				topRows[i].Visible = entry ~= nil
				topRows[i].TextColor3 = if entry
						and entry.House
						and Houses.List[entry.House]
					then Houses.List[entry.House].Color
					else T.Text
			end
			tint.TintColor = Color3.fromRGB(235, 215, 255)
			tint.Saturation = 0.25
		else
			bannerText.Text = `🔮 Mana Surge in {left}`
			bannerText.TextColor3 = T.Text
			bannerStroke.Color = T.Accent
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
			weatherText.Text = `Clear skies · {nextWeather.Name} in {Format.Time(w.Weather.NextAt - now)}`
			weatherText.TextColor3 = T.SubText
		else
			weatherText.Text = `{weather.Name}: {weather.Description} ({Format.Time(w.Weather.EndsAt - now)})`
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
			row.Label.Text =
				`{if mine then "★ " else ""}{string.gsub(Houses.List[id].Name, "House ", "")}  {Format.Number(points)}`
			row.Bar.Size = UDim2.fromScale(math.clamp(points / best, 0.04, 1), 1)
		end
		local left = math.max(0, w.HouseWeekEndsAt - now)
		local timeText = if left >= 86400 then `{left // 86400}d {(left % 86400) // 3600}h` else Format.Time(left)
		houseTitle.Text = `🏰 House War  {timeText}  {if expanded then "▲" else "▼"}`
		houseHint.Text = if d and d.House then "Break crystals to earn points!" else "Join a House in the hub!"
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

	-- Bounce the Essence pill when Essence goes up
	local lastEssence = 0
	local pulse = Ui.new("UIScale", { Parent = essencePill })
	State.Changed:Connect(function(key)
		local d = State.Data
		if key == "Data" and d then
			if d.Essence > lastEssence then
				pulse.Scale = 1.07
				TweenService:Create(pulse, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
			lastEssence = d.Essence
		end
	end)
end

return Hud
