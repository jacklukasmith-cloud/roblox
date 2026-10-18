--[[
	The 🏆 Leaderboards window: pick a category (Shared/Boards), Global or Friends, see the top 50
	with avatar pictures, and where you stand ("You: #12", or how much more you need to get on).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Boards = require(Shared.Boards)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Sound = require(Modules.Sound)

local T = Ui.Theme

local LeaderboardPanel = {}

local MEDALS = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 215, 230), Color3.fromRGB(215, 140, 80) }
local CACHE_SECONDS = 30

local thumbCache: { [number]: string } = {}
local function thumbnail(userId: number, image: ImageLabel)
	if thumbCache[userId] then
		image.Image = thumbCache[userId]
		return
	end
	task.spawn(function()
		local ok, content = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size48x48
		)
		if ok and content then
			thumbCache[userId] = content
			if image.Parent then
				image.Image = content
			end
		end
	end)
end

function LeaderboardPanel.Build(screen: Frame)
	local player = Players.LocalPlayer
	local _, content = Ui.panel(screen, "Leaderboards", "Leaderboards", UDim2.fromOffset(640, 580), "🏆")

	local boardId = Boards.List[1].Id
	local scope = "Global"
	local cache: { [string]: { Data: any, At: number } } = {}
	local loading = false

	-- category tabs
	local tabs = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 76),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 4, -6, 0, 34),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tabButtons: { [string]: TextButton } = {}
	-- Global / Friends + info line
	local scopeRow = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local scopeButtons: { [string]: TextButton } = {}
	local info = Ui.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -230, 1, 0),
		Text = "",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 15,
		Parent = scopeRow,
	})
	local list = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 1, -172),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = content,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	-- you
	local mine = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 0.35,
		Parent = content,
	}, { Ui.corner(10) })
	local mineText = Ui.text({
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, 0),
		Text = "",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = mine,
	})

	local function row(order: number, entry: any, isMe: boolean)
		local frame = Ui.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 40),
			BackgroundColor3 = if isMe then T.Accent:Lerp(T.Card, 0.5) else T.Card,
			BackgroundTransparency = 0.1,
			Parent = list,
		}, { Ui.corner(8) })
		local medal = MEDALS[entry.Rank]
		Ui.text({
			Position = UDim2.fromOffset(6, 0),
			Size = UDim2.new(0, 46, 1, 0),
			Text = `#{entry.Rank}`,
			Font = T.FontHeavy,
			TextColor3 = medal or T.SubText,
			MaxTextSize = if medal then 20 else 16,
			Parent = frame,
		})
		local avatar = Ui.new("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 56, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = T.GlassLight,
			Image = "",
			Parent = frame,
		}, { Ui.round() })
		if entry.UserId and entry.UserId > 0 then
			thumbnail(entry.UserId, avatar)
		end
		Ui.text({
			Position = UDim2.fromOffset(98, 0),
			Size = UDim2.new(1, -230, 1, 0),
			Text = entry.Name,
			TextColor3 = if isMe then T.Gold else T.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 17,
			Parent = frame,
		})
		Ui.text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0, 130, 1, 0),
			Text = Format.Number(entry.Value),
			Font = T.FontHeavy,
			TextColor3 = medal or T.Text,
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 17,
			Parent = frame,
		})
	end

	local function show(data: any)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local board = Boards.Get(boardId)
		if not data or not board then
			mineText.Text = "Couldn't load this board, try again in a moment"
			return
		end
		for i, entry in data.Rows do
			row(i, entry, entry.UserId == player.UserId)
		end
		if #data.Rows == 0 then
			Ui.text({
				Size = UDim2.new(1, -8, 0, 60),
				Text = if scope == "Friends"
					then "None of your friends are on this board yet. Invite them!"
					else "Nobody's on this board yet. Be the first!",
				Font = T.FontRegular,
				TextColor3 = T.SubText,
				TextWrapped = true,
				MaxTextSize = 17,
				Parent = list,
			})
		end
		local me = data.Me
		if me.Rank then
			mineText.Text = `You: #{me.Rank}  ·  {Format.Number(me.Value)}`
		elseif me.Need then
			mineText.Text = `You: {Format.Number(me.Value)}  ·  {Format.Number(me.Need)} more to get on the top 50!`
		else
			mineText.Text = `You: {Format.Number(me.Value)}`
		end
		info.Text = if data.Weekly and data.EndsAt
			then `Resets in {Format.Time(math.max(0, data.EndsAt - State.Now()))}`
			else "All-time"
	end

	local function load(force: boolean?)
		local key = `{boardId}:{scope}`
		local cached = cache[key]
		for id, button in tabButtons do
			button.BackgroundColor3 = if id == boardId then T.Accent else T.GlassLight
		end
		for id, button in scopeButtons do
			button.BackgroundColor3 = if id == scope then T.Accent else T.GlassLight
		end
		if cached and not force and os.clock() - cached.At < CACHE_SECONDS then
			show(cached.Data)
			return
		end
		if loading then
			return
		end
		loading = true
		mineText.Text = "Loading..."
		local wantKey = key
		task.spawn(function()
			local ok, data = pcall(function()
				return Remotes.Function("GetBoard"):InvokeServer(boardId, scope)
			end)
			loading = false
			if ok and data then
				cache[wantKey] = { Data = data, At = os.clock() }
			end
			-- only draw it if they're still looking at the same board
			if wantKey == `{boardId}:{scope}` then
				show(if ok then data else nil)
			else
				load()
			end
		end)
	end

	for i, board in Boards.List do
		tabButtons[board.Id] = Ui.button({
			LayoutOrder = i,
			Text = `{board.Icon} {board.Name}`,
			Variant = "Secondary",
			Parent = tabs,
		}, function()
			boardId = board.Id
			Sound.Play("Click", 1.2)
			load()
		end)
	end
	for i, s in { "Global", "Friends" } do
		scopeButtons[s] = Ui.button({
			Position = UDim2.fromOffset((i - 1) * 112, 0),
			Size = UDim2.fromOffset(104, 32),
			Text = if s == "Global" then "🌍 Global" else "👥 Friends",
			Variant = "Secondary",
			Parent = scopeRow,
		}, function()
			scope = s
			Sound.Play("Click", 1.2)
			load()
		end)
	end

	Ui.onPanelOpen("Leaderboards", function()
		load()
	end)
end

return LeaderboardPanel
