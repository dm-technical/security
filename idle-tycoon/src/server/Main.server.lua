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

local buyEvent = Remotes.event("BuyBusiness")
local hireEvent = Remotes.event("HireManager")
local manualEvent = Remotes.event("ManualCollect")
local settingsEvent = Remotes.event("UpdateSettings")
local stateUpdate = Remotes.event("StateUpdate")
local offlineEvent = Remotes.event("OfflineEarnings")
local notify = Remotes.event("Notify")
local getState = Remotes.func("GetState")

-- Track per-player ephemeral state (debounce timestamps, etc.).
local lastSavePush: { [number]: number } = {}

local function pushState(player: Player)
	local profile = DataService.get(player)
	if not profile then return end
	stateUpdate:FireClient(player, EconomyService.snapshot(profile))
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

	-- Replicate state once the client is ready.
	task.defer(function()
		pushState(player)
		if offlineAmount > 0 then
			offlineEvent:FireClient(player, {
				amount = offlineAmount,
				seconds = offlineSeconds,
			})
		end
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
	else
		notify:FireClient(player, { kind = "error", message = err or "Purchase failed" })
	end
	-- Silence "unused" warnings; these are useful for analytics later.
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
	-- No state push here — the tick loop will reflect progress shortly.
end)

settingsEvent.OnServerEvent:Connect(function(player: Player, payload: any)
	local profile = DataService.get(player)
	if not profile then return end
	EconomyService.updateSettings(profile, payload)
	-- No state push needed; client already updated locally. Persists on next autosave.
end)

-- Tick loop -----------------------------------------------------------------

local lastTick = os.clock()
local accum = 0
local replicateAccum = 0
local autosaveAccum = 0

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
	if replicateAccum >= 0.2 then
		replicateAccum = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pushState(player)
		end
	end

	if autosaveAccum >= Config.AUTOSAVE_INTERVAL then
		autosaveAccum = 0
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.autosave(player)
		end
	end
end)
