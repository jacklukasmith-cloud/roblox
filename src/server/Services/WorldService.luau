--[[
	Global "live ops" state: weather and the merchant timer.
	Both come from the clock, so every server agrees. Admins can override the weather
	across ALL servers via AdminService (MessagingService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Weather = require(ReplicatedStorage.Shared.Weather)
local Events = require(ReplicatedStorage.Shared.Events)
local Merchant = require(ReplicatedStorage.Shared.Merchant)

local WorldService = {}

local override: { Id: string, EndsAt: number }? = nil

function WorldService.GetWeather(): Weather.WeatherState
	local now = os.time()
	local scheduled = Weather.GetState(now)
	if override and now < override.EndsAt then
		return { Id = override.Id, EndsAt = override.EndsAt, NextId = scheduled.NextId, NextAt = scheduled.NextAt }
	end
	return scheduled
end

function WorldService.GetWeatherDef(): Weather.WeatherDef
	return Weather.Types[WorldService.GetWeather().Id] or Weather.Types.Clear
end

function WorldService.SetOverride(id: string, endsAt: number)
	if Weather.Types[id] then
		override = { Id = id, EndsAt = endsAt }
	end
end

-- Weekend events (Shared/Events), with an admin override
local eventOverride: { Id: string, EndsAt: number }? = nil

function WorldService.GetEvent(): Events.EventState
	local now = os.time()
	local scheduled = Events.GetState(now)
	if eventOverride and now < eventOverride.EndsAt then
		return {
			Id = eventOverride.Id,
			EndsAt = eventOverride.EndsAt,
			NextId = scheduled.NextId,
			NextAt = scheduled.NextAt,
		}
	end
	return scheduled
end

function WorldService.GetEventDef(): Events.EventDef
	return Events.Get(WorldService.GetEvent().Id) or Events.None
end

function WorldService.SetEventOverride(id: string, endsAt: number): boolean
	if not Events.Get(id) then
		return false
	end
	eventOverride = { Id = id, EndsAt = endsAt }
	return true
end

function WorldService.GetMerchant()
	local now = os.time()
	local slot = Merchant.GetSlot(now)
	return { Slot = slot, Stock = Merchant.GetStock(slot), NextRestockAt = Merchant.NextRestockAt(now) }
end

-- Server-side sky tint so the weather is visible for everyone
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Haze = 1
atmosphere.Parent = Lighting
task.spawn(function()
	while true do
		local def = WorldService.GetWeatherDef()
		atmosphere.Color = def.SkyTint
		atmosphere.Decay = def.SkyTint:Lerp(Color3.new(0, 0, 0), 0.4)
		atmosphere.Glare = if def.Id == "Clear" then 0 else 2
		task.wait(2)
	end
end)

return WorldService
