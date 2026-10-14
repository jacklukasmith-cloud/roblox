--[[
	Renders every player's equipped creatures floating behind them. Done on each client
	(not the server) so movement is smooth and costs the server nothing.
	All parts are moved with a single workspace:BulkMoveTo call per frame.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)
local State = require(script.Parent.State)

local Followers = {}

type Follower = { Rig: CreatureModels.Rig, Offset: Vector3, Phase: number, Position: Vector3? }

local folder = Instance.new("Folder")
folder.Name = "Followers"
folder.Parent = workspace

local byPlayer: { [Player]: { Key: string, List: { Follower } } } = {}
local DRAW_DISTANCE = 160

local function clear(player: Player)
	local entry = byPlayer[player]
	if entry then
		for _, f in entry.List do
			f.Rig.Model:Destroy()
		end
	end
	byPlayer[player] = nil
end

local function rebuild(player: Player)
	local value = player:GetAttribute("Followers") or ""
	if State.PotatoMode then
		value = ""
	end
	local entry = byPlayer[player]
	if entry and entry.Key == value then
		return
	end
	clear(player)

	local rigs = {}
	for _, token in string.split(value, ",") do
		local parts = string.split(token, ":")
		local id, variant = parts[1], parts[2] or "Normal"
		if Creatures.Get(id) then
			local rig = CreatureModels.Build(id, variant)
			-- details for tap-to-inspect (PetInspect)
			rig.Model:SetAttribute("CreatureId", id)
			rig.Model:SetAttribute("Variant", variant)
			rig.Model:SetAttribute("OwnerId", player.UserId)
			rig.Model:SetAttribute("OwnerName", player.DisplayName)
			rig.Model:SetAttribute("Radius", rig.Radius)
			rig.Model.Parent = folder
			table.insert(rigs, rig)
		end
	end

	-- Arrange in rows of 4 behind the player, spaced by the biggest creature in each row
	local list = {}
	local z = 3
	for rowStart = 1, #rigs, 4 do
		local rowSize = math.min(4, #rigs - rowStart + 1)
		local radius = 1
		for i = rowStart, rowStart + rowSize - 1 do
			radius = math.max(radius, rigs[i].Radius)
		end
		local spacing = radius * 1.8 + 0.4
		z += radius
		for i = rowStart, rowStart + rowSize - 1 do
			local col = i - rowStart
			local x = (col - (rowSize - 1) / 2) * spacing
			table.insert(list, { Rig = rigs[i], Offset = Vector3.new(x, radius * 0.6 + 0.5, z), Phase = i * 0.9 })
		end
		z += radius + 0.6
	end
	byPlayer[player] = { Key = value, List = list }
end

local function track(player: Player)
	player:GetAttributeChangedSignal("Followers"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function Followers.Start()
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(clear)
	State.Changed:Connect(function(key)
		if key == "PotatoMode" then
			for _, player in Players:GetPlayers() do
				rebuild(player)
			end
		end
	end)

	local allParts: { BasePart } = {}
	local allCFrames: { CFrame } = {}

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local alpha = 1 - math.exp(-dt * 7)
		local alphaFast = 1 - math.exp(-dt * 10)
		local camera = workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		local count = 0
		for player, entry in byPlayer do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - camPos).Magnitude < DRAW_DISTANCE then
				-- Attacking a crystal? (Pet Simulator style: creatures surround it and pounce)
				local targetValue = player:FindFirstChild("PetTarget") :: ObjectValue?
				local target = targetValue and targetValue.Value
				local targetPos: Vector3? = nil
				local targetRadius = 0
				if target and target:IsA("Model") and target.Parent then
					local pivot, size = target:GetBoundingBox()
					targetPos = pivot.Position
					targetRadius = math.max(size.X, size.Z) / 2
				end
				local n = #entry.List
				for index, f in entry.List do
					local rig = f.Rig
					local desired: Vector3
					local facing: Vector3
					if targetPos then
						local angle = (index / n) * math.pi * 2 + t * 0.4
						local pounce = math.max(0, math.sin(t * 7 + f.Phase * 2)) * 1.2
						local radius = targetRadius + rig.Radius + 1.5 - pounce
						local ground = (targetPos :: Vector3).Y
						desired = Vector3.new(
							(targetPos :: Vector3).X + math.cos(angle) * radius,
							ground + rig.Radius * 0.4 + math.sin(t * 3 + f.Phase) * 0.3,
							(targetPos :: Vector3).Z + math.sin(angle) * radius
						)
						facing = ((targetPos :: Vector3) - desired) * Vector3.new(1, 0, 1)
					else
						local bob = math.sin(t * 2.5 + f.Phase) * 0.3
						desired = (root.CFrame * CFrame.new(f.Offset + Vector3.new(0, bob, 0))).Position
						local look = root.CFrame.LookVector
						facing = Vector3.new(look.X, 0, look.Z)
					end
					local pos = f.Position
					if not pos or (pos - desired).Magnitude > 120 then
						pos = desired -- first frame / teleported / respawned
					end
					local speed = if targetPos then alphaFast else alpha
					pos = (pos :: Vector3):Lerp(desired, speed)
					f.Position = pos
					if facing.Magnitude < 0.01 then
						facing = Vector3.new(0, 0, -1)
					end
					CreatureModels.Pose(rig, CFrame.lookAt(pos, pos + facing.Unit), t + f.Phase)
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

return Followers
