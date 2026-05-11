--!strict
-- Builds a single upgrade row: themed icon, name + description, multiplier
-- chip, BUY button with cost. Visual state is set via setState() from the
-- controller's refresh loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Upgrades)

local Theme = require(script.Parent.Theme)

local UpgradeCard = {}

export type Handle = {
	def: Upgrades.Definition,
	frame: Frame,
	iconCard: Frame,
	iconLabel: TextLabel,
	nameLabel: TextLabel,
	descriptionLabel: TextLabel,
	multiplierBadge: TextLabel,
	buyButton: TextButton,
	buyLabel: TextLabel,
	-- Render state setter; called every frame by the controller.
	setState: (kind: string, canAfford: boolean) -> (), -- "locked" | "available" | "owned"
}

local function tintFor(def: Upgrades.Definition): { base: Color3, bright: Color3 }
	if def.target == "business" and def.businessId then
		return Theme.businessTheme(def.businessId)
	elseif def.target == "global_click" then
		return { base = Theme.colors.cta, bright = Theme.colors.ctaBright }
	else -- global_revenue / fallback
		return { base = Theme.colors.gold, bright = Theme.colors.goldBright }
	end
end

function UpgradeCard.build(parent: Instance, def: Upgrades.Definition, layoutOrder: number): Handle
	local tint = tintFor(def)

	local frame = Instance.new("Frame")
	frame.Name = "Upgrade_" .. def.id
	frame.Size = UDim2.new(1, 0, 0, 84)
	frame.LayoutOrder = layoutOrder
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame, 14)
	Theme.stroke(frame, Theme.colors.panelBorder, 1, 0.3)
	Theme.padding(frame, 10)

	-- Themed icon card on the left.
	local iconCard = Instance.new("Frame")
	iconCard.Size = UDim2.fromOffset(64, 64)
	iconCard.AnchorPoint = Vector2.new(0, 0.5)
	iconCard.Position = UDim2.fromScale(0, 0.5)
	iconCard.BackgroundColor3 = tint.base
	iconCard.BorderSizePixel = 0
	iconCard.Parent = frame
	Theme.corner(iconCard, 12)
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

	-- Center: name + description + multiplier badge.
	local middle = Instance.new("Frame")
	middle.Size = UDim2.new(1, -260, 1, 0)
	middle.Position = UDim2.fromOffset(74, 0)
	middle.BackgroundTransparency = 1
	middle.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -90, 0, 22)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = Theme.colors.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Theme.font.heading
	nameLabel.TextSize = 18
	nameLabel.Parent = middle

	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Size = UDim2.new(1, -10, 0, 18)
	descriptionLabel.Position = UDim2.fromOffset(0, 24)
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Text = def.description
	descriptionLabel.TextColor3 = Theme.colors.muted
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.Font = Theme.font.body
	descriptionLabel.TextSize = 13
	descriptionLabel.Parent = middle

	-- Requirement / status line below description.
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -10, 0, 16)
	statusLabel.Position = UDim2.fromOffset(0, 44)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = Theme.colors.muted
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Font = Theme.font.bodyBold
	statusLabel.TextSize = 12
	statusLabel.Parent = middle

	-- Multiplier chip pinned to the right of the middle column.
	local multiplierBadge = Instance.new("TextLabel")
	multiplierBadge.AnchorPoint = Vector2.new(1, 0)
	multiplierBadge.Position = UDim2.fromScale(1, 0)
	multiplierBadge.Size = UDim2.fromOffset(80, 24)
	multiplierBadge.BackgroundColor3 = tint.base
	multiplierBadge.Text = string.format("x%g", def.multiplier)
	multiplierBadge.TextColor3 = Theme.colors.text
	multiplierBadge.Font = Theme.font.display
	multiplierBadge.TextSize = 14
	multiplierBadge.Parent = middle
	Theme.corner(multiplierBadge, 8)

	-- Right column: BUY button.
	local buyButton = Instance.new("TextButton")
	buyButton.AnchorPoint = Vector2.new(1, 0.5)
	buyButton.Position = UDim2.new(1, 0, 0.5, 0)
	buyButton.Size = UDim2.fromOffset(170, 60)
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
	buyLabel.Text = "$0"
	buyLabel.TextColor3 = Theme.colors.text
	buyLabel.Font = Theme.font.display
	buyLabel.TextSize = 18
	buyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	buyLabel.TextStrokeTransparency = 0.5
	buyLabel.Parent = buyButton

	local handle: Handle = {
		def = def,
		frame = frame,
		iconCard = iconCard,
		iconLabel = iconLabel,
		nameLabel = nameLabel,
		descriptionLabel = descriptionLabel,
		multiplierBadge = multiplierBadge,
		buyButton = buyButton,
		buyLabel = buyLabel,
		setState = function(_, _) end,
	}

	handle.setState = function(kind: string, canAfford: boolean)
		-- Reset the per-frame styling toggles.
		local req = def.requiresOwned
		if kind == "owned" then
			-- Already purchased — show a permanent "OWNED" pill instead of BUY.
			buyButton.BackgroundColor3 = Theme.colors.buyDim
			buyHeader.Text = "OWNED"
			buyHeader.TextColor3 = Theme.colors.muted
			buyLabel.Text = "✓"
			buyLabel.TextColor3 = Theme.colors.muted
			buyButton.Active = false
			frame.BackgroundTransparency = 0.4
			statusLabel.Text = "Purchased"
			statusLabel.TextColor3 = Theme.colors.buyBright
		elseif kind == "locked" then
			buyButton.BackgroundColor3 = Theme.colors.buyDim
			buyHeader.Text = "LOCKED"
			buyHeader.TextColor3 = Theme.colors.muted
			buyLabel.Text = "🔒"
			buyLabel.TextColor3 = Theme.colors.muted
			buyButton.Active = false
			frame.BackgroundTransparency = 0.2
			if def.target == "business" then
				statusLabel.Text = string.format("Unlocks at %d owned", req)
				statusLabel.TextColor3 = Theme.colors.muted
			else
				statusLabel.Text = ""
			end
		else
			-- available
			buyButton.BackgroundColor3 = canAfford and Theme.colors.buyAction or Theme.colors.buyDim
			buyHeader.Text = "BUY"
			buyHeader.TextColor3 = Theme.colors.text
			buyLabel.TextColor3 = Theme.colors.text
			buyButton.Active = canAfford
			frame.BackgroundTransparency = 0
			statusLabel.Text = ""
		end
	end

	return handle
end

return UpgradeCard
