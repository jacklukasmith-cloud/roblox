--[[
	The ⚗️ Alchemy Cauldron window: opens when you step into the Cauldron circle on your island.
	Shows what's brewing (with a timer) and every recipe with the crystals it needs from your Vault.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Alchemy = require(Shared.Alchemy)
local Config = require(Shared.Config)
local Gloomwood = require(Shared.Gloomwood)
local Items = require(Shared.Items)
local Zones = require(Shared.Zones)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Sound = require(Modules.Sound)

local T = Ui.Theme

local CauldronPanel = {}

local GREEN = Color3.fromRGB(120, 255, 160)

local function essenceCost(data: any, recipe: any): number
	local zone = Zones.List[math.clamp(data.ZonesUnlocked or 1, 1, #Zones.List)]
	return zone.CrystalReward * recipe.Essence * (data.RebirthMultiplier or 1)
end

local function hasPass(data: any): boolean
	return data.OwnedPasses ~= nil and data.OwnedPasses.MasterAlchemist == true
end

function CauldronPanel.Build(screen: Frame)
	local _, content = Ui.panel(screen, "Cauldron", "Alchemy Cauldron", UDim2.fromOffset(640, 580), "⚗️")

	-- what's brewing (one row per slot)
	local slotsFrame = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundTransparency = 1,
		Parent = content,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local slotRows = {}
	for i = 1, Config.GamePassBonuses.CauldronSlots do
		local row = Ui.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = T.Card,
			BackgroundTransparency = 0.1,
			Parent = slotsFrame,
		}, { Ui.corner(10) })
		local fill = Ui.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = GREEN,
			BackgroundTransparency = 0.75,
			Parent = row,
		}, { Ui.corner(10) })
		local label = Ui.text({
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -24, 1, 0),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 16,
			ZIndex = 2,
			Parent = row,
		})
		slotRows[i] = { Row = row, Fill = fill, Label = label }
	end
	local passButton = Ui.button({
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "⚗️ Master Alchemist: a 2nd Cauldron slot and 25% faster brews",
		Variant = "Secondary",
		Parent = content,
	}, function()
		Ui.toggle("Shop", true)
	end)
	local list = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 132),
		Size = UDim2.new(1, 0, 1, -132),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = content,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local busy = false
	local function brew(recipe: any)
		if busy then
			return
		end
		busy = true
		Sound.Play("Click", 1.1)
		task.spawn(function()
			local ok, result, message = pcall(function()
				return Remotes.Function("Brew"):InvokeServer(recipe.Id)
			end)
			busy = false
			if ok and message then
				Ui.toast(message, if result then GREEN else Color3.fromRGB(255, 120, 120))
			end
		end)
	end

	local rows = {}
	for i, recipe in Alchemy.Recipes do
		local item = Items.Get(recipe.Item)
		local row = Ui.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, -8, 0, 74),
			BackgroundColor3 = T.Card,
			BackgroundTransparency = 0.1,
			Parent = list,
		}, { Ui.corner(12) })
		Ui.text({
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0, 48, 1, 0),
			Text = if item then item.Icon else "⚗️",
			MaxTextSize = 34,
			Parent = row,
		})
		Ui.text({
			Position = UDim2.fromOffset(62, 6),
			Size = UDim2.new(1, -200, 0, 22),
			Text = if item then item.Name else recipe.Id,
			Font = T.FontHeavy,
			TextColor3 = if item then item.Color else T.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			Parent = row,
		})
		Ui.text({
			Position = UDim2.fromOffset(62, 28),
			Size = UDim2.new(1, -200, 0, 18),
			Text = if item then item.Description else "",
			Font = T.FontRegular,
			TextColor3 = T.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 13,
			Parent = row,
		})
		local needs = Ui.text({
			Position = UDim2.fromOffset(62, 48),
			Size = UDim2.new(1, -200, 0, 20),
			Text = "",
			Font = T.FontRegular,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 14,
			Parent = row,
		})
		local button = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(112, 46),
			Text = "Brew",
			Variant = "Gold",
			Parent = row,
		}, function()
			brew(recipe)
		end)
		rows[recipe.Id] = { Needs = needs, Button = button }
	end

	local function render()
		local data = State.Data
		if not data then
			return
		end
		local now = State.Now()
		local pass = hasPass(data)
		local slots = if pass then Config.GamePassBonuses.CauldronSlots else Alchemy.BaseSlots
		local brews = data.Cauldron and data.Cauldron.Brews or {}
		passButton.Visible = not pass
		-- the rows below move up when there's only one slot (or no pass ad)
		local top = slots * 46
		passButton.Position = UDim2.fromOffset(0, top)
		top += if pass then 0 else 36
		list.Position = UDim2.fromOffset(0, top)
		list.Size = UDim2.new(1, 0, 1, -top)
		for i, slot in slotRows do
			slot.Row.Visible = i <= slots
			local brew = brews[i]
			local recipe = brew and Alchemy.Get(brew.Recipe)
			if recipe then
				local item = Items.Get(recipe.Item)
				local left = math.max(0, brew.DoneAt - now)
				local total = math.max(1, brew.DoneAt - brew.StartedAt)
				slot.Fill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
				slot.Label.Text =
					`⚗️ Brewing {if item then item.Icon .. " " .. item.Name else recipe.Id}  ·  {if left > 0
						then Format.Time(left)
						else "ready!"}`
			else
				slot.Fill.Size = UDim2.fromScale(0, 1)
				slot.Label.Text = "Empty: pick a recipe below"
			end
		end
		local vault = data.Gloom and data.Gloom.Vault or {}
		local free = #brews < slots
		for _, recipe in Alchemy.Recipes do
			local row = rows[recipe.Id]
			local parts = {}
			for _, crystal in Gloomwood.Crystals do
				local need = recipe.Ingredients[crystal.Id]
				if need then
					local have = vault[crystal.Id] or 0
					table.insert(parts, `{if have >= need then "✓" else "✗"} {crystal.Name} {have}/{need}`)
				end
			end
			local cost = essenceCost(data, recipe)
			local speed = if pass then Config.GamePassBonuses.CauldronSpeed else 1
			table.insert(parts, `💎 {Format.Number(cost)}`)
			table.insert(parts, `⏱ {Format.Time(Alchemy.Duration(recipe, speed))}`)
			row.Needs.Text = table.concat(parts, "   ")
			local enough = Alchemy.HasIngredients(vault, recipe) and (data.Essence or 0) >= cost
			local can = free and enough
			row.Needs.TextColor3 = if enough then GREEN else T.SubText
			row.Button.BackgroundColor3 = if can then Color3.fromRGB(255, 200, 70) else T.GlassLight
			row.Button.TextColor3 = if can then Color3.fromRGB(40, 28, 6) else T.SubText
			row.Button.Text = if not free then "Busy" else "Brew"
		end
	end

	Ui.onPanelOpen("Cauldron", render)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Cauldron") then
			render()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if Ui.isOpen("Cauldron") then
				render()
			end
		end
	end)
end

return CauldronPanel
