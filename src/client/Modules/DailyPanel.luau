--[[
	Daily panel: 7-day login streak and today's quests.
	Opens by itself when you join with a reward waiting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Daily = require(Shared.Daily)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Layout = require(Modules.Layout)

local T = Ui.Theme
local GOLD = T.Gold

local DailyPanel = {}

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

local function sectionTitle(parent: Instance, order: number, text: string): (Frame, TextLabel)
	local row = Ui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 26),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Ui.text({
		Size = UDim2.new(0.6, 0, 1, 0),
		Text = text,
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = row,
	})
	local right = Ui.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		Text = "",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 15,
		Parent = row,
	})
	return row, right
end

local function rewardText(rewards: { Daily.Reward }): (string, string)
	local icons, texts = {}, {}
	for _, r in rewards do
		table.insert(icons, r.Icon)
		table.insert(texts, r.Text)
	end
	return table.concat(icons, ""), table.concat(texts, " + ")
end

function DailyPanel.Build(screen: Frame)
	local _, content = Ui.panel(screen, "Daily", "Daily Rewards", UDim2.fromOffset(680, 620), "🎁")
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
	Ui.new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8), Parent = list })

	-- Login streak ----------------------------------------------------------------------
	local _, streakInfo = sectionTitle(list, 1, "🔥 Login Streak")
	local daysRow = Ui.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, -8, 0, 112),
		BackgroundTransparency = 1,
		Parent = list,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	type DayTile =
		{ Frame: Frame, Stroke: UIStroke, Day: TextLabel, Icon: TextLabel, Label: TextLabel, Check: TextLabel }
	local tiles: { DayTile } = {}
	for day, rewards in Daily.StreakRewards do
		local big = day == #Daily.StreakRewards
		local frame = Ui.new("Frame", {
			LayoutOrder = day,
			Size = UDim2.new(1 / #Daily.StreakRewards, -6, 1, 0),
			BackgroundColor3 = T.Card,
			BackgroundTransparency = 0.15,
			Parent = daysRow,
		}, { Ui.corner(10) })
		local stroke = Ui.stroke(nil, 1.4)
		stroke.Parent = frame
		local icons, label = rewardText(rewards)
		local dayLabel = Ui.text({
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 16),
			Text = `Day {day}`,
			Font = T.FontHeavy,
			TextColor3 = if big then GOLD else T.SubText,
			MaxTextSize = 14,
			Parent = frame,
		})
		local icon = Ui.text({
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, 0, 0, 40),
			Text = icons,
			MaxTextSize = if big then 32 else 30,
			Parent = frame,
		})
		local labelText = Ui.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -8, 0, 30),
			Text = label,
			Font = T.FontRegular,
			TextWrapped = true,
			TextColor3 = T.SubText,
			MaxTextSize = 12,
			Parent = frame,
		})
		local check = Ui.text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(18, 18),
			Text = "✓",
			Font = T.FontHeavy,
			TextColor3 = T.Good,
			Visible = false,
			MaxTextSize = 16,
			Parent = frame,
		})
		tiles[day] = { Frame = frame, Stroke = stroke, Day = dayLabel, Icon = icon, Label = labelText, Check = check }
	end
	local claimButton = Ui.button({
		LayoutOrder = 3,
		Text = "Claim",
		Variant = "Success",
		Size = UDim2.fromOffset(280, 46),
	}, function()
		local d = State.Data
		if d and d.Daily and d.Daily.CanClaim then
			invoke("ClaimDaily")
		end
	end)
	claimButton.Parent = list
	local streakHint = Ui.text({
		LayoutOrder = 4,
		Size = UDim2.new(1, -8, 0, 18),
		Text = "",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		MaxTextSize = 14,
		Parent = list,
	})

	-- Quests ------------------------------------------------------------------------------
	local _, questTimer = sectionTitle(list, 10, "📜 Daily Quests")
	type QuestRow =
		{ Frame: Frame, Title: TextLabel, Fill: Frame, Count: TextLabel, Button: TextButton, Done: TextLabel }
	local rows: { QuestRow } = {}
	local claimKeys: { [number]: string } = {}
	for i = 1, Daily.QuestsPerDay do
		local frame = Ui.new("Frame", {
			LayoutOrder = 10 + i,
			Size = UDim2.new(1, -8, 0, 58),
			BackgroundColor3 = T.Card,
			BackgroundTransparency = 0.15,
			Parent = list,
		}, { Ui.corner(10), Ui.stroke(nil, 1.2) })
		local title = Ui.text({
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -170, 0, 22),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			Parent = frame,
		})
		local back = Ui.new("Frame", {
			Position = UDim2.fromOffset(14, 34),
			Size = UDim2.new(1, -240, 0, 12),
			BackgroundColor3 = T.Background,
			Parent = frame,
		}, { Ui.round() })
		local fill = Ui.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = T.Accent,
			Parent = back,
		}, { Ui.round() })
		local count = Ui.text({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1, -218, 0, 40),
			Size = UDim2.fromOffset(60, 16),
			Text = "",
			Font = T.FontRegular,
			TextColor3 = T.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 14,
			Parent = frame,
		})
		local button = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(140, 40),
			Text = "Claim",
			Variant = "Success",
			Parent = frame,
		}, function()
			if claimKeys[i] then
				invoke("ClaimQuest", claimKeys[i])
			end
		end)
		local done = Ui.text({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(140, 24),
			Text = "",
			Font = T.Font,
			TextColor3 = T.SubText,
			MaxTextSize = 15,
			Parent = frame,
		})
		rows[i] = { Frame = frame, Title = title, Fill = fill, Count = count, Button = button, Done = done }
	end
	-- Bonus for finishing every quest
	local bonus = Ui.new("Frame", {
		LayoutOrder = 20,
		Size = UDim2.new(1, -8, 0, 58),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.85,
		Parent = list,
	}, { Ui.corner(10), Ui.stroke(GOLD, 1.4, 0.4) })
	Ui.text({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -170, 0, 22),
		Text = "🎁 Finish all of today's quests",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		MaxTextSize = 18,
		Parent = bonus,
	})
	Ui.text({
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -170, 0, 18),
		Text = `Bonus: {Daily.BonusReward.Icon} {Daily.BonusReward.Text}`,
		Font = T.FontRegular,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.SubText,
		MaxTextSize = 14,
		Parent = bonus,
	})
	local bonusButton = Ui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(140, 40),
		Text = "Claim",
		Variant = "Gold",
		Parent = bonus,
	}, function()
		invoke("ClaimQuest", "Bonus")
	end)
	local bonusDone = Ui.text({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(140, 24),
		Text = "",
		Font = T.Font,
		TextColor3 = T.SubText,
		MaxTextSize = 15,
		Parent = bonus,
	})

	local function render()
		local d = State.Data
		local info = d and d.Daily
		if not info then
			return
		end
		local left = Format.Time(math.max(0, info.NextReset - State.Now()))
		-- streak tiles
		for day, tile in tiles do
			local isToday = day == info.CycleDay
			local past = day < info.CycleDay or (isToday and not info.CanClaim)
			tile.Check.Visible = past
			tile.Frame.BackgroundTransparency = if past then 0.5 else 0.15
			tile.Icon.TextTransparency = if past then 0.5 else 0
			if isToday and info.CanClaim then
				tile.Stroke.Color = GOLD
				tile.Stroke.Thickness = 2.5
				tile.Stroke.Transparency = 0
				tile.Frame.BackgroundColor3 = GOLD:Lerp(T.Card, 0.75)
			elseif past then
				tile.Stroke.Color = T.Good
				tile.Stroke.Thickness = 1.4
				tile.Stroke.Transparency = 0.4
				tile.Frame.BackgroundColor3 = T.Card
			else
				tile.Stroke.Color = T.Edge
				tile.Stroke.Thickness = 1.4
				tile.Stroke.Transparency = 0.86
				tile.Frame.BackgroundColor3 = T.Card
			end
		end
		streakInfo.Text = `Streak: {info.Streak} day{if info.Streak == 1 then "" else "s"}`
		if info.CanClaim then
			claimButton.Text = `Claim Day {info.CycleDay} reward`
			claimButton.BackgroundColor3 = T.Good
			claimButton.AutoButtonColor = false
			streakHint.Text = if info.StreakLost
				then "You missed a day, so your streak started over. Keep it going!"
				else "Come back every day. Miss a day and the streak starts over."
		else
			claimButton.Text = `Next reward in {left}`
			claimButton.BackgroundColor3 = T.GlassLight
			streakHint.Text = "Claimed today ✓  Come back tomorrow for the next day."
		end

		-- quests
		questTimer.Text = `New quests in {left}`
		local allClaimed = true
		for i, row in rows do
			local q = info.Quests[i]
			local def = q and Daily.GetQuest(q.Key)
			row.Frame.Visible = def ~= nil
			if not def then
				continue
			end
			claimKeys[i] = q.Key
			local done = q.Progress >= def.Goal
			row.Title.Text = def.Text
			row.Fill.Size = UDim2.fromScale(math.clamp(q.Progress / def.Goal, 0, 1), 1)
			row.Fill.BackgroundColor3 = if done then T.Good else T.Accent
			row.Count.Text = `{Format.Number(q.Progress)}/{Format.Number(def.Goal)}`
			row.Button.Visible = done and not q.Claimed
			row.Done.Visible = not row.Button.Visible
			row.Done.Text = if q.Claimed then "✓ Claimed" else `{Daily.QuestReward.Icon} {Daily.QuestReward.Text}`
			row.Done.TextColor3 = if q.Claimed then T.Good else T.SubText
			if not q.Claimed then
				allClaimed = false
			end
		end
		bonusButton.Visible = allClaimed and not info.BonusClaimed
		bonusDone.Visible = not bonusButton.Visible
		local claimedCount = 0
		for _, q in info.Quests do
			if q.Claimed then
				claimedCount += 1
			end
		end
		bonusDone.Text = if info.BonusClaimed then "✓ Claimed" else `{claimedCount}/{#info.Quests} claimed`
		bonusDone.TextColor3 = if info.BonusClaimed then T.Good else T.SubText
	end

	local function arrange()
		daysRow.Size = UDim2.new(1, -8, 0, if Layout.Compact then 96 else 104)
	end
	Layout.Changed:Connect(arrange)
	arrange()

	Ui.onPanelOpen("Daily", render)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Daily") then
			render()
		end
	end)
	-- countdowns tick while the panel is open
	task.spawn(function()
		while true do
			task.wait(1)
			if Ui.isOpen("Daily") then
				render()
			end
		end
	end)

	-- Open by itself once per session when a streak reward is waiting
	local shown = false
	State.Changed:Connect(function(key)
		local d = State.Data
		if shown or key ~= "Data" or not d or not d.Daily then
			return
		end
		shown = true
		if d.Daily.CanClaim then
			task.delay(2.5, function()
				if not Ui.openPanel() then
					Ui.toggle("Daily", true)
				end
			end)
		end
	end)
end

return DailyPanel
