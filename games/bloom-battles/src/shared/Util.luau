--[[
	Shared helpers: number formatting, tiers, zones and costs.
]]

local Config = require(script.Parent.Config)

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Util.Format(n: number): string
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local i = 1
	local v = n
	while v >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local text = if v >= 100 then string.format("%d", math.floor(v)) else string.format("%.1f", math.floor(v * 10) / 10)
	text = string.gsub(text, "%.0$", "")
	return text .. SUFFIXES[i]
end

-- Like Format, but keeps one decimal for small non-whole numbers (+1.5/s).
function Util.FormatGain(n: number): string
	if n < 100 and math.abs(n - math.floor(n)) > 0.05 then
		return string.format("%.1f", n)
	end
	return Util.Format(n)
end

function Util.TierIndex(bloom: number): number
	local index = 1
	for i, tier in Config.Tiers do
		if bloom >= tier.Need then
			index = i
		end
	end
	return index
end

function Util.Tier(bloom: number)
	return Config.Tiers[Util.TierIndex(bloom)]
end

function Util.ZoneAt(z: number): number
	return math.clamp(math.floor(z / Config.ZoneLength) + 1, 1, #Config.Zones)
end

function Util.ReplantCost(rebirths: number): number
	return Config.ReplantBaseCost * Config.ReplantCostGrowth ^ rebirths
end

function Util.ReplantMultiplier(rebirths: number): number
	return 1 + rebirths * Config.ReplantBonus
end

function Util.ScaleFor(bloom: number): number
	local s = 1 + math.log10(math.max(bloom, 0) + 1) * Config.ScalePerDecade
	return math.min(s, Config.MaxScale)
end

function Util.Strength(bloom: number): number
	return (math.max(bloom, 0) + 10) ^ Config.Duel.StrengthPower
end

return Util
