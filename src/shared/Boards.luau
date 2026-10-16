--[[
	Leaderboard categories (Services/Leaderboards keeps them, the 🏆 Leaderboards window shows them).
	Weekly boards reset every Monday 00:00 UTC (same week as the Season), so new players can
	get on them too.

	Value(data) = the player's score from their save. Weekly ones count from the start of the
	week (data.WeekStats holds the totals at the start of the week).
]]

local Creatures = require(script.Parent.Creatures)
local Season = require(script.Parent.Season)

export type Board = {
	Id: string,
	Name: string,
	Icon: string,
	Store: string, -- OrderedDataStore name (weekly ones get the week number added)
	Weekly: boolean,
	Value: (data: any) -> number,
}

local Boards = {}

local function weekly(data: any, stat: string): number
	local ws = data.WeekStats
	local now = tonumber((data.Stats or {})[stat]) or 0
	if not ws or ws.Week ~= Season.Week() then
		return 0
	end
	return math.max(0, now - (ws.Base[stat] or now))
end

Boards.List = {
	{
		Id = "Trophies",
		Name = "Top Trophies",
		Icon = "🏆",
		Store = "MythicTamers_Trophies_v1",
		Weekly = false,
		Value = function(d)
			return d.Trophies or 0
		end,
	},
	{
		Id = "Essence",
		Name = "Most Essence Earned",
		Icon = "💎",
		Store = "MythicTamers_TotalEssence_v1",
		Weekly = false,
		Value = function(d)
			return math.min(d.TotalEssence or 0, 2 ^ 53)
		end,
	},
	{
		Id = "Rebirths",
		Name = "Most Rebirths",
		Icon = "🌀",
		Store = "MythicTamers_Rebirths_v1",
		Weekly = false,
		Value = function(d)
			return d.Rebirths or 0
		end,
	},
	{
		Id = "Index",
		Name = "Most Species Found",
		Icon = "📖",
		Store = "MythicTamers_Index_v1",
		Weekly = false,
		Value = function(d)
			local n = 0
			for id in d.Bestiary or {} do
				if Creatures.Get(id) then
					n += 1
				end
			end
			return n
		end,
	},
	{
		Id = "WeekCrystals",
		Name = "Crystals This Week",
		Icon = "💠",
		Store = "MythicTamers_WeekCrystals_v1_",
		Weekly = true,
		Value = function(d)
			return weekly(d, "CrystalsBroken")
		end,
	},
	{
		Id = "WeekHatched",
		Name = "Eggs Hatched This Week",
		Icon = "🥚",
		Store = "MythicTamers_WeekHatched_v1_",
		Weekly = true,
		Value = function(d)
			return weekly(d, "CreaturesHatched")
		end,
	},
} :: { Board }

function Boards.Get(id: string): Board?
	for _, board in Boards.List do
		if board.Id == id then
			return board
		end
	end
	return nil
end

-- Starts this week's counting (call before reading weekly values)
function Boards.RollWeek(data: any)
	local week = Season.Week()
	local ws = data.WeekStats
	if not ws or ws.Week ~= week then
		local stats = data.Stats or {}
		data.WeekStats = {
			Week = week,
			Base = { CrystalsBroken = stats.CrystalsBroken or 0, CreaturesHatched = stats.CreaturesHatched or 0 },
		}
	end
end

return Boards
