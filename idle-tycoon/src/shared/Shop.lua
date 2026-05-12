--!strict
-- Shop catalog: consumable items the player buys with science to bypass
-- friction in the moment-to-moment gameplay.
--
-- Effect types this module supports:
--   "reroll_contract" — replace the contract in `contractSlot` with a fresh roll
--   "reset_boost"     — clear the cooldown on the boost in `boostId`
--
-- Both pure consumables (no per-item persistent state) — the player can
-- buy them as many times as their science allows.

local Shop = {}

export type Definition = {
	id: string,
	name: string,
	description: string,
	icon: string,
	scienceCost: number,
	effect: string,
	-- Set when effect == "reroll_contract".
	contractSlot: number?,
	-- Set when effect == "reset_boost".
	boostId: string?,
	-- UI section grouping.
	category: string, -- "contracts" | "boosts"
}

Shop.ITEMS = {
	-- Contract rerolls. One per slot so the UI can map purchases directly
	-- to the contract bar without an extra "which slot" dialog.
	{
		id = "reroll_contract_1",
		name = "Reroll Contract 1",
		description = "Discard the first contract and roll a new one",
		icon = "🎲",
		scienceCost = 50,
		effect = "reroll_contract",
		contractSlot = 1,
		category = "contracts",
	},
	{
		id = "reroll_contract_2",
		name = "Reroll Contract 2",
		description = "Discard the second contract and roll a new one",
		icon = "🎲",
		scienceCost = 50,
		effect = "reroll_contract",
		contractSlot = 2,
		category = "contracts",
	},
	{
		id = "reroll_contract_3",
		name = "Reroll Contract 3",
		description = "Discard the third contract and roll a new one",
		icon = "🎲",
		scienceCost = 50,
		effect = "reroll_contract",
		contractSlot = 3,
		category = "contracts",
	},

	-- Boost cooldown resets. Pricing scales with how long the underlying
	-- cooldown actually is (15 / 4:30 / 10:00 active durations).
	{
		id = "reset_boost_click",
		name = "Reset Rapid Launch",
		description = "Clear the cooldown on Click Power",
		icon = "🚀",
		scienceCost = 200,
		effect = "reset_boost",
		boostId = "click",
		category = "boosts",
	},
	{
		id = "reset_boost_income",
		name = "Reset Gov't Stimulus",
		description = "Clear the cooldown on Income Boost",
		icon = "🏛️",
		scienceCost = 2_000,
		effect = "reset_boost",
		boostId = "income",
		category = "boosts",
	},
	{
		id = "reset_boost_offline",
		name = "Reset Autonomous Ops",
		description = "Clear the cooldown on Offline Earnings",
		icon = "🤖",
		scienceCost = 20_000,
		effect = "reset_boost",
		boostId = "offline",
		category = "boosts",
	},
} :: { Definition }

Shop.BY_ID = {}
for _, def in ipairs(Shop.ITEMS) do
	Shop.BY_ID[def.id] = def
end

return Shop
