--[[
	Game passes + developer products.

	Developer products use the standard safe pattern: every receipt id is stored in the
	player's save, so a purchase is never granted twice and is retried if granting fails.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local Monetization = {}

local owned: { [Player]: { [string]: boolean } } = {}
local passById: { [number]: any } = {}
local productById: { [number]: any } = {}

for _, pass in Config.GamePasses do
	if pass.Id ~= 0 then
		passById[pass.Id] = pass
	end
end
for _, product in Config.DevProducts do
	if product.Id ~= 0 then
		productById[product.Id] = product
	end
end

local notify = Remotes.Event("Notify")

-- !nopasses (testing): play as if you owned no game passes, until you type it again or rejoin
local ignoring: { [Player]: boolean } = {}

function Monetization.Owns(player: Player, key: string): boolean
	if ignoring[player] then
		return false
	end
	local set = owned[player]
	return set ~= nil and set[key] == true
end

function Monetization.GetOwned(player: Player): { [string]: boolean }
	if ignoring[player] then
		return {}
	end
	return table.clone(owned[player] or {})
end

local function applyPerks(player: Player)
	player:SetAttribute("VIP", Monetization.Owns(player, "VIP"))
end

-- Turns "pretend I own no passes" on or off; returns whether it's now on
function Monetization.ToggleIgnorePasses(player: Player): boolean
	ignoring[player] = if ignoring[player] then nil else true
	applyPerks(player)
	PlayerData.MarkChanged(player)
	return ignoring[player] == true
end

function Monetization.Refresh(player: Player)
	local set = {}
	local studioFree = RunService:IsStudio() and Config.StudioOwnsAllPasses
	for _, pass in Config.GamePasses do
		if studioFree then
			set[pass.Key] = true
		elseif pass.Id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and has then
				set[pass.Key] = true
			end
		end
	end
	owned[player] = set
	applyPerks(player)
	PlayerData.MarkChanged(player)
end

-- Other services can react to a pass being bought (e.g. the pickaxe turning gold)
local passCallbacks: { (Player, string) -> () } = {}
function Monetization.OnPassPurchased(callback: (Player, string) -> ())
	table.insert(passCallbacks, callback)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local pass = passById[passId]
	if not purchased or not pass then
		return
	end
	owned[player] = owned[player] or {}
	owned[player][pass.Key] = true
	applyPerks(player)
	PlayerData.MarkChanged(player)
	notify:FireClient(player, `Thank you! {pass.Name} unlocked!`, Color3.fromRGB(255, 215, 80))
	for _, callback in passCallbacks do
		task.spawn(callback, player, pass.Key)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	owned[player] = nil
	ignoring[player] = nil
end)

local function grant(player: Player, product)
	-- Lazy require: Economy depends on this module too.
	local Economy = require(script.Parent.Economy)
	local data = PlayerData.Get(player)
	assert(data, "no data")
	local g = product.Grant
	if g.Kind == "Essence" then
		local amount = Economy.GetProductEssence(player, g.CrystalRewards)
		Economy.AddEssence(player, amount)
		notify:FireClient(
			player,
			`+{require(ReplicatedStorage.Shared.Format).Number(amount)} Essence!`,
			Color3.fromRGB(120, 255, 200)
		)
	elseif g.Kind == "Boost" then
		Economy.AddBoost(player, g.Boost, g.Seconds)
		notify:FireClient(player, `{product.Name} activated!`, Color3.fromRGB(120, 255, 120))
	elseif g.Kind == "Item" then
		-- into the Bag (shows the "added to your Bag" pop-up)
		local Bag = require(script.Parent.Bag) :: any
		Bag.Give(player, g.Item, g.Count or 1)
	elseif g.Kind == "Creature" then
		local Creatures = require(ReplicatedStorage.Shared.Creatures)
		local Eggs = require(ReplicatedStorage.Shared.Eggs)
		assert(Creatures.Get(g.Creature), "unknown creature " .. tostring(g.Creature))
		local isNew = not data.Bestiary[g.Creature]
		PlayerData.NewCreature(data, g.Creature, "Normal")
		data.Bestiary[g.Creature] = true
		-- the big hatch reveal, retitled
		Remotes.Event("HatchResult"):FireClient(
			player,
			Eggs.EggFor(g.Creature),
			{ { Id = g.Creature, Variant = "Normal", New = isNew } },
			{ Title = "Exclusive!" }
		)
		notify:FireClient(player, `Thank you! {product.Name} joined your team!`, Color3.fromRGB(255, 95, 200))
		require(script.Parent.Celebrations).Announce(player, g.Creature, "Normal", "got")
	elseif g.Kind == "Spins" then
		require(script.Parent.SpinWheel).AddSpins(player, g.Count or 1)
		notify:FireClient(player, `🎡 +{g.Count or 1} spins! Open the Spin Wheel`, Color3.fromRGB(255, 210, 120))
	elseif g.Kind == "MerchantRestock" then
		data.Merchant.Bought = {}
		notify:FireClient(player, "The Merchant restocked just for you!", Color3.fromRGB(255, 200, 120))
	else
		error("Unknown grant kind " .. tostring(g.Kind))
	end
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = PlayerData.WaitFor(player, 10)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if PlayerData.HasReceipt(player, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = productById[receipt.ProductId]
	if not product then
		warn("[Monetization] Unknown product id", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(grant, player, product)
	if not ok then
		warn("[Monetization] Grant failed:", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerData.AddReceipt(player, receipt.PurchaseId)
	PlayerData.MarkChanged(player)
	task.spawn(PlayerData.Save, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Shows the purchase prompt for a pass the player needs (e.g. Triple Hatch)
function Monetization.PromptPass(player: Player, key: string)
	for _, pass in Config.GamePasses do
		if pass.Key == key and pass.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			return
		end
	end
	notify:FireClient(player, "This pass isn't set up yet.", Color3.fromRGB(255, 120, 120))
end

return Monetization
