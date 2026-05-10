--!strict
-- Visual feedback layer. All purely cosmetic, all driven by TweenService.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)

local Effects = {}

local QUAD_OUT = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLASH_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Coin-like particle burst from a source GuiObject. Particles are parented
-- to `layer` (typically the ScreenGui) and positioned in absolute pixel
-- coordinates so they can fly outside the source's clipping bounds.
function Effects.burstParticles(layer: Instance, source: GuiObject, count: number?, tint: Color3?)
	local n = count or 10
	local color = tint or Theme.colors.goldBright
	local strokeColor = Theme.colors.gold

	local absPos = source.AbsolutePosition
	local absSize = source.AbsoluteSize
	local cx = absPos.X + absSize.X * 0.5
	local cy = absPos.Y + absSize.Y * 0.5

	for i = 1, n do
		local p = Instance.new("Frame")
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.fromOffset(cx, cy)
		p.Size = UDim2.fromOffset(12, 12)
		p.BackgroundColor3 = color
		p.BorderSizePixel = 0
		p.ZIndex = 30
		p.Parent = layer
		Theme.corner(p, 6)

		local stroke = Instance.new("UIStroke")
		stroke.Color = strokeColor
		stroke.Thickness = 1.5
		stroke.Parent = p

		-- Even angular spread + jitter so 10 particles cover the circle.
		local angle = ((i - 1) / n) * math.pi * 2 + (math.random() - 0.5) * 0.5
		local distance = 60 + math.random() * 50
		local tx = cx + math.cos(angle) * distance
		-- Slight upward bias so it feels gravity-defying like collected coins.
		local ty = cy + math.sin(angle) * distance - 25

		TweenService:Create(p, TweenInfo.new(
			0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
		), {
			Position = UDim2.fromOffset(tx, ty),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(4, 4),
		}):Play()

		TweenService:Create(stroke, TweenInfo.new(0.55), {
			Transparency = 1,
		}):Play()

		task.delay(0.6, function()
			p:Destroy()
		end)
	end
end

-- Floating "+$X" text that rises from a target and fades.
function Effects.floatingText(parent: GuiObject, text: string, color: Color3?)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.5)
	label.Position = UDim2.fromScale(0, 0.4)
	label.AnchorPoint = Vector2.new(0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Theme.colors.goldBright
	label.Font = Theme.font.display
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.ZIndex = 10
	label.Parent = parent

	-- Slight horizontal jitter so multiple bursts don't stack.
	local xJitter = (math.random() - 0.5) * 0.3
	local rise = UDim2.new(xJitter, 0, -0.4, 0)

	local tween = TweenService:Create(label, TweenInfo.new(
		0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
	), {
		Position = label.Position + rise,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

-- Briefly punch a label's scale (used on big money increases).
function Effects.punchScale(target: GuiObject, magnitude: number?)
	local mag = magnitude or 0.12
	local scale = target:FindFirstChild("PunchScale") :: UIScale?
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "PunchScale"
		scale.Scale = 1
		scale.Parent = target
	end
	scale.Scale = 1 + mag
	TweenService:Create(scale, TweenInfo.new(
		0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out
	), { Scale = 1 }):Play()
end

-- Briefly flash a label's color, returning to baseline.
function Effects.flashColor(label: TextLabel, flashColor: Color3, baseColor: Color3)
	label.TextColor3 = flashColor
	TweenService:Create(label, FLASH_INFO, { TextColor3 = baseColor }):Play()
end

-- Quick brighten of a frame's background, returning to baseline.
function Effects.flashBackground(frame: GuiObject, flashColor: Color3, baseColor: Color3)
	frame.BackgroundColor3 = flashColor
	TweenService:Create(frame, FLASH_INFO, { BackgroundColor3 = baseColor }):Play()
end

-- Scale-down on press for tactile feedback. Hook on a button.
function Effects.bindPressFeel(button: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local function press()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.94 }):Play()
	end
	local function release()
		TweenService:Create(scale, TweenInfo.new(
			0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out
		), { Scale = 1 }):Play()
	end

	button.MouseButton1Down:Connect(press)
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

-- Continuous subtle sin-wave pulse on a UIScale; toggled by setting .enabled.
export type Pulse = { enabled: boolean, destroy: () -> () }

function Effects.affordancePulse(target: GuiObject): Pulse
	local scale = Instance.new("UIScale")
	scale.Name = "AffordancePulse"
	scale.Scale = 1
	scale.Parent = target

	local pulse = { enabled = false, destroy = function() end }
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if pulse.enabled then
			local t = os.clock() * 3
			scale.Scale = 1 + 0.04 * math.sin(t)
		elseif scale.Scale ~= 1 then
			scale.Scale = scale.Scale + (1 - scale.Scale) * 0.2
		end
	end)
	pulse.destroy = function()
		if conn then conn:Disconnect() end
		scale:Destroy()
	end
	return pulse
end

-- Slide-in/out celebration banner anchored above the business list.
function Effects.celebrationBanner(parent: ScreenGui, text: string, sub: string?)
	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, -120)
	frame.Size = UDim2.new(0, 480, 0, 96)
	frame.BackgroundColor3 = Theme.colors.gold
	frame.BorderSizePixel = 0
	frame.ZIndex = 50
	frame.Parent = parent
	Theme.corner(frame, 16)
	Theme.stroke(frame, Theme.colors.goldBright, 2)
	Theme.verticalGradient(frame, Theme.colors.goldBright, Theme.colors.gold)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, sub and 0.55 or 1, 0)
	title.BackgroundTransparency = 1
	title.Text = text
	title.TextColor3 = Color3.fromRGB(40, 30, 0)
	title.Font = Theme.font.display
	title.TextScaled = true
	title.ZIndex = 51
	title.Parent = frame

	if sub then
		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(1, 0, 0.45, 0)
		subLabel.Position = UDim2.fromScale(0, 0.55)
		subLabel.BackgroundTransparency = 1
		subLabel.Text = sub
		subLabel.TextColor3 = Color3.fromRGB(60, 45, 0)
		subLabel.Font = Theme.font.heading
		subLabel.TextScaled = true
		subLabel.ZIndex = 51
		subLabel.Parent = frame
	end

	-- Slide down → hold → slide up + fade.
	local slideIn = TweenService:Create(frame, QUAD_OUT, {
		Position = UDim2.new(0.5, 0, 0, 24),
	})
	slideIn:Play()

	task.delay(1.6, function()
		local out = TweenService:Create(frame, TweenInfo.new(
			0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In
		), {
			Position = UDim2.new(0.5, 0, 0, -120),
			BackgroundTransparency = 1,
		})
		out:Play()
		out.Completed:Connect(function()
			frame:Destroy()
		end)
	end)
end

return Effects
