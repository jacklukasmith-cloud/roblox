--[[
	The Spin Wheel (rules in Shared.Spin). Data: data.Spin = { NextFree, Spins, Total }.
	The free spin comes back every Spin.FreeEvery seconds; bought/bonus spins stack in Spins.

	SpinWheel.Spin(player) -> ok, sliceIndex | message, rewardText
	SpinWheel.AddSpins(player, n)   (Spin Pack product, codes, rewards)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Spin = require(Shared.Spin)
local Format = require(Shared.Format)
local PlayerData = require(script.Parent.PlayerData)

local SpinWheel = {}

SpinWheel.Rng = Random.new()

local function state(data: any)
	data.Spin = data.Spin or {}
	data.Spin.NextFree = data.Spin.NextFree or 0
	data.Spin.Spins = data.Spin.Spins or 0
	data.Spin.Total = data.Spin.Total or 0
	return data.Spin
end

local function grant(player: Player, data: any, slice: any): string
	local Economy = require(script.Parent.Economy) :: any
	if slice.Kind == "Essence" then
		local amount = Economy.GetProductEssence(player, slice.Amount or 0)
		Economy.AddEssence(player, amount)
		return `💎 {Format.Number(amount)} Essence`
	elseif slice.Kind == "Trophies" then
		data.Trophies = (data.Trophies or 0) + (slice.Amount or 0)
		return `🏆 {slice.Amount} Trophies`
	elseif slice.Kind == "Item" then
		local Bag = require(script.Parent.Bag) :: any
		Bag.Give(player, slice.Item, slice.Amount or 1, true)
		return `{slice.Icon} {slice.Text}`
	elseif slice.Kind == "Spins" then
		state(data).Spins += slice.Amount or 1
		return `🎡 {slice.Amount} bonus spins`
	elseif slice.Kind == "MysticEgg" then
		local Hatching = require(script.Parent.Hatching) :: any
		if Hatching.MysticHatch(player) then
			return "🥚 a Mystic Egg!"
		end
		local amount = Economy.GetProductEssence(player, 300)
		Economy.AddEssence(player, amount)
		return `💎 {Format.Number(amount)} Essence (storage full)`
	end
	return slice.Text
end

function SpinWheel.Available(player: Player, now: number?): number
	local data = PlayerData.Get(player) :: any
	return if data then Spin.Available(state(data), now or os.time()) else 0
end

function SpinWheel.AddSpins(player: Player, n: number)
	local data = PlayerData.Get(player) :: any
	if data then
		state(data).Spins += n
		PlayerData.MarkChanged(player)
	end
end

-- Spin! Uses the free spin first, then a stored one. Returns ok, slice index (or a message), reward text.
function SpinWheel.Spin(player: Player, now: number?): (boolean, any, string?)
	local data = PlayerData.Get(player) :: any
	if not data then
		return false, "Still loading..."
	end
	now = now or os.time()
	local s = state(data)
	if s.NextFree <= now then
		s.NextFree = now + Spin.FreeEvery
	elseif s.Spins > 0 then
		s.Spins -= 1
	else
		return false, "No spins left: the free one comes back soon"
	end
	local index = Spin.Pick(SpinWheel.Rng:NextNumber())
	local got = grant(player, data, Spin.Slices[index])
	s.Total += 1
	data.Stats.Spins = (data.Stats.Spins or 0) + 1
	PlayerData.MarkChanged(player)
	return true, index, got
end

function SpinWheel.Snapshot(data: any)
	local s = state(data)
	return { NextFree = s.NextFree, Spins = s.Spins, Total = s.Total, Now = os.time() }
end

return SpinWheel
