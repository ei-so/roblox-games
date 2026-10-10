"""Climb (Crystal Caverns walls): crack timer, landing spots and climb speed in Shared/Climb.luau."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from run_feedback_checks import module
from run_stick_checks import PRELUDE

# translation-only CFrame/Vector3: enough for axis-aligned wall tops
GEOMETRY = r'''
local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, Vector3) end
local CFrame = {}
CFrame.__index = CFrame
function CFrame.new(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, CFrame) end
function CFrame:PointToObjectSpace(p) return Vector3.new(p.X - self.X, p.Y - self.Y, p.Z - self.Z) end
function CFrame:PointToWorldSpace(p) return Vector3.new(p.X + self.X, p.Y + self.Y, p.Z + self.Z) end
'''


def tests():
    config = module('ReplicatedStorage/Shared/Config.luau', {})
    climb = module('ReplicatedStorage/Shared/Climb.luau', {'require(script.Parent.Config)': 'Config'})
    return PRELUDE + GEOMETRY + 'local Config=' + config + '\nlocal Climb=' + climb + r'''
assert(Config.Abilities.Climb.speedMult == 1.5 and Config.Abilities.Climb.crackAfter == 1.5 and Config.Abilities.Climb.keepLead == 20,
	"Config.Abilities.Climb tuning (user-approved 2026-10-11: climb 1.5x ride speed, keep up to 20 studs of lead)")
local function expect(label, wantAction, wantSince, action, since)
	assert(action == wantAction and since == wantSince,
		label .. ": want " .. wantAction .. ", " .. tostring(wantSince) .. " got " .. tostring(action) .. ", " .. tostring(since))
end
local A = 1.5
expect("stepping onto the top starts the timer", "start", 10, Climb.step(nil, 10, true, true, A))
expect("still on the top waits", "wait", 10, Climb.step(10, 11, true, true, A))
expect("cracks at crackAfter", "crack", nil, Climb.step(10, 11.5, true, true, A))
expect("leaving the top resets the timer", "none", nil, Climb.step(10, 11, false, true, A))
expect("off the top with no timer", "none", nil, Climb.step(nil, 11, false, true, A))
expect("no Climb on the top slips at once", "slip", nil, Climb.step(nil, 5, true, false, A))

-- wall top at z = 0, depth 8 (faces at z = -4 / +4), 1 stud tall, sitting on a 40-stud wall
local top, size = CFrame.new(5, 40.5, 0), Vector3.new(60, 1, 8)
local function at(z) return Vector3.new(12, 41, z) end
local crack = Climb.landing(top, size, at(0), "crack")
assert(crack.Z == 10 and crack.X == 12, "centre line lands outside the wall: crack goes 6 past the +Z (exit) face, same X")
assert(Climb.landing(top, size, at(-3), "crack").Z == 10, "crack always lands on the exit side")
assert(Climb.landing(top, size, at(0), "slip").Z == -10, "centre line lands outside the wall: slip goes to the -Z (nest) side")
assert(Climb.landing(top, size, at(3), "slip").Z == 10, "slip goes off the face nearer the rider")
assert(Climb.landing(top, size, at(-3), "slip").Z == -10, "slip from the nest half goes to the nest side")
assert(crack.Y == 40 + 3, "without a ground height, lands 3 above the top's base")
assert(Climb.landing(top, size, at(0), "crack", 0).Y == 3, "with a ground height, lands 3 above the ground")

assert(Climb.lift(5) == 12, "slow carrier still climbs: 12 studs/s floor")
assert(Climb.lift(100) == 150, "climbs at 1.5x ride speed")

-- cresting the top: a fast climber keeps only the upward speed that lifts its feet `rise` studs (no launch over the walls)
local g = 196.2
local crest = Climb.crestSpeed(177, 6, g)
assert(math.abs(crest - math.sqrt(2 * g * 6)) < 1e-6, "fast climber: just enough to clear the edge, got " .. crest)
assert(crest * crest / (2 * g) <= 8, "apex stays inside the ClimbTop headroom (8 studs)")
assert(Climb.crestSpeed(12, 6, g) == 12, "a slow climber is never sped up")
assert(Climb.crestSpeed(-5, 6, g) == -5, "already falling: unchanged")

-- hitting the wall at full speed bounces you back off the face; while climbing, the part of your speed that points
-- away from the wall is dropped so you stay on it (sideways and up/down speed untouched)
Vector3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__mul = function(a, k) return Vector3.new(a.X * k, a.Y * k, a.Z * k) end
function Vector3:Dot(o) return self.X * o.X + self.Y * o.Y + self.Z * o.Z end
local n = Vector3.new(0, 0, -1) -- the nest face points toward the nest (-Z)
local v1 = Climb.pressed(Vector3.new(5, 199, -61), n)
assert(v1.X == 5 and v1.Y == 199 and v1.Z == 0, "bounce away from the face is dropped, sideways and climb speed kept")
local v2 = Climb.pressed(Vector3.new(0, 50, 30), n)
assert(v2.Z == 30, "speed into the wall is left alone")

-- a walking guardian can't reach a rider on (or climbing) a wall: it heads for the exit-side landing spot instead,
-- which is on the ground, so it routes through a gap rather than walking at the wall
local g1 = Climb.chaseGoal(top, size, Vector3.new(12, 44, 1), 0)
assert(g1 and g1.Z == 10 and g1.X == 12 and g1.Y == 3, "rider on the top: guardian goes to the exit-side landing")
assert(Climb.chaseGoal(top, size, Vector3.new(12, 20, -7), 0), "rider climbing the nest face (just outside the footprint): same")
assert(Climb.chaseGoal(top, size, Vector3.new(12, 3, -7), 0) == nil, "rider on the ground beside the wall: chase them normally")
assert(Climb.chaseGoal(top, size, Vector3.new(12, 30, -30), 0) == nil, "rider far from this wall: not this wall's business")
assert(Climb.chaseGoal(top, size, Vector3.new(50, 30, 0), 0) == nil, "rider past the wall's end (the gap side): chase normally")

-- leaving the cave, the Golem's leash snaps it to reach behind; a rider who climbed a wall this chase keeps the lead
assert(Climb.keptLead(70, 41, true) == 20, "kept lead is capped at keepLead")
assert(Climb.keptLead(51, 41, true) == 10, "keeps the studs beyond the normal leash reach")
assert(Climb.keptLead(30, 41, true) == 0, "no lead (Golem closer than reach) keeps nothing")
assert(Climb.keptLead(70, 41, false) == 0, "no climb this chase, no kept lead")
print("PASS: climb crack timer, landing spots, climb speed, kept lead")
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='sam-climb-') as temp:
        script = Path(temp) / 'climb.luau'
        script.write_text(tests(), encoding='utf-8')
        subprocess.run([str(args.runtime / 'luau.exe'), str(script)], check=True)


if __name__ == '__main__':
    main()
