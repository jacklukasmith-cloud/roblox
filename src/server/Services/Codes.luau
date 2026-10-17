--[[
	Codes players type in Settings for free rewards (share them on TikTok, YouTube, Discord...).
	The list lives on the server only, so nobody can read the codes out of the game files.

	To add a code, add a line to CODES:
	  Rewards: Essence = worth N crystals of the player's best realm, Trophies = n,
	           Items = { [item id from Shared/Items] = count }
	  Expires (optional): os.time() after which it stops working, e.g. os.time({ year = 2026,
	           month = 12, day = 31 })
	Codes aren't case-sensitive. Each player can use each code once.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Format = require(Shared.Format)

local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Bag = require(script.Parent.Bag)

local Codes = {}

type Code = {
	Rewards: { Essence: number?, Trophies: number?, Items: { [string]: number }? },
	Expires: number?,
}

local CODES: { [string]: Code } = {
	RELEASE = { Rewards = { Items = { MysteryGift = 2, LuckPotion = 1 } } },
	MYTHIC = { Rewards = { Essence = 50, Items = { PetTreat = 5 } } },
	TAMER = { Rewards = { Items = { EssencePotion = 1, SpeedPotion = 1 } } },
	THANKYOU = { Rewards = { Trophies = 5, Items = { XPPotion = 1 } } },
}

local lastTry: { [Player]: number } = {}
local COOLDOWN = 2 -- seconds between attempts (stops guessing by spamming)

local function clean(text: string): string
	return string.upper((string.gsub(text, "%s", "")))
end

function Codes.Redeem(player: Player, text: any): (boolean, string?)
	local data = PlayerData.Get(player) :: any
	if not data or type(text) ~= "string" or #text > 40 then
		return false, "Type a code first"
	end
	local now = os.clock()
	if now - (lastTry[player] or 0) < COOLDOWN then
		return false, "Slow down a little!"
	end
	lastTry[player] = now
	local key = clean(text)
	if key == "" then
		return false, "Type a code first"
	end
	local code = CODES[key]
	if not code or (code.Expires and os.time() > code.Expires) then
		return false, if code then "That code has expired" else "That code doesn't exist"
	end
	data.RedeemedCodes = data.RedeemedCodes or {}
	if data.RedeemedCodes[key] then
		return false, "You've already used that code"
	end
	data.RedeemedCodes[key] = true
	data.Stats.CodesRedeemed = (data.Stats.CodesRedeemed or 0) + 1
	local parts = {}
	local rewards = code.Rewards
	if rewards.Essence then
		local amount = Economy.GetProductEssence(player, rewards.Essence)
		Economy.AddEssence(player, amount)
		table.insert(parts, `💎 {Format.Number(amount)}`)
	end
	if rewards.Trophies then
		data.Trophies += rewards.Trophies
		table.insert(parts, `🏆 {rewards.Trophies}`)
	end
	for id, count in rewards.Items or {} do
		local item = Items.Get(id)
		if item then
			Bag.Give(player, id, count, true)
			table.insert(parts, if count > 1 then `{count}x {item.Icon} {item.Name}` else `{item.Icon} {item.Name}`)
		end
	end
	PlayerData.MarkChanged(player)
	return true, `Code redeemed! {table.concat(parts, ", ")}`
end

-- for tests / the admin list
function Codes.List(): { string }
	local list = {}
	for key in CODES do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

function Codes.Forget(player: Player)
	lastTry[player] = nil
end

return Codes
