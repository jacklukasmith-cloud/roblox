--[[
	The "What's New" pop-up players see once after each update (and can reopen from Settings).
	For a new update: bump Version and replace the list. The save remembers the last one seen.
]]

local WhatsNew = {}

WhatsNew.Version = 1
WhatsNew.Title = "The Sanctuary Update!"

WhatsNew.List = {
	{
		Icon = "🏝️",
		Title = "Your own Sanctuary",
		Text = "A floating sky island just for you. Step into the Sanctuary portal or press 🏠.",
	},
	{
		Icon = "🌲",
		Title = "The Gloomwood",
		Text = "A huge foggy forest (needs Frostpeak). Mine Gloom Crystals, dodge the animals, find Map Fragments, and brave the Deepwood and the Heart for the Prismheart!",
	},
	{
		Icon = "⬆️",
		Title = "Island levels",
		Text = "Upgrade your island at its Upgrade Stone: it grows and gives more Essence.",
	},
	{
		Icon = "⚗️",
		Title = "Alchemy Cauldron",
		Text = "Brew potions on your island from the Gloom Crystals in your Vault. They brew even while you're away!",
	},
	{
		Icon = "🐾",
		Title = "Pet Habitat",
		Text = "Pets you put on your island wander around and earn XP, even while you're offline.",
	},
	{
		Icon = "🎡",
		Title = "Spin Wheel",
		Text = "A free spin every 4 hours in the top corner. Land on the 🥚 for a Mystic Egg!",
	},
	{
		Icon = "🧰",
		Title = "Island chest",
		Text = "A treasure chest on your island opens once a day. Higher island levels give better loot.",
	},
	{
		Icon = "🏜️",
		Title = "Two new realms",
		Text = "The Starfall Desert (after 1 Rebirth) and the Void Abyss (after 3) wait past Sky Sanctum, with 12 new creatures.",
	},
	{
		Icon = "🐘",
		Title = "HUGE pets",
		Text = "A 1 in 50,000 chance on every egg: a giant version with x12 power. The whole game hears about it.",
	},
	{
		Icon = "🎉",
		Title = "Weekend events",
		Text = "Every weekend something's on: Double Essence, Lucky, Hatch Fest, Gloom Rush or Shiny. The HUD counts down.",
	},
	{
		Icon = "❤️",
		Title = "Like islands",
		Text = "Visit friends' islands over the Sky Plaza and hold E on their heart sign. Weekly Most Liked board!",
	},
	{
		Icon = "🏠",
		Title = "Teleport crystals",
		Text = "Brew Home, Gloom and Camp Crystals at your Cauldron and warp there from your Bag.",
	},
	{
		Icon = "🏎️",
		Title = "Mushroom Kart",
		Text = "Build a kart at your Hangar with a seat on the back for a friend.",
	},
	{ Icon = "🎯", Title = "Missions", Text = "Follow the mission card under the menu for rewards." },
	{
		Icon = "🎒",
		Title = "The Bag",
		Text = "Potions, gifts and treasure maps go into your Bag. Use them any time.",
	},
	{ Icon = "🤝", Title = "Trading", Text = "Swap creatures and items with other players." },
	{ Icon = "🎟️", Title = "Codes", Text = "Type codes in ⚙️ Settings for free rewards. Try RELEASE!" },
	{ Icon = "👥", Title = "Friend Boost", Text = "+5% Essence for every friend in your server (up to 3)." },
	{ Icon = "🏆", Title = "New leaderboards", Text = "Global, friends and weekly boards. Can you make the top 50?" },
	{ Icon = "🏛️", Title = "A bigger hub", Text = "The Merchant has a shop circle now, next to the Blacksmith." },
}

return WhatsNew
