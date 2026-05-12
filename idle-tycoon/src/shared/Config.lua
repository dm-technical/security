--!strict
-- Game configuration: businesses, managers, upgrades, and economy tuning.
-- All scalar money values are stored as Lua numbers (IEEE 754 doubles).
-- Doubles cover ~1.7e308 which exceeds anything reachable in normal play.

local Config = {}

Config.STARTING_MONEY = 10

-- How many seconds of offline accrual a returning player can collect.
Config.MAX_OFFLINE_SECONDS = 12 * 60 * 60 -- 12 hours
-- Offline production rate is scaled down so AFK is meaningful but not better than playing.
Config.OFFLINE_EARN_RATE = 0.5

-- Server tick interval (seconds). Lower = smoother numbers, higher CPU.
Config.TICK_INTERVAL = 0.1
-- Autosave interval (seconds).
Config.AUTOSAVE_INTERVAL = 60
-- Minimum spacing between purchase saves (debounce).
Config.PURCHASE_SAVE_COOLDOWN = 5

-- Each milestone multiplies revenue. Triggered when ownedCount crosses the level.
-- Level 10 is intentionally early so new players get their first celebration
-- within ~60 seconds of starting.
Config.MILESTONES = {
	{ level = 10,   multiplier = 2 },
	{ level = 25,   multiplier = 3 },
	{ level = 50,   multiplier = 3 },
	{ level = 100,  multiplier = 3 },
	{ level = 200,  multiplier = 3 },
	{ level = 300,  multiplier = 3 },
	{ level = 400,  multiplier = 3 },
	{ level = 500,  multiplier = 3 },
}

-- Default settings for new profiles.
Config.DEFAULT_SETTINGS = {
	sfxVolume = 1.0,
	musicVolume = 0.6,
}

-- Quantity buy options. UI cycles through these.
Config.BUY_QUANTITIES = { 1, 10, 100, "MAX" }

export type BusinessDef = {
	id: string,
	name: string,
	icon: string,
	iconAssetId: string,
	baseCost: number,
	baseRevenue: number,
	-- Science yield per completed cycle at 1 owned. Scales like baseRevenue
	-- (×owned ×milestoneMult ×globalMult) inside Economy.cycleScience.
	-- Roughly 10% of baseRevenue so funds outpace science 10:1, the rate
	-- the R&D-cost table is balanced against.
	cycleScience: number,
	cycleTime: number,
	costMultiplier: number,
	managerCost: number,
	managerName: string,
}

-- Tuned roughly after AdVenture Capitalist for familiar pacing.
-- Internal IDs (lemonade/newspaper/etc.) preserved from the v1 economy so
-- existing saves keep their progress; only display strings change for the
-- space-agency rebrand.
Config.BUSINESSES = {
	-- Early programs are deliberately cheap with low cost-growth so new
	-- agencies get rapid wins in their first ~5 minutes.
	{
		id = "lemonade",
		name = "Sounding Rocket",
		icon = "🚀",
		iconAssetId = "",
		baseCost = 3,
		baseRevenue = 1,
		cycleScience = 0.1,
		cycleTime = 1,
		costMultiplier = 1.05,
		managerCost = 250,
		managerName = "Dr. Volkov",
	},
	{
		id = "newspaper",
		name = "Comm Satellite",
		icon = "🛰️",
		iconAssetId = "",
		baseCost = 40,
		baseRevenue = 60,
		cycleScience = 6,
		cycleTime = 3,
		costMultiplier = 1.10,
		managerCost = 2_500,
		managerName = "Cmdr. Phillips",
	},
	{
		id = "carwash",
		name = "Crewed Capsule",
		icon = "👨‍🚀",
		iconAssetId = "",
		baseCost = 500,
		baseRevenue = 540,
		cycleScience = 54,
		cycleTime = 6,
		costMultiplier = 1.12,
		managerCost = 25_000,
		managerName = "Pilot Aoki",
	},
	{
		id = "pizza",
		name = "Lunar Probe",
		icon = "🌑",
		iconAssetId = "",
		baseCost = 6_000,
		baseRevenue = 4_320,
		cycleScience = 432,
		cycleTime = 12,
		costMultiplier = 1.13,
		managerCost = 200_000,
		managerName = "Dr. Patel",
	},
	{
		id = "donut",
		name = "Mun Lander",
		icon = "🌕",
		iconAssetId = "",
		baseCost = 103_680,
		baseRevenue = 51_840,
		cycleScience = 5_184,
		cycleTime = 24,
		costMultiplier = 1.12,
		managerCost = 1_200_000,
		managerName = "Maj. Sanchez",
	},
	{
		id = "shrimp",
		name = "Mars Mission",
		icon = "🔴",
		iconAssetId = "",
		baseCost = 1_244_160,
		baseRevenue = 622_080,
		cycleScience = 62_208,
		cycleTime = 96,
		costMultiplier = 1.11,
		managerCost = 10_000_000,
		managerName = "Dr. Lindqvist",
	},
	{
		id = "hockey",
		name = "Outer System Probe",
		icon = "🪐",
		iconAssetId = "",
		baseCost = 14_929_920,
		baseRevenue = 7_464_960,
		cycleScience = 746_496,
		cycleTime = 384,
		costMultiplier = 1.10,
		managerCost = 111_111_111,
		managerName = "Cmdr. Okafor",
	},
	{
		id = "movie",
		name = "Interstellar Probe",
		icon = "✨",
		iconAssetId = "",
		baseCost = 179_159_040,
		baseRevenue = 89_579_520,
		cycleScience = 8_957_952,
		cycleTime = 1_536,
		costMultiplier = 1.09,
		managerCost = 555_555_555,
		managerName = "Dr. Chen",
	},
	{
		id = "bank",
		name = "Orbital Colony",
		icon = "🛸",
		iconAssetId = "",
		baseCost = 2_149_908_480,
		baseRevenue = 1_074_954_240,
		cycleScience = 107_495_424,
		cycleTime = 6_144,
		costMultiplier = 1.08,
		managerCost = 10_000_000_000,
		managerName = "Eng. Petrov",
	},
	{
		id = "oil",
		name = "Generation Ship",
		icon = "🌌",
		iconAssetId = "",
		baseCost = 25_798_901_760,
		baseRevenue = 12_899_450_880,
		cycleScience = 1_289_945_088,
		cycleTime = 36_864,
		costMultiplier = 1.07,
		managerCost = 100_000_000_000,
		managerName = "Adm. Stellaris",
	},
} :: { BusinessDef }

-- Lookup by id for O(1) access.
Config.BUSINESS_BY_ID = {}
for _, def in ipairs(Config.BUSINESSES) do
	Config.BUSINESS_BY_ID[def.id] = def
end

return Config
