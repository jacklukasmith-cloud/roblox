--[[
	Animals in the Gloomwood (Gloomwood.Beasts):
	  - Hostile ones (Shadow Wolves) roam the Midwood and chase anyone who comes near. They never go
	    near a Courier Lantern, so lanterns are safe.
	  - Guardians (Bramble Boars, Moss Bears) sleep next to a crystal and only wake up when someone
	    starts mining it. Then they chase that player until they've run far enough away.
	A hit adds Gloom (Wolves can also knock a crystal out of your satchel) and pushes you back. Fight
	back with your pickaxe; your equipped pets join in. Beat one for pet XP (and a crystal from a
	wolf). Wolves come back after a while; a beaten guardian leaves its crystal unguarded.

	They walk with a Humanoid (smooth for everyone). GloomBeasts.Move can be swapped in tests.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gloomwood = require(Shared.Gloomwood)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Bag = require(script.Parent.Bag)

local GloomBeasts = {}

local rgb = Color3.fromRGB
local notify = Remotes.Event("Notify")
local beastHit = Remotes.Event("BeastHit")

local MAX_CHASE_TIME = 30
local IGNORE_AFTER_CALM = 6 -- seconds a beast leaves you alone after giving up
local LANTERN_SAFE = Gloomwood.LanternRadius + 4

export type Beast = {
	Def: any,
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid?,
	HP: number,
	Home: Vector3,
	Crystal: Model?,
	State: string, -- "Sleep" | "Wander" | "Chase" | "Return"
	Target: Player?,
	ChaseFrom: Vector3,
	ChaseSince: number,
	LastAttack: number,
	Goal: Vector3?,
	Damage: { [Player]: number },
	Ignore: { [Player]: number },
	Bar: Frame?,
	Status: TextLabel?,
}

-- Hooks the Gloomwood service fills in
GloomBeasts.Hooks = {
	AddGloom = function(_player: Player, _amount: number) end,
	AddToSatchel = function(_player: Player, _id: string): boolean
		return false
	end,
	Steal = function(_player: Player): string?
		return nil
	end,
	Lanterns = function(): { Vector3 }
		return {}
	end,
}
GloomBeasts.Clock = os.clock
GloomBeasts.Rng = Random.new()

local folder: Instance? = nil
local beasts: { [Model]: Beast } = {}
local guardianOf: { [Model]: Beast } = {} -- crystal model -> its guardian

-- Moving ------------------------------------------------------------------------------------

-- Walks a beast towards a spot (replaced in tests)
function GloomBeasts.Move(beast: Beast, position: Vector3)
	local humanoid = beast.Humanoid
	if humanoid then
		humanoid:MoveTo(position)
	end
end

local function flat(v: Vector3): Vector3
	return v * Vector3.new(1, 0, 1)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function nearLantern(position: Vector3): boolean
	for _, lamp in GloomBeasts.Hooks.Lanterns() do
		if flat(position - lamp).Magnitude <= LANTERN_SAFE then
			return true
		end
	end
	return false
end

-- Models ------------------------------------------------------------------------------------

local function part(model: Model, root: BasePart, props: { [string]: any }, offset: CFrame): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	for k, v in props do
		if k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	p.CanCollide = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

-- Body plans: the root is the body; legs etc. hang off it. Hip = HipHeight for the Humanoid.
local PLANS = {
	ShadowWolf = function(model: Model, root: BasePart)
		local fur, dark = rgb(45, 40, 60), rgb(25, 22, 35)
		part(model, root, { Size = Vector3.new(1.6, 1.5, 1.8), Color = fur }, CFrame.new(0, 0.5, -2.6))
		part(model, root, { Size = Vector3.new(0.9, 0.7, 1), Color = dark }, CFrame.new(0, 0.2, -3.8))
		for _, x in { -0.5, 0.5 } do
			part(
				model,
				root,
				{ ClassName = "WedgePart", Size = Vector3.new(0.4, 0.7, 0.5), Color = dark },
				CFrame.new(x, 1.6, -2.4)
			)
			part(
				model,
				root,
				{ Size = Vector3.new(0.3, 0.2, 0.1), Color = rgb(200, 120, 255), Material = Enum.Material.Neon },
				CFrame.new(x * 0.8, 0.75, -3.52)
			)
		end
		part(
			model,
			root,
			{ Size = Vector3.new(0.4, 0.4, 2), Color = fur },
			CFrame.new(0, 0.6, 2.6) * CFrame.Angles(math.rad(25), 0, 0)
		)
		for _, x in { -0.7, 0.7 } do
			for _, z in { -1.4, 1.4 } do
				part(model, root, { Size = Vector3.new(0.5, 1.6, 0.5), Color = dark }, CFrame.new(x, -1.6, z))
			end
		end
		return Vector3.new(2.2, 1.8, 4), 1.5, fur
	end,
	BrambleBoar = function(model: Model, root: BasePart)
		local hide, dark = rgb(110, 75, 55), rgb(70, 45, 35)
		part(model, root, { Size = Vector3.new(1.8, 1.6, 1.4), Color = hide }, CFrame.new(0, 0.1, -2.3))
		part(model, root, { Size = Vector3.new(1, 0.8, 0.5), Color = rgb(200, 140, 130) }, CFrame.new(0, -0.1, -3.1))
		for _, x in { -0.6, 0.6 } do
			part(
				model,
				root,
				{ Size = Vector3.new(0.2, 0.2, 0.9), Color = rgb(240, 235, 220) },
				CFrame.new(x, -0.3, -3.2) * CFrame.Angles(math.rad(-35), 0, 0)
			)
		end
		-- the bramble spikes along its back
		for i = -2, 2 do
			part(
				model,
				root,
				{ ClassName = "WedgePart", Size = Vector3.new(0.5, 0.9, 0.7), Color = rgb(60, 110, 50) },
				CFrame.new(0, 1.3, i * 0.6)
			)
		end
		for _, x in { -0.8, 0.8 } do
			for _, z in { -1.1, 1.1 } do
				part(model, root, { Size = Vector3.new(0.6, 1, 0.6), Color = dark }, CFrame.new(x, -1.3, z))
			end
		end
		return Vector3.new(2.6, 2, 3.6), 0.8, hide
	end,
	DuskBat = function(model: Model, root: BasePart)
		local skin = rgb(55, 35, 70)
		for _, x in { -1, 1 } do
			-- wings, swept back a little
			part(
				model,
				root,
				{ Size = Vector3.new(2.4, 0.15, 1.3), Color = rgb(40, 25, 55) },
				CFrame.new(x * 1.7, 0.2, 0.1) * CFrame.Angles(0, x * -0.3, x * 0.35)
			)
			part(
				model,
				root,
				{ ClassName = "WedgePart", Size = Vector3.new(0.25, 0.5, 0.3), Color = skin },
				CFrame.new(x * 0.3, 0.7, -0.4)
			)
			part(
				model,
				root,
				{ Size = Vector3.new(0.2, 0.15, 0.1), Color = rgb(255, 70, 70), Material = Enum.Material.Neon },
				CFrame.new(x * 0.25, 0.2, -0.72)
			)
		end
		return Vector3.new(1.2, 1, 1.4), 5, skin -- no legs: it flutters 5 studs up
	end,
	CinderFox = function(model: Model, root: BasePart)
		local fur, dark = rgb(205, 85, 40), rgb(50, 30, 25)
		part(model, root, { Size = Vector3.new(1.2, 1.1, 1.3), Color = fur }, CFrame.new(0, 0.4, -2))
		part(model, root, { Size = Vector3.new(0.6, 0.5, 0.7), Color = rgb(240, 220, 200) }, CFrame.new(0, 0.2, -2.9))
		for _, x in { -0.35, 0.35 } do
			part(
				model,
				root,
				{ ClassName = "WedgePart", Size = Vector3.new(0.35, 0.6, 0.35), Color = dark },
				CFrame.new(x, 1.25, -1.9)
			)
		end
		-- a bushy tail with a glowing ember tip
		local tail = CFrame.new(0, 0.6, 2.1) * CFrame.Angles(math.rad(30), 0, 0)
		part(model, root, { Size = Vector3.new(0.7, 0.7, 2.2), Color = fur }, tail)
		part(
			model,
			root,
			{ Size = Vector3.new(0.6, 0.6, 0.6), Color = rgb(255, 170, 60), Material = Enum.Material.Neon },
			tail * CFrame.new(0, 0, 1.3)
		)
		for _, x in { -0.5, 0.5 } do
			for _, z in { -1, 1 } do
				part(model, root, { Size = Vector3.new(0.4, 1.2, 0.4), Color = dark }, CFrame.new(x, -1.2, z))
			end
		end
		return Vector3.new(1.6, 1.3, 3), 1.15, fur
	end,
	ThicketSpider = function(model: Model, root: BasePart)
		local shell = rgb(35, 50, 35)
		part(model, root, { Size = Vector3.new(1.4, 1, 1.2), Color = rgb(25, 35, 25) }, CFrame.new(0, -0.1, -1.8))
		for i = 0, 3 do
			part(
				model,
				root,
				{ Size = Vector3.new(0.18, 0.18, 0.1), Color = rgb(150, 255, 120), Material = Enum.Material.Neon },
				CFrame.new(-0.45 + i * 0.3, 0.15 + (i % 2) * 0.15, -2.42)
			)
		end
		-- eight long legs
		for _, x in { -1, 1 } do
			for i = 0, 3 do
				part(
					model,
					root,
					{ Size = Vector3.new(0.22, 0.22, 2.8), Color = shell },
					CFrame.new(x * 1.4, -0.4, -1.3 + i * 0.75)
						* CFrame.Angles(0, x * math.rad(90 - i * 12), 0)
						* CFrame.Angles(math.rad(-25), 0, 0)
				)
			end
		end
		return Vector3.new(2.4, 1.4, 2.6), 0.9, shell
	end,
	FrostStag = function(model: Model, root: BasePart)
		local coat, ice = rgb(185, 205, 225), rgb(140, 230, 255)
		part(
			model,
			root,
			{ Size = Vector3.new(0.9, 1.7, 0.9), Color = coat },
			CFrame.new(0, 1.3, -1.9) * CFrame.Angles(math.rad(-20), 0, 0)
		)
		part(model, root, { Size = Vector3.new(0.9, 0.9, 1.6), Color = coat }, CFrame.new(0, 2.3, -2.7))
		-- glowing ice antlers
		for _, x in { -1, 1 } do
			local base = CFrame.new(x * 0.35, 3.3, -2.5) * CFrame.Angles(0, 0, x * -0.4)
			part(model, root, { Size = Vector3.new(0.18, 1.6, 0.18), Color = ice, Material = Enum.Material.Neon }, base)
			part(
				model,
				root,
				{ Size = Vector3.new(0.15, 0.9, 0.15), Color = ice, Material = Enum.Material.Neon },
				base * CFrame.new(0, 0.3, -0.3) * CFrame.Angles(math.rad(-50), 0, 0)
			)
		end
		for _, x in { -0.7, 0.7 } do
			for _, z in { -1.5, 1.5 } do
				part(
					model,
					root,
					{ Size = Vector3.new(0.45, 2.4, 0.45), Color = rgb(150, 160, 180) },
					CFrame.new(x, -2.2, z)
				)
			end
		end
		return Vector3.new(2.2, 2, 4), 2.4, coat
	end,
	ShadowWisp = function(model: Model, root: BasePart)
		-- a ghostly flame: a glowing core with wisps trailing behind, no legs (it floats)
		local glow = rgb(170, 120, 255)
		part(model, root, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.4,
			Color = rgb(230, 210, 255),
			Material = Enum.Material.Neon,
		}, CFrame.new(0, 0.1, 0))
		for i = 1, 3 do
			part(model, root, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (1.1 - i * 0.25),
				Color = glow,
				Material = Enum.Material.Neon,
				Transparency = 0.2 + i * 0.15,
			}, CFrame.new(0, 0.3 + i * 0.5, 0.4 + i * 0.5))
		end
		for _, x in { -0.3, 0.3 } do
			part(
				model,
				root,
				{ Size = Vector3.new(0.25, 0.3, 0.1), Color = rgb(20, 10, 40), Material = Enum.Material.Neon },
				CFrame.new(x, 0.2, -0.65)
			)
		end
		return Vector3.new(1.6, 1.8, 2.2), 4, glow
	end,
	GloomTreant = function(model: Model, root: BasePart)
		local bark, leaf = rgb(45, 35, 40), rgb(60, 35, 90)
		-- the trunk is the body; a glowing hollow in the chest, arms, and a crown of dark leaves
		part(
			model,
			root,
			{ Size = Vector3.new(2.6, 2.2, 1), Color = rgb(190, 120, 255), Material = Enum.Material.Neon },
			CFrame.new(0, 1, -2.6)
		)
		for _, x in { -1, 1 } do
			part(
				model,
				root,
				{ Size = Vector3.new(0.9, 0.5, 0.2), Color = rgb(255, 220, 120), Material = Enum.Material.Neon },
				CFrame.new(x * 1.3, 4.2, -2.7)
			)
			-- long branch arms
			part(
				model,
				root,
				{ Size = Vector3.new(1.6, 7, 1.6), Color = bark, Material = Enum.Material.Wood },
				CFrame.new(x * 3.6, 0.5, -0.5) * CFrame.Angles(0, 0, x * 0.25)
			)
			part(
				model,
				root,
				{ Size = Vector3.new(1, 3, 1), Color = bark, Material = Enum.Material.Wood },
				CFrame.new(x * 4.6, -3.5, -1.5) * CFrame.Angles(0.5, 0, x * 0.3)
			)
		end
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			part(model, root, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 5,
				Color = leaf,
				Material = Enum.Material.Grass,
			}, CFrame.new(math.sin(a) * 2.5, 7.5 + (i % 2), math.cos(a) * 2.5))
		end
		part(
			model,
			root,
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 6, Color = leaf, Material = Enum.Material.Grass },
			CFrame.new(0, 9.5, 0)
		)
		for _, x in { -1.6, 1.6 } do
			part(
				model,
				root,
				{ Size = Vector3.new(1.8, 4.5, 2), Color = bark, Material = Enum.Material.Wood },
				CFrame.new(x, -5.2, 0)
			)
		end
		return Vector3.new(5, 10, 5), 2.6, bark
	end,
	MossBear = function(model: Model, root: BasePart)
		local fur, moss = rgb(80, 60, 45), rgb(70, 130, 60)
		part(model, root, { Size = Vector3.new(2.6, 2.4, 2.4), Color = fur }, CFrame.new(0, 1.4, -3.8))
		part(model, root, { Size = Vector3.new(1.2, 1, 1), Color = rgb(60, 45, 35) }, CFrame.new(0, 1, -5.3))
		for _, x in { -1, 1 } do
			part(
				model,
				root,
				{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = fur },
				CFrame.new(x, 2.8, -3.6)
			)
		end
		-- moss growing on its back
		for i, offset in { Vector3.new(-0.8, 1.9, -0.5), Vector3.new(0.7, 1.9, 1), Vector3.new(0, 1.9, 2.2) } do
			part(model, root, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2, 0.8, 2) * (1.2 - i * 0.15),
				Color = moss,
				Material = Enum.Material.Grass,
			}, CFrame.new(offset))
		end
		for _, x in { -1.3, 1.3 } do
			for _, z in { -1.9, 1.9 } do
				part(model, root, { Size = Vector3.new(1.2, 2.2, 1.2), Color = fur }, CFrame.new(x, -2.6, z))
			end
		end
		return Vector3.new(4, 3.6, 6), 1.9, fur
	end,
}

local function setBar(beast: Beast)
	local bar = beast.Bar
	if bar then
		bar.Size = UDim2.fromScale(math.clamp(beast.HP / beast.Def.HP, 0, 1), 1)
	end
	local status = beast.Status
	if status then
		status.Text = if beast.State == "Sleep"
			then `{beast.Def.Icon} {beast.Def.Name}  💤`
			else `{beast.Def.Icon} {beast.Def.Name}`
		if bar and bar.Parent then
			(bar.Parent :: GuiObject).Visible = beast.State ~= "Sleep" and beast.HP < beast.Def.HP
		end
	end
end

local function build(def: any, position: Vector3): Beast
	local helpers = WorldBuilder.Helpers
	local model = Instance.new("Model")
	model.Name = def.Id
	model:SetAttribute("GloomBeast", def.Id)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	-- build it standing at the origin first, then move the whole thing into place
	root.CFrame = CFrame.new()
	local size, hip, color = PLANS[def.Id](model, root)
	root.Size = size
	root.Color = color
	root.Parent = model
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = hip
	humanoid.WalkSpeed = def.Speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	model:PivotTo(CFrame.new(position + Vector3.new(0, hip + size.Y / 2, 0)))
	-- name + health bar
	local gui = helpers.Billboard(root, UDim2.fromOffset(170, 40), Vector3.new(0, size.Y / 2 + 2, 0), 60)
	local status = helpers.Label(gui, { Name = "Status", Text = "", Size = UDim2.fromScale(1, 0.55) })
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.fromScale(0.1, 0.62)
	back.Size = UDim2.fromScale(0.8, 0.3)
	back.BackgroundColor3 = rgb(20, 15, 30)
	back.Visible = false
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = rgb(255, 90, 110)
	fill.Parent = back
	return {
		Def = def,
		Model = model,
		Root = root,
		Humanoid = humanoid,
		HP = def.HP,
		Home = position,
		Crystal = nil,
		State = "Wander",
		Target = nil,
		ChaseFrom = position,
		ChaseSince = 0,
		LastAttack = -math.huge,
		Goal = nil,
		Damage = {},
		Ignore = {},
		Bar = fill,
		Status = status,
	}
end

local function setAnchored(beast: Beast, anchored: boolean)
	beast.Root.Anchored = anchored
	if not anchored then
		-- the server moves them (smooth for every player)
		pcall(function()
			beast.Root:SetNetworkOwner(nil)
		end)
	end
end

local function place(beast: Beast)
	beast.Model.Parent = folder
	beasts[beast.Model] = beast
	setAnchored(beast, beast.State == "Sleep")
	setBar(beast)
end

-- Pets -------------------------------------------------------------------------------------

-- Points a player's pets at a beast (the followers on every screen pounce on it)
local function petTargetOf(player: Player): ObjectValue?
	local ok, value = pcall(function()
		return (player :: any):FindFirstChild("PetTarget")
	end)
	return if ok and value and value:IsA("ObjectValue") then value else nil
end

local function sendPets(player: Player, beast: Beast)
	local value = petTargetOf(player)
	if value and (value.Value == nil or not value.Value.Parent) then
		value.Value = beast.Model
	end
end

local function callPetsBack(beast: Beast)
	for _, player in Players:GetPlayers() do
		local value = petTargetOf(player)
		if value and value.Value == beast.Model then
			value.Value = nil
		end
	end
	for player in beast.Damage do
		local value = petTargetOf(player)
		if value and value.Value == beast.Model then
			value.Value = nil
		end
	end
end

-- Spawning ---------------------------------------------------------------------------------

local function hostileSpot(def: any): Vector3?
	local rng = GloomBeasts.Rng
	local inner = if def.Ring == "Edge"
		then Gloomwood.RingEdge + 15
		elseif def.Ring == "Deepwood" then Gloomwood.RingHeart + 15
		else Gloomwood.RingMid + 20
	local outer = if def.Ring == "Edge"
		then Gloomwood.Radius - 20
		elseif def.Ring == "Deepwood" then Gloomwood.RingMid - 15
		else Gloomwood.RingEdge - 15
	-- animals that live by a landmark stay a bit further from lanterns there
	local keepAway = if def.Near then 25 else 40
	for _ = 1, 60 do
		local pos
		if def.Near then
			local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(25, 80)
			pos = Gloomwood.Place(def.Near) + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
		else
			pos = Gloomwood.At(rng:NextNumber(0, math.pi * 2), rng:NextNumber(inner, outer))
		end
		local ring = Gloomwood.RingAt(pos)
		local safe = ring ~= nil
			and ring ~= "Heart"
			and (ring == def.Ring or def.Near ~= nil)
			and flat(pos - Gloomwood.Place("DeepCamp")).Magnitude > 50
			and flat(pos - Gloomwood.Place("Gate")).Magnitude > 70
		for _, lamp in GloomBeasts.Hooks.Lanterns() do
			if flat(pos - lamp).Magnitude < keepAway then
				safe = false
				break
			end
		end
		if safe then
			return pos
		end
	end
	return nil
end

function GloomBeasts.SpawnHostile(def: any): Beast?
	local spot = hostileSpot(def)
	if not spot then
		return nil
	end
	local beast = build(def, spot)
	beast.State = "Wander"
	place(beast)
	return beast
end

-- A new crystal grew: maybe a guardian sleeps next to it
function GloomBeasts.OnCrystal(crystal: Model, crystalId: string, position: Vector3): Beast?
	-- every kind that guards this crystal gets a roll, in a random order
	local kinds = {}
	for _, def in Gloomwood.Beasts do
		if def.Kind == "Guardian" and table.find(def.Guards, crystalId) then
			table.insert(kinds, def)
		end
	end
	for i = #kinds, 2, -1 do
		local j = GloomBeasts.Rng:NextInteger(1, i)
		kinds[i], kinds[j] = kinds[j], kinds[i]
	end
	for _, def in kinds do
		if GloomBeasts.Rng:NextNumber() < def.Chance then
			local a = GloomBeasts.Rng:NextNumber(0, math.pi * 2)
			local beast = build(def, position + Vector3.new(math.sin(a) * 5, 0, math.cos(a) * 5))
			beast.State = "Sleep"
			beast.Crystal = crystal
			-- curled up facing its crystal
			beast.Model:PivotTo(
				CFrame.lookAt(beast.Root.Position, Vector3.new(position.X, beast.Root.Position.Y, position.Z))
			)
			guardianOf[crystal] = beast
			place(beast)
			return beast
		end
	end
	return nil
end

-- Behaviour --------------------------------------------------------------------------------

local function remove(beast: Beast)
	callPetsBack(beast)
	beasts[beast.Model] = nil
	if beast.Crystal and guardianOf[beast.Crystal] == beast then
		guardianOf[beast.Crystal] = nil
	end
	beast.Model:Destroy()
end

local function chase(beast: Beast, player: Player)
	local root = rootOf(player)
	if beast.State == "Sleep" then
		setAnchored(beast, false)
	end
	beast.State = "Chase"
	beast.Target = player
	beast.ChaseFrom = if beast.Def.Kind == "Guardian" then beast.Home else beast.Root.Position
	beast.ChaseSince = GloomBeasts.Clock()
	beast.Ignore[player] = nil
	sendPets(player, beast)
	setBar(beast)
	if root and beast.Def.Kind == "Guardian" then
		notify:FireClient(
			player,
			`{beast.Def.Icon} A {beast.Def.Name} woke up! Run, or fight it off`,
			rgb(255, 150, 120)
		)
		if beast.Def.Announce then
			notify:FireAllClients(
				`{beast.Def.Icon} The {beast.Def.Name} has woken in the Heart of the Gloomwood! Help {player.DisplayName}`,
				rgb(200, 150, 255)
			)
		end
	end
end

-- Stops chasing: guardians go home (or leave if their crystal is gone), hostiles wander again
local function calm(beast: Beast)
	local target = beast.Target
	if target then
		beast.Ignore[target] = GloomBeasts.Clock() + IGNORE_AFTER_CALM
		local value = petTargetOf(target)
		if value and value.Value == beast.Model then
			value.Value = nil
		end
	end
	beast.Target = nil
	beast.Goal = nil
	if beast.Def.Kind == "Guardian" then
		if not beast.Crystal then
			remove(beast)
			return
		end
		beast.State = "Return"
	else
		beast.State = "Wander"
	end
	setBar(beast)
end

local function attack(beast: Beast, player: Player)
	local def = beast.Def
	beast.LastAttack = GloomBeasts.Clock()
	GloomBeasts.Hooks.AddGloom(player, def.Gloom)
	local root = rootOf(player)
	local push = if root then flat(root.Position - beast.Root.Position) else Vector3.zero
	beastHit:FireClient(player, def.Id, if push.Magnitude > 0.01 then push.Unit else Vector3.zero)
	if def.Steal > 0 and GloomBeasts.Rng:NextNumber() < def.Steal then
		local stolen = GloomBeasts.Hooks.Steal(player)
		local crystal = stolen and Gloomwood.Get(stolen)
		if crystal then
			notify:FireClient(
				player,
				`{def.Icon} The {def.Name} knocked a {crystal.Name} out of your satchel!`,
				rgb(255, 130, 130)
			)
		end
	end
	sendPets(player, beast)
end

local function defeat(beast: Beast)
	local def = beast.Def
	for player in beast.Damage do
		if player.Parent then
			local data = PlayerData.Get(player) :: any
			if data then
				data.Stats.BeastsDefeated = (data.Stats.BeastsDefeated or 0) + 1
				PlayerData.MarkChanged(player)
				-- every few animals: an Owl Eye Potion (see further in the fog)
				if data.Stats.BeastsDefeated % Gloomwood.VisionPotionEvery == 0 then
					Bag.Give(player, "OwlEyePotion", 1)
					notify:FireClient(
						player,
						"🦉 You earned an Owl Eye Potion! Drink it from your 🎒 Bag to see further in the fog",
						rgb(255, 220, 130)
					)
				end
			end
			Economy.GrantXP(player, def.XP)
			local extra = ""
			if def.Drop and GloomBeasts.Hooks.AddToSatchel(player, def.Drop) then
				extra = `, +1 {Gloomwood.Get(def.Drop).Name}`
			end
			notify:FireClient(player, `{def.Icon} You beat a {def.Name}! +{def.XP} pet XP{extra}`, rgb(150, 255, 170))
		end
	end
	if def.Announce then
		local names = {}
		for player in beast.Damage do
			if player.Parent then
				table.insert(names, player.DisplayName)
			end
		end
		notify:FireAllClients(
			`{def.Icon} The {def.Name} was defeated by {table.concat(names, ", ")}!`,
			rgb(150, 255, 170)
		)
	end
	remove(beast)
	if def.Kind == "Hostile" then
		task.delay(def.Respawn, function()
			GloomBeasts.SpawnHostile(def)
		end)
	end
end

-- Damage from a player (pickaxe) or their pets
function GloomBeasts.Hurt(beast: Beast, player: Player, amount: number)
	if not beasts[beast.Model] or amount <= 0 then
		return
	end
	beast.Damage[player] = (beast.Damage[player] or 0) + amount
	beast.HP -= amount
	if beast.State ~= "Chase" then
		chase(beast, player)
	end
	setBar(beast)
	if beast.HP <= 0 then
		defeat(beast)
	end
end

-- A pickaxe swing at an awake animal in reach. Returns the model hit.
function GloomBeasts.Swing(player: Player, damage: number, reach: number): Model?
	local root = rootOf(player)
	if not root then
		return nil
	end
	local best, bestDist = nil, math.huge
	for model, beast in beasts do
		if beast.State ~= "Sleep" then
			local size = beast.Root.Size
			local dist = (beast.Root.Position - root.Position).Magnitude - math.max(size.X, size.Z) / 2
			if dist <= reach and dist < bestDist then
				best, bestDist = beast, dist
			end
		end
	end
	if best then
		GloomBeasts.Hurt(best, player, damage)
		return best.Model
	end
	return nil
end

-- Someone's mining a crystal: its guardian wakes up and goes for them
function GloomBeasts.CrystalHit(crystal: Model, player: Player)
	local beast = guardianOf[crystal]
	if beast and beasts[beast.Model] and beast.State ~= "Chase" then
		chase(beast, player)
	end
end

-- The crystal was mined: an asleep guardian wanders off, an awake one leaves once it calms down
function GloomBeasts.CrystalGone(crystal: Model)
	local beast = guardianOf[crystal]
	guardianOf[crystal] = nil
	if beast then
		beast.Crystal = nil
		if beast.State == "Sleep" or beast.State == "Return" then
			remove(beast)
		end
	end
end

function GloomBeasts.GuardianOf(crystal: Model): Beast?
	return guardianOf[crystal]
end

function GloomBeasts.All(): { [Model]: Beast }
	return beasts
end

-- Is this player a fair target right now?
local function canChase(beast: Beast, player: Player): boolean
	if not player.Parent then
		return false
	end
	local root = rootOf(player)
	if not root or not Gloomwood.RingAt(root.Position) or nearLantern(root.Position) then
		return false
	end
	if flat(root.Position - beast.ChaseFrom).Magnitude > beast.Def.Leash then
		return false
	end
	return GloomBeasts.Clock() - beast.ChaseSince <= MAX_CHASE_TIME
end

function GloomBeasts.StepBeast(beast: Beast)
	local def = beast.Def
	local pos = beast.Root.Position
	local now = GloomBeasts.Clock()
	if beast.State == "Sleep" then
		return
	elseif beast.State == "Chase" then
		local target = beast.Target
		if not target or not canChase(beast, target) then
			calm(beast)
			return
		end
		local root = rootOf(target) :: BasePart
		GloomBeasts.Move(beast, root.Position)
		local size = beast.Root.Size
		local dist = flat(root.Position - pos).Magnitude - math.max(size.X, size.Z) / 2
		if dist <= def.Reach and now - beast.LastAttack >= def.Cooldown then
			attack(beast, target)
		end
	elseif beast.State == "Return" then
		if flat(beast.Home - pos).Magnitude < 3 then
			beast.State = "Sleep"
			beast.HP = def.HP
			beast.Damage = {}
			setAnchored(beast, true)
			setBar(beast)
		else
			GloomBeasts.Move(beast, beast.Home)
		end
	elseif beast.State == "Wander" then
		-- anyone close enough? (hostiles only)
		if def.Kind == "Hostile" then
			local best, bestDist = nil, def.Aggro
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				if root and (beast.Ignore[player] or 0) <= now then
					local d = flat(root.Position - pos).Magnitude
					if d < bestDist and Gloomwood.RingAt(root.Position) and not nearLantern(root.Position) then
						best, bestDist = player, d
					end
				end
			end
			if best then
				chase(beast, best)
				return
			end
		end
		-- amble about near home, never towards a lantern
		if not beast.Goal or flat(beast.Goal - pos).Magnitude < 3 then
			local rng = GloomBeasts.Rng
			for _ = 1, 6 do
				local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(8, 30)
				local goal = beast.Home + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
				if Gloomwood.RingAt(goal) and not nearLantern(goal) then
					beast.Goal = goal
					break
				end
			end
		end
		if beast.Goal then
			GloomBeasts.Move(beast, beast.Goal)
		end
	end
end

-- Pets hit whatever animal their owner's pets are pointed at (every second)
function GloomBeasts.PetTick(dt: number)
	for _, player in Players:GetPlayers() do
		local value = petTargetOf(player)
		local beast = value and value.Value and beasts[value.Value :: Model]
		local data = beast and PlayerData.Get(player)
		if beast and data then
			local _, equipped = PlayerData.CountCreatures(data)
			local amount = math.min(equipped * Gloomwood.PetBeastDamage, Gloomwood.PetBeastDamageMax) * dt
			if amount > 0 then
				GloomBeasts.Hurt(beast, player, amount)
			end
		end
	end
end

function GloomBeasts.Remove(player: Player)
	for _, beast in beasts do
		beast.Damage[player] = nil
		beast.Ignore[player] = nil
		if beast.Target == player then
			calm(beast)
		end
	end
end

function GloomBeasts.Start(parent: Instance)
	local f = Instance.new("Folder")
	f.Name = "Beasts"
	f.Parent = parent
	folder = f
	for _, def in Gloomwood.Beasts do
		if def.Kind == "Hostile" then
			for _ = 1, def.Count do
				GloomBeasts.SpawnHostile(def)
			end
		end
	end
	Players.PlayerRemoving:Connect(GloomBeasts.Remove)
	task.spawn(function()
		local petClock = 0
		while true do
			local dt = task.wait(0.2) or 0.2
			for _, beast in beasts do
				local ok, err = pcall(GloomBeasts.StepBeast, beast)
				if not ok then
					warn("[GloomBeasts] " .. tostring(err))
				end
			end
			petClock += dt
			if petClock >= 1 then
				pcall(GloomBeasts.PetTick, petClock)
				petClock = 0
			end
		end
	end)
end

return GloomBeasts
