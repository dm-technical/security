--!strict
-- Center-column panel for the Mission Log tab. Shows the full achievement
-- catalog split into IN PROGRESS / UNLOCKED sections, with progress bars,
-- gem rewards, and unlock timestamps.
--
-- All achievement state is server-authoritative — this panel is a pure
-- presentation layer over state.achievements + state.{totalEarned,
-- totalClicks, totalOwned} which the controller pushes in each frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)

local AchievementsPanel = {}

export type ItemHandle = {
	def: Achievements.Definition,
	frame: Frame,
	iconCard: Frame,
	iconLabel: TextLabel,
	titleLabel: TextLabel,
	descriptionLabel: TextLabel,
	progressBar: Frame,
	progressFill: Frame,
	progressLabel: TextLabel,
	gemLabel: TextLabel,
	statusBadge: Frame,
	statusBadgeLabel: TextLabel,
	-- kind: "unlocked" | "progress"
	setState: (kind: string, current: number, progress: number, unlockedAt: number) -> (),
}

export type Handle = {
	frame: ScrollingFrame,
	items: { [string]: ItemHandle },
	inProgressHeader: Frame,
	unlockedHeader: Frame,
}

local function sectionHeader(parent: Instance, layoutOrder: number, icon: string, text: string, accent: Color3): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundTransparency = 1
	row.LayoutOrder = layoutOrder
	row.Parent = parent

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromOffset(28, 28)
	iconLabel.AnchorPoint = Vector2.new(0, 0.5)
	iconLabel.Position = UDim2.fromScale(0, 0.5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.Font = Theme.font.heading
	iconLabel.TextSize = 22
	iconLabel.Parent = row

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -36, 1, 0)
	title.Position = UDim2.fromOffset(36, 0)
	title.BackgroundTransparency = 1
	title.Text = text
	title.TextColor3 = accent
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Theme.font.display
	title.TextSize = 16
	title.Parent = row
	return row
end

-- Friendly "X / Y" string per progressKey, formatted differently for
-- money-typed metrics vs raw counts.
local function formatProgress(def: Achievements.Definition, current: number): string
	local target = def.target
	if def.progressKey == "totalEarned" then
		return Format.money(current) .. " / " .. Format.money(target)
	end
	return Format.short(current) .. " / " .. Format.short(target)
end

local function buildAchievementRow(parent: Instance, def: Achievements.Definition, layoutOrder: number): ItemHandle
	local frame = Instance.new("Frame")
	frame.Name = "Achievement_" .. def.id
	frame.Size = UDim2.new(1, 0, 0, 84)
	frame.LayoutOrder = layoutOrder
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame, 12)
	Theme.stroke(frame, Theme.colors.panelBorder, 1, 0.3)
	Theme.padding(frame, 12)

	-- Themed icon tile on the left.
	local iconCard = Instance.new("Frame")
	iconCard.Size = UDim2.fromOffset(60, 60)
	iconCard.AnchorPoint = Vector2.new(0, 0.5)
	iconCard.Position = UDim2.fromScale(0, 0.5)
	iconCard.BackgroundColor3 = Theme.colors.goldDeep
	iconCard.BorderSizePixel = 0
	iconCard.Parent = frame
	Theme.corner(iconCard, 10)
	Theme.stroke(iconCard, Theme.colors.gold, 2, 0.2)
	Theme.verticalGradient(iconCard, Theme.colors.gold, Theme.colors.goldDeep)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = def.icon
	iconLabel.Font = Theme.font.heading
	iconLabel.TextScaled = true
	iconLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	iconLabel.TextStrokeTransparency = 0.5
	iconLabel.Parent = iconCard

	-- Center: name, description, progress bar.
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -200, 0, 22)
	titleLabel.Position = UDim2.fromOffset(72, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = def.name
	titleLabel.TextColor3 = Theme.colors.text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Theme.font.heading
	titleLabel.TextSize = 16
	titleLabel.Parent = frame

	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Size = UDim2.new(1, -200, 0, 16)
	descriptionLabel.Position = UDim2.fromOffset(72, 22)
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Text = def.description
	descriptionLabel.TextColor3 = Theme.colors.muted
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.Font = Theme.font.body
	descriptionLabel.TextSize = 12
	descriptionLabel.Parent = frame

	local progressBar = Instance.new("Frame")
	progressBar.Size = UDim2.new(1, -200, 0, 12)
	progressBar.Position = UDim2.fromOffset(72, 44)
	progressBar.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
	progressBar.BorderSizePixel = 0
	progressBar.ClipsDescendants = true
	progressBar.Parent = frame
	Theme.corner(progressBar, 4)

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Theme.colors.buyAction
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBar
	Theme.corner(progressFill, 4)

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Size = UDim2.new(1, -200, 0, 14)
	progressLabel.Position = UDim2.fromOffset(72, 56)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "0 / 0"
	progressLabel.TextColor3 = Theme.colors.muted
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.Font = Theme.font.bodyBold
	progressLabel.TextSize = 11
	progressLabel.Parent = frame

	-- Right: status badge + gem reward.
	local statusBadge = Instance.new("Frame")
	statusBadge.AnchorPoint = Vector2.new(1, 0)
	statusBadge.Position = UDim2.fromScale(1, 0)
	statusBadge.Size = UDim2.fromOffset(120, 26)
	statusBadge.BackgroundColor3 = Theme.colors.panelAlt
	statusBadge.BorderSizePixel = 0
	statusBadge.Parent = frame
	Theme.corner(statusBadge, 8)

	local statusBadgeLabel = Instance.new("TextLabel")
	statusBadgeLabel.Size = UDim2.fromScale(1, 1)
	statusBadgeLabel.BackgroundTransparency = 1
	statusBadgeLabel.Text = "IN PROGRESS"
	statusBadgeLabel.TextColor3 = Theme.colors.muted
	statusBadgeLabel.Font = Theme.font.display
	statusBadgeLabel.TextSize = 11
	statusBadgeLabel.Parent = statusBadge

	local gemLabel = Instance.new("TextLabel")
	gemLabel.AnchorPoint = Vector2.new(1, 1)
	gemLabel.Position = UDim2.new(1, 0, 1, 0)
	gemLabel.Size = UDim2.fromOffset(120, 28)
	gemLabel.BackgroundTransparency = 1
	gemLabel.Text = "🔬 " .. tostring(def.gemReward)
	gemLabel.TextColor3 = Theme.colors.gemBright
	gemLabel.TextXAlignment = Enum.TextXAlignment.Right
	gemLabel.Font = Theme.font.heading
	gemLabel.TextSize = 16
	gemLabel.Parent = frame

	local handle: ItemHandle = {
		def = def,
		frame = frame,
		iconCard = iconCard,
		iconLabel = iconLabel,
		titleLabel = titleLabel,
		descriptionLabel = descriptionLabel,
		progressBar = progressBar,
		progressFill = progressFill,
		progressLabel = progressLabel,
		gemLabel = gemLabel,
		statusBadge = statusBadge,
		statusBadgeLabel = statusBadgeLabel,
		setState = function(_, _, _, _) end,
	}

	handle.setState = function(kind: string, current: number, progress: number, unlockedAt: number)
		if kind == "unlocked" then
			progressFill.Size = UDim2.fromScale(1, 1)
			progressFill.BackgroundColor3 = Theme.colors.gold
			progressLabel.Text = (unlockedAt and unlockedAt > 0)
				and ("Unlocked " .. os.date("%Y-%m-%d %H:%M", unlockedAt))
				or "Unlocked"
			progressLabel.TextColor3 = Theme.colors.gold
			statusBadgeLabel.Text = "✓ UNLOCKED"
			statusBadgeLabel.TextColor3 = Theme.colors.gold
			statusBadge.BackgroundColor3 = Theme.colors.goldDeep
			iconCard.BackgroundTransparency = 0
		else
			progressFill.Size = UDim2.fromScale(math.min(1, progress), 1)
			progressFill.BackgroundColor3 = Theme.colors.buyAction
			progressLabel.Text = formatProgress(def, current)
			progressLabel.TextColor3 = Theme.colors.muted
			statusBadgeLabel.Text = string.format("%d%%", math.floor(progress * 100))
			statusBadgeLabel.TextColor3 = Theme.colors.muted
			statusBadge.BackgroundColor3 = Theme.colors.panelAlt
			iconCard.BackgroundTransparency = 0.4
		end
	end

	return handle
end

function AchievementsPanel.build(parent: Instance): Handle
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "AchievementsPanel"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.colors.panelHi
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = parent
	Theme.padding(scroll, 6)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	-- Layout order is updated by the controller's refresh (so unlocked
	-- items get reordered into the UNLOCKED section). Section headers
	-- are stashed in handle so the refresh can resize/hide them.
	local inProgressHeader = sectionHeader(scroll, 1, "🏆", "IN PROGRESS", Theme.colors.buyBright)
	local unlockedHeader = sectionHeader(scroll, 1000, "✓", "UNLOCKED", Theme.colors.gold)

	local items: { [string]: ItemHandle } = {}
	for i, def in ipairs(Achievements.DEFINITIONS) do
		items[def.id] = buildAchievementRow(scroll, def, 2 + i)
	end

	return {
		frame = scroll,
		items = items,
		inProgressHeader = inProgressHeader,
		unlockedHeader = unlockedHeader,
	}
end

return AchievementsPanel
