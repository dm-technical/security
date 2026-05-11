--!strict
-- Server entry point. Wires up data loading, the tick loop, remote handlers,
-- autosave, and player join/leave lifecycle.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AchievementsService = require(script.Parent.AchievementsService)

local buyEvent = Remotes.event("BuyBusiness")
local hireEvent = Remotes.event("HireManager")
local manualEvent = Remotes.event("ManualCollect")
local settingsEvent = Remotes.event("UpdateSettings")
local claimDailyEvent = Remotes.event("ClaimDailyReward")
local stateUpdate = Remotes.event("StateUpdate")
local offlineEvent = Remotes.event("OfflineEarnings")
local notify = Remotes.event("Notify")
local achievementUnlocked = Remotes.event("AchievementUnlocked")
local getState = Remotes.func("GetState")

-- Track per-player ephemeral state (debounce timestamps, etc.).
local lastSavePush: { [number]: number } = {}

local function pushState(player: Player)
	local profile = DataService.get(player)
	if not profile then return end
	stateUpdate:FireClient(player, EconomyService.snapshot(profile))
end

-- Run achievement checks; notify the client of any new unlocks so it can
-- show the celebration banner. Cheap (O(achievements * 1)), safe to call
-- after any income/click/owned-changing event.
local function runAchievementChecks(player: Player)
	local profile = DataService.get(player)
	if not profile then return end
	local unlocked = AchievementsService.checkAndUnlock(profile, player)
	if #unlocked > 0 then
		achievementUnlocked:FireClient(player, { ids = unlocked })
		-- Push fresh state so the gem counter and progress bars update.
		stateUpdate:FireClient(player, EconomyService.snapshot(profile))
	end
end

local function maybeSaveAfterPurchase(player: Player)
	local now = os.clock()
	local last = lastSavePush[player.UserId] or 0
	if now - last < Config.PURCHASE_SAVE_COOLDOWN then return end
	lastSavePush[player.UserId] = now
	DataService.autosave(player)
end

-- Player lifecycle ----------------------------------------------------------

local function onPlayerAdded(player: Player)
	local profile = DataService.load(player)
	if not profile then return end -- load failure already kicked
	EconomyService.initProfile(profile)

	local offlineAmount, offlineSeconds = EconomyService.applyOfflineProgress(profile)
	-- Bump lastOnline now that we've consumed the elapsed window.
	profile.lastOnline = os.time()

	-- Kick off a fresh save so the new lastOnline lands quickly.
	DataService.autosave(player)

	-- Replicate state once the client is ready, then re-check achievements
	-- (offline earnings may have just crossed a totalEarned threshold).
	task.defer(function()
		pushState(player)
		if offlineAmount > 0 then
			offlineEvent:FireClient(player, {
				amount = offlineAmount,
				seconds = offlineSeconds,
			})
		end
		runAchievementChecks(player)
	end)
end

local function onPlayerRemoving(player: Player)
	DataService.unload(player)
	lastSavePush[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

-- Remote handlers -----------------------------------------------------------

getState.OnServerInvoke = function(player: Player)
	local profile = DataService.get(player)
	if not profile then return nil end
	return EconomyService.snapshot(profile)
end

buyEvent.OnServerEvent:Connect(function(player: Player, businessId: any, qty: any)
	if type(businessId) ~= "string" then return end
	local profile = DataService.get(player)
	if not profile then return end
	local ok, err, units, cost = EconomyService.buyBusiness(profile, businessId, qty)
	if ok then
		pushState(player)
		maybeSaveAfterPurchase(player)
		runAchievementChecks(player) -- Business Tycoon-style achievements.
	else
		notify:FireClient(player, { kind = "error", message = err or "Purchase failed" })
	end
	local _ = units
	local _ = cost
end)

hireEvent.OnServerEvent:Connect(function(player: Player, businessId: any)
	if type(businessId) ~= "string" then return end
	local profile = DataService.get(player)
	if not profile then return end
	local ok, err = EconomyService.hireManager(profile, businessId)
	if ok then
		pushState(player)
		maybeSaveAfterPurchase(player)
	else
		notify:FireClient(player, { kind = "error", message = err or "Hire failed" })
	end
end)

manualEvent.OnServerEvent:Connect(function(player: Player, businessId: any)
	if type(businessId) ~= "string" then return end
	local profile = DataService.get(player)
	if not profile then return end
	EconomyService.manualCollect(profile, businessId)
	-- The tick loop reflects cycle progress; we still check achievements
	-- because Click Master watches totalClicks which manualCollect bumps.
	runAchievementChecks(player)
end)

settingsEvent.OnServerEvent:Connect(function(player: Player, payload: any)
	local profile = DataService.get(player)
	if not profile then return end
	EconomyService.updateSettings(profile, payload)
end)

-- Daily reward stub: 24-hour cooldown, grants 25 gems on claim.
-- Will get richer rewards (escalating streak, etc.) in a later pass.
local DAILY_COOLDOWN = 24 * 3600
local DAILY_GEM_REWARD = 25
claimDailyEvent.OnServerEvent:Connect(function(player: Player)
	local profile = DataService.get(player)
	if not profile then return end
	local now = os.time()
	if now - (profile.dailyClaimedAt or 0) < DAILY_COOLDOWN then
		notify:FireClient(player, { kind = "error", message = "Daily reward not ready yet" })
		return
	end
	profile.dailyClaimedAt = now
	profile.gems = (profile.gems or 0) + DAILY_GEM_REWARD
	pushState(player)
	notify:FireClient(player, { kind = "info", message = "+" .. DAILY_GEM_REWARD .. " gems claimed!" })
	DataService.autosave(player)
end)

-- Tick loop -----------------------------------------------------------------

local lastTick = os.clock()
local accum = 0
local replicateAccum = 0
local autosaveAccum = 0
local achievementCheckAccum = 0

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local dt = now - lastTick
	lastTick = now
	accum += dt
	replicateAccum += dt
	autosaveAccum += dt

	if accum < Config.TICK_INTERVAL then return end
	local stepDt = accum
	accum = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.get(player)
		if profile then
			EconomyService.tick(profile, stepDt)
		end
	end

	-- Replicate ~5x per second; clients interpolate progress between updates.
	-- Achievement checks piggyback here at ~1Hz to catch First Million / Billionaire
	-- crossings driven by passive income without spamming AwardBadge.
	if replicateAccum >= 0.2 then
		replicateAccum = 0
		achievementCheckAccum += 1
		local shouldCheckAch = achievementCheckAccum >= 5
		if shouldCheckAch then achievementCheckAccum = 0 end
		for _, player in ipairs(Players:GetPlayers()) do
			pushState(player)
			if shouldCheckAch then
				runAchievementChecks(player)
			end
		end
	end

	if autosaveAccum >= Config.AUTOSAVE_INTERVAL then
		autosaveAccum = 0
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.autosave(player)
		end
	end
end)
