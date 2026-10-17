--[[
	The Gloomwood on your screen: dark fog while you're in the forest that gets thicker and darker
	the deeper you go (put back when you leave), and a small card at the top with your satchel and
	the Gloom meter.
	The server sets the player attributes InGloomwood and Gloom (Services/Gloomwood).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Gloomwood = require(ReplicatedStorage.Shared.Gloomwood)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Layout = require(Modules.Layout)
local Sound = require(Modules.Sound)

local T = Ui.Theme

local GloomwoodClient = {}

local rgb = Color3.fromRGB
local PURPLE = rgb(170, 110, 255)

-- The forest look (only on this client; the rest of the world is untouched). The first value is
-- at the forest's edge, the second at its very centre (Gloomwood.Depth); in between they blend,
-- so it keeps getting darker the further in you walk.
local LIGHTING = {
	ClockTime = { 17.6, 19.0 },
	Brightness = { 1.6, 0.3 },
	OutdoorAmbient = { rgb(95, 110, 110), rgb(25, 25, 40) },
	Ambient = { rgb(60, 58, 80), rgb(20, 15, 35) },
	FogColor = { rgb(55, 70, 65), rgb(12, 12, 20) },
	FogStart = { 20, 0 },
	FogEnd = { 220, 55 },
}
local ATMOSPHERE = {
	Density = { 0.38, 0.8 },
	Offset = { 0, 0 },
	Color = { rgb(85, 105, 95), rgb(25, 30, 35) },
	Decay = { rgb(70, 55, 95), rgb(25, 15, 40) },
	Glare = { 0, 0 },
	Haze = { 1.8, 3 },
}

-- With an Owl Eye Potion: as if you were only this deep, and these on top (fog much further away)
local VISION_DEPTH = 0.3
local VISION = {
	FogEnd = 2.2, -- times
	Density = 0.5,
	Haze = 0.5,
	Brightness = 1.4,
}

local function blend(pair: { any }, t: number): any
	local a, b = pair[1], pair[2]
	if type(a) == "number" then
		return a + (b - a) * t
	end
	return a:Lerp(b, t) -- a Color3
end

-- Only change a property when it's really different (setting it every frame isn't free)
local function differs(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) > 0.002
	elseif typeof(a) == typeof(b) and type(b) ~= "number" and a ~= nil then
		-- Color3s
		return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) > 0.004
	end
	return true
end

local saved: { [string]: any }? = nil
local savedAtmosphere: { [string]: any }? = nil

local function hasVision(): boolean
	local data = State.Data
	local endsAt = data and data.Boosts and data.Boosts.Vision
	return endsAt ~= nil and endsAt > State.Now()
end

-- depth: 0 = the forest's edge, 1 = its centre
local function apply(depth: number)
	local vision = hasVision()
	if vision then
		depth *= VISION_DEPTH
	end
	saved = saved or {}
	for key, pair in LIGHTING do
		if (saved :: any)[key] == nil then
			(saved :: any)[key] = (Lighting :: any)[key]
		end
		local value = blend(pair, depth)
		if vision and VISION[key] then
			value *= VISION[key]
		end
		if differs((Lighting :: any)[key], value) then
			(Lighting :: any)[key] = value
		end
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		savedAtmosphere = savedAtmosphere or {}
		for key, pair in ATMOSPHERE do
			if (savedAtmosphere :: any)[key] == nil then
				(savedAtmosphere :: any)[key] = (atmosphere :: any)[key]
			end
			local value = blend(pair, depth)
			if vision and VISION[key] then
				value *= VISION[key]
			end
			if differs((atmosphere :: any)[key], value) then
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
	-- one slim pill at the top (where the boss bar would be; it's hidden in the forest):
	-- 🎒 satchel count on the left, a thin Gloom bar on the right
	local card = Ui.new("Frame", {
		Name = "GloomCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(210, 28),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = root,
	}, { Ui.round(), Ui.stroke(PURPLE, 1) })
	local satchel = Ui.text({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0, 72, 1, 0),
		Text = "",
		Font = T.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		Parent = card,
	})
	local barBack = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(1, -100, 0, 10),
		BackgroundColor3 = rgb(25, 20, 35),
		Parent = card,
	}, { Ui.round() })
	local fill = Ui.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = PURPLE,
		Parent = barBack,
	}, { Ui.round() })
	Ui.text({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -4, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		Text = "🌑",
		MaxTextSize = 13,
		Parent = barBack,
	})
	local function arrange()
		-- just under the top-centre Mana Surge banner (which sits in the top bar on phones)
		card.Position = UDim2.new(0.5, 0, 0, if Layout.Compact then 30 else 60)
	end
	Layout.Changed:Connect(arrange)
	arrange()

	-- how deep you are, eased so a jump (the Deep Camp shortcut) fades in rather than snapping
	local depth: number? = nil
	local function targetDepth(): number
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return if root then Gloomwood.Depth(root.Position) else depth or 0
	end

	local function update()
		local inside = player:GetAttribute("InGloomwood") == true
		local gloom = tonumber(player:GetAttribute("Gloom")) or 0
		card.Visible = inside
		if inside then
			depth = depth or targetDepth()
			apply(depth :: number)
		elseif saved or savedAtmosphere then
			restore()
			depth = nil
		end
		if inside then
			local data = State.Data
			local count = Gloomwood.SatchelCount(data and data.Gloom and data.Gloom.Satchel)
			satchel.Text = `🎒 {count}/{Gloomwood.SatchelSize}`
			satchel.TextColor3 = if count >= Gloomwood.SatchelSize then rgb(255, 150, 110) else T.Text
			local frac = math.clamp(gloom / Gloomwood.Gloom.Max, 0, 1)
			TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(frac, 1) }):Play()
			fill.BackgroundColor3 = if gloom >= Gloomwood.Gloom.Warn then rgb(255, 90, 150) else PURPLE
		end
	end

	player:GetAttributeChangedSignal("InGloomwood"):Connect(update)
	player:GetAttributeChangedSignal("Gloom"):Connect(update)
	State.Changed:Connect(function(key)
		if key == "Data" then
			update()
		end
	end)
	-- a forest animal hit you: a shove, a red flash and a word about the Gloom it cost
	local flash = Ui.new("Frame", {
		Name = "BeastFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = rgb(200, 20, 40),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = root,
	})
	Remotes.Event("BeastHit").OnClientEvent:Connect(function(beastId, push)
		local def = type(beastId) == "string" and Gloomwood.GetBeast(beastId)
		if not def then
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and typeof(push) == "Vector3" then
			hrp.AssemblyLinearVelocity = push * 45 + Vector3.new(0, 28, 0)
		end
		flash.BackgroundTransparency = 0.6
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		Sound.Play("Hit", 0.6, 1)
		Ui.toast(`{def.Icon} {def.Name}! +{def.Gloom} Gloom`, rgb(255, 120, 140))
	end)

	-- follow how deep you are (10 times a second is plenty). This also keeps the forest look if
	-- the server changes the lighting (weather) while you're inside.
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < 0.1 or player:GetAttribute("InGloomwood") ~= true then
			return
		end
		local step = since
		since = 0
		local target = targetDepth()
		local current = depth or target
		depth = current + (target - current) * math.min(1, step * 1.5)
		apply(depth :: number)
	end)
	update()
end

return GloomwoodClient
