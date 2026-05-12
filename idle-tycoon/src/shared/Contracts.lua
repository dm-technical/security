--!strict
-- Mission contracts: three rolling slots of one-shot objectives the player
-- completes through normal gameplay and claims for funds + science rewards.
-- Procedurally generated based on current profile state, so contracts
-- always feel "just out of reach" rather than trivially completed.
--
-- All three slots persist across sessions; on claim, the server credits
-- rewards and rerolls that slot. Progress is computed as
-- (current_metric - baseline_at_acceptance), so values that change between
-- sessions still measure correctly.

local Shared = script.Parent
local Format = require(Shared.Format)

local Contracts = {}

export type Slot = {
	objective: string, -- "funds" | "science" | "clicks"
	target: number,
	baseline: number,
	rewardFunds: number,
	rewardScience: number,
	title: string,
	description: string,
	issuedAt: number,
}

export type Metrics = {
	totalEarned: number,
	gems: number,
	totalClicks: number,
}

-- A funds contract: earn $X in funds. Scales with totalEarned so the
-- target is always ~10% of lifetime earnings (with a floor for new players).
local function rollFunds(profile): Slot
	local total = profile.totalEarned or 0
	local target = math.max(500, total * 0.10)
	-- Round to two significant figures so the number reads cleanly.
	target = math.ceil(target)
	return {
		objective = "funds",
		target = target,
		baseline = total,
		rewardFunds = math.floor(target * 0.5),
		rewardScience = math.max(5, math.floor(target * 0.001)),
		title = "Earn " .. Format.money(target),
		description = "Generate funds from missions",
		issuedAt = os.time(),
	}
end

-- A science contract: target = 50% of current science. Reward is funds
-- (no recursion into science to keep the loop bounded).
local function rollScience(profile): Slot
	local total = profile.gems or 0
	local target = math.max(50, math.ceil(total * 0.50))
	return {
		objective = "science",
		target = target,
		baseline = total,
		rewardFunds = target * 10,
		rewardScience = 0,
		title = "Generate " .. Format.short(target) .. " science",
		description = "Earn science from mission cycles",
		issuedAt = os.time(),
	}
end

-- A clicks contract: rewards rolled per-player based on totalClicks. A
-- fresh player can complete this in a couple of taps; mid-game it scales
-- to keep it feeling earned rather than trivial.
local function rollClicks(profile): Slot
	local total = profile.totalClicks or 0
	local target = math.max(20, math.ceil(total * 0.05))
	return {
		objective = "clicks",
		target = target,
		baseline = total,
		rewardFunds = target * 100,
		rewardScience = math.max(5, math.floor(target * 0.1)),
		title = "Manually launch " .. tostring(target) .. " missions",
		description = "Tap to launch missions",
		issuedAt = os.time(),
	}
end

-- Roll a single contract by uniform-random template choice.
function Contracts.roll(profile): Slot
	local rolls = { rollFunds, rollScience, rollClicks }
	return rolls[math.random(1, #rolls)](profile)
end

-- Pull the metric value the slot's objective tracks.
local function metricFor(slot: Slot, metrics: Metrics): number
	if slot.objective == "funds" then
		return metrics.totalEarned or 0
	elseif slot.objective == "science" then
		return metrics.gems or 0
	elseif slot.objective == "clicks" then
		return metrics.totalClicks or 0
	end
	return 0
end

-- Progress amount toward the contract target. Clamped to >= 0 so accidental
-- baseline > current (shouldn't happen, but be defensive) doesn't go negative.
function Contracts.progress(slot: Slot, metrics: Metrics): number
	return math.max(0, metricFor(slot, metrics) - slot.baseline)
end

-- True iff the player has done enough to claim this contract.
function Contracts.complete(slot: Slot, metrics: Metrics): boolean
	return Contracts.progress(slot, metrics) >= slot.target
end

-- Fraction [0, 1] used by the progress bar.
function Contracts.progressFraction(slot: Slot, metrics: Metrics): number
	if slot.target <= 0 then return 1 end
	return math.min(1, Contracts.progress(slot, metrics) / slot.target)
end

return Contracts
