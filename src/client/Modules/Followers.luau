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
		local camera = workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		local count = 0
		for player, entry in byPlayer do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - camPos).Magnitude < DRAW_DISTANCE then
				for _, f in entry.List do
					local bob = math.sin(t * 2.5 + f.Phase) * 0.3
					local target = (root.CFrame * CFrame.new(f.Offset + Vector3.new(0, bob, 0))).Position
					local pos = f.Position
					if not pos or (pos - target).Magnitude > 60 then
						pos = target -- first frame / teleported / respawned
					end
					pos = (pos :: Vector3):Lerp(target, alpha)
					f.Position = pos
					-- Face where the player is heading
					local look = root.CFrame.LookVector
					local rig = f.Rig
					CreatureModels.Pose(rig, CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z)), t + f.Phase)
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
