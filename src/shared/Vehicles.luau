--[[
	Vehicles (built once at the Hangar on your Sanctuary island, kept forever). Ride one with the
	🛹 button (or R): you zoom about on a hoverboard in the hub, the forest's Edge and Midwood, and up on
	the islands. They switch off in the realms (so farming stays the same) and in the Deepwood.

	Cost = Gloom Crystals from your Vault + Essence worth that many crystals of your best realm.
	Speed = walk speed multiplier. Jump = jump power multiplier. Glide = slow falling.
	Seats = 2 means a passenger Seat on the back: anyone can sit on it and ride along with the driver.
	Skins are looks only (the Board Skins game pass unlocks the coloured ones).
]]

local Vehicles = {}

Vehicles.List = {
	{
		Id = "MossBoard",
		Name = "Moss Board",
		Icon = "🛹",
		Description = "Your first hoverboard. Zippy!",
		Color = Color3.fromRGB(110, 200, 110),
		Cost = { Moonshard = 10 },
		Essence = 20,
		Speed = 1.6,
		Jump = 1.1,
	},
	{
		Id = "CrystalBoard",
		Name = "Crystal Hoverboard",
		Icon = "💎",
		Description = "Glows in Stormquartz yellow. Very fast.",
		Color = Color3.fromRGB(255, 240, 120),
		Cost = { Stormquartz = 3, Voidstone = 1, Moonshard = 10 },
		Essence = 60,
		Speed = 2.0,
		Jump = 1.2,
	},
	{
		Id = "PrismGlider",
		Name = "Prism Glider",
		Icon = "🪁",
		Description = "Big jumps and floats gently down. Made from a Prismheart.",
		Color = Color3.fromRGB(255, 190, 255),
		Cost = { Prismheart = 1, Stormquartz = 4, Frostglass = 4 },
		Essence = 150,
		Speed = 1.8,
		Jump = 1.7,
		Glide = true,
	},
	-- a kart with a passenger seat on the back: a friend sits on it and rides along
	{
		Id = "MushroomKart",
		Name = "Mushroom Kart",
		Icon = "🏎️",
		Description = "A kart for two: bring a friend!",
		Color = Color3.fromRGB(230, 90, 90),
		Cost = { Emberheart = 6, Moonshard = 20 },
		Essence = 80,
		Speed = 1.9,
		Jump = 1,
		Seats = 2,
	},
}

-- Colours for the Board Skins pass (looks only); "Default" is the vehicle's own colour
Vehicles.Skins = {
	{ Id = "Default", Name = "Classic", Color = nil },
	{ Id = "Neon", Name = "Neon Pink", Color = Color3.fromRGB(255, 80, 200) },
	{ Id = "Ice", Name = "Ice Blue", Color = Color3.fromRGB(120, 220, 255) },
	{ Id = "Gold", Name = "Gold", Color = Color3.fromRGB(255, 200, 60) },
	{ Id = "Void", Name = "Void Purple", Color = Color3.fromRGB(120, 60, 200) },
}

Vehicles.BaseWalk = 16
Vehicles.BaseJump = 50

function Vehicles.Get(id: string): any
	for _, v in Vehicles.List do
		if v.Id == id then
			return v
		end
	end
	return nil
end

function Vehicles.GetSkin(id: string): any
	for _, s in Vehicles.Skins do
		if s.Id == id then
			return s
		end
	end
	return nil
end

function Vehicles.CanAfford(vault: { [string]: number }?, vehicle: any): boolean
	for id, n in vehicle.Cost do
		if ((vault or {})[id] or 0) < n then
			return false
		end
	end
	return true
end

return Vehicles
