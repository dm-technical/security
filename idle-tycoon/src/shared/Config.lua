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
	icon: string, -- emoji or rbxassetid placeholder
	baseCost: number,
	baseRevenue: number,
	cycleTime: number, -- seconds for one production cycle at level 1
	costMultiplier: number, -- per-level cost growth
	managerCost: number,
	managerName: string,
}

-- Tuned roughly after AdVenture Capitalist for familiar pacing.
Config.BUSINESSES = {
	-- Early businesses are deliberately cheap with low cost-growth so new
	-- players get rapid wins in their first ~5 minutes.
	{
		id = "lemonade",
		name = "Lemonade Stand",
		icon = "🍋",
		baseCost = 3,
		baseRevenue = 1,
		cycleTime = 1,
		costMultiplier = 1.05,
		managerCost = 250,
		managerName = "Mrs. Squeezy",
	},
	{
		id = "newspaper",
		name = "Newspaper Delivery",
		icon = "📰",
		baseCost = 40,
		baseRevenue = 60,
		cycleTime = 3,
		costMultiplier = 1.10,
		managerCost = 2_500,
		managerName = "Hank the Paperboy",
	},
	{
		id = "carwash",
		name = "Car Wash",
		icon = "🚗",
		baseCost = 500,
		baseRevenue = 540,
		cycleTime = 6,
		costMultiplier = 1.12,
		managerCost = 25_000,
		managerName = "Suds McGee",
	},
	{
		id = "pizza",
		name = "Pizza Place",
		icon = "🍕",
		baseCost = 6_000,
		baseRevenue = 4_320,
		cycleTime = 12,
		costMultiplier = 1.13,
		managerCost = 200_000,
		managerName = "Tony Pepperoni",
	},
	{
		id = "donut",
		name = "Donut Shop",
		icon = "🍩",
		baseCost = 103_680,
		baseRevenue = 51_840,
		cycleTime = 24,
		costMultiplier = 1.12,
		managerCost = 1_200_000,
		managerName = "Glaze Goodman",
	},
	{
		id = "shrimp",
		name = "Shrimp Boat",
		icon = "🦐",
		baseCost = 1_244_160,
		baseRevenue = 622_080,
		cycleTime = 96,
		costMultiplier = 1.11,
		managerCost = 10_000_000,
		managerName = "Captain Crustacean",
	},
	{
		id = "hockey",
		name = "Hockey Team",
		icon = "🏒",
		baseCost = 14_929_920,
		baseRevenue = 7_464_960,
		cycleTime = 384,
		costMultiplier = 1.10,
		managerCost = 111_111_111,
		managerName = "Coach Slapshot",
	},
	{
		id = "movie",
		name = "Movie Studio",
		icon = "🎬",
		baseCost = 179_159_040,
		baseRevenue = 89_579_520,
		cycleTime = 1_536,
		costMultiplier = 1.09,
		managerCost = 555_555_555,
		managerName = "Director DeMille",
	},
	{
		id = "bank",
		name = "Bank",
		icon = "🏦",
		baseCost = 2_149_908_480,
		baseRevenue = 1_074_954_240,
		cycleTime = 6_144,
		costMultiplier = 1.08,
		managerCost = 10_000_000_000,
		managerName = "Vince Vault",
	},
	{
		id = "oil",
		name = "Oil Company",
		icon = "🛢️",
		baseCost = 25_798_901_760,
		baseRevenue = 12_899_450_880,
		cycleTime = 36_864,
		costMultiplier = 1.07,
		managerCost = 100_000_000_000,
		managerName = "Derrick Crude",
	},
} :: { BusinessDef }

-- Lookup by id for O(1) access.
Config.BUSINESS_BY_ID = {}
for _, def in ipairs(Config.BUSINESSES) do
	Config.BUSINESS_BY_ID[def.id] = def
end

return Config
