--[[
	The 🗺️ Gloomwood map: a top-down view of the forest rings with you on it. Landmarks appear as you
	find their Map Fragments (Shared/Gloomwood.Fragments); find enough and every Courier Lantern
	shows too. Opens from the button on the forest pill (GloomwoodClient).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gloomwood = require(ReplicatedStorage.Shared.Gloomwood)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)

local T = Ui.Theme

local GloomMapPanel = {}

local rgb = Color3.fromRGB

local LANDMARKS = {
	{ Key = "Gate", Icon = "🌲", Name = "The gate" },
	{ Key = "DeepCamp", Icon = "⛺", Name = "Deep Camp" },
	{ Key = "BurntClearing", Icon = "🔥", Name = "Burnt Clearing" },
	{ Key = "FrozenPond", Icon = "❄️", Name = "Frozen Pond" },
	{ Key = "DeadTree", Icon = "🌳", Name = "Old Dead Tree" },
	{ Key = "Watchtower", Icon = "🗼", Name = "Broken Watchtower" },
	{ Key = "Cliffs", Icon = "⛰️", Name = "The cliffs (Stormquartz)", Angle = 1.7, Distance = 185 },
	{ Key = "Caves", Icon = "🕳️", Name = "The caves (Voidstone)", Angle = 4.6, Distance = 112 },
	{ Key = "Heart", Icon = "💜", Name = "The Heart (Prismheart)", Angle = 0, Distance = 0 },
}

function GloomMapPanel.Build(screen: Frame)
	local player = Players.LocalPlayer
	local _, content = Ui.panel(screen, "GloomMap", "Gloomwood Map", UDim2.fromOffset(640, 560), "🗺️")
	local found = Ui.text({
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		Font = T.FontHeavy,
		TextColor3 = rgb(255, 230, 170),
		MaxTextSize = 17,
		Parent = content,
	})
	-- a square that fits whatever room the window has (phones included)
	local map = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.new(1, 0, 1, -76),
		BackgroundColor3 = rgb(18, 22, 20),
		Parent = content,
	}, { Ui.round(), Ui.stroke(rgb(90, 110, 90), 2), Ui.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	-- the rings
	local function ring(radius: number, color: Color3)
		local f = radius / Gloomwood.Radius
		return Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(f, f),
			BackgroundColor3 = color,
			Parent = map,
		}, { Ui.round() })
	end
	ring(Gloomwood.Radius, rgb(40, 58, 40))
	ring(Gloomwood.RingEdge, rgb(30, 42, 34))
	ring(Gloomwood.RingMid, rgb(20, 18, 26))
	ring(Gloomwood.RingHeart, rgb(44, 28, 60))
	local function at(position: Vector3): UDim2
		local flat = position - Gloomwood.Center
		return UDim2.fromScale(0.5 + flat.X / Gloomwood.Radius / 2, 0.5 + flat.Z / Gloomwood.Radius / 2)
	end
	local lanternDots = Ui.new("Folder", { Parent = map })
	local landmarkIcons: { [string]: TextLabel } = {}
	for _, mark in LANDMARKS do
		local pos = if mark.Angle then Gloomwood.At(mark.Angle, mark.Distance) else Gloomwood.Place(mark.Key)
		landmarkIcons[mark.Key] = Ui.text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = at(pos),
			Size = UDim2.fromOffset(26, 26),
			Text = mark.Icon,
			MaxTextSize = 20,
			Visible = false,
			ZIndex = 3,
			Parent = map,
		})
	end
	-- you (always shown), with a little arrow for where you're facing
	local me = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = rgb(120, 220, 255),
		ZIndex = 5,
		Parent = map,
	}, { Ui.round(), Ui.stroke(Color3.new(1, 1, 1), 2) })
	local legend = Ui.text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextWrapped = true,
		MaxTextSize = 14,
		Parent = content,
	})

	local lanternsDrawn = false
	local function render()
		local data = State.Data
		local map_ = data and data.Gloom and data.Gloom.Map or {}
		local n = 0
		local revealed = { Gate = true } -- you always know where you came in
		for i, f in Gloomwood.Fragments do
			if map_[i] then
				n += 1
				revealed[f.Reveals] = true
			end
		end
		found.Text = `🗺️ Map Fragments: {n}/{#Gloomwood.Fragments}`
		for key, icon in landmarkIcons do
			icon.Visible = revealed[key] == true
		end
		local names = {}
		for _, mark in LANDMARKS do
			if revealed[mark.Key] then
				table.insert(names, `{mark.Icon} {mark.Name}`)
			end
		end
		legend.Text = if n >= #Gloomwood.Fragments
			then "You've mapped the whole forest!  " .. table.concat(names, "  ")
			else `Find glowing scrolls near the landmarks to fill the map in.  {table.concat(names, "  ")}`
		-- lanterns show once you've found enough fragments
		if n >= Gloomwood.MapLanternsAt and not lanternsDrawn then
			lanternsDrawn = true
			local forest = workspace:FindFirstChild("Gloomwood")
			local lanterns = forest and forest:FindFirstChild("Lanterns")
			for _, lamp in if lanterns then lanterns:GetChildren() else {} do
				if lamp:IsA("Model") and lamp.PrimaryPart then
					Ui.new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = at(lamp.PrimaryPart.Position),
						Size = UDim2.fromOffset(6, 6),
						BackgroundColor3 = rgb(255, 210, 120),
						ZIndex = 2,
						Parent = lanternDots,
					}, { Ui.round() })
				end
			end
		end
	end

	Ui.onPanelOpen("GloomMap", render)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("GloomMap") then
			render()
		end
	end)
	-- follow the player while the map's open
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < 0.2 or not Ui.isOpen("GloomMap") then
			return
		end
		since = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			me.Position = at(root.Position)
			me.Visible = Gloomwood.RingAt(root.Position) ~= nil
		end
	end)
end

return GloomMapPanel
