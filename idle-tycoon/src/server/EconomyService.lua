--!strict
-- Authoritative economy: handles purchases, manager hires, manual collects,
-- and ticks automated businesses. All money mutations flow through here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Upgrades = require(Shared.Upgrades)

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

	local total = 0
	for _, def in ipairs(Config.BUSINESSES) do
		local b = profile.businesses[def.id]
		if b and b.owned > 0 and b.hasManager then
			-- Apply purchased upgrade multipliers to offline accrual too.
			local mult = Upgrades.multiplierFor(profile, def.id)
			total += Economy.revenuePerSecond(def, b.owned, mult) * capped
		end
	end
	total *= Config.OFFLINE_EARN_RATE

	if total > 0 then
		profile.money += total
		profile.totalEarned += total
	end
	return total, capped
end

-- Tick a single business by `dt` seconds.
-- For managed businesses we accumulate progress and pay out completed cycles.
-- For unmanaged businesses, progress only advances if a manual cycle is active.
-- Multiplier comes from purchased upgrades; click multiplier stacks on manual cycles.
local function tickBusiness(profile, def: Config.BusinessDef, dt: number): number
	local b = profile.businesses[def.id]
	if not b or b.owned <= 0 then return 0 end

	local baseMult = Upgrades.multiplierFor(profile, def.id)
	local clickMult = Upgrades.clickMultiplier(profile)

	local payout = 0
	if b.hasManager then
		b.progress += dt
		while b.progress >= def.cycleTime do
			b.progress -= def.cycleTime
			payout += Economy.cyclePayout(def, b.owned, baseMult)
		end
	else
		if b.progress > 0 and b.progress < def.cycleTime then
			b.progress = math.min(def.cycleTime, b.progress + dt)
			if b.progress >= def.cycleTime then
				b.progress = 0
				-- Manual cycles get the click multiplier on top.
				payout = Economy.cyclePayout(def, b.owned, baseMult * clickMult)
			end
		end
	end
	return payout
end

function EconomyService.tick(profile, dt: number): number
	local total = 0
	for _, def in ipairs(Config.BUSINESSES) do
		total += tickBusiness(profile, def, dt)
	end
	if total > 0 then
		profile.money += total
		profile.totalEarned += total
	end
	return total
end

-- Buy `qty` units of a business. qty may be a number or "MAX".
-- Returns (success, errorMessage, unitsBought, totalCost).
function EconomyService.buyBusiness(profile, businessId: string, qty: any): (boolean, string?, number, number)
	local def = Config.BUSINESS_BY_ID[businessId]
	if not def then return false, "Unknown business", 0, 0 end

	local b = getOrInitBusiness(profile, businessId)
	local owned = b.owned

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

-- Buy a one-time upgrade. Server is authoritative on cost + unlock checks.
-- Returns (success, errorMessage).
function EconomyService.buyUpgrade(profile, upgradeId: string): (boolean, string?)
	local def = Upgrades.BY_ID[upgradeId]
	if not def then return false, "Unknown upgrade" end
	if Upgrades.isPurchased(profile, upgradeId) then
		return false, "Already purchased"
	end
	if not Upgrades.unlocked(profile, def) then
		return false, "Not unlocked yet"
	end
	if profile.money < def.cost then
		return false, "Not enough money"
	end
	profile.money -= def.cost
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
	return {
		money = profile.money,
		gems = profile.gems or 0,
		prestige = profile.prestige or 0,
		totalEarned = profile.totalEarned,
		totalClicks = profile.totalClicks or 0,
		businesses = biz,
		achievements = ach,
		upgrades = ups,
		dailyClaimedAt = profile.dailyClaimedAt or 0,
		settings = {
			sfxVolume = profile.settings.sfxVolume,
			musicVolume = profile.settings.musicVolume,
		},
		serverTime = os.clock(),
	}
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
