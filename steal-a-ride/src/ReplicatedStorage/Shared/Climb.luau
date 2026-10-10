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

-- extra leash studs when the guardian's leash first pulls on this target: the lead beyond the normal reach, capped,
-- only for a rider who climbed a wall during this chase (so the walls' shortcut survives the cave exit)
function Climb.keptLead(gap: number, reach: number, climbed: boolean): number
	return climbed and math.clamp(gap - reach, 0, Config.Abilities.Climb.keepLead) or 0
end

-- upward climb speed: scaled from ride speed, with a floor so a slow egg carrier doesn't stall halfway up
function Climb.lift(rideSpeed: number): number
	return math.max(12, rideSpeed * Config.Abilities.Climb.speedMult)
end

return Climb
