--[[
	Weekend events: from Saturday 00:00 UTC to Monday 00:00 UTC one event is on, the same in every
	server (picked from the week number, so it rotates). The HUD counts down to the next one all week.

	Essence / Luck / Shiny = multipliers on the usual ones. EggDiscount = egg price multiplier.
	GloomDrops = extra Gloom Crystals per crystal mined (2 = every crystal gives two).
	Admins can start any event early with !event <Id> <minutes>.
]]

local Events = {}

export type EventDef = {
	Id: string,
	Name: string,
	Icon: string,
	Description: string,
	Color: Color3,
	Essence: number,
	Luck: number,
	Shiny: number,
	EggDiscount: number,
	GloomDrops: number,
}

local rgb = Color3.fromRGB

local function def(t: { [string]: any }): EventDef
	t.Essence = t.Essence or 1
	t.Luck = t.Luck or 1
	t.Shiny = t.Shiny or 1
	t.EggDiscount = t.EggDiscount or 1
	t.GloomDrops = t.GloomDrops or 1
	return t :: EventDef
end

Events.List = {
	def({
		Id = "DoubleEssence",
		Name = "Double Essence Weekend",
		Icon = "💎",
		Description = "x2 Essence from everything",
		Color = rgb(120, 255, 200),
		Essence = 2,
	}),
	def({
		Id = "LuckyWeekend",
		Name = "Lucky Weekend",
		Icon = "🍀",
		Description = "x2 luck on every egg",
		Color = rgb(150, 255, 150),
		Luck = 2,
	}),
	def({
		Id = "HatchFest",
		Name = "Hatch Fest",
		Icon = "🥚",
		Description = "Eggs cost 25% less",
		Color = rgb(255, 200, 120),
		EggDiscount = 0.75,
	}),
	def({
		Id = "GloomRush",
		Name = "Gloom Rush",
		Icon = "🌲",
		Description = "Every Gloom Crystal you mine gives two",
		Color = rgb(180, 140, 255),
		GloomDrops = 2,
	}),
	def({
		Id = "ShinyWeekend",
		Name = "Shiny Weekend",
		Icon = "✨",
		Description = "x2 Shiny and Rainbow hatches",
		Color = rgb(255, 240, 150),
		Shiny = 2,
	}),
}

Events.None = def({ Id = "None", Name = "No event", Icon = "", Description = "", Color = Color3.new(1, 1, 1) })

local DAY = 86400
local WEEK = 7 * DAY
-- Unix time 0 was a Thursday; the Saturday after it starts at day 2
local FIRST_SATURDAY = 2 * DAY

function Events.Get(id: string): EventDef?
	for _, e in Events.List do
		if e.Id == id then
			return e
		end
	end
	return nil
end

-- Start of the weekend (Saturday 00:00 UTC) that contains or follows t, and which event it is
local function weekendFor(t: number): (number, EventDef)
	local n = (t - FIRST_SATURDAY) // WEEK
	local start = FIRST_SATURDAY + n * WEEK
	return start, Events.List[(n % #Events.List) + 1]
end

export type EventState = { Id: string, EndsAt: number, NextId: string, NextAt: number }

-- t is a unix time (os.time())
function Events.GetState(t: number): EventState
	local start, event = weekendFor(t)
	local endsAt = start + 2 * DAY
	local nextStart, nextEvent = weekendFor(start + WEEK)
	if t < endsAt then
		return { Id = event.Id, EndsAt = endsAt, NextId = nextEvent.Id, NextAt = nextStart }
	end
	return { Id = "None", EndsAt = nextStart, NextId = nextEvent.Id, NextAt = nextStart }
end

return Events
