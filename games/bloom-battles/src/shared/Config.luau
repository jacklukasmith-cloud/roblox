--[[
	Every tunable number for +1 Bloom Every Second: Bloom Battles lives here.

	The loop: your flower spirit gains +1 Bloom every second (times your multipliers).
	Bloom makes you bigger and brighter. Walk into new gardens for bigger multipliers,
	challenge other players (or wandering Garden Spirits) to a Bloom Battle tug-of-war,
	and Replant (rebirth) for a permanent multiplier.
]]

local Config = {}

Config.GameName = "+1 Bloom Every Second"
Config.DataStoreName = "BloomBattles_v1"
Config.AutosaveSeconds = 120

-- Growth -------------------------------------------------------------------------------
Config.BasePerSecond = 1
Config.MaxScale = 3.2 -- biggest a character can grow
Config.ScalePerDecade = 0.32 -- extra size per x10 Bloom

-- Replant (rebirth): costs grow x5 each time, each Replant adds +50% to every gain.
Config.ReplantBaseCost = 10000
Config.ReplantCostGrowth = 5
Config.ReplantBonus = 0.5

-- Optional game pass that doubles Bloom. Paste your pass id here (0 = disabled).
Config.DoubleBloomPassId = 0

-- Tiers: name, Bloom needed, colour of crown + aura. Calm pastels.
Config.Tiers = {
	{ Name = "Seedling", Need = 0, Color = Color3.fromRGB(196, 222, 178) },
	{ Name = "Sprout", Need = 100, Color = Color3.fromRGB(160, 214, 180) },
	{ Name = "Bud", Need = 1000, Color = Color3.fromRGB(246, 196, 196) },
	{ Name = "Blossom", Need = 10000, Color = Color3.fromRGB(244, 170, 196) },
	{ Name = "Full Bloom", Need = 100000, Color = Color3.fromRGB(200, 178, 236) },
	{ Name = "Radiant", Need = 1000000, Color = Color3.fromRGB(170, 206, 240) },
	{ Name = "Moonpetal", Need = 10000000, Color = Color3.fromRGB(236, 230, 250) },
	{ Name = "Eternal Garden", Need = 100000000, Color = Color3.fromRGB(255, 226, 160) },
}

-- Gardens (zones) run one after another along +Z.
Config.ZoneLength = 220
Config.ZoneHalfWidth = 90
Config.Zones = {
	{
		Name = "Sunny Meadow",
		Need = 0,
		Multiplier = 1,
		Ground = { Color3.fromRGB(168, 204, 140), Color3.fromRGB(178, 212, 148), Color3.fromRGB(158, 196, 136) },
		Path = Color3.fromRGB(232, 218, 190),
		Leaf = { Color3.fromRGB(124, 178, 120), Color3.fromRGB(140, 190, 128), Color3.fromRGB(110, 164, 116) },
		Flower = { Color3.fromRGB(250, 214, 220), Color3.fromRGB(255, 240, 196), Color3.fromRGB(255, 255, 250) },
		ClockTime = 14.5,
		Tint = Color3.fromRGB(255, 250, 242),
		Haze = Color3.fromRGB(230, 236, 222),
		SpiritBloom = 40,
	},
	{
		Name = "Lavender Hills",
		Need = 1000,
		Multiplier = 2,
		Ground = { Color3.fromRGB(176, 196, 156), Color3.fromRGB(186, 202, 160), Color3.fromRGB(168, 188, 150) },
		Path = Color3.fromRGB(226, 214, 222),
		Leaf = { Color3.fromRGB(176, 154, 210), Color3.fromRGB(190, 168, 222), Color3.fromRGB(160, 140, 200) },
		Flower = { Color3.fromRGB(196, 170, 230), Color3.fromRGB(226, 206, 246), Color3.fromRGB(250, 236, 250) },
		ClockTime = 16.2,
		Tint = Color3.fromRGB(250, 242, 255),
		Haze = Color3.fromRGB(226, 214, 236),
		SpiritBloom = 1500,
	},
	{
		Name = "Misty Lake",
		Need = 25000,
		Multiplier = 4,
		Ground = { Color3.fromRGB(150, 192, 170), Color3.fromRGB(160, 200, 178), Color3.fromRGB(142, 184, 164) },
		Path = Color3.fromRGB(214, 226, 226),
		Leaf = { Color3.fromRGB(110, 170, 160), Color3.fromRGB(126, 184, 170), Color3.fromRGB(98, 156, 150) },
		Flower = { Color3.fromRGB(186, 226, 240), Color3.fromRGB(226, 246, 250), Color3.fromRGB(250, 226, 236) },
		ClockTime = 17.4,
		Tint = Color3.fromRGB(240, 250, 255),
		Haze = Color3.fromRGB(206, 226, 232),
		SpiritBloom = 40000,
	},
	{
		Name = "Moon Grove",
		Need = 500000,
		Multiplier = 8,
		Ground = { Color3.fromRGB(110, 128, 150), Color3.fromRGB(118, 136, 158), Color3.fromRGB(102, 120, 142) },
		Path = Color3.fromRGB(190, 196, 222),
		Leaf = { Color3.fromRGB(122, 140, 190), Color3.fromRGB(140, 156, 206), Color3.fromRGB(108, 124, 176) },
		Flower = { Color3.fromRGB(220, 226, 255), Color3.fromRGB(200, 240, 236), Color3.fromRGB(250, 236, 200) },
		ClockTime = 20.6,
		Tint = Color3.fromRGB(232, 236, 255),
		Haze = Color3.fromRGB(150, 160, 196),
		SpiritBloom = 800000,
	},
}

-- Bloom Battles (tug-of-war duels) -----------------------------------------------------
Config.Duel = {
	PadRadius = 4.5,
	SpiritWait = 4, -- seconds alone on a pad before a Garden Spirit accepts
	Countdown = 3,
	Length = 12, -- seconds of tapping
	PushPerTap = 0.06, -- share of the rope one tap moves (scaled by relative strength)
	StrengthPower = 0.35, -- strength = (Bloom + 10) ^ this; more Bloom helps but tapping matters
	MaxTapsPerSecond = 14, -- server ignores taps above this
	WinShare = 0.1, -- winner gains this share of the loser's Bloom...
	WinCapSeconds = 60, -- ...but at most this many seconds of their own growth vs a player
	SpiritCapSeconds = 25, -- ...or this many vs a Garden Spirit (stops exponential farming)
	WinFlat = 50,
	LoseShare = 0.02, -- a calm game: losers still get a little
	LoseCapSeconds = 8,
	Cooldown = 3,
	SpiritTapsPerSecond = { 5, 9 },
	SpiritBloomRange = { 0.55, 1.35 }, -- spirit Bloom relative to the challenger
}

-- Sounds: built-in Roblox sounds so the game is never silent. Swap in your own ids.
Config.Sounds = {
	Pop = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Tap = "rbxasset://sounds/clickfast.wav",
	Burst = "rbxasset://sounds/electronicpingshort.wav",
	Music = "", -- paste a calm music asset id, e.g. "rbxassetid://123"
}

return Config
