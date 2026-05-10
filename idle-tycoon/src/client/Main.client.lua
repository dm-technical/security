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

local Theme = require(script.Parent:WaitForChild("Theme"))
local UI = require(script.Parent:WaitForChild("UI"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local buyEvent = Remotes.event("BuyBusiness")
local hireEvent = Remotes.event("HireManager")
local manualEvent = Remotes.event("ManualCollect")
local stateUpdate = Remotes.event("StateUpdate")
local offlineEvent = Remotes.event("OfflineEarnings")
local notify = Remotes.event("Notify")
local getState = Remotes.func("GetState")

local handles = UI.build()

-- Bind tactile feedback on every button at construction time.
Effects.bindPressFeel(handles.qtyButton)
Effects.bindPressFeel(handles.offlineCloseButton)
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
type ClientState = {
	money: number,
	totalEarned: number,
	businesses: { [string]: ClientBusiness },
	lastUpdate: number,
}

local state: ClientState = {
	money = 0,
	totalEarned = 0,
	businesses = {},
	lastUpdate = os.clock(),
}

-- Detection state -----------------------------------------------------------
-- Tracking previous-frame values lets us emit one-shot effects on edges
-- (cycle wrap, milestone cross, money increase) without flooding.

local prevProgress: { [string]: number } = {}
local prevOwned: { [string]: number } = {}
local prevHadManager: { [string]: boolean } = {}
local prevMoney = 0
-- Suppress effects on the very first snapshot so a returning player doesn't
-- see a flood of milestone banners on join.
local snapshotsApplied = 0

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
	state.totalEarned = snap.totalEarned or state.totalEarned
	state.lastUpdate = os.clock()
	for id, b in pairs(snap.businesses or {}) do
		state.businesses[id] = {
			owned = b.owned or 0,
			hasManager = b.hasManager or false,
			progress = b.progress or 0,
		}
	end
	snapshotsApplied += 1
end

stateUpdate.OnClientEvent:Connect(applySnapshot)

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
			Effects.flashBackground(h.progressFill, Theme.colors.goldBright, Theme.colors.accent)
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
		Effects.flashColor(handles.moneyLabel, Theme.colors.goldBright, Theme.colors.gold)
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

local function refreshUI()
	handles.moneyLabel.Text = Format.money(state.money)
	local rps = totalRevenuePerSecond()
	handles.rpsLabel.Text = if rps > 0 then Format.money(rps) .. "/sec" else "Tap to earn"

	local qty = currentQty()
	for id, h in pairs(handles.businesses) do
		local def = h.def
		local b = state.businesses[id] or { owned = 0, hasManager = false, progress = 0 }

		h.ownedLabel.Text = "x" .. tostring(b.owned)

		-- Locked overlay until first unit purchased.
		local locked = b.owned <= 0
		if locked then
			h.lockOverlay.Visible = true
			local unlockCost = Economy.unitCost(def, 0)
			h.lockLabel.Text = string.format("🔒  Unlock for %s", Format.money(unlockCost))
		else
			h.lockOverlay.Visible = false
		end

		-- Progress fill.
		local frac = if def.cycleTime > 0 then math.clamp(b.progress / def.cycleTime, 0, 1) else 0
		if b.owned > 0 and (b.hasManager or b.progress > 0) then
			h.progressFill.Size = UDim2.fromScale(frac, 1)
		else
			h.progressFill.Size = UDim2.fromScale(0, 1)
		end

		-- Cycle-payout label inside the bar.
		if b.owned > 0 then
			h.progressLabel.Text = Format.money(Economy.cyclePayout(def, b.owned, 1))
		else
			h.progressLabel.Text = "Locked"
		end

		-- Revenue subtext.
		if b.owned > 0 then
			h.revenueLabel.Text = string.format(
				"%s/sec  ·  cycle %s",
				Format.money(Economy.revenuePerSecond(def, b.owned, 1)),
				Format.duration(def.cycleTime)
			)
		else
			h.revenueLabel.Text = "Tap a business above to earn your first dollars"
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
		h.buyButton.BackgroundTransparency = canBuy and 0 or 0.5
		h.buyButton.BackgroundColor3 = canBuy and Theme.colors.accent or Theme.colors.dim
		buyPulses[id].enabled = canBuy and not locked

		-- Manager button.
		if b.hasManager then
			h.managerStatus.Text = "✓ " .. def.managerName
			h.managerStatus.TextColor3 = Theme.colors.accentBright
			h.managerButton.BackgroundColor3 = Theme.colors.accentDim
			h.managerButton.BackgroundTransparency = 0.4
			managerPulses[id].enabled = false
		else
			h.managerStatus.Text = string.format(
				"Hire %s — %s",
				def.managerName,
				Format.money(def.managerCost)
			)
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
	refreshUI()
end)
