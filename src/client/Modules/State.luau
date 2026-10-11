--[[ Client-side copy of what the server tells us, with a change signal. ]]

local State = {
	Data = nil :: any, -- player snapshot (see Economy.BuildSnapshot)
	World = nil :: any, -- weather / merchant / house war
	Surge = nil :: any, -- Mana Surge state
	PotatoMode = false,
}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event -- (key)

function State.Set(key: string, value: any)
	(State :: any)[key] = value
	changed:Fire(key)
end

-- Server times are unix seconds; this is the synced server clock.
function State.Now(): number
	return workspace:GetServerTimeNow()
end

return State
