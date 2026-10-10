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
assert(Config.Abilities.Climb.speedMult == 0.6 and Config.Abilities.Climb.crackAfter == 1.5, "Config.Abilities.Climb tuning")
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

assert(Climb.lift(10) == 12, "slow carrier still climbs: 12 studs/s floor")
assert(Climb.lift(100) == 60, "climbs at 0.6x ride speed")
print("PASS: climb crack timer, landing spots, climb speed")
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
