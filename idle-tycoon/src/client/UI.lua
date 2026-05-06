--!strict
-- Construct the entire game UI programmatically. Returns handles that the
-- controller uses to update text, progress, and button states each frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local UI = {}

local COLORS = {
	background = Color3.fromRGB(22, 26, 34),
	panel = Color3.fromRGB(34, 40, 52),
	panelAlt = Color3.fromRGB(44, 52, 66),
	accent = Color3.fromRGB(72, 192, 120),
	accentDim = Color3.fromRGB(48, 128, 80),
	muted = Color3.fromRGB(140, 150, 170),
	text = Color3.fromRGB(240, 244, 250),
	gold = Color3.fromRGB(255, 196, 64),
	danger = Color3.fromRGB(220, 80, 80),
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
	return p
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

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
	frame.BackgroundColor3 = COLORS.panel
	frame.BorderSizePixel = 0
	frame.LayoutOrder = layoutOrder
	frame.Parent = parent
	corner(frame, 12)
	padding(frame, 10)

	-- Left tap area: icon + owned count.
	local tapButton = Instance.new("TextButton")
	tapButton.Name = "Tap"
	tapButton.Size = UDim2.new(0, 90, 1, 0)
	tapButton.Position = UDim2.fromOffset(0, 0)
	tapButton.BackgroundColor3 = COLORS.panelAlt
	tapButton.AutoButtonColor = true
	tapButton.Text = ""
	tapButton.Parent = frame
	corner(tapButton, 10)

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0.65, 0)
	icon.BackgroundTransparency = 1
	icon.Text = def.icon
	icon.TextColor3 = COLORS.text
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.Parent = tapButton

	local ownedLabel = Instance.new("TextLabel")
	ownedLabel.Size = UDim2.new(1, 0, 0.35, 0)
	ownedLabel.Position = UDim2.fromScale(0, 0.65)
	ownedLabel.BackgroundTransparency = 1
	ownedLabel.Text = "x0"
	ownedLabel.TextColor3 = COLORS.gold
	ownedLabel.TextScaled = true
	ownedLabel.Font = Enum.Font.GothamBold
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
	nameLabel.TextColor3 = COLORS.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 18
	nameLabel.Parent = middle

	local progressBar = Instance.new("Frame")
	progressBar.Name = "Progress"
	progressBar.Size = UDim2.new(1, 0, 0, 30)
	progressBar.Position = UDim2.fromOffset(0, 28)
	progressBar.BackgroundColor3 = COLORS.background
	progressBar.BorderSizePixel = 0
	progressBar.Parent = middle
	corner(progressBar, 6)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = COLORS.accent
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBar
	corner(progressFill, 6)

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Size = UDim2.fromScale(1, 1)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "$0"
	progressLabel.TextColor3 = COLORS.text
	progressLabel.Font = Enum.Font.GothamBold
	progressLabel.TextSize = 16
	progressLabel.Parent = progressBar

	local revenueLabel = Instance.new("TextLabel")
	revenueLabel.Size = UDim2.new(1, 0, 0, 20)
	revenueLabel.Position = UDim2.fromOffset(0, 64)
	revenueLabel.BackgroundTransparency = 1
	revenueLabel.Text = "—"
	revenueLabel.TextColor3 = COLORS.muted
	revenueLabel.TextXAlignment = Enum.TextXAlignment.Left
	revenueLabel.Font = Enum.Font.Gotham
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
	buyButton.BackgroundColor3 = COLORS.accent
	buyButton.AutoButtonColor = true
	buyButton.Text = ""
	buyButton.Parent = right
	corner(buyButton, 8)

	local buyQtyLabel = Instance.new("TextLabel")
	buyQtyLabel.Size = UDim2.new(1, 0, 0.45, 0)
	buyQtyLabel.BackgroundTransparency = 1
	buyQtyLabel.Text = "BUY x1"
	buyQtyLabel.TextColor3 = COLORS.text
	buyQtyLabel.Font = Enum.Font.GothamBold
	buyQtyLabel.TextSize = 14
	buyQtyLabel.Parent = buyButton

	local buyCostLabel = Instance.new("TextLabel")
	buyCostLabel.Size = UDim2.new(1, 0, 0.55, 0)
	buyCostLabel.Position = UDim2.fromScale(0, 0.45)
	buyCostLabel.BackgroundTransparency = 1
	buyCostLabel.Text = "$0"
	buyCostLabel.TextColor3 = COLORS.text
	buyCostLabel.Font = Enum.Font.GothamBold
	buyCostLabel.TextSize = 18
	buyCostLabel.Parent = buyButton

	local managerButton = Instance.new("TextButton")
	managerButton.Name = "Manager"
	managerButton.Size = UDim2.new(1, 0, 0, 32)
	managerButton.Position = UDim2.fromOffset(0, 60)
	managerButton.BackgroundColor3 = COLORS.panelAlt
	managerButton.AutoButtonColor = true
	managerButton.Text = ""
	managerButton.Parent = right
	corner(managerButton, 8)

	local managerStatus = Instance.new("TextLabel")
	managerStatus.Size = UDim2.fromScale(1, 1)
	managerStatus.BackgroundTransparency = 1
	managerStatus.Text = "Hire " .. def.managerName
	managerStatus.TextColor3 = COLORS.muted
	managerStatus.Font = Enum.Font.Gotham
	managerStatus.TextSize = 12
	managerStatus.Parent = managerButton

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
	root.BackgroundColor3 = COLORS.background
	root.BorderSizePixel = 0
	root.Parent = screenGui

	-- Header strip with money + RPS + quantity selector.
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 80)
	header.BackgroundColor3 = COLORS.panel
	header.BorderSizePixel = 0
	header.Parent = root
	padding(header, 12)

	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Size = UDim2.new(0.5, 0, 1, 0)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.Text = "$0"
	moneyLabel.TextColor3 = COLORS.gold
	moneyLabel.Font = Enum.Font.GothamBold
	moneyLabel.TextSize = 36
	moneyLabel.Parent = header

	local rpsLabel = Instance.new("TextLabel")
	rpsLabel.Size = UDim2.new(0.3, 0, 1, 0)
	rpsLabel.Position = UDim2.fromScale(0.5, 0)
	rpsLabel.BackgroundTransparency = 1
	rpsLabel.TextXAlignment = Enum.TextXAlignment.Left
	rpsLabel.Text = "—"
	rpsLabel.TextColor3 = COLORS.muted
	rpsLabel.Font = Enum.Font.Gotham
	rpsLabel.TextSize = 18
	rpsLabel.Parent = header

	local qtyButton = Instance.new("TextButton")
	qtyButton.Size = UDim2.new(0, 100, 0, 50)
	qtyButton.Position = UDim2.new(1, -110, 0.5, -25)
	qtyButton.BackgroundColor3 = COLORS.accent
	qtyButton.Text = "BUY x1"
	qtyButton.TextColor3 = COLORS.text
	qtyButton.Font = Enum.Font.GothamBold
	qtyButton.TextSize = 16
	qtyButton.Parent = header
	corner(qtyButton, 8)

	-- Scrolling list of businesses.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Businesses"
	scroll.Size = UDim2.new(1, 0, 1, -80)
	scroll.Position = UDim2.fromOffset(0, 80)
	scroll.BackgroundColor3 = COLORS.background
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = root
	padding(scroll, 12)

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
	notifyContainer.Position = UDim2.new(1, -340, 0, 90)
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
	offlinePopup.Size = UDim2.new(0, 380, 0, 220)
	offlinePopup.Position = UDim2.new(0.5, -190, 0.5, -110)
	offlinePopup.BackgroundColor3 = COLORS.panel
	offlinePopup.Visible = false
	offlinePopup.Parent = screenGui
	corner(offlinePopup, 14)
	stroke(offlinePopup, COLORS.gold, 2)
	padding(offlinePopup, 16)

	local offlineTitle = Instance.new("TextLabel")
	offlineTitle.Size = UDim2.new(1, 0, 0, 32)
	offlineTitle.BackgroundTransparency = 1
	offlineTitle.Text = "Welcome back!"
	offlineTitle.TextColor3 = COLORS.gold
	offlineTitle.Font = Enum.Font.GothamBold
	offlineTitle.TextSize = 24
	offlineTitle.Parent = offlinePopup

	local offlineDurationLabel = Instance.new("TextLabel")
	offlineDurationLabel.Size = UDim2.new(1, 0, 0, 22)
	offlineDurationLabel.Position = UDim2.fromOffset(0, 40)
	offlineDurationLabel.BackgroundTransparency = 1
	offlineDurationLabel.Text = ""
	offlineDurationLabel.TextColor3 = COLORS.muted
	offlineDurationLabel.Font = Enum.Font.Gotham
	offlineDurationLabel.TextSize = 16
	offlineDurationLabel.Parent = offlinePopup

	local offlineAmountLabel = Instance.new("TextLabel")
	offlineAmountLabel.Size = UDim2.new(1, 0, 0, 60)
	offlineAmountLabel.Position = UDim2.fromOffset(0, 70)
	offlineAmountLabel.BackgroundTransparency = 1
	offlineAmountLabel.Text = "$0"
	offlineAmountLabel.TextColor3 = COLORS.text
	offlineAmountLabel.Font = Enum.Font.GothamBold
	offlineAmountLabel.TextSize = 40
	offlineAmountLabel.Parent = offlinePopup

	local offlineCloseButton = Instance.new("TextButton")
	offlineCloseButton.Size = UDim2.new(1, 0, 0, 44)
	offlineCloseButton.Position = UDim2.new(0, 0, 1, -44)
	offlineCloseButton.BackgroundColor3 = COLORS.accent
	offlineCloseButton.Text = "Collect"
	offlineCloseButton.TextColor3 = COLORS.text
	offlineCloseButton.Font = Enum.Font.GothamBold
	offlineCloseButton.TextSize = 18
	offlineCloseButton.Parent = offlinePopup
	corner(offlineCloseButton, 10)

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
	frame.Size = UDim2.new(1, 0, 0, 40)
	frame.BackgroundColor3 = if kind == "error" then COLORS.danger else COLORS.accent
	frame.BorderSizePixel = 0
	frame.Parent = handles.notifyContainer
	corner(frame, 8)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = COLORS.text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Parent = frame

	task.delay(2.5, function()
		frame:Destroy()
	end)
end

return UI
