"""Actual-source checks for the egg carrier speed check: two strikes, excused server moves, logged drops."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / "src" / path).read_text(encoding="utf-8-sig")


def speed_check():
    egg = read("ServerScriptService/Services/EggService.luau")
    loop = egg[egg.index("\t-- anti speed-hack"):egg.index("\t-- every nest restocks")]
    excuse = egg[egg.index("function EggService.excuse"):]
    excuse = excuse[:excuse.index("\nend\n") + 5]
    plot = read("ServerScriptService/Services/PlotService.luau")
    main = read("ServerScriptService/Main.luau")
    mama = read("ServerScriptService/Services/MamaService.luau")
    assert "PlotService.onTeleport(character)" in plot, "server teleports report the character"
    hook = main[main.index("PlotService.onTeleport = function(character)"):]
    assert "EggService.excuse(player, 1)" in hook[:hook.index("\nend\n")], "Main excuses the teleported player"
    stomp = mama[mama.index("local function bigStomp"):]
    assert stomp.index("EggService.excuse(player") < stomp.index('"fling"'), "Mama's stomp excuses its knockback"
    return """
local V={}
V.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end end
V.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__tostring=function(v) return v.X..", "..v.Y..", "..v.Z end
Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},V) end}
local now=0
local os={clock=function() return now end}
local routines={}
local task={spawn=function(fn) local co=coroutine.create(fn);table.insert(routines,co);assert(coroutine.resume(co)) end,
 wait=function(s) return coroutine.yield(s) end}
local warned,toasts={}, {}
local function warn(m) table.insert(warned,m) end
local Notify={FireClient=function(_,_,kind,msg) table.insert(toasts,msg) end}
local carried,lastPos,strikes,excusedUntil={},{},{},{}
local EggService={allowedSpeed=function() return 100 end} -- limit = 100 * 1.4 + 5 = 145 studs/s
local drops=0
function EggService.drop(p) if carried[p] then drops+=1 end carried[p]=nil lastPos[p]=nil strikes[p]=nil end
local root={Position=Vector3.new(0,3,0)}
local player={Name="Runner",Parent=true,Character={FindFirstChild=function() return root end}}
""" + excuse + loop + """
local function step(dz) now+=0.5 root.Position=Vector3.new(0,3,root.Position.Z+dz) assert(coroutine.resume(routines[1])) end
carried[player]={}
step(0)
for _=1,6 do step(60) end -- 120 studs/s: a fast honest ride
assert(drops==0,"honest running never drops")
step(200) -- one 400 studs/s sample: a lag hitch or physics snag
assert(drops==0 and strikes[player]==1,"one fast sample is only a strike")
step(60)
assert(drops==0 and strikes[player]==nil,"a normal sample clears the strike")
step(200) step(200) -- fast twice in a row: a speed hack
assert(drops==1,"two fast samples in a row drop the egg")
assert(#warned==1 and warned[1]:find("Runner dropped an egg: 400 studs/s, limit 145",1,true),warned[1])
assert(toasts[1]=="You dropped the egg: moving too fast!")
carried[player]={}
step(0)
EggService.excuse(player,1) -- the server teleports them (locked-base push-out, climb landing)
step(300) step(300)
assert(drops==1,"a server teleport is never speed")
step(60)
assert(drops==1 and lastPos[player],"the check restarts from where they landed")
step(60) step(60)
assert(drops==1,"normal running after the teleport is fine")
step(250) step(250)
assert(drops==2,"a speed hack right after an excuse is still caught")
carried[player]={}
step(0)
step(60)
step(210) -- one 420 studs/s sample: just under 3x the limit (435), still only a strike
assert(drops==2 and strikes[player]==1)
step(60)
step(230) -- one 460 studs/s sample: past 3x the limit (435), a teleport hack
assert(drops==3,"a single teleport-sized jump drops at once")
print("PASS: speed check needs two fast samples, excuses server teleports and knockback, logs every drop")
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="sam-carry-") as temp:
        script = Path(temp) / "check.luau"
        for harness in (speed_check,):
            script.write_text(harness(), encoding="utf-8")
            subprocess.run([str(args.runtime / "luau.exe"), str(script)], check=True)


if __name__ == "__main__":
    main()
