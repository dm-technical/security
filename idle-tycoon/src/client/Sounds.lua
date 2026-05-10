--!strict
-- Tiny sound system: named lookups, a small pool per name, and a per-name
-- cooldown so spamming a button doesn't flood the speakers.
--
-- Default IDs are engine-built-in `rbxasset://` URIs that ship with Roblox
-- (no upload required). Swap any entry for a `rbxassetid://NUMBER` to
-- customize without touching call sites.

local SoundService = game:GetService("SoundService")

local Sounds = {}

local POOL_SIZE = 4 -- max simultaneous instances per sound name

type Definition = {
	id: string,
	volume: number,
	cooldown: number, -- seconds between trigger-allowed plays
	pitchRange: { number }?, -- optional [min, max] random pitch
}

local definitions: { [string]: Definition } = {
	tap          = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, cooldown = 0.04, pitchRange = { 0.95, 1.15 } },
	cycle        = { id = "rbxasset://sounds/snap.mp3",                volume = 0.35, cooldown = 0.05 },
	purchase     = { id = "rbxasset://sounds/clickfast.wav",           volume = 0.6,  cooldown = 0.1 },
	purchaseFail = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5,  cooldown = 0.2,  pitchRange = { 0.6, 0.6 } },
	manager      = { id = "rbxasset://sounds/bell.wav",                volume = 0.7,  cooldown = 0.5 },
	milestone    = { id = "rbxasset://sounds/bell.wav",                volume = 1.0,  cooldown = 0.5,  pitchRange = { 1.4, 1.4 } },
	uiClick      = { id = "rbxasset://sounds/button.wav",              volume = 0.4,  cooldown = 0.05 },
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

function Sounds.play(name: string)
	local def = definitions[name]
	if not def then return end

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

	-- Restart from the top — calling Play() while already playing is a no-op
	-- on Sound, so explicitly stop first to support rapid taps.
	s:Stop()
	s:Play()
end

return Sounds
