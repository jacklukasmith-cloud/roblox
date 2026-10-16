--[[
	Egg hatching and the Wandering Merchant shop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local Eggs = require(Shared.Eggs)
local Zones = require(Shared.Zones)
local Merchant = require(Shared.Merchant)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local DailyRewards = require(script.Parent.DailyRewards)
local Monetization = require(script.Parent.Monetization)
local WorldService = require(script.Parent.WorldService)
local Celebrations = require(script.Parent.Celebrations)

local Hatching = {}

local rng = Random.new()
local notify = Remotes.Event("Notify")
local hatchResult = Remotes.Event("HatchResult")
local lastHatch: { [Player]: number } = {}

local function addCreature(player: Player, data: PlayerData.Data, creatureId: string)
	local variant = Creatures.RollVariant(rng, Economy.GetShinyMultiplier(data))
	local uid = PlayerData.NewCreature(data, creatureId, variant)
	local isNew = not data.Bestiary[creatureId]
	data.Bestiary[creatureId] = true
	if isNew then
		-- did this discovery complete an egg's Index set?
		local eggId = Eggs.EggFor(creatureId)
		local egg = Eggs.Get(eggId)
		if egg and table.find(Eggs.SetOf(eggId), creatureId) and Eggs.SetProgress(eggId, data.Bestiary) then
			task.delay(Config.MilestoneDelay or 4, function()
				notify:FireClient(
					player,
					`📖 {egg.Name} set complete! +{math.floor(Config.IndexSetBonus * 100)}% Essence forever`,
					Color3.fromRGB(255, 215, 80)
				)
			end)
		end
	end
	data.Stats.CreaturesHatched += 1
	DailyRewards.Track(player, "HatchEggs", 1)
	local def = Creatures.Get(creatureId)
	if def and Creatures.Rarities[def.Rarity].Order >= 3 then
		DailyRewards.Track(player, "HatchRare", 1)
	end
	-- Auto-equip into a free slot
	local _, equipped = PlayerData.CountCreatures(data)
	if equipped < Economy.GetEquipSlots(player) then
		data.Creatures[uid].Equipped = true
	end
	return { Id = creatureId, Variant = variant, New = isNew }
end

local function announceRare(player: Player, result)
	Celebrations.Announce(player, result.Id, result.Variant)
end

function Hatching.Hatch(player: Player, eggId: string, count: number): (boolean, string?)
	local egg = Eggs.Get(eggId)
	local data = PlayerData.Get(player)
	if not egg or not data then
		return false, "Unknown egg"
	end
	local now = os.clock()
	if now - (lastHatch[player] or 0) < 0.8 then
		return false, nil
	end
	lastHatch[player] = now
	if count == 3 and not Monetization.Owns(player, "TripleHatch") then
		Monetization.PromptPass(player, "TripleHatch")
		return false, "Triple Hatch is a game pass"
	end
	count = if count == 3 then 3 else 1
	local required = egg.RequiresZone or egg.Zone
	if required > data.ZonesUnlocked then
		local zone = Zones.Get(required)
		return false, `Unlock {if zone then zone.Name else "this realm"} first`
	end
	local total = PlayerData.CountCreatures(data)
	if total + count > Config.MaxInventory then
		return false, "Your creature storage is full - release some creatures"
	end
	local cost = egg.Cost * count
	local balance = if egg.Currency == "Trophies" then data.Trophies else data.Essence
	if balance < cost then
		return false, `You need {Format.Number(cost)} {egg.Currency}`
	end
	if egg.Currency == "Trophies" then
		data.Trophies -= cost
	else
		data.Essence -= cost
	end
	local luck = Economy.GetLuck(player, data)
	local results = {}
	for _ = 1, count do
		local result = addCreature(player, data, Eggs.Roll(egg, luck, rng))
		table.insert(results, result)
		announceRare(player, result)
	end
	PlayerData.MarkChanged(player)
	hatchResult:FireClient(player, eggId, results)
	Hatching.CheckMilestones(player)
	return true
end

-- Hatching milestones (Config.HatchMilestones): claimed in order, one per hatch, and paid out
-- after the hatch reveal so the two don't overlap.
function Hatching.CheckMilestones(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local claimed = data.Stats.HatchMilestones or 0
	local milestone = Config.HatchMilestones[claimed + 1]
	if not milestone or data.Stats.CreaturesHatched < milestone.At then
		return
	end
	-- everything is paid right now (so leaving straight away can't lose it); only the bonus
	-- creature's reveal and the message wait until your own hatch reveal has finished
	data.Stats.HatchMilestones = claimed + 1
	local delay = Config.MilestoneDelay or 4
	local parts = {}
	local trophies = milestone.Trophies or 0
	if milestone.Mystic then
		if Hatching.MysticHatch(player, `{milestone.At} Hatches!`, delay) then
			table.insert(parts, "a bonus Rare+ creature")
		else
			trophies += Config.MilestoneFullStorageTrophies -- storage full: Trophies instead
		end
	end
	if trophies > 0 then
		data.Trophies += trophies
		table.insert(parts, `+{trophies} Trophies`)
	end
	if milestone.Items then
		local Bag = require(script.Parent.Bag) :: any
		local Items = require(ReplicatedStorage.Shared.Items) :: any
		for id, count in milestone.Items do
			Bag.Give(player, id, count, true)
			local item = Items.Get(id)
			table.insert(parts, `{count}x {item and item.Name or id}`)
		end
	end
	if milestone.Title and not table.find(data.Titles, milestone.Title) then
		table.insert(data.Titles, milestone.Title)
		table.insert(parts, `the "{milestone.Title}" title`)
	end
	PlayerData.MarkChanged(player)
	task.delay(delay, function()
		if player.Parent then
			notify:FireClient(
				player,
				`🥚 {milestone.At} hatches! You got {table.concat(parts, " + ")}`,
				Color3.fromRGB(255, 215, 80)
			)
		end
	end)
end

function Hatching.BuyMerchantItem(player: Player, itemId: string): (boolean, string?)
	local data = PlayerData.Get(player)
	local item = Merchant.GetItem(itemId)
	if not data or not item then
		return false, "Unknown item"
	end
	local merchant = WorldService.GetMerchant()
	if data.Merchant.Slot ~= merchant.Slot then
		data.Merchant = { Slot = merchant.Slot, Bought = {} }
	end
	local stock = merchant.Stock[itemId] or 0
	local bought = data.Merchant.Bought[itemId] or 0
	if bought >= stock then
		return false, "Sold out! The merchant restocks soon."
	end
	local price = Merchant.GetPrice(item, data.ZonesUnlocked)
	if data.Essence < price then
		return false, `You need {Format.Number(price)} Essence`
	end
	data.Essence -= price
	data.Merchant.Bought[itemId] = bought + 1
	DailyRewards.Track(player, "BuyMerchant", 1)
	-- everything the merchant sells goes into your Bag to use when you like
	local Bag = require(script.Parent.Bag) :: any
	Bag.Give(player, itemId, 1)
	PlayerData.MarkChanged(player)
	return true
end

-- Hatch your best zone's egg with a guaranteed Rare or better (Mystic Egg). Returns false if
-- storage is full.
-- revealDelay: the creature is added straight away, but its reveal waits (e.g. after another reveal)
function Hatching.MysticHatch(player: Player, title: string?, revealDelay: number?): boolean
	local data = PlayerData.Get(player)
	if not data or PlayerData.CountCreatures(data) >= Config.MaxInventory then
		return false
	end
	local zone = Zones.Get(data.ZonesUnlocked) or Zones.List[1]
	local egg = Eggs.Get(zone.EggId) :: Eggs.EggDef
	local creatureId = Eggs.Roll(egg, Economy.GetLuck(player, data), rng, Creatures.LuckyRarityOrder)
	local result = addCreature(player, data, creatureId)
	announceRare(player, result)
	PlayerData.MarkChanged(player)
	local opts = if title then { Title = title } else nil
	if revealDelay and revealDelay > 0 then
		task.delay(revealDelay, function()
			if player.Parent then
				hatchResult:FireClient(player, egg.Id, { result }, opts)
			end
		end)
	else
		hatchResult:FireClient(player, egg.Id, { result }, opts)
	end
	return true
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastHatch[player] = nil
end)

return Hatching
