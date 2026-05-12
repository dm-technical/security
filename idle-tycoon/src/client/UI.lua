--!strict
-- Top-level UI builder. Composes the three-column layout:
--   [PlayerCard] [HeaderBar with money + gems + settings gear]
--   [LeftSidebar nav] [center: scrolling BusinessCards] [RightPanel: boosts + achievements + boost row]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Upgrades = require(Shared.Upgrades)

local Theme = require(script.Parent.Theme)
local BusinessCard = require(script.Parent.BusinessCard)
local TechTreePanel = require(script.Parent.TechTreePanel)
local TechNodeCard = require(script.Parent.TechNodeCard)
local PrestigePanel = require(script.Parent.PrestigePanel)
local ShopPanel = require(script.Parent.ShopPanel)
local LeftSidebar = require(script.Parent.LeftSidebar)
local RightPanel = require(script.Parent.RightPanel)
local ContractsBar = require(script.Parent.ContractsBar)

local UI = {}

export type Handles = {
	screenGui: ScreenGui,
	backgroundLayer: Frame,
	-- Header / wallet
	moneyLabel: TextLabel,
	rpsLabel: TextLabel,
	qtyButton: TextButton,
	gemLabel: TextLabel,
	gemAddButton: TextButton,
	-- Mission contracts strip (bottom of the center column)
	contractsBar: ContractsBar.Handle,
	-- Player card
	playerCard: Frame,
	playerNameLabel: TextLabel,
	playerPrestigeLabel: TextLabel,
	playerLevelLabel: TextLabel,
	playerXpFill: Frame,
	playerXpPercentLabel: TextLabel,
	-- Sub-systems
	sidebar: LeftSidebar.Handle,
	rightPanel: RightPanel.Handle,
	businesses: { [string]: BusinessCard.Handle },
	techNodes: { [string]: TechNodeCard.Handle },
	prestigePanel: PrestigePanel.Handle,
	shopPanel: ShopPanel.Handle,
	businessesScroll: ScrollingFrame,
	techTreeFrame: Frame,
	-- Switches which center panel is visible.
	showTab: (id: string) -> (),
	-- Notifications + popups
	notifyContainer: Frame,
	offlinePopup: Frame,
	offlineAmountLabel: TextLabel,
	offlineDurationLabel: TextLabel,
	offlineCloseButton: TextButton,
}

local function buildPlayerCard(parent: Instance): (Frame, TextLabel, TextLabel, TextLabel, Frame, TextLabel)
	local player = Players.LocalPlayer

	local card = Instance.new("Frame")
	card.Name = "PlayerCard"
	card.Position = UDim2.fromOffset(12, 12)
	card.Size = UDim2.new(0, 300, 0, 96)
	card.BackgroundColor3 = Theme.colors.panel
	card.BorderSizePixel = 0
	card.Parent = parent
	Theme.corner(card, 14)
	Theme.stroke(card, Theme.colors.panelBorder, 1, 0.3)
	Theme.padding(card, 10)

	-- Roblox avatar headshot via the rbxthumb URI scheme (resolves async).
	local avatarFrame = Instance.new("Frame")
	avatarFrame.Size = UDim2.fromOffset(76, 76)
	avatarFrame.AnchorPoint = Vector2.new(0, 0.5)
	avatarFrame.Position = UDim2.fromScale(0, 0.5)
	avatarFrame.BackgroundColor3 = Theme.colors.panelAlt
	avatarFrame.BorderSizePixel = 0
	avatarFrame.Parent = card
	Theme.corner(avatarFrame, 14)
	Theme.stroke(avatarFrame, Theme.colors.gold, 2, 0)

	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Size = UDim2.fromScale(1, 1)
	avatarImage.BackgroundTransparency = 1
	avatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150"
	avatarImage.ScaleType = Enum.ScaleType.Fit
	avatarImage.Parent = avatarFrame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -88, 0, 22)
	nameLabel.Position = UDim2.fromOffset(86, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = Theme.colors.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Theme.font.heading
	nameLabel.TextSize = 18
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = card

	-- "👑 Generation N" line.
	local prestigeLabel = Instance.new("TextLabel")
	prestigeLabel.Size = UDim2.new(1, -88, 0, 18)
	prestigeLabel.Position = UDim2.fromOffset(86, 22)
	prestigeLabel.BackgroundTransparency = 1
	prestigeLabel.Text = "👑 Generation 0"
	prestigeLabel.TextColor3 = Theme.colors.gemBright
	prestigeLabel.TextXAlignment = Enum.TextXAlignment.Left
	prestigeLabel.Font = Theme.font.bodyBold
	prestigeLabel.TextSize = 13
	prestigeLabel.Parent = card

	-- LVL bar at the bottom of the card.
	local levelBg = Instance.new("Frame")
	levelBg.Size = UDim2.new(1, -88, 0, 24)
	levelBg.Position = UDim2.new(0, 86, 1, -28)
	levelBg.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
	levelBg.BorderSizePixel = 0
	levelBg.Parent = card
	Theme.corner(levelBg, 8)

	local levelLabel = Instance.new("TextLabel")
	levelLabel.AnchorPoint = Vector2.new(0, 0.5)
	levelLabel.Position = UDim2.new(0, 6, 0.5, 0)
	levelLabel.Size = UDim2.fromOffset(56, 18)
	levelLabel.BackgroundColor3 = Theme.colors.gem
	levelLabel.Text = "LVL 1"
	levelLabel.TextColor3 = Theme.colors.text
	levelLabel.Font = Theme.font.display
	levelLabel.TextSize = 12
	levelLabel.Parent = levelBg
	Theme.corner(levelLabel, 6)

	local xpBar = Instance.new("Frame")
	xpBar.AnchorPoint = Vector2.new(1, 0.5)
	xpBar.Position = UDim2.new(1, -8, 0.5, 0)
	xpBar.Size = UDim2.new(1, -76, 0, 10)
	xpBar.BackgroundColor3 = Color3.fromRGB(30, 36, 56)
	xpBar.BorderSizePixel = 0
	xpBar.Parent = levelBg
	Theme.corner(xpBar, 5)

	local xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(0.3, 1)
	xpFill.BackgroundColor3 = Theme.colors.gemBright
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpBar
	Theme.corner(xpFill, 5)

	-- Percentage label inside the xp bar.
	local xpPercentLabel = Instance.new("TextLabel")
	xpPercentLabel.AnchorPoint = Vector2.new(1, 0.5)
	xpPercentLabel.Position = UDim2.new(1, -4, 0.5, 0)
	xpPercentLabel.Size = UDim2.fromOffset(38, 12)
	xpPercentLabel.BackgroundTransparency = 1
	xpPercentLabel.Text = "30%"
	xpPercentLabel.TextColor3 = Theme.colors.text
	xpPercentLabel.Font = Theme.font.bodyBold
	xpPercentLabel.TextSize = 10
	xpPercentLabel.TextXAlignment = Enum.TextXAlignment.Right
	xpPercentLabel.Parent = xpBar

	return card, nameLabel, prestigeLabel, levelLabel, xpFill, xpPercentLabel
end

local function buildHeaderBar(parent: Instance): (TextLabel, TextLabel, TextButton, TextLabel, TextButton, TextButton)
	-- Wallet group, centered in the top of the screen.
	local walletGroup = Instance.new("Frame")
	walletGroup.AnchorPoint = Vector2.new(0.5, 0)
	walletGroup.Position = UDim2.new(0.5, 0, 0, 14)
	walletGroup.Size = UDim2.new(0, 460, 0, 80)
	walletGroup.BackgroundTransparency = 1
	walletGroup.Parent = parent

	local bag = Instance.new("TextLabel")
	bag.AnchorPoint = Vector2.new(0, 0.5)
	bag.Position = UDim2.new(0, 0, 0.5, -6)
	bag.Size = UDim2.fromOffset(56, 56)
	bag.BackgroundTransparency = 1
	bag.Text = "💵"
	bag.Font = Theme.font.heading
	bag.TextSize = 40
	bag.Parent = walletGroup

	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Position = UDim2.fromOffset(64, 0)
	moneyLabel.Size = UDim2.new(1, -64, 0, 50)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.Text = "$0"
	moneyLabel.TextColor3 = Theme.colors.text
	moneyLabel.Font = Theme.font.display
	moneyLabel.TextSize = 44
	moneyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	moneyLabel.TextStrokeTransparency = 0.5
	moneyLabel.Parent = walletGroup

	local rpsLabel = Instance.new("TextLabel")
	rpsLabel.Position = UDim2.fromOffset(64, 50)
	rpsLabel.Size = UDim2.new(1, -64, 0, 24)
	rpsLabel.BackgroundTransparency = 1
	rpsLabel.TextXAlignment = Enum.TextXAlignment.Left
	rpsLabel.Text = "+$0 / sec"
	rpsLabel.TextColor3 = Theme.colors.money
	rpsLabel.Font = Theme.font.heading
	rpsLabel.TextSize = 18
	rpsLabel.Parent = walletGroup

	-- Buy quantity selector (qtyButton sits to the left of the gem display).
	local qtyButton = Instance.new("TextButton")
	qtyButton.AnchorPoint = Vector2.new(1, 0.5)
	qtyButton.Position = UDim2.new(1, -240, 0, 52)
	qtyButton.Size = UDim2.new(0, 96, 0, 36)
	qtyButton.BackgroundColor3 = Theme.colors.buyAction
	qtyButton.AutoButtonColor = false
	qtyButton.Text = "BUY x1"
	qtyButton.TextColor3 = Theme.colors.text
	qtyButton.Font = Theme.font.heading
	qtyButton.TextSize = 14
	qtyButton.Parent = parent
	Theme.corner(qtyButton, 10)
	Theme.stroke(qtyButton, Theme.colors.buyBright, 2, 0)

	-- Gem display (top-right).
	local gemFrame = Instance.new("Frame")
	gemFrame.AnchorPoint = Vector2.new(1, 0)
	gemFrame.Position = UDim2.new(1, -76, 0, 22)
	gemFrame.Size = UDim2.fromOffset(140, 44)
	gemFrame.BackgroundColor3 = Theme.colors.panel
	gemFrame.BorderSizePixel = 0
	gemFrame.Parent = parent
	Theme.corner(gemFrame, 12)
	Theme.stroke(gemFrame, Theme.colors.panelBorder, 1, 0.3)

	local gemIcon = Instance.new("TextLabel")
	gemIcon.Size = UDim2.fromOffset(28, 28)
	gemIcon.Position = UDim2.fromOffset(8, 8)
	gemIcon.BackgroundTransparency = 1
	gemIcon.Text = "🔬"
	gemIcon.Font = Theme.font.heading
	gemIcon.TextSize = 20
	gemIcon.Parent = gemFrame

	local gemLabel = Instance.new("TextLabel")
	gemLabel.Position = UDim2.fromOffset(40, 0)
	gemLabel.Size = UDim2.new(1, -78, 1, 0)
	gemLabel.BackgroundTransparency = 1
	gemLabel.TextXAlignment = Enum.TextXAlignment.Left
	gemLabel.Text = "0"
	gemLabel.TextColor3 = Theme.colors.text
	gemLabel.Font = Theme.font.display
	gemLabel.TextSize = 20
	gemLabel.Parent = gemFrame

	local gemAddButton = Instance.new("TextButton")
	gemAddButton.AnchorPoint = Vector2.new(1, 0.5)
	gemAddButton.Position = UDim2.new(1, -6, 0.5, 0)
	gemAddButton.Size = UDim2.fromOffset(32, 32)
	gemAddButton.BackgroundColor3 = Theme.colors.gem
	gemAddButton.AutoButtonColor = false
	gemAddButton.Text = "+"
	gemAddButton.TextColor3 = Theme.colors.text
	gemAddButton.Font = Theme.font.display
	gemAddButton.TextSize = 20
	gemAddButton.Parent = gemFrame
	Theme.corner(gemAddButton, 8)

	return moneyLabel, rpsLabel, qtyButton, gemLabel, gemAddButton, nil :: any
end

function UI.build(): Handles
	local player = Players.LocalPlayer
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "IdleTycoonUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Deep navy background.
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.colors.bgBottom
	root.BorderSizePixel = 0
	root.Parent = screenGui
	Theme.verticalGradient(root, Theme.colors.bgTop, Theme.colors.bgBottom)

	-- Ambient layer (coin rain) behind everything.
	local backgroundLayer = Instance.new("Frame")
	backgroundLayer.Name = "BackgroundLayer"
	backgroundLayer.Size = UDim2.fromScale(1, 1)
	backgroundLayer.BackgroundTransparency = 1
	backgroundLayer.ZIndex = 1
	backgroundLayer.Active = false
	backgroundLayer.Parent = root

	-- Top row: player card + wallet/header + gems.
	local playerCard, playerNameLabel, playerPrestigeLabel, playerLevelLabel, playerXpFill, playerXpPercentLabel = buildPlayerCard(root)
	local moneyLabel, rpsLabel, qtyButton, gemLabel, gemAddButton = buildHeaderBar(root)

	-- Sub-panels.
	local sidebar = LeftSidebar.build(root)
	local rightPanel = RightPanel.build(root)

	-- Center scrolling business list. Leaves room for the contracts strip
	-- pinned to the bottom (~96px tall + 12px padding).
	local centerScroll = Instance.new("ScrollingFrame")
	centerScroll.Name = "Businesses"
	centerScroll.Position = UDim2.fromOffset(244, 104)
	centerScroll.Size = UDim2.new(1, -558, 1, -224)
	centerScroll.BackgroundTransparency = 1
	centerScroll.BorderSizePixel = 0
	centerScroll.ScrollBarThickness = 6
	centerScroll.ScrollBarImageColor3 = Theme.colors.panelHi
	centerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	centerScroll.CanvasSize = UDim2.new()
	centerScroll.ZIndex = 3
	centerScroll.Parent = root
	Theme.padding(centerScroll, 4)

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 12)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = centerScroll

	-- Build a section header above each star system's programs. Iteration
	-- is in catalog order; whenever def.system changes, insert a header
	-- so the player visually groups Sol vs Alpha Centauri vs future systems.
	local function buildSystemHeader(parent: Instance, sysId: string, layoutOrder: number)
		local sys = Config.SYSTEM_BY_ID[sysId]
		if not sys then return end
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 36)
		row.LayoutOrder = layoutOrder
		row.BackgroundTransparency = 1
		row.Parent = parent

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.fromOffset(28, 28)
		iconLabel.AnchorPoint = Vector2.new(0, 0.5)
		iconLabel.Position = UDim2.fromScale(0, 0.5)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = sys.icon
		iconLabel.Font = Theme.font.heading
		iconLabel.TextSize = 22
		iconLabel.Parent = row

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -36, 1, 0)
		title.Position = UDim2.fromOffset(36, 0)
		title.BackgroundTransparency = 1
		title.Text = sys.name
		title.TextColor3 = Theme.colors.gemBright
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Font = Theme.font.display
		title.TextSize = 16
		title.Parent = row
	end

	local businesses: { [string]: BusinessCard.Handle } = {}
	local order = 1
	local lastSystem: string? = nil
	for _, def in ipairs(Config.BUSINESSES) do
		if def.system ~= lastSystem then
			lastSystem = def.system
			buildSystemHeader(centerScroll, def.system, order)
			order += 1
		end
		businesses[def.id] = BusinessCard.build(centerScroll, def, order)
		order += 1
	end

	-- Tech tree container; hidden until the R&D tab is active. Built once
	-- and lives in the same center-column slot as the businesses scroll.
	local techTreeFrame = Instance.new("Frame")
	techTreeFrame.Name = "TechTreeContainer"
	techTreeFrame.Position = centerScroll.Position
	techTreeFrame.Size = centerScroll.Size
	techTreeFrame.BackgroundTransparency = 1
	techTreeFrame.Visible = false
	techTreeFrame.ZIndex = 3
	techTreeFrame.Parent = root

	local techTree = TechTreePanel.build(techTreeFrame)

	-- Prestige panel: occupies the same center column area.
	local prestigeContainer = Instance.new("Frame")
	prestigeContainer.Name = "PrestigeContainer"
	prestigeContainer.Position = centerScroll.Position
	prestigeContainer.Size = centerScroll.Size
	prestigeContainer.BackgroundTransparency = 1
	prestigeContainer.Visible = false
	prestigeContainer.ZIndex = 3
	prestigeContainer.Parent = root
	Theme.padding(prestigeContainer, 4)

	local prestigePanel = PrestigePanel.build(prestigeContainer)
	prestigePanel.frame.Size = UDim2.fromScale(1, 1)
	prestigePanel.frame.Visible = true

	-- Shop container: same center-column slot, hidden until the Shop tab opens.
	local shopContainer = Instance.new("Frame")
	shopContainer.Name = "ShopContainer"
	shopContainer.Position = centerScroll.Position
	shopContainer.Size = centerScroll.Size
	shopContainer.BackgroundTransparency = 1
	shopContainer.Visible = false
	shopContainer.ZIndex = 3
	shopContainer.Parent = root
	local shopPanel = ShopPanel.build(shopContainer)

	local function showTab(id: string)
		centerScroll.Visible = (id == "businesses")
		techTreeFrame.Visible = (id == "upgrades")
		prestigeContainer.Visible = (id == "prestige")
		shopContainer.Visible = (id == "shop")
	end

	-- Bottom strip: 3 procedural mission contracts. Replaces the previously
	-- stubbed Double Cash Event + Invite Friends cards (those were never
	-- wired to real gameplay).
	local contractsBar = ContractsBar.build(root)

	-- Notification stack: bottom-center so it doesn't fight the right panel.
	local notifyContainer = Instance.new("Frame")
	notifyContainer.Name = "Notifications"
	notifyContainer.AnchorPoint = Vector2.new(0.5, 1)
	notifyContainer.Position = UDim2.new(0.5, 0, 1, -12)
	notifyContainer.Size = UDim2.new(0, 320, 0, 200)
	notifyContainer.BackgroundTransparency = 1
	notifyContainer.Parent = screenGui
	local notifyLayout = Instance.new("UIListLayout")
	notifyLayout.Padding = UDim.new(0, 6)
	notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notifyLayout.Parent = notifyContainer

	-- Offline-earnings modal.
	local offlinePopup = Instance.new("Frame")
	offlinePopup.Name = "OfflinePopup"
	offlinePopup.AnchorPoint = Vector2.new(0.5, 0.5)
	offlinePopup.Position = UDim2.fromScale(0.5, 0.5)
	offlinePopup.Size = UDim2.new(0, 420, 0, 260)
	offlinePopup.BackgroundColor3 = Theme.colors.panel
	offlinePopup.Visible = false
	offlinePopup.ZIndex = 100
	offlinePopup.Parent = screenGui
	Theme.corner(offlinePopup, 16)
	Theme.stroke(offlinePopup, Theme.colors.gold, 2)
	Theme.padding(offlinePopup, 20)

	local offlineTitle = Instance.new("TextLabel")
	offlineTitle.Size = UDim2.new(1, 0, 0, 36)
	offlineTitle.BackgroundTransparency = 1
	offlineTitle.Text = "Welcome back!"
	offlineTitle.TextColor3 = Theme.colors.gold
	offlineTitle.Font = Theme.font.display
	offlineTitle.TextSize = 28
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
	offlineAmountLabel.Size = UDim2.new(1, 0, 0, 80)
	offlineAmountLabel.Position = UDim2.fromOffset(0, 76)
	offlineAmountLabel.BackgroundTransparency = 1
	offlineAmountLabel.Text = "$0"
	offlineAmountLabel.TextColor3 = Theme.colors.money
	offlineAmountLabel.Font = Theme.font.display
	offlineAmountLabel.TextSize = 48
	offlineAmountLabel.TextStrokeTransparency = 0.5
	offlineAmountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	offlineAmountLabel.ZIndex = 101
	offlineAmountLabel.Parent = offlinePopup

	local offlineCloseButton = Instance.new("TextButton")
	offlineCloseButton.Size = UDim2.new(1, 0, 0, 48)
	offlineCloseButton.Position = UDim2.new(0, 0, 1, -48)
	offlineCloseButton.BackgroundColor3 = Theme.colors.buyAction
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
		backgroundLayer = backgroundLayer,
		moneyLabel = moneyLabel,
		rpsLabel = rpsLabel,
		qtyButton = qtyButton,
		gemLabel = gemLabel,
		gemAddButton = gemAddButton,
		contractsBar = contractsBar,
		playerCard = playerCard,
		playerNameLabel = playerNameLabel,
		playerPrestigeLabel = playerPrestigeLabel,
		playerLevelLabel = playerLevelLabel,
		playerXpFill = playerXpFill,
		playerXpPercentLabel = playerXpPercentLabel,
		sidebar = sidebar,
		rightPanel = rightPanel,
		businesses = businesses,
		techNodes = techTree.nodes,
		prestigePanel = prestigePanel,
		shopPanel = shopPanel,
		businessesScroll = centerScroll,
		techTreeFrame = techTreeFrame,
		showTab = showTab,
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
	frame.BackgroundColor3 = if kind == "error" then Theme.colors.danger else Theme.colors.buyAction
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
