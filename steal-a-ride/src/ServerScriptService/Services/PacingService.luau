-- Measures real pacing for brand-new players: playtime at their first own deposit from each biome, sent to
-- Roblox Analytics (Creator Hub > Analytics: Onboarding funnel + Custom events). Gameplay never depends on it.
local AnalyticsService = game:GetService("AnalyticsService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local DataService = require(script.Parent.DataService)

local PacingService = {}

-- Call once the save is loaded. Only saves with no playtime yet are tracked, so veterans never skew the numbers.
function PacingService.onPlayerReady(player)
	local data = DataService.get(player)
	if data and not data.Pacing and DataService.playtime(player) < 5 then
		data.Pacing = {} -- [biomeId] = minutes played at the first deposit
		pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, 1, "Joined")
	end
end

-- Call after an egg is put in the player's incubator by walking it home. Secret/Lucky eggs aren't progression.
function PacingService.deposited(player, egg)
	local data = DataService.get(player)
	local biome = Config.BiomeById[egg.biome]
	if not data or not data.Pacing or not biome or egg.secret or egg.lucky or data.Pacing[biome.id] then
		return
	end
	local minutes = math.floor(DataService.playtime(player) / 6 + 0.5) / 10
	data.Pacing[biome.id] = minutes
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, biome.index + 1, "First " .. biome.id .. " egg")
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, "MinutesToFirst" .. biome.id .. "Egg", minutes)
end

return PacingService
