--[[ Always-on screen elements: stats, menu buttons, surge banner, weather, house widget. ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Weather = require(Shared.Weather)
local Houses = require(Shared.Houses)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local Hud = {}

local T = Ui.Theme

function Hud.Build(screen: ScreenGui)
	-- Stats (top-left) -------------------------------------------------------------
	local stats = Ui.new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(230, 150),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.2,
		Parent = screen,
	}, {
		Ui.corner(12),
		Ui.stroke(T.Accent, 2),
		Ui.padding(8),
		Ui.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function statLine(order: number, color: Color3, height: number?): TextLabel
		return Ui.text({
			LayoutOrder = order,
			TextColor3 = color,
			Size = UDim2.new(1, 0, 0, height or 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = stats,
		})
	end
	local essenceLabel = statLine(1, T.Essence, 30)
	local trophyLabel = statLine(2, T.Trophy)
	local powerLabel = statLine(3, Color3.fromRGB(255, 160, 120))
	local multLabel = statLine(4, T.Gold, 18)
	local boostLabel = statLine(5, T.Good, 18)

	-- Surge banner (top centre) --------------------------------------------------
	local banner = Ui.new("Frame", {
		Name = "Surge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(420, 44),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.2,
		Parent = screen,
	}, { Ui.corner(12), Ui.stroke(T.Accent, 2) })
	local bannerText =
		Ui.text({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Text = "", Parent = banner })
	local topList = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(300, 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	}, { Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
	local topRows = {}
	for i = 1, 5 do
		topRows[i] = Ui.text({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 22), Text = "", Parent = topList })
	end

	-- Weather (under the banner) ----------------------------------------------------
	local weatherLabel = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(460, 22),
		Text = "",
		Parent = screen,
	})

	-- House widget (top-right) -----------------------------------------------------
	local houseFrame = Ui.new("Frame", {
		Name = "House",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 60),
		Size = UDim2.fromOffset(220, 120),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.2,
		Parent = screen,
	}, {
		Ui.corner(12),
		Ui.stroke(T.Gold, 2),
		Ui.padding(8),
		Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local houseTitle = Ui.text({ LayoutOrder = 0, Text = "House War", TextColor3 = T.Gold, Parent = houseFrame })
	local houseRows = {}
	for i, id in Houses.Order do
		houseRows[id] = Ui.text({
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 20),
			TextColor3 = Houses.List[id].Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = houseFrame,
		})
	end
	local houseHint = Ui.text({
		LayoutOrder = 9,
		Size = UDim2.new(1, 0, 0, 16),
		TextColor3 = T.SubText,
		Text = "",
		Parent = houseFrame,
	})

	-- Surge screen tint
	local tint = Ui.new("ColorCorrectionEffect", { Name = "SurgeTint", Parent = Lighting })

	-- Updaters ----------------------------------------------------------------------
	local function refreshStats()
		local d = State.Data
		if not d then
			return
		end
		essenceLabel.Text = "Essence: " .. Format.Number(d.Essence)
		trophyLabel.Text = "Trophies: " .. Format.Number(d.Trophies)
		powerLabel.Text = "Power: " .. Format.Number(d.Power)
		multLabel.Text =
			`Essence x{math.floor(d.EssenceMultiplier * 100) / 100}  |  Luck x{math.floor(d.Luck * 100) / 100}`
		local active = {}
		local now = State.Now()
		for name, endsAt in d.Boosts do
			if endsAt > now then
				table.insert(active, `{name} {Format.Time(endsAt - now)}`)
			end
		end
		boostLabel.Text = if #active > 0 then "Boosts: " .. table.concat(active, ", ") else ""
	end

	local function refreshSurge()
		local s = State.Surge
		if not s then
			bannerText.Text = "Mana Surge loading..."
			return
		end
		local left = Format.Time(s.EndsAt - State.Now())
		if s.Active then
			local rank = if s.MyRank then `#{s.MyRank}` else "-"
			bannerText.Text = `MANA SURGE! {left}  |  You: {Format.Number(s.MyScore)} ({rank})`
			bannerText.TextColor3 = Color3.fromRGB(230, 170, 255)
			topList.Visible = true
			for i = 1, 5 do
				local entry = s.Top[i]
				topRows[i].Text = if entry then `{i}. {entry.Name} - {Format.Number(entry.Score)}` else ""
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
			weatherLabel.Text = `Clear skies  -  next: {nextWeather.Name} in {Format.Time(w.Weather.NextAt - now)}`
			weatherLabel.TextColor3 = T.SubText
		else
			weatherLabel.Text = `{weather.Name}: {weather.Description} ({Format.Time(w.Weather.EndsAt - now)})`
			weatherLabel.TextColor3 = weather.SkyTint
		end
		local d = State.Data
		for _, id in Houses.Order do
			local mine = d and d.House == id
			houseRows[id].Text = `{if mine then "> " else ""}{Houses.List[id].Name}: {Format.Number(w.Houses[id] or 0)}`
		end
		houseTitle.Text = "House War  " .. Format.Time(w.HouseWeekEndsAt - now)
		houseHint.Text = if d and d.House then "Break crystals to earn points!" else "Join a House at the hub!"
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

	-- Countdowns tick every second even without new data
	task.spawn(function()
		while true do
			refreshStats()
			refreshSurge()
			refreshWorld()
			task.wait(1)
		end
	end)

	-- Pulse the essence counter when it goes up
	local lastEssence = 0
	State.Changed:Connect(function(key)
		if key == "Data" and State.Data and State.Data.Essence > lastEssence then
			local scale = essenceLabel:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = essenceLabel })
			scale.Scale = 1.08
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 1 }):Play()
		end
		if key == "Data" and State.Data then
			lastEssence = State.Data.Essence
		end
	end)
end

return Hud
