--!strict
-- Background music with a single configurable track and a runtime volume
-- scalar. Roblox doesn't ship royalty-free music as `rbxasset://`, so the
-- default ID is empty — set MUSIC_ASSET_ID below to your own uploaded asset
-- to enable music. The settings panel mute toggle works either way.
--
-- To pick or upload a track:
--   1. https://create.roblox.com/store/audio (browse free or your own uploads)
--   2. Click a track, copy its asset ID (number after rbxassetid://)
--   3. Replace the empty string below with `rbxassetid://YOUR_ID_HERE`

local SoundService = game:GetService("SoundService")

local Music = {}

-- Replace this to enable music. Empty string = silent.
local MUSIC_ASSET_ID = ""

local sound: Sound? = nil
local baseVolume = 0.6   -- the user's preferred volume (from settings)
local trackVolume = 0.6  -- master cap, tweak per-track for mastering

local function getOrCreate(): Sound
	if sound then return sound end
	local s = Instance.new("Sound")
	s.Name = "BackgroundMusic"
	s.SoundId = MUSIC_ASSET_ID
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	sound = s
	return s
end

function Music.start()
	if MUSIC_ASSET_ID == "" then
		-- No track configured. Silently skip; user can set ID later.
		return
	end
	local s = getOrCreate()
	if not s.IsPlaying then
		s:Play()
	end
end

function Music.setVolume(scalar: number)
	baseVolume = math.clamp(scalar, 0, 1)
	if sound then
		sound.Volume = baseVolume * trackVolume
	end
end

return Music
