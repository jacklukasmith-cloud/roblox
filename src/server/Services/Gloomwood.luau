--[[
	The Gloomwood (Shared/Gloomwood, built by GloomwoodBuilder): Gloom Crystals, the satchel,
	Courier Lanterns, the Gloom meter and getting in and out.

	- Gloom Crystals grow at hidden spots and are mined with the pickaxe (Pickaxe calls
	  Gloomwood.Swing). Everyone who helped mine one gets it, if their satchel has room. A mined
	  crystal grows back somewhere else after a while.
	- Stand by a Courier Lantern (or the gate) to send your satchel to your Sanctuary's Crystal Vault.
	- The Gloom meter fills while you're in the forest (faster in the Midwood) and drops by a lantern.
	  If it fills up you're pushed back to the hub and drop half of the crystals you hadn't sent home.
	- Players get the attributes InGloomwood, Gloom (0-100) for the meter on screen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gloomwood = require(Shared.Gloomwood)
local Sanctuary = require(Shared.Sanctuary)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local GloomwoodBuilder = require(script.Parent.GloomwoodBuilder)
local GloomBeasts = require(script.Parent.GloomBeasts)

local Service = {}

local rgb = Color3.fromRGB
local notify = Remotes.Event("Notify")

local TICK = 0.25
local HELP_WINDOW = 15 -- seconds: hitting a crystal this recently counts as helping mine it
local PAD_RADIUS = 4.5
local TELEPORT_COOLDOWN = 2

type CrystalState = {
	Id: string,
	Spot: number,
	HP: number,
	MaxHP: number,
	Main: BasePart,
	Hitters: { [Player]: number },
}

local layout: GloomwoodBuilder.Layout? = nil
local campPad: BasePart? = nil
local gatePad: BasePart? = nil
local crystalFolder: Folder? = nil
local crystals: { [Model]: CrystalState } = {}
local taken: { [string]: { [number]: boolean } } = {} -- crystal id -> spot index -> in use
local gloom: { [Player]: number } = {}
local warned: { [Player]: boolean } = {}
local lastTeleport: { [Player]: number } = {}
local lastPadMessage: { [Player]: number } = {}
local lastFullMessage: { [Player]: number } = {}

Service.Rng = Random.new()
Service.Clock = os.clock

local function gloomData(data: any): any
	data.Gloom = data.Gloom or {}
	local g = data.Gloom
	g.Satchel = g.Satchel or {}
	g.Vault = g.Vault or {}
	if g.CampFound == nil then
		g.CampFound = false
	end
	return g
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function teleport(player: Player, position: Vector3, lookAt: Vector3?): boolean
	local now = Service.Clock()
	if now - (lastTeleport[player] or -math.huge) < TELEPORT_COOLDOWN then
		return false
	end
	local character = player.Character
	local root = rootOf(player)
	if not character or not root then
		return false
	end
	lastTeleport[player] = now
	local target = lookAt or (position + Vector3.new(0, 0, -1))
	character:PivotTo(CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z)))
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

-- In front of the Gloomwood gate in the hub
local function hubGate(): Vector3
	local world = workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	for _, d in if hub then hub:GetDescendants() else {} do
		if d:IsA("BasePart") and d:GetAttribute("PortalTo") == "Gloomwood" then
			return Vector3.new(d.Position.X, 3, d.Position.Z + 14)
		end
	end
	return Vector3.new(0, 3, 0)
end

function Service.IsInside(player: Player): boolean
	local root = rootOf(player)
	return root ~= nil and Gloomwood.RingAt(root.Position) ~= nil
end

-- Crystals ---------------------------------------------------------------------------------

local function buildCrystal(def: any, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = def.Id
	model:SetAttribute("GloomCrystal", def.Id)
	local main = Instance.new("Part")
	main.Name = "Main"
	main.Anchored = true
	main.Size = Vector3.new(2.4, 2.4, 2.4)
	main.Position = position + Vector3.new(0, 1.2, 0)
	main.Transparency = 1
	main.CanCollide = false
	main.Parent = model
	local rng = Service.Rng
	for i = 1, 4 do
		local shard = Instance.new("Part")
		shard.Name = "Shard"
		shard.Anchored = true
		shard.CanCollide = false
		shard.Material = Enum.Material.Neon
		shard.Color = def.Color
		shard.Transparency = 0.1
		local h = 1.6 + i * 0.5
		shard.Size = Vector3.new(0.7, h, 0.7)
		local a = i / 4 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		shard.CFrame = CFrame.new(position + Vector3.new(math.sin(a) * 0.5, h / 2, math.cos(a) * 0.5))
			* CFrame.Angles(math.sin(a) * 0.35, rng:NextNumber(0, 6), math.cos(a) * 0.35)
		shard.Parent = model
	end
	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = main
	model.PrimaryPart = main
	return model
end

local function spawnCrystal(def: any): Model?
	local spots = layout and layout.Spots[def.Id]
	if not spots or #spots == 0 then
		return nil
	end
	taken[def.Id] = taken[def.Id] or {}
	local free = {}
	for i in spots do
		if not taken[def.Id][i] then
			table.insert(free, i)
		end
	end
	if #free == 0 then
		return nil
	end
	local index = free[Service.Rng:NextInteger(1, #free)]
	taken[def.Id][index] = true
	local model = buildCrystal(def, spots[index])
	crystals[model] = {
		Id = def.Id,
		Spot = index,
		HP = def.Hits,
		MaxHP = def.Hits,
		Main = model.PrimaryPart :: BasePart,
		Hitters = {},
	}
	model.Parent = crystalFolder
	GloomBeasts.OnCrystal(model, def.Id, spots[index])
	return model
end

-- Puts a crystal in the satchel; false if it's full
function Service.AddToSatchel(player: Player, id: string): boolean
	local data = PlayerData.Get(player) :: any
	if not data then
		return false
	end
	local g = gloomData(data)
	if Gloomwood.SatchelCount(g.Satchel) >= Gloomwood.SatchelSize then
		return false
	end
	g.Satchel[id] = (g.Satchel[id] or 0) + 1
	data.Stats.GloomMined = (data.Stats.GloomMined or 0) + 1
	PlayerData.MarkChanged(player)
	return true
end

local function mined(model: Model, state: CrystalState)
	local def = Gloomwood.Get(state.Id)
	crystals[model] = nil
	GloomBeasts.CrystalGone(model)
	local now = Service.Clock()
	for player, at in state.Hitters do
		if player.Parent and now - at <= HELP_WINDOW then
			if Service.AddToSatchel(player, state.Id) then
				notify:FireClient(player, `+1 {def.Name}`, def.Color)
			else
				notify:FireClient(
					player,
					"🎒 Your satchel is full! Stand by a Courier Lantern to send it home",
					rgb(255, 170, 120)
				)
			end
		end
	end
	-- let the last hit's sparks play, then it's gone
	task.delay(0.15, function()
		model:Destroy()
	end)
	-- it grows back somewhere else (a spot can't be reused until this one is freed)
	task.delay(def.Regrow, function()
		taken[state.Id][state.Spot] = nil
		spawnCrystal(def)
	end)
end

-- A pickaxe swing in the forest: hits an animal that's after you, or else the nearest Gloom Crystal
-- in reach (which wakes up its guardian, if it has one). Returns the model hit.
function Service.Swing(player: Player, damage: number, reach: number): Model?
	local root = rootOf(player)
	if not root or damage <= 0 then
		return nil
	end
	local beast = GloomBeasts.Swing(player, damage, reach)
	if beast then
		return beast
	end
	local best, bestDist = nil, math.huge
	for model, state in crystals do
		local dist = (state.Main.Position - root.Position).Magnitude - state.Main.Size.X / 2
		if dist <= reach and dist < bestDist then
			best, bestDist = model, dist
		end
	end
	local state = best and crystals[best]
	if not state then
		return nil
	end
	state.Hitters[player] = Service.Clock()
	GloomBeasts.CrystalHit(best :: Model, player)
	state.HP -= damage
	if state.HP <= 0 then
		mined(best :: Model, state)
	end
	return best
end

-- Distance to the nearest Gloom Crystal (for "get closer")
function Service.NearestDistance(player: Player): number
	local root = rootOf(player)
	local best = math.huge
	if root then
		for _, state in crystals do
			best = math.min(best, (state.Main.Position - root.Position).Magnitude - state.Main.Size.X / 2)
		end
	end
	return best
end

-- An animal's hit: more Gloom
function Service.AddGloom(player: Player, amount: number)
	local level = math.clamp((gloom[player] or 0) + amount, 0, Gloomwood.Gloom.Max)
	gloom[player] = level
	player:SetAttribute("Gloom", math.floor(level))
end

-- Knocks one random crystal out of the satchel (it's lost). Returns which.
function Service.Steal(player: Player): string?
	local data = PlayerData.Get(player) :: any
	if not data then
		return nil
	end
	local g = gloomData(data)
	local ids = {}
	for id, n in g.Satchel do
		for _ = 1, n do
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		return nil
	end
	local id = ids[Service.Rng:NextInteger(1, #ids)]
	g.Satchel[id] -= 1
	if g.Satchel[id] <= 0 then
		g.Satchel[id] = nil
	end
	PlayerData.MarkChanged(player)
	return id
end

-- Satchel and Vault ----------------------------------------------------------------------

-- Sends the satchel to the Vault (as much as fits). Returns how many went.
function Service.Bank(player: Player): number
	local data = PlayerData.Get(player) :: any
	if not data then
		return 0
	end
	local g = gloomData(data)
	if Gloomwood.SatchelCount(g.Satchel) == 0 then
		return 0
	end
	local level = data.Sanctuary and data.Sanctuary.Level or 1
	local room = Sanctuary.VaultCapacity(level) - Gloomwood.SatchelCount(g.Vault)
	local moved = 0
	for _, def in Gloomwood.Crystals do
		local n = math.min(g.Satchel[def.Id] or 0, room)
		if n > 0 then
			g.Satchel[def.Id] -= n
			if g.Satchel[def.Id] <= 0 then
				g.Satchel[def.Id] = nil
			end
			g.Vault[def.Id] = (g.Vault[def.Id] or 0) + n
			room -= n
			moved += n
		end
	end
	local now = Service.Clock()
	if moved > 0 then
		data.Stats.GloomBanked = (data.Stats.GloomBanked or 0) + moved
		PlayerData.MarkChanged(player)
		notify:FireClient(
			player,
			`🏮 Sent {moved} Gloom Crystal{if moved == 1 then "" else "s"} home to your Vault`,
			rgb(255, 210, 130)
		)
	elseif now - (lastFullMessage[player] or -math.huge) > 20 then
		lastFullMessage[player] = now
		notify:FireClient(player, "💎 Your Vault is full! Sell some crystals at your island", rgb(255, 170, 120))
	end
	return moved
end

-- Sells crystals from the Vault for Essence. Returns ok, message.
function Service.Sell(player: Player, id: any, count: any): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	local def = type(id) == "string" and Gloomwood.Get(id)
	if not data or not def or type(count) ~= "number" or count ~= count then
		return false, nil
	end
	local g = gloomData(data)
	local n = math.min(math.floor(count), g.Vault[id] or 0)
	if n <= 0 then
		return false, "You don't have any of those"
	end
	local essence = Economy.GetProductEssence(player, def.Sell) * n
	g.Vault[id] -= n
	if g.Vault[id] <= 0 then
		g.Vault[id] = nil
	end
	Economy.AddEssence(player, essence)
	PlayerData.MarkChanged(player)
	return true, `Sold {n} {def.Name} for 💎 {Format.Number(essence)}`
end

-- Getting in and out -----------------------------------------------------------------------

function Service.Enter(player: Player): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data or not layout then
		return false, nil
	end
	if (data.ZonesUnlocked or 1) < Gloomwood.UnlockZone then
		return false, "🌲 Unlock Frostpeak to enter the Gloomwood"
	end
	if not teleport(player, layout.Arrival, Gloomwood.Center) then
		return false, nil
	end
	gloom[player] = 0
	warned[player] = false
	data.Stats.GloomwoodVisits = (data.Stats.GloomwoodVisits or 0) + 1
	PlayerData.MarkChanged(player)
	return true, nil
end

function Service.Leave(player: Player): boolean
	return teleport(player, hubGate(), hubGate() + Vector3.new(0, 0, 10))
end

-- The Gloom meter got full: back to the hub, half the unsent crystals are dropped
function Service.GloomOut(player: Player)
	local data = PlayerData.Get(player) :: any
	if data then
		local g = gloomData(data)
		local dropped = 0
		for id, n in g.Satchel do
			local keep = math.ceil(n / 2)
			dropped += n - keep
			g.Satchel[id] = if keep > 0 then keep else nil
		end
		PlayerData.MarkChanged(player)
		notify:FireClient(
			player,
			if dropped > 0
				then `🌑 The gloom was too thick! You dropped {dropped} crystal{if dropped == 1 then "" else "s"}`
				else "🌑 The gloom was too thick! Back to the hub",
			rgb(200, 150, 255)
		)
	end
	gloom[player] = 0
	warned[player] = false
	lastTeleport[player] = nil
	Service.Leave(player)
end

local function near(position: Vector3, target: Vector3, radius: number): boolean
	local flat = (position - target) * Vector3.new(1, 0, 1)
	return flat.Magnitude <= radius and math.abs(position.Y - target.Y) < 10
end

-- One step of the forest loop for a player (dt seconds)
function Service.Update(player: Player, dt: number)
	local root = rootOf(player)
	local data = PlayerData.Get(player) :: any
	if not root or not data or not layout then
		return
	end
	local pos = root.Position
	local ring = Gloomwood.RingAt(pos)
	local cfg = Gloomwood.Gloom
	local level = gloom[player] or 0
	if not ring then
		level = math.max(0, level + cfg.Outside * dt)
		gloom[player] = level
		player:SetAttribute("InGloomwood", nil)
		player:SetAttribute("Gloom", if level > 0 then math.floor(level) else nil)
		return
	end
	player:SetAttribute("InGloomwood", true)
	-- by a lantern: send the satchel home and the gloom clears
	local byLantern = false
	for _, lamp in layout.Lanterns do
		if near(pos, lamp, Gloomwood.LanternRadius) then
			byLantern = true
			break
		end
	end
	if byLantern then
		Service.Bank(player)
		level = math.max(0, level + cfg.Lantern * dt)
		warned[player] = false
	else
		level += (if ring == "Edge" then cfg.Edge else cfg.Midwood) * dt
	end
	gloom[player] = level
	player:SetAttribute("Gloom", math.floor(level))
	if level >= cfg.Warn and not warned[player] then
		warned[player] = true
		notify:FireClient(player, "🌑 The gloom is getting thick! Find a lantern", rgb(200, 150, 255))
	end
	if level >= cfg.Max then
		Service.GloomOut(player)
		return
	end
	-- finding the Deep Camp
	local g = gloomData(data)
	local camp = Gloomwood.Place("DeepCamp")
	if not g.CampFound and near(pos, camp, 25) then
		g.CampFound = true
		PlayerData.MarkChanged(player)
		notify:FireClient(
			player,
			"⛺ You found the Deep Camp! You can come straight here from the gate now",
			rgb(255, 200, 120)
		)
	end
	-- the circles at the gate and the camp
	if campPad and near(pos, campPad.Position, PAD_RADIUS) then
		if g.CampFound then
			teleport(player, layout.CampArrival, Gloomwood.Center)
		elseif Service.Clock() - (lastPadMessage[player] or -math.huge) > 4 then
			lastPadMessage[player] = Service.Clock()
			notify:FireClient(player, "⛺ Find the Deep Camp in the Midwood first!", rgb(255, 200, 120))
		end
	elseif gatePad and near(pos, gatePad.Position, PAD_RADIUS) then
		teleport(player, layout.Arrival, Gloomwood.Center)
	end
end

function Service.Remove(player: Player)
	gloom[player] = nil
	warned[player] = nil
	lastTeleport[player] = nil
	lastPadMessage[player] = nil
	lastFullMessage[player] = nil
	for _, state in crystals do
		state.Hitters[player] = nil
	end
end

function Service.Layout(): GloomwoodBuilder.Layout?
	return layout
end

function Service.Start()
	-- straight in the workspace (not World) so the scripts that search the hub and realms don't
	-- have to look through thousands of trees
	local world = workspace:FindFirstChild("World") or workspace
	local built = GloomwoodBuilder.Build(workspace)
	layout = built
	campPad = built.Folder:FindFirstChild("CampPad", true) :: BasePart?
	gatePad = built.Folder:FindFirstChild("GatePad", true) :: BasePart?
	local folder = Instance.new("Folder")
	folder.Name = "GloomCrystals"
	folder.Parent = built.Folder
	crystalFolder = folder
	-- the animals (they need the crystals' spots, so they start first)
	GloomBeasts.Hooks.AddGloom = Service.AddGloom
	GloomBeasts.Hooks.AddToSatchel = Service.AddToSatchel
	GloomBeasts.Hooks.Steal = Service.Steal
	GloomBeasts.Hooks.Lanterns = function()
		return built.Lanterns
	end
	GloomBeasts.Start(built.Folder)
	for _, def in Gloomwood.Crystals do
		for _ = 1, def.Active do
			spawnCrystal(def)
		end
	end

	-- the gate in the hub and the way back out
	local function hookPortal(part: BasePart, to: string)
		part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			if to == "Gloomwood" then
				local ok, message = Service.Enter(player)
				if not ok and message and Service.Clock() - (lastPadMessage[player] or -math.huge) > 4 then
					lastPadMessage[player] = Service.Clock()
					notify:FireClient(player, message, rgb(150, 230, 170))
				end
			else
				Service.Leave(player)
			end
		end)
	end
	for _, d in built.Folder:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("PortalTo") == "Hub" then
			hookPortal(d, "Hub")
		end
	end
	local hub = world:FindFirstChild("Hub")
	for _, d in if hub then hub:GetDescendants() else {} do
		if d:IsA("BasePart") and d:GetAttribute("PortalTo") == "Gloomwood" then
			hookPortal(d, "Gloomwood")
		end
	end

	Players.PlayerRemoving:Connect(Service.Remove)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(Service.Update, player, TICK)
				if not ok then
					warn("[Gloomwood] " .. tostring(err))
				end
			end
		end
	end)
end

return Service
