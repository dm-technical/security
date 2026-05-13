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
local Upgrades = require(Shared.Upgrades)
local Prestige = require(Shared.Prestige)
local Boosts = require(Shared.Boosts)
local Contracts = require(Shared.Contracts)
local Shop = require(Shared.Shop)
local Tutorial = require(Shared.Tutorial)

local Theme = require(script.Parent:WaitForChild("Theme"))
local UI = require(script.Parent:WaitForChild("UI"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))
local Music = require(script.Parent:WaitForChild("Music"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local Background = require(script.Parent:WaitForChild("Background"))
local AgencySetup = require(script.Parent:WaitForChild("AgencySetup"))
local ProgramRenameModal = require(script.Parent:WaitForChild("ProgramRenameModal"))
local TutorialOverlay = require(script.Parent:WaitForChild("TutorialOverlay"))

local buyEvent = Remotes.event("BuyBusiness")
local hireEvent = Remotes.event("HireManager")
local manualEvent = Remotes.event("ManualCollect")
local buyUpgradeEvent = Remotes.event("BuyUpgrade")
local doPrestigeEvent = Remotes.event("DoPrestige")
local activateBoostEvent = Remotes.event("ActivateBoost")
local claimContractEvent = Remotes.event("ClaimContract")
local setAgencyNameEvent = Remotes.event("SetAgencyName")
local setProgramNameEvent = Remotes.event("SetProgramName")
local buyShopItemEvent = Remotes.event("BuyShopItem")
local advanceTutorialEvent = Remotes.event("AdvanceTutorial")
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
local agencySetup = AgencySetup.build(handles.screenGui)
local programRename = ProgramRenameModal.build(handles.screenGui)
local tutorialOverlay = TutorialOverlay.build(handles.screenGui)

tutorialOverlay.onNext = function()
	-- Server validates monotonic step advancement.
	advanceTutorialEvent:FireServer((state.tutorialStep or 0) + 1)
	Sounds.play("uiClick")
end
tutorialOverlay.onSkip = function()
	advanceTutorialEvent:FireServer(Tutorial.DONE)
	Sounds.play("uiClick")
end

-- Track the in-flight rename so we can wait for the snapshot to confirm
-- (or for an error notify) before closing the modal.
local renamePending: { id: string, name: string }? = nil

programRename.onSubmit = function(businessId: string, newName: string)
	-- Trim client-side so the "no-op resubmit" case doesn't strand the modal.
	newName = newName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	setProgramNameEvent:FireServer(businessId, newName)
	renamePending = { id = businessId, name = newName }
	programRename.setError("Saving…")
end

-- Client-side state of the setup flow: stays true until the server accepts
-- a valid name (snapshot returns it back to us non-empty).
local agencyNameSet = false

-- The tutorial step currently rendered on screen, or nil if the overlay is
-- hidden. Lets us re-show only when the step number actually advances.
local shownTutorialStep: number? = nil

agencySetup.onSubmit = function(name: string)
	setAgencyNameEvent:FireServer(name)
	-- Server validates; on success the next snapshot will carry the new
	-- agencyName and we hide the modal below. On failure the Notify event
	-- arrives and we surface the error inline.
end

-- Local mirror of server state. Declared early so the closures below (daily
-- reward countdown, snapshot handler, render loop) all capture the same
-- upvalue. Server data populates it via applySnapshot.
type ClientBusiness = { owned: number, hasManager: boolean, progress: number }
type ClientAchievement = { unlocked: boolean, unlockedAt: number }
type ClientUpgrade = { purchased: boolean, purchasedAt: number }
type ClientBoost = { activeUntil: number, cooldownUntil: number }
type ClientState = {
	money: number,
	gems: number,
	prestige: number,
	agencyName: string,
	totalEarned: number,
	totalEarnedAtLastPrestige: number,
	totalClicks: number,
	businesses: { [string]: ClientBusiness },
	achievements: { [string]: ClientAchievement },
	upgrades: { [string]: ClientUpgrade },
	boosts: { [string]: ClientBoost },
	contracts: { Contracts.Slot },
	programNames: { [string]: string },
	tutorialStep: number,
	dailyClaimedAt: number,
	lastUpdate: number,
}

local state: ClientState = {
	money = 0,
	gems = 0,
	prestige = 0,
	agencyName = "",
	totalEarned = 0,
	totalEarnedAtLastPrestige = 0,
	totalClicks = 0,
	businesses = {},
	achievements = {},
	upgrades = {},
	boosts = {},
	contracts = {},
	programNames = {},
	tutorialStep = 0,
	dailyClaimedAt = 0,
	lastUpdate = os.clock(),
}

-- Returns the player's custom name for a program if set, otherwise the
-- catalog default. Used everywhere we'd render def.name.
local function displayName(def): string
	local custom = state.programNames[def.id]
	if custom and #custom > 0 then return custom end
	return def.name
end

-- Auto-derive a 2-letter launch callsign from the custom name. For single
-- words: first two letters; for multi-word names: first letter of first
-- two words. Falls back to the catalog callsign if no override exists.
local function callsignFor(def): string
	local custom = state.programNames[def.id]
	if not custom or #custom == 0 then
		return def.callsign or "?"
	end
	local words: { string } = {}
	for w in custom:gmatch("%S+") do
		table.insert(words, w)
	end
	if #words == 0 then return def.callsign or "?" end
	if #words == 1 then
		return words[1]:sub(1, 2):upper()
	end
	return (words[1]:sub(1, 1) .. words[2]:sub(1, 1)):upper()
end

-- Player-card name shows the agency name once set, falling back to the
-- player's display name until then. The refresh loop keeps it current.
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

-- Wire sidebar tab clicks. Enabled tabs (Businesses / Upgrades / Prestige)
-- route through showTab; disabled tabs toast "coming soon".
handles.sidebar.onTab = function(id: string, enabled: boolean)
	Sounds.play("uiClick")
	if enabled then
		handles.showTab(id)
	else
		comingSoon(id:sub(1, 1):upper() .. id:sub(2))
	end
end
-- Show businesses by default.
handles.showTab("businesses")

-- Wire the big PRESTIGE button. Two-click confirmation: first click swaps
-- the label to "TAP AGAIN TO CONFIRM" for 4 seconds, second click within
-- that window fires the server.
local prestigeConfirmAt = 0
local PRESTIGE_BUTTON_DEFAULT_TEXT = handles.prestigePanel.prestigeButton.Text
Effects.bindPressFeel(handles.prestigePanel.prestigeButton)
handles.prestigePanel.prestigeButton.MouseButton1Click:Connect(function()
	if not handles.prestigePanel.prestigeButton.Active then
		Sounds.play("purchaseFail")
		return
	end
	local now = os.clock()
	if now - prestigeConfirmAt < 4 then
		-- Confirmation: fire it.
		doPrestigeEvent:FireServer()
		prestigeConfirmAt = 0
		handles.prestigePanel.prestigeButton.Text = PRESTIGE_BUTTON_DEFAULT_TEXT
		Sounds.play("milestone")
	else
		-- First press: arm confirmation.
		prestigeConfirmAt = now
		handles.prestigePanel.prestigeButton.Text = "TAP AGAIN TO CONFIRM"
		Sounds.play("uiClick")
		task.delay(4, function()
			if os.clock() - prestigeConfirmAt >= 4 then
				handles.prestigePanel.prestigeButton.Text = PRESTIGE_BUTTON_DEFAULT_TEXT
			end
		end)
	end
end)

-- Wire RESEARCH button on every tech tree node. The cost pill on each
-- TechNodeCard IS the buy button (single hit area).
for id, h in pairs(handles.techNodes) do
	h.costLabel.MouseButton1Click:Connect(function()
		if not h.costLabel.Active then return end
		buyUpgradeEvent:FireServer(id)
		Sounds.play("uiClick")
	end)
	Effects.bindPressFeel(h.costLabel)
end

-- Wire BUY on every shop item. Server validates affordability + context
-- (slot non-empty for rerolls, boost on cooldown for resets).
for id, h in pairs(handles.shopPanel.items) do
	h.buyButton.MouseButton1Click:Connect(function()
		if not h.buyButton.Active then return end
		buyShopItemEvent:FireServer(id)
		Sounds.play("uiClick")
	end)
	Effects.bindPressFeel(h.buyButton)
end
handles.rightPanel.onBoostClick = function(id: string)
	-- Local cooldown guard so spam-clicks don't flood the server.
	if state.boosts[id] and state.boosts[id].cooldownUntil > os.time() then
		Sounds.play("purchaseFail")
		return
	end
	activateBoostEvent:FireServer(id)
	Sounds.play("milestone")
end
handles.rightPanel.onViewAllClick = function()
	handles.sidebar.setActiveTab("achievements")
	handles.showTab("achievements")
	Sounds.play("uiClick")
end
-- "+" next to the science counter opens the Shop tab — the natural place
-- to actually spend science.
handles.gemAddButton.MouseButton1Click:Connect(function()
	handles.sidebar.setActiveTab("shop")
	handles.showTab("shop")
	Sounds.play("uiClick")
end)
-- Daily reward: fires the server claim, which validates the 24h cooldown.
handles.sidebar.onClaimDaily = function()
	claimDailyEvent:FireServer()
	Sounds.play("uiClick")
end

-- Mission contracts: click CLAIM → server validates completion + credits.
handles.contractsBar.onClaim = function(slotIndex: number)
	claimContractEvent:FireServer(slotIndex)
	Sounds.play("milestone")
end
for _, slot in ipairs(handles.contractsBar.slots) do
	Effects.bindPressFeel(slot.claimButton)
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

-- Detection state -----------------------------------------------------------
-- Tracking previous-frame values lets us emit one-shot effects on edges
-- (cycle wrap, milestone cross, money increase) without flooding.

local prevProgress: { [string]: number } = {}
local prevOwned: { [string]: number } = {}
local prevHadManager: { [string]: boolean } = {}
-- Client-side counter: total mission launches per program in this session,
-- used as the suffix for the launch callsign (e.g. "SR-42"). Not persisted —
-- resets on rejoin, which is fine for a flavor counter.
local flightNumbers: { [string]: number } = {}
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
		-- Optimistic state bumps so the contract progress bar (and cycle
		-- bar) move immediately, without waiting for the next 5Hz server
		-- snapshot. Server's authoritative totalClicks gets reconciled in.
		state.totalClicks += 1
		local b = state.businesses[id]
		if b and b.owned > 0 and not b.hasManager and b.progress <= 0 then
			b.progress = 0.001
		end
		Effects.punchScale(h.tapButton, 0.08)
	end)
	-- Click the program name to open the rename modal.
	h.nameLabel.MouseButton1Click:Connect(function()
		programRename.show(id, state.programNames[id] or "", h.def.name)
		Sounds.play("uiClick")
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
	state.agencyName = snap.agencyName or state.agencyName
	state.tutorialStep = snap.tutorialStep or state.tutorialStep
	state.totalEarned = snap.totalEarned or state.totalEarned
	state.totalEarnedAtLastPrestige = snap.totalEarnedAtLastPrestige or state.totalEarnedAtLastPrestige
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
	-- Replace (not merge) — server sends authoritative full state, and
	-- prestige clears these tables to {} which a merge would silently miss.
	if type(snap.achievements) == "table" then
		state.achievements = {}
		for id, st in pairs(snap.achievements) do
			state.achievements[id] = {
				unlocked = st.unlocked or false,
				unlockedAt = st.unlockedAt or 0,
			}
		end
	end
	if type(snap.upgrades) == "table" then
		state.upgrades = {}
		for id, st in pairs(snap.upgrades) do
			state.upgrades[id] = {
				purchased = st.purchased or false,
				purchasedAt = st.purchasedAt or 0,
			}
		end
	end
	if type(snap.boosts) == "table" then
		state.boosts = {}
		for id, st in pairs(snap.boosts) do
			state.boosts[id] = {
				activeUntil = st.activeUntil or 0,
				cooldownUntil = st.cooldownUntil or 0,
			}
		end
	end
	if type(snap.contracts) == "table" then
		-- Replace the full array — server is authoritative on slot contents.
		state.contracts = {}
		for i, slot in ipairs(snap.contracts) do
			state.contracts[i] = {
				objective = slot.objective or "funds",
				target = slot.target or 0,
				baseline = slot.baseline or 0,
				rewardFunds = slot.rewardFunds or 0,
				rewardScience = slot.rewardScience or 0,
				title = slot.title or "",
				description = slot.description or "",
				issuedAt = slot.issuedAt or 0,
			}
		end
	end
	if type(snap.programNames) == "table" then
		state.programNames = {}
		for id, name in pairs(snap.programNames) do
			if type(name) == "string" and #name > 0 then
				state.programNames[id] = name
			end
		end

		-- Close the rename modal if its target program now matches what we
		-- submitted (success path). Empty submit = reset, so it's confirmed
		-- when programNames[id] is nil.
		if renamePending then
			local got = state.programNames[renamePending.id]
			local expected = renamePending.name
			if (expected == "" and got == nil) or (got ~= nil and got == expected) then
				programRename.hide()
				renamePending = nil
			end
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

	-- First-launch flow: agencyName is empty until the player names their
	-- agency. Show the modal once; hide once a non-empty value comes back.
	if not agencyNameSet then
		if state.agencyName ~= "" then
			agencyNameSet = true
			agencySetup.hide()
		elseif snapshotsApplied == 0 then
			-- First snapshot arrived with no name — open the setup modal.
			agencySetup.show()
		end
	end

	-- Tutorial flow: drives the popup based on tutorialStep. Server bumps
	-- 0 → 1 inside setAgencyName, so the tutorial naturally follows the
	-- agency-setup modal. We only re-show when the step number actually
	-- changes, so the popup doesn't re-animate every snapshot.
	if state.agencyName ~= "" then
		local step = state.tutorialStep or 0
		if Tutorial.isActiveStep(step) then
			if step ~= shownTutorialStep then
				shownTutorialStep = step
				local stepDef = Tutorial.STEPS[step]
				tutorialOverlay.show(step, Tutorial.TOTAL_STEPS, stepDef.title, stepDef.body)
			end
		elseif shownTutorialStep ~= nil then
			-- Step is past TOTAL_STEPS (or DONE) — hide and stop tracking.
			shownTutorialStep = nil
			tutorialOverlay.hide()
		end
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
					"+" .. tostring(def.gemReward) .. " 🔬 science"
				)
				Sounds.play("milestone")
			end)
		end
	end
end)

notify.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.message then
		-- Route validation errors to whichever rename modal is up so they
		-- surface inline next to the input field. Otherwise toast.
		if payload.kind == "error" and agencySetup.screen.Visible then
			agencySetup.setError(payload.message)
			Sounds.play("purchaseFail")
		elseif payload.kind == "error" and programRename.screen.Visible then
			programRename.setError(payload.message)
			renamePending = nil
			Sounds.play("purchaseFail")
		else
			UI.flashNotify(handles, payload.kind or "info", payload.message)
			if payload.kind == "error" then
				Sounds.play("purchaseFail")
			end
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
	local clickMult = Upgrades.clickMultiplier(state)
	local prestigeMult = Prestige.multiplierFor(state.prestige or 0)
	local scienceMult = Upgrades.scienceYieldMultiplier(state)
	local boostMult = Boosts.activeMultipliers(state)
	for id, b in pairs(state.businesses) do
		if b.owned > 0 then
			local def = Config.BUSINESS_BY_ID[id]
			if def then
				-- Same composition as server-side tickBusiness. Each cycle pays
				-- both funds (state.money) and science (state.gems). Science
				-- yield is further multiplied by purchased global_science tech.
				local mult = Upgrades.multiplierFor(state, id) * prestigeMult * boostMult.passive
				if b.hasManager then
					b.progress += dt
					while b.progress >= def.cycleTime do
						b.progress -= def.cycleTime
						local payout = Economy.cyclePayout(def, b.owned, mult)
						state.money += payout
						state.totalEarned += payout
						state.gems += Economy.cycleScience(def, b.owned, mult * scienceMult)
					end
				elseif b.progress > 0 then
					b.progress = math.min(def.cycleTime, b.progress + dt)
					if b.progress >= def.cycleTime then
						local manualMult = mult * clickMult * boostMult.manual
						local payout = Economy.cyclePayout(def, b.owned, manualMult)
						state.money += payout
						state.totalEarned += payout
						state.gems += Economy.cycleScience(def, b.owned, manualMult * scienceMult)
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
			flightNumbers[id] = (flightNumbers[id] or 0) + 1
			local launchTag = callsignFor(def) .. "-" .. tostring(flightNumbers[id])
			Effects.floatingText(h.frame, launchTag .. "  +" .. Format.money(payout))
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
					string.format("%s × %d!", displayName(def), crossed),
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
					displayName(def) .. " runs itself now"
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
	local prestigeMult = Prestige.multiplierFor(state.prestige or 0)
	local boostMult = Boosts.activeMultipliers(state)
	for id, b in pairs(state.businesses) do
		if b.owned > 0 and b.hasManager then
			local def = Config.BUSINESS_BY_ID[id]
			if def then
				local mult = Upgrades.multiplierFor(state, id) * prestigeMult * boostMult.passive
				total += Economy.revenuePerSecond(def, b.owned, mult)
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
		else "Launch a mission to earn funds"

	-- Header gem counter + agency name + generation badge.
	handles.gemLabel.Text = Format.short(state.gems)
	if state.agencyName ~= "" then
		handles.playerNameLabel.Text = state.agencyName
	end
	handles.playerPrestigeLabel.Text = "👑 Generation " .. tostring(state.prestige)

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

		-- Display name (override or default) + a faint ✏️ to advertise that
		-- the label is clickable. Refreshed each frame so the rename takes
		-- effect immediately when the server snapshot lands.
		h.nameLabel.Text = displayName(def) .. "  ✏️"

		-- Locked overlay until first unit purchased. Tech requirement (if any)
		-- takes priority over cost since it must be satisfied first.
		local locked = b.owned <= 0
		if locked then
			h.lockOverlay.Visible = true
			local missing = Upgrades.missingTechFor(state, def.requiresTech)
			if missing then
				h.lockLabel.Text = "🔬  Research " .. missing.name
			else
				local unlockCost = Economy.unitCost(def, 0)
				h.lockLabel.Text = string.format("🔒  Unlocks at %s", Format.money(unlockCost))
			end
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

		-- Combined multiplier (upgrades + prestige + active income boost) so
		-- the card matches what the server actually pays out per cycle.
		local upgradeMult = Upgrades.multiplierFor(state, id)
			* Prestige.multiplierFor(state.prestige or 0)
			* Boosts.activeMultipliers(state).passive

		-- Cycle-payout label (now lives to the right of the bar).
		if b.owned > 0 then
			h.progressLabel.Text = Format.money(Economy.cyclePayout(def, b.owned, upgradeMult))
		else
			h.progressLabel.Text = ""
		end

		-- "$X / sec" subtitle matching the mockup.
		if b.owned > 0 then
			h.revenueLabel.Text = Format.money(Economy.revenuePerSecond(def, b.owned, upgradeMult)) .. " / sec"
		else
			h.revenueLabel.Text = "Tap to launch your first mission"
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
			h.managerStatus.Text = "Hire Director  " .. Format.money(def.managerCost)
			local canHire = state.money >= def.managerCost and b.owned > 0
			h.managerStatus.TextColor3 = canHire and Theme.colors.text or Theme.colors.muted
			h.managerButton.BackgroundColor3 = canHire and Theme.colors.manager or Theme.colors.panelAlt
			h.managerButton.BackgroundTransparency = canHire and 0 or 0.3
			managerPulses[id].enabled = canHire
		end
	end

	-- Tech tree nodes: researched / locked / available (with affordability).
	-- "Locked" here covers BOTH "not enough owned of target program" AND
	-- "prereq tier not yet researched" — Upgrades.unlocked checks both.
	for id, h in pairs(handles.techNodes) do
		local def = h.def
		local researched = Upgrades.isPurchased(state, id)
		local unlocked = Upgrades.unlocked(state, def)
		local canAfford = state.gems >= def.scienceCost

		if researched then
			h.setState("researched", false)
			h.costLabel.Text = "✓ RESEARCHED"
		elseif not unlocked then
			h.setState("locked", false)
			-- Distinguish prereq-locked vs owned-count-locked in the pill.
			if not Upgrades.prereqsMet(state, def) then
				h.costLabel.Text = "🔒 PRIOR TIER"
			else
				h.costLabel.Text = string.format("🔒 OWN %d", def.requiresOwned)
			end
		else
			h.setState("available", canAfford)
			h.costLabel.Text = "🔬 " .. Format.short(def.scienceCost)
		end
	end

	-- Prestige panel: level, earned-this-run progress, eligibility.
	do
		local level = state.prestige or 0
		local earned = Prestige.earnedThisRun(state)
		local req = Prestige.requirementFor(level)
		local can = Prestige.canPrestige(state)
		handles.prestigePanel.setState(level, earned, req, can)
	end

	-- Boost row: per-button timer + state styling.
	for id, b in pairs(handles.rightPanel.boosts) do
		local def = Boosts.BY_ID[id]
		if def then
			local uiState = Boosts.uiState(state, id)
			b.multiplierLabel.Text = string.format("x%g", def.multiplier)
			if uiState == "active" then
				b.timerLabel.Text = Format.duration(Boosts.activeSecondsLeft(state, id))
				b.timerLabel.TextColor3 = Theme.colors.buyBright
				b.button.BackgroundColor3 = Theme.colors.buyAction
			elseif uiState == "cooldown" then
				b.timerLabel.Text = Format.duration(Boosts.cooldownSecondsLeft(state, id))
				b.timerLabel.TextColor3 = Theme.colors.muted
				b.button.BackgroundColor3 = Theme.colors.buyDim
			else
				b.timerLabel.Text = "READY"
				b.timerLabel.TextColor3 = Theme.colors.gold
				b.button.BackgroundColor3 = Theme.colors.panel
			end
		end
	end

	-- Active-boost card on top of the right panel.
	local top, secsLeft = Boosts.topActive(state)
	if top then
		handles.rightPanel.activeBoostNameLabel.Text = top.name
		handles.rightPanel.activeBoostSubLabel.Text = top.description
		handles.rightPanel.activeBoostTimerLabel.Text = Format.duration(secsLeft)
	else
		handles.rightPanel.activeBoostNameLabel.Text = "No active boosts"
		handles.rightPanel.activeBoostSubLabel.Text = "Tap a boost below to start"
		handles.rightPanel.activeBoostTimerLabel.Text = ""
	end

	-- Contracts strip: feed the three slots with current progress.
	local contractMetrics = {
		totalEarned = state.totalEarned or 0,
		gems = state.gems or 0,
		totalClicks = state.totalClicks or 0,
	}
	for i = 1, 3 do
		local slotHandle = handles.contractsBar.slots[i]
		if slotHandle then
			slotHandle.setSlotState(state.contracts[i], contractMetrics)
		end
	end

	-- Shop: per-item state. Three reasons an item can be unavailable
	-- (in priority order): contract slot empty, boost active, boost ready.
	-- Otherwise we just gate on affordability.
	local nowSec = os.time()
	for id, h in pairs(handles.shopPanel.items) do
		local def = h.def
		local cost = def.scienceCost
		local available = true
		local statusText: string? = nil

		if def.effect == "reroll_contract" then
			local slot = def.contractSlot or 0
			if not state.contracts[slot] then
				available = false
				statusText = "Slot is empty"
			end
		elseif def.effect == "reset_boost" then
			local boost = state.boosts[def.boostId or ""]
			if not boost or boost.cooldownUntil <= nowSec then
				available = false
				statusText = "Already ready"
			elseif boost.activeUntil > nowSec then
				available = false
				statusText = "Currently active"
			else
				statusText = string.format("Cooldown: %s",
					Format.duration(boost.cooldownUntil - nowSec))
			end
		end

		if not available then
			h.setState("unavailable", cost, statusText)
		elseif state.gems < cost then
			h.setState("cant_afford", cost, statusText)
		else
			h.setState("available", cost, statusText)
		end
	end

	-- Achievements (Mission Log): update each row's progress + status, and
	-- reorder so unlocked items sink to the bottom UNLOCKED section while
	-- in-progress items sit under the IN PROGRESS header.
	-- LayoutOrder convention: header IN PROGRESS = 1, in-progress rows 2..n,
	-- header UNLOCKED = 1000, unlocked rows 1001..n.
	local achievementMetrics = {
		totalEarned = state.totalEarned or 0,
		gems = state.gems or 0,
		totalClicks = state.totalClicks or 0,
	}
	-- totalOwned isn't on `state` directly; derive from businesses.
	local totalOwned = 0
	for _, b in pairs(state.businesses) do
		totalOwned += (b.owned or 0)
	end
	achievementMetrics.totalOwned = totalOwned

	local inProgressOrder = 2
	local unlockedOrder = 1001
	for id, h in pairs(handles.achievementsPanel.items) do
		local def = h.def
		local current = Achievements.current(def, achievementMetrics)
		local progress = Achievements.progress(def, achievementMetrics)
		local achState = state.achievements[id]
		if achState and achState.unlocked then
			h.setState("unlocked", current, 1, achState.unlockedAt or 0)
			h.frame.LayoutOrder = unlockedOrder
			unlockedOrder += 1
		else
			h.setState("progress", current, progress, 0)
			h.frame.LayoutOrder = inProgressOrder
			inProgressOrder += 1
		end
	end
	-- Hide the UNLOCKED section header if nothing is unlocked yet — keeps
	-- the panel from looking empty-but-decorated for new players.
	handles.achievementsPanel.unlockedHeader.Visible = (unlockedOrder > 1001)
	handles.achievementsPanel.inProgressHeader.Visible = (inProgressOrder > 2)
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
