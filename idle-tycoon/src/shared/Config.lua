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
	callsign: string, -- mission-designation prefix; appears in launch floats
	-- Star-system id; drives the section header in the businesses scroll.
	-- "sol" for the home system, "alpha_centauri" for the first interstellar
	-- system, etc.
	system: string,
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
	-- Tech node ids the player must research before founding this program.
	-- Empty = available from the start. Only gates the FIRST purchase
	-- (owned == 0); once founded, the program scales freely.
	requiresTech: { string },
}

-- Star-system metadata for the section headers above each group of
-- programs. Display name + icon are the only thing the UI needs.
export type SystemDef = {
	id: string,
	name: string,
	icon: string,
}

Config.SYSTEMS = {
	{ id = "sol",            name = "SOL SYSTEM",     icon = "🌞" },
	{ id = "alpha_centauri", name = "ALPHA CENTAURI", icon = "⭐" },
} :: { SystemDef }

Config.SYSTEM_BY_ID = {}
for _, sys in ipairs(Config.SYSTEMS) do
	Config.SYSTEM_BY_ID[sys.id] = sys
end

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
		callsign = "SR",
		system = "sol",
		baseCost = 3,
		baseRevenue = 1,
		cycleScience = 0.1,
		cycleTime = 1,
		costMultiplier = 1.05,
		managerCost = 250,
		managerName = "Dr. Volkov",
		requiresTech = {}, -- always available — starting program
	},
	{
		id = "newspaper",
		name = "Comm Satellite",
		icon = "🛰️",
		iconAssetId = "",
		callsign = "CS",
		system = "sol",
		baseCost = 40,
		baseRevenue = 60,
		cycleScience = 6,
		cycleTime = 3,
		costMultiplier = 1.10,
		managerCost = 2_500,
		managerName = "Cmdr. Phillips",
		requiresTech = { "tech_telemetry" },
	},
	{
		id = "carwash",
		name = "Crewed Capsule",
		icon = "👨‍🚀",
		iconAssetId = "",
		callsign = "CC",
		system = "sol",
		baseCost = 500,
		baseRevenue = 540,
		cycleScience = 54,
		cycleTime = 6,
		costMultiplier = 1.12,
		managerCost = 25_000,
		managerName = "Pilot Aoki",
		requiresTech = { "tech_life_support" },
	},
	{
		id = "pizza",
		name = "Lunar Probe",
		icon = "🌑",
		iconAssetId = "",
		callsign = "LP",
		system = "sol",
		baseCost = 6_000,
		baseRevenue = 4_320,
		cycleScience = 432,
		cycleTime = 12,
		costMultiplier = 1.13,
		managerCost = 200_000,
		managerName = "Dr. Patel",
		requiresTech = { "tech_long_range_comms" },
	},
	{
		id = "donut",
		name = "Mun Lander",
		icon = "🌕",
		iconAssetId = "",
		callsign = "ML",
		system = "sol",
		baseCost = 103_680,
		baseRevenue = 51_840,
		cycleScience = 5_184,
		cycleTime = 24,
		costMultiplier = 1.12,
		managerCost = 1_200_000,
		managerName = "Maj. Sanchez",
		requiresTech = { "tech_lunar_landing" },
	},
	{
		id = "shrimp",
		name = "Mars Mission",
		icon = "🔴",
		iconAssetId = "",
		callsign = "MM",
		system = "sol",
		baseCost = 1_244_160,
		baseRevenue = 622_080,
		cycleScience = 62_208,
		cycleTime = 96,
		costMultiplier = 1.11,
		managerCost = 10_000_000,
		managerName = "Dr. Lindqvist",
		requiresTech = { "tech_interplanetary" },
	},
	{
		id = "hockey",
		name = "Outer System Probe",
		icon = "🪐",
		iconAssetId = "",
		callsign = "OS",
		system = "sol",
		baseCost = 14_929_920,
		baseRevenue = 7_464_960,
		cycleScience = 746_496,
		cycleTime = 384,
		costMultiplier = 1.10,
		managerCost = 111_111_111,
		managerName = "Cmdr. Okafor",
		requiresTech = { "tech_deep_space" },
	},
	{
		id = "movie",
		name = "Interstellar Probe",
		icon = "✨",
		iconAssetId = "",
		callsign = "IS",
		system = "sol",
		baseCost = 179_159_040,
		baseRevenue = 89_579_520,
		cycleScience = 8_957_952,
		cycleTime = 1_536,
		costMultiplier = 1.09,
		managerCost = 555_555_555,
		managerName = "Dr. Chen",
		requiresTech = { "tech_warp_theory" },
	},
	{
		id = "bank",
		name = "Orbital Colony",
		icon = "🛸",
		iconAssetId = "",
		callsign = "OC",
		system = "sol",
		baseCost = 2_149_908_480,
		baseRevenue = 1_074_954_240,
		cycleScience = 107_495_424,
		cycleTime = 6_144,
		costMultiplier = 1.08,
		managerCost = 10_000_000_000,
		managerName = "Eng. Petrov",
		requiresTech = { "tech_colonization" },
	},
	{
		id = "oil",
		name = "Generation Ship",
		icon = "🌌",
		iconAssetId = "",
		callsign = "GS",
		system = "sol",
		baseCost = 25_798_901_760,
		baseRevenue = 12_899_450_880,
		cycleScience = 1_289_945_088,
		cycleTime = 36_864,
		costMultiplier = 1.07,
		managerCost = 100_000_000_000,
		managerName = "Adm. Stellaris",
		requiresTech = { "tech_ftl" },
	},

	-- Alpha Centauri system. Each program is ~100× the economy of the
	-- previous tier and cycle times stretch into the multi-hour range
	-- (interstellar missions take a while). Tech-gated by the new
	-- "tech_centauri_*" research chain.
	{
		id = "proxima",
		name = "Proxima Probe",
		icon = "🌠",
		iconAssetId = "",
		callsign = "PP",
		system = "alpha_centauri",
		baseCost = 1_000_000_000_000,         -- $1T
		baseRevenue = 500_000_000_000,        -- $500B per cycle
		cycleScience = 50_000_000_000,        -- 50B per cycle
		cycleTime = 50_000,                   -- ~14 hours
		costMultiplier = 1.06,
		managerCost = 5_000_000_000_000,      -- $5T
		managerName = "Dr. Singh",
		requiresTech = { "tech_centauri_drive" },
	},
	{
		id = "centauri_outpost",
		name = "Centauri Outpost",
		icon = "🛰️",
		iconAssetId = "",
		callsign = "CT",
		system = "alpha_centauri",
		baseCost = 25_000_000_000_000,        -- $25T
		baseRevenue = 12_000_000_000_000,     -- $12T per cycle
		cycleScience = 1_200_000_000_000,
		cycleTime = 80_000,                   -- ~22 hours
		costMultiplier = 1.05,
		managerCost = 100_000_000_000_000,    -- $100T
		managerName = "Cmdr. Voss",
		requiresTech = { "tech_centauri_settlement" },
	},
	{
		id = "centauri_megacity",
		name = "Centauri Megacity",
		icon = "🏙️",
		iconAssetId = "",
		callsign = "CM",
		system = "alpha_centauri",
		baseCost = 500_000_000_000_000,       -- $500T
		baseRevenue = 250_000_000_000_000,    -- $250T per cycle
		cycleScience = 25_000_000_000_000,
		cycleTime = 120_000,                  -- ~33 hours
		costMultiplier = 1.04,
		managerCost = 1_000_000_000_000_000,  -- $1Qa
		managerName = "Adm. Cosmos",
		requiresTech = { "tech_centauri_megacity" },
	},
} :: { BusinessDef }

-- Lookup by id for O(1) access.
Config.BUSINESS_BY_ID = {}
for _, def in ipairs(Config.BUSINESSES) do
	Config.BUSINESS_BY_ID[def.id] = def
end

return Config
