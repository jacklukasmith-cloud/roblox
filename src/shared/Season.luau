--[[
	Weekly seasons. A season is one House War week (Monday 00:00 UTC to the next Monday).
	Season Points come from breaking crystals, chests and bosses (paid boosts don't count).
	When the week ends, the top players get exclusive titles, creatures and Trophies.
]]

local Config = require(script.Parent.Config)
local Houses = require(script.Parent.Houses)

local Season = {}

export type Tier = {
	MaxRank: number,
	Title: string,
	Color: Color3,
	Creature: { Id: string, Variant: string }?,
	Trophies: number,
}

-- Best tier first. A player gets the first tier their final rank fits in.
Season.Tiers = {
	{
		MaxRank = 3,
		Title = "Season Champion",
		Color = Color3.fromRGB(255, 200, 60),
		Creature = { Id = "TitanUnicorn", Variant = "Rainbow" },
		Trophies = 100,
	},
	{
		MaxRank = 10,
		Title = "Top 10 Tamer",
		Color = Color3.fromRGB(200, 120, 255),
		Creature = { Id = "TitanUnicorn", Variant = "Shiny" },
		Trophies = 50,
	},
	{
		MaxRank = 100,
		Title = "Top 100 Tamer",
		Color = Color3.fromRGB(90, 200, 255),
		Trophies = 25,
	},
} :: { Tier }

function Season.Week(now: number?): number
	return Houses.GetWeek(now or os.time(), Config.Houses.WeekEpochOffset)
end

function Season.EndsAt(week: number): number
	return Houses.WeekEndsAt(week, Config.Houses.WeekEpochOffset)
end

-- Friendly season number (Season 1 is the week the game launched)
function Season.Number(week: number): number
	return math.max(1, week - Config.Season.FirstWeek + 1)
end

function Season.TierFor(rank: number): Tier?
	for _, tier in Season.Tiers do
		if rank <= tier.MaxRank then
			return tier
		end
	end
	return nil
end

-- Titles rank from best (1) down; unknown titles sort last
function Season.TitleRank(title: string): number
	local base = string.gsub(title, "^S%d+ ", "")
	for i, tier in Season.Tiers do
		if tier.Title == base then
			return i
		end
	end
	return math.huge
end

function Season.TitleColor(title: string): Color3
	local base = string.gsub(title, "^S%d+ ", "")
	for _, tier in Season.Tiers do
		if tier.Title == base then
			return tier.Color
		end
	end
	return Color3.new(1, 1, 1)
end

return Season
