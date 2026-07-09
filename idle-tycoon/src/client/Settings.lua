--!strict
-- Settings panel: floating gear button + slide-out modal with volume
-- sliders for SFX + Music. Stores nothing locally; emits an `onChange`
-- callback the controller wires to the server's UpdateSettings remote
-- and to the Sounds/Music modules for immediate audio feedback.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local Settings = {}

export type Values = { sfxVolume: number, musicVolume: number }

export type SliderHandle = {
	row: Frame,
	track: TextButton, -- doubles as input surface for drag
	fill: Frame,
	knob: Frame,
	percentLabel: TextLabel,
	setValue: (v: number) -> (),
}

export type Handle = {
	gearButton: TextButton,
	panel: Frame,
	sfxSlider: SliderHandle,
	musicSlider: SliderHandle,
	closeButton: TextButton,
	values: Values,
	setValues: (values: Values) -> (),
	-- Fires continuously as the player drags a slider. Use this for immediate
	-- local audio feedback (Sounds.setVolume / Music.setVolume).
	onChange: ((Values) -> ())?,
	-- Fires once when the drag ends (mouse-up / touch-end). Use this to
	-- persist to the server — avoids spamming the UpdateSettings remote.
	onCommit: ((Values) -> ())?,
}

local TRACK_HEIGHT = 12
local KNOB_SIZE = 22

-- Build one slider row: icon (left), label + percent (top), track (below).
local function makeSlider(parent: Instance, layoutOrder: number, label: string, icon: string): SliderHandle
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 72)
	row.BackgroundColor3 = Theme.colors.panelAlt
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	row.Parent = parent
	Theme.corner(row, 10)
	Theme.padding(row, 12)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromOffset(30, 30)
	iconLabel.Position = UDim2.fromOffset(0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.Font = Theme.font.heading
	iconLabel.TextSize = 22
	iconLabel.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -100, 0, 26)
	nameLabel.Position = UDim2.fromOffset(38, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = label
	nameLabel.TextColor3 = Theme.colors.text
	nameLabel.Font = Theme.font.heading
	nameLabel.TextSize = 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local percentLabel = Instance.new("TextLabel")
	percentLabel.AnchorPoint = Vector2.new(1, 0)
	percentLabel.Position = UDim2.new(1, 0, 0, 0)
	percentLabel.Size = UDim2.fromOffset(60, 26)
	percentLabel.BackgroundTransparency = 1
	percentLabel.Text = "0%"
	percentLabel.TextColor3 = Theme.colors.muted
	percentLabel.Font = Theme.font.display
	percentLabel.TextSize = 14
	percentLabel.TextXAlignment = Enum.TextXAlignment.Right
	percentLabel.Parent = row

	-- Track sits below the header row. TextButton so we get InputBegan
	-- for drag; no visible text.
	local track = Instance.new("TextButton")
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.new(0, 0, 1, 0)
	track.Size = UDim2.new(1, 0, 0, TRACK_HEIGHT)
	track.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
	track.AutoButtonColor = false
	track.Text = ""
	track.Parent = row
	Theme.corner(track, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.colors.buyAction
	fill.BorderSizePixel = 0
	fill.Parent = track
	Theme.corner(fill, 6)

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE)
	knob.BackgroundColor3 = Theme.colors.buyBright
	knob.BorderSizePixel = 0
	knob.ZIndex = 2
	knob.Parent = track
	Theme.corner(knob, KNOB_SIZE)
	Theme.stroke(knob, Theme.colors.panel, 2, 0)

	local handle: SliderHandle = {
		row = row,
		track = track,
		fill = fill,
		knob = knob,
		percentLabel = percentLabel,
		setValue = function(_) end,
	}

	handle.setValue = function(v: number)
		v = math.clamp(v, 0, 1)
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
		percentLabel.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
	end

	return handle
end

-- Wire mouse/touch drag on a slider. onDrag(fraction) is called continuously
-- while dragging; onCommit(fraction) fires once when the drag ends so we can
-- persist to the server without spamming remotes during the drag itself.
local function bindDrag(slider: SliderHandle, onDrag: (number) -> (), onCommit: (number) -> ())
	local dragging = false

	local function updateFromInput(input: InputObject)
		local trackPos = slider.track.AbsolutePosition
		local trackSize = slider.track.AbsoluteSize
		local relativeX = input.Position.X - trackPos.X
		local fraction = if trackSize.X > 0 then math.clamp(relativeX / trackSize.X, 0, 1) else 0
		onDrag(fraction)
	end

	slider.track.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromInput(input)
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromInput(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			-- Compute the final value from the current slider position (we've
			-- already been mirroring the drag into the fill), then commit.
			local trackSize = slider.track.AbsoluteSize
			local fillSize = slider.fill.AbsoluteSize
			local fraction = if trackSize.X > 0 then fillSize.X / trackSize.X else 0
			onCommit(math.clamp(fraction, 0, 1))
		end
	end)
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

	-- Modal panel. Taller than before to fit the slider rows.
	local panel = Instance.new("Frame")
	panel.Name = "SettingsPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 400, 0, 320)
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

	local sfxSlider = makeSlider(list, 1, "Sound effects", "🔊")
	local musicSlider = makeSlider(list, 2, "Background music", "🎵")

	-- Bump ZIndex on every slider descendant so they render above the panel
	-- background (the panel Frame is at ZIndex 90; children default to 91).
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
		sfxSlider = sfxSlider,
		musicSlider = musicSlider,
		closeButton = closeButton,
		values = { sfxVolume = 1.0, musicVolume = 0.6 },
		setValues = function(_) end, -- placeholder, replaced below
		onChange = nil,
		onCommit = nil,
	}

	handle.setValues = function(v: Values)
		handle.values.sfxVolume = math.clamp(v.sfxVolume or 1, 0, 1)
		handle.values.musicVolume = math.clamp(v.musicVolume or 0.6, 0, 1)
		sfxSlider.setValue(handle.values.sfxVolume)
		musicSlider.setValue(handle.values.musicVolume)
	end
	handle.setValues(handle.values)

	-- Drag handlers.
	-- During drag (onDrag): update visual + fire handle.onChange every frame
	-- so the controller can update local audio volume immediately.
	-- On drag end (onCommit): fire handle.onCommit exactly once so the
	-- controller can persist the final value to the server without spamming
	-- the UpdateSettings remote during the drag itself.
	bindDrag(sfxSlider,
		function(v: number)
			handle.values.sfxVolume = v
			sfxSlider.setValue(v)
			if handle.onChange then handle.onChange(handle.values) end
		end,
		function(v: number)
			handle.values.sfxVolume = v
			if handle.onCommit then handle.onCommit(handle.values) end
		end
	)
	bindDrag(musicSlider,
		function(v: number)
			handle.values.musicVolume = v
			musicSlider.setValue(v)
			if handle.onChange then handle.onChange(handle.values) end
		end,
		function(v: number)
			handle.values.musicVolume = v
			if handle.onCommit then handle.onCommit(handle.values) end
		end
	)

	-- Local interactions.
	local function showPanel()
		panel.Visible = true
		panel.Size = UDim2.new(0, 0, 0, 0)
		TweenService:Create(panel, TweenInfo.new(
			0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out
		), { Size = UDim2.new(0, 400, 0, 320) }):Play()
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

	return handle
end

return Settings
