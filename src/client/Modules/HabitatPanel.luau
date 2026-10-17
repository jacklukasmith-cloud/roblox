--[[
	The 🐾 Pet Habitat window: opens when you step into the green circle on your island. Tap a pet
	to move it in or out. Pets in the habitat wander your island and earn XP, even offline.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Creatures)
local CreatureModels = require(Shared.CreatureModels)
local Sanctuary = require(Shared.Sanctuary)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Sound = require(Modules.Sound)

local T = Ui.Theme

local HabitatPanel = {}

local GREEN = Color3.fromRGB(110, 220, 140)

function HabitatPanel.Build(screen: Frame)
	local _, content = Ui.panel(screen, "Habitat", "Pet Habitat", UDim2.fromOffset(620, 560), "🐾")

	local info = Ui.text({
		Size = UDim2.new(1, 0, 0, 40),
		Text = "",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextWrapped = true,
		MaxTextSize = 15,
		Parent = content,
	})
	local slotsText = Ui.text({
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		Font = T.FontHeavy,
		TextColor3 = GREEN,
		MaxTextSize = 18,
		Parent = content,
	})
	local grid = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -72),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = content,
	}, { Ui.new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }) })
	Ui.autoGrid(grid, 100, 124)
	local empty = Ui.text({
		Position = UDim2.fromOffset(10, 110),
		Size = UDim2.new(1, -20, 0, 60),
		Text = "All your pets are equipped. Unequip some in 🐾 Pets to let them live here!",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextWrapped = true,
		MaxTextSize = 17,
		Visible = false,
		Parent = content,
	})

	local busy = false
	local lastKey = ""

	local function render(force: boolean?)
		local data = State.Data
		if not data then
			return
		end
		local s = data.Sanctuary or {}
		local habitat = s.Habitat or {}
		local slots = Sanctuary.HabitatSlots(s.Level or 1)
		local inHabitat = {}
		for _, uid in habitat do
			inHabitat[uid] = true
		end
		-- habitat pets first, then the strongest
		local list = {}
		for uid, entry in data.Creatures or {} do
			if not entry.Equipped and Creatures.Get(entry.Id) then
				table.insert(list, { Uid = uid, Entry = entry, In = inHabitat[uid] == true })
			end
		end
		table.sort(list, function(a, b)
			if a.In ~= b.In then
				return a.In
			end
			local pa = Creatures.GetPower(a.Entry.Id, a.Entry.Variant, a.Entry.Level)
			local pb = Creatures.GetPower(b.Entry.Id, b.Entry.Variant, b.Entry.Level)
			if pa ~= pb then
				return pa > pb
			end
			return a.Uid < b.Uid
		end)
		local nextSlotsAt = nil
		for level = (s.Level or 1) + 1, Sanctuary.MaxLevel do
			if Sanctuary.HabitatSlots(level) > slots then
				nextSlotsAt = level
				break
			end
		end
		info.Text =
			`Pets here wander your island and earn {Sanctuary.HabitatXPPerMinute} XP a minute, even while you're offline (up to {Sanctuary.HabitatOfflineHours} hours).`
		slotsText.Text = `{#habitat}/{slots} pets`
			.. (if nextSlotsAt then `  ·  more room at island level {nextSlotsAt}` else "")
		-- only rebuild the cards when something they show has changed
		local parts = { tostring(slots) }
		for _, item in list do
			table.insert(parts, `{item.Uid}{if item.In then "+" else ""}{item.Entry.Level or 1}`)
		end
		local key = table.concat(parts, ",")
		if key == lastKey and not force then
			return
		end
		lastKey = key
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		empty.Visible = #list == 0
		for i, item in list do
			local entry = item.Entry
			local def = Creatures.Get(entry.Id) :: Creatures.CreatureDef
			local level = entry.Level or 1
			local card = Ui.button({
				LayoutOrder = i,
				Text = "",
				Variant = "Secondary",
				BackgroundColor3 = if item.In then GREEN:Lerp(T.Card, 0.55) else T.Card,
				Parent = grid,
			}, function()
				if busy then
					return
				end
				if not item.In and #habitat >= slots then
					Ui.toast(`Your habitat is full ({slots} pets). Upgrade your island for more room!`, T.Gold)
					return
				end
				busy = true
				Sound.Play("Click", if item.In then 0.9 else 1.2)
				task.spawn(function()
					local ok, result, message = pcall(function()
						return Remotes.Function("SetHabitat"):InvokeServer(item.Uid, not item.In)
					end)
					busy = false
					if ok and not result and message then
						Ui.toast(message, Color3.fromRGB(255, 120, 120))
					end
				end)
			end)
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if item.In and stroke then
				stroke.Color = GREEN
				stroke.Thickness = 2.5
			end
			-- (the button has padding, so these sit inside it)
			local viewport = CreatureModels.Viewport(entry.Id, entry.Variant, {
				Position = UDim2.new(0.5, -32, 0, 0),
				Size = UDim2.fromOffset(64, 64),
			})
			viewport.Parent = card
			Ui.text({
				Position = UDim2.fromOffset(0, 66),
				Size = UDim2.new(1, 0, 0, 20),
				Text = Creatures.DisplayName(entry.Id, entry.Variant),
				TextColor3 = Creatures.Rarities[def.Rarity].Color,
				MaxTextSize = 14,
				Parent = card,
			})
			Ui.text({
				Position = UDim2.fromOffset(0, 88),
				Size = UDim2.new(1, 0, 0, 18),
				Text = if item.In
					then `🏡 Lv {level}{if level >= Creatures.MaxLevel then " MAX" else ""}`
					else `Lv {level}{if level >= Creatures.MaxLevel then " MAX" else ""}`,
				Font = T.FontRegular,
				TextColor3 = if item.In then GREEN else T.SubText,
				MaxTextSize = 13,
				Parent = card,
			})
		end
	end

	Ui.onPanelOpen("Habitat", function()
		render(true)
	end)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Habitat") then
			render()
		end
	end)
end

return HabitatPanel
