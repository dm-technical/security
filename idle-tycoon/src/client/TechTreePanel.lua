--!strict
-- R&D tech tree panel. Lays out tech nodes in a vertical scroll:
--   1) "Global Research" section — globals laid out left to right
--   2) "Mission Research" section — one row per mission program with the
--      Mk II / Mk III / Mk IV tier chain connected by short arrow lines
--
-- Each node card is a TechNodeCard handle. Connector arrows are thin Frames
-- placed between siblings; they don't react to state changes so we draw them
-- once at build time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Upgrades = require(Shared.Upgrades)

local Theme = require(script.Parent.Theme)
local TechNodeCard = require(script.Parent.TechNodeCard)

local TechTreePanel = {}

export type Handle = {
	frame: ScrollingFrame,
	nodes: { [string]: TechNodeCard.Handle },
}

local NODE_WIDTH, NODE_HEIGHT = TechNodeCard.size()
local ROW_PADDING = 18
local NODE_GAP = 38 -- horizontal space between sibling nodes (room for arrow)
local ROW_HEIGHT = NODE_HEIGHT + 24

-- Tiny arrow connector between two horizontally-adjacent nodes. Stays at
-- design-time visibility; styling reflects whether the parent is purchased.
local function makeConnector(parent: Instance, parentId: string, x: number, y: number): TextLabel
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow_from_" .. parentId
	arrow.Size = UDim2.fromOffset(NODE_GAP, NODE_HEIGHT)
	arrow.Position = UDim2.fromOffset(x, y)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▶"
	arrow.TextColor3 = Theme.colors.dim
	arrow.Font = Theme.font.heading
	arrow.TextSize = 28
	arrow.Parent = parent
	return arrow
end

local function sectionHeader(parent: Instance, layoutOrder: number, icon: string, text: string, accent: Color3): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
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

-- Build a row containing the left header (icon + name) and the chain of
-- tier nodes connected by arrows.
local function buildProgramRow(parent: Instance, layoutOrder: number, def: Config.BusinessDef,
                               nodeStore: { [string]: TechNodeCard.Handle }): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Theme.colors.panel
	row.BackgroundTransparency = 0.55
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	row.Parent = parent
	Theme.corner(row, 12)
	Theme.padding(row, 12)

	-- Left header: icon tile + name. Size matches a node card so the row
	-- has consistent visual weight.
	local theme = Theme.businessTheme(def.id)
	local header = Instance.new("Frame")
	header.Size = UDim2.fromOffset(140, NODE_HEIGHT)
	header.BackgroundTransparency = 1
	header.Parent = row

	local iconTile = Instance.new("Frame")
	iconTile.Size = UDim2.fromOffset(56, 56)
	iconTile.Position = UDim2.fromOffset(0, 6)
	iconTile.BackgroundColor3 = theme.base
	iconTile.BorderSizePixel = 0
	iconTile.Parent = header
	Theme.corner(iconTile, 10)
	Theme.stroke(iconTile, theme.bright, 2, 0.2)
	Theme.verticalGradient(iconTile, theme.bright, theme.base)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = def.icon
	iconLabel.Font = Theme.font.heading
	iconLabel.TextScaled = true
	iconLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	iconLabel.TextStrokeTransparency = 0.5
	iconLabel.Parent = iconTile

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 36)
	nameLabel.Position = UDim2.fromOffset(0, 68)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = Theme.colors.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Top
	nameLabel.Font = Theme.font.bodyBold
	nameLabel.TextSize = 13
	nameLabel.TextWrapped = true
	nameLabel.Parent = header

	-- Build the three tier nodes left to right with arrow connectors.
	local tierIds = { def.id .. "_25", def.id .. "_50", def.id .. "_100" }
	local startX = 156 -- right of the header (140 + 16 pad)
	for i, tid in ipairs(tierIds) do
		local nodeDef = Upgrades.BY_ID[tid]
		if nodeDef then
			local node = TechNodeCard.build(row, nodeDef)
			node.frame.Position = UDim2.fromOffset(startX, 0)
			nodeStore[tid] = node
			startX += NODE_WIDTH

			if i < #tierIds then
				makeConnector(row, tid, startX, 0)
				startX += NODE_GAP
			end
		end
	end

	return row
end

local function buildGlobalRow(parent: Instance, layoutOrder: number,
                              nodeStore: { [string]: TechNodeCard.Handle }): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Theme.colors.panel
	row.BackgroundTransparency = 0.55
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	row.Parent = parent
	Theme.corner(row, 12)
	Theme.padding(row, 12)

	-- Layout order: Coalition → Contracts (chained), Override standalone after.
	local sequence = { "global_revenue_1", "global_revenue_2" }
	local standalone = { "global_click_1" }

	local x = 0
	for i, gid in ipairs(sequence) do
		local nodeDef = Upgrades.BY_ID[gid]
		if nodeDef then
			local node = TechNodeCard.build(row, nodeDef)
			node.frame.Position = UDim2.fromOffset(x, 0)
			nodeStore[gid] = node
			x += NODE_WIDTH

			if i < #sequence then
				makeConnector(row, gid, x, 0)
				x += NODE_GAP
			end
		end
	end

	-- Gap then any standalone globals.
	x += 32
	for _, gid in ipairs(standalone) do
		local nodeDef = Upgrades.BY_ID[gid]
		if nodeDef then
			local node = TechNodeCard.build(row, nodeDef)
			node.frame.Position = UDim2.fromOffset(x, 0)
			nodeStore[gid] = node
			x += NODE_WIDTH + 16
		end
	end

	return row
end

-- Mission tech: linear chain of 9 unlock-gate nodes. Wraps to multiple rows
-- via UIGridLayout so the entire chain fits without horizontal scrolling.
local MISSION_TECH_IDS = {
	"tech_telemetry",
	"tech_life_support",
	"tech_long_range_comms",
	"tech_lunar_landing",
	"tech_interplanetary",
	"tech_deep_space",
	"tech_warp_theory",
	"tech_colonization",
	"tech_ftl",
}

local function buildMissionTechSection(parent: Instance, layoutOrder: number,
                                       nodeStore: { [string]: TechNodeCard.Handle }): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundColor3 = Theme.colors.panel
	row.BackgroundTransparency = 0.55
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	row.Parent = parent
	Theme.corner(row, 12)
	Theme.padding(row, 12)

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(NODE_WIDTH, NODE_HEIGHT)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = row

	for i, tid in ipairs(MISSION_TECH_IDS) do
		local nodeDef = Upgrades.BY_ID[tid]
		if nodeDef then
			local node = TechNodeCard.build(row, nodeDef)
			node.frame.LayoutOrder = i
			nodeStore[tid] = node
		end
	end

	return row
end

function TechTreePanel.build(parent: Instance): Handle
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "TechTree"
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
	layout.Padding = UDim.new(0, ROW_PADDING / 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local nodes: { [string]: TechNodeCard.Handle } = {}
	local order = 1

	sectionHeader(scroll, order, "🌐", "GLOBAL RESEARCH", Theme.colors.gold).Parent = scroll
	order += 1
	buildGlobalRow(scroll, order, nodes)
	order += 1

	sectionHeader(scroll, order, "🛰️", "MISSION TECH", Theme.colors.gemBright).Parent = scroll
	order += 1
	buildMissionTechSection(scroll, order, nodes)
	order += 1

	sectionHeader(scroll, order, "🚀", "MISSION RESEARCH", Theme.colors.buyBright).Parent = scroll
	order += 1
	for _, def in ipairs(Config.BUSINESSES) do
		buildProgramRow(scroll, order, def, nodes)
		order += 1
	end

	return {
		frame = scroll,
		nodes = nodes,
	}
end

return TechTreePanel
