--!strict
-- Ambient coin rain: gold "$" symbols drift down behind the gameplay UI to
-- give the screen constant motion. Lightweight: max ~6 active particles,
-- spawned every 0.6-1.4s, each tween-driven (no RunService loops).

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Background = {}

local SYMBOLS = { "$", "💰", "💵", "🪙" }
-- Toned down for the darker navy theme: fewer particles, more transparent.
local MAX_ACTIVE = 3
local active = 0
local running = false

local function spawnOne(layer: GuiObject)
	if active >= MAX_ACTIVE then return end
	active += 1

	local viewport = layer.AbsoluteSize
	local startX = math.random() * viewport.X
	local size = 32 + math.random(0, 28)

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(startX, -size)
	label.Size = UDim2.fromOffset(size, size)
	label.BackgroundTransparency = 1
	label.Text = SYMBOLS[math.random(1, #SYMBOLS)]
	label.TextColor3 = Theme.colors.gold
	label.TextStrokeColor3 = Theme.colors.goldDeep
	label.TextStrokeTransparency = 0.7
	label.TextTransparency = 0.75
	label.Font = Theme.font.display
	label.TextScaled = true
	label.Rotation = (math.random() - 0.5) * 30
	label.ZIndex = 1
	label.Parent = layer

	local duration = 6 + math.random() * 5
	local drift = (math.random() - 0.5) * 80 -- horizontal sway over the fall
	local endRotation = label.Rotation + (math.random() - 0.5) * 90

	local tween = TweenService:Create(label, TweenInfo.new(
		duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In
	), {
		Position = UDim2.fromOffset(startX + drift, viewport.Y + size),
		Rotation = endRotation,
		TextTransparency = 0.95,
	})
	tween:Play()
	tween.Completed:Connect(function()
		active -= 1
		label:Destroy()
	end)
end

-- Begin spawning into `layer`. Idempotent: subsequent calls no-op.
function Background.start(layer: GuiObject)
	if running then return end
	running = true
	task.spawn(function()
		while running and layer.Parent do
			spawnOne(layer)
			task.wait(1.4 + math.random() * 1.6)
		end
	end)
end

function Background.stop()
	running = false
end

return Background
