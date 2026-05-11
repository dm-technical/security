--!strict
-- Prestige tuning. Reset money/businesses/upgrades in exchange for a
-- permanent global revenue multiplier; achievements + gems + lifetime
-- totals are preserved. Pure helpers; called by both server and client.
--
-- Curve:
--   * Multiplier per prestige level: +20% (multiplicative, so level 10 ≈ ×6.19)
--   * Per-run requirement to advance from level N to N+1: $1M × 10^N
--       level 0 → 1: earn $1M this run
--       level 1 → 2: earn $10M this run
--       level 2 → 3: earn $100M this run
--       ... etc

local Prestige = {}

local BONUS_PER_LEVEL = 0.20
local FIRST_REQUIREMENT = 1_000_000
local REQUIREMENT_GROWTH = 10

-- Amount you must earn THIS run (since last prestige) to advance from `level`.
function Prestige.requirementFor(level: number): number
	return FIRST_REQUIREMENT * (REQUIREMENT_GROWTH ^ level)
end

-- Global revenue multiplier from being at `level`.
function Prestige.multiplierFor(level: number): number
	return 1 + BONUS_PER_LEVEL * level
end

-- Cumulative earnings since the last prestige (or since profile creation
-- if the player has never prestiged).
function Prestige.earnedThisRun(profile): number
	local lifetime = profile.totalEarned or 0
	local atLastPrestige = profile.totalEarnedAtLastPrestige or 0
	return math.max(0, lifetime - atLastPrestige)
end

-- True iff the player has earned enough this run to advance.
function Prestige.canPrestige(profile): boolean
	local level = profile.prestige or 0
	return Prestige.earnedThisRun(profile) >= Prestige.requirementFor(level)
end

-- Fraction [0, 1] of progress toward the next prestige threshold.
function Prestige.progress(profile): number
	local level = profile.prestige or 0
	local need = Prestige.requirementFor(level)
	if need <= 0 then return 1 end
	return math.min(1, Prestige.earnedThisRun(profile) / need)
end

-- Human-readable percentage bonus, e.g. "+20%".
function Prestige.bonusText(level: number): string
	return string.format("+%d%%", math.floor(BONUS_PER_LEVEL * level * 100 + 0.5))
end

return Prestige
