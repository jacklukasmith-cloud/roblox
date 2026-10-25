--[[
	+1 Bloom every second. Also owns how your character looks as it grows:
	size, a low-poly flower crown and a petal aura that change colour each tier.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.BloomShared.Config)
local Util = require(ReplicatedStorage.BloomShared.Util)
local Net = require(ReplicatedStorage.BloomShared.Net)
local Data = require(script.Parent.Data)

local Growth = {}

local notify = Net.Event("Notify")
local effect = Net.Event("Effect")

local passOwners = {} -- [Player] = true
local lastScale = {} -- [Player] = number
local lastTier = {} -- [Player] = number

-- Visuals ------------------------------------------------------------------------------

local function buildCrown(head: BasePart, color: Color3, scale: number)
	local crown = Instance.new("Model")
	crown.Name = "BloomCrown"
	local petals = 7
	for i = 1, petals do
		local angle = (i / petals) * math.pi * 2
		local petal = Instance.new("Part")
		petal.Name = "Petal"
		petal.Size = Vector3.new(0.5, 0.18, 0.75) * scale
		petal.Material = Enum.Material.SmoothPlastic
		petal.Color = color
		petal.CanCollide = false
		petal.CanQuery = false
		petal.CanTouch = false
		petal.Massless = true
		local offset = CFrame.new(0, head.Size.Y * 0.55, 0)
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(0, 0, -head.Size.X * 0.42)
			* CFrame.Angles(math.rad(-28), 0, 0)
		petal.CFrame = head.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = petal
		weld.Parent = petal
		petal.Parent = crown
	end
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Block
	core.Size = Vector3.new(0.45, 0.3, 0.45) * scale
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(255, 236, 170)
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Massless = true
	core.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.62, 0) * CFrame.Angles(0, math.rad(45), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = core
	weld.Parent = core
	core.Parent = crown
	crown.Parent = head.Parent
end

local function buildAura(root: BasePart, color: Color3)
	local att = Instance.new("Attachment")
	att.Name = "BloomAura"
	att.Parent = root

	local petals = Instance.new("ParticleEmitter")
	petals.Name = "Petals"
	petals.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	petals.Color = ColorSequence.new(color)
	petals.LightEmission = 0.4
	petals.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	petals.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.45) })
	petals.Lifetime = NumberRange.new(1.8, 2.8)
	petals.Speed = NumberRange.new(0.6, 1.4)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Acceleration = Vector3.new(0, 1.2, 0)
	petals.RotSpeed = NumberRange.new(-60, 60)
	petals.Rate = 4
	petals.Parent = att

	local ring = Instance.new("ParticleEmitter")
	ring.Name = "Glow"
	ring.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	ring.Color = ColorSequence.new(color)
	ring.LightEmission = 1
	ring.Transparency = NumberSequence.new(0.75)
	ring.Size = NumberSequence.new(3)
	ring.Lifetime = NumberRange.new(1)
	ring.Speed = NumberRange.new(0)
	ring.LockedToPart = true
	ring.Rate = 0
	ring.Parent = att

	local light = Instance.new("PointLight")
	light.Name = "BloomLight"
	light.Color = color
	light.Brightness = 0
	light.Range = 10
	light.Shadows = false
	light.Parent = root
end

local function applyLook(player: Player, force: boolean?)
	local d = Data.Get(player)
	local character = player.Character
	if not (d and character) then
		return
	end
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (head and root) then
		return
	end
	local tierIndex = Util.TierIndex(d.Bloom)
	local tier = Config.Tiers[tierIndex]

	-- Size: only rescale on a noticeable change (ScaleTo is not free).
	local target = Util.ScaleFor(d.Bloom)
	local scale = lastScale[player]
	if force or not scale or math.abs(target - scale) >= 0.03 then
		lastScale[player] = target
		pcall(function()
			character:ScaleTo(target)
		end)
	end

	if force or lastTier[player] ~= tierIndex then
		lastTier[player] = tierIndex
		local crown = character:FindFirstChild("BloomCrown")
		if crown then
			crown:Destroy()
		end
		-- Built to fit the current (already scaled) head; later ScaleTo calls resize it too.
		buildCrown(head, tier.Color, character:GetScale())
		local att = root:FindFirstChild("BloomAura")
		if not att then
			buildAura(root, tier.Color)
			att = root:FindFirstChild("BloomAura")
		end
		local petals = att:FindFirstChild("Petals") :: ParticleEmitter
		local glow = att:FindFirstChild("Glow") :: ParticleEmitter
		petals.Color = ColorSequence.new(tier.Color, Color3.new(1, 1, 1))
		petals.Rate = 3 + tierIndex * 3
		glow.Color = ColorSequence.new(tier.Color)
		glow.Rate = if tierIndex >= 4 then tierIndex - 2 else 0
		local light = root:FindFirstChild("BloomLight") :: PointLight
		if light then
			light.Color = tier.Color
			light.Brightness = math.max(0, (tierIndex - 2) * 0.35)
			light.Range = 8 + tierIndex * 1.5
		end
	end
end

-- Gains --------------------------------------------------------------------------------

function Growth.Multiplier(player: Player): number
	local d = Data.Get(player)
	if not d then
		return 1
	end
	local mult = Util.ReplantMultiplier(d.Rebirths)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local zone = Util.ZoneAt(root.Position.Z)
		if zone <= d.Zones then
			mult *= Config.Zones[zone].Multiplier
		end
	end
	if passOwners[player] then
		mult *= 2
	end
	return mult
end

-- Adds Bloom (from any source), handles tier-ups and garden unlocks.
function Growth.Add(player: Player, amount: number)
	local d = Data.Get(player)
	if not d then
		return
	end
	local oldTier = Util.TierIndex(d.Bloom)
	d.Bloom += amount
	local newTier = Util.TierIndex(d.Bloom)

	for i = d.Zones + 1, #Config.Zones do
		if d.Bloom >= Config.Zones[i].Need then
			d.Zones = i
			notify:FireClient(player, "The gate to " .. Config.Zones[i].Name .. " is open!", Config.Zones[i].Flower[1])
		end
	end

	Data.Sync(player)
	if newTier > oldTier then
		local tier = Config.Tiers[newTier]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			effect:FireAllClients("Milestone", root.Position, tier.Color, { Player = player, Tier = newTier })
		end
	end
	applyLook(player)
end

function Growth.Replant(player: Player)
	local d = Data.Get(player)
	if not d then
		return false, "Still loading..."
	end
	local cost = Util.ReplantCost(d.Rebirths)
	if d.Bloom < cost then
		return false, "You need " .. Util.Format(cost) .. " Bloom to Replant."
	end
	d.Bloom = 0
	d.Rebirths += 1
	Data.Sync(player)
	applyLook(player, true)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		effect:FireAllClients("Replant", root.Position, Color3.fromRGB(255, 226, 160), { Player = player })
	end
	return true, "Replanted! Every gain is now x" .. Util.ReplantMultiplier(d.Rebirths)
end

function Growth.PlayerAdded(player: Player)
	if Config.DoubleBloomPassId > 0 then
		task.spawn(function()
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.DoubleBloomPassId)
			end)
			if ok and owns then
				passOwners[player] = true
			end
		end)
	end
	local function onCharacter(character: Model)
		lastScale[player] = nil
		lastTier[player] = nil
		character:WaitForChild("HumanoidRootPart", 10)
		character:WaitForChild("Head", 10)
		task.wait(0.2)
		applyLook(player, true)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function Growth.Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if bought and passId == Config.DoubleBloomPassId then
			passOwners[player] = true
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		passOwners[player] = nil
		lastScale[player] = nil
		lastTier[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if Data.Get(player) then
					local mult = Growth.Multiplier(player)
					player:SetAttribute("PerSecond", Config.BasePerSecond * mult)
					Growth.Add(player, Config.BasePerSecond * mult)
				end
			end
		end
	end)
end

return Growth
