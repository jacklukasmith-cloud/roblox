--[[
	Boss raids: every Config.Boss.Interval a giant Rainbow creature appears in one of the realms
	(taking turns). Everyone's creatures attack it like a crystal (crits and combos included).
	Its HP is sized from the whole server's power so it takes about a minute together.

	When it falls, everyone who hit it is paid Essence by their share of the damage, the top 3
	get extra Trophies and #1 also gets a Mystic Egg hatch. If nobody beats it in time it escapes.
	A live boss bar (BossUpdate) shows HP, time left and the top damage dealers.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local Eggs = require(Shared.Eggs)
local CreatureModels = require(Shared.CreatureModels)
local Zones = require(Shared.Zones)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Crystals = require(script.Parent.Crystals)
local Hatching = require(script.Parent.Hatching)
local WorldBuilder = require(script.Parent.WorldBuilder)

local BossRaid = {}

local bossUpdate = Remotes.Event("BossUpdate")
local notify = Remotes.Event("Notify")
local BOSS_COLOR = Color3.fromRGB(255, 90, 140)

type Active = {
	Model: Model,
	Main: BasePart,
	Zone: number,
	CreatureId: string,
	Name: string,
	EndsAt: number,
}

local active: Active? = nil
local nextSpawnAt = 0 -- os.time() of the next scheduled boss
local rng = Random.new()

-- The boss is one of the two strongest creatures from that realm's own egg, so early realms get
-- gentler bosses (a Meadow boss is a Moon Rabbit or Fae Dragonling, Sky Sanctum brings the Void Leviathan)
local function bossCandidates(zoneIndex: number): { string }
	local zone = Zones.Get(zoneIndex)
	local list = if zone then Eggs.SetOf(zone.EggId) else {}
	table.sort(list, function(a, b)
		return Creatures.RarityOrder(a) > Creatures.RarityOrder(b)
	end)
	while #list > 2 do
		table.remove(list)
	end
	if #list == 0 then
		list = { "Phoenix" }
	end
	return list
end

-- Damage per second of the players who can actually reach the realm (sizes the boss's HP)
local function serverDps(zoneIndex: number): number
	local total = 0
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data and data.ZonesUnlocked >= zoneIndex then
			total += Economy.GetPower(data) * Config.PetDamageMultiplier / Config.PetAttackInterval
		end
	end
	return math.max(total, 1)
end

-- A realm somebody on the server has unlocked, leaning towards the furthest one
local function pickZone(): number
	local best = 1
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data then
			best = math.max(best, data.ZonesUnlocked)
		end
	end
	best = math.clamp(best, 1, #Zones.List)
	-- 60% the furthest realm anyone has reached, otherwise any realm up to it
	return if rng:NextNumber() < 0.6 then best else rng:NextInteger(1, best)
end

local function topDamage(damage: { [Player]: number }, count: number): { { Player: Player, Damage: number } }
	local list = {}
	for player, dealt in damage do
		if player.Parent then
			table.insert(list, { Player = player, Damage = dealt })
		end
	end
	table.sort(list, function(a, b)
		return a.Damage > b.Damage
	end)
	while #list > count do
		table.remove(list)
	end
	return list
end

local function broadcast()
	local boss = active
	if not boss then
		bossUpdate:FireAllClients({ Active = false, NextAt = nextSpawnAt })
		return
	end
	local hp, maxHp, damage = Crystals.GetStatus(boss.Model)
	local top = {}
	for _, entry in topDamage(damage, 5) do
		table.insert(top, { Name = entry.Player.DisplayName, UserId = entry.Player.UserId, Damage = entry.Damage })
	end
	local zone = Zones.Get(boss.Zone)
	bossUpdate:FireAllClients({
		Active = true,
		Name = boss.Name,
		Zone = boss.Zone,
		ZoneName = zone and zone.Name or "",
		HP = hp,
		MaxHP = maxHp,
		EndsAt = boss.EndsAt,
		Top = top,
	})
end

local function despawn()
	local boss = active
	if not boss then
		return
	end
	active = nil
	Crystals.Unregister(boss.Model)
	task.delay(1.5, function()
		boss.Model:Destroy()
	end)
	broadcast()
end

local function onDefeated(damage: { [Player]: number })
	local boss = active
	if not boss then
		return
	end
	nextSpawnAt = os.time() + Config.Boss.Interval
	local ranking = topDamage(damage, math.huge)
	for rank, entry in ranking do
		local player = entry.Player
		local data = PlayerData.Get(player)
		if data then
			local trophies = Config.Boss.TopTrophies[rank] or Config.Boss.ParticipationTrophies
			data.Trophies += trophies
			PlayerData.MarkChanged(player)
			local extra = ""
			if rank == 1 and Hatching.MysticHatch(player) then
				extra = " + a Mystic Egg"
			end
			notify:FireClient(
				player,
				`Boss defeated! You were #{rank} for damage: +{trophies} Trophies{extra}`,
				Color3.fromRGB(255, 220, 90)
			)
		end
	end
	local mvp = ranking[1]
	for _, player in Players:GetPlayers() do
		if not damage[player] then
			notify:FireClient(
				player,
				`{boss.Name} was defeated{if mvp then " - MVP: " .. mvp.Player.DisplayName else ""}!`,
				BOSS_COLOR
			)
		end
	end
	despawn()
end

local function buildBoss(zoneIndex: number, creatureId: string): (Model, BasePart)
	local zone = Zones.Get(zoneIndex) :: Zones.ZoneDef
	local z0 = WorldBuilder.Helpers.ZoneStart(zoneIndex)
	local position = Vector3.new(0, 7, z0 + 68 * WorldBuilder.Helpers.Spread)
	local model = Instance.new("Model")
	model.Name = "Boss"
	local main = Instance.new("Part")
	main.Name = "Main"
	main.Size = Vector3.new(12, 12, 12)
	main.CFrame = CFrame.new(position)
	main.Anchored = true
	main.CanCollide = false
	main.Transparency = 1
	main.Parent = model
	model.PrimaryPart = main

	-- bosses in later realms are bigger
	local rig = CreatureModels.Build(creatureId, "Rainbow", Config.Boss.Scale * (0.75 + 0.15 * zoneIndex))
	CreatureModels.Place(rig, CFrame.new(position) * CFrame.Angles(0, math.pi, 0))
	rig.Model:SetAttribute("Bob", 1)
	rig.Model.Parent = model
	-- Creature parts normally ignore the mouse; the boss has to be clickable/tappable anywhere
	for _, d in rig.Model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = true
		end
	end
	-- and the invisible hitbox covers the whole body (it also anchors the health bar and range checks)
	local boxCFrame, boxSize = rig.Model:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - boxSize.Y / 2
	if bottom < 0.5 then -- big creatures would otherwise sink into the ground
		rig.Model:PivotTo(rig.Model:GetPivot() + Vector3.new(0, 0.5 - bottom, 0))
		boxCFrame, boxSize = rig.Model:GetBoundingBox()
	end
	main.Size = boxSize + Vector3.new(2, 2, 2)
	main.CFrame = CFrame.new(boxCFrame.Position)

	local helpers = WorldBuilder.Helpers
	helpers.HealthBar(main, BOSS_COLOR, 320, boxSize.Y / 2 + 3)
	helpers.Burst(main, BOSS_COLOR)
	helpers.Light(main, BOSS_COLOR, 40, 3)
	local title = helpers.Billboard(main, UDim2.fromOffset(360, 40), Vector3.new(0, boxSize.Y / 2 + 6.5, 0), 200)
	helpers.Label(title, {
		Text = `⚔️ BOSS: {Creatures.DisplayName(creatureId, "Rainbow")}`,
		TextColor3 = Color3.fromRGB(255, 220, 90),
	})
	local folder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Bosses")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Bosses"
		folder.Parent = workspace:FindFirstChild("World") or workspace
	end
	model.Parent = folder
	return model, main
end

-- Spawns a boss now (zoneIndex optional: otherwise realms take turns)
function BossRaid.Spawn(zoneIndex: number?): boolean
	if active then
		return false
	end
	local zoneIdx = zoneIndex or pickZone()
	local zone = Zones.Get(zoneIdx)
	if not zone then
		return false
	end
	local candidates = bossCandidates(zoneIdx)
	local creatureId = candidates[rng:NextInteger(1, #candidates)]
	local model, main = buildBoss(zoneIdx, creatureId)
	local hp = serverDps(zoneIdx) * Config.Boss.TargetSeconds
	Crystals.Register(model, zoneIdx, {
		HPMultiplier = math.max(hp / zone.CrystalHP, 40),
		RewardMultiplier = Config.Boss.RewardMultiplier,
		Kind = "Boss",
		NoRespawn = true,
		OnBreak = onDefeated,
	})
	active = {
		Model = model,
		Main = main,
		Zone = zoneIdx,
		CreatureId = creatureId,
		Name = Creatures.DisplayName(creatureId, "Rainbow"),
		EndsAt = os.time() + Config.Boss.Duration,
	}
	for _, player in Players:GetPlayers() do
		notify:FireClient(
			player,
			`⚔️ A {active.Name} boss appeared in {zone.Name}! Team up to defeat it!`,
			BOSS_COLOR
		)
	end
	broadcast()
	return true
end

-- Removes the current boss without rewards (admin / tests)
function BossRaid.Despawn()
	despawn()
end

-- Teleports a player next to the boss (if they've unlocked its realm)
function BossRaid.GoTo(player: Player): (boolean, string?)
	local boss = active
	local data = PlayerData.Get(player)
	if not boss or not data then
		return false, "There's no boss right now"
	end
	if boss.Zone > data.ZonesUnlocked then
		local zone = Zones.Get(boss.Zone)
		return false, `Unlock {zone and zone.Name or "that realm"} to join this boss`
	end
	local character = player.Character
	if not character then
		return false
	end
	local center = boss.Main.Position
	local spot = Vector3.new(center.X, 4, center.Z - boss.Main.Size.Z / 2 - 16)
	character:PivotTo(CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z)))
	-- send their creatures straight at it
	Crystals.Target(player, boss.Model)
	return true
end

function BossRaid.Start()
	local firstDelay = if RunService:IsStudio() then Config.Boss.StudioFirstDelay else Config.Boss.FirstDelay
	nextSpawnAt = os.time() + firstDelay
	local warned = false
	task.spawn(function()
		while true do
			task.wait(1)
			-- a failure here must never stop future bosses
			local ok, err = pcall(function()
				local boss = active
				local now = os.time()
				if boss then
					if now >= boss.EndsAt then
						for _, player in Players:GetPlayers() do
							notify:FireClient(player, `The {boss.Name} escaped... be faster next time!`, BOSS_COLOR)
						end
						nextSpawnAt = now + Config.Boss.Interval
						warned = false
						despawn()
					else
						broadcast()
					end
				elseif #Players:GetPlayers() > 0 then
					if not warned and now >= nextSpawnAt - Config.Boss.WarnBefore then
						warned = true
						for _, player in Players:GetPlayers() do
							notify:FireClient(
								player,
								`⚔️ A boss raid starts in {math.max(0, nextSpawnAt - now)} seconds!`,
								BOSS_COLOR
							)
						end
					end
					if now >= nextSpawnAt then
						nextSpawnAt = now + Config.Boss.Interval
						warned = false
						BossRaid.Spawn()
					end
				end
			end)
			if not ok then
				warn("[BossRaid] " .. tostring(err))
			end
		end
	end)
	-- the countdown to the next boss, kept fresh for everyone
	task.spawn(function()
		while true do
			task.wait(10)
			if not active then
				broadcast()
			end
		end
	end)
	-- late joiners see the current boss (or the countdown) straight away
	Players.PlayerAdded:Connect(function()
		task.wait(3)
		broadcast()
	end)
end

function BossRaid.Describe(): string
	local boss = active
	return if boss
		then `{boss.Name} ({Format.Time(boss.EndsAt - os.time())} left)`
		else `none (next in {Format.Time(math.max(0, nextSpawnAt - os.time()))})`
end

return BossRaid
