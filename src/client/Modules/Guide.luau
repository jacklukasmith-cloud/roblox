--[[
	New-player guide, shown in the world instead of the HUD: a glowing line from you to the next
	goal and a bouncing arrow with a hint above it.
	  1. Break a crystal (any Meadow crystal)
	  2. Hatch an egg (the Meadow Egg)
	  3. Unlock Ember Rift (the gate, with Essence progress)
	Disappears for good once Ember Rift is unlocked.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Zones)
local Format = require(Shared.Format)

local Modules = script.Parent
local State = require(Modules.State)

local Guide = {}

local COLOR = Color3.fromRGB(255, 225, 90)

local function world(): Instance?
	return workspace:FindFirstChild("World")
end

-- Closest unbroken crystal in the first realm
local function nearestCrystal(from: Vector3): BasePart?
	local w = world()
	local zones = w and w:FindFirstChild("Zones")
	local meadow = zones and zones:FindFirstChild(Zones.List[1].Name)
	local folder = meadow and meadow:FindFirstChild("Crystals")
	if not folder then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, model in folder:GetChildren() do
		local main = model:IsA("Model") and model.PrimaryPart
		if main and model:GetAttribute("Breakable") == "Crystal" and main.Transparency < 1 then
			local dist = (main.Position - from).Magnitude
			if dist < bestDist then
				best, bestDist = main, dist
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

-- What to do next: (hint, target position) or nil when the guide is finished
function Guide.Step(data: any, from: Vector3): (string?, Vector3?)
	if not data or (data.ZonesUnlocked or 1) >= 2 then
		return nil, nil
	end
	local stats = data.Stats or {}
	if (stats.CrystalsBroken or 0) < 1 then
		local crystal = nearestCrystal(from)
		return "Click a crystal!", crystal and crystal.Position
	end
	if (stats.CreaturesHatched or 0) < 1 then
		local stand = eggStand(Zones.List[1].EggId)
		return "Hatch an egg here!", stand and stand:GetPivot().Position
	end
	local zone = Zones.List[2]
	local gate = gateTerminal(2)
	return `Unlock {zone.Name}: {Format.Number(data.Essence or 0)} / {Format.Number(zone.UnlockCost)}`,
		gate and gate.Position
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
			if root then
				text, target = Guide.Step(State.Data, root.Position)
			end
			if State.Data and (State.Data.ZonesUnlocked or 1) >= 2 then
				done = true -- finished for good
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

return Guide
