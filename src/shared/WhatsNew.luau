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
		Text = "A huge foggy forest (needs Frostpeak). Mine Gloom Crystals, watch out for wolves, foxes, bats and sleeping guardians, and send them home before the gloom gets you!",
	},
	{
		Icon = "⬆️",
		Title = "Island levels",
		Text = "Upgrade your island at its Upgrade Stone: it grows and gives more Essence.",
	},
	{
		Icon = "🐾",
		Title = "Pet Habitat",
		Text = "Pets you put on your island wander around and earn XP, even while you're offline.",
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
