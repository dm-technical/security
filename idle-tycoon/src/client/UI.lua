--!strict
-- Build the entire game UI programmatically and return handles the
-- controller updates each frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)

local UI = {}

export type BusinessHandle = {
	def: Config.BusinessDef,
	frame: Frame,
	icon: TextLabel,
	ownedLabel: TextLabel,
	progressBar: Frame,
	progressFill: Frame,
	progressLabel: TextLabel,
	revenueLabel: TextLabel,
	buyButton: TextButton,
	buyCostLabel: TextLabel,
	buyQtyLabel: TextLabel,
	managerButton: TextButton,
	managerStatus: TextLabel,
	tapButton: TextButton,
	lockOverlay: Frame,
	lockLabel: TextLabel,
}

export type Handles = {
	screenGui: ScreenGui,
	moneyLabel: TextLabel,
	rpsLabel: TextLabel,
	qtyButton: TextButton,
	businesses: { [string]: BusinessHandle },
	notifyContainer: Frame,
	offlinePopup: Frame,
	offlineAmountLabel: TextLabel,
	offlineDurationLabel: TextLabel,
	offlineCloseButton: TextButton,
}

local function makeBusinessRow(parent: Instance, def: Config.BusinessDef, layoutOrder: number): BusinessHandle
	local frame = Instance.new("Frame")
	frame.Name = "Business_" .. def.id
	frame.Size = UDim2.new(1, 0, 0, 110)
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BorderSizePixel = 0
	frame.LayoutOrder = layoutOrder
	frame.Parent = parent
	Theme.corner(frame, 14)
	Theme.padding(frame, 10)
	Theme.stroke(frame, Theme.colors.backgroundDeep, 1, 0.4)

	-- Left: icon + owned count, doubles as the manual-tap button.
	local tapButton = Instance.new("TextButton")
	tapButton.Name = "Tap"
	tapButton.Size = UDim2.new(0, 90, 1, 0)
	tapButton.Position = UDim2.fromOffset(0, 0)
	tapButton.BackgroundColor3 = Theme.colors.panelAlt
	tapButton.AutoButtonColor = false
	tapButton.Text = ""
	tapButton.Parent = frame
	Theme.corner(tapButton, 10)
	Theme.verticalGradient(tapButton, Theme.colors.panelHi, Theme.colors.panelAlt)

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0.65, 0)
	icon.BackgroundTransparency = 1
	icon.Text = def.icon
	icon.TextColor3 = Theme.colors.text
	icon.TextScaled = true
	icon.Font = Theme.font.heading
	icon.Parent = tapButton

	local ownedLabel = Instance.new("TextLabel")
	ownedLabel.Size = UDim2.new(1, 0, 0.35, 0)
	ownedLabel.Position = UDim2.fromScale(0, 0.65)
	ownedLabel.BackgroundTransparency = 1
	ownedLabel.Text = "x0"
	ownedLabel.TextColor3 = Theme.colors.gold
	ownedLabel.TextScaled = true
	ownedLabel.Font = Theme.font.display
	ownedLabel.Parent = tapButton

	-- Center: name, progress bar, revenue.
	local middle = Instance.new("Frame")
	middle.Name = "Middle"
	middle.Size = UDim2.new(1, -260, 1, 0)
	middle.Position = UDim2.fromOffset(100, 0)
	middle.BackgroundTransparency = 1
	middle.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 22)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = Theme.colors.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Theme.font.heading
	nameLabel.TextSize = 18
	nameLabel.Parent = middle

	local progressBar = Instance.new("Frame")
	progressBar.Name = "Progress"
	progressBar.Size = UDim2.new(1, 0, 0, 30)
	progressBar.Position = UDim2.fromOffset(0, 28)
	progressBar.BackgroundColor3 = Theme.colors.backgroundDeep
	progressBar.BorderSizePixel = 0
	progressBar.ClipsDescendants = true
	progressBar.Parent = middle
	Theme.corner(progressBar, 6)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Theme.colors.accent
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBar
	Theme.corner(progressFill, 6)

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Size = UDim2.fromScale(1, 1)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "$0"
	progressLabel.TextColor3 = Theme.colors.text
	progressLabel.Font = Theme.font.heading
	progressLabel.TextSize = 16
	progressLabel.TextStrokeTransparency = 0.7
	progressLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	progressLabel.Parent = progressBar

	local revenueLabel = Instance.new("TextLabel")
	revenueLabel.Size = UDim2.new(1, 0, 0, 20)
	revenueLabel.Position = UDim2.fromOffset(0, 64)
	revenueLabel.BackgroundTransparency = 1
	revenueLabel.Text = "—"
	revenueLabel.TextColor3 = Theme.colors.muted
	revenueLabel.TextXAlignment = Enum.TextXAlignment.Left
	revenueLabel.Font = Theme.font.body
	revenueLabel.TextSize = 14
	revenueLabel.Parent = middle

	-- Right: buy + manager buttons stacked.
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.Size = UDim2.new(0, 150, 1, 0)
	right.Position = UDim2.new(1, -150, 0, 0)
	right.BackgroundTransparency = 1
	right.Parent = frame

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "Buy"
	buyButton.Size = UDim2.new(1, 0, 0, 56)
	buyButton.BackgroundColor3 = Theme.colors.accent
	buyButton.AutoButtonColor = false
	buyButton.Text = ""
	buyButton.Parent = right
	Theme.corner(buyButton, 10)

	local buyQtyLabel = Instance.new("TextLabel")
	buyQtyLabel.Size = UDim2.new(1, 0, 0.4, 0)
	buyQtyLabel.BackgroundTransparency = 1
	buyQtyLabel.Text = "BUY x1"
	buyQtyLabel.TextColor3 = Theme.colors.text
	buyQtyLabel.Font = Theme.font.heading
	buyQtyLabel.TextSize = 13
	buyQtyLabel.Parent = buyButton

	local buyCostLabel = Instance.new("TextLabel")
	buyCostLabel.Size = UDim2.new(1, 0, 0.6, 0)
	buyCostLabel.Position = UDim2.fromScale(0, 0.4)
	buyCostLabel.BackgroundTransparency = 1
	buyCostLabel.Text = "$0"
	buyCostLabel.TextColor3 = Theme.colors.text
	buyCostLabel.Font = Theme.font.display
	buyCostLabel.TextSize = 18
	buyCostLabel.TextStrokeTransparency = 0.7
	buyCostLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	buyCostLabel.Parent = buyButton

	local managerButton = Instance.new("TextButton")
	managerButton.Name = "Manager"
	managerButton.Size = UDim2.new(1, 0, 0, 36)
	managerButton.Position = UDim2.fromOffset(0, 64)
	managerButton.BackgroundColor3 = Theme.colors.panelAlt
	managerButton.AutoButtonColor = false
	managerButton.Text = ""
	managerButton.Parent = right
	Theme.corner(managerButton, 8)

	local managerStatus = Instance.new("TextLabel")
	managerStatus.Size = UDim2.fromScale(1, 1)
	managerStatus.BackgroundTransparency = 1
	managerStatus.Text = "Hire " .. def.managerName
	managerStatus.TextColor3 = Theme.colors.muted
	managerStatus.Font = Theme.font.bodyBold
	managerStatus.TextSize = 12
	managerStatus.Parent = managerButton

	-- Lock overlay covers icon + progress columns only (buy button stays
	-- clickable so the player can unlock). Active=false keeps it visual.
	local lockOverlay = Instance.new("Frame")
	lockOverlay.Name = "Lock"
	lockOverlay.Size = UDim2.new(1, -160, 1, 0)
	lockOverlay.Position = UDim2.fromOffset(0, 0)
	lockOverlay.BackgroundColor3 = Theme.colors.backgroundDeep
	lockOverlay.BackgroundTransparency = 0.2
	lockOverlay.BorderSizePixel = 0
	lockOverlay.ZIndex = 5
	lockOverlay.Active = false
	lockOverlay.Visible = false
	lockOverlay.Parent = frame
	Theme.corner(lockOverlay, 12)

	local lockLabel = Instance.new("TextLabel")
	lockLabel.Size = UDim2.fromScale(1, 1)
	lockLabel.BackgroundTransparency = 1
	lockLabel.Text = "🔒  Unlock for $0"
	lockLabel.TextColor3 = Theme.colors.text
	lockLabel.Font = Theme.font.heading
	lockLabel.TextSize = 18
	lockLabel.TextStrokeTransparency = 0.5
	lockLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	lockLabel.ZIndex = 6
	lockLabel.Parent = lockOverlay

	return {
		def = def,
		frame = frame,
		icon = icon,
		ownedLabel = ownedLabel,
		progressBar = progressBar,
		progressFill = progressFill,
		progressLabel = progressLabel,
		revenueLabel = revenueLabel,
		buyButton = buyButton,
		buyCostLabel = buyCostLabel,
		buyQtyLabel = buyQtyLabel,
		managerButton = managerButton,
		managerStatus = managerStatus,
		tapButton = tapButton,
		lockOverlay = lockOverlay,
		lockLabel = lockLabel,
	}
end

function UI.build(): Handles
	local player = Players.LocalPlayer
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "IdleTycoonUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.colors.background
	root.BorderSizePixel = 0
	root.Parent = screenGui
	Theme.verticalGradient(root, Theme.colors.background, Theme.colors.backgroundDeep)

	-- Header strip.
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 90)
	header.BackgroundColor3 = Theme.colors.panel
	header.BorderSizePixel = 0
	header.Parent = root
	Theme.padding(header, 14)
	Theme.verticalGradient(header, Theme.colors.panel, Theme.colors.background)

	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Size = UDim2.new(0.5, 0, 1, 0)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.Text = "$0"
	moneyLabel.TextColor3 = Theme.colors.gold
	moneyLabel.Font = Theme.font.display
	moneyLabel.TextSize = 40
	moneyLabel.TextStrokeTransparency = 0.6
	moneyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	moneyLabel.Parent = header

	local rpsLabel = Instance.new("TextLabel")
	rpsLabel.Size = UDim2.new(0.3, 0, 1, 0)
	rpsLabel.Position = UDim2.fromScale(0.5, 0)
	rpsLabel.BackgroundTransparency = 1
	rpsLabel.TextXAlignment = Enum.TextXAlignment.Left
	rpsLabel.Text = "Tap to earn"
	rpsLabel.TextColor3 = Theme.colors.muted
	rpsLabel.Font = Theme.font.bodyBold
	rpsLabel.TextSize = 18
	rpsLabel.Parent = header

	local qtyButton = Instance.new("TextButton")
	qtyButton.Size = UDim2.new(0, 110, 0, 56)
	qtyButton.Position = UDim2.new(1, -120, 0.5, -28)
	qtyButton.BackgroundColor3 = Theme.colors.accent
	qtyButton.AutoButtonColor = false
	qtyButton.Text = "BUY x1"
	qtyButton.TextColor3 = Theme.colors.text
	qtyButton.Font = Theme.font.heading
	qtyButton.TextSize = 18
	qtyButton.Parent = header
	Theme.corner(qtyButton, 10)

	-- Scrolling list of businesses.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Businesses"
	scroll.Size = UDim2.new(1, 0, 1, -90)
	scroll.Position = UDim2.fromOffset(0, 90)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.colors.muted
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = root
	Theme.padding(scroll, 12)

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroll

	local businesses: { [string]: BusinessHandle } = {}
	for i, def in ipairs(Config.BUSINESSES) do
		businesses[def.id] = makeBusinessRow(scroll, def, i)
	end

	-- Notification stack (top-right).
	local notifyContainer = Instance.new("Frame")
	notifyContainer.Name = "Notifications"
	notifyContainer.Size = UDim2.new(0, 320, 1, -100)
	notifyContainer.Position = UDim2.new(1, -340, 0, 100)
	notifyContainer.BackgroundTransparency = 1
	notifyContainer.Parent = screenGui
	local notifyLayout = Instance.new("UIListLayout")
	notifyLayout.Padding = UDim.new(0, 6)
	notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notifyLayout.Parent = notifyContainer

	-- Offline-earnings modal.
	local offlinePopup = Instance.new("Frame")
	offlinePopup.Name = "OfflinePopup"
	offlinePopup.Size = UDim2.new(0, 400, 0, 240)
	offlinePopup.Position = UDim2.new(0.5, -200, 0.5, -120)
	offlinePopup.BackgroundColor3 = Theme.colors.panel
	offlinePopup.Visible = false
	offlinePopup.ZIndex = 100
	offlinePopup.Parent = screenGui
	Theme.corner(offlinePopup, 16)
	Theme.stroke(offlinePopup, Theme.colors.gold, 2)
	Theme.padding(offlinePopup, 18)
	Theme.verticalGradient(offlinePopup, Theme.colors.panel, Theme.colors.panelAlt)

	local offlineTitle = Instance.new("TextLabel")
	offlineTitle.Size = UDim2.new(1, 0, 0, 36)
	offlineTitle.BackgroundTransparency = 1
	offlineTitle.Text = "Welcome back!"
	offlineTitle.TextColor3 = Theme.colors.gold
	offlineTitle.Font = Theme.font.display
	offlineTitle.TextSize = 26
	offlineTitle.ZIndex = 101
	offlineTitle.Parent = offlinePopup

	local offlineDurationLabel = Instance.new("TextLabel")
	offlineDurationLabel.Size = UDim2.new(1, 0, 0, 22)
	offlineDurationLabel.Position = UDim2.fromOffset(0, 44)
	offlineDurationLabel.BackgroundTransparency = 1
	offlineDurationLabel.Text = ""
	offlineDurationLabel.TextColor3 = Theme.colors.muted
	offlineDurationLabel.Font = Theme.font.body
	offlineDurationLabel.TextSize = 16
	offlineDurationLabel.ZIndex = 101
	offlineDurationLabel.Parent = offlinePopup

	local offlineAmountLabel = Instance.new("TextLabel")
	offlineAmountLabel.Size = UDim2.new(1, 0, 0, 70)
	offlineAmountLabel.Position = UDim2.fromOffset(0, 76)
	offlineAmountLabel.BackgroundTransparency = 1
	offlineAmountLabel.Text = "$0"
	offlineAmountLabel.TextColor3 = Theme.colors.text
	offlineAmountLabel.Font = Theme.font.display
	offlineAmountLabel.TextSize = 44
	offlineAmountLabel.TextStrokeTransparency = 0.5
	offlineAmountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	offlineAmountLabel.ZIndex = 101
	offlineAmountLabel.Parent = offlinePopup

	local offlineCloseButton = Instance.new("TextButton")
	offlineCloseButton.Size = UDim2.new(1, 0, 0, 48)
	offlineCloseButton.Position = UDim2.new(0, 0, 1, -48)
	offlineCloseButton.BackgroundColor3 = Theme.colors.accent
	offlineCloseButton.AutoButtonColor = false
	offlineCloseButton.Text = "Collect"
	offlineCloseButton.TextColor3 = Theme.colors.text
	offlineCloseButton.Font = Theme.font.heading
	offlineCloseButton.TextSize = 20
	offlineCloseButton.ZIndex = 101
	offlineCloseButton.Parent = offlinePopup
	Theme.corner(offlineCloseButton, 12)

	return {
		screenGui = screenGui,
		moneyLabel = moneyLabel,
		rpsLabel = rpsLabel,
		qtyButton = qtyButton,
		businesses = businesses,
		notifyContainer = notifyContainer,
		offlinePopup = offlinePopup,
		offlineAmountLabel = offlineAmountLabel,
		offlineDurationLabel = offlineDurationLabel,
		offlineCloseButton = offlineCloseButton,
	}
end

function UI.flashNotify(handles: Handles, kind: string, message: string)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 44)
	frame.BackgroundColor3 = if kind == "error" then Theme.colors.danger else Theme.colors.accent
	frame.BorderSizePixel = 0
	frame.Parent = handles.notifyContainer
	Theme.corner(frame, 10)
	Theme.stroke(frame, Color3.new(0, 0, 0), 1, 0.6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = Theme.colors.text
	label.Font = Theme.font.heading
	label.TextSize = 14
	label.Parent = frame

	task.delay(2.5, function()
		frame:Destroy()
	end)
end

return UI
