-- Number formatting: 999.9, 1.23K, 4.56M ... 7.89Dc, then 1.23e36
local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.number(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	if n < 1000 then
		local s = string.format("%.1f", math.floor(n * 10) / 10)
		return sign .. (s:gsub("%.0$", ""))
	end
	local tier = math.floor(math.log10(n) / 3)
	local value = n / 10 ^ (tier * 3)
	-- log10 can land a hair off at exact powers of 1000
	if value >= 1000 then
		tier += 1
		value /= 1000
	elseif value < 1 then
		tier -= 1
		value *= 1000
	end
	if tier > #SUFFIXES then
		return sign .. (string.format("%.2e", n):gsub("e%+?", "e"))
	end
	-- floor, not round, so 999.999K never shows as 1000.00K
	return sign .. string.format("%.2f", math.floor(value * 100) / 100) .. SUFFIXES[tier]
end

return Format
