--!strict
-- Timed-multiplier boosts triggered from the right-panel boost row.
-- Each boost has a `duration` (active window) and `cooldown` (time before
-- it can be re-activated; cooldown is total from activation, NOT additive
-- after duration). cooldown >= duration always.
--
-- Targets:
--   * "manual"  — multiplies only manual cycle revenue (stacks with click)
--   * "passive" — multiplies all cycle revenue (managed + manual)
--   * "offline" — multiplies offline-accrual amount; checked at re-entry
--
-- State per boost on the profile:
--   { activeUntil = number, cooldownUntil = number }
-- Both are os.time() (UNIX seconds) so they survive sessions correctly.

local Boosts = {}

export type Target = string -- "manual" | "passive" | "offline"

export type Definition = {
	id: string,
	name: string,
	description: string,
	icon: string,
	multiplier: number,
	duration: number,   -- seconds the boost is active
	cooldown: number,   -- seconds between activations (>= duration)
	target: Target,
}

Boosts.DEFINITIONS = {
	{
		id = "click",
		name = "Click Power",
		description = "5× click revenue",
		icon = "👆",
		multiplier = 5,
		duration = 15,
		cooldown = 60,
		target = "manual",
	},
	{
		id = "income",
		name = "Income Boost",
		description = "2× all income",
		icon = "💰",
		multiplier = 2,
		duration = 270,    -- 4:30
		cooldown = 900,    -- 15 min
		target = "passive",
	},
	{
		id = "offline",
		name = "Offline Earnings",
		description = "2× offline earnings",
		icon = "⏰",
		multiplier = 2,
		duration = 600,    -- 10 min
		cooldown = 1800,   -- 30 min
		target = "offline",
	},
} :: { Definition }

Boosts.BY_ID = {}
for _, def in ipairs(Boosts.DEFINITIONS) do
	Boosts.BY_ID[def.id] = def
end

local function stateOf(profile, id: string)
	local s = profile.boosts and profile.boosts[id]
	return s or { activeUntil = 0, cooldownUntil = 0 }
end

function Boosts.isActive(profile, id: string): boolean
	return stateOf(profile, id).activeUntil > os.time()
end

function Boosts.activeSecondsLeft(profile, id: string): number
	return math.max(0, stateOf(profile, id).activeUntil - os.time())
end

function Boosts.cooldownSecondsLeft(profile, id: string): number
	return math.max(0, stateOf(profile, id).cooldownUntil - os.time())
end

function Boosts.canActivate(profile, id: string): boolean
	return Boosts.cooldownSecondsLeft(profile, id) <= 0
end

-- Returns the buy-side state of a boost for the UI: "ready" | "active" | "cooldown".
function Boosts.uiState(profile, id: string): string
	if Boosts.isActive(profile, id) then return "active" end
	if Boosts.cooldownSecondsLeft(profile, id) > 0 then return "cooldown" end
	return "ready"
end

-- Combined active multipliers across all boosts. Stacks multiplicatively
-- if multiple boosts target the same channel (currently no overlap among
-- the three default boosts).
function Boosts.activeMultipliers(profile): { manual: number, passive: number, offline: number }
	local mult = { manual = 1, passive = 1, offline = 1 }
	for _, def in ipairs(Boosts.DEFINITIONS) do
		if Boosts.isActive(profile, def.id) then
			if def.target == "manual" then mult.manual *= def.multiplier
			elseif def.target == "passive" then mult.passive *= def.multiplier
			elseif def.target == "offline" then mult.offline *= def.multiplier
			end
		end
	end
	return mult
end

-- Returns the active boost with the longest remaining time, plus that
-- remaining time. Used by the right-panel "Active Boosts" card.
function Boosts.topActive(profile): (Definition?, number)
	local best: Definition? = nil
	local bestLeft = 0
	for _, def in ipairs(Boosts.DEFINITIONS) do
		local left = Boosts.activeSecondsLeft(profile, def.id)
		if left > bestLeft then
			best = def
			bestLeft = left
		end
	end
	return best, bestLeft
end

return Boosts
