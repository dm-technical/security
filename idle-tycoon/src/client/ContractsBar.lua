--!strict
-- Bottom-of-screen contracts strip: three slots, each showing the
-- objective's title, a progress bar, the reward, and a claim/in-progress
-- pill that doubles as the buy button. Per-slot state is refreshed from
-- the controller each frame via setSlotState().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contracts = require(Shared.Contracts)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)

local ContractsBar = {}

export type SlotHandle = {
	frame: Frame,
	titleLabel: TextLabel,
	progressBar: Frame,
	progressFill: Frame,
	progressLabel: TextLabel,
	rewardLabel: TextLabel,
	claimButton: TextButton,
	-- slot may be nil while the server hasn't sent state yet.
	setSlotState: (slot: Contracts.Slot?, metrics: Contracts.Metrics) -> (),
}

export type Handle = {
	bar: Frame,
	slots: { SlotHandle },
	-- Fired when the player taps a slot's CLAIM button. Index is 1..3.
	onClaim: ((slotIndex: number) -> ())?,
}

local TINTS = {
	funds   = { base = Theme.colors.buyAction, bright = Theme.colors.buyBright },
	science = { base = Theme.colors.gem,       bright = Theme.colors.gemBright },
	clicks  = { base = Theme.colors.gold,      bright = Theme.colors.goldBright },
}

local function tintForObjective(objective: string?): { base: Color3, bright: Color3 }
	return TINTS[objective or ""] or TINTS.funds
end

local function makeSlotCard(parent: Instance, slotIndex: number, handle: Handle): SlotHandle
	local card = Instance.new("Frame")
	card.Name = "ContractSlot" .. tostring(slotIndex)
	card.Size = UDim2.new(1 / 3, -8, 1, 0)
	card.LayoutOrder = slotIndex
	card.BackgroundColor3 = Theme.colors.panel
	card.BorderSizePixel = 0
	card.Parent = parent
	Theme.corner(card, 12)
	Theme.stroke(card, Theme.colors.panelBorder, 1, 0.2)
	Theme.padding(card, 10)

	-- Header: title (left) + reward chip (right).
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -110, 0, 22)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Loading…"
	titleLabel.TextColor3 = Theme.colors.text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Theme.font.heading
	titleLabel.TextSize = 14
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Parent = card

	-- Progress bar across the middle.
	local progressBar = Instance.new("Frame")
	progressBar.Size = UDim2.new(1, 0, 0, 18)
	progressBar.Position = UDim2.fromOffset(0, 26)
	progressBar.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
	progressBar.BorderSizePixel = 0
	progressBar.ClipsDescendants = true
	progressBar.Parent = card
	Theme.corner(progressBar, 6)

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Theme.colors.buyAction
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBar
	Theme.corner(progressFill, 6)

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Size = UDim2.fromScale(1, 1)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "0 / 0"
	progressLabel.TextColor3 = Theme.colors.text
	progressLabel.Font = Theme.font.bodyBold
	progressLabel.TextSize = 12
	progressLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	progressLabel.TextStrokeTransparency = 0.6
	progressLabel.Parent = progressBar

	-- Footer: reward (left) + claim button (right).
	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.AnchorPoint = Vector2.new(0, 1)
	rewardLabel.Position = UDim2.new(0, 0, 1, 0)
	rewardLabel.Size = UDim2.new(1, -110, 0, 20)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.Text = ""
	rewardLabel.TextColor3 = Theme.colors.muted
	rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
	rewardLabel.Font = Theme.font.bodyBold
	rewardLabel.TextSize = 12
	rewardLabel.Parent = card

	local claimButton = Instance.new("TextButton")
	claimButton.AnchorPoint = Vector2.new(1, 1)
	claimButton.Position = UDim2.new(1, 0, 1, 0)
	claimButton.Size = UDim2.fromOffset(100, 30)
	claimButton.BackgroundColor3 = Theme.colors.buyDim
	claimButton.AutoButtonColor = false
	claimButton.Text = "IN PROGRESS"
	claimButton.TextColor3 = Theme.colors.muted
	claimButton.Font = Theme.font.display
	claimButton.TextSize = 12
	claimButton.Active = false
	claimButton.Parent = card
	Theme.corner(claimButton, 8)

	claimButton.MouseButton1Click:Connect(function()
		if not claimButton.Active then return end
		if handle.onClaim then handle.onClaim(slotIndex) end
	end)

	local slotHandle: SlotHandle = {
		frame = card,
		titleLabel = titleLabel,
		progressBar = progressBar,
		progressFill = progressFill,
		progressLabel = progressLabel,
		rewardLabel = rewardLabel,
		claimButton = claimButton,
		setSlotState = function(_, _) end,
	}

	slotHandle.setSlotState = function(slot: Contracts.Slot?, metrics: Contracts.Metrics)
		if not slot then
			-- No contract in this slot; should be rare (server keeps slots full).
			titleLabel.Text = "—"
			progressFill.Size = UDim2.fromScale(0, 1)
			progressLabel.Text = ""
			rewardLabel.Text = ""
			claimButton.Text = "EMPTY"
			claimButton.Active = false
			claimButton.BackgroundColor3 = Theme.colors.buyDim
			claimButton.TextColor3 = Theme.colors.muted
			return
		end

		local tint = tintForObjective(slot.objective)
		titleLabel.Text = slot.title

		-- Themed fill matches objective: green funds / purple science / gold clicks.
		progressFill.BackgroundColor3 = tint.base

		local progress = Contracts.progress(slot, metrics)
		local frac = Contracts.progressFraction(slot, metrics)
		progressFill.Size = UDim2.fromScale(frac, 1)

		-- Format the X / Y pair appropriately per objective.
		if slot.objective == "funds" then
			progressLabel.Text = Format.money(progress) .. " / " .. Format.money(slot.target)
		elseif slot.objective == "science" then
			progressLabel.Text = Format.short(progress) .. " / " .. Format.short(slot.target)
		else -- clicks
			progressLabel.Text = string.format("%d / %d", math.floor(progress), slot.target)
		end

		-- Reward summary.
		local parts = {}
		if slot.rewardFunds > 0 then
			table.insert(parts, "+" .. Format.money(slot.rewardFunds))
		end
		if slot.rewardScience > 0 then
			table.insert(parts, "+" .. Format.short(slot.rewardScience) .. " 🔬")
		end
		rewardLabel.Text = table.concat(parts, "  ")

		local complete = Contracts.complete(slot, metrics)
		if complete then
			claimButton.Text = "CLAIM"
			claimButton.Active = true
			claimButton.BackgroundColor3 = Theme.colors.buyAction
			claimButton.TextColor3 = Theme.colors.text
		else
			claimButton.Text = "IN PROGRESS"
			claimButton.Active = false
			claimButton.BackgroundColor3 = Theme.colors.buyDim
			claimButton.TextColor3 = Theme.colors.muted
		end
	end

	return slotHandle
end

function ContractsBar.build(parent: Instance): Handle
	local bar = Instance.new("Frame")
	bar.Name = "ContractsBar"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 244, 1, -12)
	bar.Size = UDim2.new(1, -558, 0, 96)
	bar.BackgroundTransparency = 1
	bar.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local handle: Handle = {
		bar = bar,
		slots = {},
		onClaim = nil,
	}

	for i = 1, 3 do
		handle.slots[i] = makeSlotCard(bar, i, handle)
	end

	return handle
end

return ContractsBar
