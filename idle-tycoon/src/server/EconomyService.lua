--!strict
-- Authoritative economy: handles purchases, manager hires, manual collects,
-- and ticks automated businesses. All money mutations flow through here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Upgrades = require(Shared.Upgrades)
local Prestige = require(Shared.Prestige)
local Boosts = require(Shared.Boosts)
local Contracts = require(Shared.Contracts)
local Shop = require(Shared.Shop)
local Tutorial = require(Shared.Tutorial)

local DataService = require(script.Parent.DataService)

local EconomyService = {}

-- Per-business state lives on the player's profile; we just normalize access.
local function getOrInitBusiness(profile, id: string)
	local b = profile.businesses[id]
	if not b then
		b = { owned = 0, hasManager = false, progress = 0 }
		profile.businesses[id] = b
	end
	return b
end

-- Seed a new player's profile with starting cash.
function EconomyService.initProfile(profile)
	if profile.money == 0 and profile.totalEarned == 0 then
		profile.money = Config.STARTING_MONEY
	end
	for _, def in ipairs(Config.BUSINESSES) do
		getOrInitBusiness(profile, def.id)
	end
end

-- Compute offline accrual since lastOnline. Only automated businesses earn.
-- Returns { amount, seconds } where amount is what was added to the wallet.
function EconomyService.applyOfflineProgress(profile): (number, number)
	local now = os.time()
	local elapsed = math.max(0, now - (profile.lastOnline or now))
	local capped = math.min(elapsed, Config.MAX_OFFLINE_SECONDS)
	if capped <= 0 then
		return 0, 0
	end

	local prestigeMult = Prestige.multiplierFor(profile.prestige or 0)
	local scienceMult = Upgrades.scienceYieldMultiplier(profile)
	local total = 0
	local totalScience = 0
	for _, def in ipairs(Config.BUSINESSES) do
		local b = profile.businesses[def.id]
		if b and b.owned > 0 and b.hasManager then
			local mult = Upgrades.multiplierFor(profile, def.id) * prestigeMult
			total += Economy.revenuePerSecond(def, b.owned, mult) * capped
			totalScience += Economy.sciencePerSecond(def, b.owned, mult * scienceMult) * capped
		end
	end
	total *= Config.OFFLINE_EARN_RATE
	totalScience *= Config.OFFLINE_EARN_RATE

	-- Offline Earnings boost: if the boost was still active at the moment
	-- the player went offline, apply its multiplier to the whole window for
	-- BOTH currencies (funds + science).
	local offlineState = profile.boosts and profile.boosts["offline"]
	if offlineState and offlineState.activeUntil > (profile.lastOnline or now) then
		local boostDef = Boosts.BY_ID["offline"]
		if boostDef then
			total *= boostDef.multiplier
			totalScience *= boostDef.multiplier
		end
	end

	if total > 0 then
		profile.money += total
		profile.totalEarned += total
	end
	if totalScience > 0 then
		profile.gems = (profile.gems or 0) + totalScience
	end
	return total, capped
end

-- Tick a single business by `dt` seconds. Returns (fundsPayout, sciencePayout)
-- so the outer loop can accumulate both currencies before crediting once.
-- Both scale by the same multiplier composition: upgrades × prestige × boosts
-- (passive on managed/manual, plus click on manual cycles).
local function tickBusiness(profile, def: Config.BusinessDef, dt: number): (number, number)
	local b = profile.businesses[def.id]
	if not b or b.owned <= 0 then return 0, 0 end

	local prestigeMult = Prestige.multiplierFor(profile.prestige or 0)
	local boostMult = Boosts.activeMultipliers(profile)
	-- Income Boost (target="passive") stacks on every cycle, managed or manual.
	local baseMult = Upgrades.multiplierFor(profile, def.id) * prestigeMult * boostMult.passive
	-- Click Power (target="manual") only stacks on manually-tapped cycles.
	local clickMult = Upgrades.clickMultiplier(profile) * boostMult.manual
	-- Science yield: global_science research scales cycleScience but not funds.
	local scienceMult = Upgrades.scienceYieldMultiplier(profile)

	local payout = 0
	local science = 0
	if b.hasManager then
		b.progress += dt
		while b.progress >= def.cycleTime do
			b.progress -= def.cycleTime
			payout += Economy.cyclePayout(def, b.owned, baseMult)
			science += Economy.cycleScience(def, b.owned, baseMult * scienceMult)
		end
	else
		if b.progress > 0 and b.progress < def.cycleTime then
			b.progress = math.min(def.cycleTime, b.progress + dt)
			if b.progress >= def.cycleTime then
				b.progress = 0
				payout = Economy.cyclePayout(def, b.owned, baseMult * clickMult)
				science = Economy.cycleScience(def, b.owned, baseMult * clickMult * scienceMult)
			end
		end
	end
	return payout, science
end

function EconomyService.tick(profile, dt: number): number
	local total = 0
	local totalScience = 0
	for _, def in ipairs(Config.BUSINESSES) do
		local p, s = tickBusiness(profile, def, dt)
		total += p
		totalScience += s
	end
	if total > 0 then
		profile.money += total
		profile.totalEarned += total
	end
	if totalScience > 0 then
		profile.gems = (profile.gems or 0) + totalScience
	end
	return total
end

-- Buy `qty` units of a business. qty may be a number or "MAX".
-- Returns (success, errorMessage, unitsBought, totalCost).
-- Tech gate: programs with non-empty requiresTech can't be founded until
-- the required tech node is researched. Only gates the FIRST purchase;
-- once owned > 0, the program scales freely.
function EconomyService.buyBusiness(profile, businessId: string, qty: any): (boolean, string?, number, number)
	local def = Config.BUSINESS_BY_ID[businessId]
	if not def then return false, "Unknown business", 0, 0 end

	local b = getOrInitBusiness(profile, businessId)
	local owned = b.owned

	if owned == 0 and def.requiresTech and #def.requiresTech > 0 then
		local missing = Upgrades.missingTechFor(profile, def.requiresTech)
		if missing then
			return false, "Research " .. missing.name .. " first", 0, 0
		end
	end

	local n: number
	if qty == "MAX" then
		n = Economy.maxAffordable(def, owned, profile.money)
	else
		n = tonumber(qty) or 0
		n = math.floor(n)
	end
	if n <= 0 then return false, "Invalid quantity", 0, 0 end

	local cost = Economy.bulkCost(def, owned, n)
	if cost > profile.money then
		-- For numeric quantities, fail rather than silently truncating.
		return false, "Not enough money", 0, 0
	end

	profile.money -= cost
	b.owned += n
	return true, nil, n, cost
end

function EconomyService.hireManager(profile, businessId: string): (boolean, string?)
	local def = Config.BUSINESS_BY_ID[businessId]
	if not def then return false, "Unknown business" end
	local b = getOrInitBusiness(profile, businessId)
	if b.hasManager then return false, "Already hired" end
	if profile.money < def.managerCost then return false, "Not enough money" end
	profile.money -= def.managerCost
	b.hasManager = true
	return true, nil
end

-- Begin a manual production cycle. Only meaningful when no manager is hired.
-- Always increments totalClicks (even if no cycle starts) so the achievement
-- ticks up when players are tapping while locked-out businesses are unlocked.
function EconomyService.manualCollect(profile, businessId: string): boolean
	profile.totalClicks = (profile.totalClicks or 0) + 1

	local def = Config.BUSINESS_BY_ID[businessId]
	if not def then return false end
	local b = getOrInitBusiness(profile, businessId)
	if b.owned <= 0 then return false end
	if b.hasManager then return false end -- already automated
	if b.progress > 0 then return false end -- cycle in flight
	b.progress = 0.0001 -- start the cycle; tick() will advance it
	return true
end

-- Perform a prestige: hard-reset run-state (money, businesses, upgrades) in
-- exchange for a permanent +20% global revenue multiplier per level.
-- Preserves achievements, gems, lifetime totalEarned/totalClicks.
function EconomyService.doPrestige(profile): (boolean, string?, number)
	if not Prestige.canPrestige(profile) then
		return false, "Not enough earnings this run", 0
	end

	-- Snapshot the level we're about to advance to so we can tell the caller.
	local newLevel = (profile.prestige or 0) + 1

	-- Lock the high-water mark so future prestiges measure earnings since now.
	profile.totalEarnedAtLastPrestige = profile.totalEarned or 0

	-- Run-state reset.
	profile.money = Config.STARTING_MONEY
	profile.businesses = {}
	profile.upgrades = {}
	for _, def in ipairs(Config.BUSINESSES) do
		profile.businesses[def.id] = { owned = 0, hasManager = false, progress = 0 }
	end

	-- Permanent gains.
	profile.prestige = newLevel

	return true, nil, newLevel
end

-- Ensure all 3 contract slots are populated. Called on profile load and
-- after each claim so empty slots get fresh contracts. Cheap; only rolls
-- new contracts when a slot is actually empty.
function EconomyService.ensureContracts(profile)
	profile.contracts = profile.contracts or {}
	for i = 1, 3 do
		if not profile.contracts[i] then
			profile.contracts[i] = Contracts.roll(profile)
		end
	end
end

-- Snapshot of metrics that contract progress checks against.
local function contractMetrics(profile)
	return {
		totalEarned = profile.totalEarned or 0,
		gems = profile.gems or 0,
		totalClicks = profile.totalClicks or 0,
	}
end

-- Claim a completed contract. Server validates completion against profile
-- metrics, credits both currencies, and rerolls the slot. Reroll is
-- intentionally NOT a separate cost — claiming IS what generates the next
-- contract in that slot.
function EconomyService.claimContract(profile, slotIndex: any): (boolean, string?)
	if type(slotIndex) ~= "number" then return false, "Invalid slot" end
	slotIndex = math.floor(slotIndex)
	if slotIndex < 1 or slotIndex > 3 then return false, "Invalid slot" end

	local slot = profile.contracts and profile.contracts[slotIndex]
	if not slot then return false, "Empty slot" end

	if not Contracts.complete(slot, contractMetrics(profile)) then
		return false, "Contract not yet complete"
	end

	-- Credit rewards. Contract funds count toward totalEarned so they show
	-- up in lifetime stats; we accept that they also count toward the next
	-- prestige (which scales rewards anyway, so it's self-balancing).
	profile.money = (profile.money or 0) + slot.rewardFunds
	profile.totalEarned = (profile.totalEarned or 0) + slot.rewardFunds
	profile.gems = (profile.gems or 0) + slot.rewardScience

	-- Reroll this slot with a fresh contract scaled to the new metrics.
	profile.contracts[slotIndex] = Contracts.roll(profile)
	return true, nil
end

-- Activate a timed boost. Server validates the cooldown and stamps both
-- activeUntil and cooldownUntil with os.time() values.
function EconomyService.activateBoost(profile, boostId: string): (boolean, string?)
	local def = Boosts.BY_ID[boostId]
	if not def then return false, "Unknown boost" end
	if not Boosts.canActivate(profile, boostId) then
		local left = Boosts.cooldownSecondsLeft(profile, boostId)
		return false, string.format("On cooldown (%ds)", left)
	end
	profile.boosts = profile.boosts or {}
	local now = os.time()
	profile.boosts[boostId] = {
		activeUntil = now + def.duration,
		cooldownUntil = now + def.cooldown,
	}
	return true, nil
end

-- Buy a one-time R&D upgrade. Costs science (profile.gems), not funds.
-- Server is authoritative on cost + unlock checks.
function EconomyService.buyUpgrade(profile, upgradeId: string): (boolean, string?)
	local def = Upgrades.BY_ID[upgradeId]
	if not def then return false, "Unknown research" end
	if Upgrades.isPurchased(profile, upgradeId) then
		return false, "Already researched"
	end
	if not Upgrades.prereqsMet(profile, def) then
		return false, "Research a prior tier first"
	end
	if not Upgrades.unlocked(profile, def) then
		return false, "Not unlocked yet"
	end
	local science = profile.gems or 0
	if science < def.scienceCost then
		return false, "Not enough science"
	end
	profile.gems = science - def.scienceCost
	profile.upgrades = profile.upgrades or {}
	profile.upgrades[upgradeId] = { purchased = true, purchasedAt = os.time() }
	return true, nil
end

-- Build a compact snapshot for replication to a single client.
function EconomyService.snapshot(profile)
	local biz = {}
	for id, b in pairs(profile.businesses) do
		biz[id] = { owned = b.owned, hasManager = b.hasManager, progress = b.progress }
	end
	local ach = {}
	for id, state in pairs(profile.achievements or {}) do
		ach[id] = { unlocked = state.unlocked, unlockedAt = state.unlockedAt }
	end
	local ups = {}
	for id, state in pairs(profile.upgrades or {}) do
		ups[id] = { purchased = state.purchased, purchasedAt = state.purchasedAt }
	end
	local bsts = {}
	for id, state in pairs(profile.boosts or {}) do
		bsts[id] = { activeUntil = state.activeUntil, cooldownUntil = state.cooldownUntil }
	end
	-- Contracts: copy each slot by value so the client mirror can mutate
	-- progress freely (it doesn't, but cleaner contract).
	local cts: { any } = {}
	for i, slot in ipairs(profile.contracts or {}) do
		cts[i] = {
			objective = slot.objective,
			target = slot.target,
			baseline = slot.baseline,
			rewardFunds = slot.rewardFunds,
			rewardScience = slot.rewardScience,
			title = slot.title,
			description = slot.description,
			issuedAt = slot.issuedAt,
		}
	end
	return {
		money = profile.money,
		gems = profile.gems or 0,
		prestige = profile.prestige or 0,
		agencyName = profile.agencyName or "",
		totalEarned = profile.totalEarned,
		totalEarnedAtLastPrestige = profile.totalEarnedAtLastPrestige or 0,
		totalClicks = profile.totalClicks or 0,
		businesses = biz,
		achievements = ach,
		upgrades = ups,
		boosts = bsts,
		contracts = cts,
		programNames = profile.programNames or {},
		tutorialStep = profile.tutorialStep or 0,
		dailyClaimedAt = profile.dailyClaimedAt or 0,
		settings = {
			sfxVolume = profile.settings.sfxVolume,
			musicVolume = profile.settings.musicVolume,
		},
		serverTime = os.clock(),
	}
end

-- Validate + store the agency name. Called by the first-launch setup modal
-- and from the settings panel later if we add rename UI.
function EconomyService.setAgencyName(profile, name: any): (boolean, string?)
	if type(name) ~= "string" then return false, "Invalid name" end
	-- Trim leading/trailing whitespace, collapse internal runs of whitespace.
	name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	if #name < 3 then return false, "Name must be at least 3 characters" end
	if #name > 24 then return false, "Name must be 24 characters or fewer" end
	-- Allow letters, digits, spaces, hyphens, apostrophes. Reject anything else.
	if not name:match("^[%w%s%-']+$") then
		return false, "Name may only contain letters, digits, spaces, hyphens"
	end
	profile.agencyName = name
	-- First-time naming kicks off the tutorial. Existing players with
	-- tutorialStep already past 0 (typical migration case) keep their state.
	if (profile.tutorialStep or 0) == 0 then
		profile.tutorialStep = 1
	end
	return true, nil
end

-- Validate + store an override display name for a single mission program.
-- An empty (post-trim) name clears the override, restoring the default.
-- Advance / skip the first-launch tutorial. The client requests a specific
-- next-step value rather than just "increment" so a Skip button can jump
-- straight to the DONE sentinel in one round-trip.
function EconomyService.advanceTutorial(profile, nextStep: any): (boolean, string?)
	local n = tonumber(nextStep)
	if not n then return false, "Invalid step" end
	n = math.floor(n)
	-- Tutorial is monotonic: never let the client roll back to an earlier step.
	local current = profile.tutorialStep or 0
	if n <= current then return false, "Already past that step" end
	-- Clamp ridiculous values back to the sentinel.
	if n > Tutorial.DONE then n = Tutorial.DONE end
	profile.tutorialStep = n
	return true, nil
end

function EconomyService.setProgramName(profile, businessId: any, name: any): (boolean, string?)
	if type(businessId) ~= "string" then return false, "Invalid program" end
	if not Config.BUSINESS_BY_ID[businessId] then return false, "Unknown program" end
	if type(name) ~= "string" then return false, "Invalid name" end

	name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	profile.programNames = profile.programNames or {}

	if #name == 0 then
		-- Empty → clear override, fall back to default.
		profile.programNames[businessId] = nil
		return true, nil
	end

	if #name > 24 then return false, "Name must be 24 characters or fewer" end
	if not name:match("^[%w%s%-']+$") then
		return false, "Name may only contain letters, digits, spaces, hyphens"
	end
	profile.programNames[businessId] = name
	return true, nil
end

-- Spend science on a Shop item. Two effect kinds today:
--   * reroll_contract — replaces a contract slot with a fresh roll
--   * reset_boost     — clears the cooldown on a specific boost (only
--                       valid when the boost is actually on cooldown,
--                       i.e. not currently active and not already ready)
function EconomyService.buyShopItem(profile, itemId: any): (boolean, string?)
	if type(itemId) ~= "string" then return false, "Invalid item" end
	local def = Shop.BY_ID[itemId]
	if not def then return false, "Unknown item" end

	-- Validate the effect can apply before charging — avoids "paid but
	-- nothing happened" cases.
	if def.effect == "reroll_contract" then
		local slot = def.contractSlot or 0
		if slot < 1 or slot > 3 then return false, "Invalid slot" end
		if not profile.contracts or not profile.contracts[slot] then
			return false, "Slot empty"
		end
	elseif def.effect == "reset_boost" then
		local boostId = def.boostId or ""
		local b = profile.boosts and profile.boosts[boostId]
		local now = os.time()
		if not b or b.cooldownUntil <= now then
			return false, "Boost is ready — no need to reset"
		end
		if b.activeUntil > now then
			return false, "Boost is still active"
		end
	else
		return false, "Unknown effect"
	end

	local science = profile.gems or 0
	if science < def.scienceCost then
		return false, "Not enough science"
	end

	profile.gems = science - def.scienceCost

	-- Apply.
	if def.effect == "reroll_contract" then
		profile.contracts[def.contractSlot :: number] = Contracts.roll(profile)
	elseif def.effect == "reset_boost" then
		profile.boosts[def.boostId :: string].cooldownUntil = os.time()
	end

	return true, nil
end

-- Apply validated settings updates from the client.
-- Volumes are clamped to [0, 1]; other fields are ignored.
function EconomyService.updateSettings(profile, payload: any)
	if type(payload) ~= "table" then return end
	if payload.sfxVolume ~= nil then
		local v = tonumber(payload.sfxVolume)
		if v then profile.settings.sfxVolume = math.clamp(v, 0, 1) end
	end
	if payload.musicVolume ~= nil then
		local v = tonumber(payload.musicVolume)
		if v then profile.settings.musicVolume = math.clamp(v, 0, 1) end
	end
end

return EconomyService
