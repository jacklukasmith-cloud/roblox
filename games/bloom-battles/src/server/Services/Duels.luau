--[[
	Bloom Battles: a tug-of-war of taps on the arena in every garden.

	- Two players on the two pads start a battle. Alone on a pad for a few seconds and a
	  Garden Spirit (an AI opponent near your Bloom) floats in to challenge you instead.
	- Every tap pulls the marker towards your opponent. How far depends on your share of
	  the total strength, and strength grows with Bloom, so bigger flowers pull harder
	  but quick fingers still win close fights.
	- The server owns the rope; clients only send taps (rate-limited).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.BloomShared.Config)
local Util = require(ReplicatedStorage.BloomShared.Util)
local Net = require(ReplicatedStorage.BloomShared.Net)
local Data = require(script.Parent.Data)
local Growth = require(script.Parent.Growth)

local Duels = {}

local D = Config.Duel
local duelEvent = Net.Event("Duel")
local tapEvent = Net.Event("DuelTap")
local effect = Net.Event("Effect")
local notify = Net.Event("Notify")

local rng = Random.new()
local states = {}
local tapLog = {} -- [Player] = { times }

local SPIRIT_NAMES = { "Dewdrop", "Mossling", "Petalwisp", "Fernlet", "Moonbud", "Clover", "Bramble", "Willowkin" }
local SPIRIT_COLORS = {
	Color3.fromRGB(196, 232, 200),
	Color3.fromRGB(250, 214, 224),
	Color3.fromRGB(214, 204, 244),
	Color3.fromRGB(200, 228, 246),
	Color3.fromRGB(255, 236, 196),
}

-- Helpers ------------------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onPad(root: BasePart, pad: BasePart): boolean
	local offset = root.Position - pad.Position
	return Vector2.new(offset.X, offset.Z).Magnitude <= D.PadRadius and offset.Y > -2 and offset.Y < 14
end

local function inDuel(player: Player): boolean
	return player:GetAttribute("InDuel") == true
end

local function placeOnPad(player: Player, pad: BasePart, facing: Vector3)
	local character = player.Character
	local root = rootOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) then
		return
	end
	local height = pad.Position.Y + pad.Size.X / 2 + humanoid.HipHeight + root.Size.Y / 2
	local pos = Vector3.new(pad.Position.X, height, pad.Position.Z)
	character:PivotTo(CFrame.lookAt(pos, Vector3.new(facing.X, height, facing.Z)))
	root.Anchored = true
end

local function release(player: Player, state)
	local root = rootOf(player)
	if root then
		root.Anchored = false
		local center = state.center
		local away = if root.Position.X < center.X then -1 else 1
		local character = player.Character
		local pos = Vector3.new(center.X + away * 22, root.Position.Y, center.Z)
		character:PivotTo(CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)))
	end
	player:SetAttribute("InDuel", nil)
end

local function buildSpirit(pad: BasePart, facing: Vector3, bloom: number, name: string): Model
	local color = SPIRIT_COLORS[rng:NextInteger(1, #SPIRIT_COLORS)]
	local model = Instance.new("Model")
	model.Name = "GardenSpirit"
	local function block(n, size, offset, c, neon)
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Color = c
		p.CFrame = offset
		p.Parent = model
		return p
	end
	local base = CFrame.new(0, 0, 0)
	local body = block("Body", Vector3.new(2.4, 2.6, 2.4), base * CFrame.new(0, 1.3, 0), color)
	block("Head", Vector3.new(2.2, 2, 2.2), base * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.rad(45), 0), color:Lerp(Color3.new(1, 1, 1), 0.35))
	block("EyeL", Vector3.new(0.3, 0.45, 0.2), base * CFrame.new(-0.45, 3.7, -1.12), Color3.fromRGB(80, 74, 90))
	block("EyeR", Vector3.new(0.3, 0.45, 0.2), base * CFrame.new(0.45, 3.7, -1.12), Color3.fromRGB(80, 74, 90))
	block("LeafL", Vector3.new(1.6, 0.3, 0.9), base * CFrame.new(-1.8, 1.8, 0) * CFrame.Angles(0, 0, math.rad(25)), Color3.fromRGB(150, 200, 140))
	block("LeafR", Vector3.new(1.6, 0.3, 0.9), base * CFrame.new(1.8, 1.8, 0) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(150, 200, 140))
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		block("Petal", Vector3.new(0.6, 0.2, 1), base * CFrame.new(0, 4.7, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.8) * CFrame.Angles(math.rad(-30), 0, 0), color, true)
	end
	model.PrimaryPart = body

	local att = Instance.new("Attachment")
	att.Parent = body
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(color)
	sparkle.LightEmission = 0.8
	sparkle.Size = NumberSequence.new(0.3, 0)
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 12
	sparkle.Parent = att
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 1
	light.Parent = body

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = name .. "\n" .. Util.Format(bloom) .. " Bloom"
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(90, 84, 100)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = body

	local scale = Util.ScaleFor(bloom)
	model:ScaleTo(scale)
	-- The pivot is the body's centre, 1.3 studs above its feet at scale 1.
	local top = pad.Position.Y + pad.Size.X / 2 + 1.3 * scale
	local pos = Vector3.new(pad.Position.X, top, pad.Position.Z)
	model:PivotTo(CFrame.lookAt(pos, Vector3.new(facing.X, top, facing.Z)))
	model:SetAttribute("SpiritColor", color)
	model.Parent = workspace
	return model
end

local function sideName(side): string
	return if side.Player then side.Player.DisplayName else side.Name
end

local function sidePosition(side): Vector3?
	if side.Player then
		local root = rootOf(side.Player)
		return root and root.Position
	elseif side.Spirit and side.Spirit.PrimaryPart then
		return side.Spirit.PrimaryPart.Position
	end
	return nil
end

local function send(state, payload)
	for key, side in state.sides do
		if side.Player then
			local copy = table.clone(payload)
			copy.You = key
			duelEvent:FireClient(side.Player, copy)
		end
	end
end

local function setMarker(state)
	local spin = os.clock() * 2
	state.marker.CFrame = CFrame.new(state.center + Vector3.new(state.p * 10, 3.2, 0)) * CFrame.Angles(math.rad(45), spin, math.rad(45))
end

-- Duel flow ----------------------------------------------------------------------------

local finish

local function makeSide(player: Player?, spirit: Model?, name: string?, bloom: number)
	return {
		Player = player,
		Spirit = spirit,
		Name = name,
		Bloom = bloom,
		Strength = Util.Strength(bloom),
	}
end

local function tap(state, key: string)
	if state.phase ~= "Fight" then
		return
	end
	local a, b = state.sides.A, state.sides.B
	local total = a.Strength + b.Strength
	local mine = state.sides[key].Strength
	local push = D.PushPerTap * (mine / total) * 2
	state.p += if key == "A" then push else -push
	if math.abs(state.p) >= 1 then
		state.p = math.clamp(state.p, -1, 1)
		finish(state, if state.p > 0 then "A" else "B")
	end
end

local function spiritLoop(state, key: string, id: number)
	local rate = rng:NextNumber(D.SpiritTapsPerSecond[1], D.SpiritTapsPerSecond[2])
	while state.id == id and state.phase == "Fight" do
		task.wait(1 / rate * rng:NextNumber(0.75, 1.25))
		if state.id == id then
			tap(state, key)
		end
	end
end

local function start(state, sideA, sideB)
	state.id += 1
	local id = state.id
	state.phase = "Countdown"
	state.p = 0
	state.sides = { A = sideA, B = sideB }
	state.aloneSince = nil
	setMarker(state)

	local padA, padB = state.padA.Position, state.padB.Position
	if sideA.Player then
		sideA.Player:SetAttribute("InDuel", true)
		placeOnPad(sideA.Player, state.padA, padB)
	end
	if sideB.Player then
		sideB.Player:SetAttribute("InDuel", true)
		placeOnPad(sideB.Player, state.padB, padA)
	end

	send(state, {
		Type = "Start",
		Arena = state.model,
		AName = sideName(sideA),
		BName = sideName(sideB),
		ABloom = sideA.Bloom,
		BBloom = sideB.Bloom,
		Countdown = D.Countdown,
		Length = D.Length,
	})
	effect:FireAllClients("DuelStart", state.center, Color3.fromRGB(255, 236, 196), { Arena = state.model })

	task.delay(D.Countdown, function()
		if state.id ~= id or state.phase ~= "Countdown" then
			return
		end
		state.phase = "Fight"
		state.endsAt = os.clock() + D.Length
		send(state, { Type = "Fight" })
		for key, side in state.sides do
			if side.Spirit then
				task.spawn(spiritLoop, state, key, id)
			end
		end
	end)
end

local function cleanup(state, id: number)
	task.delay(1.6, function()
		if state.id ~= id then
			return
		end
		for _, side in state.sides do
			if side.Player then
				release(side.Player, state)
			end
			if side.Spirit then
				local pos = side.Spirit.PrimaryPart and side.Spirit.PrimaryPart.Position
				if pos then
					effect:FireAllClients("Poof", pos, side.Spirit:GetAttribute("SpiritColor") or Color3.new(1, 1, 1), {})
				end
				side.Spirit:Destroy()
			end
		end
		state.sides = {}
		state.p = 0
		setMarker(state)
		state.phase = "Idle"
		state.cooldownUntil = os.clock() + D.Cooldown
	end)
end

finish = function(state, winnerKey: string)
	if state.phase ~= "Fight" and state.phase ~= "Countdown" then
		return
	end
	state.phase = "Ending"
	local winner = state.sides[winnerKey]
	local loser = state.sides[if winnerKey == "A" then "B" else "A"]

	-- Rewards scale with the opponent but are capped to a slice of your own growth rate,
	-- so duelling speeds you up without letting Bloom snowball exponentially.
	local function perSecond(side): number
		return if side.Player then side.Player:GetAttribute("PerSecond") or 1 else 1
	end
	local cap = if loser.Spirit then D.SpiritCapSeconds else D.WinCapSeconds
	local winGain = math.floor(math.min(loser.Bloom * D.WinShare, perSecond(winner) * cap)) + D.WinFlat
	local loseGain = math.floor(math.min(loser.Bloom * D.LoseShare, perSecond(loser) * D.LoseCapSeconds)) + 5

	if winner.Player then
		local d = Data.Get(winner.Player)
		if d then
			d.Wins += 1
			Growth.Add(winner.Player, winGain)
		end
		duelEvent:FireClient(winner.Player, { Type = "End", Won = true, Reward = winGain, Opponent = sideName(loser), P = state.p })
	end
	if loser.Player then
		Growth.Add(loser.Player, loseGain)
		duelEvent:FireClient(loser.Player, { Type = "End", Won = false, Reward = loseGain, Opponent = sideName(winner), P = state.p })
	end
	local pos = sidePosition(winner)
	if pos then
		effect:FireAllClients("DuelWin", pos, if winnerKey == "A" then state.padA.Color else state.padB.Color, { Name = sideName(winner) })
	end
	cleanup(state, state.id)
end

local function abort(state, leaverKey: string)
	if state.phase ~= "Fight" and state.phase ~= "Countdown" then
		return
	end
	state.phase = "Ending"
	local other = state.sides[if leaverKey == "A" then "B" else "A"]
	if other.Player then
		duelEvent:FireClient(other.Player, { Type = "Cancel" })
		notify:FireClient(other.Player, "Your opponent wandered off. No harm done!")
	end
	state.sides[leaverKey] = {} -- don't try to release a player who is gone
	cleanup(state, state.id)
end

-- Per-arena tick -----------------------------------------------------------------------

local function tickIdle(state, now: number)
	if now < state.cooldownUntil then
		return
	end
	local onA, onB
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and not inDuel(player) and Data.Get(player) then
			if not onA and onPad(root, state.padA) then
				onA = player
			elseif not onB and onPad(root, state.padB) then
				onB = player
			end
		end
	end

	if onA and onB then
		start(state, makeSide(onA, nil, nil, Data.Get(onA).Bloom), makeSide(onB, nil, nil, Data.Get(onB).Bloom))
		return
	end
	local alone = onA or onB
	if not alone then
		state.aloneSince, state.alonePlayer = nil, nil
		return
	end
	if state.alonePlayer ~= alone then
		state.alonePlayer = alone
		state.aloneSince = now
		duelEvent:FireClient(alone, { Type = "Waiting", Wait = D.SpiritWait })
		return
	end
	if now - state.aloneSince < D.SpiritWait then
		return
	end

	-- A Garden Spirit accepts the challenge
	local playerBloom = Data.Get(alone).Bloom
	local base = Config.Zones[state.zone].SpiritBloom
	local bloom = math.floor(math.max(playerBloom * rng:NextNumber(D.SpiritBloomRange[1], D.SpiritBloomRange[2]), base * rng:NextNumber(0.6, 1.1)))
	local name = SPIRIT_NAMES[rng:NextInteger(1, #SPIRIT_NAMES)]
	local playerSide = makeSide(alone, nil, nil, playerBloom)
	if alone == onA then
		local spirit = buildSpirit(state.padB, state.padA.Position, bloom, name)
		start(state, playerSide, makeSide(nil, spirit, name, bloom))
	else
		local spirit = buildSpirit(state.padA, state.padB.Position, bloom, name)
		start(state, makeSide(nil, spirit, name, bloom), playerSide)
	end
	effect:FireAllClients("Poof", state.center + Vector3.new(0, 4, 0), Color3.fromRGB(220, 240, 220), {})
end

local function tickActive(state, now: number)
	for key, side in state.sides do
		if side.Player and (side.Player.Parent == nil or not rootOf(side.Player)) then
			abort(state, key)
			return
		end
	end
	if state.phase == "Fight" then
		setMarker(state)
		local left = state.endsAt - now
		if left <= 0 then
			local key = if state.p > 0 then "A" elseif state.p < 0 then "B" elseif state.sides.A.Bloom >= state.sides.B.Bloom then "A" else "B"
			finish(state, key)
		end
	end
end

function Duels.Start(arenaFolder: Folder)
	for _, model in arenaFolder:GetChildren() do
		local floor = model:FindFirstChild("Floor") :: BasePart
		local padA = model:FindFirstChild("PadA") :: BasePart
		local padB = model:FindFirstChild("PadB") :: BasePart
		table.insert(states, {
			model = model,
			zone = model:GetAttribute("Zone") or 1,
			center = Vector3.new((padA.Position.X + padB.Position.X) / 2, floor.Position.Y, padA.Position.Z),
			padA = padA,
			padB = padB,
			marker = model:FindFirstChild("Marker"),
			phase = "Idle",
			sides = {},
			p = 0,
			id = 0,
			cooldownUntil = 0,
		})
	end

	tapEvent.OnServerEvent:Connect(function(player)
		local now = os.clock()
		local log = tapLog[player]
		if not log then
			log = {}
			tapLog[player] = log
		end
		while log[1] and now - log[1] > 1 do
			table.remove(log, 1)
		end
		if #log >= D.MaxTapsPerSecond then
			return
		end
		table.insert(log, now)
		for _, state in states do
			if state.phase == "Fight" then
				for key, side in state.sides do
					if side.Player == player then
						tap(state, key)
						return
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		tapLog[player] = nil
	end)

	local acc = 0
	local lastSend = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local now = os.clock()
		local sendNow = now - lastSend >= 0.1
		if sendNow then
			lastSend = now
		end
		for _, state in states do
			if state.phase == "Idle" then
				tickIdle(state, now)
			elseif state.phase == "Fight" or state.phase == "Countdown" then
				tickActive(state, now)
				if sendNow and state.phase == "Fight" then
					send(state, { Type = "State", P = state.p, TimeLeft = math.max(0, state.endsAt - now) })
				end
			end
		end
	end)
end

return Duels
