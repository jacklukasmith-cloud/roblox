--[[
	The 🛹 Hangar window: opens when you step into the Hangar circle on your island. Build vehicles
	from the Gloom Crystals in your Vault, pick a skin (Board Skins pass) and hop on.
	HangarPanel also adds the 🛹 ride button (key R) next to the 🏠 button.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Vehicles = require(Shared.Vehicles)
local Gloomwood = require(Shared.Gloomwood)
local Zones = require(Shared.Zones)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Sound = require(Modules.Sound)
local Layout = require(Modules.Layout)

local T = Ui.Theme

local HangarPanel = {}

local ORANGE = Color3.fromRGB(255, 190, 110)

local function essenceCost(data: any, def: any): number
	local zone = Zones.List[math.clamp(data.ZonesUnlocked or 1, 1, #Zones.List)]
	return zone.CrystalReward * def.Essence * (data.RebirthMultiplier or 1)
end

local busy = false
local function call(name: string, ...: any)
	if busy then
		return
	end
	busy = true
	local args = { ... }
	task.spawn(function()
		local ok, result, message = pcall(function()
			return Remotes.Function(name):InvokeServer(table.unpack(args))
		end)
		busy = false
		if ok and message then
			Ui.toast(message, if result then ORANGE else Color3.fromRGB(255, 120, 120))
		end
	end)
end

-- Hop on your last-ridden (or only) vehicle, or off
local function toggleRide()
	local data = State.Data
	local g = data and data.Vehicles
	if not g then
		return
	end
	local riding = Players.LocalPlayer:GetAttribute("Riding")
	if riding then
		call("Ride", nil)
		return
	end
	local id = g.LastRidden
	if not id or not g.Owned[id] then
		for owned in g.Owned do
			id = owned
			break
		end
	end
	if not id then
		Ui.toast("🛹 Build a hoverboard at the Hangar on your island first", T.SubText)
		return
	end
	Sound.Play("Click", 1.2)
	call("Ride", id)
end

function HangarPanel.Build(screen: Frame, root: Frame)
	local player = Players.LocalPlayer
	local _, content = Ui.panel(screen, "Hangar", "Hangar", UDim2.fromOffset(620, 560), "🛹")
	Ui.text({
		Size = UDim2.new(1, 0, 0, 36),
		Text = "Build hoverboards from the Gloom Crystals in your Vault. Ride them with 🛹 (or R) in the hub, the forest's Edge and Midwood and up on the islands.",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextWrapped = true,
		MaxTextSize = 14,
		Parent = content,
	})
	-- skins row
	local skinsRow = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = content,
	}, { Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
	local skinButtons: { [string]: TextButton } = {}
	for i, skin in Vehicles.Skins do
		skinButtons[skin.Id] = Ui.button({
			LayoutOrder = i,
			Size = UDim2.fromOffset(if skin.Color then 34 else 86, 30),
			Text = if skin.Color then "" else "Classic",
			BackgroundColor3 = skin.Color or T.GlassLight,
			Variant = "Secondary",
			Parent = skinsRow,
		}, function()
			local data = State.Data
			if skin.Color and not (data and data.OwnedPasses and data.OwnedPasses.BoardSkins) then
				Ui.toggle("Shop", true)
				Ui.toast("Board Skins is a game pass", T.Gold)
				return
			end
			call("SetSkin", skin.Id)
		end)
	end
	Ui.text({
		Position = UDim2.fromOffset(300, 40),
		Size = UDim2.new(1, -300, 0, 34),
		Text = "← skins (Board Skins pass)",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		Parent = content,
	})
	local list = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 1, -82),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = content,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local rows = {}
	for i, def in Vehicles.List do
		local row = Ui.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, -8, 0, 78),
			BackgroundColor3 = T.Card,
			BackgroundTransparency = 0.1,
			Parent = list,
		}, { Ui.corner(12) })
		Ui.text({
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0, 48, 1, 0),
			Text = def.Icon,
			MaxTextSize = 34,
			Parent = row,
		})
		Ui.text({
			Position = UDim2.fromOffset(62, 6),
			Size = UDim2.new(1, -200, 0, 22),
			Text = def.Name .. (if def.ComingSoon then "  (coming soon)" else ""),
			Font = T.FontHeavy,
			TextColor3 = def.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			Parent = row,
		})
		Ui.text({
			Position = UDim2.fromOffset(62, 28),
			Size = UDim2.new(1, -200, 0, 18),
			Text = `{def.Description}  ·  speed x{def.Speed}{if def.Glide then ", glides" else ""}{if def.Seats
				then `, {def.Seats} seats`
				else ""}`,
			Font = T.FontRegular,
			TextColor3 = T.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 13,
			Parent = row,
		})
		local needs = Ui.text({
			Position = UDim2.fromOffset(62, 50),
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
			Text = "Build",
			Variant = "Gold",
			Parent = row,
		}, function()
			local data = State.Data
			local owned = data and data.Vehicles and data.Vehicles.Owned[def.Id]
			Sound.Play("Click", 1.1)
			if owned then
				call("Ride", def.Id)
			else
				call("BuildVehicle", def.Id)
			end
		end)
		rows[def.Id] = { Needs = needs, Button = button }
	end

	local function render()
		local data = State.Data
		if not data then
			return
		end
		local g = data.Vehicles or { Owned = {}, Skin = "Default" }
		local vault = data.Gloom and data.Gloom.Vault or {}
		local ridingId = player:GetAttribute("Riding")
		for id, button in skinButtons do
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = if (g.Skin or "Default") == id then 3 else 1
				stroke.Color = if (g.Skin or "Default") == id then Color3.new(1, 1, 1) else T.Edge
			end
		end
		for _, def in Vehicles.List do
			local row = rows[def.Id]
			if g.Owned[def.Id] then
				row.Needs.Text = "✓ Built"
				row.Needs.TextColor3 = ORANGE
				row.Button.Text = if ridingId == def.Id then "Hop off" else "Ride"
				row.Button.BackgroundColor3 = ORANGE
				row.Button.TextColor3 = Color3.fromRGB(40, 28, 6)
			else
				local parts = {}
				for _, crystal in Gloomwood.Crystals do
					local need = def.Cost[crystal.Id]
					if need then
						local have = vault[crystal.Id] or 0
						table.insert(parts, `{if have >= need then "✓" else "✗"} {crystal.Name} {have}/{need}`)
					end
				end
				local cost = essenceCost(data, def)
				table.insert(parts, `💎 {Format.Number(cost)}`)
				row.Needs.Text = table.concat(parts, "   ")
				local can = not def.ComingSoon and Vehicles.CanAfford(vault, def) and (data.Essence or 0) >= cost
				row.Needs.TextColor3 = if can then Color3.fromRGB(150, 255, 170) else T.SubText
				row.Button.Text = if def.ComingSoon then "Soon" else "Build"
				row.Button.BackgroundColor3 = if can then Color3.fromRGB(255, 200, 70) else T.GlassLight
				row.Button.TextColor3 = if can then Color3.fromRGB(40, 28, 6) else T.SubText
			end
		end
	end
	Ui.onPanelOpen("Hangar", render)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Hangar") then
			render()
		end
	end)
	player:GetAttributeChangedSignal("Riding"):Connect(function()
		if Ui.isOpen("Hangar") then
			render()
		end
	end)

	-- the 🛹 button, left of the 🏠 button
	local ride = Ui.button({
		Name = "RideButton",
		Text = "🛹",
		AnchorPoint = Vector2.new(1, 1),
		Variant = "Secondary",
		Parent = root,
	}, toggleRide)
	local caption = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(60, 14),
		Text = "Ride",
		Font = T.Font,
		TextColor3 = T.SubText,
		MaxTextSize = 12,
		Parent = ride,
	})
	local function arrange()
		local touch = Layout.Touch or Layout.Compact
		local size = if Layout.Compact then 46 else 54
		ride.Size = UDim2.fromOffset(size, size)
		-- two buttons left of the ⛏ button (the 🏠 is one left)
		ride.Position = if touch
			then UDim2.new(1, -24 - (size + 10) * 2, 1, -205)
			else UDim2.new(1, -20 - (size + 12) * 2, 1, -20)
	end
	Layout.Changed:Connect(arrange)
	arrange()
	local function refreshRide()
		local data = State.Data
		local owns = false
		for _ in (data and data.Vehicles and data.Vehicles.Owned) or {} do
			owns = true
			break
		end
		ride.Visible = owns
		local riding = player:GetAttribute("Riding")
		caption.Text = if riding then "Hop off" else "Ride"
		ride.BackgroundColor3 = if riding then ORANGE else T.GlassLight
	end
	player:GetAttributeChangedSignal("Riding"):Connect(refreshRide)
	State.Changed:Connect(function(key)
		if key == "Data" then
			refreshRide()
		end
	end)
	refreshRide()
	ContextActionService:BindAction("MythicRide", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggleRide()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R)
end

return HangarPanel
