--!strict
-- Ambient star field: tiny stars drift slowly across the screen behind the
-- UI to evoke deep space. Lightweight; each particle is a self-managing
-- tween. A handful of larger drifting symbols (planets, rockets) sprinkle in
-- less frequently for variety.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Background = {}

local STAR_SYMBOLS = { "·", "•", "✦", "✧", "✷", "✸", "✺" }
local FEATURE_SYMBOLS = { "🛰", "🪐", "✨" }
-- Stars are cheap; keep many in flight at low opacity. Features are rarer.
local MAX_STARS = 24
local MAX_FEATURES = 2
local activeStars = 0
local activeFeatures = 0
local running = false

local function spawnStar(layer: GuiObject)
	if activeStars >= MAX_STARS then return end
	activeStars += 1

	local viewport = layer.AbsoluteSize
	local startY = math.random() * viewport.Y
	-- Random size and brightness per star for parallax-ish depth.
	local size = 6 + math.random(0, 14)
	local brightness = 0.4 + math.random() * 0.5

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	-- Drift right-to-left, slowly. Start just off-screen on the right.
	label.Position = UDim2.fromOffset(viewport.X + size, startY)
	label.Size = UDim2.fromOffset(size, size)
	label.BackgroundTransparency = 1
	label.Text = STAR_SYMBOLS[math.random(1, #STAR_SYMBOLS)]
	label.TextColor3 = Color3.fromRGB(220, 230, 255)
	label.TextTransparency = 1 - brightness
	label.Font = Theme.font.body
	label.TextScaled = true
	label.ZIndex = 1
	label.Parent = layer

	-- Bigger stars drift faster (foreground); smaller ones slower (depth).
	local duration = (24 - size * 0.4) + math.random() * 16
	local endX = -size

	local tween = TweenService:Create(label, TweenInfo.new(
		duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut
	), {
		Position = UDim2.fromOffset(endX, startY + (math.random() - 0.5) * 40),
	})
	tween:Play()
	tween.Completed:Connect(function()
		activeStars -= 1
		label:Destroy()
	end)
end

local function spawnFeature(layer: GuiObject)
	if activeFeatures >= MAX_FEATURES then return end
	activeFeatures += 1

	local viewport = layer.AbsoluteSize
	local startY = math.random() * viewport.Y * 0.7 + viewport.Y * 0.15
	local size = 40 + math.random(0, 30)

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(viewport.X + size, startY)
	label.Size = UDim2.fromOffset(size, size)
	label.BackgroundTransparency = 1
	label.Text = FEATURE_SYMBOLS[math.random(1, #FEATURE_SYMBOLS)]
	label.TextTransparency = 0.7
	label.Font = Theme.font.heading
	label.TextScaled = true
	label.Rotation = (math.random() - 0.5) * 20
	label.ZIndex = 1
	label.Parent = layer

	local duration = 30 + math.random() * 20
	local tween = TweenService:Create(label, TweenInfo.new(
		duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut
	), {
		Position = UDim2.fromOffset(-size, startY),
		Rotation = label.Rotation + (math.random() - 0.5) * 40,
	})
	tween:Play()
	tween.Completed:Connect(function()
		activeFeatures -= 1
		label:Destroy()
	end)
end

-- Begin spawning into `layer`. Idempotent: subsequent calls no-op.
function Background.start(layer: GuiObject)
	if running then return end
	running = true
	-- Stars: fast spawn cadence, many on screen.
	task.spawn(function()
		while running and layer.Parent do
			spawnStar(layer)
			task.wait(0.3 + math.random() * 0.5)
		end
	end)
	-- Features (rocket / planet / sparkle): rare cameos.
	task.spawn(function()
		while running and layer.Parent do
			task.wait(15 + math.random() * 25)
			if layer.Parent then spawnFeature(layer) end
		end
	end)
end

function Background.stop()
	running = false
end

return Background
