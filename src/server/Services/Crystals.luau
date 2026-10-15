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

local PetStats = require(ReplicatedStorage.Shared.PetStats)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
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
	Swung: { [Player]: boolean }, -- players who landed a pickaxe hit (hands-on bonus)
	ShatterUntil: number, -- Frost Shatter: takes extra damage until this os.clock()
	ShatterBonus: number,
	Bar: Frame,
	Label: TextLabel,
}

local states: { [Model]: CrystalState } = {}
local combos: { [Player]: { Count: number, ExpiresAt: number } } = {}
local critRng = Random.new()
local targets: { [Player]: Model } = {}
local targetSince: { [Player]: number } = {}
local targetDistance: { [Player]: number } = {}
local lastWarn: { [Player]: number } = {}
local notify = Remotes.Event("Notify")
local crystalHit = Remotes.Event("CrystalHit")
local petAbility = Remotes.Event("PetAbility")
local abilityReady: { [Player]: { [string]: number } } = {}
local luckRng = Random.new()

-- Lucky Find: combined chance from every equipped Meadow creature, and the best one (for the effect)
local function luckyFind(player: Player): (number, string?)
	local data = PlayerData.Get(player)
	if not data then
		return 0, nil
	end
	local miss, bestId, bestChance = 1, nil, 0
	for _, entry in data.Creatures or {} do
		if entry.Equipped then
			local ability = PetStats.Ability(entry.Id)
			if ability and ability.Kind == "LuckyFind" then
				local chance = ability.Chance or 0
				miss *= 1 - chance
				if chance > bestChance then
					bestId, bestChance = entry.Id, chance
				end
			end
		end
	end
	return 1 - miss, bestId
end
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
		-- how far the creatures have to fly (they start next to you)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		targetDistance[player] = if root and model
			then math.max(0, ((model:GetPivot().Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude - 3)
			else 0
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
	-- golden crystals: a gold glow (a Highlight works on textured meshes too) and extra Essence
	local golden = sizeRng:NextNumber() < Config.GoldenCrystal.Chance
	state.Model:SetAttribute("Golden", golden)
	local glow = state.Model:FindFirstChild("GoldenGlow")
	local sparkle = state.Main:FindFirstChild("GoldenSparkle")
	if golden then
		state.SizeReward *= Config.GoldenCrystal.Reward
		if glow then
			(glow :: Highlight).Enabled = true
		else
			local highlight = Instance.new("Highlight")
			highlight.Name = "GoldenGlow"
			highlight.FillColor = Color3.fromRGB(255, 205, 60)
			highlight.FillTransparency = 0.45
			highlight.OutlineColor = Color3.fromRGB(255, 240, 160)
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = state.Model
		end
		if sparkle then
			(sparkle :: ParticleEmitter).Enabled = true
		else
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "GoldenSparkle"
			emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 215, 80))
			emitter.LightEmission = 1
			emitter.Rate = 8
			emitter.Lifetime = NumberRange.new(0.8, 1.3)
			emitter.Speed = NumberRange.new(1, 3)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
			emitter.Parent = state.Main
		end
	else
		if glow then
			glow:Destroy()
		end
		if sparkle then
			sparkle:Destroy()
		end
	end
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
	local swung = state.Swung
	state.Swung = {}
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
			-- hands-on bonus: you swung your pickaxe at it yourself
			local handsOn = if swung[player] then Config.Pickaxe.HandsOnBonus else 1
			-- Lucky Find ability: sometimes doubles this break's Essence
			local luckChance, luckyId = luckyFind(player)
			if luckChance > 0 and luckRng:NextNumber() < luckChance then
				handsOn *= 2
				petAbility:FireClient(player, luckyId, "LuckyFind", state.Model)
			end
			local earned = Economy.AwardCrystal(
				player,
				state.Zone,
				share,
				state.RewardMultiplier * state.SizeReward * comboMult * handsOn
			)
			crystalBroken:FireClient(
				player,
				state.Model,
				earned,
				math.max(1, math.round(orbs * math.max(share, 0.3))),
				combo.Count,
				Config.Combo.Window
			)
			DailyRewards.Track(player, if state.Kind == "Chest" then "BreakChests" else "BreakCrystals", 1)
			-- creature XP (bigger crystals give more)
			local xp = if state.Kind == "Chest"
				then Config.PetXP.Chest
				elseif state.Kind == "Boss" then Config.PetXP.Boss
				else Config.PetXP.Crystal * math.max(1, math.round(state.SizeReward))
			Economy.GrantXP(player, xp)
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
	-- a broken golden crystal stops glowing until it respawns (and re-rolls)
	local glow = state.Model:FindFirstChild("GoldenGlow") :: Highlight?
	if glow then
		glow.Enabled = false
	end
	local sparkle = state.Main:FindFirstChild("GoldenSparkle") :: ParticleEmitter?
	if sparkle then
		sparkle.Enabled = false
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
	if os.clock() < state.ShatterUntil then
		amount *= 1 + state.ShatterBonus
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
		Swung = {},
		ShatterUntil = 0,
		ShatterBonus = 0,
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

-- A pickaxe swing: hits the closest breakable (crystal, chest or boss) within reach of the
-- player's character. Returns the model hit (or nil) and whether it was a crit. Same damage path as
-- creatures (crits, combos).
function Crystals.Swing(player: Player, power: number, reach: number, bossMultiplier: number?): (Model?, boolean)
	local pos = characterPosition(player)
	if not pos or power <= 0 then
		return nil, false
	end
	local best, bestDist = nil, math.huge
	local petTarget = targets[player]
	for model, state in states do
		if not state.Broken then
			-- measure to the surface of big things (bosses), not their centre
			local size = state.Main.Size
			local radius = math.max(size.X, size.Z) / 2
			local dist = (state.Main.Position - pos).Magnitude - radius
			-- whatever your creatures are attacking wins if it's in reach, so you join the same fight
			local score = if model == petTarget then dist - 1000 else dist
			if dist <= reach and score < bestDist and canAttack(player, state, math.huge, true) then
				best, bestDist = model, score
			end
		end
	end
	local state = best and states[best]
	if not state then
		return nil, false
	end
	local amount = power * (if state.Kind == "Boss" then bossMultiplier or 1 else 1)
	local crit = critRng:NextNumber() < Config.Crit.Chance
	if crit then
		amount *= Config.Crit.Multiplier
	end
	state.Swung[player] = true
	-- clicks don't reach crystals while a tool is held, so a swing also sends your creatures
	if targets[player] ~= best then
		setTarget(player, best)
	end
	damage(player, state, amount, crit)
	return best, crit
end

-- Distance from a player to the nearest unbroken breakable they could attack (for "get closer")
function Crystals.NearestDistance(player: Player): number
	local pos = characterPosition(player)
	local best = math.huge
	if pos then
		for _, state in states do
			if not state.Broken then
				local size = state.Main.Size
				local dist = (state.Main.Position - pos).Magnitude - math.max(size.X, size.Z) / 2
				best = math.min(best, dist)
			end
		end
	end
	return best
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
		if not state.Broken and state.Zone <= data.ZonesUnlocked then
			local dist = (state.Main.Position - pos).Magnitude
			if state.Kind == "Boss" and dist <= Config.MaxHitDistance then
				return model -- a boss nearby always comes first
			end
			if state.Kind ~= "Boss" and dist < bestDist then
				best, bestDist = model, dist
			end
		end
	end
	return best
end

-- Creature abilities with a cooldown, used while the team is attacking `state`
local function useAbilities(player: Player, data: any, state: CrystalState)
	local now = os.clock()
	local ready = abilityReady[player]
	if not ready then
		ready = {}
		abilityReady[player] = ready
	end
	for uid, entry in data.Creatures or {} do
		local ability = entry.Equipped and PetStats.Ability(entry.Id)
		if ability and ability.Cooldown and now >= (ready[uid] or 0) and not state.Broken then
			ready[uid] = now + ability.Cooldown
			local power = Creatures.GetPower(entry.Id, entry.Variant, entry.Level) * Config.PetDamageMultiplier
			if ability.Kind == "FireBurst" or ability.Kind == "SpiritFlame" then
				petAbility:FireClient(player, entry.Id, ability.Kind, state.Model)
				damage(player, state, power * (ability.Mult or 1), false)
			elseif ability.Kind == "FrostShatter" then
				if now >= state.ShatterUntil then
					state.ShatterBonus = 0
				end
				state.ShatterUntil = now + (ability.Duration or 4)
				state.ShatterBonus = math.max(state.ShatterBonus, ability.Bonus or 0)
				petAbility:FireClient(player, entry.Id, ability.Kind, state.Model)
			elseif ability.Kind == "StormStrike" then
				-- lightning jumps to up to 2 other crystals near the target
				local hits = 0
				for model, other in states do
					if hits >= 2 then
						break
					end
					if
						other ~= state
						and not other.Broken
						and other.Kind == "Crystal"
						and (other.Main.Position - state.Main.Position).Magnitude <= 30
						and canAttack(player, other, math.huge, false)
					then
						hits += 1
						petAbility:FireClient(player, entry.Id, ability.Kind, model)
						damage(player, other, power * (ability.Mult or 1), false)
					end
				end
			end
		end
	end
end

-- One player's creature attack tick (runs every PetAttackInterval)
local function tickPlayer(player: Player)
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
		-- (faster teams get there sooner)
		-- a moment to get going, then the flight itself (both quicker for faster teams)
		local teamSpeed = Economy.GetTeamSpeed(data)
		local travel = (Config.PetTravelTime + (targetDistance[player] or 0) / Config.PetMoveSpeed) / teamSpeed
		-- no creatures out = nobody attacking (your pickaxe still works)
		local _, equipped = PlayerData.CountCreatures(data)
		if state and equipped > 0 and os.clock() - (targetSince[player] or 0) >= travel then
			local amount = Economy.GetTeamDamage(data) * Config.PetDamageMultiplier
			local crit = critRng:NextNumber() < Config.Crit.Chance
			if crit then
				amount *= Config.Crit.Multiplier
			end
			damage(player, state, amount, crit)
			useAbilities(player, data, state)
		end
	end
end

-- One creature attack tick for every player. Each player is isolated so one error (e.g. in a
-- reward hook) can never stop crystal damage for the whole server.
function Crystals.Tick()
	for _, player in Players:GetPlayers() do
		local ok, err = pcall(tickPlayer, player)
		if not ok then
			warn("[Crystals] " .. tostring(err))
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
	abilityReady[player] = nil
	targets[player] = nil
	targetSince[player] = nil
	targetDistance[player] = nil
	lastWarn[player] = nil
	combos[player] = nil
	for _, state in states do
		state.Damage[player] = nil
	end
end)

return Crystals
