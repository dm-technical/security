--!strict
-- Modal that lets the player rename a single mission program. Reuses the
-- AgencySetup visual treatment — full-screen click absorber, centered
-- card, text input, primary/secondary buttons. Hidden by default; opened
-- via Handle.show(businessId, currentName, defaultName).

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local ProgramRenameModal = {}

export type Handle = {
	screen: Frame,
	titleLabel: TextLabel,
	subtitleLabel: TextLabel,
	textBox: TextBox,
	saveButton: TextButton,
	resetButton: TextButton,
	cancelButton: TextButton,
	errorLabel: TextLabel,
	-- Receives the (businessId, newName) the user typed. If newName is empty,
	-- the controller should fire a reset-to-default to the server.
	onSubmit: ((businessId: string, newName: string) -> ())?,
	show: (businessId: string, currentName: string, defaultName: string) -> (),
	hide: () -> (),
	setError: (msg: string) -> (),
}

function ProgramRenameModal.build(parent: ScreenGui): Handle
	-- Click absorber that fills the screen — prevents accidental taps to
	-- the businesses/tech tree behind it.
	local screen = Instance.new("Frame")
	screen.Name = "ProgramRename"
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundColor3 = Color3.new(0, 0, 0)
	screen.BackgroundTransparency = 0.4
	screen.BorderSizePixel = 0
	screen.ZIndex = 200
	screen.Visible = false
	screen.Active = true
	screen.Parent = parent

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(520, 360)
	card.BackgroundColor3 = Theme.colors.panel
	card.BorderSizePixel = 0
	card.ZIndex = 201
	card.Parent = screen
	Theme.corner(card, 18)
	Theme.stroke(card, Theme.colors.buyBright, 2, 0)
	Theme.padding(card, 24)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 32)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "RENAME PROGRAM"
	titleLabel.TextColor3 = Theme.colors.buyBright
	titleLabel.Font = Theme.font.display
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextSize = 24
	titleLabel.ZIndex = 202
	titleLabel.Parent = card

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Position = UDim2.fromOffset(0, 36)
	subtitleLabel.Size = UDim2.new(1, 0, 0, 22)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "Currently: —"
	subtitleLabel.TextColor3 = Theme.colors.muted
	subtitleLabel.Font = Theme.font.body
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.TextSize = 14
	subtitleLabel.ZIndex = 202
	subtitleLabel.Parent = card

	-- Input field.
	local boxBg = Instance.new("Frame")
	boxBg.Position = UDim2.fromOffset(0, 76)
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
	textBox.PlaceholderText = "Falcon Heavy, Saturn V, Apollo 11..."
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
	hintLabel.Position = UDim2.fromOffset(0, 138)
	hintLabel.Size = UDim2.new(1, 0, 0, 16)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "1–24 characters · launch callsign auto-derived"
	hintLabel.TextColor3 = Theme.colors.muted
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Font = Theme.font.body
	hintLabel.TextSize = 12
	hintLabel.ZIndex = 202
	hintLabel.Parent = card

	local errorLabel = Instance.new("TextLabel")
	errorLabel.Position = UDim2.fromOffset(0, 158)
	errorLabel.Size = UDim2.new(1, 0, 0, 22)
	errorLabel.BackgroundTransparency = 1
	errorLabel.Text = ""
	errorLabel.TextColor3 = Theme.colors.danger
	errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	errorLabel.Font = Theme.font.bodyBold
	errorLabel.TextSize = 13
	errorLabel.ZIndex = 202
	errorLabel.Parent = card

	-- Bottom row: Cancel (left) + Reset to default (middle) + Save (right).
	local saveButton = Instance.new("TextButton")
	saveButton.AnchorPoint = Vector2.new(1, 1)
	saveButton.Position = UDim2.new(1, 0, 1, 0)
	saveButton.Size = UDim2.fromOffset(160, 56)
	saveButton.BackgroundColor3 = Theme.colors.buyAction
	saveButton.AutoButtonColor = false
	saveButton.Text = "SAVE"
	saveButton.TextColor3 = Theme.colors.text
	saveButton.Font = Theme.font.display
	saveButton.TextSize = 18
	saveButton.ZIndex = 202
	saveButton.Parent = card
	Theme.corner(saveButton, 12)
	Theme.stroke(saveButton, Theme.colors.buyBright, 2, 0)

	local resetButton = Instance.new("TextButton")
	resetButton.AnchorPoint = Vector2.new(0.5, 1)
	resetButton.Position = UDim2.new(0.5, 0, 1, 0)
	resetButton.Size = UDim2.fromOffset(160, 56)
	resetButton.BackgroundColor3 = Theme.colors.panelHi
	resetButton.AutoButtonColor = false
	resetButton.Text = "USE DEFAULT"
	resetButton.TextColor3 = Theme.colors.text
	resetButton.Font = Theme.font.heading
	resetButton.TextSize = 14
	resetButton.ZIndex = 202
	resetButton.Parent = card
	Theme.corner(resetButton, 12)

	local cancelButton = Instance.new("TextButton")
	cancelButton.AnchorPoint = Vector2.new(0, 1)
	cancelButton.Position = UDim2.new(0, 0, 1, 0)
	cancelButton.Size = UDim2.fromOffset(120, 56)
	cancelButton.BackgroundColor3 = Theme.colors.panelAlt
	cancelButton.AutoButtonColor = false
	cancelButton.Text = "CANCEL"
	cancelButton.TextColor3 = Theme.colors.muted
	cancelButton.Font = Theme.font.heading
	cancelButton.TextSize = 14
	cancelButton.ZIndex = 202
	cancelButton.Parent = card
	Theme.corner(cancelButton, 12)

	-- Currently-targeted business; set in show(), read by the button handlers.
	local activeBusinessId: string? = nil

	local handle: Handle = {
		screen = screen,
		titleLabel = titleLabel,
		subtitleLabel = subtitleLabel,
		textBox = textBox,
		saveButton = saveButton,
		resetButton = resetButton,
		cancelButton = cancelButton,
		errorLabel = errorLabel,
		onSubmit = nil,
		show = function(_, _, _) end,
		hide = function() end,
		setError = function(_) end,
	}

	handle.show = function(businessId: string, currentName: string, defaultName: string)
		activeBusinessId = businessId
		textBox.Text = currentName
		subtitleLabel.Text = "Default: " .. defaultName
		errorLabel.Text = ""

		screen.Visible = true
		card.Size = UDim2.fromOffset(0, 0)
		TweenService:Create(card, TweenInfo.new(
			0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out
		), { Size = UDim2.fromOffset(520, 360) }):Play()
		task.defer(function()
			textBox:CaptureFocus()
		end)
	end

	handle.hide = function()
		local tween = TweenService:Create(card, TweenInfo.new(
			0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In
		), { Size = UDim2.fromOffset(0, 0) })
		tween:Play()
		tween.Completed:Connect(function()
			screen.Visible = false
		end)
		activeBusinessId = nil
	end

	handle.setError = function(msg: string)
		errorLabel.Text = msg
	end

	local function fireSubmit(text: string)
		if not activeBusinessId then return end
		if not handle.onSubmit then return end
		handle.onSubmit(activeBusinessId, text)
	end

	saveButton.MouseButton1Click:Connect(function()
		fireSubmit(textBox.Text)
	end)
	resetButton.MouseButton1Click:Connect(function()
		-- Sending an empty string clears the override on the server.
		fireSubmit("")
	end)
	cancelButton.MouseButton1Click:Connect(function()
		handle.hide()
	end)
	textBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then fireSubmit(textBox.Text) end
	end)

	return handle
end

return ProgramRenameModal
