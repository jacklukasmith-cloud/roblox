--[[
	Mana crystals, Pet Simulator style.

	Clicking a crystal sends your equipped creatures at it. Every PetAttackInterval they deal
	your Power as damage. When a crystal breaks, everyone who damaged it is paid for their
	share, and the client shows Essence orbs bursting out and flying into the player.
	Crystals are shared, so groups of players can team up on big Mana Chests.

	Each player's current target is an ObjectValue "PetTarget" so every client can show
	that player's creatures flying to it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Monetization = require(script.Parent.Monetization)
local DailyRewards = require(script.Parent.DailyRewards)

local Crystals = {}

export type Options = {
	HPMultiplier: number?,
	RewardMultiplier: number?,
	RespawnTime: number?,
	Kind: string?,
	-- one-off targets (bosses): no respawn; OnBreak gets everyone's damage when it breaks
	NoRespawn: boolean?,
	OnBreak: ((damage: { [Player]: number }) -> ())?,
}

type CrystalState = {
	Model: Model,
	Main: BasePart,
	Parts: { { Part: BasePart, Transparency: number, CanCollide: boolean } },
	Zone: number,
	BaseHP: number,
	MaxHP: number,
	HP: number,
	SizeReward: number,
	RewardMultiplier: number,
	RespawnTime: number,
	Kind: string,
	NoRespawn: boolean,
	OnBreak: ((damage: { [Player]: number }) -> ())?,
	Broken: boolean,
	Damage: { [Player]: number },
	Bar: Frame,
	Label: TextLabel,
}

local states: { [Model]: CrystalState } = {}
local combos: { [Player]: { Count: number, ExpiresAt: number } } = {}
local critRng = Random.new()
local targets: { [Player]: Model } = {}
local targetSince: { [Player]: number } = {}
local lastWarn: { [Player]: number } = {}
local notify = Remotes.Event("Notify")
local crystalHit = Remotes.Event("CrystalHit")
local crystalBroken = Remotes.Event("CrystalBroken")

local function characterPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function targetValue(player: Player): ObjectValue
	local value = player:FindFirstChild("PetTarget") :: ObjectValue?
	if not value then
		local v = Instance.new("ObjectValue")
		v.Name = "PetTarget"
		v.Parent = player
		value = v
	end
	return value :: ObjectValue
end

local function setTarget(player: Player, model: Model?)
	if targets[player] ~= model then
		targetSince[player] = os.clock()
	end
	targets[player] = model
	local value = targetValue(player)
	if value.Value ~= model then
		value.Value = model
	end
end

local function updateBar(state: CrystalState)
	local pct = math.clamp(state.HP / state.MaxHP, 0, 1)
	state.Bar.Size = UDim2.fromScale(pct, 1)
	state.Label.Text = Format.Number(math.ceil(state.HP))
end

-- Rolls this crystal's strength (normal crystals only) and resizes it to match,
-- keeping its base on the ground
local sizeRng = Random.new()
local function rollSize(state: CrystalState)
	if state.Kind ~= "Crystal" then
		return
	end
	local sizes = Config.CrystalSizes
	local total = 0
	for _, size in sizes do
		total += size.Weight
	end
	local roll = sizeRng:NextNumber() * total
	local chosen = sizes[1]
	for _, size in sizes do
		roll -= size.Weight
		if roll <= 0 then
			chosen = size
			break
		end
	end
	state.MaxHP = state.BaseHP * chosen.HP
	state.HP = state.MaxHP
	state.SizeReward = chosen.Reward
	state.Model:SetAttribute("Size", chosen.Name)
	local model = state.Model
	if math.abs(model:GetScale() - chosen.Scale) > 1e-3 then
		local before = model:GetBoundingBox()
		local _, sizeBefore = model:GetBoundingBox()
		local bottom = before.Position.Y - sizeBefore.Y / 2
		model:ScaleTo(chosen.Scale)
		local after, sizeAfter = model:GetBoundingBox()
		local shift = bottom - (after.Position.Y - sizeAfter.Y / 2)
		model:PivotTo(model:GetPivot() + Vector3.new(0, shift, 0))
	end
end

local function breakCrystal(state: CrystalState)
	state.Broken = true
	local damage = state.Damage
	state.Damage = {}
	local orbs = if state.Kind == "Crystal" then Config.OrbsPerBreak else Config.OrbsPerChest
	local now = os.clock()
	for player, dealt in damage do
		if player.Parent then
			local share = math.min(dealt / state.MaxHP, 1)
			-- back-to-back breaks build a combo that boosts this break's Essence
			local combo = combos[player]
			if combo and now <= combo.ExpiresAt then
				combo.Count = math.min(combo.Count + 1, Config.Combo.Max)
			else
				combo = { Count = 1, ExpiresAt = 0 }
				combos[player] = combo
			end
			combo.ExpiresAt = now + Config.Combo.Window
			local comboMult = 1 + (combo.Count - 1) * Config.Combo.Step
			local earned =
				Economy.AwardCrystal(player, state.Zone, share, state.RewardMultiplier * state.SizeReward * comboMult)
			crystalBroken:FireClient(
				player,
				state.Model,
				earned,
				math.max(1, math.round(orbs * math.max(share, 0.3))),
				combo.Count,
				Config.Combo.Window
			)
			DailyRewards.Track(player, if state.Kind == "Chest" then "BreakChests" else "BreakCrystals", 1)
		end
	end
	-- Creatures attacking this crystal go back to their owners
	for player, model in targets do
		if model == state.Model then
			setTarget(player, nil)
		end
	end
	for _, entry in state.Parts do
		entry.Part.Transparency = 1
		entry.Part.CanCollide = false
	end
	local light = state.Main:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = false
	end
	local billboard = state.Main:FindFirstChild("HealthGui") :: BillboardGui?
	if billboard then
		billboard.Enabled = false
	end
	local burst = state.Main:FindFirstChild("Burst") :: ParticleEmitter?
	if burst then
		burst:Emit(if state.Kind == "Crystal" then 30 else 80)
	end
	if state.OnBreak then
		task.spawn(state.OnBreak, damage)
	end
	if state.NoRespawn then
		states[state.Model] = nil
		return
	end
	task.delay(state.RespawnTime, function()
		state.HP = state.MaxHP
		rollSize(state)
		state.Broken = false
		for _, entry in state.Parts do
			entry.Part.Transparency = entry.Transparency
			entry.Part.CanCollide = entry.CanCollide
		end
		if light then
			light.Enabled = true
		end
		if billboard then
			billboard.Enabled = true
		end
		updateBar(state)
	end)
end

local function damage(player: Player, state: CrystalState, amount: number, crit: boolean?)
	if state.Broken or amount <= 0 then
		return
	end
	local dealt = math.min(amount, state.HP)
	state.HP -= dealt
	state.Damage[player] = (state.Damage[player] or 0) + dealt
	crystalHit:FireClient(player, state.Model, dealt, crit == true)
	if state.HP <= 0 then
		breakCrystal(state)
	else
		updateBar(state)
	end
end

local function canAttack(player: Player, state: CrystalState, maxDistance: number, warn: boolean): boolean
	local data = PlayerData.Get(player)
	if not data or state.Broken then
		return false
	end
	if state.Zone > data.ZonesUnlocked then
		local now = os.clock()
		if warn and now - (lastWarn[player] or 0) > 2 then
			lastWarn[player] = now
			local zone = Zones.Get(state.Zone)
			notify:FireClient(
				player,
				`Unlock {zone and zone.Name or "this zone"} first!`,
				Color3.fromRGB(255, 120, 120)
			)
		end
		return false
	end
	local pos = characterPosition(player)
	return pos ~= nil and (pos - state.Main.Position).Magnitude <= maxDistance
end

-- Player clicked a crystal: send their creatures at it. Damage starts once they arrive.
function Crystals.Target(player: Player, model: Model)
	local state = states[model]
	if not state or not canAttack(player, state, Config.MaxHitDistance, true) then
		return
	end
	setTarget(player, model)
end

function Crystals.Register(model: Model, zoneIndex: number, options: Options?)
	local zone = Zones.Get(zoneIndex)
	assert(zone, "bad zone")
	local o: Options = options or {}
	local main = model.PrimaryPart :: BasePart
	local gui = main:FindFirstChild("HealthGui") :: BillboardGui
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, { Part = d, Transparency = d.Transparency, CanCollide = d.CanCollide })
		end
	end
	local maxHP = zone.CrystalHP * (o.HPMultiplier or 1)
	local state: CrystalState = {
		Model = model,
		Main = main,
		Parts = parts,
		Zone = zoneIndex,
		BaseHP = maxHP,
		MaxHP = maxHP,
		HP = maxHP,
		SizeReward = 1,
		RewardMultiplier = o.RewardMultiplier or 1,
		RespawnTime = o.RespawnTime or Config.CrystalRespawnTime,
		Kind = o.Kind or "Crystal",
		NoRespawn = o.NoRespawn == true,
		OnBreak = o.OnBreak,
		Broken = false,
		Damage = {},
		Bar = (gui :: any).Back.Fill,
		Label = (gui :: any).Back.Amount,
	}
	states[model] = state
	model:SetAttribute("Breakable", state.Kind)
	rollSize(state)
	updateBar(state)
	-- A ClickDetector inside a Model makes every part of it clickable
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = Config.MaxHitDistance
	detector.MouseClick:Connect(function(player)
		Crystals.Target(player, model)
	end)
	detector.Parent = model
end

-- Removes a breakable (e.g. a boss that escaped); creatures attacking it return to their owners
function Crystals.Unregister(model: Model)
	states[model] = nil
	for player, target in targets do
		if target == model then
			setTarget(player, nil)
		end
	end
end

-- Current HP and each player's damage so far (for live boss boards)
function Crystals.GetStatus(model: Model): (number, number, { [Player]: number })
	local state = states[model]
	if not state then
		return 0, 0, {}
	end
	return state.HP, state.MaxHP, state.Damage
end

local function nearestCrystal(player: Player, range: number): Model?
	local data = PlayerData.Get(player)
	local pos = characterPosition(player)
	if not data or not pos then
		return nil
	end
	local best, bestDist = nil, range
	for model, state in states do
		if not state.Broken and state.Kind ~= "Boss" and state.Zone <= data.ZonesUnlocked then
			local dist = (state.Main.Position - pos).Magnitude
			if dist < bestDist then
				best, bestDist = model, dist
			end
		end
	end
	return best
end

-- One creature attack tick for every player (runs every PetAttackInterval)
function Crystals.Tick()
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data then
			local model = targets[player]
			local state = model and states[model]
			if state and not canAttack(player, state, Config.MaxAttackDistance, false) then
				setTarget(player, nil)
				state = nil
			end
			-- Auto Collect pass: pick the nearest crystal automatically
			if not state and data.AutoCollectEnabled and Monetization.Owns(player, "AutoCollect") then
				local nearest = nearestCrystal(player, Config.AutoCollectRange)
				if nearest then
					setTarget(player, nearest)
					state = states[nearest]
				end
			end
			-- Creatures need a moment to fly over before they start hitting
			if state and os.clock() - (targetSince[player] or 0) >= Config.PetTravelTime then
				local amount = Economy.GetPower(data) * Config.PetDamageMultiplier
				local crit = critRng:NextNumber() < Config.Crit.Chance
				if crit then
					amount *= Config.Crit.Multiplier
				end
				damage(player, state, amount, crit)
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(Config.PetAttackInterval)
		Crystals.Tick()
	end
end)

Players.PlayerAdded:Connect(targetValue)
for _, player in Players:GetPlayers() do
	targetValue(player)
end

Players.PlayerRemoving:Connect(function(player)
	targets[player] = nil
	targetSince[player] = nil
	lastWarn[player] = nil
	combos[player] = nil
	for _, state in states do
		state.Damage[player] = nil
	end
end)

return Crystals
