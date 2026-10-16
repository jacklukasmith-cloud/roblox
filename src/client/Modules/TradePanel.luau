--[[
	The 🤝 Trade window (server rules are in Services/Trading).
	  Not trading: players in this server with a Trade button, plus any requests you've received.
	  Trading: what you offer (left) and what they offer (right), your creatures and items to add
	  underneath, Ready and Cancel. When both are ready a 5-second countdown runs before the swap.
	A pop-up asks you to accept or decline when someone sends you a request.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Creatures)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Sound = require(Modules.Sound)
local Layout = require(Modules.Layout)
local Invite = require(Modules.Invite)
local Config = require(Shared.Config)

local T = Ui.Theme

local TradePanel = {}

type IconFn = (parent: Instance, def: any, variant: string?, size: number, silhouette: boolean?) -> Frame

local function call(name: string, ...): (boolean, string?)
	local ok, success, message = pcall(function(...)
		return Remotes.Function(name):InvokeServer(...)
	end, ...)
	if not ok then
		Ui.toast("Something went wrong, try again", T.Bad)
		return false, nil
	end
	if message then
		Ui.toast(message, if success then T.Good else T.Bad)
	end
	return success == true, message
end

local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function scroll(parent: Instance, props: { [string]: any }): ScrollingFrame
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 5,
		BorderSizePixel = 0,
		Parent = parent,
	}
	for k, v in props do
		defaults[k] = v
	end
	return Ui.new("ScrollingFrame", defaults)
end

function TradePanel.Build(screen: Frame, creatureIcon: IconFn)
	local player = Players.LocalPlayer
	local _, content = Ui.panel(screen, "Trade", "Trade", UDim2.fromOffset(700, 580), "🤝")

	local current: any = nil -- the server's view of our trade (nil = not trading)
	local receivedAt = 0
	local invites: { [number]: { Name: string, Expires: number } } = {}
	local pickerTab = "Pets"

	-- Lobby: players and requests ----------------------------------------------------------
	local lobby = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
	Ui.text({
		Size = UDim2.new(1, -230, 0, 40),
		Text = "Trade creatures and Bag items with players in this server",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		MaxTextSize = 16,
		Parent = lobby,
	})
	Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(220, 40),
		Text = `👥 Invite friends (+{math.floor(Config.FriendBoost.PerFriend * 100 + 0.5)}% each)`,
		Variant = "Gold",
		Parent = lobby,
	}, Invite.Prompt)
	local lobbyList = scroll(lobby, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48) })
	Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = lobbyList })

	local function row(order: number, text: string, color: Color3?): Frame
		local frame = Ui.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 54),
			BackgroundColor3 = T.Card,
			Parent = lobbyList,
		}, { Ui.corner(10), Ui.stroke(color or T.Edge, 1.2, if color then 0.2 else 0.85) })
		Ui.text({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -260, 1, 0),
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			Parent = frame,
		})
		return frame
	end

	local function renderLobby()
		clear(lobbyList)
		local order = 0
		local now = os.clock()
		for userId, invite in invites do
			if invite.Expires > now and Players:GetPlayerByUserId(userId) then
				order += 1
				local frame = row(order, `📨 {invite.Name} wants to trade`, T.Gold)
				Ui.button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -124, 0.5, 0),
					Size = UDim2.fromOffset(104, 38),
					Text = "Accept",
					Variant = "Success",
					Parent = frame,
				}, function()
					invites[userId] = nil
					call("TradeRespond", userId, true)
					renderLobby()
				end)
				Ui.button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(104, 38),
					Text = "Decline",
					Variant = "Secondary",
					Parent = frame,
				}, function()
					invites[userId] = nil
					call("TradeRespond", userId, false)
					renderLobby()
				end)
			else
				invites[userId] = nil
			end
		end
		local others = 0
		for _, other in Players:GetPlayers() do
			if other ~= player then
				others += 1
				order += 1
				local frame = row(order, other.DisplayName)
				Ui.button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(150, 38),
					Text = "🤝 Trade",
					Variant = "Primary",
					Parent = frame,
				}, function()
					call("TradeRequest", other.UserId)
				end)
			end
		end
		if others == 0 then
			order += 1
			Ui.text({
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 60),
				Text = "Nobody else is in this server yet. Invite a friend to trade!",
				Font = T.FontRegular,
				TextColor3 = T.SubText,
				TextWrapped = true,
				MaxTextSize = 17,
				Parent = lobbyList,
			})
		end
	end

	-- Trade window --------------------------------------------------------------------------
	local window = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = content,
	})
	local SIDES = 0.42 -- the two offer boxes take this much of the height
	local gridLayouts: { UIGridLayout } = {}
	local function side(x: number, title: string): (TextLabel, ScrollingFrame, Frame)
		local box = Ui.new("Frame", {
			Position = UDim2.new(x, if x == 0 then 0 else 4, 0, 0),
			Size = UDim2.new(0.5, -4, SIDES, 0),
			BackgroundColor3 = T.Card,
			BackgroundTransparency = 0.2,
			Parent = window,
		}, { Ui.corner(12) })
		local label = Ui.text({
			Position = UDim2.fromOffset(10, 2),
			Size = UDim2.new(1, -20, 0, 24),
			Text = title,
			Font = T.FontHeavy,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			Parent = box,
		})
		local grid = scroll(box, { Position = UDim2.fromOffset(6, 28), Size = UDim2.new(1, -12, 1, -32) })
		table.insert(
			gridLayouts,
			Ui.new("UIGridLayout", {
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = grid,
			})
		)
		return label, grid, box
	end
	local myLabel, myGrid, myBox = side(0, "You offer")
	local theirLabel, theirGrid, theirBox = side(0.5, "They offer")

	-- status + buttons
	local status = Ui.text({
		Position = UDim2.new(0, 0, SIDES, 4),
		Size = UDim2.new(1, -300, 0, 44),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		MaxTextSize = 17,
		Parent = window,
	})
	local readyButton = Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -132, SIDES, 6),
		Size = UDim2.fromOffset(156, 42),
		Text = "Ready",
		Variant = "Success",
		Parent = window,
	}, function()
		if current then
			Sound.Play("Click", 1.2)
			call("TradeReady", not current.MyReady)
		end
	end)
	Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, SIDES, 6),
		Size = UDim2.fromOffset(124, 42),
		Text = "Cancel",
		Variant = "Danger",
		Parent = window,
	}, function()
		call("TradeCancel")
	end)

	-- picker: your creatures / your items
	local pickerTabs = Ui.new("Frame", {
		Position = UDim2.new(0, 0, SIDES, 54),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local picker = scroll(window, {
		Position = UDim2.new(0, 0, SIDES, 92),
		Size = UDim2.new(1, 0, 1 - SIDES, -92),
	})
	table.insert(
		gridLayouts,
		Ui.new("UIGridLayout", {
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = picker,
		})
	)
	-- smaller tiles on phones
	local function arrange()
		for _, layout in gridLayouts do
			layout.CellSize = if Layout.Compact then UDim2.fromOffset(58, 70) else UDim2.fromOffset(76, 92)
		end
	end
	Layout.Changed:Connect(arrange)
	arrange()
	local renderTrade: () -> ()
	local tabButtons: { [string]: TextButton } = {}
	for i, tab in { { "Pets", "🐾 Your creatures" }, { "Items", "🎒 Your items" } } do
		tabButtons[tab[1]] = Ui.button({
			LayoutOrder = i,
			Size = UDim2.fromOffset(180, 32),
			Text = tab[2],
			Variant = "Secondary",
			Parent = pickerTabs,
		}, function()
			pickerTab = tab[1]
			renderTrade()
		end)
	end

	-- One tile: a creature (3D icon) or an item (emoji) with a caption
	local function petTile(parent: Instance, order: number, pet: any, caption: string, onClick: (() -> ())?)
		local def = Creatures.Get(pet.Id)
		local tile = Ui.new("TextButton", {
			LayoutOrder = order,
			Text = "",
			AutoButtonColor = onClick ~= nil,
			BackgroundColor3 = T.PanelLight,
			Parent = parent,
		}, { Ui.corner(10) })
		if def then
			local icon = creatureIcon(tile, def, pet.Variant, if Layout.Compact then 42 else 58)
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 4)
		end
		Ui.text({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2, 1, -2),
			Size = UDim2.new(1, -4, 0, 26),
			Text = caption,
			Font = T.Font,
			TextWrapped = true,
			MaxTextSize = 12,
			Parent = tile,
		})
		if onClick then
			tile.Activated:Connect(onClick)
		end
	end
	local function itemTile(parent: Instance, order: number, id: string, count: number, onClick: (() -> ())?)
		local item = Items.Get(id)
		if not item then
			return
		end
		local tile = Ui.new("TextButton", {
			LayoutOrder = order,
			Text = "",
			AutoButtonColor = onClick ~= nil,
			BackgroundColor3 = item.Color:Lerp(T.Card, 0.75),
			Parent = parent,
		}, { Ui.corner(10) })
		Ui.text({
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, 0, 0.5, 0),
			Text = item.Icon,
			MaxTextSize = 36,
			Parent = tile,
		})
		Ui.text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 2),
			Size = UDim2.fromOffset(40, 18),
			Text = `x{count}`,
			Font = T.FontHeavy,
			TextColor3 = T.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 14,
			Parent = tile,
		})
		Ui.text({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2, 1, -2),
			Size = UDim2.new(1, -4, 0, 26),
			Text = item.Name,
			Font = T.Font,
			TextWrapped = true,
			MaxTextSize = 12,
			Parent = tile,
		})
		if onClick then
			tile.Activated:Connect(onClick)
		end
	end

	local function variantPrefix(variant: string): string
		return if variant == "Shiny" then "✨ " elseif variant == "Rainbow" then "🌈 " else ""
	end

	local function updateStatus()
		if not current then
			return
		end
		local partner = current.Partner.Name
		local lockLeft = if current.LockIn then current.LockIn - (os.clock() - receivedAt) else nil
		if lockLeft then
			status.Text = `🔒 Both ready! Trading in {math.max(0, math.ceil(lockLeft))}...`
			status.TextColor3 = T.Gold
		elseif current.MyReady then
			status.Text = `✅ You're ready. Waiting for {partner}...`
			status.TextColor3 = T.Good
		elseif current.TheirReady then
			status.Text = `✅ {partner} is ready. Check their offer, then press Ready`
			status.TextColor3 = T.Good
		else
			status.Text = "Add creatures and items, then press Ready. Any change un-readies both of you."
			status.TextColor3 = T.SubText
		end
		readyButton.Text = if current.MyReady then "Not ready" else "Ready"
		myBox.BackgroundColor3 = if current.MyReady then T.Good:Lerp(T.Card, 0.7) else T.Card
		theirBox.BackgroundColor3 = if current.TheirReady then T.Good:Lerp(T.Card, 0.7) else T.Card
	end

	renderTrade = function()
		if not current then
			return
		end
		myLabel.Text = "You offer"
		theirLabel.Text = `{current.Partner.Name} offers`
		clear(myGrid)
		clear(theirGrid)
		clear(picker)
		local offered: { [string]: boolean } = {}
		local offeredItems: { [string]: number } = {}
		for i, pet in current.Mine.Pets do
			offered[pet.Uid] = true
			petTile(myGrid, i, pet, `{variantPrefix(pet.Variant)}Lv {pet.Level}`, function()
				call("TradeSetPet", pet.Uid, false)
			end)
		end
		for i, entry in current.Mine.Items do
			offeredItems[entry.Id] = entry.Count
			itemTile(myGrid, 100 + i, entry.Id, entry.Count, function()
				call("TradeSetItem", entry.Id, entry.Count - 1)
			end)
		end
		for i, pet in current.Theirs.Pets do
			petTile(theirGrid, i, pet, `{variantPrefix(pet.Variant)}Lv {pet.Level}`)
		end
		for i, entry in current.Theirs.Items do
			itemTile(theirGrid, 100 + i, entry.Id, entry.Count)
		end
		-- the picker: tap to add
		local d = State.Data
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == pickerTab then T.Accent else T.GlassLight
		end
		if d and pickerTab == "Pets" then
			local list = {}
			for uid, entry in d.Creatures or {} do
				if not offered[uid] then
					table.insert(list, { Uid = uid, Entry = entry })
				end
			end
			table.sort(list, function(a, b)
				return Creatures.GetPower(a.Entry.Id, a.Entry.Variant, a.Entry.Level)
					> Creatures.GetPower(b.Entry.Id, b.Entry.Variant, b.Entry.Level)
			end)
			-- the strongest 60 (each tile is a little 3D model, so not all 150 at once)
			for i, pick in list do
				if i > 60 then
					break
				end
				local entry = pick.Entry
				local caption =
					`{variantPrefix(entry.Variant)}{if entry.Equipped then "⭐ " else ""}Lv {entry.Level or 1}`
				petTile(picker, i, { Id = entry.Id, Variant = entry.Variant }, caption, function()
					call("TradeSetPet", pick.Uid, true)
				end)
			end
		elseif d then
			local order = 0
			for _, item in Items.List do
				local have = (d.Items and d.Items[item.Id] or 0) - (offeredItems[item.Id] or 0)
				if have > 0 then
					order += 1
					itemTile(picker, order, item.Id, have, function()
						call("TradeSetItem", item.Id, (offeredItems[item.Id] or 0) + 1)
					end)
				end
			end
		end
		updateStatus()
	end

	local function refresh()
		lobby.Visible = current == nil
		window.Visible = current ~= nil
		if current then
			renderTrade()
		else
			renderLobby()
		end
	end

	-- Networking ----------------------------------------------------------------------------
	Remotes.Event("TradeUpdate").OnClientEvent:Connect(function(view, message, color)
		local starting = current == nil and view ~= nil
		current = view
		receivedAt = os.clock()
		if starting then
			Sound.Play("Fanfare", 1.5, 0.5)
			if not Ui.isOpen("Trade") then
				Ui.toggle("Trade", true)
			end
		end
		if view == nil and type(message) == "string" then
			Ui.toast(message, if typeof(color) == "Color3" then color else T.SubText)
		end
		refresh()
	end)
	Remotes.Event("TradeInvite").OnClientEvent:Connect(function(fromUserId, fromName)
		if type(fromUserId) ~= "number" then
			return
		end
		invites[fromUserId] = { Name = tostring(fromName), Expires = os.clock() + 30 }
		Sound.Play("Click", 0.9)
		if Ui.isOpen("Trade") then
			refresh()
		end
		Ui.confirm("🤝 Trade request", `{fromName} wants to trade with you!`, "Accept", function()
			invites[fromUserId] = nil
			call("TradeRespond", fromUserId, true)
		end)
	end)

	Ui.onPanelOpen("Trade", refresh)
	State.Changed:Connect(function(key)
		if key == "Data" and current and Ui.isOpen("Trade") then
			renderTrade()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if Ui.isOpen("Trade") and not current then
			renderLobby()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if Ui.isOpen("Trade") and not current then
			task.defer(renderLobby)
		end
	end)
	-- countdown ticker
	task.spawn(function()
		while true do
			task.wait(0.25)
			if current and current.LockIn then
				updateStatus()
			end
		end
	end)
end

return TradePanel
