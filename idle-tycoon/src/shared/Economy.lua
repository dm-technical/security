--!strict
-- Pure economy math shared by client and server.
-- Keeping it deterministic and stateless lets the client preview costs
-- and revenue without round-tripping to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Economy = {}

-- Cost of the Nth additional unit (0-indexed: cost(0) is the first unit).
function Economy.unitCost(def: Config.BusinessDef, ownedBefore: number): number
	return def.baseCost * (def.costMultiplier ^ ownedBefore)
end

-- Cost to buy `qty` more units when the player already owns `owned`.
-- Geometric series: baseCost * mult^owned * (mult^qty - 1) / (mult - 1).
function Economy.bulkCost(def: Config.BusinessDef, owned: number, qty: number): number
	if qty <= 0 then return 0 end
	local m = def.costMultiplier
	local first = def.baseCost * (m ^ owned)
	if math.abs(m - 1) < 1e-9 then
		return first * qty
	end
	return first * ((m ^ qty) - 1) / (m - 1)
end

-- How many units the player can afford with `money` on top of `owned`.
-- Closed-form inversion of bulkCost.
function Economy.maxAffordable(def: Config.BusinessDef, owned: number, money: number): number
	if money <= 0 then return 0 end
	local m = def.costMultiplier
	local first = def.baseCost * (m ^ owned)
	if first > money then return 0 end
	if math.abs(m - 1) < 1e-9 then
		return math.floor(money / first)
	end
	-- money >= first * (m^q - 1) / (m - 1)
	-- => q <= log(1 + money * (m-1) / first) / log(m)
	local q = math.log(1 + money * (m - 1) / first) / math.log(m)
	return math.max(0, math.floor(q))
end

-- Milestone revenue multiplier from owning `owned` units of one business.
function Economy.milestoneMultiplier(owned: number): number
	local mult = 1
	for _, ms in ipairs(Config.MILESTONES) do
		if owned >= ms.level then
			mult *= ms.multiplier
		end
	end
	return mult
end

-- Revenue produced by one full cycle at this ownership level.
function Economy.cyclePayout(def: Config.BusinessDef, owned: number, globalMult: number): number
	if owned <= 0 then return 0 end
	return def.baseRevenue * owned * Economy.milestoneMultiplier(owned) * globalMult
end

-- Science produced by one full cycle at this ownership level. Same scaling
-- as cyclePayout (owned × milestone × global) but using the def's smaller
-- cycleScience base so funds outpace science roughly 10:1.
function Economy.cycleScience(def: Config.BusinessDef, owned: number, globalMult: number): number
	if owned <= 0 then return 0 end
	return (def.cycleScience or 0) * owned * Economy.milestoneMultiplier(owned) * globalMult
end

-- Steady-state science per second (used for offline accrual and rate displays).
function Economy.sciencePerSecond(def: Config.BusinessDef, owned: number, globalMult: number): number
	if owned <= 0 or def.cycleTime <= 0 then return 0 end
	return Economy.cycleScience(def, owned, globalMult) / def.cycleTime
end

-- Steady-state revenue per second (used for offline accrual and DPS displays).
function Economy.revenuePerSecond(def: Config.BusinessDef, owned: number, globalMult: number): number
	if owned <= 0 or def.cycleTime <= 0 then return 0 end
	return Economy.cyclePayout(def, owned, globalMult) / def.cycleTime
end

return Economy
