--!strict
-- Builds a single business row in the mockup style:
-- [large themed icon card with multiplier badge] [name + /sec + themed progress bar + cycle $] [BUY stack with bonus badge]
--
-- Returns the handle struct expected by Main.client.lua's refreshUI loop
-- (same field names as previous UI.lua revisions for compatibility).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)

local BusinessCard = {}

export type Handle = {
	def: Config.BusinessDef,
	frame: Frame,
	icon: TextLabel,
	iconImage: ImageLabel,
	iconCard: TextButton, -- the big themed left card; doubles as manual-tap button
	ownedLabel: TextLabel, -- the "x197" multiplier badge
	nameLabel: TextButton, -- clickable program name; opens rename modal
	progressBar: Frame,
	progressFill: Frame,
	progressLabel: TextLabel,
	revenueLabel: TextLabel, -- "/sec" subtitle
	buyButton: TextButton,
	buyCostLabel: TextLabel,
	buyQtyLabel: TextLabel,
	bonusBadge: Frame,
	bonusLabel: TextLabel,
	managerButton: TextButton, -- preserved for compat; shown under BUY stack
	managerStatus: TextLabel,
	tapButton: TextButton, -- alias to iconCard for back-compat
	lockOverlay: Frame,
	lockLabel: TextLabel,
}

function BusinessCard.build(parent: Instance, def: Config.BusinessDef, layoutOrder: number): Handle
	local theme = Theme.businessTheme(def.id)

	local frame = Instance.new("Frame")
	frame.Name = "Business_" .. def.id
	frame.Size = UDim2.new(1, 0, 0, 124)
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BorderSizePixel = 0
	frame.LayoutOrder = layoutOrder
	frame.Parent = parent
	Theme.corner(frame, 16)
	Theme.stroke(frame, Theme.colors.panelBorder, 1, 0.2)
	Theme.padding(frame, 12)

	-- Large themed icon card on the left ----------------------------------
	local iconCard = Instance.new("TextButton")
	iconCard.Name = "IconCard"
	iconCard.Size = UDim2.fromOffset(100, 100)
	iconCard.Position = UDim2.fromOffset(0, 0)
	iconCard.BackgroundColor3 = theme.base
	iconCard.AutoButtonColor = false
	iconCard.Text = ""
	iconCard.Parent = frame
	Theme.corner(iconCard, 16)
	Theme.stroke(iconCard, theme.bright, 2, 0.2)
	Theme.verticalGradient(iconCard, theme.bright, theme.base)

	-- Emoji fallback icon, shown when iconAssetId is empty.
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Text = def.icon
	icon.TextColor3 = Theme.colors.text
	icon.TextScaled = true
	icon.Font = Theme.font.heading
	icon.TextStrokeColor3 = Color3.new(0, 0, 0)
	icon.TextStrokeTransparency = 0.5
	icon.Parent = iconCard

	-- Custom image (hidden unless iconAssetId is configured).
	local iconImage = Instance.new("ImageLabel")
	iconImage.Size = UDim2.fromScale(1, 1)
	iconImage.BackgroundTransparency = 1
	iconImage.Image = def.iconAssetId
	iconImage.ScaleType = Enum.ScaleType.Fit
	iconImage.Visible = def.iconAssetId ~= ""
	iconImage.Parent = iconCard
	if iconImage.Visible then
		icon.Visible = false
	end

	-- Multiplier badge on the bottom of the icon card ("x197").
	local ownedBadge = Instance.new("Frame")
	ownedBadge.AnchorPoint = Vector2.new(0.5, 1)
	ownedBadge.Position = UDim2.new(0.5, 0, 1, 6)
	ownedBadge.Size = UDim2.fromOffset(54, 24)
	ownedBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	ownedBadge.BorderSizePixel = 0
	ownedBadge.ZIndex = 4
	ownedBadge.Parent = iconCard
	Theme.corner(ownedBadge, 8)
	Theme.stroke(ownedBadge, theme.bright, 1, 0.3)

	local ownedLabel = Instance.new("TextLabel")
	ownedLabel.Size = UDim2.fromScale(1, 1)
	ownedLabel.BackgroundTransparency = 1
	ownedLabel.Text = "x0"
	ownedLabel.TextColor3 = theme.bright
	ownedLabel.Font = Theme.font.display
	ownedLabel.TextSize = 13
	ownedLabel.ZIndex = 5
	ownedLabel.Parent = ownedBadge

	-- Middle column: name, /sec, progress bar, cycle payout text -----------
	local middle = Instance.new("Frame")
	middle.Name = "Middle"
	middle.Size = UDim2.new(1, -340, 1, 0)
	middle.Position = UDim2.fromOffset(120, 0)
	middle.BackgroundTransparency = 1
	middle.Parent = frame

	-- Name is a TextButton so the player can click it to rename the program.
	-- A small ✏️ suffix is appended in refreshUI to advertise the action.
	local nameLabel = Instance.new("TextButton")
	nameLabel.Size = UDim2.new(1, 0, 0, 24)
	nameLabel.BackgroundTransparency = 1
	nameLabel.AutoButtonColor = false
	nameLabel.Text = def.name
	nameLabel.TextColor3 = Theme.colors.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Theme.font.heading
	nameLabel.TextSize = 22
	nameLabel.Parent = middle

	local revenueLabel = Instance.new("TextLabel")
	revenueLabel.Size = UDim2.new(1, 0, 0, 18)
	revenueLabel.Position = UDim2.fromOffset(0, 24)
	revenueLabel.BackgroundTransparency = 1
	revenueLabel.Text = "$0 / sec"
	revenueLabel.TextColor3 = Theme.colors.muted
	revenueLabel.TextXAlignment = Enum.TextXAlignment.Left
	revenueLabel.Font = Theme.font.body
	revenueLabel.TextSize = 14
	revenueLabel.Parent = middle

	-- Themed progress bar with cycle payout text inside it.
	local progressBar = Instance.new("Frame")
	progressBar.Name = "Progress"
	progressBar.Size = UDim2.new(1, -140, 0, 24)
	progressBar.Position = UDim2.fromOffset(0, 56)
	progressBar.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
	progressBar.BorderSizePixel = 0
	progressBar.ClipsDescendants = true
	progressBar.Parent = middle
	Theme.corner(progressBar, 12)
	Theme.stroke(progressBar, theme.base, 1, 0.5)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = theme.base
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBar
	Theme.corner(progressFill, 12)

	-- Cycle payout shown to the right of the bar, in money green.
	local progressLabel = Instance.new("TextLabel")
	progressLabel.AnchorPoint = Vector2.new(1, 0.5)
	progressLabel.Position = UDim2.new(1, 0, 0, 68)
	progressLabel.Size = UDim2.fromOffset(130, 24)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "$0"
	progressLabel.TextColor3 = Theme.colors.money
	progressLabel.TextXAlignment = Enum.TextXAlignment.Right
	progressLabel.Font = Theme.font.heading
	progressLabel.TextSize = 20
	progressLabel.Parent = middle

	-- Right column: BUY button + bonus badge + (compat) manager toggle -----
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.Size = UDim2.new(0, 180, 1, 0)
	right.Position = UDim2.new(1, -180, 0, 0)
	right.BackgroundTransparency = 1
	right.Parent = frame

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "Buy"
	buyButton.Size = UDim2.new(1, 0, 0, 64)
	buyButton.BackgroundColor3 = Theme.colors.buyAction
	buyButton.AutoButtonColor = false
	buyButton.Text = ""
	buyButton.Parent = right
	Theme.corner(buyButton, 14)
	Theme.stroke(buyButton, Theme.colors.buyBright, 2, 0)

	local buyQtyLabel = Instance.new("TextLabel")
	buyQtyLabel.Size = UDim2.new(1, 0, 0.4, 0)
	buyQtyLabel.BackgroundTransparency = 1
	buyQtyLabel.Text = "BUY x1"
	buyQtyLabel.TextColor3 = Theme.colors.text
	buyQtyLabel.Font = Theme.font.heading
	buyQtyLabel.TextSize = 14
	buyQtyLabel.Parent = buyButton

	local buyCostLabel = Instance.new("TextLabel")
	buyCostLabel.Size = UDim2.new(1, 0, 0.6, 0)
	buyCostLabel.Position = UDim2.fromScale(0, 0.4)
	buyCostLabel.BackgroundTransparency = 1
	buyCostLabel.Text = "$0"
	buyCostLabel.TextColor3 = Theme.colors.text
	buyCostLabel.Font = Theme.font.display
	buyCostLabel.TextSize = 20
	buyCostLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	buyCostLabel.TextStrokeTransparency = 0.5
	buyCostLabel.Parent = buyButton

	-- Bonus badge under the BUY button ("x2 BONUS" with a small arrow).
	local bonusBadge = Instance.new("Frame")
	bonusBadge.Name = "Bonus"
	bonusBadge.Size = UDim2.new(1, 0, 0, 22)
	bonusBadge.Position = UDim2.fromOffset(0, 68)
	bonusBadge.BackgroundColor3 = theme.base
	bonusBadge.BorderSizePixel = 0
	bonusBadge.Visible = false
	bonusBadge.Parent = right
	Theme.corner(bonusBadge, 8)

	local bonusLabel = Instance.new("TextLabel")
	bonusLabel.Size = UDim2.fromScale(1, 1)
	bonusLabel.BackgroundTransparency = 1
	bonusLabel.Text = "x2 BONUS ▴"
	bonusLabel.TextColor3 = Theme.colors.text
	bonusLabel.Font = Theme.font.heading
	bonusLabel.TextSize = 12
	bonusLabel.Parent = bonusBadge

	-- Manager toggle (mockup hides this; we keep a thin button to preserve
	-- the mechanic without crowding the row).
	local managerButton = Instance.new("TextButton")
	managerButton.Name = "Manager"
	managerButton.Size = UDim2.new(1, 0, 0, 22)
	managerButton.Position = UDim2.fromOffset(0, 96)
	managerButton.BackgroundColor3 = Theme.colors.manager
	managerButton.AutoButtonColor = false
	managerButton.Text = ""
	managerButton.Parent = right
	Theme.corner(managerButton, 6)

	local managerStatus = Instance.new("TextLabel")
	managerStatus.Size = UDim2.fromScale(1, 1)
	managerStatus.BackgroundTransparency = 1
	managerStatus.Text = "Hire " .. def.managerName
	managerStatus.TextColor3 = Theme.colors.text
	managerStatus.Font = Theme.font.bodyBold
	managerStatus.TextSize = 11
	managerStatus.Parent = managerButton

	-- Lock overlay (visual only — buy button stays clickable).
	local lockOverlay = Instance.new("Frame")
	lockOverlay.Name = "Lock"
	lockOverlay.Size = UDim2.new(1, -200, 1, 0)
	lockOverlay.Position = UDim2.fromOffset(0, 0)
	lockOverlay.BackgroundColor3 = Color3.fromRGB(15, 17, 30)
	lockOverlay.BackgroundTransparency = 0.15
	lockOverlay.BorderSizePixel = 0
	lockOverlay.ZIndex = 10
	lockOverlay.Active = false
	lockOverlay.Visible = false
	lockOverlay.Parent = frame
	Theme.corner(lockOverlay, 14)

	local lockLabel = Instance.new("TextLabel")
	lockLabel.Size = UDim2.fromScale(1, 1)
	lockLabel.BackgroundTransparency = 1
	lockLabel.Text = "🔒  Unlocks at $0"
	lockLabel.TextColor3 = Theme.colors.muted
	lockLabel.Font = Theme.font.heading
	lockLabel.TextSize = 18
	lockLabel.ZIndex = 11
	lockLabel.Parent = lockOverlay

	return {
		def = def,
		frame = frame,
		icon = icon,
		iconImage = iconImage,
		iconCard = iconCard,
		ownedLabel = ownedLabel,
		nameLabel = nameLabel,
		progressBar = progressBar,
		progressFill = progressFill,
		progressLabel = progressLabel,
		revenueLabel = revenueLabel,
		buyButton = buyButton,
		buyCostLabel = buyCostLabel,
		buyQtyLabel = buyQtyLabel,
		bonusBadge = bonusBadge,
		bonusLabel = bonusLabel,
		managerButton = managerButton,
		managerStatus = managerStatus,
		tapButton = iconCard, -- back-compat alias
		lockOverlay = lockOverlay,
		lockLabel = lockLabel,
	}
end

return BusinessCard
