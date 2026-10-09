"""Nest egg count scales down with the server's player count (never above the full nest)."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from run_feedback_checks import module
from run_stick_checks import PRELUDE

ROOT = Path(__file__).resolve().parents[1] / 'src'


def counts():
    return PRELUDE + 'local Config=' + module('ReplicatedStorage/Shared/Config.luau', {}) + r'''
local want = {[0]={4,3}, {4,3}, {5,4}, {6,5}, {6,5}, {8,6}, {8,6}, {8,6}, {8,6}, {8,6}}
for players, w in want do
	assert(Config.nestEggs('Forest', players) == w[1], 'Forest eggs with ' .. players .. ' players')
	assert(Config.nestEggs('Lake', players) == w[2], 'Lake eggs with ' .. players .. ' players')
	assert(Config.nestEggs('MysticGrove', players) == w[2], 'Mystic eggs with ' .. players .. ' players')
end
print('PASS: nest egg counts by player count (1: 4/3, 2: 5/4, 3-4: 6/5, 5+: 8/6)')
'''


def refill():
    source = (ROOT / 'ServerScriptService/Services/EggService.luau').read_text(encoding='utf-8-sig')
    body = source[source.index('local function refill'):source.index('function EggService.registerNest')]
    return r'''
local Config = {nestEggs=function(b, n) return ({[1]=3, [2]=4, [3]=5, [4]=5})[n] or 6 end}
local playerCount = 1
local Players = {GetPlayers=function() local t = {} for i = 1, playerCount do t[i] = i end return t end}
local capacity
local workspace = {Biomes={Lake={Nest={SetAttribute=function(_, k, v) if k == 'EggCapacity' then capacity = v end end}}}}
local spots = {'S1','S2','S3','S4','S5','S6'}
local nests = {Lake={}}
for _, s in spots do nests.Lake[s] = false end
local spotOrder = {Lake=spots}
local function spawnNestEgg(b, spot) nests[b][spot] = 'egg' end
local function stock() local n = 0 for _, m in nests.Lake do if m then n += 1 end end return n end
''' + body + r'''
refill('Lake')
assert(stock() == 3 and capacity == 3, 'solo: 3 eggs')
assert(nests.Lake.S1 and nests.Lake.S2 and nests.Lake.S3 and not nests.Lake.S4, 'fills spots in order')
nests.Lake.S2 = false -- one stolen
playerCount = 3
refill('Lake')
assert(stock() == 5 and capacity == 5, 'join tops up to the new count, refilling the gap first')
assert(nests.Lake.S2, 'empty earlier spot filled')
playerCount = 1
refill('Lake')
assert(stock() == 5 and capacity == 3, 'leave never removes eggs')
for _, s in spots do nests.Lake[s] = false end -- the 5-minute refill clears the nest first
refill('Lake')
assert(stock() == 3, 'next refill uses the lower count')
playerCount = 8
refill('Lake')
assert(stock() == 6 and capacity == 6, 'never more than the nest spots')
print('PASS: refill fills to the player-count target, joins top up, leaves wait for the refill')
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='sam-nest-') as temp:
        for name, build in (('counts', counts), ('refill', refill)):
            script = Path(temp) / f'{name}.luau'
            script.write_text(build(), encoding='utf-8')
            subprocess.run([str(args.runtime / 'luau.exe'), str(script)], check=True)


if __name__ == '__main__':
    main()
