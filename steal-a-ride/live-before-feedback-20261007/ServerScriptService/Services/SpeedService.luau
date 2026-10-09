-- Owns every player's WalkSpeed: (best mount speed or walk speed) + saddle,
-- then Dash, water (non-swimmers), boosts and stuns on top.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local DataService = require(script.Parent.DataService)

local SpeedService = {}
SpeedService.mountSpeedOf = function(_player) -- set by MountService
	return nil
end

local stunnedUntil, dashUntil, inWater = {}, {}, {}
local multipliers = {} -- [player] = { [name] = { mult, untilClock } } (Speed Soda, Net Gun)

function SpeedService.base(player): number
	local data = DataService.get(player)
	return (SpeedService.mountSpeedOf(player) or Config.WalkSpeed) + (data and data.SaddleLevel or 0)
end

function SpeedService.current(player): number
	local now = os.clock()
	if (stunnedUntil[player] or 0) > now then
		return 0
	end
	local speed = SpeedService.base(player)
	if (dashUntil[player] or 0) > now then
		speed *= Config.Abilities.Dash.speedMult
	end
	for _, m in multipliers[player] or {} do
		if m[2] > now then
			speed *= m[1]
		end
	end
	if inWater[player] then
		speed *= Config.Abilities.Swim.nonSwimmerMult
	end
	return speed
end

function SpeedService.refresh(player)
	player:SetAttribute("Speed", SpeedService.base(player))
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = SpeedService.current(player)
	end
end

local function timed(store, player, seconds)
	store[player] = os.clock() + seconds
	SpeedService.refresh(player)
	task.delay(seconds + 0.05, function()
		if player.Parent then
			SpeedService.refresh(player)
		end
	end)
end

function SpeedService.stun(player, seconds: number)
	timed(stunnedUntil, player, seconds)
end

function SpeedService.dash(player, seconds: number)
	timed(dashUntil, player, seconds)
end

function SpeedService.multiply(player, name: string, mult: number, seconds: number)
	multipliers[player] = multipliers[player] or {}
	multipliers[player][name] = { mult, os.clock() + seconds }
	SpeedService.refresh(player)
	task.delay(seconds + 0.05, function()
		if player.Parent then
			SpeedService.refresh(player)
		end
	end)
end

function SpeedService.setInWater(player, wet: boolean)
	if (inWater[player] or false) ~= wet then
		inWater[player] = wet or nil
		SpeedService.refresh(player)
	end
end

-- top speed the server allows right now (anti speed-hack check)
function SpeedService.allowed(player): number
	local speed = SpeedService.base(player) * Config.Abilities.Dash.speedMult
	for _, m in multipliers[player] or {} do
		if m[2] > os.clock() and m[1] > 1 then
			speed *= m[1]
		end
	end
	return speed
end

function SpeedService.release(player)
	stunnedUntil[player], dashUntil[player], inWater[player], multipliers[player] = nil, nil, nil, nil
end

return SpeedService

