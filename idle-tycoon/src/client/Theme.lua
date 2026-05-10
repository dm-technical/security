--!strict
-- Centralized colors, fonts, and tiny UI helpers.
-- Deep-navy idle-game palette matched to the v2 mockup: dark backgrounds,
-- bright green money, themed business cards, accent gems.

local Theme = {}

Theme.colors = {
	-- Background gradient (deep navy → near-black at bottom).
	bgTop = Color3.fromRGB(26, 27, 58),
	bgBottom = Color3.fromRGB(15, 20, 40),

	-- Panels (cards, sidebar containers).
	panel = Color3.fromRGB(30, 37, 64),
	panelAlt = Color3.fromRGB(40, 48, 80),
	panelHi = Color3.fromRGB(58, 68, 110),
	panelBorder = Color3.fromRGB(45, 52, 84),

	-- Money / wealth: lime green like the mockup ($38.0K text).
	money = Color3.fromRGB(132, 230, 144),
	moneyDim = Color3.fromRGB(74, 222, 128),
	gold = Color3.fromRGB(250, 204, 21),
	goldBright = Color3.fromRGB(254, 240, 138),
	goldDeep = Color3.fromRGB(202, 138, 4),

	-- Action buttons.
	buyAction = Color3.fromRGB(34, 197, 94),
	buyBright = Color3.fromRGB(74, 222, 128),
	buyDim = Color3.fromRGB(60, 80, 100),
	cta = Color3.fromRGB(239, 68, 68),
	ctaBright = Color3.fromRGB(248, 113, 113),
	manager = Color3.fromRGB(99, 102, 241),
	managerBright = Color3.fromRGB(129, 140, 248),

	-- Currency: gem purple.
	gem = Color3.fromRGB(168, 85, 247),
	gemBright = Color3.fromRGB(216, 180, 254),
	gemDeep = Color3.fromRGB(126, 34, 206),

	-- Text scale.
	text = Color3.fromRGB(241, 245, 249),
	textDark = Color3.fromRGB(15, 23, 41),
	muted = Color3.fromRGB(148, 163, 184),
	dim = Color3.fromRGB(100, 116, 139),
	danger = Color3.fromRGB(239, 68, 68),

	-- Compatibility aliases (legacy callers).
	background = Color3.fromRGB(15, 20, 40),
	backgroundDeep = Color3.fromRGB(8, 12, 26),
	accent = Color3.fromRGB(34, 197, 94),
	accentBright = Color3.fromRGB(74, 222, 128),
	accentDim = Color3.fromRGB(22, 101, 52),
}

-- Themed colors per business id. Used by the icon card background and the
-- progress bar fill. Keys mirror Config.BUSINESSES.id.
Theme.businessThemes = {
	lemonade  = { base = Color3.fromRGB(34, 197, 94),  bright = Color3.fromRGB(74, 222, 128) },
	newspaper = { base = Color3.fromRGB(59, 130, 246), bright = Color3.fromRGB(96, 165, 250) },
	carwash   = { base = Color3.fromRGB(239, 68, 68),  bright = Color3.fromRGB(248, 113, 113) },
	pizza     = { base = Color3.fromRGB(249, 115, 22), bright = Color3.fromRGB(251, 146, 60) },
	donut     = { base = Color3.fromRGB(168, 85, 247), bright = Color3.fromRGB(192, 132, 252) },
	shrimp    = { base = Color3.fromRGB(236, 72, 153), bright = Color3.fromRGB(244, 114, 182) },
	hockey    = { base = Color3.fromRGB(6, 182, 212),  bright = Color3.fromRGB(34, 211, 238) },
	movie     = { base = Color3.fromRGB(234, 179, 8),  bright = Color3.fromRGB(250, 204, 21) },
	bank      = { base = Color3.fromRGB(20, 184, 166), bright = Color3.fromRGB(45, 212, 191) },
	oil       = { base = Color3.fromRGB(100, 116, 139),bright = Color3.fromRGB(148, 163, 184) },
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

-- Convenience: themed business colors with a fallback when an id has no
-- explicit entry (e.g., a future business added before the theme is set).
function Theme.businessTheme(id: string): { base: Color3, bright: Color3 }
	local t = Theme.businessThemes[id]
	if t then return t end
	return { base = Theme.colors.buyAction, bright = Theme.colors.buyBright }
end

return Theme
