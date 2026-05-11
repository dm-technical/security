--!strict
-- Tracks achievement progress, unlocks when thresholds cross, grants gems,
-- and awards Roblox badges via BadgeService.
--
-- Idempotent: calling checkAndUnlock repeatedly is safe — already-unlocked
-- achievements are skipped. BadgeService.AwardBadge itself is idempotent
-- (Roblox dedupes), so even a duplicate call won't cause double-awarding.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)

local AchievementsService = {}

local function totalOwned(profile): number
	local sum = 0
	for _, b in pairs(profile.businesses) do
		sum += (b.owned or 0)
	end
	return sum
end

function AchievementsService.metrics(profile): Achievements.Metrics
	return {
		totalEarned = profile.totalEarned or 0,
		totalOwned = totalOwned(profile),
		totalClicks = profile.totalClicks or 0,
	}
end

-- Returns the list of newly-unlocked achievement ids (empty if none).
function AchievementsService.checkAndUnlock(profile, player: Player?): { string }
	local newlyUnlocked: { string } = {}
	local metrics = AchievementsService.metrics(profile)

	for _, def in ipairs(Achievements.DEFINITIONS) do
		local state = profile.achievements[def.id]
		if not state or not state.unlocked then
			if Achievements.current(def, metrics) >= def.target then
				profile.achievements[def.id] = {
					unlocked = true,
					unlockedAt = os.time(),
				}
				profile.gems += def.gemReward
				table.insert(newlyUnlocked, def.id)

				-- Award the badge async; failure is logged, not fatal.
				if def.badgeId > 0 and player then
					task.spawn(function()
						local ok, err = pcall(function()
							BadgeService:AwardBadge(player.UserId, def.badgeId)
						end)
						if not ok then
							warn(string.format(
								"[Achievements] AwardBadge failed for %s (badge %d): %s",
								def.id, def.badgeId, tostring(err)
							))
						end
					end)
				end
			end
		end
	end

	return newlyUnlocked
end

return AchievementsService
