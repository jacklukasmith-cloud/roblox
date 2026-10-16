--[[
	The player's Bag: items (Shared/Items) are collected first and used later from the 🎒 Bag
	menu. Stored in the save as data.Items = { [item id] = count }.

	Bag.Give(player, id, count?, quiet?)  adds items (tells the player unless quiet)
	Bag.Use(player, id)                   uses one: drinks the potion, opens the gift...
	Bag.Drop(player, lootTable)           rolls a loot table from Config.ItemDrops and gives it
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)

local Bag = {}

local itemGained = Remotes.Event("ItemGained")
local rng = Random.new()

function Bag.Count(player: Player, id: string): number
	local data = PlayerData.Get(player) :: any
	return if data and data.Items then data.Items[id] or 0 else 0
end

function Bag.Give(player: Player, id: string, count: number?, quiet: boolean?): boolean
	local data = PlayerData.Get(player) :: any
	local item = Items.Get(id)
	local n = math.floor(count or 1)
	if not data or not item or n <= 0 then
		return false
	end
	data.Items = data.Items or {}
	data.Items[id] = math.min((data.Items[id] or 0) + n, Items.MaxStack)
	PlayerData.MarkChanged(player)
	if not quiet then
		itemGained:FireClient(player, id, n)
	end
	return true
end

-- Rolls one entry of a loot table (see Config.ItemDrops) and gives it
function Bag.Drop(player: Player, loot: { any }, quiet: boolean?): string
	local id, count = Items.Roll(loot, rng:NextNumber())
	Bag.Give(player, id, count, quiet)
	return id
end

-- What using each kind of item does. Returns (ok, message).
local function apply(player: Player, data: any, item: Items.Item): (boolean, string?)
	-- required here: these services report back to the Bag (drops, rewards)
	local Economy = require(script.Parent.Economy) :: any
	if item.Kind == "Boost" then
		for name, seconds in item.Boosts or {} do
			Economy.AddBoost(player, name, seconds)
		end
		return true, `{item.Icon} {item.Name} activated!`
	elseif item.Kind == "XP" then
		local _, equipped = PlayerData.CountCreatures(data)
		if equipped == 0 then
			return false, "Equip a creature first"
		end
		Economy.GrantXP(player, item.Amount or 0)
		return true, `{item.Icon} Your creatures got +{item.Amount} XP!`
	elseif item.Kind == "Essence" then
		local amount = Economy.GetProductEssence(player, item.CrystalRewards or 0)
		Economy.AddEssence(player, amount)
		return true, `{item.Icon} +{Format.Number(amount)} Essence!`
	elseif item.Kind == "Mystic" then
		local total = PlayerData.CountCreatures(data)
		if total >= Config.MaxInventory then
			return false, "Your creature storage is full"
		end
		local Hatching = require(script.Parent.Hatching) :: any
		if not Hatching.MysticHatch(player, item.Name) then
			return false, "Couldn't hatch right now"
		end
		return true, nil
	elseif item.Kind == "Gift" then
		local id, count = Items.Roll(item.Loot or {}, rng:NextNumber())
		local prize = Items.Get(id) :: Items.Item
		Bag.Give(player, id, count, true)
		local amount = if count > 1 then `{count}x ` else ""
		return true, `{item.Icon} Inside: {amount}{prize.Icon} {prize.Name}!`
	elseif item.Kind == "Treasure" then
		local Treasures = require(script.Parent.Treasures) :: any
		if Treasures.IsActive() then
			return false, "A Lost Treasure is already hidden somewhere. Find that one first!"
		end
		local zone = rng:NextInteger(1, math.max(1, data.ZonesUnlocked or 1))
		if not Treasures.Spawn(zone) then
			return false, "Couldn't hide a treasure right now"
		end
		return true, nil -- Treasures tells everyone where it is
	elseif item.Kind == "Boss" then
		local BossRaid = require(script.Parent.BossRaid) :: any
		if not BossRaid.Spawn() then
			return false, "A boss is already here!"
		end
		for _, other in Players:GetPlayers() do
			Remotes.Event("Notify"):FireClient(
				other,
				`📯 {player.DisplayName} blew a Boss Horn! A boss is coming!`,
				Color3.fromRGB(255, 120, 90)
			)
		end
		return true, nil
	end
	return false, "You can't use that"
end

function Bag.Use(player: Player, id: string): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	local item = Items.Get(id)
	if not data or not item then
		return false, "Unknown item"
	end
	if (data.Items and data.Items[id] or 0) <= 0 then
		return false, `You don't have a {item.Name}`
	end
	local ok, message = apply(player, data, item)
	if ok then
		data.Items[id] -= 1
		if data.Items[id] <= 0 then
			data.Items[id] = nil
		end
		data.Stats.ItemsUsed = (data.Stats.ItemsUsed or 0) + 1
		PlayerData.MarkChanged(player)
	end
	return ok, message
end

-- Crystal drops: a small chance per crystal you help break (bigger crystals roll more times)
function Bag.CrystalDrop(player: Player, kind: string, sizeReward: number?)
	local drops = Config.ItemDrops
	if kind == "Chest" then
		Bag.Drop(player, drops.Chest)
	elseif kind == "Boss" then
		Bag.Give(player, "MysteryGift", 1)
		Bag.Drop(player, drops.Boss)
	else
		for _ = 1, math.clamp(math.round(sizeReward or 1), 1, 10) do
			if rng:NextNumber() < drops.CrystalChance then
				Bag.Drop(player, drops.Crystal)
				return
			end
		end
	end
end

-- Speed Potion: faster walking while the boost lasts
local BASE_WALK = 16
function Bag.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			local Economy = require(script.Parent.Economy) :: any
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local speed = if Economy.HasBoost(player, "Speed")
						then BASE_WALK * Config.Boosts.Speed
						else BASE_WALK
					if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
						humanoid.WalkSpeed = speed
					end
				end
			end
		end
	end)
end

return Bag
