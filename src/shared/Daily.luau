--[[
	Daily login streak and daily quests (shared so the client can show the same lists).

	Days roll over at midnight UTC. Claiming on consecutive days grows your streak through
	a 7-day cycle (day 7 is the big one, then it starts again). Miss a day and the streak
	starts over at day 1.

	Every day everyone gets the same 3 quests, picked from QUESTS by the day number.
	Finishing all 3 unlocks a bonus reward.
]]

local Daily = {}

export type Reward = {
	Kind: string, -- "Essence" (worth N crystals of your best zone) | "Trophies" | "Boost" | "MysticEgg"
	Amount: number?,
	Boost: string?,
	Seconds: number?,
	Text: string, -- short label for the UI
	Icon: string,
}

-- Day 1..7 of the login streak. A reward can be a list of several.
Daily.StreakRewards = {
	{ { Kind = "Essence", Amount = 40, Text = "Essence", Icon = "💎" } },
	{ { Kind = "Boost", Boost = "Luck", Seconds = 600, Text = "Luck Potion", Icon = "🍀" } },
	{ { Kind = "Essence", Amount = 100, Text = "Essence", Icon = "💎" } },
	{ { Kind = "Boost", Boost = "Essence", Seconds = 900, Text = "Essence Potion", Icon = "⚗️" } },
	{ { Kind = "Trophies", Amount = 5, Text = "5 Trophies", Icon = "🏆" } },
	{ { Kind = "Boost", Boost = "Shiny", Seconds = 600, Text = "Shiny Elixir", Icon = "✨" } },
	{
		{ Kind = "MysticEgg", Text = "Mystic Egg", Icon = "🥚" },
		{ Kind = "Essence", Amount = 300, Text = "Essence", Icon = "💎" },
	},
} :: { { Reward } }

export type Quest = {
	Key: string,
	Stat: string, -- what is counted (see Daily.Track calls on the server)
	Goal: number,
	Text: string,
	Reward: Reward,
}

-- The pool daily quests are drawn from. Stats:
--   BreakCrystals, BreakChests, HatchEggs, HatchRare, BuyMerchant, PlayMinutes
Daily.Quests = {
	{ Key = "Crystals50", Stat = "BreakCrystals", Goal = 50, Text = "Break 50 crystals" },
	{ Key = "Crystals150", Stat = "BreakCrystals", Goal = 150, Text = "Break 150 crystals" },
	{ Key = "Chests2", Stat = "BreakChests", Goal = 2, Text = "Open 2 Mana Chests" },
	{ Key = "Hatch10", Stat = "HatchEggs", Goal = 10, Text = "Hatch 10 eggs" },
	{ Key = "Hatch25", Stat = "HatchEggs", Goal = 25, Text = "Hatch 25 eggs" },
	{ Key = "HatchRare", Stat = "HatchRare", Goal = 1, Text = "Hatch a Rare or better" },
	{ Key = "Merchant1", Stat = "BuyMerchant", Goal = 1, Text = "Buy from the Wandering Merchant" },
	{ Key = "Play15", Stat = "PlayMinutes", Goal = 15, Text = "Play for 15 minutes" },
} :: { any }

-- Reward per quest, and for finishing all of today's quests
Daily.QuestReward = { Kind = "Essence", Amount = 60, Text = "Essence", Icon = "💎" } :: Reward
Daily.BonusReward =
	{ Kind = "Boost", Boost = "Luck", Seconds = 900, Text = "Luck Potion (15 min)", Icon = "🍀" } :: Reward
Daily.QuestsPerDay = 3

function Daily.Today(now: number?): number
	return (now or os.time()) // 86400
end

function Daily.NextReset(now: number?): number
	return (Daily.Today(now) + 1) * 86400
end

-- Which streak day (1..7) a streak count lands on
function Daily.CycleDay(streak: number): number
	return ((math.max(streak, 1) - 1) % #Daily.StreakRewards) + 1
end

-- Streak count after claiming today, given the last day claimed
function Daily.NextStreak(streak: number, lastClaimDay: number, today: number): number
	if lastClaimDay == today - 1 then
		return streak + 1
	end
	return 1
end

local byKey: { [string]: any } = {}
for _, q in Daily.Quests do
	byKey[q.Key] = q
end

function Daily.GetQuest(key: string): any
	return byKey[key]
end

-- Today's quests: a fixed pick per day (same for every player), never two of the same stat
function Daily.QuestsFor(day: number): { any }
	local rng = Random.new(day * 7919 + 17)
	local picked, usedStats = {}, {}
	local pool = table.clone(Daily.Quests)
	while #picked < Daily.QuestsPerDay and #pool > 0 do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		if not usedStats[q.Stat] then
			usedStats[q.Stat] = true
			table.insert(picked, q)
		end
	end
	return picked
end

return Daily
