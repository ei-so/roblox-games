"""Run real Luau service code with small Roblox boundary stubs, plus compile all scripts.

Usage: python steal-a-ride/tests/run_feedback_checks.py --runtime PATH_TO_LUAU_DIRECTORY
The generated harness is scratch, never installed in the game.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def module(path, replacements):
    source = (ROOT / "src" / path).read_text(encoding="utf-8-sig")
    for old, new in replacements.items():
        assert old in source, f"test loader dependency changed: {old}"
        source = source.replace(old, new)
    return "(function()\n" + source + "\nend)()"


def harness():
    prelude = '''
local Config = {
    BiomeById = {Forest = {species = {"Chick", "Bunny", "Fox"}, hatchTime = 10}},
    Species = {Chick = {biome = "Forest"}, Bunny = {biome = "Forest"}, Fox = {biome = "Forest"}},
    SpeciesWeights = {50, 35, 15},
    Rarities = {{id="Common",odds=55,hatchX=1},{id="Uncommon",odds=28,hatchX=1.5},{id="Rare",odds=12,hatchX=2},{id="Epic",odds=4,hatchX=3},{id="Legendary",odds=1,hatchX=5},{id="Mythic",odds=0,hatchX=8}},
    Events = {secretOdds={0,0,0,72,18,10}, secretHatch=60, luckyHatch=30},
    LuckyPassChance = 0.1,
}
Config.RarityById = {}
for _, r in Config.Rarities do Config.RarityById[r.id] = r end
local workspace = {GetAttribute=function() return nil end}
local Random = {new = function() return {NextNumber = function() return 0.3 end} end}
local attrs = {}
local player = {SetAttribute = function(_, k, v) attrs[k] = v end, GetAttribute = function(_, k) return attrs[k] end}
local data = {Incubators={false}, IncubatorCount=1, PendingEggs={}}
local folder = {ClearAllChildren=function() end}
local plot = {Incubators={GetChildren=function() return {} end}, FindFirstChild=function() return folder end}
local DataService = {get=function() return data end}
local PlotService = {get=function() return plot end}
local Players = {}
local CreatureBuilder, CreatureService = {}, {}
local Notify = {FireClient=function() end}
local ReplicatedStorage = {Remotes={Notify=Notify}}
local game = {GetService=function(_, k) return k == "Players" and Players or ReplicatedStorage end}
'''
    hatch = module("ServerScriptService/Services/HatchService.luau", {
        "local Config = require(ReplicatedStorage.Shared.Config)": "",
        "local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)": "",
        "local DataService = require(script.Parent.DataService)": "",
        "local PlotService = require(script.Parent.PlotService)": "",
        "local CreatureService = require(script.Parent.CreatureService)": "",
    })
    checks = '''
local egg = {biome="Forest", species="Fox", mutation="Golden"}
local result = HatchService.roll(egg)
assert(result.species == "Fox", "chosen species must hatch, rather than rolling a different species")
assert(result.mutation == "Golden", "mutation survives hatching")
assert(HatchService.deposit(player, egg), "deposit succeeds")
assert(data.Incubators[1].species == "Fox", "deposit/save keeps chosen species")
local rolled = data.Incubators[1].result
assert(rolled and rolled.species == "Fox" and rolled.mutation == "Golden", "rarity is rolled at deposit, keeping species and mutation")
assert(HatchService.hatchTime(data.Incubators[1]) == 10 * Config.RarityById[rolled.rarity].hatchX, "hatch time = biome time x rarity")
for _, r in Config.Rarities do
    assert(HatchService.hatchTime({biome="Forest",result={rarity=r.id}}) == 10 * r.hatchX, r.id.." hatch multiplier")
end
assert(HatchService.hatchTime({biome="Forest",result={rarity="Legendary"}}) > HatchService.hatchTime({biome="Forest",result={rarity="Common"}}), "rarer eggs take longer")
assert(HatchService.hatchTime({biome="Forest"}) == 10, "eggs saved before this update keep the biome time")
assert(HatchService.hatchTime({biome="Forest",secret=true,result={rarity="Epic"}}) == 60 * 3, "Secret Eggs scale from their 60 s base")
assert(HatchService.hatchTime({biome="Forest",lucky=true,result={rarity="Legendary"}}) == 30, "Lucky Eggs stay a fast 30 s reward")
local raided = HatchService.takeEgg(player, 1)
assert(raided.species == "Fox", "PvP/Mama removal keeps chosen species")
assert(raided.result == nil, "a raided egg re-rolls for its new owner")
data.Incubators[1] = {biome="Forest",startedAt=0}
HatchService.give(player, raided, 4)
assert(data.PendingEggs[1].species == "Fox", "full-incubator queue keeps chosen species")
assert(data.PendingEggs[1].progress == 4, "pending return keeps hatch progress")
local secret = HatchService.roll({biome="Forest",secret=true,species="Fox"})
assert(secret.species == "Chick" and secret.rarity == "Epic", "Secret Eggs keep existing rolls")
assert(HatchService.roll({biome="Forest",lucky=true,species="Fox"}).species == "Chick", "Lucky rewards keep existing rolls")
assert(HatchService.roll({biome="Forest"}).species == "Chick", "older saves without species still hatch")
assert(HatchService.roll({biome="Forest",species="not-a-species"}).species == "Chick", "invalid saved species falls back safely")
print("PASS: chosen species, rarity rolled at deposit, rarity hatch times, deposit/save, PvP/Mama take, pending return, old saves, Secret/Lucky compatibility")
'''
    return prelude + "\nlocal HatchService = " + hatch + checks



def visual_harness():
    stubs = r"""
local V = {}; V.__index = V
local function vec(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V) end
V.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__mul=function(a,b)
    if type(a)=="number" then a,b=b,a end
    return type(b)=="number" and vec(a.X*b,a.Y*b,a.Z*b) or vec(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
local Vector3={new=vec,zero=vec()}
local Vector2={new=vec}
local cfmeta={__mul=function(a,b) return a end}
local function cf(...) return setmetatable({...},cfmeta) end
local CFrame={new=cf,lookAt=cf,Angles=cf}
local Color={}; Color.__index=Color
local function color(r,g,b) return setmetatable({R=r,G=g,B=b},Color) end
function Color:Lerp(other,t) return color(self.R+(other.R-self.R)*t,self.G+(other.G-self.G)*t,self.B+(other.B-self.B)*t) end
local Color3={new=color,fromRGB=function(r,g,b) return color(r/255,g/255,b/255) end}
local Enum=setmetatable({},{__index=function(t,k) local e=setmetatable({},{__index=function(_,n) return n end}); rawset(t,k,e); return e end})
local methods={}
function methods:IsA(class) return self.class==class or class=="BasePart" and self.class=="Part" end
function methods:GetDescendants()
    local out={}
    local function walk(n) for _,c in n.children do table.insert(out,c); walk(c) end end
    walk(self); return out
end
function methods:SetAttribute(k,v) self.attrs[k]=v end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:AddTag(tag) self.tags=self.tags or {};self.tags[tag]=true end
local Instance={new=function(class)
    return setmetatable({class=class,children={},attrs={},Transparency=0},{__index=methods,__newindex=function(t,k,v)
        rawset(t,k,v); if k=="Parent" and v then table.insert(v.children,t) end
    end})
end}
local Config={BiomeById={Forest={look={accent=Color3.fromRGB(120,230,90)}}},Species={
    Chick={biome="Forest",body=Color3.fromRGB(255,221,64),accent=Color3.fromRGB(255,140,30),features={"beak","wings:small"}},
    Bunny={biome="Forest",body=Color3.fromRGB(245,245,245),accent=Color3.fromRGB(255,170,190),features={"ears:long","tail:puff","nose"}},
    Fox={biome="Forest",body=Color3.fromRGB(235,120,40),accent=Color3.fromRGB(250,245,235),features={"ears:pointy","muzzle","tail:bushy"}},
}}
Config.EggFX={themes={Forest={texture="test-firefly",color=Color3.fromRGB(255,235,120),size={0.25,0},rate=2,life=1.5,speed=0.4,light=1,acceleration=Vector3.zero,spread=45,spin=0}}}
local ColorSequence={new=function(...) return {...} end}
local NumberSequence={new=function(...) return {...} end}
local NumberSequenceKeypoint={new=function(...) return {...} end}
local NumberRange={new=function(...) return {...} end}
"""
    deps = {"local Config = require(script.Parent.Config)":"", "local Meshes = script.Parent.Parent:FindFirstChild(\"CreatureMeshes\")":"local Meshes = nil"}
    current = module("ReplicatedStorage/Shared/CreatureBuilder.luau", deps)
    original = module("../before-feedback-20261007/ReplicatedStorage/Shared/CreatureBuilder.luau", deps)
    checks = r"""
local bunny=Builder.buildEgg("Forest",nil,false,"Bunny")
local fox=Builder.buildEgg("Forest",nil,false,"Fox")
assert(bunny.PrimaryPart.Color.R ~= fox.PrimaryPart.Color.R,"regular shells need species-specific visual clues")
local ear=false
for _,p in bunny:GetDescendants() do
    if p.Name=="Ear" then ear=true end
    assert(not p:IsA("TextLabel") and not p:IsA("BillboardGui"),"no explicit species labels")
    if p:IsA("BasePart") then assert(p.CanCollide==false,"clues remain noncolliding") end
end
assert(ear,"Bunny egg carries an ear-shaped clue")
local themed=0
for _,p in bunny:GetDescendants() do
    if p.Name=="EggThemeParticles" then
        themed+=1
        assert(p:IsA("ParticleEmitter") and p.Parent==bunny.PrimaryPart and not p.Enabled,
            "normal eggs provide a disabled shell emitter for client distance gating")
        assert(p.tags and p.tags.BiomeEggFX,"normal egg particles must register for the client budget")
    end
end
assert(themed==1,"a normal egg has exactly one biome-themed emitter")
local secret=Builder.buildEgg("Forest",nil,true,"Bunny")
local old=OriginalBuilder.buildEgg("Forest",nil,true)
assert(#secret:GetDescendants()==#old:GetDescendants(),"Secret Egg structure stays unchanged")
assert(secret.PrimaryPart.Color.R==old.PrimaryPart.Color.R and secret.PrimaryPart.Material==old.PrimaryPart.Material,"Secret Egg appearance stays unchanged")
print("PASS: species shell clues, no name labels, noncolliding parts, unchanged Secret Egg")
"""
    return stubs + "local Builder = " + current + "\nlocal OriginalBuilder = " + original + checks


def mama_harness():
    source = (ROOT / "src/ServerScriptService/Services/MamaService.luau").read_text(encoding="utf-8-sig")
    hit = source[source.index("local function onHit("):source.index("local function buildMama(")]
    stubs = r"""
local V={}; V.__index=function(t,k)
    local m=math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z)
    if k=="Magnitude" then return m end
    if k=="Unit" then return setmetatable({X=t.X/m,Y=t.Y/m,Z=t.Z/m},V) end
    return V[k]
end
local function vec(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V) end
V.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__mul=function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
local Vector3={new=vec}
local function typeof(v) return getmetatable(v)==V and "Vector3" or type(v) end
local Color3={new=function() return {} end}
local task={delay=function() end}
local RaycastParams={new=function() return {} end}
local Enum={RaycastFilterType={Exclude="Exclude"}}
local E={mamaClickRange=80,mamaClickCap=8}
local ORB_ON={}
local orb={Position=vec(0,0,10), Size=vec(6,6,6)}
local root={Position=vec()}
local humanoid={Health=100}
local head={Position=vec()}
local player={Parent=true,CameraMaxZoomDistance=128,Character={
    FindFirstChild=function(_,k) return k=="HumanoidRootPart" and root or k=="Head" and head end,
    FindFirstChildOfClass=function() return humanoid end},SetAttribute=function() end}
local workspace={Raycast=function(_,o,d,p) if p.RespectCanCollide then return nil end return {Instance=orb} end}
local afterDamage=function() end
local function fresh() return {hp=300,activeOrb=orb,clicks={},damage={}} end
"""
    checks = r"""
local f=fresh(); humanoid.Health=0; onHit(f,player,orb)
assert(f.hp==300,"dead players cannot damage Mama")
humanoid.Health=100; root.Position=vec(1000,0,0); f=fresh(); onHit(f,player,orb)
assert(f.hp==300,"out-of-range attacks cannot damage Mama")
root.Position=vec(); f=fresh(); onHit(f,player,{Position=vec()})
assert(f.hp==300,"inactive/foreign weak spots cannot damage Mama")
f=fresh(); f.over="defeated"; onHit(f,player,orb)
assert(f.hp==300,"finished fights reject hits")
f=fresh(); onHit(f,player,orb,vec(0,0,-64),vec(0,0,1))
assert(f.hp==299,"legitimate zoomed-out camera can attack")
f=fresh(); onHit(f,player,orb,vec(1000,0,0),vec(0,0,1))
assert(f.hp==300,"forged distant camera origins cannot damage Mama")
f=fresh(); onHit(f,player,orb,vec(),vec(0/0,0,1))
assert(f.hp==300,"nonfinite aim cannot damage Mama")
workspace.Raycast=function() return {Instance={}} end
f=fresh(); onHit(f,player,orb,vec(),vec(0,0,1))
assert(f.hp==300,"blocked aim cannot damage Mama")
workspace.Raycast=function(_,o,d,p) if p.RespectCanCollide then return nil end return {Instance=orb} end
f=fresh()
for i=1,12 do
    if i%2==0 then onHit(f,player,orb,vec(),vec(0,0,1)) else onHit(f,player,orb) end
end
assert(f.hp==292 and f.damage[player]==8,"click and hold share the eight-hit rolling cap")
print("PASS: Mama dead/range/orb/end/origin/nonfinite/occlusion validation and combined click-hold cap")
"""
    return stubs + hit + checks


def movement_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    speed=module("ServerScriptService/Services/SpeedService.luau",{
        'local Config = require(game:GetService("ReplicatedStorage").Shared.Config)':'',
        'local DataService = require(script.Parent.DataService)':''})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local task={delay=function() end}
local data={SaddleLevel=2}
local DataService={get=function() return data end}
local player={Parent=true,SetAttribute=function() end,Character={FindFirstChildOfClass=function() return {} end}}
"""
    checks=r"""
assert(Config.WalkSpeed==25,"walking starts at 25")
local plan={Forest={22.5,4,.96},Lake={33.75,15,.94},Desert={45,60,.91},Jungle={55,200,.88},Tundra={65,700,.85},Volcano={75,2500,.82},Cosmic={95,8000,.80}}
local prev
for _,b in Config.Biomes do
    local want=plan[b.id]
    assert(math.abs(b.guardianSpeed-want[1])<1e-9,b.id.." guardian speed after the 1.25 scale")
    assert(b.baseIncome==want[2],b.id.." lowered base income")
    assert(Config.carryMult({biome=b.id})==want[3],b.id.." normal egg carry weight")
    local secret=Config.carryMult({biome=b.id,secret=true})
    assert(math.abs(secret-want[3]*.85)<1e-9 and secret<want[3],b.id.." Secret Egg is heavier than its normal egg")
    assert(Config.carryMult({biome=b.id,lucky=true})==want[3],b.id.." Lucky Eggs use the normal weight")
    if prev then assert(want[3]<prev,"eggs get heavier with biome depth") end
    prev=want[3]
end
assert(Config.Guardian.tiredMult==0.95,"guardians tire less")
assert(Config.Steal.carrierHold==0 and Config.Steal.takeBackHold==0,"stealing from a carrier and taking it back are instant taps")
local hatch={Forest=15,Lake=30,Desert=45,Jungle=68,Tundra=90,Volcano=135,Cosmic=180}
for _,b in Config.Biomes do assert(b.hatchTime==hatch[b.id],b.id.." base hatch time spread x1.5") end
assert(Config.Nests.refillInterval==360 and Config.Nests.forestRefill==20,"deep nests refill every 6 min; Forest unchanged")
assert(math.abs(Config.Costs.saddle(10)-100*1.85^10)<1e-6,"saddle price grows 1.85x per level")
assert(Config.Gear.priceSeconds==300 and Config.Gear.minPrice==500,"cash gear costs five minutes of income")
assert(math.abs(Config.BiomeById.Forest.mountBase-28.125)<0.001,"mount bases scale with walking")
local riding=Config.mountSpeed({species="Chick",rarity="Common"})
assert(math.abs(riding-30.125)<0.001,"mount base scales while its species bonus stays")
assert(SpeedService.base(player)==27,"saddle still adds to walking speed")
SpeedService.mountSpeedOf=function() return riding end
assert(SpeedService.base(player)==riding+2,"saddle still adds to mount speed")
SpeedService.multiply(player,"soda",1.25,20)
assert(SpeedService.current(player)==(riding+2)*1.25,"soda multiplier survives")
assert(SpeedService.allowed(player)>=SpeedService.current(player),"carrier allowance covers legitimate boosted speed")
SpeedService.setInWater(player,true)
assert(SpeedService.current(player)<(riding+2)*1.25,"water penalty survives")
SpeedService.stun(player,1)
assert(SpeedService.current(player)==0,"stuns survive speed calibration")
-- egg weight: applied while carrying, gone the moment the egg leaves
local carryPlayer={Parent=true,SetAttribute=function() end,Character={FindFirstChildOfClass=function() return {} end}}
local held
SpeedService.carryOf=function(p) return p==carryPlayer and held or nil end
local free=SpeedService.current(carryPlayer)
held={biome="Cosmic",secret=true}; SpeedService.carryChanged(carryPlayer)
assert(math.abs(SpeedService.current(carryPlayer)-free*.68)<1e-9,"Cosmic Secret Egg keeps 68% speed")
assert(math.abs(SpeedService.allowed(carryPlayer)-SpeedService.base(carryPlayer)*Config.Abilities.Dash.speedMult*.68)<1e-9,"carrier allowance uses the weighted straight-line maximum")
SpeedService.multiply(carryPlayer,"soda",1.25,20)
assert(SpeedService.allowed(carryPlayer)>=SpeedService.current(carryPlayer),"weighted allowance still covers boosts")
held=nil; SpeedService.carryChanged(carryPlayer)
assert(math.abs(SpeedService.current(carryPlayer)-free*1.25)<1e-9,"speed restores immediately when the egg is gone")
-- turning: horizontal travel direction only
local step=SpeedService.turnStep
local m,x,z=step(1,nil,nil,30,0,.1)
assert(m==1 and x==1 and z==0,"first sample just records the heading")
for _=1,10 do m,x,z=step(m,x,z,30,0,.1) end
assert(m==1,"straight travel keeps full speed")
local c,cx,cz=step(1,1,0,30*math.cos(math.rad(5)),30*math.sin(math.rad(5)),.1)
assert(c==1,"small corrections (50 deg/s) are free")
m,x,z=step(1,1,0,-30,0,.1)
assert(math.abs(m-.8)<1e-9,"a sharp reversal hits the 20% floor")
for i=1,20 do m,x,z=step(m,x,z,(i%2==0 and 30 or -30),0,.1) end
assert(math.abs(m-.8)<1e-9,"repeated zigzags sustain, never stack beyond, the floor")
local mid=step(1,1,0,30*math.cos(math.rad(26.25)),30*math.sin(math.rad(26.25)),.1)
assert(math.abs(mid-.9)<1e-6,"penalty ramps linearly between 75 and 450 deg/s")
local r,rx,rz=m,x,z
for _=1,4 do r,rx,rz=step(r,rx,rz,rx*30,rz*30,.1) end
assert(math.abs(r-.9)<1e-9,"0.4 s of straight travel recovers half")
for _=1,4 do r,rx,rz=step(r,rx,rz,rx*30,rz*30,.1) end
assert(math.abs(r-1)<1e-9,"0.8 s of straight travel fully recovers")
local s,sx,sz=step(.8,1,0,0,0,.1)
assert(s==.8 and sx==nil,"stopping keeps the penalty and forgets the heading")
s,sx,sz=step(s,sx,sz,0,30,.1)
assert(s==.8,"resuming after a stop is not counted as a turn")
assert(step(1,1,0,-30,0,2)==1,"long sampling gaps reset history instead of penalising")
assert(step(1,1,0,-1,0,.1)==1,"slow drifting below 2 studs/s is ignored")
assert(step(1,1,0,-30,0,.05)==step(1,1,0,-30,0,.2) and step(1,1,0,0,30,.4)>step(1,1,0,0,30,.1),"turn rate uses the real sampling interval")
print("PASS: movement, biome guardian/income/carry tuning, Secret weight, mount/saddle bonuses, soda, water, stun, weighted carrier allowance, turn slowdown and recovery")
"""
    return pre+"local Config="+cfg+"\nlocal SpeedService="+speed+checks


def pen_roam_harness():
    walk = module("ReplicatedStorage/Shared/WalkCycle.luau", {
        "local Config = require(script.Parent.Config)": "local Config = {}",
    })
    # Random is a Roblox boundary; movement and timing run from the real module.
    pre = r'''
local Random = {new=function(seed)
    return {NextNumber=function(_, low, high)
        seed = (seed * 48271) % 2147483647
        return low + (high-low) * seed/2147483647
    end}
end}
'''
    checks = r'''
for _, dt in {1/60, 1/15, .1, .5} do
    for seed=1,32 do
        local state=WalkCycle.newPenRoam(seed*7919,1.6)
        local moved, rested, turned=0,0,0
        for tick=1,math.ceil(60/dt) do
            local x,z,yaw,phase=state.x,state.z,state.yaw,state.phase
            WalkCycle.stepPenRoam(state,dt,2.5)
            local distance=math.sqrt((state.x-x)^2+(state.z-z)^2)
            assert(state.x^2+state.z^2<=1.6^2+1e-8,"creature escaped its assigned Pen area")
            assert(distance<=1.25*math.min(dt,.1)+1e-8,"movement jumped after a slow frame")
            assert(math.abs(state.yaw-yaw)<=2.4*math.min(dt,.1)+1e-8,"turning must stay smooth")
            assert(state.phase>=phase and state.amount>=0 and state.amount<=1,"gait stays valid")
            if distance>0 then moved+=distance else rested+=dt end
            if state.yaw~=yaw then turned+=1 end
        end
        assert(moved>3 and rested>1 and turned>0,"Pen pets must stroll, turn and pause")
    end
end
local a,b=WalkCycle.newPenRoam(123,1.6),WalkCycle.newPenRoam(456,1.6)
for i=1,600 do WalkCycle.stepPenRoam(a,1/60,2);WalkCycle.stepPenRoam(b,1/60,2) end
assert(math.abs(a.x-b.x)+math.abs(a.z-b.z)>.1,"different pets should not march in sync")
local x,z,yaw,phase=a.x,a.z,a.yaw,a.phase
WalkCycle.stepPenRoam(a,0,2)
assert(a.x==x and a.z==z and a.yaw==yaw and a.phase==phase,"zero elapsed time cannot move a pet")
print("PASS: Pen roaming stays bounded, turns smoothly, walks and rests; slow frames and independent pets")
'''
    return pre + "local WalkCycle=" + walk + checks


def tutorial_harness():
    source=(ROOT/"src/StarterPlayer/StarterPlayerScripts/ClientMain.luau").read_text(encoding="utf-8-sig")
    step=source[source.index("local function tutorialStep()"):source.index("local function updateTutorial(")]
    pre=r"""
local attrs={Tips="",CreatureCount=1,Riding="Chick",Cash=0,CashPerSecond=0,SaddleLevel=0}
local player={GetAttribute=function(_,k) return attrs[k] end}
local flags={}
local done=function(k) return flags[k] end
local mark=function(k) flags[k]=true end
local myPlot=function() return nil end
local nestPosition=function(id) return id end
local Config={Costs={saddle=function() return 180 end},Plot={joinLock=30}}
local finishedAt
"""
    checks=r"""
local goal,msg=tutorialStep()
assert(msg and not msg:find("Shop"),"a player with no pen income should get an earning goal before shopping")
attrs.CashPerSecond=5; goal,msg=tutorialStep()
assert(msg and not msg:find("buy"),"a player below the upgrade price should not be told to buy it")
attrs.Cash=200; goal,msg=tutorialStep()
assert(msg and msg:find("Shop"),"an affordable upgrade points to the existing Shop")
flags.done=true; goal,msg=tutorialStep()
assert(goal==nil and msg==nil,"completed tutorials stay completed")
print("PASS: earning-first tutorial, upgrade affordability, preserved saved completion")
"""
    return pre+step+checks

def mount_harness():
    mount=module("ServerScriptService/Services/MountService.luau",{
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)':'',
        'local WalkCycle = require(ReplicatedStorage.Shared.WalkCycle)':'',
        'local DataService = require(script.Parent.DataService)':'',
        'local SpeedService = require(script.Parent.SpeedService)':'',
        'local CreatureService = require(script.Parent.CreatureService)':''})
    pre=r"""
local ReplicatedStorage={Remotes={Notify={FireClient=function() end}}}
local game={GetService=function() return ReplicatedStorage end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local Config={Species={Chick={display="Chick"},Fox={display="Fox",ability="Jump"}},mountSpeed=function(c) return c.speed end}
local data={Rebirths=0,Mounts={"a","b"},Pen={},Creatures={a={species="Chick",speed=1},b={species="Fox",speed=2}}}
local DataService={get=function() return data end}
local SpeedService={refresh=function() end}
local changed=0
local CreatureService={changed=function() changed+=1 end,stableCount=function() return 0 end}
local attrs={ExtraMountPass=true}
local player={GetAttribute=function(_,k) return attrs[k] end,SetAttribute=function(_,k,v) attrs[k]=v end}
"""
    checks=r"""
MountService.trim(player)
assert(#data.Mounts==2 and changed==0,"pass owners keep both saved mounts")
attrs.ExtraMountPass=nil
MountService.trim(player)
assert(#data.Mounts==1 and data.Mounts[1]=="b","without a slot source the oldest saved mount returns to the stable")
assert(data.Creatures.a,"trimmed creature is kept, not deleted")
data.Mounts={"a","b"}; data.Rebirths=3
MountService.trim(player)
assert(#data.Mounts==2,"the rebirth-3 slot still allows two mounts")
print("PASS: saved mounts trimmed to pass/rebirth slots on join, creatures kept")
"""
    return pre+"local MountService="+mount+checks


def guardian_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    guardian=module("ServerScriptService/Services/GuardianService.luau",{
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)':'',
        'local WalkCycle = require(ReplicatedStorage.Shared.WalkCycle)':'',
        'local SpeedService = require(script.Parent.SpeedService)':''})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local RaycastParams={new=function() return {} end}
local ReplicatedStorage={Remotes={Notify={}}}
local game={GetService=function(_,k) return k=="ReplicatedStorage" and ReplicatedStorage or {} end}
"""
    checks=r"""
local G=Config.Guardian
assert(G.rageDistance==60 and G.rageMult==1.3,"rage tuning as approved")
assert(math.abs(GuardianService.chaseFactor(0,false,false)-G.patrolSpeedMult)<1e-9,"a chase starts at patrol pace")
assert(GuardianService.chaseFactor(5,false,false)==1,"full speed after the wind-up")
assert(GuardianService.chaseFactor(G.tireAfter+1,false,false)==G.tiredMult,"long chases still tire")
assert(GuardianService.chaseFactor(G.tireAfter+1,true,false)==G.rageMult,"rage ignores tiredness")
assert(GuardianService.chaseFactor(5,true,false)==G.rageMult,"rage is 1.3x full speed")
assert(GuardianService.chaseFactor(5,true,true)==G.rageMult*G.noLaneSpeedMult,"no-lane penalty still stacks")
for _,b in Config.Biomes do
    local set=Config.GuardianSounds and Config.GuardianSounds[b.id]
    assert(set,b.id.." guardian has a sound set")
    for _,state in {"idle","alert","chase","step"} do
        local e=set[state]
        assert(e and type(e[1])=="number" and e[1]>0 and e[2]>0 and e[3]>0 and e[3]<=1,b.id.." "..state.." sound has id, pitch and volume")
    end
end
local EM=Config.EscapeMusic
assert(EM and EM.sting and EM.sting[1]>0 and EM.duck>0 and EM.duck<1,"escape music has a safe-line sting and an ambience duck")
for _,b in Config.Biomes do
    local t=EM.tracks[b.id]
    assert(t and t[1]>0 and t[2]>0 and t[2]<=1,b.id.." has an escape track with a volume")
end
local W,P=Config.Patch.warn,Config.Patch
assert(W and 0<W.flash and W.flash<W.tick and W.tick<W.frantic and W.frantic<P.stuckAfter,"patch warning ramps flash -> tick -> frantic before the sink")
local M=Config.MamaFX
assert(M and M.duck>0 and M.duck<1,"Mama entrance has an event-long music duck")
for _,state in {"roar","whoosh","step","wingLoop"} do
    local e=M[state]
    assert(e and type(e[1])=="number" and e[1]>0 and e[2]>0 and e[3]>0 and e[3]<=1,"Mama "..state.." has a loadable id, pitch and volume")
end
assert(type(M.shadowImage)=="string","Mama shadow has a texture or uses the oval fallback")
print("PASS: guardian wind-up, tiredness, rage 1.3x near the safe line overriding tiredness; patch warning ramp before sinking")
"""
    return pre+"local Config="+cfg+"\nlocal GuardianService="+guardian+checks


def gear_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    gear=module("ServerScriptService/Services/GearService.luau",{
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local DataService = require(script.Parent.DataService)':'',
        'local SpeedService = require(script.Parent.SpeedService)':'',
        'local CreatureService = require(script.Parent.CreatureService)':'',
        'local ShopService = require(script.Parent.ShopService)':'',
        'local GuardianService = require(script.Parent.GuardianService)':''})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local income=0
local CreatureService={incomeOf=function() return income end}
local DataService,SpeedService,ShopService,GuardianService={}, {}, {extraItems={}}, {}
local game={GetService=function() return {Remotes={Notify={}}} end}
"""
    checks=r"""
assert(GearService.price({})==500,"zero income pays the $500 floor")
income=1; assert(GearService.price({})==500,"low income still pays the floor")
income=10; assert(GearService.price({})==3000,"price is five minutes of income")
income=8000.5; assert(GearService.price({})==2400150,"high income: floor(income * 300)")
print("PASS: cash gear costs five minutes of income with a $500 floor")
"""
    return pre+"local Config="+cfg+"\nlocal GearService="+gear+checks


def touch_buttons_harness():
    mod=module("ReplicatedStorage/Shared/TouchButtons.luau",{
        'local Players = game:GetService("Players")':'local Players = {}',
        'local ContextActionService = game:GetService("ContextActionService")':'local ContextActionService = {}'})
    pre=r"""
local V={}; V.__index=V
local Vector2={new=function(x,y) return setmetatable({X=x,Y=y},V) end}
local workspace={}
"""
    checks=r"""
-- Roblox TouchJump: small screens (min axis <= 500) 70 px at (W-95, H-90); otherwise 120 px at (W-170, H-210)
local function overlap(a,as,b,bs) return a.X<b.X+bs and b.X<a.X+as and a.Y<b.Y+bs and b.Y<a.Y+as end
for _,screen in {{name="phone",w=844,h=390,j=70,jx=95,jy=90,b=50},{name="tablet",w=1180,h=820,j=120,jx=170,jy=210,b=70},{name="big tablet",w=1366,h=1024,j=120,jx=170,jy=210,b=70}} do
    local jp=Vector2.new(screen.w-screen.jx,screen.h-screen.jy)
    local placed={}
    for _,name in {"Dash","RideFlight","RideUp","RideDown"} do
        local size=name=="Dash" and screen.b or 58
        local at=TouchButtons.slot(name,jp,Vector2.new(screen.j,screen.j),size)
        assert(at,name.." has a slot")
        assert(not overlap(at,size,jp,screen.j),screen.name..": "..name.." must not cover the jump button")
        assert(at.X>=0 and at.Y>=0 and at.X+size<=screen.w and at.Y+size<=screen.h,screen.name..": "..name.." stays on screen")
        for other,o in placed do assert(not overlap(at,size,o.at,o.size),screen.name..": "..name.." overlaps "..other) end
        placed[name]={at=at,size=size}
    end
end
assert(TouchButtons.slot("Unknown",Vector2.new(0,0),Vector2.new(70,70),50)==nil,"unknown actions are left alone")
print("PASS: Dash and flight touch buttons sit beside the jump button on phones and tablets without overlapping")
"""
    return pre+"local TouchButtons="+mod+checks


def pacing_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    mod=module("ServerScriptService/Services/PacingService.luau",{
        'local AnalyticsService = game:GetService("AnalyticsService")':'',
        'local Config = require(game:GetService("ReplicatedStorage").Shared.Config)':'',
        'local DataService = require(script.Parent.DataService)':''})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local logs={}
local AnalyticsService={
    LogOnboardingFunnelStepEvent=function(_,p,step,name) table.insert(logs,{"funnel",step,name}) end,
    LogCustomEvent=function(_,p,name,value) table.insert(logs,{"custom",name,value}) end}
local saves, played = {}, {}
local DataService={get=function(p) return saves[p] end, playtime=function(p) return played[p] end}
"""
    checks=r"""
local new, veteran = {}, {}
saves[new], played[new] = {}, 0
saves[veteran], played[veteran] = {}, 5000
PacingService.onPlayerReady(new); PacingService.onPlayerReady(veteran)
assert(saves[new].Pacing and saves[veteran].Pacing==nil,"only brand-new saves are tracked")
played[new]=600
PacingService.deposited(new,{biome="Lake"})
assert(saves[new].Pacing.Lake==10,"first Lake deposit at 10 min recorded")
local n=#logs
played[new]=700
PacingService.deposited(new,{biome="Lake"})
assert(#logs==n and saves[new].Pacing.Lake==10,"only the first deposit per biome counts")
PacingService.deposited(new,{biome="Cosmic",secret=true}); PacingService.deposited(new,{biome="Cosmic",lucky=true})
assert(saves[new].Pacing.Cosmic==nil,"Secret and Lucky eggs are not progression")
PacingService.deposited(veteran,{biome="Cosmic"})
assert(saves[veteran].Pacing==nil and #logs==n,"veterans are never logged")
played[new]=9000
PacingService.deposited(new,{biome="Cosmic"})
assert(saves[new].Pacing.Cosmic==150,"first Cosmic at 150 min")
local f,c
for _,l in logs do if l[1]=="funnel" and l[3]=="First Cosmic egg" then f=l[2] end if l[1]=="custom" and l[2]=="MinutesToFirstCosmicEgg" then c=l[3] end end
assert(f==8 and c==150,"funnel step 8 and minutes custom event for Cosmic")
AnalyticsService.LogCustomEvent=function() error("analytics down") end
PacingService.deposited(new,{biome="Desert"})
assert(saves[new].Pacing.Desert,"analytics failures never break gameplay")
print("PASS: pacing tracker logs first deposit per biome for brand-new players only; Secret/Lucky excluded; failures harmless")
"""
    return pre+"local Config="+cfg+"\nlocal PacingService="+mod+checks


def plaza_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    mod=module("ServerScriptService/Services/PlazaService.luau",{
        'local Players = game:GetService("Players")':'local Players = {}',
        'local DataStoreService = game:GetService("DataStoreService")':'local DataStoreService = {}',
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")':'local ReplicatedStorage = {Remotes={Notify={}}}',
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)':'local CreatureBuilder = {}',
        'local Format = require(ReplicatedStorage.Shared.Format)':'local Format = {}',
        'local DataService = require(script.Parent.DataService)':'local DataService = {}',
        'local CreatureService = require(script.Parent.CreatureService)':'local CreatureService = {}'})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
"""
    checks=r"""
local a,b,c={},{},{}
local function e(owner,uid,rarity,income) return {owner=owner,uid=uid,creature={rarity=rarity},income=income} end
local picked=PlazaService.pickShowcase({e(a,"1","Common",5),e(a,"2","Mythic",100),e(a,"3","Legendary",900),e(b,"4","Legendary",50),e(c,"5","Rare",10)},3)
assert(picked[1].uid=="2","rarest creature takes the first pedestal")
assert(picked[2].uid=="4" and picked[3].uid=="5","one creature per owner before anyone gets a second spot")
local two=PlazaService.pickShowcase({e(a,"1","Common",5),e(a,"2","Epic",9),e(a,"3","Epic",20)},3)
assert(#two==3 and two[1].uid=="3" and two[2].uid=="2","a solo server still fills every pedestal, income breaks ties")
assert(#PlazaService.pickShowcase({},3)==0,"empty server shows nothing")
assert(PlazaService.chestReward(0)==1000 and PlazaService.chestReward(1)==1000,"chest pays at least $1000")
assert(PlazaService.chestReward(100)==60000,"chest pays 10 minutes of income")
assert(Config.Plaza.chestCooldown==4*3600,"chest every 4 hours")
print("PASS: Plaza showcase picks rarest per owner then fills; chest pays 10 min of income (min $1000) every 4 h")
"""
    return pre+"local Config="+cfg+"\nlocal PlazaService="+mod+checks


def egg_fx_harness():
    cfg = module("ReplicatedStorage/Shared/Config.luau", {})
    source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Effects.luau").read_text(encoding="utf-8-sig")
    begin = source.find("local function updateEggFX()")
    end = source.find("-- End egg FX budget", begin)
    budget = source[begin:end] if begin >= 0 else ""
    pre = r'''
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local V={__sub=function(a,b) return {Magnitude=math.abs(a.x-b.x)} end}
local function vec(x) return setmetatable({x=x},V) end
local workspace={CurrentCamera={CFrame={Position=vec(0)}}}
local tagged={}
local CollectionService={GetTagged=function() return tagged end}
local function egg(x,inside)
    local p={Position=vec(x),IsA=function(_,k) return k=="BasePart" end}
    return {Parent=p,Enabled=true,cleared=0,IsA=function(_,k) return k=="ParticleEmitter" end,
        IsDescendantOf=function() return inside~=false end,Clear=function(self) self.cleared+=1 end}
end
'''
    checks = r'''
for _,b in Config.Biomes do
    local t=Config.EggFX.themes[b.id]
    assert(t and t.texture~="" and t.rate>0 and t.life>0 and t.sound[1]>0 and t.sound[4]<=4,b.id.." egg/hatch theme is complete and short")
end
local near,far,closest,outside=egg(10),egg(81),egg(5),egg(0,false)
tagged={near,far,closest,outside};Config.EggFX.maxActive=1
updateEggFX()
assert(closest.Enabled and not near.Enabled and not far.Enabled and not outside.Enabled,"only closest in-range egg gets the particle budget")
assert(near.cleared==1 and far.cleared==1,"disabled particles clear when eggs leave the budget")
Config.EggFX.maxActive=24;updateEggFX()
assert(near.Enabled and closest.Enabled and not far.Enabled,"nearby eggs share the normal budget; far eggs stay quiet")
workspace.CurrentCamera.CFrame.Position=vec(1000);updateEggFX()
assert(not near.Enabled and not closest.Enabled and not far.Enabled,"camera leaving clears all egg motes")
print("PASS: all seven egg/hatch themes; nearest-egg budget, distance cutoff and cleanup")
'''
    return pre + "local Config=" + cfg + "\n" + budget + checks


def fuse_ui_harness():
    source = (ROOT / "src/StarterGui/MainUI/StableUI.luau").read_text(encoding="utf-8-sig")
    begin = source.find("local function fuseGroups(creatures)")
    end = source.find("-- End fuse grouping", begin)
    grouping = source[begin:end] if begin >= 0 else ""
    return '''
local Config={RarityById={Common={index=1},Rare={index=3},Epic={index=4},Legendary={index=5},Mythic={index=6}}}
''' + grouping + '''
local function c(uid,species,rarity,location)
    return {uid=uid,species=species,rarity=rarity,location=location,display=species}
end
local groups,ready=fuseGroups({c("a","Bunny","Common","Pen"),c("b","Bunny","Common","Stable"),
    c("c","Bunny","Common","Stable"),c("d","Bunny","Common","Mount"),c("e","Fox","Epic","Stable"),
    c("f","Fox","Legendary","Stable"),c("g","Fox","Mythic","Pen"),c("h","Bunny","Rare","Stable")})
assert(#groups==3 and ready==1,"mounts/top rarities excluded and different rarities never mixed")
assert(groups[1].count==3 and groups[1].creature.species=="Bunny" and groups[1].creature.rarity=="Common",
    "ready recipes first, combining Pen and Stable while excluding equipped mounts")
assert(groups[2].creature.rarity=="Epic" and groups[3].creature.rarity=="Rare","remaining recipes arranged by rarity")
local empty,n=fuseGroups({});assert(#empty==0 and n==0,"empty inventory has no fuse recipes")
print("PASS: dedicated Fuse recipes use 3 matching species/rarity, exclude mounts and top rarities, sort ready first")
'''


def mama_fx_harness():
    source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Effects.luau").read_text(encoding="utf-8-sig")
    wing = source[source.index("local mamaWing"):source.index("local function syncMama()")]
    # Run the real entrance through its delayed callback with the phase attribute still absent.
    entrance = source[source.index("local entranceToken"):source.index("-- Normal eggs share")]
    pre = r'''
local phase = "active"
local workspace = {GetAttribute=function() return phase end}
local MFX = {wingLoop={123,0.65,0.45},shadowImage="",roar={123,0.62,0.9},whoosh={123,0.75,0.9}}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local sounds, delayed = {}, {}
local Instance={new=function(kind)
    local object={Play=function(self) self.IsPlaying=true end,Destroy=function(self) self.Parent=nil end}
    if kind=="Sound" then table.insert(sounds,object) end
    return object
end}
local function signal()
    local listeners={}
    return {Connect=function(_,fn)
        local connection={connected=true,Disconnect=function(self) self.connected=false end}
        table.insert(listeners,{connection,fn});return connection
    end,Fire=function(_,child)
        for _,row in listeners do if row[1].connected then row[2](child) end end
    end}
end
local function model()
    return {Parent=true,DescendantAdded=signal(),FindFirstChildWhichIsA=function(self) return self.body end}
end
local task={spawn=function(fn) fn() end,delay=function(seconds,fn) table.insert(delayed,fn) end}
local voice=function() return Instance.new("Sound") end
local TweenInfo={new=function() return {} end}
local TweenService={Create=function() return {Play=function() end} end}
local Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
local Color3={new=function() return {} end}
local CFrame={new=function() return setmetatable({},{__mul=function() return {} end}) end,Angles=function() return {} end}
local rumbleUntil=0
'''
    checks = r'''
local dragon=model()
startMamaWing(dragon)
assert(#sounds==0,"a not-yet-replicated body cannot host a wing sound")
local body={IsA=function(_,kind) return kind=="BasePart" end}
dragon.body=body;dragon.DescendantAdded:Fire(body)
assert(#sounds==1 and sounds[1].Parent==body and sounds[1].IsPlaying and sounds[1].Looped,
    "Mama wing loop must start when the body replicates after the model/phase")
dragon.DescendantAdded:Fire(body)
assert(#sounds==1,"later descendants must not duplicate the wing loop")
mamaWing:Destroy();mamaWing=nil
local ended=model();startMamaWing(ended)
phase=nil;ended.body=body;ended.DescendantAdded:Fire(body)
assert(#sounds==1,"a late body must not start wings after Mama ends")
mamaEntrance()
assert(#delayed==1,"warning should schedule an entrance")
delayed[1]()
assert(mamaShadow and mamaShadow.Parent==workspace,
    "warning remote must sweep even if the phase attribute has not replicated yet")
print("PASS: late Mama body starts one wing loop; ended event rejects late body; warning sweep survives delayed phase replication")
'''
    return pre + wing + entrance + checks


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", type=Path, required=True)
    args = parser.parse_args()
    exe = ".exe" if (args.runtime / "luau.exe").exists() else ""
    with tempfile.TemporaryDirectory(prefix="mount-feedback-checks-") as scratch:
        script = Path(scratch) / "feedback.luau"
        script.write_text(harness(), encoding="utf-8")
        subprocess.run([str(args.runtime / ("luau" + exe)), str(script)], check=True)
        script.write_text(visual_harness(), encoding="utf-8")
        subprocess.run([str(args.runtime / ("luau" + exe)), str(script)], check=True)
        script.write_text(mama_harness(), encoding="utf-8")
        subprocess.run([str(args.runtime / ("luau" + exe)), str(script)], check=True)
        for extra in (movement_harness, pen_roam_harness, tutorial_harness, mount_harness, guardian_harness, mama_fx_harness, egg_fx_harness, fuse_ui_harness, gear_harness, touch_buttons_harness, pacing_harness, plaza_harness):
            script.write_text(extra(), encoding="utf-8")
            subprocess.run([str(args.runtime / ("luau" + exe)), str(script)], check=True)
    scripts = sorted((ROOT / "src").rglob("*.luau"))
    subprocess.run([str(args.runtime / ("luau-compile" + exe)), "--null", *map(str, scripts)], check=True, stdout=subprocess.DEVNULL)
    print(f"PASS: compiled {len(scripts)} Luau sources")


if __name__ == "__main__":
    main()
