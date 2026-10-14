--[[
	Tap (or click) any creature following a player to see its stats: name, rarity, variant,
	power and whose creature it is. Works on everyone's pets.

	Creature parts don't take part in raycasts, so the tap is matched on screen: the
	follower whose centre is closest to the tap (within its on-screen size) wins.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Creatures)
local Format = require(Shared.Format)

local Modules = script.Parent
local Ui = require(Modules.Ui)

local T = Ui.Theme

local PetInspect = {}

-- Finds the follower creature under a screen position (or nil)
local function pick(screenPos: Vector2): Model?
	local camera = workspace.CurrentCamera
	local folder = workspace:FindFirstChild("Followers")
	if not camera or not folder then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, model in folder:GetChildren() do
		local root = model:IsA("Model") and model.PrimaryPart
		if root then
			local center, onScreen = camera:WorldToScreenPoint(root.Position)
			if onScreen and center.Z > 0 then
				local radius = tonumber(model:GetAttribute("Radius")) or 1.5
				local edge = camera:WorldToScreenPoint(root.Position + camera.CFrame.RightVector * radius)
				local reach = math.max(28, (Vector2.new(edge.X, edge.Y) - Vector2.new(center.X, center.Y)).Magnitude)
				local dist = (Vector2.new(center.X, center.Y) - screenPos).Magnitude
				-- when several overlap the tap, take the one closest to the camera
				if dist <= reach and center.Z < bestDist then
					best, bestDist = model, center.Z
				end
			end
		end
	end
	return best
end

function PetInspect.Start(root: Frame)
	local player = Players.LocalPlayer
	local card = Ui.glass({
		Name = "PetCard",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.fromOffset(300, 112),
		Visible = false,
		ZIndex = 30,
		Parent = root,
	}, { Ui.corner(14) })
	local scale = Ui.new("UIScale", { Parent = card })
	local nameLabel = Ui.text({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 28),
		Text = "",
		Font = T.FontHeavy,
		ZIndex = 31,
		MaxTextSize = 24,
		Parent = card,
	})
	local rarityLabel = Ui.text({
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "",
		Font = T.Font,
		ZIndex = 31,
		MaxTextSize = 16,
		Parent = card,
	})
	local powerLabel = Ui.text({
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "",
		Font = T.Font,
		TextColor3 = T.Power,
		ZIndex = 31,
		MaxTextSize = 16,
		Parent = card,
	})
	local ownerLabel = Ui.text({
		Position = UDim2.fromOffset(14, 84),
		Size = UDim2.new(1, -28, 0, 18),
		Text = "",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		ZIndex = 31,
		MaxTextSize = 14,
		Parent = card,
	})
	local edge = card:FindFirstChildOfClass("UIStroke")
	local token = 0

	local function show(model: Model)
		local id = model:GetAttribute("CreatureId")
		local def = type(id) == "string" and Creatures.Get(id)
		if not def then
			return
		end
		local variant = tostring(model:GetAttribute("Variant") or "Normal")
		local rarity = Creatures.Rarities[def.Rarity]
		nameLabel.Text = Creatures.DisplayName(def.Id, variant)
		nameLabel.TextColor3 = rarity.Color
		rarityLabel.Text = if variant == "Normal" then def.Rarity else `{def.Rarity}  ·  {variant}`
		rarityLabel.TextColor3 = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.3)
		powerLabel.Text = `💪 Power {Format.Number(Creatures.GetPower(def.Id, variant))}`
		local ownerId = model:GetAttribute("OwnerId")
		ownerLabel.Text = if ownerId == player.UserId
			then "🐾 Your creature (equipped)"
			else `🐾 {model:GetAttribute("OwnerName") or "Someone"}'s creature`
		if edge then
			edge.Color = rarity.Color
			edge.Transparency = 0.2
		end
		card.Visible = true
		scale.Scale = 0.7
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		token += 1
		local myToken = token
		task.delay(4, function()
			if token == myToken then
				card.Visible = false
			end
		end)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local model = pick(Vector2.new(input.Position.X, input.Position.Y))
		if model then
			show(model)
		elseif card.Visible then
			token += 1
			card.Visible = false
		end
	end)
end

return PetInspect
