--!strict
-- Upgrade definitions and the per-business multiplier they combine into.
-- Two flavors:
--   * "business" upgrades: target a single business by id, gated by owned count.
--   * "global" upgrades:   apply to every business's revenue (or click power),
--                          no owned-count requirement.
--
-- All upgrades are one-time purchases. Multipliers stack multiplicatively
-- (×2 + ×2 = ×4). Server and client both call multiplierFor()/clickMultiplier()
-- so optimistic local extrapolation matches authoritative payout exactly.

local Upgrades = {}

export type Target = string -- "business" | "global_revenue" | "global_click"

export type Definition = {
	id: string,
	name: string,
	description: string,
	icon: string,
	scienceCost: number, -- paid in science (the profile.gems field), not funds
	multiplier: number,
	target: Target,
	businessId: string?, -- set when target == "business"
	requiresOwned: number, -- 0 for global; otherwise minimum owned count of target business
}

-- Helper to generate the three-tier R&D ladder used by every mission program.
-- Costs are science, scaled to take ~10-30 minutes to grind at the unlock
-- point. Field name kept as scienceCost so the buy path is unambiguous.
local function biz(id: string, name: string, icon: string, baseCost: number): { Definition }
	return {
		{
			id = id .. "_25",
			name = name .. " Mk II",
			description = "2x " .. name .. " contract value",
			icon = icon,
			scienceCost = baseCost,
			multiplier = 2,
			target = "business",
			businessId = id,
			requiresOwned = 25,
		},
		{
			id = id .. "_50",
			name = name .. " Mk III",
			description = "3x " .. name .. " contract value",
			icon = icon,
			scienceCost = baseCost * 10,
			multiplier = 3,
			target = "business",
			businessId = id,
			requiresOwned = 50,
		},
		{
			id = id .. "_100",
			name = name .. " Mk IV",
			description = "5x " .. name .. " contract value",
			icon = icon,
			scienceCost = baseCost * 100,
			multiplier = 5,
			target = "business",
			businessId = id,
			requiresOwned = 100,
		},
	}
end

-- Catalog. Tier costs roughly mirror manager prices × 5, 50, 500.
-- Adjust freely; nothing about the math depends on these exact numbers.
local catalog: { Definition } = {
	-- Global research first so they sort to the top.
	{
		id = "global_revenue_1",
		name = "International Coalition",
		description = "+25% funds from all missions",
		icon = "🌐",
		scienceCost = 5_000,
		multiplier = 1.25,
		target = "global_revenue",
		requiresOwned = 0,
	},
	{
		id = "global_revenue_2",
		name = "Lucrative Contracts",
		description = "+50% funds from all missions",
		icon = "📜",
		scienceCost = 500_000,
		multiplier = 1.5,
		target = "global_revenue",
		requiresOwned = 0,
	},
	{
		id = "global_click_1",
		name = "Manual Launch Override",
		description = "+200% manual launch payout",
		icon = "🎯",
		scienceCost = 10_000,
		multiplier = 3,
		target = "global_click",
		requiresOwned = 0,
	},
}

-- Append each program's research ladder. Costs roughly track AC-style scaling.
for _, ladder in ipairs({
	biz("lemonade",  "Sounding Rocket",      "🚀", 1_250),
	biz("newspaper", "Comm Satellite",       "🛰️", 12_500),
	biz("carwash",   "Crewed Capsule",       "👨‍🚀", 125_000),
	biz("pizza",     "Lunar Probe",          "🌑", 1_000_000),
	biz("donut",     "Mun Lander",           "🌕", 5_000_000),
	biz("shrimp",    "Mars Mission",         "🔴", 50_000_000),
	biz("hockey",    "Outer System Probe",   "🪐", 500_000_000),
	biz("movie",     "Interstellar Probe",   "✨", 5_000_000_000),
	biz("bank",      "Orbital Colony",       "🛸", 50_000_000_000),
	biz("oil",       "Generation Ship",      "🌌", 500_000_000_000),
}) do
	for _, def in ipairs(ladder) do
		table.insert(catalog, def)
	end
end

Upgrades.DEFINITIONS = catalog

Upgrades.BY_ID = {}
for _, def in ipairs(catalog) do
	Upgrades.BY_ID[def.id] = def
end

-- Combined multiplier on a specific business's payout, from all purchased
-- upgrades targeting that business + every purchased global revenue upgrade.
function Upgrades.multiplierFor(profile, businessId: string): number
	local mult = 1
	local purchased = profile.upgrades or {}
	for _, def in ipairs(catalog) do
		if not purchased[def.id] or not purchased[def.id].purchased then continue end
		if def.target == "global_revenue" then
			mult *= def.multiplier
		elseif def.target == "business" and def.businessId == businessId then
			mult *= def.multiplier
		end
	end
	return mult
end

-- Multiplier specifically for manual cycle revenue. Adds global_click upgrades
-- on top of the business multiplier; servers/clients call multiplierFor too
-- and combine when paying out a manual cycle.
function Upgrades.clickMultiplier(profile): number
	local mult = 1
	local purchased = profile.upgrades or {}
	for _, def in ipairs(catalog) do
		if def.target == "global_click" and purchased[def.id] and purchased[def.id].purchased then
			mult *= def.multiplier
		end
	end
	return mult
end

-- True iff the upgrade is buyable: not yet purchased AND (no owned requirement
-- OR profile owns enough of the target business). Cost is checked separately
-- so the UI can show "locked" vs "can't afford" distinctly.
function Upgrades.unlocked(profile, def: Definition): boolean
	if profile.upgrades and profile.upgrades[def.id] and profile.upgrades[def.id].purchased then
		return false -- already owned, not "unlocked" for purchase
	end
	if def.requiresOwned <= 0 then return true end
	local b = profile.businesses[def.businessId or ""]
	if not b then return false end
	return (b.owned or 0) >= def.requiresOwned
end

function Upgrades.isPurchased(profile, defId: string): boolean
	local state = profile.upgrades and profile.upgrades[defId]
	return state ~= nil and state.purchased == true
end

return Upgrades
