-- Owns every player's WalkSpeed: (best mount speed or walk speed) + saddle,
-- then Dash, water (non-swimmers), boosts and stuns on top, and egg weight + sharp-turn slowdown while carrying.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local DataService = require(script.Parent.DataService)

local SpeedService = {}
SpeedService.mountSpeedOf = function(_player) -- set by MountService
	return nil
end
SpeedService.carryOf = function(_player) -- the carried egg, set by Main (EggService.getCarried)
	return nil
end

local stunnedUntil, dashUntil, inWater = {}, {}, {}
local multipliers = {} -- [player] = { [name] = { mult, untilClock } } (Speed Soda, Net Gun)
local turning = {} -- [carrier] = { mult, x, z, t, root }: sharp-turn slowdown, egg carriers only

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
	local egg = SpeedService.carryOf(player)
	if egg then
		speed *= Config.carryMult(egg) * (turning[player] and turning[player].mult or 1)
	end
	return speed
end

function SpeedService.refresh(player)
	player:SetAttribute("Speed", SpeedService.base(player))
	local current = SpeedService.current(player)
	player:SetAttribute("CurrentSpeed", math.floor(current * 10 + 0.5) / 10) -- what the HUD speed pill shows
	-- HUD boost timer: server time the last active speed-up (Soda, Mama reward) ends, 0 when none
	local now, left = os.clock(), 0
	for _, m in multipliers[player] or {} do
		if m[1] > 1 and m[2] > now then
			left = math.max(left, m[2] - now)
		end
	end
	player:SetAttribute("BoostUntil", left > 0 and workspace:GetServerTimeNow() + left or 0)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = current
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

-- top speed the server allows right now (anti speed-hack check): weighted, straight-line, every permitted boost
function SpeedService.allowed(player): number
	local speed = SpeedService.base(player) * Config.Abilities.Dash.speedMult
	for _, m in multipliers[player] or {} do
		if m[2] > os.clock() and m[1] > 1 then
			speed *= m[1]
		end
	end
	local egg = SpeedService.carryOf(player)
	return egg and speed * Config.carryMult(egg) or speed
end

-- One sample of horizontal travel (velocity vx, vz over dt seconds) against the previous heading (prevX, prevZ).
-- Returns the new turn multiplier and the heading to compare next time (nil when stopped).
function SpeedService.turnStep(mult: number, prevX: number?, prevZ: number?, vx: number, vz: number, dt: number)
	local T = Config.Carry.turn
	local speed = math.sqrt(vx * vx + vz * vz)
	if speed < T.minSpeed then
		return mult, nil, nil -- stopped: keep the penalty, forget the heading
	end
	local x, z = vx / speed, vz / speed
	if not prevX or dt <= 0 or dt > T.maxGap then
		return mult, x, z
	end
	local rate = math.deg(math.acos(math.clamp(prevX * x + prevZ * z, -1, 1))) / dt
	local target = 1 - (1 - T.floor) * math.clamp((rate - T.freeRate) / (T.fullRate - T.freeRate), 0, 1)
	if target < mult then
		return target, x, z
	end
	return math.min(target, mult + T.recover * dt), x, z
end

-- Call whenever a player picks up or loses an egg: weight applies or clears now, turn history starts fresh.
function SpeedService.carryChanged(player)
	turning[player] = SpeedService.carryOf(player) and { mult = 1, t = os.clock() } or nil
	SpeedService.refresh(player)
end

function SpeedService.start()
	task.spawn(function()
		while true do
			task.wait(Config.Carry.turn.sampleEvery)
			local now = os.clock()
			for player, st in turning do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root ~= st.root then
					st.root, st.x, st.z = root, nil, nil -- new character: no stale heading
				end
				if root then
					local v, old = root.AssemblyLinearVelocity, st.mult
					st.mult, st.x, st.z = SpeedService.turnStep(old, st.x, st.z, v.X, v.Z, now - st.t)
					if st.mult ~= old then
						SpeedService.refresh(player)
					end
				end
				st.t = now
			end
		end
	end)
end

function SpeedService.release(player)
	stunnedUntil[player], dashUntil[player], inWater[player], multipliers[player], turning[player] = nil, nil, nil, nil, nil
end

return SpeedService
