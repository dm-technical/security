--!strict
-- Right sidebar: Active Boosts panel, Achievement Progress panel, and a
-- three-button boost row across the bottom. All three areas are stubbed
-- visually now and will be wired to gameplay systems in a later phase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)

local Theme = require(script.Parent.Theme)

local RightPanel = {}

export type AchievementRowHandle = {
	frame: Frame,
	titleLabel: TextLabel,
	subtitleLabel: TextLabel,
	progressBar: Frame,
	progressFill: Frame,
	percentLabel: TextLabel,
	gemLabel: TextLabel,
	iconLabel: TextLabel,
}

export type BoostButton = {
	id: string,
	frame: Frame,
	button: TextButton,
	multiplierLabel: TextLabel,
	timerLabel: TextLabel,
}

export type Handle = {
	frame: Frame,
	activeBoostFrame: Frame,
	activeBoostNameLabel: TextLabel,
	activeBoostSubLabel: TextLabel,
	activeBoostTimerLabel: TextLabel,
	achievementsContainer: Frame,
	achievementRows: { [string]: AchievementRowHandle },
	viewAllButton: TextButton,
	boostRow: Frame,
	boosts: { [string]: BoostButton },
	onBoostClick: ((id: string) -> ())?,
	onViewAllClick: (() -> ())?,
}

local function sectionHeader(parent: Instance, icon: string, text: string, accent: Color3): Frame
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundTransparency = 1
	header.Parent = parent

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromOffset(24, 24)
	iconLabel.AnchorPoint = Vector2.new(0, 0.5)
	iconLabel.Position = UDim2.fromScale(0, 0.5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.Font = Theme.font.heading
	iconLabel.TextSize = 18
	iconLabel.TextColor3 = accent
	iconLabel.Parent = header

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -30, 1, 0)
	title.Position = UDim2.fromOffset(30, 0)
	title.BackgroundTransparency = 1
	title.Text = text
	title.TextColor3 = accent
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Theme.font.heading
	title.TextSize = 14
	title.Parent = header
	return header
end

local function makeBoostButton(parent: Instance, id: string, icon: string, label: string,
                                multiplier: string, timer: string, accent: Color3, layoutOrder: number): BoostButton
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1/3, -8, 1, 0)
	frame.LayoutOrder = layoutOrder
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 64)
	button.BackgroundColor3 = Theme.colors.panel
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = frame
	Theme.corner(button, 14)
	Theme.stroke(button, accent, 2, 0.2)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 0.65)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextColor3 = accent
	iconLabel.Font = Theme.font.heading
	iconLabel.TextScaled = true
	iconLabel.Parent = button

	local multiplierLabel = Instance.new("TextLabel")
	multiplierLabel.AnchorPoint = Vector2.new(1, 1)
	multiplierLabel.Position = UDim2.new(1, -6, 1, -4)
	multiplierLabel.Size = UDim2.fromOffset(34, 20)
	multiplierLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	multiplierLabel.Text = multiplier
	multiplierLabel.TextColor3 = accent
	multiplierLabel.Font = Theme.font.display
	multiplierLabel.TextSize = 12
	multiplierLabel.Parent = button
	Theme.corner(multiplierLabel, 6)

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, 0, 0, 14)
	sub.Position = UDim2.fromOffset(0, 66)
	sub.BackgroundTransparency = 1
	sub.Text = label
	sub.TextColor3 = Theme.colors.muted
	sub.Font = Theme.font.body
	sub.TextSize = 11
	sub.Parent = frame

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Size = UDim2.new(1, 0, 0, 14)
	timerLabel.Position = UDim2.fromOffset(0, 80)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = timer
	timerLabel.TextColor3 = Theme.colors.text
	timerLabel.Font = Theme.font.bodyBold
	timerLabel.TextSize = 12
	timerLabel.Parent = frame

	return {
		id = id,
		frame = frame,
		button = button,
		multiplierLabel = multiplierLabel,
		timerLabel = timerLabel,
	}
end

function RightPanel.build(parent: Instance): Handle
	local frame = Instance.new("Frame")
	frame.Name = "RightPanel"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -12, 0, 104)
	frame.Size = UDim2.new(0, 290, 1, -116)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	-- Active boosts card ---------------------------------------------------
	local activeBoostFrame = Instance.new("Frame")
	activeBoostFrame.Size = UDim2.new(1, 0, 0, 140)
	activeBoostFrame.BackgroundColor3 = Theme.colors.panel
	activeBoostFrame.BorderSizePixel = 0
	activeBoostFrame.Parent = frame
	Theme.corner(activeBoostFrame, 14)
	Theme.stroke(activeBoostFrame, Theme.colors.panelBorder, 1, 0.3)
	Theme.padding(activeBoostFrame, 12)

	sectionHeader(activeBoostFrame, "📡", "MISSION CONTROL", Theme.colors.gemBright).Parent = activeBoostFrame

	local boostRow = Instance.new("Frame")
	boostRow.Size = UDim2.new(1, 0, 0, 64)
	boostRow.Position = UDim2.fromOffset(0, 34)
	boostRow.BackgroundColor3 = Theme.colors.panelAlt
	boostRow.BorderSizePixel = 0
	boostRow.Parent = activeBoostFrame
	Theme.corner(boostRow, 10)
	Theme.padding(boostRow, 10)

	local boostIcon = Instance.new("TextLabel")
	boostIcon.Size = UDim2.fromOffset(38, 38)
	boostIcon.AnchorPoint = Vector2.new(0, 0.5)
	boostIcon.Position = UDim2.fromScale(0, 0.5)
	boostIcon.BackgroundColor3 = Theme.colors.gemDeep
	boostIcon.Text = "⚡"
	boostIcon.TextColor3 = Theme.colors.gemBright
	boostIcon.Font = Theme.font.heading
	boostIcon.TextSize = 22
	boostIcon.Parent = boostRow
	Theme.corner(boostIcon, 10)

	local activeBoostNameLabel = Instance.new("TextLabel")
	activeBoostNameLabel.Size = UDim2.new(1, -100, 0, 20)
	activeBoostNameLabel.Position = UDim2.fromOffset(46, 0)
	activeBoostNameLabel.BackgroundTransparency = 1
	activeBoostNameLabel.Text = "No active operations"
	activeBoostNameLabel.TextColor3 = Theme.colors.text
	activeBoostNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	activeBoostNameLabel.Font = Theme.font.heading
	activeBoostNameLabel.TextSize = 14
	activeBoostNameLabel.Parent = boostRow

	local activeBoostSubLabel = Instance.new("TextLabel")
	activeBoostSubLabel.Size = UDim2.new(1, -100, 0, 16)
	activeBoostSubLabel.Position = UDim2.fromOffset(46, 22)
	activeBoostSubLabel.BackgroundTransparency = 1
	activeBoostSubLabel.Text = "Tap an op below to engage"
	activeBoostSubLabel.TextColor3 = Theme.colors.muted
	activeBoostSubLabel.TextXAlignment = Enum.TextXAlignment.Left
	activeBoostSubLabel.Font = Theme.font.body
	activeBoostSubLabel.TextSize = 12
	activeBoostSubLabel.Parent = boostRow

	local activeBoostTimerLabel = Instance.new("TextLabel")
	activeBoostTimerLabel.AnchorPoint = Vector2.new(1, 0.5)
	activeBoostTimerLabel.Position = UDim2.new(1, 0, 0.5, 0)
	activeBoostTimerLabel.Size = UDim2.fromOffset(60, 24)
	activeBoostTimerLabel.BackgroundTransparency = 1
	activeBoostTimerLabel.Text = ""
	activeBoostTimerLabel.TextColor3 = Theme.colors.gemBright
	activeBoostTimerLabel.Font = Theme.font.display
	activeBoostTimerLabel.TextSize = 16
	activeBoostTimerLabel.Parent = boostRow

	-- Achievement progress card -------------------------------------------
	local achievementsCard = Instance.new("Frame")
	achievementsCard.Size = UDim2.new(1, 0, 0, 280)
	achievementsCard.Position = UDim2.fromOffset(0, 152)
	achievementsCard.BackgroundColor3 = Theme.colors.panel
	achievementsCard.BorderSizePixel = 0
	achievementsCard.Parent = frame
	Theme.corner(achievementsCard, 14)
	Theme.stroke(achievementsCard, Theme.colors.panelBorder, 1, 0.3)
	Theme.padding(achievementsCard, 12)

	sectionHeader(achievementsCard, "🏆", "MISSION RECORDS", Theme.colors.gold).Parent = achievementsCard

	local achievementsContainer = Instance.new("Frame")
	achievementsContainer.Size = UDim2.new(1, 0, 1, -80)
	achievementsContainer.Position = UDim2.fromOffset(0, 34)
	achievementsContainer.BackgroundTransparency = 1
	achievementsContainer.Parent = achievementsCard
	local achLayout = Instance.new("UIListLayout")
	achLayout.Padding = UDim.new(0, 8)
	achLayout.SortOrder = Enum.SortOrder.LayoutOrder
	achLayout.Parent = achievementsContainer

	-- Show up to 3 in-progress achievements; full list lives behind View All.
	local achievementRows: { [string]: AchievementRowHandle } = {}
	local visibleDefs = {}
	for _, def in ipairs(Achievements.DEFINITIONS) do
		if #visibleDefs >= 3 then break end
		table.insert(visibleDefs, def)
	end

	for i, def in ipairs(visibleDefs) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 56)
		row.LayoutOrder = i
		row.BackgroundColor3 = Theme.colors.panelAlt
		row.BorderSizePixel = 0
		row.Parent = achievementsContainer
		Theme.corner(row, 10)
		Theme.padding(row, 8)

		local iconBox = Instance.new("TextLabel")
		iconBox.Size = UDim2.fromOffset(38, 38)
		iconBox.AnchorPoint = Vector2.new(0, 0.5)
		iconBox.Position = UDim2.fromScale(0, 0.5)
		iconBox.BackgroundColor3 = Theme.colors.goldDeep
		iconBox.Text = def.icon
		iconBox.Font = Theme.font.heading
		iconBox.TextSize = 20
		iconBox.Parent = row
		Theme.corner(iconBox, 8)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -110, 0, 16)
		title.Position = UDim2.fromOffset(46, 0)
		title.BackgroundTransparency = 1
		title.Text = def.name
		title.TextColor3 = Theme.colors.text
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Font = Theme.font.heading
		title.TextSize = 13
		title.Parent = row

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -110, 0, 13)
		sub.Position = UDim2.fromOffset(46, 16)
		sub.BackgroundTransparency = 1
		sub.Text = def.description
		sub.TextColor3 = Theme.colors.muted
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Font = Theme.font.body
		sub.TextSize = 11
		sub.Parent = row

		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(1, -110, 0, 7)
		barBg.Position = UDim2.fromOffset(46, 32)
		barBg.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
		barBg.BorderSizePixel = 0
		barBg.Parent = row
		Theme.corner(barBg, 3)

		local barFill = Instance.new("Frame")
		barFill.Size = UDim2.fromScale(0, 1)
		barFill.BackgroundColor3 = Theme.colors.buyAction
		barFill.BorderSizePixel = 0
		barFill.Parent = barBg
		Theme.corner(barFill, 3)

		-- Percentage label tucked next to the gem reward.
		local percentLabel = Instance.new("TextLabel")
		percentLabel.AnchorPoint = Vector2.new(1, 0)
		percentLabel.Position = UDim2.new(1, 0, 0, 30)
		percentLabel.Size = UDim2.fromOffset(50, 12)
		percentLabel.BackgroundTransparency = 1
		percentLabel.Text = "0%"
		percentLabel.TextColor3 = Theme.colors.muted
		percentLabel.TextXAlignment = Enum.TextXAlignment.Right
		percentLabel.Font = Theme.font.bodyBold
		percentLabel.TextSize = 11
		percentLabel.Parent = row

		local gemReward = Instance.new("TextLabel")
		gemReward.AnchorPoint = Vector2.new(1, 0)
		gemReward.Position = UDim2.fromScale(1, 0)
		gemReward.Size = UDim2.fromOffset(60, 24)
		gemReward.BackgroundTransparency = 1
		gemReward.Text = "💎 " .. tostring(def.gemReward)
		gemReward.TextColor3 = Theme.colors.gemBright
		gemReward.TextXAlignment = Enum.TextXAlignment.Right
		gemReward.Font = Theme.font.heading
		gemReward.TextSize = 14
		gemReward.Parent = row

		achievementRows[def.id] = {
			frame = row,
			titleLabel = title,
			subtitleLabel = sub,
			progressBar = barBg,
			progressFill = barFill,
			percentLabel = percentLabel,
			gemLabel = gemReward,
			iconLabel = iconBox,
		}
	end

	local viewAllButton = Instance.new("TextButton")
	viewAllButton.AnchorPoint = Vector2.new(0, 1)
	viewAllButton.Position = UDim2.new(0, 0, 1, 0)
	viewAllButton.Size = UDim2.new(1, 0, 0, 32)
	viewAllButton.BackgroundColor3 = Theme.colors.panelAlt
	viewAllButton.AutoButtonColor = false
	viewAllButton.Text = "View All Records"
	viewAllButton.TextColor3 = Theme.colors.text
	viewAllButton.Font = Theme.font.heading
	viewAllButton.TextSize = 13
	viewAllButton.Parent = achievementsCard
	Theme.corner(viewAllButton, 10)

	-- Bottom boost row -----------------------------------------------------
	local boostRowFrame = Instance.new("Frame")
	boostRowFrame.AnchorPoint = Vector2.new(0, 1)
	boostRowFrame.Position = UDim2.new(0, 0, 1, 0)
	boostRowFrame.Size = UDim2.new(1, 0, 0, 100)
	boostRowFrame.BackgroundTransparency = 1
	boostRowFrame.Parent = frame
	local boostLayout = Instance.new("UIListLayout")
	boostLayout.FillDirection = Enum.FillDirection.Horizontal
	boostLayout.Padding = UDim.new(0, 8)
	boostLayout.SortOrder = Enum.SortOrder.LayoutOrder
	boostLayout.Parent = boostRowFrame

	local boosts: { [string]: BoostButton } = {}
	boosts["click"] = makeBoostButton(boostRowFrame, "click", "🚀", "Rapid Launch", "x5", "00:15", Theme.colors.buyBright, 1)
	boosts["income"] = makeBoostButton(boostRowFrame, "income", "🏛️", "Gov't Stimulus", "x2", "04:30", Theme.colors.gold, 2)
	boosts["offline"] = makeBoostButton(boostRowFrame, "offline", "🤖", "Autonomous Ops", "x2", "10:00", Theme.colors.gemBright, 3)

	local handle: Handle = {
		frame = frame,
		activeBoostFrame = activeBoostFrame,
		activeBoostNameLabel = activeBoostNameLabel,
		activeBoostSubLabel = activeBoostSubLabel,
		activeBoostTimerLabel = activeBoostTimerLabel,
		achievementsContainer = achievementsContainer,
		achievementRows = achievementRows,
		viewAllButton = viewAllButton,
		boostRow = boostRowFrame,
		boosts = boosts,
		onBoostClick = nil,
		onViewAllClick = nil,
	}

	for id, b in pairs(boosts) do
		b.button.MouseButton1Click:Connect(function()
			if handle.onBoostClick then handle.onBoostClick(id) end
		end)
	end
	viewAllButton.MouseButton1Click:Connect(function()
		if handle.onViewAllClick then handle.onViewAllClick() end
	end)

	return handle
end

return RightPanel
