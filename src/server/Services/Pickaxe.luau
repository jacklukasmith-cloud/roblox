--[[
	The player's own pickaxe, so you're not just watching your creatures work.

	- Every player gets a Pickaxe tool. Equip it and click/tap to swing (Roblox's built-in slash
	  animation): it hits the closest crystal, chest or boss within reach, with the same crits and
	  combos as creatures. Damage = your Power * the tier's multiplier.
	- A Blacksmith anvil in the hub upgrades it (Wooden -> Stone -> Iron -> Crystal -> Mythic) for
	  Essence (Config.Pickaxe).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Crystals = require(script.Parent.Crystals)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Monetization = require(script.Parent.Monetization)

local Pickaxe = {}

local cfg = Config.Pickaxe
local notify = Remotes.Event("Notify")
local lastSwing: { [Player]: number } = {}
local ANVIL_POSITION = Vector3.new(-30, 0, 18)

local function tierOf(player: Player): number
	local data = PlayerData.Get(player) :: any
	return math.clamp(if data then data.Pickaxe or 1 else 1, 1, #cfg.Tiers)
end

local function newPart(props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function hasGolden(player: Player): boolean
	return Monetization.Owns(player, "GoldenPickaxe")
end

--[[
	An imported 3D model (ReplicatedStorage.WorldMeshes, see WorldBuilder.MeshNames) replaces the
	block head. Its longest side is lined up with the handle and scaled to the tool's length.
	Optional attributes on the imported model: Flip = true (head and handle the wrong way round),
	Roll (degrees, turn it around the handle), Scale (size multiplier).
]]
local function attachMesh(tool: Tool, handle: BasePart, meshName: string): boolean
	local folder = ReplicatedStorage:FindFirstChild("WorldMeshes")
	local template = folder and folder:FindFirstChild(meshName)
	if not template or not (template:IsA("Model") or template:IsA("BasePart")) then
		return false
	end
	local model: Model
	if template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		template:Clone().Parent = model
	end
	local length = 3.8 * (tonumber(template:GetAttribute("Scale")) or 1)
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * length / math.max(size.X, size.Y, size.Z, 0.01))
	local box, extents = model:GetBoundingBox()
	-- turn the longest side onto the handle's Z axis
	local align = if extents.Y >= extents.X and extents.Y >= extents.Z
		then CFrame.Angles(math.rad(-90), 0, 0)
		elseif extents.X >= extents.Z then CFrame.Angles(0, math.rad(90), 0)
		else CFrame.identity
	local flip = if template:GetAttribute("Flip") then CFrame.Angles(math.pi, 0, 0) else CFrame.identity
	local roll = CFrame.Angles(0, 0, math.rad(tonumber(template:GetAttribute("Roll")) or 0))
	local pivotInBox = box:Inverse() * model:GetPivot()
	model:PivotTo(handle.CFrame * roll * flip * align:Inverse() * pivotInBox)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = d
			weld.Parent = d
		end
	end
	model.Name = "Look"
	model.Parent = tool
	handle.Transparency = 1
	return true
end

-- Builds the tool for a tier: a wooden handle along Z (held at the bottom) with a coloured head.
-- The Golden Pickaxe pass turns the head gold and adds sparkles.
local function buildTool(tier: number, golden: boolean?): Tool
	local info = cfg.Tiers[tier]
	local tool = Instance.new("Tool")
	tool.Name = "Pickaxe"
	tool.ToolTip = if golden then `Golden {info.Name}` else info.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	-- same grip layout as Roblox's classic sword: the handle's +Z points up out of the hand
	tool.GripPos = Vector3.new(0, 0, -1.3)
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)
	tool:SetAttribute("Tier", tier)
	tool:SetAttribute("Golden", golden == true)
	local handle = newPart({
		Name = "Handle",
		Size = Vector3.new(0.3, 0.3, 3.4),
		Color = Color3.fromRGB(120, 80, 45),
		Material = Enum.Material.Wood,
		CanCollide = false,
		Massless = true,
		Parent = tool,
	})
	local function headPiece(size: Vector3, offset: CFrame, material: Enum.Material)
		local piece = newPart({
			Size = size,
			CFrame = handle.CFrame * offset,
			Color = if golden then Color3.fromRGB(255, 205, 60) else info.Color,
			Material = material,
			CanCollide = false,
			Massless = true,
			Parent = tool,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = piece
		weld.Parent = piece
	end
	if attachMesh(tool, handle, if golden then cfg.GoldenMesh else info.Mesh) then
		if golden then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Color3.fromRGB(255, 215, 80)
			sparkles.Parent = handle
		end
		return tool
	end
	local metal = if tier >= 4 or golden then Enum.Material.Neon else Enum.Material.Metal
	if golden then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 215, 80)
		sparkles.Parent = handle
	end
	headPiece(Vector3.new(2.4, 0.45, 0.45), CFrame.new(0, 0, 1.55), metal)
	-- pointed tips
	headPiece(Vector3.new(0.45, 0.45, 0.7), CFrame.new(1.35, 0, 1.35) * CFrame.Angles(0, math.rad(35), 0), metal)
	headPiece(Vector3.new(0.45, 0.45, 0.7), CFrame.new(-1.35, 0, 1.35) * CFrame.Angles(0, math.rad(-35), 0), metal)
	return tool
end

-- Swings the player's pickaxe (called from the tool's Activated, which runs on the server)
function Pickaxe.Swing(player: Player, tool: Tool?): boolean
	local now = os.clock()
	local golden = hasGolden(player)
	if now - (lastSwing[player] or 0) < cfg.Cooldown * (if golden then cfg.GoldenSpeed else 1) then
		return false
	end
	lastSwing[player] = now
	if tool then
		-- the default Animate script plays the slash animation when it sees this value
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		task.delay(0.3, function()
			anim:Destroy()
		end)
	end
	local data = PlayerData.Get(player)
	if not data then
		return false
	end
	local power = Economy.GetPower(data) * cfg.Tiers[tierOf(player)].Mult * (if golden then cfg.GoldenDamage else 1)
	local hit = Crystals.Swing(player, power, cfg.Reach, cfg.AxeBossBonus)
	-- pick side for crystals, turn it round to the axe side for bosses
	if tool and hit then
		local axe = hit:GetAttribute("Breakable") == "Boss"
		if tool:GetAttribute("Side") ~= (if axe then "Axe" else "Pick") then
			tool:SetAttribute("Side", if axe then "Axe" else "Pick")
			tool.GripRight = if axe then Vector3.new(0, -1, 0) else Vector3.new(0, 1, 0)
			tool.GripForward = if axe then Vector3.new(1, 0, 0) else Vector3.new(-1, 0, 0)
		end
	end
	return hit ~= nil
end

-- Puts the right pickaxe in the player's backpack (replacing an older one)
function Pickaxe.Give(player: Player)
	local tier = tierOf(player)
	local golden = hasGolden(player)
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			local old = container:FindFirstChild("Pickaxe")
			if old and old:IsA("Tool") then
				if old:GetAttribute("Tier") == tier and old:GetAttribute("Golden") == golden then
					return
				end
				old:Destroy()
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = buildTool(tier, golden)
	tool.Activated:Connect(function()
		Pickaxe.Swing(player, tool)
	end)
	tool.Parent = backpack
end

-- Takes the pickaxe out / puts it away (the game hides Roblox's hotbar). Returns held?
function Pickaxe.Toggle(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	local held = character:FindFirstChild("Pickaxe")
	if held and held:IsA("Tool") then
		humanoid:UnequipTools()
		return false
	end
	Pickaxe.Give(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = backpack and backpack:FindFirstChild("Pickaxe")
	if tool and tool:IsA("Tool") then
		humanoid:EquipTool(tool)
		return true
	end
	return false
end

function Pickaxe.Upgrade(player: Player): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data then
		return false
	end
	local tier = tierOf(player)
	local nextTier = cfg.Tiers[tier + 1]
	if not nextTier then
		return false, `Your {cfg.Tiers[tier].Name} is already the best!`
	end
	if data.Essence < nextTier.Cost then
		return false, `{nextTier.Name}: {Format.Number(nextTier.Cost)} Essence (you have {Format.Number(data.Essence)})`
	end
	data.Essence -= nextTier.Cost
	data.Pickaxe = tier + 1
	PlayerData.MarkChanged(player)
	Pickaxe.Give(player)
	return true, `⛏ {nextTier.Name}! Swings now deal {nextTier.Mult}x your Power`
end

-- The Blacksmith anvil in the hub
local function buildAnvil(): BasePart?
	local world = workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	if not hub then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Blacksmith"
	local stone = Color3.fromRGB(95, 90, 105)
	local iron = Color3.fromRGB(70, 72, 80)
	local p = ANVIL_POSITION
	newPart({
		Name = "Base",
		Anchored = true,
		Size = Vector3.new(4, 2, 3),
		Position = p + Vector3.new(0, 1, 0),
		Color = stone,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	local top = newPart({
		Name = "Anvil",
		Anchored = true,
		Size = Vector3.new(5, 1, 2.2),
		Position = p + Vector3.new(0, 2.7, 0),
		Color = iron,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	newPart({
		Name = "Horn",
		ClassName = "WedgePart",
		Anchored = true,
		Size = Vector3.new(2.2, 1, 1.6),
		CFrame = CFrame.new(p + Vector3.new(3.3, 2.7, 0)) * CFrame.Angles(0, math.rad(-90), 0),
		Color = iron,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	-- a floating pickaxe that spins above it (the client animates Spin/Bob)
	local display = buildTool(#cfg.Tiers)
	local float = Instance.new("Model")
	float.Name = "DisplayPickaxe"
	for _, child in display:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.Parent = float
		end
	end
	display:Destroy()
	float.PrimaryPart = float:FindFirstChild("Handle") :: BasePart
	float:PivotTo(CFrame.new(p + Vector3.new(0, 6.5, 0)) * CFrame.Angles(math.rad(-90), 0, 0))
	float:SetAttribute("Spin", 1.2)
	float:SetAttribute("Bob", 0.4)
	float.Parent = model
	local helpers = WorldBuilder.Helpers
	helpers.Light(top, Color3.fromRGB(255, 160, 80), 14, 1.5)
	local sign = helpers.Billboard(top, UDim2.fromOffset(240, 56), Vector3.new(0, 7.5, 0), 120)
	helpers.Label(sign, { Text = "⛏ Blacksmith\nUpgrade your pickaxe", TextColor3 = Color3.fromRGB(255, 200, 120) })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Upgrade Pickaxe"
	prompt.ObjectText = "Blacksmith"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = top
	model.Parent = hub
	return top
end

function Pickaxe.Start()
	local anvil = buildAnvil()
	local prompt = anvil and anvil:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			local ok, message = Pickaxe.Upgrade(player)
			if message then
				notify:FireClient(
					player,
					message,
					if ok then Color3.fromRGB(255, 200, 120) else Color3.fromRGB(255, 130, 130)
				)
			end
		end)
	end
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			Pickaxe.Give(player)
		end)
		if player.Character then
			task.spawn(Pickaxe.Give, player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	-- data loads after the first character can spawn: re-give at the saved tier
	PlayerData.Loaded:Connect(function(player)
		Pickaxe.Give(player)
		-- game passes are checked just after loading: make sure a Golden Pickaxe shows up
		task.delay(4, Pickaxe.Give, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
	Monetization.OnPassPurchased(function(player, key)
		if key == "GoldenPickaxe" then
			Pickaxe.Give(player)
		end
	end)
end

return Pickaxe
