--!strict
-- Center-column content for the Prestige tab. Shows current level + bonus,
-- per-run progress to the next prestige, what gets kept vs reset, and a
-- big PRESTIGE button that's disabled until eligible.
--
-- All numbers update each frame via setState(); a pure render function.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Prestige = require(Shared.Prestige)

local Theme = require(script.Parent.Theme)

local PrestigePanel = {}

export type Handle = {
	frame: Frame,
	prestigeButton: TextButton,
	levelLabel: TextLabel,
	bonusLabel: TextLabel,
	progressFill: Frame,
	progressLabel: TextLabel,
	nextBonusLabel: TextLabel,
	-- Updates everything from the current profile-like state.
	setState: (level: number, earnedThisRun: number, requirement: number, canPrestige: boolean) -> (),
}

function PrestigePanel.build(parent: Instance): Handle
	-- Top-level container; same position/size as the other center scrolls so
	-- swapping visibility lines up.
	local frame = Instance.new("Frame")
	frame.Name = "Prestige"
	frame.Visible = false
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, 0)
	card.Size = UDim2.new(1, -16, 0, 520)
	card.BackgroundColor3 = Theme.colors.panel
	card.BorderSizePixel = 0
	card.Parent = frame
	Theme.corner(card, 18)
	Theme.stroke(card, Theme.colors.gem, 2, 0.3)
	Theme.padding(card, 24)

	-- Crown + title.
	local crown = Instance.new("TextLabel")
	crown.Size = UDim2.fromOffset(64, 64)
	crown.Position = UDim2.fromOffset(0, 0)
	crown.BackgroundTransparency = 1
	crown.Text = "👑"
	crown.Font = Theme.font.heading
	crown.TextScaled = true
	crown.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Position = UDim2.fromOffset(72, 0)
	title.BackgroundTransparency = 1
	title.Text = "NEW GENERATION"
	title.TextColor3 = Theme.colors.gemBright
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Theme.font.display
	title.TextSize = 28
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -80, 0, 22)
	subtitle.Position = UDim2.fromOffset(72, 34)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Reorganize your agency for a permanent funds multiplier"
	subtitle.TextColor3 = Theme.colors.muted
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Font = Theme.font.body
	subtitle.TextSize = 15
	subtitle.Parent = card

	-- Current level + bonus stat box.
	local statBox = Instance.new("Frame")
	statBox.Position = UDim2.fromOffset(0, 84)
	statBox.Size = UDim2.new(1, 0, 0, 72)
	statBox.BackgroundColor3 = Theme.colors.panelAlt
	statBox.BorderSizePixel = 0
	statBox.Parent = card
	Theme.corner(statBox, 12)
	Theme.padding(statBox, 14)

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.new(0.5, 0, 1, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Generation 0"
	levelLabel.TextColor3 = Theme.colors.text
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Font = Theme.font.display
	levelLabel.TextSize = 28
	levelLabel.Parent = statBox

	local bonusLabel = Instance.new("TextLabel")
	bonusLabel.AnchorPoint = Vector2.new(1, 0.5)
	bonusLabel.Position = UDim2.new(1, 0, 0.5, 0)
	bonusLabel.Size = UDim2.new(0.5, 0, 1, 0)
	bonusLabel.BackgroundTransparency = 1
	bonusLabel.Text = "+0% funds"
	bonusLabel.TextColor3 = Theme.colors.gemBright
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Right
	bonusLabel.Font = Theme.font.display
	bonusLabel.TextSize = 24
	bonusLabel.Parent = statBox

	-- Progress bar toward next prestige.
	local progLabel = Instance.new("TextLabel")
	progLabel.Position = UDim2.fromOffset(0, 174)
	progLabel.Size = UDim2.new(1, 0, 0, 22)
	progLabel.BackgroundTransparency = 1
	progLabel.Text = "Earn $1M to advance"
	progLabel.TextColor3 = Theme.colors.text
	progLabel.TextXAlignment = Enum.TextXAlignment.Left
	progLabel.Font = Theme.font.heading
	progLabel.TextSize = 16
	progLabel.Parent = card

	local progressBar = Instance.new("Frame")
	progressBar.Position = UDim2.fromOffset(0, 202)
	progressBar.Size = UDim2.new(1, 0, 0, 28)
	progressBar.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
	progressBar.BorderSizePixel = 0
	progressBar.ClipsDescendants = true
	progressBar.Parent = card
	Theme.corner(progressBar, 8)

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Theme.colors.gem
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBar
	Theme.corner(progressFill, 8)

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Size = UDim2.fromScale(1, 1)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "$0 / $1M"
	progressLabel.TextColor3 = Theme.colors.text
	progressLabel.Font = Theme.font.heading
	progressLabel.TextSize = 14
	progressLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	progressLabel.TextStrokeTransparency = 0.6
	progressLabel.Parent = progressBar

	-- "What you'll keep / lose" cards.
	local keepCard = Instance.new("Frame")
	keepCard.Position = UDim2.fromOffset(0, 254)
	keepCard.Size = UDim2.new(0.5, -8, 0, 132)
	keepCard.BackgroundColor3 = Theme.colors.panelAlt
	keepCard.BorderSizePixel = 0
	keepCard.Parent = card
	Theme.corner(keepCard, 12)
	Theme.padding(keepCard, 12)

	local keepTitle = Instance.new("TextLabel")
	keepTitle.Size = UDim2.new(1, 0, 0, 20)
	keepTitle.BackgroundTransparency = 1
	keepTitle.Text = "✓  You'll keep"
	keepTitle.TextColor3 = Theme.colors.buyBright
	keepTitle.TextXAlignment = Enum.TextXAlignment.Left
	keepTitle.Font = Theme.font.heading
	keepTitle.TextSize = 14
	keepTitle.Parent = keepCard

	local keepBody = Instance.new("TextLabel")
	keepBody.Position = UDim2.fromOffset(0, 24)
	keepBody.Size = UDim2.new(1, 0, 1, -24)
	keepBody.BackgroundTransparency = 1
	keepBody.Text = "• Science crystals\n• Achievements\n• Agency records\n• +20% funds per generation"
	keepBody.TextColor3 = Theme.colors.text
	keepBody.TextXAlignment = Enum.TextXAlignment.Left
	keepBody.TextYAlignment = Enum.TextYAlignment.Top
	keepBody.Font = Theme.font.body
	keepBody.TextSize = 13
	keepBody.Parent = keepCard

	local loseCard = Instance.new("Frame")
	loseCard.AnchorPoint = Vector2.new(1, 0)
	loseCard.Position = UDim2.new(1, 0, 0, 254)
	loseCard.Size = UDim2.new(0.5, -8, 0, 132)
	loseCard.BackgroundColor3 = Theme.colors.panelAlt
	loseCard.BorderSizePixel = 0
	loseCard.Parent = card
	Theme.corner(loseCard, 12)
	Theme.padding(loseCard, 12)

	local loseTitle = Instance.new("TextLabel")
	loseTitle.Size = UDim2.new(1, 0, 0, 20)
	loseTitle.BackgroundTransparency = 1
	loseTitle.Text = "✗  You'll reset"
	loseTitle.TextColor3 = Theme.colors.cta
	loseTitle.TextXAlignment = Enum.TextXAlignment.Left
	loseTitle.Font = Theme.font.heading
	loseTitle.TextSize = 14
	loseTitle.Parent = loseCard

	local loseBody = Instance.new("TextLabel")
	loseBody.Position = UDim2.fromOffset(0, 24)
	loseBody.Size = UDim2.new(1, 0, 1, -24)
	loseBody.BackgroundTransparency = 1
	loseBody.Text = "• Funds\n• Vehicle fleet\n• Mission directors\n• Researched R&D"
	loseBody.TextColor3 = Theme.colors.text
	loseBody.TextXAlignment = Enum.TextXAlignment.Left
	loseBody.TextYAlignment = Enum.TextYAlignment.Top
	loseBody.Font = Theme.font.body
	loseBody.TextSize = 13
	loseBody.Parent = loseCard

	-- Big prestige button at the bottom.
	local prestigeButton = Instance.new("TextButton")
	prestigeButton.AnchorPoint = Vector2.new(0.5, 1)
	prestigeButton.Position = UDim2.new(0.5, 0, 1, 0)
	prestigeButton.Size = UDim2.new(1, 0, 0, 64)
	prestigeButton.BackgroundColor3 = Theme.colors.gem
	prestigeButton.AutoButtonColor = false
	prestigeButton.Text = "ADVANCE GENERATION"
	prestigeButton.TextColor3 = Theme.colors.text
	prestigeButton.Font = Theme.font.display
	prestigeButton.TextSize = 24
	prestigeButton.Parent = card
	Theme.corner(prestigeButton, 14)
	Theme.stroke(prestigeButton, Theme.colors.gemBright, 2, 0)

	local nextBonusLabel = Instance.new("TextLabel")
	nextBonusLabel.AnchorPoint = Vector2.new(0.5, 1)
	nextBonusLabel.Position = UDim2.new(0.5, 0, 1, -72)
	nextBonusLabel.Size = UDim2.new(1, 0, 0, 20)
	nextBonusLabel.BackgroundTransparency = 1
	nextBonusLabel.Text = "Next generation: +20% funds"
	nextBonusLabel.TextColor3 = Theme.colors.gemBright
	nextBonusLabel.Font = Theme.font.heading
	nextBonusLabel.TextSize = 14
	nextBonusLabel.Parent = card

	local handle: Handle = {
		frame = frame,
		prestigeButton = prestigeButton,
		levelLabel = levelLabel,
		bonusLabel = bonusLabel,
		progressFill = progressFill,
		progressLabel = progressLabel,
		nextBonusLabel = nextBonusLabel,
		setState = function(_, _, _, _) end,
	}

	handle.setState = function(level, earnedThisRun, requirement, canPrestige)
		levelLabel.Text = "Generation " .. tostring(level)
		bonusLabel.Text = Prestige.bonusText(level) .. " funds"

		local frac = if requirement > 0
			then math.min(1, earnedThisRun / requirement)
			else 1
		progressFill.Size = UDim2.fromScale(frac, 1)
		progressLabel.Text = Format.money(earnedThisRun) .. " / " .. Format.money(requirement)

		progLabel.Text = canPrestige
			and "Ready to advance!"
			or ("Earn " .. Format.money(math.max(0, requirement - earnedThisRun)) .. " more to advance")

		nextBonusLabel.Text = "Next generation: " .. Prestige.bonusText(level + 1) .. " funds (+20%)"

		if canPrestige then
			prestigeButton.BackgroundColor3 = Theme.colors.gem
			prestigeButton.TextColor3 = Theme.colors.text
			prestigeButton.Active = true
		else
			prestigeButton.BackgroundColor3 = Theme.colors.buyDim
			prestigeButton.TextColor3 = Theme.colors.muted
			prestigeButton.Active = false
		end
	end

	return handle
end

return PrestigePanel
