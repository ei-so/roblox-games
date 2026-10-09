-- Cartoon walk for single-mesh creatures: one bounce per step, the body rocks to the side of the
-- stepping foot, and leans into the run. phase counts steps (a foot lands at every whole number).
--   WalkCycle.offset(phase, amount 0..1, height in studs, gait) -> CFrame to apply after the model's pivot
--   WalkCycle.gaitOf(speciesId) / WalkCycle.stride(model)
local Config = require(script.Parent.Config)

local WalkCycle = {}

-- bob: fraction of height lifted mid-step; roll / lean / nod in degrees
local GAITS = {
	quad = { bob = 0.06, roll = 5, lean = 4, nod = 2 },
	biped = { bob = 0.08, roll = 10, lean = 6, nod = 2 },
	heavy = { bob = 0.035, roll = 4, lean = 2, nod = 1.5 },
	float = { bob = 0.1, roll = 3, lean = 6, nod = 0 }, -- fliers / floaters: a smooth hover, no footfalls
}

function WalkCycle.offset(phase: number, amount: number, height: number, gait: string?): CFrame
	local g = GAITS[gait or "quad"] or GAITS.quad
	local s = math.sin(math.pi * phase) -- 0 at each footfall, alternating sign per step
	local lift = gait == "float" and (math.sin(math.pi * phase * 0.5) + 1) * 0.5 or math.abs(s)
	local bob = lift * g.bob * height * amount
	local roll = s * g.roll * amount
	local pitch = -(g.lean + g.nod * math.cos(2 * math.pi * phase)) * amount
	return CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
end

-- breathing while standing still (t in seconds)
function WalkCycle.idle(t: number, height: number, seed: number?): CFrame
	local p = t * 1.6 + (seed or 0)
	return CFrame.new(0, (math.sin(p) + 1) * 0.02 * height, 0) * CFrame.Angles(0, 0, math.rad(math.sin(p * 0.5) * 1.5))
end

function WalkCycle.gaitOf(speciesId: string): string
	local spec = Config.Species[speciesId]
	local legs = spec and spec.legs or 4
	return legs == 0 and "float" or (legs == 2 and "biped" or "quad")
end

-- studs per step, from the model's size
function WalkCycle.stride(model: Model): number
	local _, size = model:GetBoundingBox()
	return math.max(2, 0.45 * math.max(size.X, size.Z))
end

return WalkCycle
