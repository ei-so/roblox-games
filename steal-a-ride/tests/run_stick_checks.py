"""Base stun stick: tier pricing/gating and StealService.swing hit rules."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from run_feedback_checks import module

ROOT = Path(__file__).resolve().parents[1] / 'src'

PRELUDE = r'''
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end,new=function(r,g,b) return {R=r,G=g,B=b} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local ColorSequence={new=function() return {} end}
local NumberSequence={new=function() return {} end}
local Vector3={new=function() return {} end}
local Vector2={new=function() return {} end}
local NumberRange={new=function() return {} end}
local CFrame={new=function() return {} end}
local Instance={new=function() return setmetatable({},{__index=function() return function() end end}) end}
'''


def pricing():
    config = module('ReplicatedStorage/Shared/Config.luau', {})
    base = (ROOT / 'ServerScriptService/Services/BaseService.luau').read_text(encoding='utf-8-sig')
    price = base[base.index('function BaseService.price'):base.index('function BaseService.equipped')]
    return PRELUDE + 'local Config=' + config + '\nlocal Base=Config.Base\nlocal BaseService={}\n' + price + r'''
local ids={}
for _,item in Config.Base.items do if item.slot=='stick' then table.insert(ids,item.id) end end
assert(table.concat(ids,',')=='stickWood,stickIron,stickGold,stickCrystal,stickGlitch','five stick tiers in order')
local slotOk=false
for _,s in Config.Base.slots do if s.id=='stick' then slotOk=true end end
assert(slotOk,'stick slot in Base panel')
assert(Config.Stick.range==7 and Config.Stick.stun==2 and Config.Stick.cooldown==0.8,'stick tuning')
local I=Config.Base.itemById
assert(Config.basePrice(I.stickIron,10)==6000,'10 min of $10/s')
assert(Config.basePrice(I.stickGlitch,10)==72000,'120 min of $10/s')
assert(Config.basePrice(I.stickIron,0)==Config.Gear.minPrice,'price floor')
assert(Config.basePrice(I.colorOcean,999)==2500,'fixed-price items unchanged')
local data={Base={owned={},equipped={}}}
assert(BaseService.price(data,'stickWood',10)==0,'wood free')
assert(BaseService.price(data,'stickIron',10)==6000,'iron needs nothing')
assert(BaseService.price(data,'stickGold',10)==nil,'gold locked without iron')
data.Base.owned.stickIron=true
assert(BaseService.price(data,'stickIron',10)==0,'owned = equip only')
assert(BaseService.price(data,'stickGold',10)==18000,'gold unlocked by iron')
assert(BaseService.price(data,'colorOcean')==2500,'old callers without income still work')
print('PASS: stick tiers, income pricing, floor, requires gate')
'''


def swing():
    steal = module('ServerScriptService/Services/StealService.luau', {
        'local Players = game:GetService("Players")': '',
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")': '',
        'local Debris = game:GetService("Debris")': '',
        'local SoundService = game:GetService("SoundService")': '',
        'local Config = require(ReplicatedStorage.Shared.Config)': '',
        'local DataService = require(script.Parent.DataService)': '',
        'local PlotService = require(script.Parent.PlotService)': '',
        'local EggService = require(script.Parent.EggService)': '',
        'local HatchService = require(script.Parent.HatchService)': '',
        'local GuardianService = require(script.Parent.GuardianService)': '',
        'local SpeedService = require(script.Parent.SpeedService)': '',
        'local BaseService = require(script.Parent.BaseService)': '',
        'local Notify = ReplicatedStorage.Remotes.Notify': '',
    })
    return PRELUDE + r'''
local now=100
local os={clock=function() return now end,time=function() return 0 end}
local vmt={}
local function vec(x,z) return setmetatable({X=x,Y=0,Z=z,Magnitude=math.sqrt(x*x+z*z)},vmt) end
vmt.__sub=function(a,b) return vec(a.X-b.X,a.Z-b.Z) end
local function mk(name,x,z)
    local root={Position=vec(x,z)}
    local hum={Health=100}
    local p={DisplayName=name,UserId=#name}
    p.Character={FindFirstChild=function(_,n) if n=='HumanoidRootPart' then return root end end,FindFirstChildOfClass=function() return hum end}
    p.root=root
    return p
end
local owner,thief,other=mk('Owner',0,0),mk('Thief',5,0),mk('Other',100,0)
local Players={GetPlayers=function() return {owner,thief,other} end,PlayerRemoving={Connect=function() end}}
local Debris={AddItem=function() end}
local whooshes=0
local bonks=0
local SoundService={SFX={FindFirstChild=function(_,n)
    if n=='StickSwing' then return {Clone=function() whooshes+=1 return {Play=function() end} end} end
    if n=='StickHit' then return {Clone=function() bonks+=1 return {Play=function() end} end} end
end}}
local workspace={GetAttribute=function() return nil end}
local Config={Steal={robCooldown=60,catchGrace=3,shieldSeconds=0,carrierRange=8},Plot={lockSeconds=60,lockPerRebirth=0},
    Stick={range=7,stun=2,cooldown=0.8},Base={itemById={stickWood={color={},burst=10}}}}
local DataService={get=function() return {Rebirths=0} end,playtime=function() return 99999 end}
local plot={Floor={Position=vec(0,0),Size={X=40,Z=40}}}
local PlotService={get=function(p) if p==owner then return plot end end}
local carriers={}
local EggService={carriers=function() return carriers end,isCarrying=function(p) return carriers[p]~=nil end,
    take=function(p) local e=carriers[p];carriers[p]=nil;return e end,attach=function(p,e) carriers[p]=e;return true end}
local given={}
local HatchService={give=function(p,e) table.insert(given,{p,e}) end}
local GuardianService={caughtAt={}}
local stunned={}
local SpeedService={stun=function(p,s) stunned[p]=s end}
local BaseService={equipped=function() return 'stickWood' end}
local toasts={}
local Notify={FireClient=function(_,p,_,msg) table.insert(toasts,{p,msg}) end}
local StealService=''' + steal + r'''

-- thief steals owner's carried egg: robCooldown starts
local egg={biome='Forest'}
carriers[owner]=egg
StealService.stealFromCarrier(thief,owner)
assert(carriers[thief]==egg and egg.stolenFrom==owner,'fixture: thief carries owner egg')
assert(not StealService.canSteal(other,owner),'fixture: robCooldown active')

-- owner outside own plot: no hit
owner.root.Position=vec(30,0);thief.root.Position=vec(33,0)
assert(StealService.swing(owner)==nil and carriers[thief]==egg,'no hit outside your base')

-- thief out of range
now+=1;owner.root.Position=vec(0,0);thief.root.Position=vec(10,0)
assert(StealService.swing(owner)==nil and carriers[thief]==egg,'no hit beyond 7 studs')

-- bystander carrying someone else's stolen egg
now+=1;local other_egg={biome='Lake',stolenFrom=other};carriers[other]=other_egg;other.root.Position=vec(2,0);thief.root.Position=vec(30,0)
assert(StealService.swing(owner)==nil and carriers[other]==other_egg,'whiff on bystander')
carriers[other]=nil;other.root.Position=vec(100,0)

-- thief just outside the plot edge (owner inside) but in range: hit
now+=1;owner.root.Position=vec(17,0);thief.root.Position=vec(22,0)
assert(StealService.swing(owner)==thief,'hit thief in range even past the plot edge')
assert(carriers[thief]==nil and given[1][1]==owner and given[1][2]==egg,'egg back to owner incubator')
assert(stunned[thief]==2,'thief stunned 2s')
assert(bonks==1,'a hit bonks once; the earlier whiffs/refusals stayed silent')
assert(StealService.canSteal(thief,owner),'robCooldown cleared after a stick hit')

-- cooldown: re-steal then swing twice within 0.8 s
carriers[thief]=egg
now+=0.5
assert(StealService.swing(owner)==nil and carriers[thief]==egg,'swing cooldown 0.8s')
now+=0.4
assert(StealService.swing(owner)==thief and #given==2,'swing works after cooldown, one give per hit')
-- chained steal: thief steals the owner's egg, other steals it from thief -> owner can still whack other
now+=1
local chainEgg={biome='Jungle'}
carriers[owner]=chainEgg;owner.root.Position=vec(0,0);thief.root.Position=vec(5,0);other.root.Position=vec(100,0)
GuardianService.caughtAt={}
StealService.stealFromCarrier(thief,owner)
assert(carriers[thief]==chainEgg,'fixture: thief has owner egg')
other.root.Position=vec(8,0)
StealService.stealFromCarrier(other,thief)
assert(carriers[other]==chainEgg and chainEgg.stolenFrom==thief,'fixture: other stole it from thief')
other.root.Position=vec(3,0);thief.root.Position=vec(30,0)
assert(StealService.swing(owner)==other and carriers[other]==nil,'owner whacks the second thief in a chain')
-- clicks: only accepted swings create the slash anim, and it is cleaned up
local made, cleaned = 0, 0
Instance={new=function(cls) if cls=='StringValue' then made+=1 end return {} end}
Debris.AddItem=function() cleaned+=1 end
now+=1
for _=1,10 do StealService.activate(owner,{Handle={}}) end
assert(made==1 and cleaned==2 and whooshes==1,'click spam within cooldown makes one anim + one whoosh, both cleaned up')
now+=1;StealService.activate(owner,{Handle={}})
assert(made==2 and cleaned==4 and whooshes==2,'next accepted swing animates and whooshes again')
print('PASS: stick swing rules (hit bonk, chained steal, click spam anim/whoosh cleanup, base-only, range, bystander whiff, edge, egg home, stun, cooldown clear, swing cooldown)')
'''



def drop():
    egg = (ROOT / 'ServerScriptService/Services/EggService.luau').read_text(encoding='utf-8-sig')
    body = egg[egg.index('function EggService.take'):egg.index('function EggService.carriers')]
    return r'''
local carried, lastPos, respawned = {}, {}, {}
local nests = {Forest = {}}
local function spawnNestEgg(b, spot, e) respawned[spot] = e end
local EggService = {}
local p = {SetAttribute=function() end}
''' + body + r'''
local victim = {}
local e = {biome='Forest', spot='S1', stolenFrom=victim, stolenAt=1, victims={[victim]=true}}
carried[p] = e
EggService.drop(p)
assert(respawned.S1 == e, 'fixture: nest egg respawned with the same table')
assert(e.stolenFrom == nil and e.stolenAt == nil and e.victims == nil, 'dropped eggs forget who they were stolen from')
print('PASS: drop clears theft history (no stale whacks/take-backs on the next grabber)')
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='sam-stick-') as temp:
        for name, build in (('pricing', pricing), ('swing', swing), ('drop', drop)):
            script = Path(temp) / f'{name}.luau'
            script.write_text(build(), encoding='utf-8')
            subprocess.run([str(args.runtime / 'luau.exe'), str(script)], check=True)


if __name__ == '__main__':
    main()
