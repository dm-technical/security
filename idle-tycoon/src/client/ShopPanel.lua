--!strict
-- Center-column panel for the Shop tab. Two sections (Contracts / Boosts),
-- each holding a vertical list of item rows. Each row exposes a per-frame
-- setState(kind, scienceCost, statusText) so the controller can flip
-- between "available", "cant_afford", and "unavailable" reasons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared.Shop)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)

local ShopPanel = {}

export type ItemHandle = {
	def: Shop.Definition,
	frame: Frame,
	titleLabel: TextLabel,
	descriptionLabel: TextLabel,
	statusLabel: TextLabel, -- contextual line above the buy button
	buyButton: TextButton,
	-- kind: "available" | "cant_afford" | "unavailable"
	setState: (kind: string, scienceCost: number, statusText: string?) -> (),
}

export type Handle = {
	frame: ScrollingFrame,
	items: { [string]: ItemHandle },
}

local TINTS = {
	contracts = { base = Theme.colors.gold,    bright = Theme.colors.goldBright },
	boosts    = { base = Theme.colors.gem,     bright = Theme.colors.gemBright },
}

local function tintForCategory(cat: string): { base: Color3, bright: Color3 }
	return TINTS[cat] or TINTS.contracts
end

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

local function buildItemRow(parent: Instance, def: Shop.Definition, layoutOrder: number): ItemHandle
	local tint = tintForCategory(def.category)

	local frame = Instance.new("Frame")
	frame.Name = "ShopItem_" .. def.id
	frame.Size = UDim2.new(1, 0, 0, 80)
	frame.LayoutOrder = layoutOrder
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame, 12)
	Theme.stroke(frame, Theme.colors.panelBorder, 1, 0.3)
	Theme.padding(frame, 12)

	-- Themed icon tile.
	local iconCard = Instance.new("Frame")
	iconCard.Size = UDim2.fromOffset(56, 56)
	iconCard.AnchorPoint = Vector2.new(0, 0.5)
	iconCard.Position = UDim2.fromScale(0, 0.5)
	iconCard.BackgroundColor3 = tint.base
	iconCard.BorderSizePixel = 0
	iconCard.Parent = frame
	Theme.corner(iconCard, 10)
	Theme.stroke(iconCard, tint.bright, 2, 0.2)
	Theme.verticalGradient(iconCard, tint.bright, tint.base)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = def.icon
	iconLabel.Font = Theme.font.heading
	iconLabel.TextScaled = true
	iconLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	iconLabel.TextStrokeTransparency = 0.5
	iconLabel.Parent = iconCard

	-- Middle column.
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -240, 0, 22)
	titleLabel.Position = UDim2.fromOffset(68, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = def.name
	titleLabel.TextColor3 = Theme.colors.text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Theme.font.heading
	titleLabel.TextSize = 16
	titleLabel.Parent = frame

	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Size = UDim2.new(1, -240, 0, 18)
	descriptionLabel.Position = UDim2.fromOffset(68, 28)
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Text = def.description
	descriptionLabel.TextColor3 = Theme.colors.muted
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.Font = Theme.font.body
	descriptionLabel.TextSize = 13
	descriptionLabel.Parent = frame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -240, 0, 16)
	statusLabel.Position = UDim2.fromOffset(68, 48)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = Theme.colors.muted
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Font = Theme.font.bodyBold
	statusLabel.TextSize = 12
	statusLabel.Parent = frame

	-- Buy button stack on the right.
	local buyButton = Instance.new("TextButton")
	buyButton.AnchorPoint = Vector2.new(1, 0.5)
	buyButton.Position = UDim2.new(1, 0, 0.5, 0)
	buyButton.Size = UDim2.fromOffset(160, 56)
	buyButton.BackgroundColor3 = Theme.colors.buyAction
	buyButton.AutoButtonColor = false
	buyButton.Text = ""
	buyButton.Parent = frame
	Theme.corner(buyButton, 12)
	Theme.stroke(buyButton, Theme.colors.buyBright, 2, 0)

	local buyHeader = Instance.new("TextLabel")
	buyHeader.Size = UDim2.new(1, 0, 0.4, 0)
	buyHeader.BackgroundTransparency = 1
	buyHeader.Text = "BUY"
	buyHeader.TextColor3 = Theme.colors.text
	buyHeader.Font = Theme.font.heading
	buyHeader.TextSize = 14
	buyHeader.Parent = buyButton

	local buyLabel = Instance.new("TextLabel")
	buyLabel.Size = UDim2.new(1, 0, 0.6, 0)
	buyLabel.Position = UDim2.fromScale(0, 0.4)
	buyLabel.BackgroundTransparency = 1
	buyLabel.Text = "🔬 0"
	buyLabel.TextColor3 = Theme.colors.text
	buyLabel.Font = Theme.font.display
	buyLabel.TextSize = 18
	buyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	buyLabel.TextStrokeTransparency = 0.5
	buyLabel.Parent = buyButton

	local handle: ItemHandle = {
		def = def,
		frame = frame,
		titleLabel = titleLabel,
		descriptionLabel = descriptionLabel,
		statusLabel = statusLabel,
		buyButton = buyButton,
		setState = function(_, _, _) end,
	}

	handle.setState = function(kind: string, scienceCost: number, statusText: string?)
		statusLabel.Text = statusText or ""
		if kind == "available" then
			buyButton.BackgroundColor3 = Theme.colors.buyAction
			buyButton.Active = true
			buyHeader.Text = "BUY"
			buyHeader.TextColor3 = Theme.colors.text
			buyLabel.Text = "🔬 " .. Format.short(scienceCost)
			buyLabel.TextColor3 = Theme.colors.text
		elseif kind == "cant_afford" then
			buyButton.BackgroundColor3 = Theme.colors.buyDim
			buyButton.Active = false
			buyHeader.Text = "NEED"
			buyHeader.TextColor3 = Theme.colors.muted
			buyLabel.Text = "🔬 " .. Format.short(scienceCost)
			buyLabel.TextColor3 = Theme.colors.muted
		else
			-- unavailable (boost active/ready, slot empty, etc.)
			buyButton.BackgroundColor3 = Theme.colors.buyDim
			buyButton.Active = false
			buyHeader.Text = "—"
			buyHeader.TextColor3 = Theme.colors.muted
			buyLabel.Text = ""
		end
	end

	return handle
end

function ShopPanel.build(parent: Instance): Handle
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Shop"
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

	local items: { [string]: ItemHandle } = {}
	local order = 1

	-- Contracts section.
	sectionHeader(scroll, order, "🎲", "CONTRACTS", Theme.colors.gold).Parent = scroll
	order += 1
	for _, def in ipairs(Shop.ITEMS) do
		if def.category == "contracts" then
			items[def.id] = buildItemRow(scroll, def, order)
			order += 1
		end
	end

	-- Boosts section.
	sectionHeader(scroll, order, "📡", "BOOST CONTROL", Theme.colors.gemBright).Parent = scroll
	order += 1
	for _, def in ipairs(Shop.ITEMS) do
		if def.category == "boosts" then
			items[def.id] = buildItemRow(scroll, def, order)
			order += 1
		end
	end

	return {
		frame = scroll,
		items = items,
	}
end

return ShopPanel
