--!strict
-- Centralized colors, fonts, and tiny UI helpers. Imported by UI/Effects.
-- Vibrant idle-game palette: bright greens, gold money, red CTAs.

local Theme = {}

Theme.colors = {
	-- Background gradient stops (top to bottom) — the bright Vegas-lawn green.
	bgTop = Color3.fromRGB(74, 222, 128),
	bgBottom = Color3.fromRGB(20, 130, 70),
	bgPattern = Color3.fromRGB(35, 165, 95),

	-- Cards and panels: dark slate so business icons + bright text pop.
	panel = Color3.fromRGB(28, 38, 56),
	panelAlt = Color3.fromRGB(45, 58, 82),
	panelHi = Color3.fromRGB(72, 88, 118),
	panelLight = Color3.fromRGB(255, 255, 255),
	panelLightAlt = Color3.fromRGB(241, 245, 249),

	-- Money / wealth.
	gold = Color3.fromRGB(250, 204, 21),
	goldBright = Color3.fromRGB(254, 240, 138),
	goldDeep = Color3.fromRGB(202, 138, 4),

	-- Action buttons.
	buyAction = Color3.fromRGB(34, 197, 94),
	buyBright = Color3.fromRGB(74, 222, 128),
	buyDim = Color3.fromRGB(22, 101, 52),
	cta = Color3.fromRGB(239, 68, 68),       -- red CTA (settings, special actions)
	ctaBright = Color3.fromRGB(248, 113, 113),
	manager = Color3.fromRGB(99, 102, 241),
	managerBright = Color3.fromRGB(129, 140, 248),

	text = Color3.fromRGB(241, 245, 249),
	textDark = Color3.fromRGB(15, 23, 41),
	muted = Color3.fromRGB(148, 163, 184),
	dim = Color3.fromRGB(100, 116, 139),
	danger = Color3.fromRGB(239, 68, 68),

	-- Background-compatible legacy aliases used elsewhere.
	background = Color3.fromRGB(20, 130, 70),
	backgroundDeep = Color3.fromRGB(8, 60, 30),
	accent = Color3.fromRGB(34, 197, 94),
	accentBright = Color3.fromRGB(74, 222, 128),
	accentDim = Color3.fromRGB(22, 101, 52),
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

-- Cheap drop-shadow effect: an offset frame behind the target.
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
