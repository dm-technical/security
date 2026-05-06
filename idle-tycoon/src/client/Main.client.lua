--!strict
-- Client controller. Builds the UI, requests initial state, listens for
-- server snapshots, and locally interpolates progress bars between updates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent:WaitForChild("UI"))

local buyEvent = Remotes.event("BuyBusiness")
local hireEvent = Remotes.event("HireManager")
local manualEvent = Remotes.event("ManualCollect")
local stateUpdate = Remotes.event("StateUpdate")
local offlineEvent = Remotes.event("OfflineEarnings")
local notify = Remotes.event("Notify")
local getState = Remotes.func("GetState")

local handles = UI.build()

-- Local mirror of server state. Money and progress are interpolated locally
-- between snapshots to keep the UI smooth at high FPS.
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

-- Buy quantity selector cycles through Config.BUY_QUANTITIES.
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
end)

-- Wire per-business buttons.
for id, h in pairs(handles.businesses) do
	h.buyButton.MouseButton1Click:Connect(function()
		buyEvent:FireServer(id, currentQty())
	end)
	h.managerButton.MouseButton1Click:Connect(function()
		hireEvent:FireServer(id)
	end)
	h.tapButton.MouseButton1Click:Connect(function()
		manualEvent:FireServer(id)
	end)
end

-- Apply a state snapshot from the server.
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
end

stateUpdate.OnClientEvent:Connect(applySnapshot)

notify.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.message then
		UI.flashNotify(handles, payload.kind or "info", payload.message)
	end
end)

offlineEvent.OnClientEvent:Connect(function(payload)
	if not payload or not payload.amount or payload.amount <= 0 then return end
	handles.offlineAmountLabel.Text = Format.money(payload.amount)
	handles.offlineDurationLabel.Text =
		"You were away for " .. Format.duration(payload.seconds) .. "."
	handles.offlinePopup.Visible = true
end)

handles.offlineCloseButton.MouseButton1Click:Connect(function()
	handles.offlinePopup.Visible = false
end)

-- Pull the initial snapshot. The server may also push it via StateUpdate
-- on first join, but invoking here covers reconnects and respawns.
task.spawn(function()
	local ok, snap = pcall(function()
		return getState:InvokeServer()
	end)
	if ok then
		applySnapshot(snap)
	end
end)

-- Render loop ---------------------------------------------------------------
-- We extrapolate progress between server snapshots: managed businesses
-- advance freely; manual ones only move once started by ManualCollect.

local function advanceLocal(dt: number)
	for id, b in pairs(state.businesses) do
		if b.owned > 0 then
			if b.hasManager then
				b.progress += dt
				local def = Config.BUSINESS_BY_ID[id]
				if def then
					-- Wrap visually so we don't hold at 100% awaiting the server.
					while b.progress >= def.cycleTime do
						b.progress -= def.cycleTime
						-- Optimistically credit money so the wallet ticks smoothly;
						-- the next server snapshot is the source of truth.
						state.money += Economy.cyclePayout(def, b.owned, 1)
					end
				end
			elseif b.progress > 0 then
				local def = Config.BUSINESS_BY_ID[id]
				if def then
					b.progress = math.min(def.cycleTime, b.progress + dt)
				end
			end
		end
	end
end

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
			h.revenueLabel.Text = "Buy your first to start earning"
		end

		-- Buy button cost.
		local n: number
		if qty == "MAX" then
			n = math.max(1, Economy.maxAffordable(def, b.owned, state.money))
		else
			n = tonumber(qty) or 1
		end
		local cost = Economy.bulkCost(def, b.owned, n)
		h.buyQtyLabel.Text = "BUY " .. formatQty(qty == "MAX" and ("x" .. n) or qty)
		h.buyCostLabel.Text = Format.money(cost)
		h.buyButton.Active = state.money >= cost
		h.buyButton.AutoButtonColor = state.money >= cost
		h.buyButton.BackgroundTransparency = state.money >= cost and 0 or 0.4

		-- Manager button.
		if b.hasManager then
			h.managerStatus.Text = def.managerName .. " ✓"
			h.managerButton.Active = false
			h.managerButton.AutoButtonColor = false
			h.managerButton.BackgroundTransparency = 0.5
		else
			h.managerStatus.Text = string.format(
				"Hire %s — %s",
				def.managerName,
				Format.money(def.managerCost)
			)
			local canHire = state.money >= def.managerCost and b.owned > 0
			h.managerButton.Active = canHire
			h.managerButton.AutoButtonColor = canHire
			h.managerButton.BackgroundTransparency = canHire and 0 or 0.4
		end
	end
end

local lastFrame = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = now - lastFrame
	lastFrame = now
	advanceLocal(dt)
	refreshUI()
end)
