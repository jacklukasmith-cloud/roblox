--[[
	Houses: a weekly faction war across ALL servers (a simpler take on PS99 clan battles).
	Players pledge to a House; crystal breaks and Mana Surge placements earn House points.
	When the week ends, members of the winning House get Trophies.
]]

local Houses = {}

local rgb = Color3.fromRGB

Houses.Order = { "Emberclaw", "Frostfang", "Stormwing" }

Houses.List = {
	Emberclaw = { Id = "Emberclaw", Name = "House Emberclaw", Motto = "Burn bright.", Color = rgb(255, 95, 50) },
	Frostfang = { Id = "Frostfang", Name = "House Frostfang", Motto = "Never melt.", Color = rgb(90, 190, 255) },
	Stormwing = { Id = "Stormwing", Name = "House Stormwing", Motto = "Ride the storm.", Color = rgb(250, 215, 70) },
}

function Houses.Get(id: string?)
	return if id then Houses.List[id] else nil
end

-- Week number used to key House War results. offset shifts the rollover day.
function Houses.GetWeek(t: number, offset: number): number
	return (t - offset) // 604800
end

function Houses.WeekEndsAt(week: number, offset: number): number
	return (week + 1) * 604800 + offset
end

return Houses
