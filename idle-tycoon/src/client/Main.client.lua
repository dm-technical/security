--!strict
-- Client controller. Builds the UI, requests initial state, listens for
-- server snapshots, locally extrapolates progress, and drives polish effects
-- (sounds, floating text, milestone banners).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)
local Achievements = require(Shared.Achievements)

local Theme = require(script.Parent:WaitForChild("Theme"))
local UI = require(script.Parent:WaitForChild("UI"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))
local Music = require(script.Parent:WaitForChild("Music"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local Background = require(script.Parent:WaitForChild("Background"))

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

local Players = game:GetService("Players")

local handles = UI.build()
local settingsPanel = Settings.build(handles.screenGui)

-- Pre-populate the player card with the local player's display name.
handles.playerNameLabel.Text = Players.LocalPlayer.DisplayName

-- Start ambient coin-rain in the dedicated background layer.
Background.start(handles.backgroundLayer)

-- Begin music; will silently no-op if no track ID is configured.
Music.start()

-- "Coming soon" toast for stubbed systems.
local function comingSoon(label: string)
	UI.flashNotify(handles, "info", label .. " — coming soon!")
	Sounds.play("uiClick")
end

-- Wire stubbed interactions.
handles.sidebar.onTab = function(id: string, enabled: boolean)
	Sounds.play("uiClick")
	if not enabled then
		comingSoon(id:sub(1, 1):upper() .. id:sub(2))
	end
end
handles.rightPanel.onBoostClick = function(id: string)
	comingSoon("Boosts")
end
handles.rightPanel.onViewAllClick = function()
	comingSoon("Achievements")
end
handles.gemAddButton.MouseButton1Click:Connect(function()
	comingSoon("Gem shop")
end)
handles.eventActivateButton.MouseButton1Click:Connect(function()
	comingSoon("Events")
end)
handles.inviteButton.MouseButton1Click:Connect(function()
	comingSoon("Invite friends")
end)

-- Daily reward: fires the server claim, which validates the 24h cooldown.
handles.sidebar.onClaimDaily = function()
	claimDailyEvent:FireServer()
	Sounds.play("uiClick")
end

-- Daily reward + bottom event countdowns. Re-evaluated once per second.
task.spawn(function()
	while handles.sidebar.dailyTimerLabel.Parent do
		local now = os.time()

		-- Daily reward: server uses 24h cooldown from dailyClaimedAt.
		local claimedAt = state.dailyClaimedAt or 0
		local secsUntilDaily = math.max(0, claimedAt + 24 * 3600 - now)
		if secsUntilDaily == 0 then
			handles.sidebar.dailyTimerLabel.Text = "Ready!"
			handles.sidebar.dailyTimerLabel.TextColor3 = Theme.colors.buyBright
			handles.sidebar.setDailyClaimEnabled(true)
		else
			local h = math.floor(secsUntilDaily / 3600)
			local m = math.floor((secsUntilDaily % 3600) / 60)
			local s = secsUntilDaily % 60
			handles.sidebar.dailyTimerLabel.Text = string.format("%02d:%02d:%02d", h, m, s)
			handles.sidebar.dailyTimerLabel.TextColor3 = Theme.colors.text
			handles.sidebar.setDailyClaimEnabled(false)
		end

		-- Bottom-bar event timer: placeholder 24h rolling countdown until the
		-- event system ships. Replace with real event state in Phase 2.
		local eventSecsLeft = 24 * 3600 - (now % (24 * 3600))
		local eh = math.floor(eventSecsLeft / 3600)
		local em = math.floor((eventSecsLeft % 3600) / 60)
		local es = eventSecsLeft % 60
		handles.eventTimerLabel.Text = string.format("⏰  %02d:%02d:%02d", eh, em, es)

		task.wait(1)
	end
end)

-- Settings -> apply locally + persist to server.
local function applySettings(values: Settings.Values)
	Sounds.setVolume(values.sfxVolume)
	Music.setVolume(values.musicVolume)
	settingsEvent:FireServer(values)
end
settingsPanel.onChange = applySettings

-- Bind tactile feedback on every button at construction time.
Effects.bindPressFeel(handles.qtyButton)
Effects.bindPressFeel(handles.offlineCloseButton)
Effects.bindPressFeel(settingsPanel.gearButton)
Effects.bindPressFeel(settingsPanel.sfxButton)
Effects.bindPressFeel(settingsPanel.musicButton)
Effects.bindPressFeel(settingsPanel.closeButton)
for _, h in pairs(handles.businesses) do
	Effects.bindPressFeel(h.buyButton)
	Effects.bindPressFeel(h.managerButton)
	Effects.bindPressFeel(h.tapButton)
end

-- Affordance pulses (turned on/off in the render loop).
local buyPulses: { [string]: any } = {}
local managerPulses: { [string]: any } = {}
for id, h in pairs(handles.businesses) do
	buyPulses[id] = Effects.affordancePulse(h.buyButton)
	managerPulses[id] = Effects.affordancePulse(h.managerButton)
end

-- Local mirror of server state.
type ClientBusiness = { owned: number, hasManager: boolean, progress: number }
type ClientAchievement = { unlocked: boolean, unlockedAt: number }
type ClientState = {
	money: number,
	gems: number,
	prestige: number,
	totalEarned: number,
	totalClicks: number,
	businesses: { [string]: ClientBusiness },
	achievements: { [string]: ClientAchievement },
	dailyClaimedAt: number,
	lastUpdate: number,
}

local state: ClientState = {
	money = 0,
	gems = 0,
	prestige = 0,
	totalEarned = 0,
	totalClicks = 0,
	businesses = {},
	achievements = {},
	dailyClaimedAt = 0,
	lastUpdate = os.clock(),
}

-- Detection state -----------------------------------------------------------
-- Tracking previous-frame values lets us emit one-shot effects on edges
-- (cycle wrap, milestone cross, money increase) without flooding.

local prevProgress: { [string]: number } = {}
local prevOwned: { [string]: number } = {}
local prevHadManager: { [string]: boolean } = {}
local prevMoney = 0
-- Smoothly-animated value displayed in the HUD; lerps toward state.money.
local displayedMoney = 0
-- Suppress effects on the very first snapshot so a returning player doesn't
-- see a flood of milestone banners on join.
local snapshotsApplied = 0
-- Whether we've pulled settings from the first snapshot yet.
local settingsApplied = false

local qtyIndex = 1
local function currentQty(): any
	return Config.BUY_QUANTITIES[qtyIndex]
end

local function formatQty(q: any): string
	if q == "MAX" then return "MAX" end
	return "x" .. tostring(q)
end

handles.qtyButton.MouseButton1Click:Connect(function()
	qtyIndex = (qtyIndex % #Config.BUY_QUANTITIES) + 1
	handles.qtyButton.Text = "BUY " .. formatQty(currentQty())
	Sounds.play("uiClick")
end)

-- Wire per-business buttons.
for id, h in pairs(handles.businesses) do
	h.buyButton.MouseButton1Click:Connect(function()
		buyEvent:FireServer(id, currentQty())
		Sounds.play("uiClick")
	end)
	h.managerButton.MouseButton1Click:Connect(function()
		hireEvent:FireServer(id)
		Sounds.play("uiClick")
	end)
	h.tapButton.MouseButton1Click:Connect(function()
		manualEvent:FireServer(id)
		Sounds.play("tap")
		-- Optimistic local cycle start so the bar moves immediately,
		-- without waiting for the next 5Hz server snapshot.
		local b = state.businesses[id]
		if b and b.owned > 0 and not b.hasManager and b.progress <= 0 then
			b.progress = 0.001
		end
		Effects.punchScale(h.tapButton, 0.08)
	end)
end

-- Snapshot application ------------------------------------------------------

local function whichMilestoneCrossed(prev: number, current: number): number?
	for _, ms in ipairs(Config.MILESTONES) do
		if prev < ms.level and current >= ms.level then
			return ms.level
		end
	end
	return nil
end

local function applySnapshot(snap)
	if not snap then return end
	state.money = snap.money or state.money
	state.gems = snap.gems or state.gems
	state.prestige = snap.prestige or state.prestige
	state.totalEarned = snap.totalEarned or state.totalEarned
	state.totalClicks = snap.totalClicks or state.totalClicks
	state.dailyClaimedAt = snap.dailyClaimedAt or state.dailyClaimedAt
	state.lastUpdate = os.clock()
	for id, b in pairs(snap.businesses or {}) do
		state.businesses[id] = {
			owned = b.owned or 0,
			hasManager = b.hasManager or false,
			progress = b.progress or 0,
		}
	end
	if type(snap.achievements) == "table" then
		for id, st in pairs(snap.achievements) do
			state.achievements[id] = {
				unlocked = st.unlocked or false,
				unlockedAt = st.unlockedAt or 0,
			}
		end
	end

	-- Apply persisted audio settings on the very first snapshot.
	if not settingsApplied and type(snap.settings) == "table" then
		local v = {
			sfxVolume = tonumber(snap.settings.sfxVolume) or 1.0,
			musicVolume = tonumber(snap.settings.musicVolume) or 0.6,
		}
		settingsPanel.setValues(v)
		Sounds.setVolume(v.sfxVolume)
		Music.setVolume(v.musicVolume)
		settingsApplied = true
		-- Also seed the displayed money so the first frame doesn't tween from 0.
		displayedMoney = state.money
	end

	snapshotsApplied += 1
end

stateUpdate.OnClientEvent:Connect(applySnapshot)

achievementUnlocked.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.ids) ~= "table" then return end
	-- One banner per unlock, slightly staggered so multi-unlocks don't pile up.
	for i, id in ipairs(payload.ids) do
		local def = Achievements.BY_ID[id]
		if def then
			task.delay((i - 1) * 0.4, function()
				Effects.celebrationBanner(
					handles.screenGui,
					def.icon .. "  " .. def.name .. " unlocked!",
					"+" .. tostring(def.gemReward) .. " 💎"
				)
				Sounds.play("milestone")
			end)
		end
	end
end)

notify.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.message then
		UI.flashNotify(handles, payload.kind or "info", payload.message)
		if payload.kind == "error" then
			Sounds.play("purchaseFail")
		end
	end
end)

offlineEvent.OnClientEvent:Connect(function(payload)
	if not payload or not payload.amount or payload.amount <= 0 then return end
	handles.offlineAmountLabel.Text = Format.money(payload.amount)
	handles.offlineDurationLabel.Text =
		"You were away for " .. Format.duration(payload.seconds) .. "."
	handles.offlinePopup.Visible = true
	Sounds.play("milestone")
end)

handles.offlineCloseButton.MouseButton1Click:Connect(function()
	handles.offlinePopup.Visible = false
	Sounds.play("uiClick")
end)

-- Pull initial snapshot.
task.spawn(function()
	local ok, snap = pcall(function()
		return getState:InvokeServer()
	end)
	if ok then
		applySnapshot(snap)
	end
end)

-- Local extrapolation + edge detection -------------------------------------

local function advanceLocal(dt: number)
	for id, b in pairs(state.businesses) do
		if b.owned > 0 then
			local def = Config.BUSINESS_BY_ID[id]
			if def then
				if b.hasManager then
					b.progress += dt
					while b.progress >= def.cycleTime do
						b.progress -= def.cycleTime
						-- Optimistic credit; server snapshot is source of truth.
						state.money += Economy.cyclePayout(def, b.owned, 1)
					end
				elseif b.progress > 0 then
					b.progress = math.min(def.cycleTime, b.progress + dt)
					if b.progress >= def.cycleTime then
						-- Manual cycle just completed locally.
						state.money += Economy.cyclePayout(def, b.owned, 1)
						b.progress = 0
					end
				end
			end
		end
	end
end

local function emitEdgeEffects()
	-- Cycle-completion floating text + sound (only once per business per frame
	-- group, to avoid spamming when many cycles wrap at once with managers).
	for id, b in pairs(state.businesses) do
		local h = handles.businesses[id]
		if not h then continue end
		local def = h.def
		local prev = prevProgress[id] or 0
		local owned = b.owned

		-- A "wrap" is when progress went backward (managed: cycleTime → 0,
		-- manual: high → 0). Owned must be > 0 to count.
		if owned > 0 and prev > b.progress and prev > def.cycleTime * 0.5 then
			local payout = Economy.cyclePayout(def, owned, 1)
			Effects.floatingText(h.frame, "+" .. Format.money(payout))
			-- Themed flash on the per-business progress bar.
			local theme = Theme.businessTheme(id)
			Effects.flashBackground(h.progressFill, theme.bright, theme.base)
			Effects.burstParticles(handles.screenGui, h.iconCard, 10, theme.bright)
			Sounds.play("cycle")
		end

		-- Owned increment (purchase landed): pulse the icon.
		local prevO = prevOwned[id] or 0
		if owned > prevO then
			Effects.punchScale(h.icon, 0.15)
			if snapshotsApplied > 1 then
				Sounds.play("purchase")
			end

			-- Milestone celebration.
			local crossed = whichMilestoneCrossed(prevO, owned)
			if crossed and snapshotsApplied > 1 then
				local mult = 1
				for _, ms in ipairs(Config.MILESTONES) do
					if ms.level == crossed then mult = ms.multiplier; break end
				end
				Effects.celebrationBanner(
					handles.screenGui,
					string.format("%s × %d!", def.name, crossed),
					string.format("Revenue ×%d", mult)
				)
				Sounds.play("milestone")
			end
		end

		-- Manager just hired: fanfare + persistent visual change handled in refreshUI.
		if b.hasManager and not (prevHadManager[id] or false) then
			if snapshotsApplied > 1 then
				Sounds.play("manager")
				Effects.celebrationBanner(
					handles.screenGui,
					def.managerName .. " hired!",
					def.name .. " runs itself now"
				)
			end
		end

		prevProgress[id] = b.progress
		prevOwned[id] = owned
		prevHadManager[id] = b.hasManager
	end

	-- Money-increase flash on the HUD label.
	if state.money > prevMoney + 0.5 then
		Effects.flashColor(handles.moneyLabel, Theme.colors.money, Theme.colors.text)
		-- Punch scale only on big jumps (purchases reduce, cycles bump).
		local delta = state.money - prevMoney
		if delta > prevMoney * 0.05 and prevMoney > 0 then
			Effects.punchScale(handles.moneyLabel, 0.08)
		end
	end
	prevMoney = state.money
end

-- Render loop ---------------------------------------------------------------

local function totalRevenuePerSecond(): number
	local total = 0
	for id, b in pairs(state.businesses) do
		if b.owned > 0 and b.hasManager then
			local def = Config.BUSINESS_BY_ID[id]
			if def then
				total += Economy.revenuePerSecond(def, b.owned, 1)
			end
		end
	end
	return total
end

-- Smoothly catch displayedMoney up to state.money. Snaps when very close
-- to avoid lingering fractional remainders.
local function tickMoneyDisplay(dt: number)
	local target = state.money
	if math.abs(target - displayedMoney) < 0.01 then
		displayedMoney = target
		return
	end
	-- Time-based exponential decay; ~85% of the gap closes every 0.2s.
	local lerp = 1 - math.exp(-dt * 9)
	displayedMoney += (target - displayedMoney) * lerp
end

local function totalOwnedCount(): number
	local sum = 0
	for _, b in pairs(state.businesses) do
		sum += (b.owned or 0)
	end
	return sum
end

local function refreshUI()
	handles.moneyLabel.Text = Format.money(displayedMoney)
	local rps = totalRevenuePerSecond()
	handles.rpsLabel.Text = if rps > 0
		then "+" .. Format.money(rps) .. " / sec"
		else "Tap a business to earn"

	-- Header gem counter + prestige badge.
	handles.gemLabel.Text = Format.short(state.gems)
	handles.playerPrestigeLabel.Text = "👑 Prestige " .. tostring(state.prestige)

	-- Achievement progress rows (top 3 visible; full list behind View All).
	local metrics = {
		totalEarned = state.totalEarned or 0,
		totalOwned = totalOwnedCount(),
		totalClicks = state.totalClicks or 0,
	}
	for id, row in pairs(handles.rightPanel.achievementRows) do
		local def = Achievements.BY_ID[id]
		if def then
			local progress = Achievements.progress(def, metrics)
			row.progressFill.Size = UDim2.fromScale(progress, 1)
			local already = state.achievements[id] and state.achievements[id].unlocked
			if already then
				row.percentLabel.Text = "DONE"
				row.percentLabel.TextColor3 = Theme.colors.gold
				row.progressFill.BackgroundColor3 = Theme.colors.gold
			else
				row.percentLabel.Text = string.format("%d%%", math.floor(progress * 100))
				row.percentLabel.TextColor3 = Theme.colors.muted
				row.progressFill.BackgroundColor3 = Theme.colors.buyAction
			end
		end
	end

	local qty = currentQty()
	for id, h in pairs(handles.businesses) do
		local def = h.def
		local theme = Theme.businessTheme(id)
		local b = state.businesses[id] or { owned = 0, hasManager = false, progress = 0 }

		h.ownedLabel.Text = "x" .. tostring(b.owned)

		-- Locked overlay until first unit purchased.
		local locked = b.owned <= 0
		if locked then
			h.lockOverlay.Visible = true
			local unlockCost = Economy.unitCost(def, 0)
			h.lockLabel.Text = string.format("🔒  Unlocks at %s", Format.money(unlockCost))
		else
			h.lockOverlay.Visible = false
		end

		-- Progress fill (themed color stays; flashes handled elsewhere).
		local frac = if def.cycleTime > 0 then math.clamp(b.progress / def.cycleTime, 0, 1) else 0
		if b.owned > 0 and (b.hasManager or b.progress > 0) then
			h.progressFill.Size = UDim2.fromScale(frac, 1)
		else
			h.progressFill.Size = UDim2.fromScale(0, 1)
		end

		-- Cycle-payout label (now lives to the right of the bar).
		if b.owned > 0 then
			h.progressLabel.Text = Format.money(Economy.cyclePayout(def, b.owned, 1))
		else
			h.progressLabel.Text = ""
		end

		-- "$X / sec" subtitle matching the mockup.
		if b.owned > 0 then
			h.revenueLabel.Text = Format.money(Economy.revenuePerSecond(def, b.owned, 1)) .. " / sec"
		else
			h.revenueLabel.Text = "Tap to earn your first dollar"
		end

		-- Bonus badge: shown when at least one milestone is active.
		local mult = Economy.milestoneMultiplier(b.owned)
		if mult > 1 then
			h.bonusBadge.Visible = true
			h.bonusBadge.BackgroundColor3 = theme.base
			h.bonusLabel.Text = string.format("x%d BONUS  ▴", mult)
		else
			h.bonusBadge.Visible = false
		end

		-- Buy button cost.
		local n: number
		if qty == "MAX" then
			n = math.max(1, Economy.maxAffordable(def, b.owned, state.money))
		else
			n = tonumber(qty) or 1
		end
		local cost = Economy.bulkCost(def, b.owned, n)
		h.buyQtyLabel.Text = "BUY " .. (qty == "MAX" and ("x" .. n) or formatQty(qty))
		h.buyCostLabel.Text = Format.money(cost)
		local canBuy = state.money >= cost
		h.buyButton.AutoButtonColor = false
		h.buyButton.BackgroundColor3 = canBuy and Theme.colors.buyAction or Theme.colors.buyDim
		buyPulses[id].enabled = canBuy and not locked

		-- Manager mini-toggle (under the bonus badge).
		if b.hasManager then
			h.managerStatus.Text = "✓ " .. def.managerName
			h.managerStatus.TextColor3 = Theme.colors.text
			h.managerButton.BackgroundColor3 = Theme.colors.buyAction
			h.managerButton.BackgroundTransparency = 0.2
			managerPulses[id].enabled = false
		else
			h.managerStatus.Text = "Hire Manager  " .. Format.money(def.managerCost)
			local canHire = state.money >= def.managerCost and b.owned > 0
			h.managerStatus.TextColor3 = canHire and Theme.colors.text or Theme.colors.muted
			h.managerButton.BackgroundColor3 = canHire and Theme.colors.manager or Theme.colors.panelAlt
			h.managerButton.BackgroundTransparency = canHire and 0 or 0.3
			managerPulses[id].enabled = canHire
		end
	end
end

local lastFrame = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = now - lastFrame
	lastFrame = now
	advanceLocal(dt)
	emitEdgeEffects()
	tickMoneyDisplay(dt)
	refreshUI()
end)
