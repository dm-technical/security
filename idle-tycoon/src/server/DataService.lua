--!strict
-- DataStore wrapper with retry, session locking, and a graceful fallback
-- to in-memory storage when DataStores are unavailable (Studio without API access).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DATASTORE_NAME = "IdleTycoon_v1"
local SESSION_LOCK_TTL = 600 -- seconds; old locks auto-expire after this

local DataService = {}
DataService.__index = DataService

local store: DataStore? = nil
local datastoresEnabled = false

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok and result then
		store = result
		datastoresEnabled = true
	else
		warn("[DataService] DataStores unavailable, falling back to in-memory storage:", result)
	end
end

local memoryFallback: { [string]: any } = {}

local function userKey(userId: number): string
	return "u_" .. tostring(userId)
end

-- Retry wrapper with exponential backoff, capped at 4 tries.
local function retry<T>(fn: () -> T): (boolean, T?)
	local delayMs = 200
	for attempt = 1, 4 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(string.format("[DataService] attempt %d failed: %s", attempt, tostring(result)))
		if attempt < 4 then
			task.wait(delayMs / 1000)
			delayMs *= 2
		end
	end
	return false, nil
end

export type ProfileSettings = {
	sfxVolume: number,
	musicVolume: number,
}

export type AchievementState = {
	unlocked: boolean,
	unlockedAt: number,
}

export type UpgradeState = {
	purchased: boolean,
	purchasedAt: number,
}

export type BoostState = {
	activeUntil: number,
	cooldownUntil: number,
}

export type ContractSlot = {
	objective: string,
	target: number,
	baseline: number,
	rewardFunds: number,
	rewardScience: number,
	title: string,
	description: string,
	issuedAt: number,
}

export type ProfileData = {
	version: number,
	agencyName: string,
	money: number,
	gems: number,
	prestige: number,
	totalClicks: number,
	businesses: { [string]: { owned: number, hasManager: boolean, progress: number } },
	settings: ProfileSettings,
	achievements: { [string]: AchievementState },
	upgrades: { [string]: UpgradeState },
	boosts: { [string]: BoostState },
	contracts: { ContractSlot },
	programNames: { [string]: string }, -- player-set override per business id
	tutorialStep: number, -- 0 = not started; 1..N = current step; >N = done
	dailyClaimedAt: number,
	totalEarnedAtLastPrestige: number,
	lastOnline: number,
	totalEarned: number,
	createdAt: number,
}

local CURRENT_VERSION = 10

local function defaultSettings(): ProfileSettings
	return { sfxVolume = 1.0, musicVolume = 0.6 }
end

local function defaultProfile(): ProfileData
	return {
		version = CURRENT_VERSION,
		agencyName = "", -- empty until the first-launch setup modal collects one
		money = 0, -- caller seeds with starting money
		gems = 0,
		prestige = 0,
		totalClicks = 0,
		businesses = {},
		settings = defaultSettings(),
		achievements = {},
		upgrades = {},
		boosts = {},
		contracts = {},
		programNames = {},
		tutorialStep = 0, -- triggers the first-launch tutorial after agency setup
		dailyClaimedAt = 0,
		totalEarnedAtLastPrestige = 0,
		lastOnline = os.time(),
		totalEarned = 0,
		createdAt = os.time(),
	}
end

-- Migrate older saves forward. Add cases as the schema evolves.
local function migrate(data: any): ProfileData
	if type(data) ~= "table" then
		return defaultProfile()
	end
	data.businesses = data.businesses or {}
	data.money = tonumber(data.money) or 0
	data.totalEarned = tonumber(data.totalEarned) or 0
	data.lastOnline = tonumber(data.lastOnline) or os.time()
	data.createdAt = tonumber(data.createdAt) or os.time()

	-- v1 -> v2: add settings.
	if not data.settings or type(data.settings) ~= "table" then
		data.settings = defaultSettings()
	else
		data.settings.sfxVolume = tonumber(data.settings.sfxVolume) or 1.0
		data.settings.musicVolume = tonumber(data.settings.musicVolume) or 0.6
	end

	-- v2 -> v3: add gems, prestige, totalClicks, achievements, dailyClaimedAt.
	data.gems = tonumber(data.gems) or 0
	data.prestige = tonumber(data.prestige) or 0
	data.totalClicks = tonumber(data.totalClicks) or 0
	data.dailyClaimedAt = tonumber(data.dailyClaimedAt) or 0
	if type(data.achievements) ~= "table" then
		data.achievements = {}
	end

	-- v3 -> v4: add upgrades.
	if type(data.upgrades) ~= "table" then
		data.upgrades = {}
	end

	-- v4 -> v5: add totalEarnedAtLastPrestige. Default to current totalEarned
	-- so existing players don't get a "free prestige" they didn't earn this run.
	if data.totalEarnedAtLastPrestige == nil then
		data.totalEarnedAtLastPrestige = data.totalEarned or 0
	else
		data.totalEarnedAtLastPrestige = tonumber(data.totalEarnedAtLastPrestige) or 0
	end

	-- v5 -> v6: add boosts state (timed multiplier per boost id).
	if type(data.boosts) ~= "table" then
		data.boosts = {}
	end

	-- v6 -> v7: add agencyName. Empty string triggers the setup modal client-side.
	if type(data.agencyName) ~= "string" then
		data.agencyName = ""
	end

	-- v7 -> v8: add contracts slot array. Empty triggers ensureContracts() to
	-- roll the initial 3 on first server load.
	if type(data.contracts) ~= "table" then
		data.contracts = {}
	end

	-- v8 -> v9: add programNames override map. Empty = all defaults used.
	if type(data.programNames) ~= "table" then
		data.programNames = {}
	end

	-- v9 -> v10: add tutorialStep. Existing players have already learned the
	-- mechanics, so default them to "done" instead of triggering the popup.
	if data.tutorialStep == nil then
		-- New profile (defaultProfile returns 0); migrated profile with any
		-- real progress skips straight to done.
		local hasProgress = (data.totalEarned or 0) > 0 or (data.totalClicks or 0) > 0
		data.tutorialStep = hasProgress and 999 or 0
	else
		data.tutorialStep = tonumber(data.tutorialStep) or 0
	end

	data.version = CURRENT_VERSION
	return data :: ProfileData
end

-- Acquire a session lock by checking if the existing lock is stale.
-- Roblox's UpdateAsync gives us atomic compare-and-swap semantics.
local function acquireLock(key: string): (boolean, ProfileData?)
	if not datastoresEnabled or not store then
		local existing = memoryFallback[key]
		return true, existing
	end

	local jobId = game.JobId ~= "" and game.JobId or "studio"
	local now = os.time()
	local acquired = false
	local profile: ProfileData? = nil

	local ok = retry(function()
		return (store :: DataStore):UpdateAsync(key, function(old)
			old = old or { data = defaultProfile() }
			local lock = old.lock
			if lock and lock.jobId ~= jobId and (now - (lock.time or 0)) < SESSION_LOCK_TTL then
				-- Held by another live session.
				return nil
			end
			old.lock = { jobId = jobId, time = now }
			acquired = true
			profile = migrate(old.data)
			return old
		end)
	end)

	if not ok then
		return false, nil
	end
	return acquired, profile
end

local function releaseLock(key: string, finalData: ProfileData)
	if not datastoresEnabled or not store then
		memoryFallback[key] = finalData
		return
	end
	local jobId = game.JobId ~= "" and game.JobId or "studio"
	retry(function()
		return (store :: DataStore):UpdateAsync(key, function(old)
			old = old or {}
			-- Only clear our own lock to avoid stomping a takeover.
			if old.lock and old.lock.jobId == jobId then
				old.lock = nil
			end
			old.data = finalData
			return old
		end)
	end)
end

local function saveData(key: string, data: ProfileData, keepLock: boolean)
	if not datastoresEnabled or not store then
		memoryFallback[key] = data
		return
	end
	local jobId = game.JobId ~= "" and game.JobId or "studio"
	retry(function()
		return (store :: DataStore):UpdateAsync(key, function(old)
			old = old or {}
			old.data = data
			if keepLock then
				old.lock = { jobId = jobId, time = os.time() }
			end
			return old
		end)
	end)
end

-- Public API ----------------------------------------------------------------

local profiles: { [number]: ProfileData } = {}
local saveLocks: { [number]: boolean } = {}

function DataService.load(player: Player): ProfileData?
	local key = userKey(player.UserId)
	local acquired, profile = acquireLock(key)
	if not acquired then
		warn(string.format("[DataService] could not acquire session lock for %s", player.Name))
		-- Kick the player to avoid duplication if another server holds the lock.
		player:Kick("Your previous session is still saving. Please rejoin in a moment.")
		return nil
	end
	profile = profile or defaultProfile()
	profiles[player.UserId] = profile
	return profile
end

function DataService.get(player: Player): ProfileData?
	return profiles[player.UserId]
end

function DataService.autosave(player: Player)
	local data = profiles[player.UserId]
	if not data then return end
	if saveLocks[player.UserId] then return end
	saveLocks[player.UserId] = true
	task.spawn(function()
		data.lastOnline = os.time()
		saveData(userKey(player.UserId), data, true)
		saveLocks[player.UserId] = nil
	end)
end

function DataService.unload(player: Player)
	local data = profiles[player.UserId]
	if not data then return end
	data.lastOnline = os.time()
	releaseLock(userKey(player.UserId), data)
	profiles[player.UserId] = nil
end

-- Make sure data flushes on server shutdown (BindToClose has ~30s budget).
game:BindToClose(function()
	if RunService:IsStudio() and not datastoresEnabled then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			DataService.unload(player)
		end)
	end
	-- Give pcall'd writes a moment to complete.
	task.wait(2)
end)

return DataService
