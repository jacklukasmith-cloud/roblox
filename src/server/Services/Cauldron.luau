--[[
	The Alchemy Cauldron (Shared/Alchemy): brew potions from the Gloom Crystals in your Crystal Vault.
	Brews take real time and keep going while you're away; a finished one goes straight into your Bag.
	The Master Alchemist pass gives a second slot and 25% quicker brews.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Alchemy = require(Shared.Alchemy)
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Monetization = require(script.Parent.Monetization)
local Bag = require(script.Parent.Bag)
local Sanctuaries = require(script.Parent.Sanctuaries)

local Cauldron = {}

local notify = Remotes.Event("Notify")
local TICK = 2

Cauldron.Clock = os.time

local function cauldronOf(data: any): any
	data.Cauldron = data.Cauldron or {}
	data.Cauldron.Brews = data.Cauldron.Brews or {}
	return data.Cauldron
end

function Cauldron.Slots(player: Player): number
	return if Monetization.Owns(player, "MasterAlchemist")
		then Config.GamePassBonuses.CauldronSlots
		else Alchemy.BaseSlots
end

function Cauldron.Speed(player: Player): number
	return if Monetization.Owns(player, "MasterAlchemist") then Config.GamePassBonuses.CauldronSpeed else 1
end

-- The cauldron on the island bubbles while something's brewing
function Cauldron.UpdateIsland(player: Player)
	local data = PlayerData.Get(player) :: any
	local island = Sanctuaries.IslandOf(player)
	if data and island then
		Sanctuaries.ShowBrewing(island, #cauldronOf(data).Brews > 0)
	end
end

-- Starts a brew. Returns ok, message.
function Cauldron.Brew(player: Player, recipeId: any): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	local recipe = type(recipeId) == "string" and Alchemy.Get(recipeId)
	if not data or not recipe then
		return false, nil
	end
	local c = cauldronOf(data)
	local slots = Cauldron.Slots(player)
	if #c.Brews >= slots then
		return false,
			if slots < Config.GamePassBonuses.CauldronSlots
				then "Your Cauldron is busy! (Master Alchemist gives you a second slot)"
				else "Both Cauldron slots are busy"
	end
	local vault = data.Gloom and data.Gloom.Vault or {}
	if not Alchemy.HasIngredients(vault, recipe) then
		return false, "You need more Gloom Crystals in your Vault for that"
	end
	local essence = Economy.GetProductEssence(player, recipe.Essence)
	if data.Essence < essence then
		return false, `You need 💎 {Format.Number(essence - data.Essence)} more Essence`
	end
	data.Essence -= essence
	for id, n in recipe.Ingredients do
		vault[id] -= n
		if vault[id] <= 0 then
			vault[id] = nil
		end
	end
	local now = Cauldron.Clock()
	table.insert(c.Brews, {
		Recipe = recipe.Id,
		StartedAt = now,
		DoneAt = now + Alchemy.Duration(recipe, Cauldron.Speed(player)),
	})
	PlayerData.MarkChanged(player)
	Cauldron.UpdateIsland(player)
	local item = Items.Get(recipe.Item)
	return true, `⚗️ Brewing {if item then item.Name else recipe.Id}...`
end

-- Puts finished brews in the Bag. Returns how many finished.
function Cauldron.Tick(player: Player): number
	local data = PlayerData.Get(player) :: any
	if not data then
		return 0
	end
	local c = cauldronOf(data)
	local now = Cauldron.Clock()
	local done = 0
	for i = #c.Brews, 1, -1 do
		local brew = c.Brews[i]
		local recipe = Alchemy.Get(brew.Recipe)
		if not recipe then
			table.remove(c.Brews, i)
		elseif now >= brew.DoneAt then
			table.remove(c.Brews, i)
			Bag.Give(player, recipe.Item, 1)
			data.Stats.PotionsBrewed = (data.Stats.PotionsBrewed or 0) + 1
			done += 1
			local item = Items.Get(recipe.Item)
			notify:FireClient(
				player,
				`⚗️ Your {if item then item.Name else recipe.Id} is ready! It's in your 🎒 Bag`,
				Color3.fromRGB(150, 255, 190)
			)
		end
	end
	if done > 0 then
		PlayerData.MarkChanged(player)
		Cauldron.UpdateIsland(player)
	end
	return done
end

function Cauldron.Start()
	PlayerData.Loaded:Connect(function(player)
		-- anything that finished while you were away
		task.delay(5, function()
			if player.Parent then
				Cauldron.Tick(player)
				Cauldron.UpdateIsland(player)
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(Cauldron.Tick, player)
				if not ok then
					warn("[Cauldron] " .. tostring(err))
				end
			end
		end
	end)
end

return Cauldron
