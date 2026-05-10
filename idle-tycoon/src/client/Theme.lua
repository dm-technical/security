--!strict
-- Centralized colors, fonts, and tiny UI helpers. Imported by UI/Effects.

local Theme = {}

Theme.colors = {
	background = Color3.fromRGB(15, 23, 41),
	backgroundDeep = Color3.fromRGB(8, 14, 28),
	panel = Color3.fromRGB(30, 41, 59),
	panelAlt = Color3.fromRGB(51, 65, 85),
	panelHi = Color3.fromRGB(71, 85, 110),
	accent = Color3.fromRGB(16, 185, 129),
	accentBright = Color3.fromRGB(52, 211, 153),
	accentDim = Color3.fromRGB(5, 120, 87),
	gold = Color3.fromRGB(251, 191, 36),
	goldBright = Color3.fromRGB(253, 224, 71),
	text = Color3.fromRGB(241, 245, 249),
	muted = Color3.fromRGB(148, 163, 184),
	dim = Color3.fromRGB(100, 116, 139),
	danger = Color3.fromRGB(239, 68, 68),
	manager = Color3.fromRGB(99, 102, 241),
}

Theme.font = {
	display = Enum.Font.GothamBlack,
	heading = Enum.Font.GothamBold,
	body = Enum.Font.Gotham,
	bodyBold = Enum.Font.GothamSemibold,
}

-- UI primitives -------------------------------------------------------------

function Theme.corner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

function Theme.padding(parent: Instance, px: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Theme.stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Cheap drop-shadow effect: a slightly-larger offset frame behind the target.
function Theme.dropShadow(target: GuiObject, opacity: number?): Frame
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 4)
	shadow.Size = UDim2.new(1, 6, 1, 6)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = opacity or 0.65
	shadow.BorderSizePixel = 0
	shadow.ZIndex = (target.ZIndex or 1) - 1
	shadow.Parent = target.Parent
	Theme.corner(shadow, 14)
	return shadow
end

function Theme.verticalGradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom),
	})
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

return Theme
