--!strict
-- Idle-game style number formatting: 1.23K, 4.56M, 7.89B, 1.23aa, ...
-- After standard suffixes we use double-letter suffixes (aa, ab, ac, ...).

local Format = {}

local SHORT_SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
}

-- Generate aa..zz lazily; suitable up to ~10^81 just from this.
local LETTER_SUFFIXES: { string } = {}
local function letterSuffix(index: number): string
	if LETTER_SUFFIXES[index] then
		return LETTER_SUFFIXES[index]
	end
	local n = index - 1
	local first = math.floor(n / 26)
	local second = n % 26
	local s = string.char(97 + first) .. string.char(97 + second)
	LETTER_SUFFIXES[index] = s
	return s
end

-- Format a positive number with a short suffix and 2 decimal places of precision.
function Format.short(n: number): string
	if n ~= n then return "NaN" end
	if n == math.huge then return "∞" end
	if n < 0 then return "-" .. Format.short(-n) end
	if n < 1000 then
		-- Whole numbers under 1000 stay clean.
		if n == math.floor(n) then
			return tostring(math.floor(n))
		end
		return string.format("%.2f", n)
	end

	local exp = math.floor(math.log10(n) / 3)
	local suffix
	if exp < #SHORT_SUFFIXES then
		suffix = SHORT_SUFFIXES[exp + 1]
	else
		suffix = letterSuffix(exp - #SHORT_SUFFIXES + 1)
	end

	local mantissa = n / (10 ^ (exp * 3))
	-- Trim to 3 significant digits visually (e.g. 1.23, 12.3, 123).
	if mantissa >= 100 then
		return string.format("%.0f%s", mantissa, suffix)
	elseif mantissa >= 10 then
		return string.format("%.1f%s", mantissa, suffix)
	else
		return string.format("%.2f%s", mantissa, suffix)
	end
end

-- Format money with a leading $.
function Format.money(n: number): string
	return "$" .. Format.short(n)
end

-- HH:MM:SS for cycle countdowns.
function Format.duration(seconds: number): string
	if seconds == math.huge then return "∞" end
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return string.format("%ds", seconds)
	elseif seconds < 3600 then
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
	else
		local h = math.floor(seconds / 3600)
		local m = math.floor((seconds % 3600) / 60)
		local s = seconds % 60
		return string.format("%d:%02d:%02d", h, m, s)
	end
end

return Format
