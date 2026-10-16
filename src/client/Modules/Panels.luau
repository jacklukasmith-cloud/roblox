--[[ Menu buttons + every pop-up panel + the hatch reveal. ]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local Eggs = require(Shared.Eggs)
local PetStats = require(Shared.PetStats)
local Merchant = require(Shared.Merchant)
local Items = require(Shared.Items)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local CreatureModels = require(Shared.CreatureModels)
local Ui = require(script.Parent.Ui)
local DailyPanel = require(script.Parent.DailyPanel)
local SeasonPanel = require(script.Parent.SeasonPanel)
local BlacksmithPanel = require(script.Parent.BlacksmithPanel)
local BagPanel = require(script.Parent.BagPanel)
local TradePanel = require(script.Parent.TradePanel)
local Layout = require(script.Parent.Layout)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

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

-- A rounded tile with a live 3D model of the creature inside.
local function creatureIcon(
	parent: Instance,
	def: Creatures.CreatureDef,
	variant: string?,
	size: number,
	silhouette: boolean?
)
	local rarityColor = Creatures.Rarities[def.Rarity].Color
	local icon = Ui.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, { Ui.corner(size // 4) })
	Ui.new("UIGradient", {
		Color = if silhouette
			then ColorSequence.new(Color3.fromRGB(45, 35, 70), Color3.fromRGB(25, 18, 40))
			else ColorSequence.new(
				rarityColor:Lerp(Color3.new(1, 1, 1), 0.35),
				rarityColor:Lerp(Color3.new(0, 0, 0), 0.55)
			),
		Rotation = 90,
		Parent = icon,
	})
	if variant == "Shiny" or variant == "Rainbow" then
		Ui.new("UIStroke", {
			Color = if variant == "Rainbow" then Color3.fromRGB(255, 120, 220) else Color3.fromRGB(255, 225, 120),
			Thickness = 2.5,
			Parent = icon,
		})
	end
	local viewport = CreatureModels.Viewport(def.Id, variant, { Size = UDim2.fromScale(1, 1) })
	if silhouette then
		viewport.ImageColor3 = Color3.new(0, 0, 0)
		viewport.ImageTransparency = 0.15
	end
	viewport.Parent = icon
	return icon
end

-- A small egg model in a viewport; returns a function that shakes it (0 = still, 1 = wild).
-- Menu ---------------------------------------------------------------------------------
local MENU = {
	{ Panel = "Creatures", Label = "Pets", Icon = "🐾", Color = Color3.fromRGB(90, 170, 255) },
	{ Panel = "Bag", Label = "Bag", Icon = "🎒", Color = Color3.fromRGB(110, 210, 150) },
	{ Panel = "Shop", Label = "Shop", Icon = "🛒", Color = Color3.fromRGB(255, 200, 60) },
	{ Panel = "Merchant", Label = "Merchant", Icon = "🧙", Color = Color3.fromRGB(255, 145, 70) },
	{ Panel = "Trade", Label = "Trade", Icon = "🤝", Color = Color3.fromRGB(110, 190, 255) },
	{ Panel = "Rebirth", Label = "Rebirth", Icon = "🌀", Color = Color3.fromRGB(255, 110, 215) },
	{ Panel = "Bestiary", Label = "Index", Icon = "📖", Color = Color3.fromRGB(90, 215, 120) },
	{ Panel = "Settings", Label = "Settings", Icon = "⚙️", Color = Color3.fromRGB(150, 150, 190) },
	-- Corner = sits on its own in the top-right instead of in the left menu
	{ Panel = "Season", Label = "Season", Icon = "🏅", Color = Color3.fromRGB(255, 120, 90), Corner = true },
	{ Panel = "Daily", Label = "Daily", Icon = "🎁", Color = Color3.fromRGB(255, 196, 64), Corner = true },
}
Panels.MenuButtons = {} :: { TextButton }

-- Left-side menu: big icon tiles (one column on PC/tablet, two columns on phones)
local function buildMenu(root: Frame)
	local holder = Ui.new("Frame", {
		Name = "MenuHolder",
		BackgroundTransparency = 1,
		Parent = root,
	})
	local menu = Ui.new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local grid = Ui.new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	-- Top-right corner button(s), e.g. Daily
	local corner = Ui.new("Frame", {
		Name = "CornerButtons",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local cornerTiles: { TextButton } = {}
	local gridCount = 0
	for _, entry in MENU do
		if not entry.Corner then
			gridCount += 1
		end
	end
	local hints: { TextLabel } = {}
	for i, entry in MENU do
		local tile = Ui.button({
			Name = entry.Panel .. "Button",
			Text = "",
			LayoutOrder = i,
			Variant = "Secondary",
			BackgroundColor3 = T.Glass,
			BackgroundTransparency = 0.18,
			Parent = if entry.Corner then corner else menu,
		}, function()
			Ui.toggle(entry.Panel)
		end)
		if entry.Corner then
			table.insert(cornerTiles, tile)
		end
		local pad = tile:FindFirstChildOfClass("UIPadding")
		if pad then
			pad:Destroy()
		end
		-- coloured icon chip + label + accent underline
		local chip = Ui.new("Frame", {
			Name = "Chip",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.1),
			Size = UDim2.fromScale(0.56, 0.5),
			BackgroundColor3 = entry.Color,
			BackgroundTransparency = 0.72,
			Parent = tile,
		}, { Ui.corner(8), Ui.stroke(entry.Color, 1, 0.45) })
		Ui.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = chip })
		Ui.text({
			Text = entry.Icon,
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.1, 0.1),
			MaxTextSize = 30,
			Parent = chip,
		})
		Ui.text({
			Text = entry.Label,
			Size = UDim2.fromScale(0.92, 0.2),
			Position = UDim2.fromScale(0.04, 0.66),
			Font = T.Font,
			MaxTextSize = 14,
			Parent = tile,
		})
		Ui.new("Frame", {
			Name = "Accent",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(0.4, 0, 0, 3),
			BackgroundColor3 = entry.Color,
			BorderSizePixel = 0,
			Parent = tile,
		}, { Ui.round() })
		-- Keyboard shortcut badge (PC only)
		local badge = Ui.new("Frame", {
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = T.GlassLight,
			BackgroundTransparency = 0.2,
			ZIndex = 3,
			Parent = tile,
		}, { Ui.corner(5), Ui.stroke() })
		table.insert(
			hints,
			Ui.text({
				Text = if i == 10 then "0" else tostring(i), -- key 0 opens the 10th
				Size = UDim2.fromScale(1, 1),
				ZIndex = 4,
				TextColor3 = T.SubText,
				MaxTextSize = 12,
				Parent = badge,
			})
		)
		if entry.Panel == "Daily" then
			-- red bubble with the number of rewards waiting to be claimed
			local bubble = Ui.new("Frame", {
				Name = "Ready",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = T.Bad,
				Visible = false,
				ZIndex = 5,
				Parent = tile,
			}, { Ui.round(), Ui.stroke(Color3.new(1, 1, 1), 1.5, 0.2) })
			local count = Ui.text({
				Size = UDim2.fromScale(1, 1),
				Text = "",
				Font = T.FontHeavy,
				ZIndex = 6,
				MaxTextSize = 13,
				Parent = bubble,
			})
			-- gentle pulse while something is waiting, so it catches the eye
			local pulseScale = Ui.new("UIScale", { Parent = tile:FindFirstChild("Chip") })
			local pulse = TweenService:Create(
				pulseScale,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.12 }
			)
			local pulsing = false
			local function setPulse(on: boolean)
				if on == pulsing then
					return
				end
				pulsing = on
				if on then
					pulse:Play()
				else
					pulse:Cancel()
					pulseScale.Scale = 1
				end
			end
			State.Changed:Connect(function(key)
				local d = State.Data
				if key == "Data" and d and d.Daily then
					local ready = d.Daily.ReadyCount > 0
					bubble.Visible = ready
					count.Text = tostring(d.Daily.ReadyCount)
					setPulse(ready)
				end
			end)
		end
		table.insert(Panels.MenuButtons, tile)
	end
	-- Gamepad hint (outside the grid so it isn't laid out as a tile)
	local padHint = Ui.text({
		Text = "Ⓨ Menu   Ⓑ Close",
		Size = UDim2.new(1, 60, 0, 18),
		Position = UDim2.new(0, 0, 1, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.SubText,
		MaxTextSize = 16,
		Parent = holder,
	})
	local function arrange()
		local c = Layout.Compact
		-- Phones: 2 rows; everything else: 2 columns. Touch devices keep it in the top-left (clear of the
		-- thumbstick); PC/console keep it left-centre (clear of the chat window).
		local tileSize = if c then 48 else 58
		-- phones: 4 across once there are 7+ tiles, so the menu stays 2 rows (clear of the thumbstick)
		local cols = if c then (if gridCount > 6 then 4 else 3) else 2
		grid.CellSize = UDim2.fromOffset(tileSize, tileSize)
		local rows = math.ceil(gridCount / cols)
		local size = UDim2.fromOffset(cols * tileSize + (cols - 1) * 8, rows * tileSize + (rows - 1) * 8)
		menu.Size = size
		holder.Size = size
		local top = Layout.Touch or c
		holder.AnchorPoint = Vector2.new(0, if top then 0 else 0.5)
		holder.Position = UDim2.new(0, if c then 10 else 16, if top then 0 else 0.6, if top then 8 else 0)
		for _, hint in hints do
			(hint.Parent :: GuiObject).Visible = not Layout.Touch and not Layout.Gamepad
		end
		padHint.Visible = Layout.Gamepad
		-- Corner buttons: top-right. On PC/console they sit left of the player list.
		for _, tile in cornerTiles do
			tile.Size = UDim2.fromOffset(tileSize, tileSize)
		end
		corner.Size = UDim2.fromOffset(#cornerTiles * tileSize + (#cornerTiles - 1) * 8, tileSize)
		corner.Position = UDim2.new(1, if Layout.Touch or c then -10 else -224, 0, 8)
		-- Gamepad: d-pad moves through the menu in order
		for i, button in Panels.MenuButtons do
			button.NextSelectionDown = Panels.MenuButtons[i + cols]
			button.NextSelectionUp = Panels.MenuButtons[i - cols]
		end
	end
	Layout.Changed:Connect(arrange)
	arrange()
end

-- Keyboard shortcuts (1-7) and controller buttons (Y = menu, B = close)
local function bindInput()
	local keys = {
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six,
		Enum.KeyCode.Seven,
		Enum.KeyCode.Eight,
		Enum.KeyCode.Nine,
		Enum.KeyCode.Zero,
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local index = table.find(keys, input.KeyCode)
		if index and MENU[index] then
			Ui.toggle(MENU[index].Panel)
		end
	end)
	ContextActionService:BindAction("MythicMenu", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.ButtonY then
			if Ui.openPanel() then
				Ui.closeAll()
				GuiService.SelectedObject = nil
			elseif GuiService.SelectedObject then
				GuiService.SelectedObject = nil
			else
				GuiService.SelectedObject = Panels.MenuButtons[1]
			end
			return Enum.ContextActionResult.Sink
		elseif input.KeyCode == Enum.KeyCode.ButtonB then
			local open = Ui.openPanel()
			if open then
				Ui.toggle(open, false)
				GuiService.SelectedObject = Panels.MenuButtons[1]
				return Enum.ContextActionResult.Sink
			elseif GuiService.SelectedObject then
				GuiService.SelectedObject = nil
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB)
end

-- Creatures panel ------------------------------------------------------------------------
local function buildCreatures(screen: Frame)
	local panelFrame, content = Ui.panel(screen, "Creatures", "Your Creatures", nil, "🐾")
	local releaseMode = false
	local fuseMode = false
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

	local fuseButton
	fuseButton = Ui.button(
		{ LayoutOrder = 5, Text = "Fuse", Variant = "Gold", Size = UDim2.fromOffset(110, 40), Parent = bar },
		function()
			fuseMode = not fuseMode
			releaseMode = false
			selected = {}
			releaseButton.BackgroundColor3 = T.Card
			confirmButton.Visible = false
			fuseButton.Text = if fuseMode then "Done" else "Fuse"
			refresh(true)
		end
	)
	releaseButton = Ui.button(
		{ LayoutOrder = 3, Text = "Release Mode", BackgroundColor3 = T.Card, Parent = bar },
		function()
			releaseMode = not releaseMode
			fuseMode = false
			fuseButton.Text = "Fuse"
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
		local precious = 0
		local d = State.Data
		for uid in selected do
			table.insert(uids, uid)
			local entry = d and d.Creatures[uid]
			local def = entry and Creatures.Get(entry.Id)
			-- Epic+, Shiny/Rainbow, levelled or Robux-only creatures deserve a second look
			if
				def
				and (
					Creatures.Rarities[def.Rarity].Order >= 4
					or (entry.Variant or "Normal") ~= "Normal"
					or (entry.Level or 1) > 1
				)
			then
				precious += 1
			end
		end
		if #uids == 0 then
			return
		end
		local function release()
			invoke("Release", uids)
			selected = {}
			refresh(true)
		end
		if precious > 0 then
			Ui.confirm(
				`Release {#uids} creature{if #uids == 1 then "" else "s"}?`,
				`{precious} of them {if precious == 1 then "is" else "are"} rare, Shiny/Rainbow or levelled. Released creatures are gone forever.`,
				"Release",
				release
			)
		else
			release()
		end
	end)

	local grid = scrolling(content, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48) })
	Ui.autoGrid(grid, 112, 138)

	-- Stats card: tap a creature to see its details (and equip / unequip it from there)
	local shownUid: string? = nil
	local backdrop = Ui.new("TextButton", {
		Name = "PetDetails",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Visible = false,
		Parent = panelFrame, -- covers the whole panel so it has room on phones
	}, { Ui.corner(16) })
	local detail = Ui.glass({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 1, -24),
		Active = true,
		Parent = backdrop,
	}, { Ui.corner(14), Ui.new("UISizeConstraint", { MaxSize = Vector2.new(470, 330) }) })
	local detailEdge = detail:FindFirstChildOfClass("UIStroke")
	local detailScale = Ui.new("UIScale", { Parent = detail })
	local iconHolder = Ui.new("Frame", {
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.new(0.38, -16, 1, -82),
		BackgroundTransparency = 1,
		Parent = detail,
	}, { Ui.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local detailName = Ui.text({
		Position = UDim2.new(0.38, 8, 0, 16),
		Size = UDim2.new(0.62, -24, 0, 30),
		Text = "",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Parent = detail,
	})
	local detailRarity = Ui.text({
		Position = UDim2.new(0.38, 8, 0, 48),
		Size = UDim2.new(0.62, -24, 0, 20),
		Text = "",
		Font = T.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Parent = detail,
	})
	local statsList = Ui.new("Frame", {
		Position = UDim2.new(0.38, 8, 0, 76),
		Size = UDim2.new(0.62, -24, 1, -136),
		BackgroundTransparency = 1,
		Parent = detail,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local statRows: { TextLabel } = {}
	for i = 1, 6 do
		statRows[i] = Ui.text({
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 1 / 6, -3),
			Text = "",
			Font = T.Font,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 16,
			Parent = statsList,
		})
	end
	local actionButton: TextButton
	local function hideDetails()
		shownUid = nil
		backdrop.Visible = false
	end
	actionButton = Ui.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -14),
		Size = UDim2.new(0.5, -22, 0, 44),
		Text = "Equip",
		Variant = "Success",
		Parent = detail,
	}, function()
		local uid = shownUid
		local d = State.Data
		local entry = uid and d and d.Creatures[uid]
		if entry then
			invoke(if entry.Equipped then "Unequip" else "Equip", uid)
		end
	end)
	Ui.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -14),
		Size = UDim2.new(0.5, -22, 0, 44),
		Text = "Close",
		Variant = "Secondary",
		Parent = detail,
	}, hideDetails)
	backdrop.MouseButton1Click:Connect(hideDetails)

	local function renderDetails(animate: boolean)
		local d = State.Data
		local uid = shownUid
		local entry = uid and d and d.Creatures[uid]
		local def = entry and Creatures.Get(entry.Id)
		if not entry or not def then
			hideDetails()
			return
		end
		local rarityColor = Creatures.Rarities[def.Rarity].Color
		local variant = entry.Variant or "Normal"
		if animate then
			clearChildren(iconHolder, "Frame")
			local icon = creatureIcon(iconHolder, def, variant, 10)
			icon.Size = UDim2.fromScale(1, 1)
			local corner = icon:FindFirstChildOfClass("UICorner")
			if corner then
				corner.CornerRadius = UDim.new(0, 18)
			end
			detailScale.Scale = 0.8
			TweenService:Create(detailScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		if detailEdge then
			detailEdge.Color = rarityColor
			detailEdge.Transparency = 0.2
		end
		detailName.Text = Creatures.DisplayName(def.Id, variant)
		detailName.TextColor3 = rarityColor
		detailRarity.Text = if variant == "Normal" then def.Rarity else `{def.Rarity}  ·  {variant}`
		detailRarity.TextColor3 = rarityColor:Lerp(Color3.new(1, 1, 1), 0.3)
		local level = entry.Level or 1
		local power = Creatures.GetPower(def.Id, variant, level)
		local speed = PetStats.Speed(def.Id, level)
		local ability = PetStats.Ability(def.Id)
		local multiplier = (Creatures.Variants[variant] or Creatures.Variants.Normal).Multiplier
		local bonuses = {}
		if multiplier > 1 then
			table.insert(bonuses, `x{multiplier} {variant}`)
		end
		if level > 1 then
			table.insert(bonuses, `+{math.floor((Creatures.LevelMultiplier(level) - 1) * 100 + 0.5)}% Lv`)
		end
		local copies = 0
		for _, other in d.Creatures do
			if other.Id == entry.Id and (other.Variant or "Normal") == variant then
				copies += 1
			end
		end
		local nextVariant = Creatures.FuseNext[variant]
		local egg = Eggs.Get(Eggs.EggFor(def.Id))
		local rows = {
			`💪 Power  {Format.Number(math.floor(power + 0.5))}{if #bonuses > 0
				then `  ({table.concat(bonuses, " · ")})`
				else ""}`,
			if level >= Creatures.MaxLevel
				then `⭐ Level {level}  (MAX)`
				else `⭐ Level {level}  ·  {math.floor(entry.XP or 0)}/{Creatures.XPToNext(level)} XP`,
			`⚡ Speed  {math.floor(speed * 100 + 0.5) / 100}  ·  ⚔️ {Format.Number(
				power * speed * Config.PetDamageMultiplier / Config.PetAttackInterval
			)} dmg/sec`,
			if ability
				then `{ability.Icon} {ability.Name} · {ability.Short}`
				else `🥚 From the {if egg then egg.Name else "?"}`,
			`📦 Owned  {copies}` .. (if nextVariant
				then `  ·  Fuse {math.min(copies, Creatures.FuseCost)}/{Creatures.FuseCost} → {nextVariant}`
				else ""),
			if entry.Equipped then "✅ Equipped" else "💤 In storage",
		}
		for i, row in statRows do
			row.Text = rows[i] or ""
			row.TextColor3 = if i == 1
				then T.Power
				elseif i == 2 then Color3.fromRGB(255, 215, 90)
				elseif i == 4 then Color3.fromRGB(200, 175, 255)
				elseif i == 6 and entry.Equipped then T.Good
				else T.Text
		end
		actionButton.Text = if entry.Equipped then "Unequip" else "Equip"
		actionButton.BackgroundColor3 = if entry.Equipped then T.Card else T.Good
		backdrop.Visible = true
	end

	refresh = function(force: boolean)
		local d = State.Data
		if not d then
			return
		end
		local list = {}
		local equipped = 0
		for uid, entry in d.Creatures do
			table.insert(
				list,
				{ Uid = uid, Entry = entry, Power = Creatures.GetPower(entry.Id, entry.Variant, entry.Level) }
			)
			if entry.Equipped then
				equipped += 1
			end
		end
		info.Text = `Equipped {equipped}/{d.EquipSlots}  -  Storage {d.CreatureCount}/{d.MaxInventory}`

		-- Fuse mode: one card per creature + variant with how many you own
		if fuseMode then
			local groups: { [string]: { Id: string, Variant: string, Count: number } } = {}
			for _, item in list do
				local k = item.Entry.Id .. "|" .. item.Entry.Variant
				local g = groups[k] or { Id = item.Entry.Id, Variant = item.Entry.Variant, Count = 0 }
				g.Count += 1
				groups[k] = g
			end
			local sorted = {}
			local keyParts = { "F" }
			for k, g in groups do
				table.insert(sorted, g)
				table.insert(keyParts, k .. g.Count)
			end
			table.sort(keyParts)
			local key = table.concat(keyParts, ",")
			if key == lastKey and not force then
				return
			end
			lastKey = key
			table.sort(sorted, function(a, b)
				local fa = a.Count >= Creatures.FuseCost and Creatures.FuseNext[a.Variant] ~= nil
				local fb = b.Count >= Creatures.FuseCost and Creatures.FuseNext[b.Variant] ~= nil
				if fa ~= fb then
					return fa
				end
				if a.Count ~= b.Count then
					return a.Count > b.Count
				end
				return a.Id < b.Id
			end)
			clearChildren(grid, "TextButton")
			for i, g in sorted do
				local def = Creatures.Get(g.Id)
				if def then
					local nextVariant = Creatures.FuseNext[g.Variant]
					local ready = nextVariant ~= nil and g.Count >= Creatures.FuseCost
					local rarityColor = Creatures.Rarities[def.Rarity].Color
					local card = Ui.new("TextButton", {
						LayoutOrder = i,
						Text = "",
						AutoButtonColor = ready,
						BackgroundColor3 = if ready then T.Gold:Lerp(T.Card, 0.75) else T.Card,
						Parent = grid,
					}, { Ui.corner(10), Ui.stroke(if ready then T.Gold else rarityColor, if ready then 3 else 1.5) })
					local icon = creatureIcon(card, def, g.Variant, 58)
					icon.AnchorPoint = Vector2.new(0.5, 0)
					icon.Position = UDim2.new(0.5, 0, 0, 8)
					Ui.text({
						Text = `{Creatures.DisplayName(def.Id, g.Variant)} x{g.Count}`,
						Position = UDim2.fromOffset(4, 66),
						Size = UDim2.new(1, -8, 0, 22),
						TextColor3 = rarityColor,
						Parent = card,
					})
					Ui.text({
						Text = if nextVariant == nil
							then "Max (Rainbow)"
							else `{math.min(g.Count, Creatures.FuseCost)}/{Creatures.FuseCost} → {nextVariant}`,
						Position = UDim2.fromOffset(4, 90),
						Size = UDim2.new(1, -8, 0, 18),
						TextColor3 = if ready then T.Gold else T.SubText,
						Parent = card,
					})
					Ui.text({
						Text = if ready then "TAP TO FUSE" else "",
						Font = T.FontHeavy,
						Position = UDim2.fromOffset(4, 112),
						Size = UDim2.new(1, -8, 0, 16),
						TextColor3 = T.Good,
						Parent = card,
					})
					card.MouseButton1Click:Connect(function()
						if ready then
							invoke("Fuse", g.Id, g.Variant)
						elseif nextVariant then
							Ui.toast(`Collect {Creatures.FuseCost} to fuse into a {nextVariant}`, T.SubText)
						end
					end)
				end
			end
			return
		end
		local count = 0
		for _ in selected do
			count += 1
		end
		confirmButton.Text = `Release ({count})`
		local tally: { [string]: number } = {}
		local fusable = 0
		for _, item in list do
			if Creatures.FuseNext[item.Entry.Variant] then
				local k = item.Entry.Id .. "|" .. item.Entry.Variant
				tally[k] = (tally[k] or 0) + 1
				if tally[k] == Creatures.FuseCost then
					fusable += 1
				end
			end
		end
		if not fuseMode then
			fuseButton.Text = if fusable > 0 then `Fuse ({fusable})` else "Fuse"
		end

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
				item.Uid
					.. (if item.Entry.Equipped then "E" else "")
					.. (if selected[item.Uid] then "S" else "")
					.. "L"
					.. tostring(item.Entry.Level or 1)
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
				local icon = creatureIcon(card, def, item.Entry.Variant, 58)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.Position = UDim2.new(0.5, 0, 0, 8)
				if (item.Entry.Level or 1) > 1 then
					Ui.text({
						Text = `Lv {item.Entry.Level}`,
						Position = UDim2.fromOffset(5, 4),
						Size = UDim2.fromOffset(34, 16),
						Font = T.FontHeavy,
						TextColor3 = Color3.fromRGB(255, 215, 90),
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 13,
						ZIndex = 3,
						Parent = card,
					})
				end
				Ui.text({
					Text = Creatures.DisplayName(def.Id, item.Entry.Variant),
					Position = UDim2.fromOffset(4, 66),
					Size = UDim2.new(1, -8, 0, 22),
					TextColor3 = rarityColor,
					Parent = card,
				})
				Ui.text({
					Text = "Power " .. Format.Number(math.floor(item.Power + 0.5)),
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
					else
						shownUid = item.Uid
						renderDetails(true)
					end
				end)
			end
		end
	end

	Ui.onPanelOpen("Creatures", function()
		hideDetails()
		refresh(true)
	end)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Creatures") then
			refresh(false)
			if shownUid then
				renderDetails(false)
			end
		end
	end)
end

-- Shop panel ------------------------------------------------------------------------------
-- Live icon + price for a pass/product straight from Roblox (cached), so the shop always matches
-- what you set on the Creator Hub. Returns nil if it can't be fetched.
local productInfoCache: { [string]: { Icon: string?, Price: number? } | false } = {}
local function productInfo(id: number, infoType: Enum.InfoType)
	local key = `{infoType.Name}:{id}`
	local cached = productInfoCache[key]
	if cached ~= nil then
		return cached or nil
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)
	if not ok or type(info) ~= "table" then
		return nil -- try again next time the shop opens
	end
	local iconId = info.IconImageAssetId
	local result = {
		Icon = if type(iconId) == "number" and iconId > 0 then `rbxassetid://{iconId}` else nil,
		Price = if type(info.PriceInRobux) == "number" then info.PriceInRobux else nil,
	}
	productInfoCache[key] = result
	return result
end

local SHOP_EMOJI = {
	VIP = "👑",
	DoubleEssence = "💎",
	AutoCollect = "⛏️",
	LuckyHatch = "🍀",
	TripleHatch = "🥚",
	ExtraEquip = "🐾",
	LongerOffline = "🌙",
	GoldenPickaxe = "⛏",
	EssencePouch = "👝",
	EssenceChest = "🧰",
	LuckPotion = "🧪",
	MerchantRestock = "🔄",
}

local function shopCard(
	parent: Instance,
	order: number,
	item,
	owned: boolean,
	onBuy: () -> (),
	infoType: Enum.InfoType?
)
	local card = Ui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 74),
		BackgroundColor3 = T.Card,
		Parent = parent,
	}, { Ui.corner(10), Ui.stroke(T.Gold, 1.5) })
	-- Icon: Config.Icon if set, otherwise the icon uploaded on the Creator Hub (fetched below)
	local textX = 76
	local icon = Ui.new("ImageLabel", {
		Image = item.Icon or "",
		BackgroundColor3 = T.GlassLight,
		BackgroundTransparency = 0.3,
		Position = UDim2.fromOffset(8, 7),
		Size = UDim2.fromOffset(60, 60),
		Parent = card,
	}, { Ui.corner(30) })
	-- emoji until (or unless) a real icon is available
	local fallback = Ui.text({
		Size = UDim2.fromScale(1, 1),
		Text = SHOP_EMOJI[item.Key] or "⭐",
		Visible = item.Icon == nil or item.Icon == "",
		MaxTextSize = 32,
		Parent = icon,
	})
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
	if item.Id ~= 0 and infoType then
		task.spawn(function()
			local info = productInfo(item.Id, infoType)
			if not info or not card.Parent then
				return
			end
			if (item.Icon == nil or item.Icon == "") and info.Icon then
				icon.Image = info.Icon
				fallback.Visible = false
			end
			if info.Price and not owned then
				button.Text = `R$ {info.Price}`
			end
		end)
	end
	return card
end

-- Big featured card for a Robux-exclusive creature (a developer product that grants a creature)
local function exclusiveCard(parent: Instance, order: number, product)
	local def = Creatures.Get(product.Grant.Creature)
	if not def then
		return
	end
	local color = Creatures.Rarities[def.Rarity].Color
	local card = Ui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 150),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, {
		Ui.corner(14),
		Ui.stroke(color, 2.5),
		Ui.new("UIGradient", {
			Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.45), Color3.fromRGB(30, 20, 60)),
			Rotation = 20,
		}),
	})
	local icon = creatureIcon(card, def, nil, 128)
	icon.Position = UDim2.fromOffset(11, 11)
	Ui.text({
		Text = "★ ROBUX EXCLUSIVE",
		Position = UDim2.fromOffset(152, 12),
		Size = UDim2.new(1, -300, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35),
		Font = T.FontHeavy,
		MaxTextSize = 15,
		Parent = card,
	})
	Ui.text({
		Text = def.Name,
		Position = UDim2.fromOffset(152, 34),
		Size = UDim2.new(1, -300, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = T.FontHeavy,
		MaxTextSize = 32,
		Parent = card,
	})
	Ui.text({
		Text = `💪 Power {Format.Number(def.Power)}  ·  ⚔️ {Format.Number(
			def.Power * Config.PetDamageMultiplier / Config.PetAttackInterval
		)} damage/sec`,
		Position = UDim2.fromOffset(152, 76),
		Size = UDim2.new(1, -300, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.Power,
		MaxTextSize = 18,
		Parent = card,
	})
	Ui.text({
		Text = product.Description,
		Position = UDim2.fromOffset(152, 104),
		Size = UDim2.new(1, -300, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.SubText,
		TextWrapped = true,
		MaxTextSize = 15,
		Parent = card,
	})
	local button = Ui.button({
		Text = `R$ {product.PriceHint}`,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(130, 56),
		Variant = "Gold",
		Parent = card,
	}, function()
		if product.Id == 0 then
			Ui.toast("This product isn't set up yet (add its ID in Config.luau)", T.Bad)
		else
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end
	end)
	if product.Id ~= 0 then
		task.spawn(function()
			local info = productInfo(product.Id, Enum.InfoType.Product)
			if info and info.Price and card.Parent then
				button.Text = `R$ {info.Price}`
			end
		end)
	end
end

local function buildShop(screen: Frame)
	local _, content = Ui.panel(screen, "Shop", "Shop", nil, "🛒")
	local list = scrolling(content)
	Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local function render()
		clearChildren(list, "Frame")
		clearChildren(list, "TextLabel")
		local owned = if State.Data then State.Data.OwnedPasses else {}
		for i, product in Config.DevProducts do
			if product.Grant.Kind == "Creature" then
				exclusiveCard(list, -100 + i, product)
			end
		end
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
			end, Enum.InfoType.GamePass)
		end
		Ui.text({
			LayoutOrder = 100,
			Text = "Boosts & Packs",
			TextColor3 = T.Accent,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = list,
		})
		for i, product in Config.DevProducts do
			if product.Grant.Kind == "Creature" then
				continue -- featured at the top
			end
			shopCard(list, 100 + i, product, false, function()
				if product.Id == 0 then
					Ui.toast("This product isn't set up yet (add its ID in Config.luau)", T.Bad)
				else
					MarketplaceService:PromptProductPurchase(player, product.Id)
				end
			end, Enum.InfoType.Product)
		end
	end
	Ui.onPanelOpen("Shop", render)
end

-- Merchant panel ------------------------------------------------------------------------
local function buildMerchant(screen: Frame)
	local _, content = Ui.panel(screen, "Merchant", "Wandering Merchant", nil, "🧙")
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
					Text = `{(Items.Get(item.Id) or {}).Icon or ""} {item.Name}  (x{left} left)`,
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
local function buildRebirth(screen: Frame)
	local _, content = Ui.panel(screen, "Rebirth", "Rebirth", UDim2.fromOffset(520, 340), "🌀")
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
		local d = State.Data
		if d and d.Essence < d.RebirthCost then
			invoke("Rebirth") -- the server explains what's missing
			return
		end
		Ui.confirm(
			"Rebirth?",
			"Your Essence and unlocked realms reset. You keep your creatures and get a permanent Essence boost.",
			"Rebirth",
			function()
				invoke("Rebirth")
			end
		)
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
local function buildBestiary(screen: Frame)
	local _, content = Ui.panel(screen, "Bestiary", "Bestiary", nil, "📖")
	local header = Ui.text({ Size = UDim2.new(1, 0, 0, 26), Text = "", TextColor3 = T.Good, Parent = content })
	local milestoneLabel = Ui.text({
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		Font = T.FontRegular,
		TextColor3 = Color3.fromRGB(255, 215, 90),
		MaxTextSize = 15,
		Parent = content,
	})
	local setsLabel = Ui.text({
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		MaxTextSize = 15,
		Parent = content,
	})
	local grid = scrolling(content, { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 1, -76) })
	Ui.autoGrid(grid, 112, 110)

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
			local icon = creatureIcon(card, def, nil, 52, not known)
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 6)
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
		-- Index sets: discover everything an egg can hatch for a permanent bonus
		local sets = {}
		for _, eggId in Eggs.Order do
			local egg = Eggs.Get(eggId)
			local complete, have, total = Eggs.SetProgress(eggId, d.Bestiary)
			if egg and total > 0 then
				local short = string.gsub(egg.Name, " Egg$", "")
				table.insert(sets, if complete then `{short} ✅` else `{short} {have}/{total}`)
			end
		end
		setsLabel.Text =
			`📖 Sets (+{math.floor(Config.IndexSetBonus * 100)}% Essence each): {table.concat(sets, "  ·  ")}`
		local hatched = d.Stats and d.Stats.CreaturesHatched or 0
		local nextMilestone = Config.HatchMilestones[(d.Stats and d.Stats.HatchMilestones or 0) + 1]
		milestoneLabel.Text = if nextMilestone
			then `🥚 Hatched {Format.Number(hatched)} / {Format.Number(nextMilestone.At)}  ·  next milestone: a bonus Rare+ creature{if nextMilestone.Title
				then ` + "{nextMilestone.Title}"`
				else ""}`
			else `🥚 Hatched {Format.Number(hatched)}  ·  every milestone claimed!`
		header.Text = `Discovered {found}/{#Creatures.Ordered}  -  Bestiary bonus: +{math.floor(
			(d.BestiaryMultiplier - 1) * 100 + 0.5
		)}% Essence`
	end
	Ui.onPanelOpen("Bestiary", render)
end

-- Settings panel -------------------------------------------------------------------------
local function buildSettings(screen: Frame)
	local _, content = Ui.panel(screen, "Settings", "Settings", UDim2.fromOffset(460, 540), "⚙️")
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
			if inst:IsA("ParticleEmitter") or inst:IsA("PointLight") or inst:IsA("Fire") then
				inst.Enabled = not State.PotatoMode
			end
		end
	end)
	local music
	music = Ui.button({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "Music: ON",
		BackgroundColor3 = T.Card,
		Parent = content,
	}, function()
		State.Set("MusicMuted", not State.MusicMuted)
		music.Text = "Music: " .. (if State.MusicMuted then "OFF" else "ON")
	end)
	local sfx
	sfx = Ui.button({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "Sound Effects: ON",
		BackgroundColor3 = T.Card,
		Parent = content,
	}, function()
		State.Set("SfxMuted", not State.SfxMuted)
		sfx.Text = "Sound Effects: " .. (if State.SfxMuted then "OFF" else "ON")
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
	Ui.button({
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 44),
		Text = `👥 Invite friends: +{math.floor(Config.FriendBoost.PerFriend * 100 + 0.5)}% Essence for each friend here`,
		Variant = "Gold",
		Parent = content,
	}, require(script.Parent.Invite).Prompt)
	-- Codes: type one in for free rewards
	local codeRow = Ui.new("Frame", {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local codeBox = Ui.new("TextBox", {
		Size = UDim2.new(1, -130, 1, 0),
		BackgroundColor3 = T.Card,
		PlaceholderText = "🎟️ Enter a code",
		PlaceholderColor3 = T.SubText,
		Text = "",
		ClearTextOnFocus = false,
		Font = T.Font,
		TextColor3 = T.Text,
		TextScaled = true,
		Parent = codeRow,
	}, {
		Ui.corner(10),
		Ui.new("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
	})
	local redeeming = false
	local function redeem()
		if redeeming then
			return
		end
		redeeming = true
		if invoke("RedeemCode", codeBox.Text) then
			codeBox.Text = ""
			Sound.Play("Fanfare", 1.2)
		end
		redeeming = false
	end
	Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 120, 1, 0),
		Text = "Redeem",
		Variant = "Gold",
		Parent = codeRow,
	}, redeem)
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
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
function Panels.Build(screen: Frame)
	buildMenu(screen)
	bindInput()
	buildCreatures(screen)
	buildShop(screen)
	buildMerchant(screen)
	buildRebirth(screen)
	buildBestiary(screen)
	buildSettings(screen)
	DailyPanel.Build(screen)
	SeasonPanel.Build(screen)
	BlacksmithPanel.Build(screen)
	BagPanel.Build(screen)
	TradePanel.Build(screen, creatureIcon)

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
