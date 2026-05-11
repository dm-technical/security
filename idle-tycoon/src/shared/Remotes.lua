--!strict
-- Lazily creates a single Folder of remotes under ReplicatedStorage.
-- Server requires this first; clients then WaitForChild safely.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "IdleTycoonRemotes"

local Remotes = {}

local REMOTE_EVENTS = {
	"BuyBusiness",        -- client -> server: { businessId, quantity (number | "MAX") }
	"HireManager",        -- client -> server: { businessId }
	"ManualCollect",      -- client -> server: { businessId }
	"BuyUpgrade",         -- client -> server: { upgradeId }
	"DoPrestige",         -- client -> server: ()
	"ActivateBoost",      -- client -> server: { boostId }
	"UpdateSettings",     -- client -> server: { sfxVolume?, musicVolume? }
	"ClaimDailyReward",   -- client -> server: ()
	"StateUpdate",        -- server -> client: full or partial state snapshot
	"OfflineEarnings",    -- server -> client: { amount, seconds }
	"Notify",             -- server -> client: { kind, message }
	"AchievementUnlocked",-- server -> client: { ids = { string } }
}

local REMOTE_FUNCTIONS = {
	"GetState", -- client -> server: returns initial state snapshot
}

local function ensureFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		for _, name in ipairs(REMOTE_EVENTS) do
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		for _, name in ipairs(REMOTE_FUNCTIONS) do
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Folder
end

function Remotes.event(name: string): RemoteEvent
	local folder = ensureFolder()
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	local folder = ensureFolder()
	return folder:WaitForChild(name) :: RemoteFunction
end

-- Force-init the folder on require (server only).
if RunService:IsServer() then
	ensureFolder()
end

return Remotes
