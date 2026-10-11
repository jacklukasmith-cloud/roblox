--[[ Number / time formatting shared by server and client. ]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(text: string): string
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

-- 1234 -> "1.23K", 5600000 -> "5.6M"
function Format.Number(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text
	if n >= 100 then
		text = tostring(math.floor(n))
	elseif n >= 10 then
		text = trimZeros(string.format("%.1f", math.floor(n * 10) / 10))
	else
		text = trimZeros(string.format("%.2f", math.floor(n * 100) / 100))
	end
	return sign .. text .. SUFFIXES[index]
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Format.Percent(chance: number): string
	local pct = chance * 100
	if pct >= 10 then
		return string.format("%d%%", math.floor(pct + 0.5))
	elseif pct >= 1 then
		return trimZeros(string.format("%.1f", pct)) .. "%"
	end
	return trimZeros(string.format("%.3f", pct)) .. "%"
end

return Format
