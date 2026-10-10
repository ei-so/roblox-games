-- Climb (Crystal Caverns quartz walls): pure rules shared by the server's wall-top timer and the client's climbing.
-- Walls run across the route; +Z is the exit side (toward home), -Z the nest side.
local Config = require(script.Parent.Config)

local Climb = {}

-- one server tick on a wall top. since = when the crack timer started (nil = not running).
-- returns the action ("none" | "start" | "wait" | "crack" | "slip") and the new since
function Climb.step(since: number?, now: number, onTop: boolean, hasClimb: boolean, crackAfter: number): (string, number?)
	if not onTop then
		return "none", nil
	elseif not hasClimb then
		return "slip", nil
	elseif not since then
		return "start", now
	elseif now - since >= crackAfter then
		return "crack", nil
	end
	return "wait", since
end

-- where a pushed-off rider lands: 6 studs past a face of the wall top (crack: the exit face; slip: the face nearer
-- the rider, the centre line counting as the nest side), same X, 3 studs above groundY (or the top's base)
function Climb.landing(top: CFrame, size: Vector3, pos: Vector3, action: string, groundY: number?): Vector3
	local p = top:PointToObjectSpace(pos)
	local exit = action == "crack" or p.Z > 0
	local z = (size.Z / 2 + 6) * (exit and 1 or -1)
	local spot = top:PointToWorldSpace(Vector3.new(p.X, -size.Y / 2, z))
	return Vector3.new(spot.X, (groundY or spot.Y) + 3, spot.Z)
end

-- while climbing: drop the part of the rider's velocity that points away from the wall (normal = the face's
-- outward normal), so hitting the wall at full speed doesn't bounce you off it mid-climb
function Climb.pressed(v: Vector3, normal: Vector3): Vector3
	local away = v:Dot(normal)
	return away > 0 and v - normal * away or v
end

-- a walking guardian chasing a rider who is on this wall's top or climbing one of its faces (within 6 studs, off the
-- ground) can't reach them: it heads for the exit-side landing spot instead (on the ground, so it routes through a
-- gap). nil = not on this wall: chase the rider as usual
function Climb.chaseGoal(top: CFrame, size: Vector3, pos: Vector3, groundY: number?): Vector3?
	local p = top:PointToObjectSpace(pos)
	if math.abs(p.X) > size.X / 2 or math.abs(p.Z) > size.Z / 2 + 6 or pos.Y < (groundY or 0) + 6 then
		return nil
	end
	return Climb.landing(top, size, pos, "crack", groundY)
end

-- extra leash studs when the guardian's leash first pulls on this target: the lead beyond the normal reach, capped,
-- only for a rider who climbed a wall during this chase (so the walls' shortcut survives the cave exit)
function Climb.keptLead(gap: number, reach: number, climbed: boolean): number
	return climbed and math.clamp(gap - reach, 0, Config.Abilities.Climb.keepLead) or 0
end

-- upward climb speed: scaled from ride speed, with a floor so a slow egg carrier doesn't stall halfway up
function Climb.lift(rideSpeed: number): number
	return math.max(12, rideSpeed * Config.Abilities.Climb.speedMult)
end

-- upward speed kept when the climb ends at the top: only what lifts the rider `rise` studs over the edge, so a fast
-- climber (lift ~180 studs/s) lands on the wall top instead of being launched over the next walls; never speeds up
function Climb.crestSpeed(vy: number, rise: number, gravity: number): number
	return math.min(vy, math.sqrt(2 * gravity * rise))
end

return Climb
