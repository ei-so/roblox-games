-- Shared cartoon gaits and joint animation for mounts, pen pets and guardians.
local Config = require(script.Parent.Config)
local WalkCycle = {}
local GAITS = {
	quad = { bob = .025, roll = 2, lean = 4, nod = 2 },
	biped = { bob = .04, roll = 4, lean = 5, nod = 2 },
	heavy = { bob = .02, roll = 2, lean = 2, nod = 1 },
	hop = { bob = .12, roll = 0, lean = 2, nod = 9 },
	waddle = { bob = .025, roll = 8, lean = 2, nod = 1 },
	float = { bob = .08, roll = 2, lean = 0, nod = 0 },
	fly = { bob = .025, roll = 2, lean = 6, nod = 0 },
}

function WalkCycle.offset(phase: number, amount: number, height: number, gait: string?): CFrame
	local g = GAITS[gait or "quad"] or GAITS.quad
	local s = math.sin(math.pi * phase)
	local floating = gait == "float" or gait == "fly"
	local lift = floating and (math.sin(math.pi * phase * .5) + 1) * .5 or math.abs(s)
	return CFrame.new(0, lift * g.bob * height * amount, 0)
		* CFrame.Angles(math.rad(-(g.lean + g.nod * math.cos(2 * math.pi * phase)) * amount), 0, math.rad(s * g.roll * amount))
end

function WalkCycle.idle(t: number, height: number, seed: number?): CFrame
	local p = t * 1.6 + (seed or 0)
	return CFrame.new(0, (math.sin(p) + 1) * .012 * height, 0) * CFrame.Angles(0, 0, math.rad(math.sin(p * .5)))
end

function WalkCycle.gaitOf(speciesId: string): string
	local spec = Config.Species[speciesId]
	local legs = spec and spec.legs or 4
	return spec and spec.locomotion or (legs == 0 and "float" or legs == 2 and "biped" or "quad")
end

function WalkCycle.stride(model: Model): number
	local _, size = model:GetBoundingBox()
	return math.max(1.5, .45 * math.max(size.X, size.Z))
end

-- Cosmetic Pen movement only: each pet walks one smooth closed loop (a slightly wobbly ellipse) around its pad,
-- always facing along the path and turning gradually, and now and then pauses on the loop before carrying on.
-- The loop stays inside `radius` (largest point = 0.78 * 1.12 of it).
local SPEED, TURN = 1.25, 2.4 -- studs/s along the loop, max rad/s of turning

local function loopPoint(state, t: number)
	local wobble = 1 + .12 * math.sin(2 * t + state.wobble)
	return math.cos(t) * state.rx * wobble, math.sin(t) * state.rz * wobble
end

function WalkCycle.newPenRoam(seed: number, radius: number)
	local rng = Random.new(seed)
	local state = { phase = 0, amount = 0, radius = radius, rng = rng,
		t = rng:NextNumber(0, 2 * math.pi), dir = rng:NextNumber(0, 1) < .5 and -1 or 1, wobble = rng:NextNumber(0, 2 * math.pi),
		rx = radius * rng:NextNumber(.6, .78), rz = radius * rng:NextNumber(.45, .78),
		rest = rng:NextNumber(.4, 2), walk = 0 }
	state.x, state.z = loopPoint(state, state.t)
	local ax, az = loopPoint(state, state.t + .01 * state.dir)
	state.yaw = math.atan2(-(ax - state.x), -(az - state.z)) -- models face local -Z: start facing along the loop
	return state
end

function WalkCycle.stepPenRoam(state, dt: number, stride: number)
	dt = math.clamp(dt, 0, .1) -- no catch-up jump after a stalled frame
	local moving = false
	if state.rest > 0 then
		state.rest = math.max(0, state.rest - dt)
		if state.rest == 0 then
			state.walk = state.rng:NextNumber(3, 7)
		end
	elseif dt > 0 then
		-- advance the loop parameter so the pet covers about SPEED * dt studs (halved until the chord fits)
		local ax, az = loopPoint(state, state.t + 1e-3 * state.dir)
		local perT = math.max(1e-6, math.sqrt((ax - state.x) ^ 2 + (az - state.z) ^ 2) / 1e-3)
		local dT, nx, nz = SPEED * dt / perT, 0, 0
		repeat
			nx, nz = loopPoint(state, state.t + dT * state.dir)
			local fits = math.sqrt((nx - state.x) ^ 2 + (nz - state.z) ^ 2) <= SPEED * dt
			if not fits then
				dT /= 2
			end
		until fits
		local dx, dz = nx - state.x, nz - state.z
		local step = math.sqrt(dx * dx + dz * dz)
		state.t += dT * state.dir
		state.x, state.z = nx, nz
		if step > 0 then
			local heading = math.atan2(-dx, -dz)
			local turn = math.atan2(math.sin(heading - state.yaw), math.cos(heading - state.yaw))
			state.yaw += math.clamp(turn, -TURN * dt, TURN * dt)
		end
		state.phase += step / math.max(1.5, stride)
		moving = step > 0
		state.walk -= dt
		if state.walk <= 0 then
			state.rest = state.rng:NextNumber(.8, 2.4)
		end
	end
	state.amount = math.clamp(state.amount + (moving and dt or -dt) * 5, 0, 1)
end

function WalkCycle.bind(model: Model)
	local joints = {}
	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") and joint:GetAttribute("Side") then
			table.insert(joints, { motor = joint, base = joint.C0, side = joint:GetAttribute("Side"),
				front = joint:GetAttribute("Front") or 0, kind = joint:GetAttribute("MotionKind") or "Leg" })
		end
	end
	return joints
end

function WalkCycle.animateJoints(joints, phase: number, amount: number, now: number, gait: string, airborne: boolean)
	local step = math.sin(math.pi * phase)
	for _, j in joints do
		local pose = CFrame.identity
		if j.kind == "Wing" then
			local flap = airborne and (35 + math.sin(now * 8) * 30) or math.sin(now * 1.8) * 2
			pose = CFrame.Angles(0, 0, math.rad(flap * j.side))
		elseif j.kind == "Tentacle" then
			pose = CFrame.Angles(math.sin(now * 2 + j.side + j.front) * .12, 0, math.cos(now * 1.5 + j.side) * .08)
		elseif airborne then
			pose = CFrame.Angles(math.rad(-25), 0, 0)
		else
			local direction = j.side * (j.front > 0 and -1 or 1)
			if gait == "hop" then direction = 1 end
			local angle = gait == "heavy" and 10 or gait == "waddle" and 14 or 16 -- small swings keep the cut faces hidden
			pose = CFrame.Angles(math.rad(angle) * step * amount * direction, 0, 0)
		end
		j.motor.C0 = j.base * pose
	end
end

function WalkCycle.flightVelocity(direction: Vector3, speed: number, vertical: number): Vector3
	if speed <= 0 then return Vector3.zero end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude > 1 then flat = flat.Unit end
	return flat * speed + Vector3.new(0, math.clamp(vertical, -1, 1) * Config.Flight.verticalSpeed, 0)
end

return WalkCycle
