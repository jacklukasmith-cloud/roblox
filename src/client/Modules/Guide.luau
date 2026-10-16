--[[
	The mission guide (missions are in Shared/Missions):
	  - in the world: a glowing line from you to where the current mission happens, with a bouncing
	    arrow and a hint above it. Shown automatically for the first few missions; after that, tap
	    the mission card to turn it on or off.
	  - on screen: a small mission card under the left menu (mission, progress, reward).
	  - a fanfare and a message when a mission is done.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Zones)
local Format = require(Shared.Format)
local Missions = require(Shared.Missions)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local State = require(Modules.State)
local Ui = require(Modules.Ui)
local Sound = require(Modules.Sound)
local Layout = require(Modules.Layout)

local T = Ui.Theme
local AUTO_GUIDE_UNTIL = 8 -- the arrow shows by itself up to the Blacksmith mission, then only when asked

local Guide = {}

local COLOR = Color3.fromRGB(255, 225, 90)

local function world(): Instance?
	return workspace:FindFirstChild("World")
end

-- Closest unbroken crystal in any realm you've unlocked
local function nearestCrystal(from: Vector3, zonesUnlocked: number): BasePart?
	local w = world()
	local zones = w and w:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	local best, bestDist = nil, math.huge
	for i = 1, math.min(zonesUnlocked, #Zones.List) do
		local realm = zones:FindFirstChild(Zones.List[i].Name)
		local folder = realm and realm:FindFirstChild("Crystals")
		for _, model in if folder then folder:GetChildren() else {} do
			local main = model:IsA("Model") and model.PrimaryPart
			if main and model:GetAttribute("Breakable") == "Crystal" and main.Transparency < 1 then
				local dist = (main.Position - from).Magnitude
				if dist < bestDist then
					best, bestDist = main, dist
				end
			end
		end
	end
	return best
end

local function eggStand(eggId: string): Model?
	local w = world()
	if not w then
		return nil
	end
	for _, d in w:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("EggId") == eggId then
			return d
		end
	end
	return nil
end

local function gateTerminal(zoneIndex: number): BasePart?
	local w = world()
	if not w then
		return nil
	end
	for _, d in w:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("ZoneIndex") == zoneIndex then
			local terminal = d:FindFirstChild("GateTerminal")
			return if terminal and terminal:IsA("BasePart") then terminal else d
		end
	end
	return nil
end

local function blacksmithPad(): BasePart?
	local w = world()
	local pad = w and w:FindFirstChild("BlacksmithPad", true)
	return if pad and pad:IsA("BasePart") then pad else nil
end

local function activeBoss(): Model?
	local w = world()
	local bosses = w and w:FindFirstChild("Bosses")
	for _, boss in if bosses then bosses:GetChildren() else {} do
		if boss:IsA("Model") then
			return boss
		end
	end
	return nil
end

-- Where the current mission happens (nil = nowhere in particular / not around right now)
local function targetFor(target: string?, data: any, from: Vector3): Vector3?
	local unlocked = data.ZonesUnlocked or 1
	if target == "Crystal" then
		local crystal = nearestCrystal(from, unlocked)
		return crystal and crystal.Position
	elseif target == "Egg" then
		local zone = Zones.List[math.min(unlocked, #Zones.List)]
		local stand = eggStand(zone.EggId)
		return stand and stand:GetPivot().Position
	elseif target == "Gate" then
		local gate = gateTerminal(unlocked + 1)
		return gate and gate.Position
	elseif target == "Blacksmith" then
		local pad = blacksmithPad()
		return pad and pad.Position
	elseif target == "Boss" then
		local boss = activeBoss()
		return boss and boss:GetPivot().Position
	end
	return nil
end

-- One line describing the mission and how far along it is
function Guide.MissionText(data: any): string?
	local mission, progress, goal = Missions.Current(data)
	if not mission then
		return nil
	end
	if mission.Stat == "ZonesUnlocked" then
		local zone = Zones.List[goal]
		if zone then
			return `{mission.Text}: {Format.Number(data.Essence or 0)} / {Format.Number(zone.UnlockCost)}`
		end
	end
	-- a counter makes sense for "do N" and "discover N", not for a pickaxe tier
	if goal > 1 and mission.Stat ~= "Pickaxe" and mission.Stat ~= "Rebirths" then
		return `{mission.Text} ({progress}/{goal})`
	end
	return mission.Text
end

-- What to do next: (hint, target position) or nil when there's nothing to point at
function Guide.Step(data: any, from: Vector3): (string?, Vector3?)
	if not data then
		return nil, nil
	end
	local mission = Missions.Current(data)
	if not mission then
		return nil, nil
	end
	return Guide.MissionText(data), targetFor(mission.Target, data, from)
end

-- Should the arrow show right now? (on by itself early on; the mission card toggles it)
function Guide.Showing(data: any): boolean
	if State.ShowWay ~= nil then
		return State.ShowWay
	end
	local index = data and data.Missions and data.Missions.Index or 1
	return index <= AUTO_GUIDE_UNTIL
end

function Guide.Start()
	local player = Players.LocalPlayer
	-- the arrow + hint, and the line from you to it
	local marker = Instance.new("Part")
	marker.Name = "GuideMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.one
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = marker
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 90)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = marker
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, 0, 0.45, 0)
	hint.Font = Enum.Font.FredokaOne
	hint.TextScaled = true
	hint.TextColor3 = COLOR
	hint.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = hint
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Position = UDim2.fromScale(0, 0.45)
	arrow.Size = UDim2.new(1, 0, 0.55, 0)
	arrow.Font = Enum.Font.FredokaOne
	arrow.Text = "⬇"
	arrow.TextScaled = true
	arrow.TextColor3 = COLOR
	arrow.Parent = gui
	local beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(COLOR)
	beam.Transparency = NumberSequence.new(0.35)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 0.35
	beam.Width1 = 0.35
	beam.Segments = 1
	beam.Attachment1 = targetAttachment
	beam.Parent = marker

	local done = false
	-- bounce the arrow
	local bounce = RunService.RenderStepped:Connect(function()
		if marker.Parent then
			gui.StudsOffsetWorldSpace = Vector3.new(0, 6 + math.sin(os.clock() * 4) * 0.6, 0)
		end
	end)
	task.spawn(function()
		while not done do
			task.wait(0.4)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local text, target = nil, nil
			if root and Guide.Showing(State.Data) then
				text, target = Guide.Step(State.Data, root.Position)
			end
			if State.Data and not Missions.Current(State.Data) then
				done = true -- every mission finished
			end
			-- hide it once you're standing at the spot
			if target and root and (target - root.Position).Magnitude < 9 then
				target = nil
			end
			if text and target and root then
				hint.Text = text
				marker.Position = target
				local from = root:FindFirstChild("GuideAttachment") :: Attachment?
				if not from then
					local a = Instance.new("Attachment")
					a.Name = "GuideAttachment"
					a.Position = Vector3.new(0, -2.5, 0)
					a.Parent = root
					from = a
				end
				beam.Attachment0 = from
				marker.Parent = workspace
			else
				marker.Parent = nil
			end
		end
		bounce:Disconnect()
		marker:Destroy()
	end)
end

-- The mission card under the left menu. Tap it to show/hide the arrow.
function Guide.BuildTracker(root: Frame)
	local holder = root:FindFirstChild("MenuHolder") :: Frame?
	local card = Ui.glass({
		Name = "MissionCard",
		Position = UDim2.new(0, 0, 1, 8),
		Size = UDim2.fromOffset(230, 54),
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = holder or root,
	}, { Ui.corner(12) })
	local scale = Ui.new("UIScale", { Parent = card })
	local caption = Ui.text({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -40, 0, 16),
		Text = "",
		Font = T.FontHeavy,
		TextColor3 = T.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		Parent = card,
	})
	local pin = Ui.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 3),
		Size = UDim2.fromOffset(22, 18),
		Text = "📍",
		MaxTextSize = 14,
		Parent = card,
	})
	local label = Ui.text({
		Position = UDim2.fromOffset(10, 20),
		Size = UDim2.new(1, -20, 0, 20),
		Text = "",
		Font = T.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = card,
	})
	local barBack = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -6),
		Size = UDim2.new(1, -20, 0, 5),
		BackgroundColor3 = T.GlassLight,
		Parent = card,
	}, { Ui.round() })
	local barFill = Ui.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = T.Gold,
		Parent = barBack,
	}, { Ui.round() })
	local button = Ui.new("TextButton", {
		Name = "Toggle",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = card,
	})

	local function refresh()
		local data = State.Data
		local mission, progress, goal = Missions.Current(data)
		card.Visible = data ~= nil and mission ~= nil
		if not data or not mission then
			return
		end
		local index = data.Missions and data.Missions.Index or 1
		caption.Text = `📜 MISSION {index}/{#Missions.List}  ·  {Missions.RewardText(mission.Reward, Format.Number)}`
		label.Text = Guide.MissionText(data) or mission.Text
		barFill.Size = UDim2.fromScale(if goal > 0 then progress / goal else 0, 1)
		pin.TextTransparency = if Guide.Showing(data) and mission.Target then 0 else 0.7
		card.Size = UDim2.fromOffset(if Layout.Compact then 200 else 230, 54)
	end

	button.Activated:Connect(function()
		local data = State.Data
		local mission = Missions.Current(data)
		if not mission then
			return
		end
		local on = not Guide.Showing(data)
		State.Set("ShowWay", on)
		Sound.Play("Click", 1.2)
		if on and mission.Hint then
			Ui.toast(`💡 {mission.Hint}`, T.Gold)
		elseif on and not mission.Target then
			Ui.toast(`💡 {mission.Text}`, T.Gold)
		end
		refresh()
	end)

	State.Changed:Connect(function(key)
		if key == "Data" or key == "ShowWay" then
			refresh()
		end
	end)
	Layout.Changed:Connect(refresh)
	refresh()

	-- Mission done: fanfare, a pop on the card and what's next
	Remotes.Event("MissionComplete").OnClientEvent:Connect(function(title, reward, nextText)
		Sound.Play("Fanfare", 1.1)
		Ui.toast(`✅ {title}!  {reward}`, T.Gold)
		scale.Scale = 1.15
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if type(nextText) == "string" then
			task.delay(1.6, function()
				local data = State.Data
				local mission = Missions.Current(data)
				Ui.toast(`📜 Next: {nextText}`, T.Text)
				if mission and mission.Hint and Guide.Showing(data) then
					task.delay(1.6, function()
						Ui.toast(`💡 {mission.Hint}`, T.SubText)
					end)
				end
			end)
		else
			task.delay(1.6, function()
				Ui.toast("🏆 You finished every mission. You're a Master Tamer!", T.Gold)
			end)
		end
	end)
end

return Guide
