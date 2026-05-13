--!strict
-- First-launch tutorial popup. Sits centered on top of the game UI with a
-- soft dim behind it, but the dim is non-blocking so the player can keep
-- tapping if they want. Five short steps; "Next" advances, "Skip" jumps
-- to done.
--
-- All state lives on the profile (server-authoritative). This module is
-- purely presentation — the controller calls show(step, total, title, body)
-- and wires onNext / onSkip to the server-bound remote.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local TutorialOverlay = {}

export type Handle = {
	screen: Frame,
	card: Frame,
	titleLabel: TextLabel,
	progressLabel: TextLabel,
	bodyLabel: TextLabel,
	nextButton: TextButton,
	skipButton: TextButton,
	onNext: (() -> ())?,
	onSkip: (() -> ())?,
	show: (step: number, total: number, title: string, body: string) -> (),
	hide: () -> (),
}

function TutorialOverlay.build(parent: ScreenGui): Handle
	-- Light dim behind the card. Active = false so it doesn't block clicks
	-- to the game underneath — the tutorial is guidance, not a gate.
	local screen = Instance.new("Frame")
	screen.Name = "TutorialOverlay"
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundColor3 = Color3.new(0, 0, 0)
	screen.BackgroundTransparency = 0.55
	screen.BorderSizePixel = 0
	screen.ZIndex = 180
	screen.Visible = false
	screen.Active = false
	screen.Parent = parent

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -120)
	card.Size = UDim2.fromOffset(560, 220)
	card.BackgroundColor3 = Theme.colors.panel
	card.BorderSizePixel = 0
	card.ZIndex = 181
	card.Parent = screen
	Theme.corner(card, 18)
	Theme.stroke(card, Theme.colors.gemBright, 2, 0)
	Theme.padding(card, 22)

	-- Header row: gold title (left) + step counter (right).
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -120, 0, 30)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = ""
	titleLabel.TextColor3 = Theme.colors.gemBright
	titleLabel.Font = Theme.font.display
	titleLabel.TextSize = 22
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 182
	titleLabel.Parent = card

	local progressLabel = Instance.new("TextLabel")
	progressLabel.AnchorPoint = Vector2.new(1, 0)
	progressLabel.Position = UDim2.fromScale(1, 0)
	progressLabel.Size = UDim2.fromOffset(110, 26)
	progressLabel.BackgroundColor3 = Theme.colors.panelAlt
	progressLabel.Text = "Step 1 of 5"
	progressLabel.TextColor3 = Theme.colors.muted
	progressLabel.Font = Theme.font.heading
	progressLabel.TextSize = 12
	progressLabel.ZIndex = 182
	progressLabel.Parent = card
	Theme.corner(progressLabel, 8)

	-- Body — wraps multi-line. Sits between header and buttons.
	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Position = UDim2.fromOffset(0, 40)
	bodyLabel.Size = UDim2.new(1, 0, 1, -110)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Text = ""
	bodyLabel.TextColor3 = Theme.colors.text
	bodyLabel.Font = Theme.font.body
	bodyLabel.TextSize = 15
	bodyLabel.TextWrapped = true
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.ZIndex = 182
	bodyLabel.Parent = card

	-- Footer: Skip link on the left, primary Next button on the right.
	local skipButton = Instance.new("TextButton")
	skipButton.AnchorPoint = Vector2.new(0, 1)
	skipButton.Position = UDim2.new(0, 0, 1, 0)
	skipButton.Size = UDim2.fromOffset(140, 44)
	skipButton.BackgroundColor3 = Theme.colors.panelAlt
	skipButton.AutoButtonColor = false
	skipButton.Text = "SKIP TUTORIAL"
	skipButton.TextColor3 = Theme.colors.muted
	skipButton.Font = Theme.font.heading
	skipButton.TextSize = 13
	skipButton.ZIndex = 182
	skipButton.Parent = card
	Theme.corner(skipButton, 10)

	local nextButton = Instance.new("TextButton")
	nextButton.AnchorPoint = Vector2.new(1, 1)
	nextButton.Position = UDim2.new(1, 0, 1, 0)
	nextButton.Size = UDim2.fromOffset(160, 44)
	nextButton.BackgroundColor3 = Theme.colors.buyAction
	nextButton.AutoButtonColor = false
	nextButton.Text = "NEXT  →"
	nextButton.TextColor3 = Theme.colors.text
	nextButton.Font = Theme.font.display
	nextButton.TextSize = 16
	nextButton.ZIndex = 182
	nextButton.Parent = card
	Theme.corner(nextButton, 10)
	Theme.stroke(nextButton, Theme.colors.buyBright, 2, 0)

	local handle: Handle = {
		screen = screen,
		card = card,
		titleLabel = titleLabel,
		progressLabel = progressLabel,
		bodyLabel = bodyLabel,
		nextButton = nextButton,
		skipButton = skipButton,
		onNext = nil,
		onSkip = nil,
		show = function(_, _, _, _) end,
		hide = function() end,
	}

	handle.show = function(step: number, total: number, title: string, body: string)
		titleLabel.Text = title
		bodyLabel.Text = body
		progressLabel.Text = string.format("Step %d of %d", step, total)
		nextButton.Text = (step >= total) and "GOT IT  ✓" or "NEXT  →"

		screen.Visible = true
		card.Size = UDim2.fromOffset(0, 0)
		TweenService:Create(card, TweenInfo.new(
			0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out
		), { Size = UDim2.fromOffset(560, 220) }):Play()
	end

	handle.hide = function()
		local tween = TweenService:Create(card, TweenInfo.new(
			0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In
		), { Size = UDim2.fromOffset(0, 0) })
		tween:Play()
		tween.Completed:Connect(function()
			screen.Visible = false
		end)
	end

	nextButton.MouseButton1Click:Connect(function()
		if handle.onNext then handle.onNext() end
	end)
	skipButton.MouseButton1Click:Connect(function()
		if handle.onSkip then handle.onSkip() end
	end)

	return handle
end

return TutorialOverlay
