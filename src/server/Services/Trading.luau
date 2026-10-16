--[[
	Player-to-player trading (creatures and Bag items), in the style of Adopt Me and Pet Simulator 99.

	1. Send a request from the 🤝 Trade menu; the other player accepts or declines (30 s).
	2. Both sides add creatures and Bag items. Any change un-readies both players.
	3. Both press Ready -> a 5-second lock counts down. Any change or Cancel stops it.
	4. The server checks everything is still owned and fits, then swaps both sides in one go,
	   saves both players straight away and writes it to both trade logs.

	Everything is checked on the server; the client only ever asks.
	Players whose Roblox account policy doesn't allow trading paid items can't trade.
]]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)

local Trading = {}

Trading.LockSeconds = 5
Trading.InviteSeconds = 30
Trading.MaxPets = 12 -- per side
Trading.MaxItemStacks = 12 -- per side
Trading.RequestCooldown = 5
Trading.LogSize = 20

local tradeUpdate = Remotes.Event("TradeUpdate")
local tradeInvite = Remotes.Event("TradeInvite")

type Offer = { Pets: { [string]: boolean }, Items: { [string]: number } }
type Trade = {
	A: Player,
	B: Player,
	Offers: { [Player]: Offer },
	Ready: { [Player]: boolean },
	LockEndsAt: number?,
	Version: number,
	Open: boolean,
}

local sessions: { [Player]: Trade } = {}
local invites: { [Player]: { [Player]: number } } = {} -- invites[target][from] = expires at
local lastRequest: { [Player]: number } = {}
local policyCache: { [Player]: boolean } = {}

local function other(trade: Trade, player: Player): Player
	return if trade.A == player then trade.B else trade.A
end

-- Roblox requires blocking trades of paid items for some accounts/regions
local function canTrade(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	local cached = policyCache[player]
	if cached ~= nil then
		return cached
	end
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local allowed = ok and type(info) == "table" and info.IsPaidItemTradingAllowed == true
	policyCache[player] = allowed
	return allowed
end

-- What one side sees: their offer, the other side's offer, ready flags and the countdown
local function view(trade: Trade, viewer: Player): any
	local function describe(player: Player)
		local data = PlayerData.Get(player) :: any
		local offer = trade.Offers[player]
		local pets, items = {}, {}
		for uid in offer.Pets do
			local entry = data and data.Creatures[uid]
			if entry then
				table.insert(pets, { Uid = uid, Id = entry.Id, Variant = entry.Variant, Level = entry.Level or 1 })
			end
		end
		for id, count in offer.Items do
			table.insert(items, { Id = id, Count = count })
		end
		table.sort(items, function(x, y)
			return x.Id < y.Id
		end)
		return { Pets = pets, Items = items }
	end
	local partner = other(trade, viewer)
	return {
		Partner = { Name = partner.DisplayName, UserId = partner.UserId },
		Mine = describe(viewer),
		Theirs = describe(partner),
		MyReady = trade.Ready[viewer] == true,
		TheirReady = trade.Ready[partner] == true,
		LockIn = if trade.LockEndsAt then math.max(0, trade.LockEndsAt - os.clock()) else nil,
	}
end

local function push(trade: Trade)
	for _, player in { trade.A, trade.B } do
		if player.Parent then
			tradeUpdate:FireClient(player, view(trade, player))
		end
	end
end

local function close(trade: Trade, message: string?, color: Color3?)
	if not trade.Open then
		return
	end
	trade.Open = false
	for _, player in { trade.A, trade.B } do
		if sessions[player] == trade then
			sessions[player] = nil
		end
		if player.Parent then
			tradeUpdate:FireClient(player, nil, message, color)
		end
	end
end

-- Anything changed: nobody is ready any more and the lock stops
local function changed(trade: Trade)
	trade.Ready[trade.A] = false
	trade.Ready[trade.B] = false
	trade.LockEndsAt = nil
	trade.Version += 1
	push(trade)
end

-- Is everything on offer still there? (they might have released or fused something)
local function offerValid(player: Player, offer: Offer): boolean
	local data = PlayerData.Get(player) :: any
	if not data then
		return false
	end
	for uid in offer.Pets do
		if not data.Creatures[uid] then
			return false
		end
	end
	for id, count in offer.Items do
		if (data.Items and data.Items[id] or 0) < count then
			return false
		end
	end
	return true
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function log(data: any, partner: Player, gave: { string }, got: { string })
	data.TradeLog = data.TradeLog or {}
	table.insert(data.TradeLog, 1, {
		Time = os.time(),
		With = partner.UserId,
		Name = partner.Name,
		Gave = gave,
		Got = got,
	})
	while #data.TradeLog > Trading.LogSize do
		table.remove(data.TradeLog)
	end
end

local function summary(player: Player, offer: Offer): { string }
	local data = PlayerData.Get(player) :: any
	local list = {}
	for uid in offer.Pets do
		local entry = data and data.Creatures[uid]
		if entry then
			table.insert(list, `{entry.Variant ~= "Normal" and entry.Variant .. " " or ""}{entry.Id}`)
		end
	end
	for id, n in offer.Items do
		table.insert(list, `{n}x {id}`)
	end
	return list
end

-- Moves one side's offer to the other player
local function move(from: Player, to: Player, offer: Offer)
	local fromData = PlayerData.Get(from) :: any
	local toData = PlayerData.Get(to) :: any
	for uid in offer.Pets do
		local entry = fromData.Creatures[uid]
		fromData.Creatures[uid] = nil
		local newUid = PlayerData.NewCreature(toData, entry.Id, entry.Variant)
		local copy = toData.Creatures[newUid]
		copy.Level = entry.Level
		copy.XP = entry.XP
		copy.Equipped = false
		toData.Bestiary[entry.Id] = true
	end
	for id, n in offer.Items do
		fromData.Items[id] -= n
		if fromData.Items[id] <= 0 then
			fromData.Items[id] = nil
		end
		toData.Items = toData.Items or {}
		toData.Items[id] = math.min((toData.Items[id] or 0) + n, Items.MaxStack)
	end
end

-- Does the swap if both are still ready and nothing changed during the lock
local function finish(trade: Trade, version: number)
	if not trade.Open or trade.Version ~= version or not (trade.Ready[trade.A] and trade.Ready[trade.B]) then
		return
	end
	local a, b = trade.A, trade.B
	local offerA, offerB = trade.Offers[a], trade.Offers[b]
	if not a.Parent or not b.Parent then
		close(trade, "The other player left")
		return
	end
	if not offerValid(a, offerA) or not offerValid(b, offerB) then
		close(trade, "Trade cancelled: something on offer isn't there any more", Color3.fromRGB(255, 120, 120))
		return
	end
	local dataA, dataB = PlayerData.Get(a) :: any, PlayerData.Get(b) :: any
	local countA, countB = PlayerData.CountCreatures(dataA), PlayerData.CountCreatures(dataB)
	local petsA, petsB = count(offerA.Pets), count(offerB.Pets)
	if countA - petsA + petsB > Config.MaxInventory or countB - petsB + petsA > Config.MaxInventory then
		close(trade, "Trade cancelled: someone's creature storage would be too full", Color3.fromRGB(255, 120, 120))
		return
	end
	if petsA == 0 and petsB == 0 and count(offerA.Items) == 0 and count(offerB.Items) == 0 then
		close(trade, "Trade cancelled: nothing was offered")
		return
	end
	local gaveA, gaveB = summary(a, offerA), summary(b, offerB)
	move(a, b, offerA)
	move(b, a, offerB)
	log(dataA, b, gaveA, gaveB)
	log(dataB, a, gaveB, gaveA)
	print(`[Trading] {a.Name} gave [{table.concat(gaveA, ", ")}] to {b.Name} for [{table.concat(gaveB, ", ")}]`)
	PlayerData.MarkChanged(a)
	PlayerData.MarkChanged(b)
	-- save both right away, so a server crash can't undo half a trade
	task.spawn(PlayerData.Save, a)
	task.spawn(PlayerData.Save, b)
	close(trade, "🤝 Trade complete!", Color3.fromRGB(120, 255, 160))
end

local function start(a: Player, b: Player)
	local trade: Trade = {
		A = a,
		B = b,
		Offers = { [a] = { Pets = {}, Items = {} }, [b] = { Pets = {}, Items = {} } },
		Ready = { [a] = false, [b] = false },
		LockEndsAt = nil,
		Version = 0,
		Open = true,
	}
	sessions[a] = trade
	sessions[b] = trade
	if invites[a] then
		invites[a][b] = nil
	end
	if invites[b] then
		invites[b][a] = nil
	end
	push(trade)
end

local function findPlayer(userId: any): Player?
	return if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

-- Remote handlers (each returns ok, message) ------------------------------------------------

function Trading.Request(player: Player, targetUserId: any): (boolean, string?)
	local target = findPlayer(targetUserId)
	if not target or target == player then
		return false, "That player isn't here"
	end
	if not PlayerData.Get(player) or not PlayerData.Get(target) then
		return false, "Still loading..."
	end
	if not canTrade(player) then
		return false, "Trading isn't available on your account"
	end
	if not canTrade(target) then
		return false, `{target.DisplayName} can't trade`
	end
	if sessions[player] then
		return false, "You're already trading"
	end
	if sessions[target] then
		return false, `{target.DisplayName} is busy trading`
	end
	-- they already asked you: just start
	local mine = invites[player]
	if mine and mine[target] and mine[target] > os.clock() then
		start(target, player)
		return true, nil
	end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < Trading.RequestCooldown then
		return false, "Wait a moment before sending another request"
	end
	lastRequest[player] = now
	invites[target] = invites[target] or {}
	invites[target][player] = now + Trading.InviteSeconds
	tradeInvite:FireClient(target, player.UserId, player.DisplayName)
	return true, `Trade request sent to {target.DisplayName}`
end

function Trading.Respond(player: Player, fromUserId: any, accept: any): (boolean, string?)
	local from = findPlayer(fromUserId)
	local pending = invites[player]
	if not from or not pending or not pending[from] or pending[from] < os.clock() then
		return false, "That request has expired"
	end
	pending[from] = nil
	if accept ~= true then
		if from.Parent then
			Remotes.Event("Notify")
				:FireClient(from, `{player.DisplayName} declined your trade`, Color3.fromRGB(255, 160, 120))
		end
		return true, nil
	end
	if sessions[player] or sessions[from] then
		return false, "One of you is already trading"
	end
	start(from, player)
	return true, nil
end

function Trading.SetPet(player: Player, uid: any, on: any): (boolean, string?)
	local trade = sessions[player]
	local data = PlayerData.Get(player) :: any
	if not trade or not data or type(uid) ~= "string" or not data.Creatures[uid] then
		return false, nil
	end
	local pets = trade.Offers[player].Pets
	if on == true then
		if count(pets) >= Trading.MaxPets then
			return false, `You can offer up to {Trading.MaxPets} creatures`
		end
		pets[uid] = true
	else
		pets[uid] = nil
	end
	changed(trade)
	return true, nil
end

function Trading.SetItem(player: Player, id: any, amount: any): (boolean, string?)
	local trade = sessions[player]
	local data = PlayerData.Get(player) :: any
	if not trade or not data or type(id) ~= "string" or not Items.Get(id) or type(amount) ~= "number" then
		return false, nil
	end
	local have = data.Items and data.Items[id] or 0
	local n = math.clamp(math.floor(amount), 0, have)
	local items = trade.Offers[player].Items
	if n > 0 and not items[id] and count(items) >= Trading.MaxItemStacks then
		return false, `You can offer up to {Trading.MaxItemStacks} kinds of items`
	end
	items[id] = if n > 0 then n else nil
	changed(trade)
	return true, nil
end

function Trading.SetReady(player: Player, ready: any): (boolean, string?)
	local trade = sessions[player]
	if not trade then
		return false, nil
	end
	trade.Ready[player] = ready == true
	if trade.Ready[trade.A] and trade.Ready[trade.B] then
		trade.LockEndsAt = os.clock() + Trading.LockSeconds
		local version = trade.Version
		task.delay(Trading.LockSeconds, finish, trade, version)
	else
		trade.LockEndsAt = nil
		trade.Version += 1 -- stops a running countdown
	end
	push(trade)
	return true, nil
end

function Trading.Cancel(player: Player): (boolean, string?)
	local trade = sessions[player]
	if trade then
		close(trade, `Trade cancelled by {player.DisplayName}`)
	end
	return true, nil
end

function Trading.InTrade(player: Player): boolean
	return sessions[player] ~= nil
end

function Trading.Start()
	Players.PlayerRemoving:Connect(function(player)
		local trade = sessions[player]
		if trade then
			close(trade, `{player.DisplayName} left the game`)
		end
		invites[player] = nil
		for _, list in invites do
			list[player] = nil
		end
		lastRequest[player] = nil
		policyCache[player] = nil
	end)
end

return Trading
