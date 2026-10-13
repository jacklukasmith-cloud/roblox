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
Config.PetAttackInterval = 0.5 -- seconds between creature attack ticks
Config.PetDamageMultiplier = 1.5 -- damage per tick = Power * this
Config.MaxHitDistance = 45 -- studs from character to crystal when choosing a target
Config.MaxAttackDistance = 70 -- creatures give up if you walk further than this away
Config.CrystalRespawnTime = 4
Config.AutoCollectRange = 40 -- Auto Collect pass: auto-targets the nearest crystal within this range
Config.StarterCreature = "GlowSprite" -- every new player gets one, so they can farm straight away

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
		Id = 0,
		Name = "VIP",
		Description = "+50% Essence, golden chat tag & VIP title",
		PriceHint = 199, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "DoubleEssence",
		Id = 0,
		Name = "2x Essence",
		Description = "Double all Essence you earn, forever",
		PriceHint = 299, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "AutoCollect",
		Id = 0,
		Name = "Auto Collect",
		Description = "Your creatures mine nearby crystals for you",
		PriceHint = 149, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "LuckyHatch",
		Id = 0,
		Name = "Lucky Hatch",
		Description = "x1.5 chance for Rare+ creatures",
		PriceHint = 249, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "TripleHatch",
		Id = 0,
		Name = "Triple Hatch",
		Description = "Hatch 3 eggs at once",
		PriceHint = 199, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "ExtraEquip",
		Id = 0,
		Name = "+3 Creature Slots",
		Description = "Equip 3 more creatures",
		PriceHint = 349, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
	},
	{
		Key = "LongerOffline",
		Id = 0,
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
		Id = 0,
		Name = "Essence Pouch",
		Description = "Instant Essence (scales with your best zone)",
		PriceHint = 49, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
		Grant = { Kind = "Essence", CrystalRewards = 40 },
	},
	{
		Key = "EssenceChest",
		Id = 0,
		Name = "Essence Chest",
		Description = "A LOT of instant Essence",
		PriceHint = 249, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
		Grant = { Kind = "Essence", CrystalRewards = 300 },
	},
	{
		Key = "LuckPotion",
		Id = 0,
		Name = "Luck Potion",
		Description = "x2 Rare+ odds for 15 minutes (stacks time)",
		PriceHint = 79, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
		Grant = { Kind = "Boost", Boost = "Luck", Seconds = 900 },
	},
	{
		Key = "MerchantRestock",
		Id = 0,
		Name = "Merchant Restock",
		Description = "Refill your Wandering Merchant stock right now",
		PriceHint = 39, -- shown in the shop UI; set the real price on the Creator Hub
		Icon = "", -- optional "rbxassetid://..." after uploading the icon
		Grant = { Kind = "MerchantRestock" },
	},
}

-- Boost strengths (from potions, merchant items, products) ----------------------
Config.Boosts = {
	Luck = 2,
	Essence = 2,
	Shiny = 3,
}

return Config
