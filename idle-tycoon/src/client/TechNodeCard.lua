--!strict
-- Compact tile that represents a single node in the tech tree. Slots into
-- a row at a fixed width (180×116). Visual states (locked / available /
-- researched) are pushed in via setState() each frame from the controller.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Upgrades)

local Theme = require(script.Parent.Theme)

local TechNodeCard = {}

export type Handle = {
	def: Upgrades.Definition,
	frame: Frame,
	iconCard: Frame,
	iconLabel: TextLabel,
	multiplierBadge: TextLabel,
	nameLabel: TextLabel,
	-- The cost pill at the bottom is the buy hit area; it's a TextButton
	-- whose Text shows the cost / status.
	costLabel: TextButton,
	-- "locked" | "available" | "researched"
	setState: (kind: string, canAfford: boolean) -> (),
}

-- Each node has a theme tint based on what it targets.
local function tintFor(def: Upgrades.Definition): { base: Color3, bright: Color3 }
	if def.target == "business" and def.businessId then
		return Theme.businessTheme(def.businessId)
	elseif def.target == "global_click" then
		return { base = Theme.colors.cta, bright = Theme.colors.ctaBright }
	else
		return { base = Theme.colors.gold, bright = Theme.colors.goldBright }
	end
end

local NODE_WIDTH = 180
local NODE_HEIGHT = 116

function TechNodeCard.size(): (number, number)
	return NODE_WIDTH, NODE_HEIGHT
end

function TechNodeCard.build(parent: Instance, def: Upgrades.Definition): Handle
	local tint = tintFor(def)

	local frame = Instance.new("Frame")
	frame.Name = "Node_" .. def.id
	frame.Size = UDim2.fromOffset(NODE_WIDTH, NODE_HEIGHT)
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame, 12)
	Theme.stroke(frame, Theme.colors.panelBorder, 1, 0.2)
	Theme.padding(frame, 8)

	-- Themed icon tile in the top-left corner.
	local iconCard = Instance.new("Frame")
	iconCard.Size = UDim2.fromOffset(48, 48)
	iconCard.Position = UDim2.fromOffset(0, 0)
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

	-- Multiplier chip in the top-right corner.
	local multiplierBadge = Instance.new("TextLabel")
	multiplierBadge.Size = UDim2.fromOffset(56, 22)
	multiplierBadge.AnchorPoint = Vector2.new(1, 0)
	multiplierBadge.Position = UDim2.new(1, 0, 0, 0)
	multiplierBadge.BackgroundColor3 = tint.base
	multiplierBadge.Text = string.format("x%g", def.multiplier)
	multiplierBadge.TextColor3 = Theme.colors.text
	multiplierBadge.Font = Theme.font.display
	multiplierBadge.TextSize = 13
	multiplierBadge.Parent = frame
	Theme.corner(multiplierBadge, 6)

	-- Name across the bottom (two lines if needed).
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Position = UDim2.fromOffset(0, 54)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = Theme.colors.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Top
	nameLabel.Font = Theme.font.heading
	nameLabel.TextSize = 13
	nameLabel.TextWrapped = true
	nameLabel.Parent = frame

	-- Cost / status pill at the bottom — doubles as the buy hit area.
	local costButton = Instance.new("TextButton")
	costButton.Name = "Buy"
	costButton.AnchorPoint = Vector2.new(0, 1)
	costButton.Position = UDim2.new(0, 0, 1, 0)
	costButton.Size = UDim2.new(1, 0, 0, 26)
	costButton.BackgroundColor3 = Theme.colors.buyAction
	costButton.AutoButtonColor = false
	costButton.Text = "🔬 0"
	costButton.TextColor3 = Theme.colors.text
	costButton.Font = Theme.font.display
	costButton.TextSize = 14
	costButton.Parent = frame
	Theme.corner(costButton, 8)

	local handle: Handle = {
		def = def,
		frame = frame,
		iconCard = iconCard,
		iconLabel = iconLabel,
		multiplierBadge = multiplierBadge,
		nameLabel = nameLabel,
		costLabel = costButton,
		setState = function(_, _) end,
	}

	handle.setState = function(kind: string, canAfford: boolean)
		if kind == "researched" then
			costButton.BackgroundColor3 = Theme.colors.buyDim
			costButton.Text = "✓ RESEARCHED"
			costButton.TextColor3 = Theme.colors.muted
			costButton.Active = false
			frame.BackgroundTransparency = 0.3
			iconCard.BackgroundTransparency = 0
		elseif kind == "locked" then
			costButton.BackgroundColor3 = Theme.colors.buyDim
			costButton.Text = "🔒 LOCKED"
			costButton.TextColor3 = Theme.colors.muted
			costButton.Active = false
			frame.BackgroundTransparency = 0.4
			iconCard.BackgroundTransparency = 0.5
		else
			-- available
			costButton.BackgroundColor3 = canAfford and Theme.colors.buyAction or Theme.colors.buyDim
			costButton.TextColor3 = canAfford and Theme.colors.text or Theme.colors.muted
			costButton.Active = canAfford
			frame.BackgroundTransparency = 0
			iconCard.BackgroundTransparency = 0
		end
	end

	return handle
end

return TechNodeCard
