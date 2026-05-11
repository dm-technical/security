--!strict
-- Left sidebar: section nav (Businesses active; rest stubbed) and a
-- "Daily Reward" countdown card at the bottom.
-- Clicking any non-Businesses tab fires a "comingSoon" callback so the
-- controller can flash a toast.

local Theme = require(script.Parent.Theme)

local LeftSidebar = {}

export type NavTab = {
	id: string,
	label: string,
	icon: string,
	enabled: boolean,
}

local TABS: { NavTab } = {
	{ id = "businesses",  label = "Businesses",   icon = "🏪", enabled = true  },
	{ id = "upgrades",    label = "Upgrades",     icon = "📈", enabled = true  },
	{ id = "prestige",    label = "Prestige",     icon = "👑", enabled = true  },
	{ id = "achievements",label = "Achievements", icon = "🏆", enabled = false },
	{ id = "shop",        label = "Shop",         icon = "🛒", enabled = false },
	{ id = "boosts",      label = "Boosts",       icon = "⚡", enabled = false },
}

export type Handle = {
	frame: Frame,
	dailyRewardFrame: Frame,
	dailyRewardLabel: TextLabel,
	dailyTimerLabel: TextLabel,
	dailyClaimButton: TextButton,
	tabs: { [string]: TextButton },
	activeTab: string,
	onTab: ((id: string, enabled: boolean) -> ())?,
	onClaimDaily: (() -> ())?,
	setActiveTab: (id: string) -> (),
	setDailyClaimEnabled: (enabled: boolean) -> (),
}

local function styleTab(button: TextButton, label: TextLabel, isActive: boolean, enabled: boolean)
	if isActive then
		button.BackgroundColor3 = Theme.colors.buyAction
		label.TextColor3 = Theme.colors.text
	elseif enabled then
		button.BackgroundColor3 = Theme.colors.panel
		label.TextColor3 = Theme.colors.text
	else
		button.BackgroundColor3 = Theme.colors.panel
		label.TextColor3 = Theme.colors.muted
	end
end

function LeftSidebar.build(parent: Instance): Handle
	local frame = Instance.new("Frame")
	frame.Name = "LeftSidebar"
	frame.Size = UDim2.new(0, 220, 1, -104)
	frame.Position = UDim2.fromOffset(12, 104)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local nav = Instance.new("Frame")
	nav.Size = UDim2.new(1, 0, 1, -120)
	nav.BackgroundTransparency = 1
	nav.Parent = frame
	local navLayout = Instance.new("UIListLayout")
	navLayout.Padding = UDim.new(0, 8)
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navLayout.Parent = nav

	local handle: Handle = {
		frame = frame,
		dailyRewardFrame = (nil :: any),
		dailyRewardLabel = (nil :: any),
		dailyTimerLabel = (nil :: any),
		dailyClaimButton = (nil :: any),
		tabs = {},
		activeTab = "businesses",
		onTab = nil,
		onClaimDaily = nil,
		setActiveTab = function(_) end,
		setDailyClaimEnabled = function(_) end,
	}

	local tabRefs: { [string]: { button: TextButton, label: TextLabel, def: NavTab } } = {}

	for i, tab in ipairs(TABS) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 0, 56)
		button.LayoutOrder = i
		button.BackgroundColor3 = Theme.colors.panel
		button.AutoButtonColor = false
		button.Text = ""
		button.Parent = nav
		Theme.corner(button, 14)
		Theme.padding(button, 14)
		Theme.stroke(button, Theme.colors.panelBorder, 1, 0.3)

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.fromOffset(30, 30)
		iconLabel.Position = UDim2.fromScale(0, 0.5)
		iconLabel.AnchorPoint = Vector2.new(0, 0.5)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = tab.icon
		iconLabel.Font = Theme.font.heading
		iconLabel.TextSize = 22
		iconLabel.Parent = button

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -40, 1, 0)
		nameLabel.Position = UDim2.fromOffset(40, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = tab.label
		nameLabel.TextColor3 = Theme.colors.text
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = Theme.font.heading
		nameLabel.TextSize = 18
		nameLabel.Parent = button

		tabRefs[tab.id] = { button = button, label = nameLabel, def = tab }
		handle.tabs[tab.id] = button

		button.MouseButton1Click:Connect(function()
			if handle.onTab then handle.onTab(tab.id, tab.enabled) end
			if tab.enabled then
				handle.setActiveTab(tab.id)
			end
		end)
	end

	handle.setActiveTab = function(id: string)
		handle.activeTab = id
		for tabId, ref in pairs(tabRefs) do
			styleTab(ref.button, ref.label, tabId == id, ref.def.enabled)
		end
	end
	handle.setActiveTab(handle.activeTab)

	-- Daily reward card pinned to the bottom of the sidebar.
	local dailyRewardFrame = Instance.new("Frame")
	dailyRewardFrame.Name = "DailyReward"
	dailyRewardFrame.AnchorPoint = Vector2.new(0, 1)
	dailyRewardFrame.Position = UDim2.new(0, 0, 1, 0)
	dailyRewardFrame.Size = UDim2.new(1, 0, 0, 132)
	dailyRewardFrame.BackgroundColor3 = Theme.colors.panel
	dailyRewardFrame.BorderSizePixel = 0
	dailyRewardFrame.Parent = frame
	Theme.corner(dailyRewardFrame, 14)
	Theme.stroke(dailyRewardFrame, Theme.colors.gold, 2, 0.3)
	Theme.padding(dailyRewardFrame, 10)

	local giftIcon = Instance.new("TextLabel")
	giftIcon.Size = UDim2.fromOffset(44, 44)
	giftIcon.Position = UDim2.fromOffset(0, 0)
	giftIcon.BackgroundTransparency = 1
	giftIcon.Text = "🎁"
	giftIcon.Font = Theme.font.heading
	giftIcon.TextSize = 30
	giftIcon.Parent = dailyRewardFrame

	local dailyRewardLabel = Instance.new("TextLabel")
	dailyRewardLabel.Size = UDim2.new(1, -52, 0, 20)
	dailyRewardLabel.Position = UDim2.fromOffset(52, 0)
	dailyRewardLabel.BackgroundTransparency = 1
	dailyRewardLabel.Text = "DAILY REWARD"
	dailyRewardLabel.TextColor3 = Theme.colors.gold
	dailyRewardLabel.TextXAlignment = Enum.TextXAlignment.Left
	dailyRewardLabel.Font = Theme.font.display
	dailyRewardLabel.TextSize = 14
	dailyRewardLabel.Parent = dailyRewardFrame

	local dailyTimerLabel = Instance.new("TextLabel")
	dailyTimerLabel.Size = UDim2.new(1, -52, 0, 22)
	dailyTimerLabel.Position = UDim2.fromOffset(52, 22)
	dailyTimerLabel.BackgroundTransparency = 1
	dailyTimerLabel.Text = "23:59:59"
	dailyTimerLabel.TextColor3 = Theme.colors.text
	dailyTimerLabel.TextXAlignment = Enum.TextXAlignment.Left
	dailyTimerLabel.Font = Theme.font.display
	dailyTimerLabel.TextSize = 18
	dailyTimerLabel.Parent = dailyRewardFrame

	local dailyClaimButton = Instance.new("TextButton")
	dailyClaimButton.AnchorPoint = Vector2.new(0, 1)
	dailyClaimButton.Position = UDim2.new(0, 0, 1, 0)
	dailyClaimButton.Size = UDim2.new(1, 0, 0, 40)
	dailyClaimButton.BackgroundColor3 = Theme.colors.buyAction
	dailyClaimButton.AutoButtonColor = false
	dailyClaimButton.Text = "CLAIM"
	dailyClaimButton.TextColor3 = Theme.colors.text
	dailyClaimButton.Font = Theme.font.display
	dailyClaimButton.TextSize = 16
	dailyClaimButton.Parent = dailyRewardFrame
	Theme.corner(dailyClaimButton, 10)
	Theme.stroke(dailyClaimButton, Theme.colors.buyBright, 2, 0)

	dailyClaimButton.MouseButton1Click:Connect(function()
		if handle.onClaimDaily then handle.onClaimDaily() end
	end)

	handle.setDailyClaimEnabled = function(enabled: boolean)
		if enabled then
			dailyClaimButton.BackgroundColor3 = Theme.colors.buyAction
			dailyClaimButton.TextColor3 = Theme.colors.text
			dailyClaimButton.AutoButtonColor = false
			dailyClaimButton.Active = true
		else
			dailyClaimButton.BackgroundColor3 = Theme.colors.buyDim
			dailyClaimButton.TextColor3 = Theme.colors.muted
			dailyClaimButton.Active = false
		end
	end
	handle.setDailyClaimEnabled(false)

	handle.dailyRewardFrame = dailyRewardFrame
	handle.dailyRewardLabel = dailyRewardLabel
	handle.dailyTimerLabel = dailyTimerLabel
	handle.dailyClaimButton = dailyClaimButton

	return handle
end

return LeftSidebar
