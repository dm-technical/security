--!strict
-- Achievement definitions, used by both server (for unlocking) and client
-- (for the right-panel progress display).
--
-- To wire each achievement to a Roblox badge that appears on the player's
-- profile:
--   1. Go to https://create.roblox.com/dashboard → your experience → Badges
--   2. Create a badge per achievement, copy its asset ID (the number).
--   3. Paste the number into `badgeId` below.
-- Leave `badgeId = 0` to skip badge awarding for an achievement.

local Achievements = {}

export type Definition = {
	id: string,
	name: string,
	description: string,
	icon: string,
	target: number,
	gemReward: number,
	badgeId: number,
	-- Which numeric metric on the profile this achievement progresses against.
	progressKey: string, -- "totalEarned" | "totalOwned" | "totalClicks"
}

export type Metrics = {
	totalEarned: number,
	totalOwned: number,
	totalClicks: number,
}

Achievements.DEFINITIONS = {
	{
		id = "first_million",
		name = "First Million",
		description = "Earn $1,000,000 total",
		icon = "💰",
		target = 1_000_000,
		gemReward = 50,
		badgeId = 0,
		progressKey = "totalEarned",
	},
	{
		id = "business_tycoon",
		name = "Business Tycoon",
		description = "Own 50 businesses",
		icon = "🏢",
		target = 50,
		gemReward = 75,
		badgeId = 0,
		progressKey = "totalOwned",
	},
	{
		id = "click_master",
		name = "Click Master",
		description = "Perform 1,000 clicks",
		icon = "👆",
		target = 1_000,
		gemReward = 25,
		badgeId = 0,
		progressKey = "totalClicks",
	},
	{
		id = "billionaire",
		name = "Billionaire",
		description = "Earn $1,000,000,000 total",
		icon = "💎",
		target = 1_000_000_000,
		gemReward = 200,
		badgeId = 0,
		progressKey = "totalEarned",
	},
	{
		id = "click_legend",
		name = "Click Legend",
		description = "Perform 10,000 clicks",
		icon = "⚡",
		target = 10_000,
		gemReward = 100,
		badgeId = 0,
		progressKey = "totalClicks",
	},
} :: { Definition }

Achievements.BY_ID = {}
for _, def in ipairs(Achievements.DEFINITIONS) do
	Achievements.BY_ID[def.id] = def
end

-- Progress value [0, 1] for a single achievement against the given metrics.
function Achievements.progress(def: Definition, metrics: Metrics): number
	if def.target <= 0 then return 1 end
	local current = (metrics :: any)[def.progressKey] or 0
	return math.min(1, current / def.target)
end

-- Current raw metric value for an achievement.
function Achievements.current(def: Definition, metrics: Metrics): number
	return (metrics :: any)[def.progressKey] or 0
end

return Achievements
