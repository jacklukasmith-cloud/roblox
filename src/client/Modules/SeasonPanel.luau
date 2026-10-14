--[[
	Weekly Season panel: countdown, your points and rank, the rewards for each tier, this
	week's top 10 and the titles you've won (tap one to show it above your head).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Season = require(Shared.Season)
local Creatures = require(Shared.Creatures)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)

local T = Ui.Theme
local ACCENT = Color3.fromRGB(255, 120, 90)

local SeasonPanel = {}

local function invoke(name: string, ...)
	local ok, success, message = pcall(function(...)
		return Remotes.Function(name):InvokeServer(...)
	end, ...)
	if not ok then
		Ui.toast("Something went wrong, try again", T.Bad)
	elseif message then
		Ui.toast(message, if success then T.Good else T.Bad)
	end
end

function SeasonPanel.Build(screen: Frame)
	local _, content = Ui.panel(screen, "Season", "Weekly Season", UDim2.fromOffset(680, 600), "🏅")
	local list = Ui.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = content,
	})
	Ui.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	Ui.new("UIPadding", { PaddingBottom = UDim.new(0, 8), Parent = list })

	-- Header: season number + countdown, your standing
	local header = Ui.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 0.82,
		Parent = list,
	}, { Ui.corner(12), Ui.stroke(ACCENT, 1.4, 0.4) })
	local seasonTitle = Ui.text({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.6, 0, 0, 24),
		Text = "",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = header,
	})
	local countdown = Ui.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.new(0.4, 0, 0, 24),
		Text = "",
		Font = T.Font,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 16,
		Parent = header,
	})
	local standing = Ui.text({
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "",
		Font = T.Font,
		TextColor3 = Color3.fromRGB(255, 220, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = header,
	})

	-- Reward tiers
	Ui.text({
		LayoutOrder = 2,
		Size = UDim2.new(1, -8, 0, 22),
		Text = "🎁 End-of-season rewards (Season Points from crystals, chests & bosses)",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = list,
	})
	local tiersRow = Ui.new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, -8, 0, 96),
		BackgroundTransparency = 1,
		Parent = list,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})
	local previous = 0
	for _, tier in Season.Tiers do
		local card = Ui.new("Frame", {
			Size = UDim2.new(1 / #Season.Tiers, -6, 1, 0),
			BackgroundColor3 = T.Card,
			BackgroundTransparency = 0.15,
			Parent = tiersRow,
		}, { Ui.corner(10), Ui.stroke(tier.Color, 1.5, 0.3) })
		Ui.text({
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 18),
			Text = if previous == 0 then `Top {tier.MaxRank}` else `#{previous + 1}-{tier.MaxRank}`,
			Font = T.FontHeavy,
			TextColor3 = tier.Color,
			MaxTextSize = 16,
			Parent = card,
		})
		Ui.text({
			Position = UDim2.fromOffset(6, 28),
			Size = UDim2.new(1, -12, 0, 18),
			Text = `"{tier.Title}"`,
			Font = T.Font,
			MaxTextSize = 14,
			Parent = card,
		})
		local reward = `🏆 {tier.Trophies} Trophies`
		if tier.Creature then
			reward = `{Creatures.DisplayName(tier.Creature.Id, tier.Creature.Variant)}\n` .. reward
		end
		Ui.text({
			Position = UDim2.fromOffset(6, 50),
			Size = UDim2.new(1, -12, 0, 38),
			Text = reward,
			Font = T.FontRegular,
			TextColor3 = T.SubText,
			TextWrapped = true,
			MaxTextSize = 13,
			Parent = card,
		})
		previous = tier.MaxRank
	end

	-- Top 10
	Ui.text({
		LayoutOrder = 4,
		Size = UDim2.new(1, -8, 0, 22),
		Text = "📊 This week's top 10",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = list,
	})
	local board = Ui.new("Frame", {
		LayoutOrder = 5,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Card,
		BackgroundTransparency = 0.25,
		Parent = list,
	}, {
		Ui.corner(10),
		Ui.padding(8),
		Ui.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local rows: { TextLabel } = {}
	for i = 1, 10 do
		rows[i] = Ui.text({
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 20),
			Text = "",
			Font = T.Font,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 15,
			Parent = board,
		})
	end

	-- Titles you own
	local titlesHeader = Ui.text({
		LayoutOrder = 6,
		Size = UDim2.new(1, -8, 0, 22),
		Text = "👑 Your titles (tap to show above your head)",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = list,
	})
	local titlesRow = Ui.new("Frame", {
		LayoutOrder = 7,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = list,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local titlesKey = ""

	local function render()
		local d = State.Data
		local s = d and d.Season
		if not s then
			return
		end
		seasonTitle.Text = `Season {s.Number}`
		local left = math.max(0, s.EndsAt - State.Now())
		countdown.Text = if left >= 86400
			then `Ends in {left // 86400}d {(left % 86400) // 3600}h`
			else `Ends in {Format.Time(left)}`
		standing.Text = if s.Rank
			then `Your points: {Format.Number(s.Points)}  ·  Rank #{s.Rank}`
			else `Your points: {Format.Number(s.Points)}  ·  Not in the top 100 yet`
		for i, row in rows do
			local entry = s.Top[i]
			row.Visible = entry ~= nil or i == 1
			row.Text = if entry
				then `#{i}  {entry.Name}  -  {Format.Number(entry.Points)}`
				else (if i == 1 then "No scores yet this week - be the first!" else "")
			row.TextColor3 = if i == 1 then Color3.fromRGB(255, 210, 80) elseif i <= 3 then T.Text else T.SubText
		end
		-- titles (rebuild only when they change)
		local key = table.concat(s.Titles or {}, "|") .. "#" .. (s.Title or "")
		if key ~= titlesKey then
			titlesKey = key
			for _, child in titlesRow:GetChildren() do
				if child:IsA("TextButton") then
					child:Destroy()
				end
			end
			local owned = s.Titles or {}
			titlesHeader.Visible = #owned > 0
			titlesRow.Visible = #owned > 0
			local options = table.clone(owned)
			table.insert(options, "")
			for i, title in options do
				local equipped = title == (s.Title or "")
				Ui.button({
					LayoutOrder = i,
					Text = if title == "" then "No title" else title,
					Variant = if equipped then "Success" else "Secondary",
					Size = UDim2.fromOffset(190, 34),
					Parent = titlesRow,
				}, function()
					if not equipped then
						invoke("EquipTitle", title)
					end
				end)
			end
		end
	end

	Ui.onPanelOpen("Season", render)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Season") then
			render()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if Ui.isOpen("Season") then
				render()
			end
		end
	end)
end

return SeasonPanel
