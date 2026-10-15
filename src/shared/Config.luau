--[[
	Central tuning file. Almost every number that affects balance or money lives here,
	so you can rebalance the game without touching gameplay code.

	BEFORE PUBLISHING: create your game passes / developer products on the Creator Hub
	and paste their IDs below. An Id of 0 means "not set up yet" - the shop shows it as
	unavailable and nothing breaks.
]]

local Config = {}

-- Data ----------------------------------------------------------------------------
Config.DataStoreName = "MythicTamers_PlayerData_v1"
Config.AutosaveInterval = 120 -- seconds
Config.MaxReceiptHistory = 50

-- Collecting (Pet Simulator style) -------------------------------------------------
-- Click a crystal to send your creatures at it; they deal your Power as damage every tick.
Config.BaseClickPower = 1
Config.PetAttackInterval = 0.25 -- seconds between creature attack ticks
Config.PetDamageMultiplier = 0.75 -- damage per tick = Power * this (3 Power/sec)
Config.PetTravelTime = 0.6 -- creatures fly to the target first; damage starts after this
Config.MaxHitDistance = 45 -- studs from character to crystal when choosing a target
Config.MaxAttackDistance = 70 -- creatures give up if you walk further than this away
Config.CrystalRespawnTime = 4
Config.AutoCollectRange = 40 -- Auto Collect pass: auto-targets the nearest crystal within this range
Config.StarterCreature = "GlowSprite" -- every new player gets one, so they can farm straight away

-- Critical hits: each creature attack tick can crit for bonus damage
Config.Crit = {
	Chance = 0.08,
	Multiplier = 2.5,
}

-- Combos: breaking crystals back-to-back (within Window seconds of the last break) builds a combo.
-- Each step adds Step to the Essence multiplier, up to Max steps (about x1.9 at 30).
Config.Combo = {
	Window = 3,
	Step = 0.03,
	Max = 30,
}

-- Crystal strength: every crystal rolls a size when it spawns/respawns (Weight = how common).
-- HP and Reward multiply the realm's base crystal; Scale is how big it looks.
Config.CrystalSizes = {
	{ Name = "Normal", Weight = 50, HP = 1, Reward = 1, Scale = 1 },
	{ Name = "Strong", Weight = 30, HP = 1.5, Reward = 1.5, Scale = 1.15 },
	{ Name = "Tough", Weight = 17, HP = 2, Reward = 2, Scale = 1.3 },
	{ Name = "Giant", Weight = 3, HP = 10, Reward = 12, Scale = 2 },
}

-- Boss raids: a giant creature appears in a realm; everyone attacks it together
Config.Boss = {
	FirstDelay = 120, -- seconds after the server starts (StudioFirstDelay in Studio playtests)
	StudioFirstDelay = 20,
	Interval = 900, -- seconds between bosses
	WarnBefore = 30, -- everyone gets a heads-up this many seconds before a boss appears
	Duration = 180, -- seconds before an undefeated boss escapes
	TargetSeconds = 60, -- HP is sized so the whole server needs about this long
	RewardMultiplier = 150, -- Essence worth this many crystals, shared by damage
	TopTrophies = { 10, 6, 4 }, -- extra Trophies for the top 3 damage dealers
	ParticipationTrophies = 1,
	Scale = 3.2, -- creature model size
}

-- Ground textures (Higgsfield images, see docs/ICONS.md). Upload each image on the Creator Hub
-- (Creations -> Development Items -> Images) and paste its ID here, e.g. "rbxassetid://123".
-- Empty = keep the plain material. TileStuds = how many studs one copy of the image covers.
Config.GroundTextures = {
	TileStuds = 16,
	Hub = "rbxassetid://84951941657028", -- stone
	[1] = "rbxassetid://97461172258793", -- Enchanted Meadow (grass)
	[2] = "rbxassetid://78449218687433", -- Ember Rift (lava rock)
	[3] = "rbxassetid://104335708388109", -- Frostpeak (snow)
	[4] = "rbxassetid://123790088154148", -- Sky Sanctum (marble)
}

-- Creature XP for each break you helped with (crystals also scale with their size: a Giant gives 12)
Config.PetXP = { Crystal = 1, Chest = 6, Boss = 25 }

-- Hatching milestones: every At total hatches gives a guaranteed Rare+ creature (Mystic) plus extras.
-- Boost = a boost name from Config.Boosts for Seconds; Title shows up with your Season titles.
Config.HatchMilestones = {
	{ At = 100, Mystic = true, Trophies = 5 },
	{ At = 250, Mystic = true, Boost = "Luck", Seconds = 600 },
	{ At = 500, Mystic = true, Trophies = 15, Boost = "Shiny", Seconds = 600 },
	{ At = 1000, Mystic = true, Trophies = 25, Title = "Egg Master" },
	{ At = 2500, Mystic = true, Trophies = 50, Boost = "Luck", Seconds = 1800 },
	{ At = 5000, Mystic = true, Trophies = 100, Title = "Hatch Legend" },
}
Config.MilestoneFullStorageTrophies = 10 -- given instead of the creature if storage is full

-- Golden crystals: a rare crystal that glows gold and pays extra (rolled each time a crystal spawns)
Config.GoldenCrystal = { Chance = 0.03, Reward = 5 }

-- Lost Treasures: a glowing chest hidden in a realm; first to open it wins
Config.Treasure = {
	FirstDelay = { 60, 120 }, -- seconds after the server starts
	Interval = { 90, 180 }, -- seconds between treasures (after the last one ends)
	Lifetime = 120, -- seconds before it vanishes
	CrystalRewards = 25, -- Essence worth this many of that realm's crystals
	XP = 10, -- creature XP
	MysticChance = 0.15, -- chance of a bonus Rare+ creature
}

-- Big breakables: one Mana Chest per realm
Config.Chest = {
	HPMultiplier = 25,
	RewardMultiplier = 35,
	RespawnTime = 45,
}

-- Essence orbs that burst out of broken crystals (visual only; Essence is awarded on break)
Config.OrbsPerBreak = 6
Config.OrbsPerChest = 20

-- Creatures -----------------------------------------------------------------------
Config.BaseEquipSlots = 4
Config.MaxInventory = 150
Config.BestiaryBonusPerSpecies = 0.02 -- +2% Essence per species discovered
Config.IndexSetBonus = 0.1 -- +10% Essence for each egg whose whole set you've discovered

-- Rebirth -------------------------------------------------------------------------
Config.Rebirth = {
	BaseCost = 25000,
	CostGrowth = 3, -- cost = BaseCost * CostGrowth ^ rebirths
	MultiplierPerRebirth = 0.5, -- each rebirth adds +50% Essence
}

-- Offline earnings (idle-game hook) ---------------------------------------------
Config.Offline = {
	MaxHours = 8,
	Efficiency = 0.5, -- "virtual hits per second" your creatures make while you're away
	MinSeconds = 120, -- don't bother for very short absences
}

-- Mana Surge: the server-wide competitive round ----------------------------------
Config.Surge = {
	Interval = 240, -- seconds of downtime between surges
	Duration = 90,
	EssenceMultiplier = 2, -- everybody earns double during a surge
	TrophyRewards = { 5, 3, 2 }, -- 1st, 2nd, 3rd
	ParticipationTrophies = 1, -- anyone who scored at least something
	HousePointRewards = { 50, 30, 20 }, -- bonus points for your House
}

-- Houses: weekly cross-server faction war (inspired by PS99 clan battles) -------
Config.Houses = {
	DataStoreName = "MythicTamers_HouseWar_v1",
	FlushInterval = 60, -- seconds between pushing this server's points to the global total
	WeekEpochOffset = 4 * 86400, -- shifts the week boundary so weeks roll over on Monday 00:00 UTC
	WinnerTrophies = 10,
	ParticipantTrophies = 2,
	MinPointsForReward = 5,
}

-- Leaderboards --------------------------------------------------------------------
Config.Leaderboards = {
	TrophiesStore = "MythicTamers_Trophies_v1",
	EssenceStore = "MythicTamers_TotalEssence_v1",
	RefreshInterval = 90,
	Size = 10,
}

-- Weekly seasons (rewards are in Shared/Season.luau) --------------------------------
Config.Season = {
	FirstWeek = 2962, -- week index of Season 1 (week of 12 Oct 2026)
	StorePrefix = "MythicTamers_Season_v1_",
	BoardSize = 10,
}

-- Admins can run live events with chat commands (see AdminService) ---------------
-- The place owner is always an admin. Add extra UserIds here.
Config.AdminUserIds = {}

-- Studio testing: pretend you own every game pass while playtesting in Studio.
Config.StudioOwnsAllPasses = false

-- Monetization --------------------------------------------------------------------
-- Order controls the order in the shop.
Config.GamePasses = {
	{
		Key = "VIP",
		Id = 2036234466,
		Name = "VIP",
		Description = "+50% Essence, golden chat tag & VIP title",
		PriceHint = 199, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "DoubleEssence",
		Id = 2036564468,
		Name = "2x Essence",
		Description = "Double all Essence you earn, forever",
		PriceHint = 299, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "AutoCollect",
		Id = 2039582264,
		Name = "Auto Collect",
		Description = "Your creatures mine nearby crystals for you",
		PriceHint = 199, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "LuckyHatch",
		Id = 2039528282,
		Name = "Lucky Hatch",
		Description = "x1.5 chance for Rare+ creatures",
		PriceHint = 249, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "TripleHatch",
		Id = 2036828438,
		Name = "Triple Hatch",
		Description = "Hatch 3 eggs at once",
		PriceHint = 199, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "ExtraEquip",
		Id = 2037734445,
		Name = "+3 Creature Slots",
		Description = "Equip 3 more creatures",
		PriceHint = 349, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "LongerOffline",
		Id = 2036516467,
		Name = "Night Shift",
		Description = "Creatures gather offline for 24h instead of 8h",
		PriceHint = 99, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
}

Config.GamePassBonuses = {
	VIPEssence = 0.5,
	DoubleEssence = 2,
	LuckyHatchLuck = 1.5,
	ExtraEquipSlots = 3,
	LongerOfflineHours = 24,
}

Config.DevProducts = {
	{
		Key = "EssencePouch",
		Id = 3718616590,
		Name = "Essence Pouch",
		Description = "Instant Essence (scales with your best zone)",
		PriceHint = 49, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
		Grant = { Kind = "Essence", CrystalRewards = 40 },
	},
	{
		Key = "EssenceChest",
		Id = 3718616759,
		Name = "Essence Chest",
		Description = "A LOT of instant Essence",
		PriceHint = 249, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
		Grant = { Kind = "Essence", CrystalRewards = 500 },
	},
	{
		Key = "LuckPotion",
		Id = 3718616652,
		Name = "Luck Potion",
		Description = "x2 Rare+ odds for 15 minutes (stacks time)",
		PriceHint = 79, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
		Grant = { Kind = "Boost", Boost = "Luck", Seconds = 900 },
	},
	{
		Key = "MerchantRestock",
		Id = 3718616539,
		Name = "Merchant Restock",
		Description = "Refill your Wandering Merchant stock right now",
		PriceHint = 39, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
		Grant = { Kind = "MerchantRestock" },
	},
	{
		-- Robux-exclusive creature: featured at the top of the Shop. Can be bought more than once
		-- (5 copies fuse into a Shiny). Create a Developer Product and paste its ID here.
		Key = "NebulaKitsune",
		Id = 3718659889,
		Name = "Nebula Kitsune",
		Description = "Robux exclusive creature - never drops from eggs",
		PriceHint = 399, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "",
		Grant = { Kind = "Creature", Creature = "NebulaKitsune" },
	},
}

-- Sounds & music ------------------------------------------------------------------
-- Every sound has a built-in Roblox fallback, so the game is never silent. To use your own:
--   a) paste an audio asset id here, e.g. Hit = "rbxassetid://1234567", or
--   b) put a Sound named after the key (e.g. "MusicMeadow") anywhere in Workspace or in
--      ReplicatedStorage.GameSounds - the game picks it up automatically.
-- A realm without its own track uses MusicHub (or any other track you added).
Config.MusicBox = false -- true = play the generated music box where there's no track at all
Config.Sounds = {
	Hit = "",
	Break = "",
	ChestBreak = "",
	Orb = "",
	Click = "",
	EggShake = "",
	Reveal = "",
	RareReveal = "",
	Fanfare = "",
	MusicHub = "",
	MusicMeadow = "",
	MusicEmber = "",
	MusicFrost = "",
	MusicSky = "",
}

-- Boost strengths (from potions, merchant items, products) ----------------------
Config.Boosts = {
	Luck = 2,
	Essence = 2,
	Shiny = 3,
}

return Config
