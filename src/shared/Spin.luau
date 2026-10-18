--[[
	The Spin Wheel (🎡 in the menu). One free spin every few hours; extra spins come from the
	Spin Pack product. Each spin lands on one of the Slices below (weighted); rewards reuse the
	Daily reward kinds (Essence / Item / Trophies / MysticEgg) plus "Spins" (bonus spins).

	The server picks the slice and hands out the reward straight away; the client just animates
	the wheel landing on it and then shows what you won.
]]

local Spin = {}

Spin.FreeEvery = 4 * 3600 -- seconds between free spins
Spin.SpinSeconds = 3.2 -- how long the client animation runs
Spin.PackSpins = 5 -- spins per Spin Pack (the Robux product)

-- Weight = how likely. Icon/Text show on the wheel.
Spin.Slices = {
	{ Weight = 26, Icon = "💎", Text = "Essence", Kind = "Essence", Amount = 60 },
	{ Weight = 16, Icon = "🍪", Text = "3 Treats", Kind = "Item", Item = "PetTreat", Amount = 3 },
	{ Weight = 14, Icon = "🍀", Text = "Luck Potion", Kind = "Item", Item = "LuckPotion", Amount = 1 },
	{ Weight = 12, Icon = "💎💎", Text = "Big Essence", Kind = "Essence", Amount = 200 },
	{ Weight = 10, Icon = "⚗️", Text = "Essence Potion", Kind = "Item", Item = "EssencePotion", Amount = 1 },
	{ Weight = 9, Icon = "🏆", Text = "3 Trophies", Kind = "Trophies", Amount = 3 },
	{ Weight = 8, Icon = "🎁", Text = "Mystery Gift", Kind = "Item", Item = "MysteryGift", Amount = 1 },
	{ Weight = 3, Icon = "🎡", Text = "+2 Spins", Kind = "Spins", Amount = 2, Rare = true },
	{ Weight = 2, Icon = "🥚", Text = "Mystic Egg", Kind = "MysticEgg", Text2 = "JACKPOT", Rare = true },
}

function Spin.TotalWeight(): number
	local total = 0
	for _, s in Spin.Slices do
		total += s.Weight
	end
	return total
end

-- Picks a slice index from a roll in [0, 1)
function Spin.Pick(roll: number): number
	local target = roll * Spin.TotalWeight()
	local acc = 0
	for i, s in Spin.Slices do
		acc += s.Weight
		if target < acc then
			return i
		end
	end
	return #Spin.Slices
end

-- How many spins someone has right now (free one counts as 1)
function Spin.Available(state: any, now: number): number
	local n = (state and state.Spins) or 0
	if (state and state.NextFree or 0) <= now then
		n += 1
	end
	return n
end

return Spin
