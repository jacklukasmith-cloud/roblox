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
local lastSwing: { [Player]: number } = {}
local streaks: { [Player]: { Count: number, LastHit: number } } = {}
local pickaxeHit = Remotes.Event("PickaxeHit")
local ANVIL_PLAN = Vector3.new(-30, 0, 18) -- on the 100-wide map plan (spread out by WorldBuilder)

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
	-- a broken import must never stop you getting your pickaxe: fall back to the block head
	local ok, attached = pcall(attachMesh, tool, handle, if golden then cfg.GoldenMesh else info.Mesh)
	if not ok then
		warn(`[Pickaxe] couldn't use the model for {info.Name}: {attached}`)
		local look = tool:FindFirstChild("Look")
		if look then
			look:Destroy()
		end
		handle.Transparency = 0
		attached = false
	end
	if attached then
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
-- Which way round the head faces: the pick side for crystals, the axe side for bosses. Turning
-- the grip 180 degrees around the handle swaps which end of the head points forward.
local function setSide(tool: Tool, axe: boolean)
	local side = if axe then "Axe" else "Pick"
	if tool:GetAttribute("Side") == side then
		return
	end
	tool:SetAttribute("Side", side)
	tool.GripRight = if axe then Vector3.new(0, -1, 0) else Vector3.new(0, 1, 0)
	tool.GripForward = if axe then Vector3.new(1, 0, 0) else Vector3.new(-1, 0, 0)
end

-- Is a boss close enough that you're fighting it (or are your creatures attacking one)?
local BOSS_RANGE = 25 -- studs beyond the boss's own size
local function nearBoss(player: Player): boolean
	local targetValue = player:FindFirstChild("PetTarget")
	local target = targetValue and (targetValue :: ObjectValue).Value
	if target and target:GetAttribute("Breakable") == "Boss" then
		return true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local world = workspace:FindFirstChild("World")
	local bosses = world and world:FindFirstChild("Bosses")
	if not root or not bosses then
		return false
	end
	for _, boss in bosses:GetChildren() do
		if boss:IsA("Model") then
			local box, size = boss:GetBoundingBox()
			local flat = (box.Position - root.Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude <= math.max(size.X, size.Z) / 2 + BOSS_RANGE then
				return true
			end
		end
	end
	return false
end

-- Turns the held pickaxe to the right side (called a few times a second)
function Pickaxe.UpdateSide(player: Player)
	local character = player.Character
	local tool = character and character:FindFirstChild("Pickaxe")
	if tool and tool:IsA("Tool") then
		setSide(tool, nearBoss(player))
	end
end

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
	-- mining streak: keep landing hits for up to +50% damage
	local streak = streaks[player]
	if not streak or now - streak.LastHit > cfg.StreakWindow then
		streak = { Count = 0, LastHit = 0 }
		streaks[player] = streak
	end
	local power = Economy.GetPower(data)
		* cfg.Tiers[tierOf(player)].Mult
		* (if golden then cfg.GoldenDamage else 1)
		* (1 + streak.Count * cfg.StreakStep)
	local hit, crit = Crystals.Swing(player, power, cfg.Reach, cfg.AxeBossBonus)
	if hit then
		streak.Count = math.min(streak.Count + 1, cfg.StreakMax)
		streak.LastHit = now
		pickaxeHit:FireClient(player, hit, crit, streak.Count)
	else
		-- swinging at air next to something: tell them to step closer
		local near = Crystals.NearestDistance(player) < cfg.Reach + 12
		pickaxeHit:FireClient(player, nil, false, streak.Count, near)
	end
	-- whatever you actually hit decides the side too (pick for crystals, axe for bosses)
	if tool and hit then
		setSide(tool, hit:GetAttribute("Breakable") == "Boss")
	end
	return hit ~= nil
end

-- Puts the right pickaxe in the player's backpack (replacing an older one). If the old one was
-- in their hand (or equip is true) the new one goes straight into their hand.
function Pickaxe.Give(player: Player, equip: boolean?)
	local tier = tierOf(player)
	local golden = hasGolden(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local wantHeld = equip == true
	local containers = { player:FindFirstChildOfClass("Backpack"), character }
	for _, container in containers do
		if container then
			local old = container:FindFirstChild("Pickaxe")
			if old and old:IsA("Tool") then
				if old:GetAttribute("Tier") == tier and old:GetAttribute("Golden") == golden then
					if wantHeld and humanoid and old.Parent ~= character then
						humanoid:EquipTool(old)
					end
					return
				end
				wantHeld = wantHeld or container == character
				old:Destroy()
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack or not backpack:IsA("Backpack") then
		warn(`[Pickaxe] {player.Name} has no Backpack yet - couldn't give the pickaxe`)
		return
	end
	local tool = buildTool(tier, golden)
	print(
		`[Mythic Tamers] Gave {player.Name} the {tool.ToolTip} ({if tool:FindFirstChild("Look")
			then "your 3D model"
			else "block model"})`
	)
	tool.Activated:Connect(function()
		Pickaxe.Swing(player, tool)
	end)
	tool.Parent = backpack
	if wantHeld and humanoid and humanoid.Health > 0 then
		humanoid:EquipTool(tool)
	end
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
	local ok, err = pcall(Pickaxe.Give, player, true)
	if not ok then
		warn(`[Pickaxe] give after upgrade failed: {err}`)
	end
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
	local p = ANVIL_PLAN * Vector3.new(WorldBuilder.Helpers.Spread, 1, WorldBuilder.Helpers.Spread)
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
	-- the shop circle: walk into it and the Blacksmith window opens (client: BlacksmithPanel)
	local padCenter = p + Vector3.new(8, 0, 0)
	local ring = newPart({
		Name = "BlacksmithPad",
		Anchored = true,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 9, 9),
		CFrame = CFrame.new(padCenter + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 170, 80),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	newPart({
		Name = "PadInner",
		Anchored = true,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.22, 7.6, 7.6),
		CFrame = CFrame.new(padCenter + Vector3.new(0, 0.13, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(60, 40, 30),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local padSign = helpers.Billboard(ring, UDim2.fromOffset(200, 34), Vector3.new(0, 3, 0), 60)
	helpers.Label(padSign, { Text = "⛏ Step in to shop", TextColor3 = Color3.fromRGB(255, 200, 120) })
	model.Parent = hub
	return top
end

function Pickaxe.Start()
	buildAnvil()
	local function hook(player: Player)
		-- spawn holding it (the hotbar is hidden, so otherwise it's easy to miss)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			Pickaxe.Give(player, true)
		end)
		if player.Character then
			task.spawn(Pickaxe.Give, player, true)
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
		streaks[player] = nil
	end)
	-- turn to the axe side as soon as you're near a boss, back to the pick when you leave
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(Pickaxe.UpdateSide, player)
				if not ok then
					warn(`[Pickaxe] {err}`)
				end
			end
		end
	end)
	Monetization.OnPassPurchased(function(player, key)
		if key == "GoldenPickaxe" then
			Pickaxe.Give(player, true)
		end
	end)
end

return Pickaxe
