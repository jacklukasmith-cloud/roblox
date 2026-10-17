--[[
	The Gloomwood on your screen: thick dark fog while you're in the forest (put back when you
	leave), and a small card at the top with your satchel and the Gloom meter.
	The server sets the player attributes InGloomwood and Gloom (Services/Gloomwood).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Gloomwood = require(ReplicatedStorage.Shared.Gloomwood)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)

local T = Ui.Theme

local GloomwoodClient = {}

local rgb = Color3.fromRGB
local PURPLE = rgb(170, 110, 255)

-- The forest look (only on this client; the rest of the world is untouched)
local LIGHTING = {
	ClockTime = 18.3,
	Brightness = 1.1,
	OutdoorAmbient = rgb(70, 85, 90),
	Ambient = rgb(45, 40, 65),
	FogColor = rgb(40, 55, 50),
	FogStart = 10,
	FogEnd = 110,
}
local ATMOSPHERE = {
	Density = 0.55,
	Offset = 0,
	Color = rgb(65, 85, 75),
	Decay = rgb(55, 40, 80),
	Glare = 0,
	Haze = 2.6,
}

local saved: { [string]: any }? = nil
local savedAtmosphere: { [string]: any }? = nil

local function apply()
	saved = saved or {}
	for key, value in LIGHTING do
		if (saved :: any)[key] == nil then
			(saved :: any)[key] = (Lighting :: any)[key]
		end
		if (Lighting :: any)[key] ~= value then
			(Lighting :: any)[key] = value
		end
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		savedAtmosphere = savedAtmosphere or {}
		for key, value in ATMOSPHERE do
			if (savedAtmosphere :: any)[key] == nil then
				(savedAtmosphere :: any)[key] = (atmosphere :: any)[key]
			end
			if (atmosphere :: any)[key] ~= value then
				(atmosphere :: any)[key] = value
			end
		end
	end
end

local function restore()
	if saved then
		for key, value in saved do
			(Lighting :: any)[key] = value
		end
		saved = nil
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and savedAtmosphere then
		for key, value in savedAtmosphere do
			(atmosphere :: any)[key] = value
		end
	end
	savedAtmosphere = nil
end

function GloomwoodClient.Build(root: Frame)
	local player = Players.LocalPlayer
	local card = Ui.new("Frame", {
		Name = "GloomCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(280, 58),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = root,
	}, { Ui.corner(12), Ui.stroke(PURPLE, 1.2) })
	local satchel = Ui.text({
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Parent = card,
	})
	local barBack = Ui.new("Frame", {
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 16),
		BackgroundColor3 = rgb(25, 20, 35),
		Parent = card,
	}, { Ui.corner(8) })
	local fill = Ui.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = PURPLE,
		Parent = barBack,
	}, { Ui.corner(8) })
	local gloomText = Ui.text({
		Size = UDim2.fromScale(1, 1),
		Text = "🌑 Gloom",
		Font = T.FontHeavy,
		MaxTextSize = 12,
		Parent = barBack,
	})

	local function update()
		local inside = player:GetAttribute("InGloomwood") == true
		local gloom = tonumber(player:GetAttribute("Gloom")) or 0
		card.Visible = inside
		if inside then
			apply()
		elseif saved or savedAtmosphere then
			restore()
		end
		if inside then
			local data = State.Data
			local count = Gloomwood.SatchelCount(data and data.Gloom and data.Gloom.Satchel)
			satchel.Text = `🎒 Satchel {count}/{Gloomwood.SatchelSize}`
			satchel.TextColor3 = if count >= Gloomwood.SatchelSize then rgb(255, 150, 110) else T.Text
			local frac = math.clamp(gloom / Gloomwood.Gloom.Max, 0, 1)
			TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(frac, 1) }):Play()
			fill.BackgroundColor3 = if gloom >= Gloomwood.Gloom.Warn then rgb(255, 90, 150) else PURPLE
			gloomText.Text = `🌑 Gloom {math.floor(frac * 100)}%`
		end
	end

	player:GetAttributeChangedSignal("InGloomwood"):Connect(update)
	player:GetAttributeChangedSignal("Gloom"):Connect(update)
	State.Changed:Connect(function(key)
		if key == "Data" then
			update()
		end
	end)
	-- the server can change the lighting (weather): keep the forest look while inside
	task.spawn(function()
		while true do
			task.wait(1)
			if player:GetAttribute("InGloomwood") == true then
				apply()
			end
		end
	end)
	update()
end

return GloomwoodClient
