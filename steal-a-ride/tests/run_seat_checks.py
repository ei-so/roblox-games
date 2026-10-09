"""Exercise the real spawn/teleport path and check seat release precedes movement."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from run_feedback_checks import module


def harness():
    source = module('ServerScriptService/Services/PlotService.luau', {
        'local Config = require(game:GetService("ReplicatedStorage").Shared.Config)': 'local Config = {}',
    })
    return r'''
local spawnFrame=setmetatable({}, {__add=function() return 'spawnTarget' end})
local plot={Spawn={CFrame=spawnFrame}}
local plots={FindFirstChild=function() return plot end}
local workspace={WaitForChild=function() return {WaitForChild=function() return plots end} end}
local Vector3={new=function() return {} end}
local Enum={HumanoidStateType={GettingUp='GettingUp'}}
local task={defer=function(fn) fn() end,wait=function() end}
local player={GetAttribute=function() return 'Plot1' end}
local moved, states, destroyed = 0, 0, 0
local humanoid={Sit=true}
local character
local part={IsDescendantOf=function(_,model) return model==character end}
local weld={Part1=part,Destroy=function() destroyed+=1 end}
local seat={FindFirstChild=function() return weld end}
humanoid.SeatPart=seat
function humanoid:ChangeState(state) states+=1;assert(state=='GettingUp') end
character={FindFirstChildOfClass=function() return humanoid end,WaitForChild=function() return {} end,
    PivotTo=function(_,target)
        assert(destroyed==1 and not humanoid.Sit,'seated spawn must detach the external SeatWeld and stand up before teleport')
        moved+=1
    end}
''' + 'local PlotService=' + source + r'''
PlotService.spawn(player,character)
assert(moved==1 and states==1,'spawn uses the seat-safe movement path')
humanoid.SeatPart=nil;humanoid.Sit=false
PlotService.teleport(character,'exit')
assert(moved==2 and states==1,'standing teleports do not change the humanoid state')
humanoid.SeatPart=seat;humanoid.Sit=true
part.IsDescendantOf=function() return false end
PlotService.teleport(character,'exit')
assert(destroyed==1,'a stale SeatPart must not delete a different occupants weld')
humanoid.SeatPart=nil;humanoid.Sit=true
PlotService.teleport(character,'exit')
assert(not humanoid.Sit,'seated state is cleared even when SeatPart has already disappeared')
print('PASS: seated spawn/teleport breaks only its SeatWeld before movement; standing and stale-seat cleanup')
'''


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--runtime',type=Path,required=True)
    args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='sam-seat-') as temp:
        script=Path(temp)/'seat.luau'
        script.write_text(harness(),encoding='utf-8')
        subprocess.run([str(args.runtime/'luau.exe'),str(script)],check=True)


if __name__=='__main__':
    main()
