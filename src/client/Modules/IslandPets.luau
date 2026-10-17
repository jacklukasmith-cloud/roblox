--[[
	Draws the Pet Habitat pets wandering around every Sanctuary island (the island model's "Habitat"
	attribute lists them). Done on each client like the followers, so it costs the server nothing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)
local State = require(script.Parent.State)

local IslandPets = {}

type Pet = {
	Rig: CreatureModels.Rig,
	Position: Vector3,
	Goal: Vector3,
	Facing: Vector3,
	WaitUntil: number,
	Phase: number,
}

local DRAW_DISTANCE = 260
local WALK_SPEED = 4
local folder: Folder? = nil
local byIsland: { [Model]: { Key: string, Pets: { Pet } } } = {}

local function clear(island: Model)
	local entry = byIsland[island]
	if entry then
		for _, pet in entry.Pets do
			pet.Rig.Model:Destroy()
		end
	end
	byIsland[island] = nil
end

-- Somewhere on the grass to walk to (away from the edge)
local function randomSpot(ground: BasePart, rng: Random): Vector3
	local r = ground.Size.Y / 2 * 0.62
	local a = rng:NextNumber() * math.pi * 2
	local d = math.sqrt(rng:NextNumber()) * r
	return ground.Position + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
end

local rng = Random.new()

local function rebuild(island: Model)
	local key = island:GetAttribute("Habitat") or ""
	if State.PotatoMode then
		key = ""
	end
	local entry = byIsland[island]
	if entry and entry.Key == key then
		return
	end
	clear(island)
	local ground = island.PrimaryPart
	local pets = {}
	if ground and key ~= "" then
		for i, token in string.split(key, ",") do
			local bits = string.split(token, ":")
			if Creatures.Get(bits[1]) then
				local ok, rig = pcall(CreatureModels.Build, bits[1], bits[2] or "Normal")
				if ok then
					rig.Model.Parent = folder
					local start = randomSpot(ground, rng)
					table.insert(pets, {
						Rig = rig,
						Position = start,
						Goal = start,
						Facing = Vector3.new(0, 0, -1),
						WaitUntil = 0,
						Phase = i * 1.3,
					})
				end
			end
		end
	end
	byIsland[island] = { Key = key, Pets = pets }
end

function IslandPets.Start()
	local f = Instance.new("Folder")
	f.Name = "IslandPets"
	f.Parent = workspace
	folder = f

	-- islands come and go (players join, leave, upgrade): check every second
	task.spawn(function()
		while true do
			local islands = workspace:FindFirstChild("Sanctuaries")
			local alive = {}
			for _, island in if islands then islands:GetChildren() else {} do
				if island:IsA("Model") then
					alive[island] = true
					rebuild(island)
				end
			end
			for island in byIsland do
				if not alive[island] or not island.Parent then
					clear(island)
				end
			end
			task.wait(1)
		end
	end)

	local allParts: { BasePart } = {}
	local allCFrames: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		local count = 0
		for island, entry in byIsland do
			local ground = island.PrimaryPart
			if ground and #entry.Pets > 0 and (ground.Position - camPos).Magnitude < DRAW_DISTANCE then
				-- the grass top is 1.5 above the ground part's middle
				local top = ground.Position.Y + 1.7
				for _, pet in entry.Pets do
					local rig = pet.Rig
					local flat = (pet.Goal - pet.Position) * Vector3.new(1, 0, 1)
					if flat.Magnitude < 0.3 then
						-- arrived: look around a bit, then pick somewhere new
						if pet.WaitUntil == 0 then
							pet.WaitUntil = t + rng:NextNumber(1.5, 4)
						elseif t >= pet.WaitUntil then
							pet.Goal = randomSpot(ground, rng)
							pet.WaitUntil = 0
						end
					else
						pet.Facing = flat.Unit
						pet.Position += flat.Unit * math.min(flat.Magnitude, WALK_SPEED * dt)
					end
					local hop = if flat.Magnitude >= 0.3 then math.abs(math.sin(t * 6 + pet.Phase)) * 0.4 else 0
					local pos = Vector3.new(pet.Position.X, top + rig.Radius * 0.7 + hop, pet.Position.Z)
					CreatureModels.Pose(rig, CFrame.lookAt(pos, pos + pet.Facing), t + pet.Phase)
					for i, part in rig.Parts do
						count += 1
						allParts[count] = part
						allCFrames[count] = rig.CFrames[i]
					end
				end
			end
		end
		for i = count + 1, #allParts do
			allParts[i] = nil
			allCFrames[i] = nil
		end
		if count > 0 then
			workspace:BulkMoveTo(allParts, allCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return IslandPets
