--!strict
-- Settings panel: floating gear button + slide-out modal with toggles.
-- Stores nothing locally; emits an `onChange` callback the controller wires
-- to the server's UpdateSettings remote and to the Sounds/Music modules.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Settings = {}

export type Values = { sfxVolume: number, musicVolume: number }

export type Handle = {
	gearButton: TextButton,
	panel: Frame,
	sfxButton: TextButton,
	musicButton: TextButton,
	closeButton: TextButton,
	values: Values,
	setValues: (values: Values) -> (),
	onChange: ((Values) -> ())?,
}

local function makeToggle(parent: Instance, layoutOrder: number, label: string, icon: string): (Frame, TextButton)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Theme.colors.panelAlt
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	row.Parent = parent
	Theme.corner(row, 10)
	Theme.padding(row, 12)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromOffset(36, 36)
	iconLabel.Position = UDim2.fromOffset(0, 8)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.Font = Theme.font.heading
	iconLabel.TextSize = 24
	iconLabel.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -130, 1, 0)
	nameLabel.Position = UDim2.fromOffset(44, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = label
	nameLabel.TextColor3 = Theme.colors.text
	nameLabel.Font = Theme.font.heading
	nameLabel.TextSize = 18
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.new(0, 80, 0, 36)
	toggle.Position = UDim2.new(1, -80, 0.5, -18)
	toggle.AutoButtonColor = false
	toggle.BackgroundColor3 = Theme.colors.buyAction
	toggle.Text = "ON"
	toggle.TextColor3 = Theme.colors.text
	toggle.Font = Theme.font.heading
	toggle.TextSize = 16
	toggle.Parent = row
	Theme.corner(toggle, 8)

	return row, toggle
end

local function styleToggle(button: TextButton, isOn: boolean)
	if isOn then
		button.BackgroundColor3 = Theme.colors.buyAction
		button.Text = "ON"
	else
		button.BackgroundColor3 = Theme.colors.dim
		button.Text = "OFF"
	end
end

function Settings.build(parent: ScreenGui): Handle
	-- Floating gear in top-right corner.
	local gearButton = Instance.new("TextButton")
	gearButton.Name = "SettingsGear"
	gearButton.Size = UDim2.fromOffset(48, 48)
	gearButton.Position = UDim2.new(1, -60, 0, 12)
	gearButton.BackgroundColor3 = Theme.colors.panel
	gearButton.AutoButtonColor = false
	gearButton.Text = "⚙"
	gearButton.TextColor3 = Theme.colors.text
	gearButton.Font = Theme.font.heading
	gearButton.TextSize = 28
	gearButton.ZIndex = 80
	gearButton.Parent = parent
	Theme.corner(gearButton, 12)
	Theme.stroke(gearButton, Theme.colors.panelHi, 2, 0)

	-- Modal panel.
	local panel = Instance.new("Frame")
	panel.Name = "SettingsPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 380, 0, 280)
	panel.BackgroundColor3 = Theme.colors.panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 90
	panel.Parent = parent
	Theme.corner(panel, 16)
	Theme.stroke(panel, Theme.colors.gold, 2, 0)
	Theme.padding(panel, 18)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "Settings"
	title.TextColor3 = Theme.colors.gold
	title.Font = Theme.font.display
	title.TextSize = 26
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 91
	title.Parent = panel

	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, 0, 1, -100)
	list.Position = UDim2.fromOffset(0, 44)
	list.BackgroundTransparency = 1
	list.ZIndex = 91
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local _, sfxButton = makeToggle(list, 1, "Sound effects", "🔊")
	local _, musicButton = makeToggle(list, 2, "Background music", "🎵")
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child.ZIndex = 91
			for _, gc in ipairs(child:GetDescendants()) do
				if gc:IsA("GuiObject") then gc.ZIndex = 92 end
			end
		end
	end

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(1, 0, 0, 44)
	closeButton.Position = UDim2.new(0, 0, 1, -44)
	closeButton.BackgroundColor3 = Theme.colors.cta
	closeButton.AutoButtonColor = false
	closeButton.Text = "Close"
	closeButton.TextColor3 = Theme.colors.text
	closeButton.Font = Theme.font.heading
	closeButton.TextSize = 18
	closeButton.ZIndex = 92
	closeButton.Parent = panel
	Theme.corner(closeButton, 10)

	local handle: Handle = {
		gearButton = gearButton,
		panel = panel,
		sfxButton = sfxButton,
		musicButton = musicButton,
		closeButton = closeButton,
		values = { sfxVolume = 1.0, musicVolume = 0.6 },
		setValues = function(_) end, -- placeholder, replaced below
		onChange = nil,
	}

	local function fire()
		styleToggle(handle.sfxButton, handle.values.sfxVolume > 0)
		styleToggle(handle.musicButton, handle.values.musicVolume > 0)
		if handle.onChange then handle.onChange(handle.values) end
	end

	handle.setValues = function(v: Values)
		handle.values.sfxVolume = math.clamp(v.sfxVolume or 1, 0, 1)
		handle.values.musicVolume = math.clamp(v.musicVolume or 0.6, 0, 1)
		styleToggle(handle.sfxButton, handle.values.sfxVolume > 0)
		styleToggle(handle.musicButton, handle.values.musicVolume > 0)
	end

	-- Local interactions.
	local function showPanel()
		panel.Visible = true
		panel.Size = UDim2.new(0, 0, 0, 0)
		TweenService:Create(panel, TweenInfo.new(
			0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out
		), { Size = UDim2.new(0, 380, 0, 280) }):Play()
	end

	local function hidePanel()
		local tween = TweenService:Create(panel, TweenInfo.new(
			0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In
		), { Size = UDim2.new(0, 0, 0, 0) })
		tween:Play()
		tween.Completed:Connect(function()
			panel.Visible = false
		end)
	end

	gearButton.MouseButton1Click:Connect(function()
		if panel.Visible then hidePanel() else showPanel() end
	end)
	closeButton.MouseButton1Click:Connect(hidePanel)

	sfxButton.MouseButton1Click:Connect(function()
		handle.values.sfxVolume = handle.values.sfxVolume > 0 and 0 or 1.0
		fire()
	end)
	musicButton.MouseButton1Click:Connect(function()
		handle.values.musicVolume = handle.values.musicVolume > 0 and 0 or 0.6
		fire()
	end)

	return handle
end

return Settings
