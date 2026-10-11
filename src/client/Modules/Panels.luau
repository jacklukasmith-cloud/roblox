--[[ Menu buttons + every pop-up panel + the hatch reveal. ]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local Eggs = require(Shared.Eggs)
local Merchant = require(Shared.Merchant)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Panels = {}

local T = Ui.Theme
local player = Players.LocalPlayer

local function invoke(name: string, ...): boolean
	local ok, success, message = pcall(function(...)
		return Remotes.Function(name):InvokeServer(...)
	end, ...)
	if not ok then
		Ui.toast("Something went wrong, try again", T.Bad)
		return false
	end
	if message then
		Ui.toast(message, if success then T.Good else T.Bad)
	end
	return success == true
end

local function scrolling(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local defaults = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = parent,
	}
	for k, v in props or {} do
		defaults[k] = v
	end
	return Ui.new("ScrollingFrame", defaults)
end

local function clearChildren(parent: Instance, className: string)
	for _, child in parent:GetChildren() do
		if child:IsA(className) then
			child:Destroy()
		end
	end
end

local function creatureIcon(parent: Instance, def: Creatures.CreatureDef, variant: string?, size: number)
	local icon = Ui.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = def.Color,
		Parent = parent,
	}, { Ui.corner(size // 2), Ui.stroke(def.Accent, 3) })
	if variant == "Shiny" or variant == "Rainbow" then
		Ui.new("UIGradient", {
			Color = if variant == "Rainbow"
				then ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 255, 160)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 140, 255)),
				})
				else ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 225, 120)),
			Rotation = 45,
			Parent = icon,
		})
	end
	return icon
end

-- Menu ---------------------------------------------------------------------------------
local function buildMenu(screen: ScreenGui)
	local menu = Ui.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.55, 0),
		Size = UDim2.fromOffset(130, 320),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local entries = {
		{ "Creatures", "Creatures", Color3.fromRGB(120, 200, 255) },
		{ "Shop", "Shop", T.Gold },
		{ "Merchant", "Merchant", Color3.fromRGB(255, 170, 90) },
		{ "Rebirth", "Rebirth", Color3.fromRGB(255, 120, 230) },
		{ "Bestiary", "Bestiary", T.Good },
		{ "Settings", "Settings", Color3.fromRGB(170, 170, 200) },
	}
	for i, entry in entries do
		Ui.button({
			Text = entry[2],
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = entry[3],
			TextColor3 = Color3.fromRGB(30, 20, 50),
			Parent = menu,
		}, function()
			Ui.toggle(entry[1])
		end)
	end
end

-- Creatures panel ------------------------------------------------------------------------
local function buildCreatures(screen: ScreenGui)
	local _, content = Ui.panel(screen, "Creatures", "Your Creatures")
	local releaseMode = false
	local selected: { [string]: boolean } = {}
	local lastKey = ""

	local bar = Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content }, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local info = Ui.text({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(250, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = bar,
	})
	Ui.button({ LayoutOrder = 2, Text = "Equip Best", BackgroundColor3 = T.Good, Parent = bar }, function()
		invoke("EquipBest")
	end)
	local releaseButton
	local confirmButton
	local refresh: (boolean) -> ()

	releaseButton = Ui.button(
		{ LayoutOrder = 3, Text = "Release Mode", BackgroundColor3 = T.Card, Parent = bar },
		function()
			releaseMode = not releaseMode
			selected = {}
			releaseButton.BackgroundColor3 = if releaseMode then T.Bad else T.Card
			confirmButton.Visible = releaseMode
			refresh(true)
		end
	)
	confirmButton = Ui.button({
		LayoutOrder = 4,
		Text = "Release (0)",
		BackgroundColor3 = T.Bad,
		Visible = false,
		Size = UDim2.fromOffset(140, 40),
		Parent = bar,
	}, function()
		local uids = {}
		for uid in selected do
			table.insert(uids, uid)
		end
		if #uids > 0 then
			invoke("Release", uids)
		end
		selected = {}
	end)

	local grid = scrolling(content, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48) })
	Ui.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(112, 138),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	refresh = function(force: boolean)
		local d = State.Data
		if not d then
			return
		end
		local list = {}
		local equipped = 0
		for uid, entry in d.Creatures do
			table.insert(list, { Uid = uid, Entry = entry, Power = Creatures.GetPower(entry.Id, entry.Variant) })
			if entry.Equipped then
				equipped += 1
			end
		end
		info.Text = `Equipped {equipped}/{d.EquipSlots}  -  Storage {d.CreatureCount}/{d.MaxInventory}`
		local count = 0
		for _ in selected do
			count += 1
		end
		confirmButton.Text = `Release ({count})`

		-- Only rebuild cards when the creature list actually changed
		table.sort(list, function(a, b)
			if a.Entry.Equipped ~= b.Entry.Equipped then
				return a.Entry.Equipped
			end
			if a.Power ~= b.Power then
				return a.Power > b.Power
			end
			return tonumber(a.Uid) < tonumber(b.Uid)
		end)
		local keyParts = {}
		for _, item in list do
			table.insert(
				keyParts,
				item.Uid .. (if item.Entry.Equipped then "E" else "") .. (if selected[item.Uid] then "S" else "")
			)
		end
		local key = table.concat(keyParts, ",")
		if key == lastKey and not force then
			return
		end
		lastKey = key
		clearChildren(grid, "TextButton")
		for i, item in list do
			local def = Creatures.Get(item.Entry.Id)
			if def then
				local rarityColor = Creatures.Rarities[def.Rarity].Color
				local card = Ui.new("TextButton", {
					LayoutOrder = i,
					Text = "",
					AutoButtonColor = true,
					BackgroundColor3 = if item.Entry.Equipped then Color3.fromRGB(60, 90, 70) else T.Card,
					Parent = grid,
				}, {
					Ui.corner(10),
					Ui.stroke(if selected[item.Uid] then T.Bad else rarityColor, if selected[item.Uid] then 4 else 2),
				})
				local icon = creatureIcon(card, def, item.Entry.Variant, 54)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.Position = UDim2.new(0.5, 0, 0, 8)
				Ui.text({
					Text = Creatures.DisplayName(def.Id, item.Entry.Variant),
					Position = UDim2.fromOffset(4, 66),
					Size = UDim2.new(1, -8, 0, 22),
					TextColor3 = rarityColor,
					Parent = card,
				})
				Ui.text({
					Text = "Power " .. Format.Number(item.Power),
					Position = UDim2.fromOffset(4, 90),
					Size = UDim2.new(1, -8, 0, 18),
					Parent = card,
				})
				Ui.text({
					Text = if item.Entry.Equipped then "EQUIPPED" else def.Rarity,
					Position = UDim2.fromOffset(4, 112),
					Size = UDim2.new(1, -8, 0, 16),
					TextColor3 = if item.Entry.Equipped then T.Good else T.SubText,
					Parent = card,
				})
				card.MouseButton1Click:Connect(function()
					if releaseMode then
						if item.Entry.Equipped then
							Ui.toast("Unequip a creature before releasing it", T.Bad)
							return
						end
						selected[item.Uid] = if selected[item.Uid] then nil else true
						refresh(true)
					elseif item.Entry.Equipped then
						invoke("Unequip", item.Uid)
					else
						invoke("Equip", item.Uid)
					end
				end)
			end
		end
	end

	Ui.onPanelOpen("Creatures", function()
		refresh(true)
	end)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Creatures") then
			refresh(false)
		end
	end)
end

-- Shop panel ------------------------------------------------------------------------------
local function shopCard(parent: Instance, order: number, item, owned: boolean, onBuy: () -> ())
	local card = Ui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 74),
		BackgroundColor3 = T.Card,
		Parent = parent,
	}, { Ui.corner(10), Ui.stroke(T.Gold, 1.5) })
	local textX = 10
	if item.Icon and item.Icon ~= "" then
		Ui.new("ImageLabel", {
			Image = item.Icon,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 7),
			Size = UDim2.fromOffset(60, 60),
			Parent = card,
		}, { Ui.corner(30) })
		textX = 76
	end
	Ui.text({
		Text = item.Name,
		Position = UDim2.fromOffset(textX, 8),
		Size = UDim2.new(1, -textX - 140, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.Gold,
		Parent = card,
	})
	Ui.text({
		Text = item.Description,
		Position = UDim2.fromOffset(textX, 40),
		Size = UDim2.new(1, -textX - 140, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.SubText,
		Parent = card,
	})
	local button = Ui.button({
		Text = if owned then "Owned" else `R$ {item.PriceHint}`,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		BackgroundColor3 = if owned then T.Card else T.Good,
		Parent = card,
	}, function()
		if not owned then
			onBuy()
		end
	end)
	button.Active = not owned
	return card
end

local function buildShop(screen: ScreenGui)
	local _, content = Ui.panel(screen, "Shop", "Shop")
	local list = scrolling(content)
	Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local function render()
		clearChildren(list, "Frame")
		clearChildren(list, "TextLabel")
		local owned = if State.Data then State.Data.OwnedPasses else {}
		Ui.text({
			LayoutOrder = 0,
			Text = "Game Passes (forever)",
			TextColor3 = T.Accent,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = list,
		})
		for i, pass in Config.GamePasses do
			shopCard(list, i, pass, owned[pass.Key] == true, function()
				if pass.Id == 0 then
					Ui.toast("This pass isn't set up yet (add its ID in Config.luau)", T.Bad)
				else
					MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				end
			end)
		end
		Ui.text({
			LayoutOrder = 100,
			Text = "Boosts & Packs",
			TextColor3 = T.Accent,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = list,
		})
		for i, product in Config.DevProducts do
			shopCard(list, 100 + i, product, false, function()
				if product.Id == 0 then
					Ui.toast("This product isn't set up yet (add its ID in Config.luau)", T.Bad)
				else
					MarketplaceService:PromptProductPurchase(player, product.Id)
				end
			end)
		end
	end
	Ui.onPanelOpen("Shop", render)
end

-- Merchant panel ------------------------------------------------------------------------
local function buildMerchant(screen: ScreenGui)
	local _, content = Ui.panel(screen, "Merchant", "Wandering Merchant")
	local timer = Ui.text({ Size = UDim2.new(1, 0, 0, 26), Text = "", TextColor3 = T.SubText, Parent = content })
	local list = scrolling(content, { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34) })
	Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local lastKey = ""

	local function render(force: boolean)
		local d, w = State.Data, State.World
		if not d or not w then
			return
		end
		local slot = w.Merchant.Slot
		local bought = if d.Merchant.Slot == slot then d.Merchant.Bought else {}
		local keyParts = { tostring(slot), tostring(d.ZonesUnlocked) }
		for id, n in bought do
			table.insert(keyParts, id .. n)
		end
		table.sort(keyParts)
		local key = table.concat(keyParts, "|")
		if key == lastKey and not force then
			return
		end
		lastKey = key
		clearChildren(list, "Frame")
		local order = 0
		for _, item in Merchant.Items do
			local stock = w.Merchant.Stock[item.Id] or 0
			if stock > 0 then
				order += 1
				local left = stock - (bought[item.Id] or 0)
				local price = Merchant.GetPrice(item, d.ZonesUnlocked)
				local card = Ui.new("Frame", {
					LayoutOrder = order,
					Size = UDim2.new(1, -8, 0, 70),
					BackgroundColor3 = T.Card,
					Parent = list,
				}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(255, 170, 90), 1.5) })
				Ui.text({
					Text = `{item.Name}  (x{left} left)`,
					Position = UDim2.fromOffset(10, 6),
					Size = UDim2.new(1, -160, 0, 28),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Color3.fromRGB(255, 200, 120),
					Parent = card,
				})
				Ui.text({
					Text = item.Description,
					Position = UDim2.fromOffset(10, 38),
					Size = UDim2.new(1, -160, 0, 22),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = T.SubText,
					Parent = card,
				})
				Ui.button({
					Text = if left > 0 then Format.Number(price) .. " Essence" else "Sold out",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(140, 40),
					BackgroundColor3 = if left > 0 then T.Good else T.Card,
					Parent = card,
				}, function()
					if left > 0 then
						invoke("BuyMerchantItem", item.Id)
					end
				end)
			end
		end
		local restock = Config.DevProducts[4]
		for _, product in Config.DevProducts do
			if product.Key == "MerchantRestock" then
				restock = product
			end
		end
		order += 1
		local footer = Ui.new(
			"Frame",
			{ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 50), BackgroundTransparency = 1, Parent = list }
		)
		Ui.button({
			Text = `Restock now - R$ {restock.PriceHint}`,
			Size = UDim2.fromOffset(240, 42),
			BackgroundColor3 = T.Gold,
			TextColor3 = Color3.fromRGB(40, 30, 10),
			Parent = footer,
		}, function()
			if restock.Id == 0 then
				Ui.toast("Restock product isn't set up yet (Config.luau)", T.Bad)
			else
				MarketplaceService:PromptProductPurchase(player, restock.Id)
			end
		end)
	end

	Ui.onPanelOpen("Merchant", function()
		render(true)
	end)
	State.Changed:Connect(function(key)
		if (key == "Data" or key == "World") and Ui.isOpen("Merchant") then
			render(false)
		end
	end)
	task.spawn(function()
		while true do
			if State.World then
				timer.Text = "Restocks in "
					.. Format.Time(State.World.Merchant.NextRestockAt - State.Now())
					.. "  (same stock in every server!)"
			end
			task.wait(1)
		end
	end)
end

-- Rebirth panel --------------------------------------------------------------------------
local function buildRebirth(screen: ScreenGui)
	local _, content = Ui.panel(screen, "Rebirth", "Rebirth", UDim2.fromScale(0.4, 0.45))
	Ui.new("UIListLayout", {
		Padding = UDim.new(0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})
	local lines = Ui.text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 60), Text = "", Parent = content })
	local barBack = Ui.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(0.9, 0, 0, 24),
		BackgroundColor3 = T.Background,
		Parent = content,
	}, { Ui.corner(12) })
	local barFill = Ui.new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 120, 230), Parent = barBack },
		{ Ui.corner(12) }
	)
	Ui.text({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 36),
		TextColor3 = T.SubText,
		Text = "Resets Essence and zones. Keeps creatures, Trophies and your Bestiary.",
		Parent = content,
	})
	Ui.button({
		LayoutOrder = 4,
		Text = "REBIRTH",
		Size = UDim2.fromOffset(200, 50),
		BackgroundColor3 = Color3.fromRGB(255, 120, 230),
	}, function()
		invoke("Rebirth")
	end).Parent =
		content

	local function render()
		local d = State.Data
		if not d then
			return
		end
		lines.Text =
			`Rebirths: {d.Rebirths}   Essence x{d.RebirthMultiplier} -> x{d.NextRebirthMultiplier}\nCost: {Format.Number(
				d.RebirthCost
			)} Essence`
		barFill.Size = UDim2.fromScale(math.clamp(d.Essence / d.RebirthCost, 0, 1), 1)
	end
	Ui.onPanelOpen("Rebirth", render)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Rebirth") then
			render()
		end
	end)
end

-- Bestiary panel -------------------------------------------------------------------------
local function buildBestiary(screen: ScreenGui)
	local _, content = Ui.panel(screen, "Bestiary", "Bestiary")
	local header = Ui.text({ Size = UDim2.new(1, 0, 0, 26), Text = "", TextColor3 = T.Good, Parent = content })
	local grid = scrolling(content, { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34) })
	Ui.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(112, 110),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local function render()
		local d = State.Data
		if not d then
			return
		end
		clearChildren(grid, "Frame")
		local found = 0
		for i, def in Creatures.Ordered do
			local known = d.Bestiary[def.Id] == true
			if known then
				found += 1
			end
			local card = Ui.new("Frame", { LayoutOrder = i, BackgroundColor3 = T.Card, Parent = grid }, {
				Ui.corner(10),
				Ui.stroke(if known then Creatures.Rarities[def.Rarity].Color else T.Background, 2),
			})
			local icon = creatureIcon(card, def, nil, 50)
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 8)
			if not known then
				icon.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
			end
			Ui.text({
				Text = if known then def.Name else "???",
				Position = UDim2.fromOffset(4, 62),
				Size = UDim2.new(1, -8, 0, 20),
				TextColor3 = if known then Creatures.Rarities[def.Rarity].Color else T.SubText,
				Parent = card,
			})
			Ui.text({
				Text = def.Rarity,
				Position = UDim2.fromOffset(4, 84),
				Size = UDim2.new(1, -8, 0, 16),
				TextColor3 = T.SubText,
				Parent = card,
			})
		end
		header.Text = `Discovered {found}/{#Creatures.Ordered}  -  Bestiary bonus: +{math.floor(
			(d.BestiaryMultiplier - 1) * 100 + 0.5
		)}% Essence`
	end
	Ui.onPanelOpen("Bestiary", render)
end

-- Settings panel -------------------------------------------------------------------------
local function buildSettings(screen: ScreenGui)
	local _, content = Ui.panel(screen, "Settings", "Settings", UDim2.fromScale(0.4, 0.4))
	Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	local potato
	potato = Ui.button({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "Low Graphics: OFF",
		BackgroundColor3 = T.Card,
		Parent = content,
	}, function()
		State.Set("PotatoMode", not State.PotatoMode)
		potato.Text = "Low Graphics: " .. (if State.PotatoMode then "ON" else "OFF")
		-- Strip particles & lights for low-end devices (PS99's "Potato Mode")
		for _, inst in workspace:GetDescendants() do
			if inst:IsA("ParticleEmitter") or inst:IsA("PointLight") then
				inst.Enabled = not State.PotatoMode
			end
		end
	end)
	local auto
	auto = Ui.button({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "Auto Collect",
		BackgroundColor3 = T.Card,
		Parent = content,
	}, function()
		local d = State.Data
		if not d then
			return
		end
		if not d.OwnedPasses.AutoCollect then
			Ui.toggle("Shop", true)
			Ui.toast("Auto Collect is a game pass", T.Gold)
			return
		end
		invoke("SetAutoCollect", not d.AutoCollectEnabled)
	end)
	State.Changed:Connect(function(key)
		local d = State.Data
		if key == "Data" and d then
			auto.Text = if d.OwnedPasses.AutoCollect
				then "Auto Collect: " .. (if d.AutoCollectEnabled then "ON" else "OFF")
				else "Auto Collect (game pass)"
		end
	end)
end

-- Hatch reveal ---------------------------------------------------------------------------
local function buildHatchDisplay(screen: ScreenGui)
	local overlay = Ui.new("Frame", {
		Name = "Hatch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(520, 240),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	local title = Ui.text({ Size = UDim2.new(1, 0, 0, 40), Text = "", Parent = overlay })
	local row = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 180),
		BackgroundTransparency = 1,
		Parent = overlay,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
		}),
	})
	local token = 0

	Remotes.Event("HatchResult").OnClientEvent:Connect(function(eggId, results)
		token += 1
		local myToken = token
		local egg = Eggs.Get(eggId)
		clearChildren(row, "Frame")
		overlay.Visible = true
		title.Text = (if egg then egg.Name else "Egg") .. " hatched!"
		local best = 0
		for i, result in results do
			local def = Creatures.Get(result.Id)
			if def then
				local rarity = Creatures.Rarities[def.Rarity]
				best = math.max(best, rarity.Order)
				local card = Ui.new(
					"Frame",
					{ LayoutOrder = i, Size = UDim2.fromOffset(150, 170), BackgroundColor3 = T.Panel, Parent = row },
					{
						Ui.corner(14),
						Ui.stroke(rarity.Color, 3),
					}
				)
				local scale = Ui.new("UIScale", { Scale = 0, Parent = card })
				local icon = creatureIcon(card, def, result.Variant, 70)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.Position = UDim2.new(0.5, 0, 0, 12)
				Ui.text({
					Text = Creatures.DisplayName(def.Id, result.Variant),
					Position = UDim2.fromOffset(6, 90),
					Size = UDim2.new(1, -12, 0, 26),
					TextColor3 = rarity.Color,
					Parent = card,
				})
				Ui.text({
					Text = def.Rarity,
					Position = UDim2.fromOffset(6, 118),
					Size = UDim2.new(1, -12, 0, 20),
					TextColor3 = T.SubText,
					Parent = card,
				})
				Ui.text({
					Text = "Power " .. Format.Number(Creatures.GetPower(def.Id, result.Variant)),
					Position = UDim2.fromOffset(6, 140),
					Size = UDim2.new(1, -12, 0, 20),
					Parent = card,
				})
				task.delay((i - 1) * 0.25, function()
					TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				end)
			end
		end
		if best >= Creatures.LuckyRarityOrder then
			title.Text = "WOW! " .. title.Text
		end
		task.delay(3, function()
			if token == myToken then
				overlay.Visible = false
			end
		end)
	end)
end

function Panels.Build(screen: ScreenGui)
	buildMenu(screen)
	buildCreatures(screen)
	buildShop(screen)
	buildMerchant(screen)
	buildRebirth(screen)
	buildBestiary(screen)
	buildSettings(screen)
	buildHatchDisplay(screen)

	-- The merchant stall in the hub opens the panel
	task.spawn(function()
		local world = workspace:WaitForChild("World")
		local stall = world:WaitForChild("Hub"):WaitForChild("Merchant")
		local prompt = stall:WaitForChild("MerchantPrompt") :: ProximityPrompt
		game:GetService("ProximityPromptService").PromptTriggered:Connect(function(triggered)
			if triggered == prompt then
				Ui.toggle("Merchant", true)
			end
		end)
	end)
end

return Panels
