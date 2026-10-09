"""Exercise the actual flight service with Roblox boundaries stubbed."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def harness():
    source = (ROOT / 'src/ServerScriptService/Services/FlightService.luau').read_text(encoding='utf-8-sig')
    source = source.replace('local Config = require(RS.Shared.Config)', '')
    source = source.replace('local SpeedService = require(script.Parent.SpeedService)', '')
    return r'''
local now, heartbeat, leaving, grounded, toasts = 1, nil, nil, false, 0
local os = {clock=function() return now end}
local Config = {Flight={maxHeight=48,takeoffSeconds=.6}}
local SpeedService = {current=function() return 25 end}
local Vector3 = {new=function(x,y,z) return {X=x,Y=y,Z=z} end}
local RaycastParams = {new=function() return {} end}
local workspace = {Raycast=function(_,_,direction)
    if direction.Y < -900 or grounded then return {Position={Y=0}} end
end}
local RS = {Remotes={UseAbility={OnServerEvent={Connect=function() end}},
    Notify={FireClient=function() toasts+=1 end}}}
local Players = {PlayerRemoving={Connect=function(_,f) leaving=f end}}
local RunService = {Heartbeat={Connect=function(_,f) heartbeat=f end}}
local game = {GetService=function(_,name)
    return ({Players=Players,RunService=RunService,ReplicatedStorage=RS})[name]
end}
local attrs, mountAttrs = {}, {CanFly=true,RiderRootHeight=5}
local humanoid = {Health=100}
local root = {Position={Y=6}}
local mount = {GetAttribute=function(_,k) return mountAttrs[k] end}
local character = {FindFirstChildOfClass=function() return humanoid end,
    FindFirstChild=function(_,k) return ({Mount=mount,HumanoidRootPart=root})[k] end}
local player = {Parent=true,Character=character,
    GetAttribute=function(_,k) return attrs[k] end,
    SetAttribute=function(_,k,v) attrs[k]=v end}
''' + 'local FlightService=(function()\n' + source + '\nend)()\n' + r'''
FlightService.start()
local function request(action) now+=.2;return FlightService.request(player,action) end
attrs.CarryingEgg='Cosmic'
assert(not request('toggle') and not attrs.Flying, 'egg carriers must not take off')
assert(toasts==1, 'blocked takeoff explains how to fly again')
attrs.CarryingEgg=nil
assert(request('toggle') and attrs.Flying and attrs.FlightCeiling==53, 'empty-handed flight keeps its ceiling')
attrs.CarryingEgg='Forest'
heartbeat()
assert(attrs.Flying and attrs.FlightLanding, 'airborne egg pickup must force a controlled landing')
local count=toasts
for i=1,10 do heartbeat() end
assert(toasts==count, 'forced landing must not spam notifications')
assert(request('toggle') and attrs.FlightLanding, 'toggle cannot cancel forced landing')
assert(not request('landed') and attrs.Flying, 'false landing reports cannot clear flight in mid-air')
grounded=true;now+=1;heartbeat()
assert(attrs.Flying==false and attrs.FlightLanding==false and attrs.FlightCeiling==nil, 'landing clears all flight state')
assert(not request('toggle'), 'still carrying after landing cannot take off')
attrs.CarryingEgg=nil
assert(request('toggle') and attrs.Flying, 'delivery/drop restores takeoff')
humanoid.Health=0;heartbeat()
assert(attrs.Flying==false and attrs.FlightCeiling==nil, 'death clears flight state')
humanoid.Health=100;mountAttrs.CanFly=false
assert(not request('toggle'), 'ground mounts cannot fly')
mountAttrs.CanFly=true
assert(request('toggle'), 'remount after cleanup still works')
leaving(player)
print('PASS: carrier takeoff blocked, airborne pickup forces landing, no spam/cancel/fake landing, delivery/drop recovery and lifecycle')
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='sam-flight-') as temp:
        script = Path(temp) / 'flight.luau'
        script.write_text(harness(), encoding='utf-8')
        subprocess.run([str(args.runtime / 'luau.exe'), str(script)], check=True)


if __name__ == '__main__':
    main()
