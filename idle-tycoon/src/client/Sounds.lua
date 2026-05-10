--!strict
-- Tiny sound system: named lookups, a small pool per name, a per-name
-- cooldown to prevent flooding, and a global volume scalar driven by the
-- settings panel.
--
-- Default IDs are engine-built-in `rbxasset://` URIs that ship with Roblox
-- (no upload required). For premium polish, replace any `id` below with
-- `rbxassetid://YOUR_NUMBER` from a coin-collect / cash-register sound pack.

local SoundService = game:GetService("SoundService")

local Sounds = {}

local POOL_SIZE = 4 -- max simultaneous instances per sound name
local globalVolume = 1.0 -- multiplied into every play() call

type Definition = {
	id: string,
	volume: number,
	cooldown: number, -- seconds between trigger-allowed plays
	pitchRange: { number }?, -- optional [min, max] random pitch
}

-- Cycle uses clickfast for a snappier "coin clink" feel and wider pitch
-- variation so a row of repeating cycles doesn't sound mechanical.
local definitions: { [string]: Definition } = {
	tap          = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, cooldown = 0.04, pitchRange = { 1.4, 1.7 } },
	cycle        = { id = "rbxasset://sounds/clickfast.wav",           volume = 0.6, cooldown = 0.04, pitchRange = { 1.6, 2.4 } },
	purchase     = { id = "rbxasset://sounds/snap.mp3",                volume = 0.7, cooldown = 0.08, pitchRange = { 0.95, 1.1 } },
	purchaseFail = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, cooldown = 0.2,  pitchRange = { 0.55, 0.55 } },
	manager      = { id = "rbxasset://sounds/bell.wav",                volume = 0.7, cooldown = 0.5,  pitchRange = { 1.0, 1.2 } },
	milestone    = { id = "rbxasset://sounds/bell.wav",                volume = 1.0, cooldown = 0.5,  pitchRange = { 1.4, 1.6 } },
	uiClick      = { id = "rbxasset://sounds/button.wav",              volume = 0.4, cooldown = 0.05 },
}

local pools: { [string]: { Sound } } = {}
local lastPlayed: { [string]: number } = {}
local poolIndex: { [string]: number } = {}

local function getPool(name: string): { Sound }?
	local def = definitions[name]
	if not def then return nil end
	local pool = pools[name]
	if pool then return pool end

	pool = {}
	for i = 1, POOL_SIZE do
		local s = Instance.new("Sound")
		s.Name = "Sfx_" .. name .. "_" .. tostring(i)
		s.SoundId = def.id
		s.Volume = def.volume
		s.Parent = SoundService
		pool[i] = s
	end
	pools[name] = pool
	poolIndex[name] = 0
	return pool
end

function Sounds.setVolume(scalar: number)
	globalVolume = math.clamp(scalar, 0, 1)
	-- Re-apply to existing pooled sounds so currently-playing audio fades
	-- to the new level rather than waiting for the next play().
	for name, pool in pairs(pools) do
		local def = definitions[name]
		if def then
			for _, s in ipairs(pool) do
				s.Volume = def.volume * globalVolume
			end
		end
	end
end

function Sounds.play(name: string)
	local def = definitions[name]
	if not def then return end
	if globalVolume <= 0 then return end

	local now = os.clock()
	local last = lastPlayed[name] or 0
	if now - last < def.cooldown then
		return
	end
	lastPlayed[name] = now

	local pool = getPool(name)
	if not pool then return end

	local idx = (poolIndex[name] % POOL_SIZE) + 1
	poolIndex[name] = idx
	local s = pool[idx]

	if def.pitchRange then
		local pitch = def.pitchRange[1] + math.random() * (def.pitchRange[2] - def.pitchRange[1])
		s.PlaybackSpeed = pitch
	else
		s.PlaybackSpeed = 1
	end
	s.Volume = def.volume * globalVolume

	s:Stop()
	s:Play()
end

return Sounds
