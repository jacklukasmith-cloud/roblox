--[[
	Magical weather (inspired by Grow a Garden's weather events).

	The schedule is calculated from the clock with a fixed seed, so EVERY server shows the same
	weather at the same time - players can tell friends in other servers "Aurora is up!".
	Each slot is 10 minutes: an event runs for the first 3 minutes, then the sky clears.
]]

export type WeatherDef = {
	Id: string,
	Name: string,
	Description: string,
	Weight: number,
	Essence: number,
	Luck: number,
	Shiny: number,
	SkyTint: Color3,
}

local Weather = {}

Weather.Seed = 41_337
Weather.SlotLength = 600
Weather.EventLength = 180

local rgb = Color3.fromRGB

Weather.Types = {
	Clear = {
		Id = "Clear",
		Name = "Clear Skies",
		Description = "A calm day in the realm",
		Weight = 25,
		Essence = 1,
		Luck = 1,
		Shiny = 1,
		SkyTint = rgb(255, 255, 255),
	},
	Starfall = {
		Id = "Starfall",
		Name = "Starfall",
		Description = "+50% Essence from crystals",
		Weight = 30,
		Essence = 1.5,
		Luck = 1,
		Shiny = 1,
		SkyTint = rgb(200, 210, 255),
	},
	Aurora = {
		Id = "Aurora",
		Name = "Aurora",
		Description = "Shiny & Rainbow hatches x3 more likely",
		Weight = 25,
		Essence = 1,
		Luck = 1,
		Shiny = 3,
		SkyTint = rgb(170, 255, 220),
	},
	Eclipse = {
		Id = "Eclipse",
		Name = "Eclipse",
		Description = "x1.5 luck for Rare+ creatures",
		Weight = 15,
		Essence = 1,
		Luck = 1.5,
		Shiny = 1,
		SkyTint = rgb(255, 150, 120),
	},
	ManaStorm = {
		Id = "ManaStorm",
		Name = "Mana Storm",
		Description = "RARE! x2 Essence, x2 luck, x2 shiny",
		Weight = 5,
		Essence = 2,
		Luck = 2,
		Shiny = 2,
		SkyTint = rgb(210, 140, 255),
	},
} :: { [string]: WeatherDef }

Weather.Order = { "Clear", "Starfall", "Aurora", "Eclipse", "ManaStorm" }

local function rollSlot(slot: number): string
	local rng = Random.new(Weather.Seed + slot * 7919)
	local total = 0
	for _, id in Weather.Order do
		total += Weather.Types[id].Weight
	end
	local roll = rng:NextNumber() * total
	for _, id in Weather.Order do
		roll -= Weather.Types[id].Weight
		if roll <= 0 then
			return id
		end
	end
	return "Clear"
end

export type WeatherState = { Id: string, EndsAt: number, NextId: string, NextAt: number }

-- t is a unix time (os.time() on the server)
function Weather.GetState(t: number): WeatherState
	local slot = t // Weather.SlotLength
	local slotStart = slot * Weather.SlotLength
	local eventId = rollSlot(slot)
	local nextId = rollSlot(slot + 1)
	local nextAt = slotStart + Weather.SlotLength
	if t < slotStart + Weather.EventLength then
		return { Id = eventId, EndsAt = slotStart + Weather.EventLength, NextId = nextId, NextAt = nextAt }
	end
	return { Id = "Clear", EndsAt = nextAt, NextId = nextId, NextAt = nextAt }
end

return Weather
