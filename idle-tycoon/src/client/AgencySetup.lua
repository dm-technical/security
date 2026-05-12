--!strict
-- First-launch modal asking the player to name their space agency.
-- Shown when the snapshot's `agencyName` is empty; hidden permanently once
-- the server accepts the name (next snapshot will carry it back).

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local AgencySetup = {}

export type Handle = {
	screen: Frame,
	titleLabel: TextLabel,
	textBox: TextBox,
	hintLabel: TextLabel,
	confirmButton: TextButton,
	errorLabel: TextLabel,
	onSubmit: ((name: string) -> ())?,
	show: () -> (),
	hide: () -> (),
	setError: (msg: string) -> (),
}

function AgencySetup.build(parent: ScreenGui): Handle
	-- Full-screen overlay that intercepts all input behind it.
	local screen = Instance.new("Frame")
	screen.Name = "AgencySetup"
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundColor3 = Color3.new(0, 0, 0)
	screen.BackgroundTransparency = 0.4
	screen.BorderSizePixel = 0
	screen.ZIndex = 200
	screen.Visible = false
	screen.Active = true -- absorb clicks behind the modal
	screen.Parent = parent

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(520, 320)
	card.BackgroundColor3 = Theme.colors.panel
	card.BorderSizePixel = 0
	card.ZIndex = 201
	card.Parent = screen
	Theme.corner(card, 18)
	Theme.stroke(card, Theme.colors.gemBright, 2, 0)
	Theme.padding(card, 24)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 36)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🚀  WELCOME, DIRECTOR"
	titleLabel.TextColor3 = Theme.colors.gemBright
	titleLabel.Font = Theme.font.display
	titleLabel.TextSize = 26
	titleLabel.ZIndex = 202
	titleLabel.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromOffset(0, 40)
	subtitle.Size = UDim2.new(1, 0, 0, 44)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Name your space agency. This will be displayed on your\nprofile and in mission reports."
	subtitle.TextColor3 = Theme.colors.muted
	subtitle.Font = Theme.font.body
	subtitle.TextSize = 15
	subtitle.TextWrapped = true
	subtitle.ZIndex = 202
	subtitle.Parent = card

	-- Text input box, styled like a console terminal field.
	local boxBg = Instance.new("Frame")
	boxBg.Position = UDim2.fromOffset(0, 100)
	boxBg.Size = UDim2.new(1, 0, 0, 56)
	boxBg.BackgroundColor3 = Theme.colors.panelAlt
	boxBg.BorderSizePixel = 0
	boxBg.ZIndex = 202
	boxBg.Parent = card
	Theme.corner(boxBg, 12)
	Theme.stroke(boxBg, Theme.colors.panelHi, 1, 0)
	Theme.padding(boxBg, 12)

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.fromScale(1, 1)
	textBox.BackgroundTransparency = 1
	textBox.PlaceholderText = "e.g. Stellaris Aerospace, KASA, Helios Group..."
	textBox.PlaceholderColor3 = Theme.colors.dim
	textBox.Text = ""
	textBox.TextColor3 = Theme.colors.text
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.Font = Theme.font.heading
	textBox.TextSize = 20
	textBox.ClearTextOnFocus = false
	textBox.TextEditable = true
	textBox.MultiLine = false
	textBox.ZIndex = 203
	textBox.Parent = boxBg

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Position = UDim2.fromOffset(0, 164)
	hintLabel.Size = UDim2.new(1, 0, 0, 16)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "3–24 characters · letters, digits, spaces, hyphens"
	hintLabel.TextColor3 = Theme.colors.muted
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Font = Theme.font.body
	hintLabel.TextSize = 12
	hintLabel.ZIndex = 202
	hintLabel.Parent = card

	local errorLabel = Instance.new("TextLabel")
	errorLabel.Position = UDim2.fromOffset(0, 184)
	errorLabel.Size = UDim2.new(1, 0, 0, 20)
	errorLabel.BackgroundTransparency = 1
	errorLabel.Text = ""
	errorLabel.TextColor3 = Theme.colors.danger
	errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	errorLabel.Font = Theme.font.bodyBold
	errorLabel.TextSize = 13
	errorLabel.ZIndex = 202
	errorLabel.Parent = card

	local confirmButton = Instance.new("TextButton")
	confirmButton.AnchorPoint = Vector2.new(0.5, 1)
	confirmButton.Position = UDim2.new(0.5, 0, 1, 0)
	confirmButton.Size = UDim2.new(1, 0, 0, 56)
	confirmButton.BackgroundColor3 = Theme.colors.buyAction
	confirmButton.AutoButtonColor = false
	confirmButton.Text = "FOUND AGENCY"
	confirmButton.TextColor3 = Theme.colors.text
	confirmButton.Font = Theme.font.display
	confirmButton.TextSize = 20
	confirmButton.ZIndex = 202
	confirmButton.Parent = card
	Theme.corner(confirmButton, 12)
	Theme.stroke(confirmButton, Theme.colors.buyBright, 2, 0)

	local handle: Handle = {
		screen = screen,
		titleLabel = titleLabel,
		textBox = textBox,
		hintLabel = hintLabel,
		confirmButton = confirmButton,
		errorLabel = errorLabel,
		onSubmit = nil,
		show = function() end,
		hide = function() end,
		setError = function(_) end,
	}

	handle.show = function()
		screen.Visible = true
		card.Size = UDim2.fromOffset(0, 0)
		TweenService:Create(card, TweenInfo.new(
			0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out
		), { Size = UDim2.fromOffset(520, 320) }):Play()
		task.defer(function()
			textBox:CaptureFocus()
		end)
	end

	handle.hide = function()
		local tween = TweenService:Create(card, TweenInfo.new(
			0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In
		), { Size = UDim2.fromOffset(0, 0) })
		tween:Play()
		tween.Completed:Connect(function()
			screen.Visible = false
		end)
	end

	handle.setError = function(msg: string)
		errorLabel.Text = msg
	end

	local function submit()
		local name = textBox.Text
		if not handle.onSubmit then return end
		errorLabel.Text = ""
		handle.onSubmit(name)
	end

	confirmButton.MouseButton1Click:Connect(submit)
	textBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then submit() end
	end)

	return handle
end

return AgencySetup
