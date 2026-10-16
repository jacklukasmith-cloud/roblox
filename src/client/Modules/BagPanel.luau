--[[
	The 🎒 Bag: every item you've collected (Shared/Items), as a grid of tiles with a count.
	Tap a tile to see what it does, then Use it. Also shows a pop-up when something new goes
	into your Bag.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Creatures = require(Shared.Creatures)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Sound = require(Modules.Sound)

local T = Ui.Theme

local BagPanel = {}

local function rarityColor(rarity: string): Color3
	local r = Creatures.Rarities[rarity]
	return if r then r.Color else T.SubText
end

function BagPanel.Build(screen: Frame)
	local _, content = Ui.panel(screen, "Bag", "Bag", UDim2.fromOffset(620, 560), "🎒")
	local DETAIL_H = 92

	local grid = Ui.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -(DETAIL_H + 8)),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = content,
	}, { Ui.new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }) })
	Ui.autoGrid(grid, 92, 104)
	local empty = Ui.text({
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.fromOffset(10, 40),
		Text = "Your Bag is empty.\nBreak crystals, open Mana Chests, beat bosses and visit the Merchant to find items!",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextWrapped = true,
		MaxTextSize = 17,
		Visible = false,
		Parent = content,
	})

	-- Detail bar at the bottom: what the selected item does + Use
	local detail = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, DETAIL_H),
		BackgroundColor3 = T.Card,
		BackgroundTransparency = 0.1,
		Parent = content,
	}, { Ui.corner(12) })
	local detailIcon = Ui.text({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		Text = "🎒",
		MaxTextSize = 40,
		Parent = detail,
	})
	local detailName = Ui.text({
		Position = UDim2.fromOffset(80, 12),
		Size = UDim2.new(1, -230, 0, 26),
		Text = "Tap an item",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = detail,
	})
	local detailText = Ui.text({
		Position = UDim2.fromOffset(80, 40),
		Size = UDim2.new(1, -230, 0, 40),
		Text = "to see what it does.",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		MaxTextSize = 15,
		Parent = detail,
	})
	local selected: string? = nil
	local busy = false
	local useButton = Ui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(130, 48),
		Text = "Use",
		Variant = "Success",
		Visible = false,
		Parent = detail,
	}, function()
		local id = selected
		if not id or busy then
			return
		end
		busy = true
		local ok, success, message = pcall(function()
			return Remotes.Function("UseItem"):InvokeServer(id)
		end)
		busy = false
		if not ok then
			Ui.toast("Something went wrong, try again", T.Bad)
			return
		end
		if message then
			Ui.toast(message, if success then T.Gold else T.Bad)
		end
		if success then
			Sound.Play("Fanfare", 1.4, 0.6)
		end
	end)

	local function showDetail()
		local d = State.Data
		local item = selected and Items.Get(selected)
		local count = if item and d and d.Items then d.Items[item.Id] or 0 else 0
		if not item or count <= 0 then
			selected = nil
			detailIcon.Text = "🎒"
			detailName.Text = "Tap an item"
			detailName.TextColor3 = T.Text
			detailText.Text = "to see what it does."
			useButton.Visible = false
			return
		end
		detailIcon.Text = item.Icon
		detailName.Text = `{item.Name}  x{count}`
		detailName.TextColor3 = rarityColor(item.Rarity):Lerp(Color3.new(1, 1, 1), 0.3)
		detailText.Text = item.Description
		useButton.Text = if item.Kind == "Gift" then "Open" else "Use"
		useButton.Visible = true
	end

	local tiles: { [string]: { Frame: TextButton, Count: TextLabel, Stroke: UIStroke } } = {}
	local function render()
		local d = State.Data
		if not d then
			return
		end
		local bag = d.Items or {}
		local any = false
		for _, item in Items.List do
			local count = bag[item.Id] or 0
			local tile = tiles[item.Id]
			if count > 0 then
				any = true
				if not tile then
					local color = rarityColor(item.Rarity)
					local frame = Ui.new("TextButton", {
						Name = item.Id,
						Text = "",
						AutoButtonColor = true,
						LayoutOrder = (item :: any).Order,
						BackgroundColor3 = item.Color:Lerp(T.Card, 0.75),
						Parent = grid,
					}, { Ui.corner(12) })
					local stroke = Ui.stroke(color, 1.5, 0.3)
					stroke.Parent = frame
					Ui.text({
						Position = UDim2.fromOffset(0, 8),
						Size = UDim2.new(1, 0, 0, 48),
						Text = item.Icon,
						MaxTextSize = 40,
						Parent = frame,
					})
					Ui.text({
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 4, 1, -6),
						Size = UDim2.new(1, -8, 0, 32),
						Text = item.Name,
						Font = T.Font,
						TextWrapped = true,
						MaxTextSize = 14,
						Parent = frame,
					})
					local badge = Ui.text({
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -6, 0, 4),
						Size = UDim2.fromOffset(44, 20),
						Text = "",
						Font = T.FontHeavy,
						TextColor3 = T.Gold,
						TextXAlignment = Enum.TextXAlignment.Right,
						MaxTextSize = 15,
						Parent = frame,
					})
					frame.Activated:Connect(function()
						selected = item.Id
						Sound.Play("Click", 1.3)
						render()
					end)
					tile = { Frame = frame, Count = badge, Stroke = stroke }
					tiles[item.Id] = tile
				end
				tile.Count.Text = `x{count}`
				tile.Stroke.Thickness = if selected == item.Id then 3 else 1.5
				tile.Stroke.Transparency = if selected == item.Id then 0 else 0.3
			elseif tile then
				tile.Frame:Destroy()
				tiles[item.Id] = nil
			end
		end
		empty.Visible = not any
		showDetail()
	end

	Ui.onPanelOpen("Bag", render)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Bag") then
			render()
		end
	end)

	-- Something new went into the Bag
	Remotes.Event("ItemGained").OnClientEvent:Connect(function(id, count)
		local item = Items.Get(id)
		if not item then
			return
		end
		local amount = if type(count) == "number" and count > 1 then `{count}x ` else ""
		Ui.toast(`🎒 +{amount}{item.Icon} {item.Name}`, rarityColor(item.Rarity):Lerp(Color3.new(1, 1, 1), 0.2))
		Sound.Play("Orb", 1.6, 0.6)
	end)
end

return BagPanel
