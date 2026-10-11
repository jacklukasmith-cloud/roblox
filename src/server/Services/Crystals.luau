--[[
	Mana crystals: click (or auto-collect) to damage them; when one breaks, everyone who
	hit it is paid for the share of damage they dealt. Crystals are shared, so players in
	the same zone race each other for breaks.
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

local Crystals = {}

type CrystalState = {
	Part: BasePart,
	Zone: number,
	MaxHP: number,
	HP: number,
	Broken: boolean,
	Damage: { [Player]: number },
	Bar: Frame,
	Label: TextLabel,
}

local states: { [BasePart]: CrystalState } = {}
local lastHit: { [Player]: number } = {}
local lastWarn: { [Player]: number } = {}
local notify = Remotes.Event("Notify")

local function updateBar(state: CrystalState)
	local pct = math.clamp(state.HP / state.MaxHP, 0, 1)
	state.Bar.Size = UDim2.fromScale(pct, 1)
	state.Label.Text = Format.Number(math.ceil(state.HP))
end

local function breakCrystal(state: CrystalState)
	state.Broken = true
	local part = state.Part
	local damage = state.Damage
	state.Damage = {}
	for player, dealt in damage do
		if player.Parent then
			Economy.AwardCrystal(player, state.Zone, math.min(dealt / state.MaxHP, 1))
		end
	end
	part.Transparency = 1
	part.CanCollide = false
	local billboard = part:FindFirstChild("HealthGui") :: BillboardGui?
	if billboard then
		billboard.Enabled = false
	end
	local burst = part:FindFirstChild("Burst") :: ParticleEmitter?
	if burst then
		burst:Emit(25)
	end
	task.delay(Config.CrystalRespawnTime, function()
		state.HP = state.MaxHP
		state.Broken = false
		part.Transparency = 0.15
		part.CanCollide = true
		if billboard then
			billboard.Enabled = true
		end
		updateBar(state)
	end)
end

local function characterPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

function Crystals.Hit(player: Player, part: BasePart, fromAuto: boolean?)
	local state = states[part]
	if not state or state.Broken then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if state.Zone > data.ZonesUnlocked then
		local now = os.clock()
		if not fromAuto and now - (lastWarn[player] or 0) > 2 then
			lastWarn[player] = now
			local zone = Zones.Get(state.Zone)
			notify:FireClient(
				player,
				`Unlock {zone and zone.Name or "this zone"} first!`,
				Color3.fromRGB(255, 120, 120)
			)
		end
		return
	end
	local now = os.clock()
	if not fromAuto and now - (lastHit[player] or 0) < Config.HitCooldown then
		return
	end
	local pos = characterPosition(player)
	if not pos or (pos - part.Position).Magnitude > Config.MaxHitDistance then
		return
	end
	if not fromAuto then
		lastHit[player] = now
	end
	local damage = math.min(Economy.GetPower(data), state.HP)
	state.HP -= damage
	state.Damage[player] = (state.Damage[player] or 0) + damage
	if state.HP <= 0 then
		breakCrystal(state)
	else
		updateBar(state)
	end
end

function Crystals.Register(part: BasePart, zoneIndex: number)
	local zone = Zones.Get(zoneIndex)
	assert(zone, "bad zone")
	local gui = part:FindFirstChild("HealthGui") :: BillboardGui
	local state: CrystalState = {
		Part = part,
		Zone = zoneIndex,
		MaxHP = zone.CrystalHP,
		HP = zone.CrystalHP,
		Broken = false,
		Damage = {},
		Bar = gui.Back.Fill,
		Label = gui.Back.Amount,
	}
	states[part] = state
	updateBar(state)
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = Config.MaxHitDistance
	detector.MouseClick:Connect(function(player)
		Crystals.Hit(player, part)
	end)
	detector.Parent = part
end

-- Auto Collect game pass: damages the nearest crystal in range on a timer.
task.spawn(function()
	while true do
		task.wait(Config.AutoCollectInterval)
		for _, player in Players:GetPlayers() do
			local data = PlayerData.Get(player)
			if data and data.AutoCollectEnabled and Monetization.Owns(player, "AutoCollect") then
				local pos = characterPosition(player)
				if pos then
					local best, bestDist = nil, Config.AutoCollectRange
					for part, state in states do
						if not state.Broken and state.Zone <= data.ZonesUnlocked then
							local dist = (part.Position - pos).Magnitude
							if dist < bestDist then
								best, bestDist = part, dist
							end
						end
					end
					if best then
						Crystals.Hit(player, best, true)
					end
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastHit[player] = nil
	lastWarn[player] = nil
	for _, state in states do
		state.Damage[player] = nil
	end
end)

return Crystals
