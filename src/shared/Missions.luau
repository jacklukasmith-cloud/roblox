--[[
	The mission chain that guides players through the game, one mission at a time. Each one
	points the guide arrow at where to go and pays a reward when it's done.

	Kind:
	  "Count": do it N more times from when the mission started (the start value is stored as
	           Missions.Baseline in the save, so earlier progress doesn't count)
	  "Reach": get the stat up to N (counts what you already have)
	Target: where the guide arrow points (Crystal, Egg, Gate, Blacksmith, Boss, or nil for none)
	Reward: { Essence = n } / { Trophies = n } / { Title = "..." } (any mix)
]]

local Creatures = require(script.Parent.Creatures)

export type Mission = {
	Id: string,
	Text: string,
	Stat: string,
	Kind: "Count" | "Reach",
	Goal: number,
	Target: string?,
	Hint: string?, -- extra help shown under the mission
	Reward: { Essence: number?, Trophies: number?, Title: string? },
}

local Missions = {}

Missions.List = {
	{
		Id = "Break3",
		Text = "Break 3 crystals",
		Stat = "CrystalsBroken",
		Kind = "Count",
		Goal = 3,
		Target = "Crystal",
		Hint = "Click a crystal and your creatures attack it",
		Reward = { Essence = 25 },
	},
	{
		Id = "Hatch1",
		Text = "Hatch your first egg",
		Stat = "CreaturesHatched",
		Kind = "Count",
		Goal = 1,
		Target = "Egg",
		Hint = "Walk up to the egg and hatch it",
		Reward = { Essence = 40 },
	},
	{
		Id = "Pickaxe5",
		Text = "Hit 5 crystals with your pickaxe",
		Stat = "PickaxeHits",
		Kind = "Count",
		Goal = 5,
		Target = "Crystal",
		Hint = "Hold your pickaxe (⛏ or Q) and click near a crystal",
		Reward = { Essence = 60 },
	},
	{
		Id = "Hatch3",
		Text = "Hatch 3 more eggs",
		Stat = "CreaturesHatched",
		Kind = "Count",
		Goal = 3,
		Target = "Egg",
		Hint = "New creatures join your team automatically",
		Reward = { Essence = 80 },
	},
	{
		Id = "Break25",
		Text = "Break 25 crystals",
		Stat = "CrystalsBroken",
		Kind = "Count",
		Goal = 25,
		Target = "Crystal",
		Reward = { Essence = 150 },
	},
	{
		Id = "Zone2",
		Text = "Unlock Ember Rift",
		Stat = "ZonesUnlocked",
		Kind = "Reach",
		Goal = 2,
		Target = "Gate",
		Hint = "Save up Essence and open the gate",
		Reward = { Essence = 500 },
	},
	{
		Id = "Pickaxe2",
		Text = "Upgrade your pickaxe",
		Stat = "Pickaxe",
		Kind = "Reach",
		Goal = 2,
		Target = "Blacksmith",
		Hint = "Step into the Blacksmith's circle in the hub",
		Reward = { Essence = 600 },
	},
	{
		Id = "Hatch5",
		Text = "Hatch 5 eggs",
		Stat = "CreaturesHatched",
		Kind = "Count",
		Goal = 5,
		Target = "Egg",
		Reward = { Essence = 1000 },
	},
	{
		Id = "Index8",
		Text = "Discover 8 species",
		Stat = "Species",
		Kind = "Reach",
		Goal = 8,
		Target = "Egg",
		Hint = "Check the Index to see which ones you're missing",
		Reward = { Essence = 2000 },
	},
	{
		Id = "Level5",
		Text = "Level a creature up to level 5",
		Stat = "BestLevel",
		Kind = "Reach",
		Goal = 5,
		Target = "Crystal",
		Hint = "Equipped creatures level up as they break crystals",
		Reward = { Essence = 3000 },
	},
	{
		Id = "Break150",
		Text = "Break 150 crystals",
		Stat = "CrystalsBroken",
		Kind = "Count",
		Goal = 150,
		Target = "Crystal",
		Reward = { Essence = 5000 },
	},
	{
		Id = "Zone3",
		Text = "Unlock Frostpeak",
		Stat = "ZonesUnlocked",
		Kind = "Reach",
		Goal = 3,
		Target = "Gate",
		Reward = { Essence = 15000 },
	},
	{
		Id = "Fuse1",
		Text = "Fuse creatures for the first time",
		Stat = "Fusions",
		Kind = "Count",
		Goal = 1,
		Hint = "Open Pets, tap a creature you have lots of copies of, then Fuse",
		Reward = { Essence = 20000 },
	},
	{
		Id = "Boss1",
		Text = "Help defeat a boss",
		Stat = "BossesDefeated",
		Kind = "Count",
		Goal = 1,
		Target = "Boss",
		Hint = "Bosses appear every so often; the top of the screen counts down",
		Reward = { Essence = 40000 },
	},
	{
		Id = "Pickaxe4",
		Text = "Get an Iron Pickaxe",
		Stat = "Pickaxe",
		Kind = "Reach",
		Goal = 4,
		Target = "Blacksmith",
		Reward = { Essence = 50000 },
	},
	{
		Id = "Index15",
		Text = "Discover 15 species",
		Stat = "Species",
		Kind = "Reach",
		Goal = 15,
		Target = "Egg",
		Reward = { Essence = 80000 },
	},
	{
		Id = "Zone4",
		Text = "Unlock Sky Sanctum",
		Stat = "ZonesUnlocked",
		Kind = "Reach",
		Goal = 4,
		Target = "Gate",
		Reward = { Essence = 300000 },
	},
	{
		Id = "Rebirth1",
		Text = "Rebirth for the first time",
		Stat = "Rebirths",
		Kind = "Reach",
		Goal = 1,
		Hint = "Open Rebirth: you restart with +50% Essence forever and keep your creatures",
		Reward = { Trophies = 10 },
	},
	{
		Id = "Index25",
		Text = "Discover all 25 species",
		Stat = "Species",
		Kind = "Reach",
		Goal = 25,
		Target = "Egg",
		Reward = { Trophies = 25, Title = "Master Tamer" },
	},
} :: { Mission }

-- Current value of a mission stat from the save (or the client's snapshot)
function Missions.Value(data: any, stat: string): number
	local stats = data.Stats or {}
	if stat == "ZonesUnlocked" then
		return data.ZonesUnlocked or 1
	elseif stat == "Pickaxe" then
		return data.Pickaxe or 1
	elseif stat == "Rebirths" then
		return data.Rebirths or 0
	elseif stat == "Species" then
		local n = 0
		for id in data.Bestiary or {} do
			if Creatures.Get(id) then
				n += 1
			end
		end
		return n
	elseif stat == "BestLevel" then
		local best = 1
		for _, entry in data.Creatures or {} do
			best = math.max(best, entry.Level or 1)
		end
		return best
	end
	return tonumber(stats[stat]) or 0
end

-- The current mission (nil = all done), how far along it is, and the goal
function Missions.Current(data: any): (Mission?, number, number)
	if not data then
		return nil, 0, 0
	end
	local state = data.Missions
	local mission = Missions.List[if state then state.Index else 1]
	if not mission then
		return nil, 0, 0
	end
	local value = Missions.Value(data, mission.Stat)
	local progress = if mission.Kind == "Count" then value - ((state and state.Baseline) or value) else value
	return mission, math.clamp(progress, 0, mission.Goal), mission.Goal
end

function Missions.RewardText(
	reward: { Essence: number?, Trophies: number?, Title: string? },
	format: (number) -> string
): string
	local parts = {}
	if reward.Essence then
		table.insert(parts, `💎 {format(reward.Essence)}`)
	end
	if reward.Trophies then
		table.insert(parts, `🏆 {reward.Trophies}`)
	end
	if reward.Title then
		table.insert(parts, `"{reward.Title}" title`)
	end
	return table.concat(parts, " + ")
end

return Missions
