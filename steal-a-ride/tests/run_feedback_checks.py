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
    Events = {secretOdds={0,0,0,90,9,1}, secretOddsByBiome={}, secretHatch=60, luckyHatch=30},
    LuckyPassChance = 0.1,
    rebirthLuck = function() return 0 end,
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
for _=1,30 do
    assert(HatchService.roll({biome="Forest",species="Fox"},false,false,1).rarity~="Common","rebirth luck 100%: always one rarity up")
end
for i, r in Config.Rarities do r.index = i end
for _, s in Config.Species do s.display = "X" end
local added = {}
CreatureService.add = function(_, c) if CreatureService.full then return nil end table.insert(added, c) return "uid" end
Notify.FireAllClients = function() end
plot.Incubators.Incubator1 = {Timer={Text={Text=""}}}
data.PendingEggs, data.Incubators[1] = {}, false
assert(HatchService.deposit(player, {biome="Forest",species="Fox"}), "fresh egg deposits")
assert(not HatchService.hatch(player, 1) and data.Incubators[1], "an unfinished egg cannot be hatched")
data.Incubators[1].startedAt = 0
CreatureService.full = true
assert(not HatchService.hatch(player, 1) and data.Incubators[1], "a full pen and stable keep the ready egg waiting")
CreatureService.full = false
assert(HatchService.hatch(player, 1) and #added == 1 and data.Incubators[1] == false, "the owner hatches a ready egg into the pen and frees the slot")
assert(not HatchService.hatch(player, 1), "an empty slot cannot hatch twice")
print("PASS: manual hatch waits for the timer, keeps the egg when full, frees the slot once")
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
    rewards = source[source.index("local function hitRewards("):source.index("local function topList(")]
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
local hitRewards=function() end
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
do
    local E={mamaSpeedHits=50,mamaSpeedBoost=1.25,mamaSpeedTime=180,mamaCashHits=75,mamaCashTime=300,mamaEggHits=100}
    local log={}
    local SpeedService={multiply=function(_,_,m,t) table.insert(log,"speed"..m.."/"..t) end}
    local Notify={FireClient=function() end}
    local p={SetAttribute=function(_,k,v) table.insert(log,k) end,GetAttribute=function() return 2 end}
    local HatchService={give=function(_,egg) table.insert(log,"egg:"..egg.biome..tostring(egg.lucky)) end}
    local Config={Biomes={{id="Forest"},{id="Lake"}}}
    local os={time=function() return 1000 end}
""" + rewards + r"""
    hitRewards(p,48,49); assert(#log==0,"no reward below 50 hits")
    hitRewards(p,49,50); assert(log[1]=="speed1.25/180" and #log==1,"50th hit grants 1.25x speed for 3 min")
    hitRewards(p,50,74); assert(#log==1,"speed reward only once")
    hitRewards(p,74,80); assert(log[2]=="CashBoostUntil" and #log==2,"75th hit grants 2x cash")
    hitRewards(p,80,99); assert(#log==2,"no egg below 100 hits")
    hitRewards(p,99,100); assert(log[3]=="egg:Laketrue" and #log==3,"100th hit grants one Lucky Egg of the best biome")
    hitRewards(p,100,300); assert(#log==3,"rewards only once")
    print("PASS: Mama 50/75/100-hit speed, cash and Lucky Egg rewards fire once at their thresholds")
end
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
local workspace={GetServerTimeNow=function() return 1000 end}
local data={SaddleLevel=2}
local DataService={get=function() return data end}
local speedAttrs={}
local player={Parent=true,SetAttribute=function(_,k,v) speedAttrs[k]=v end,Character={FindFirstChildOfClass=function() return {} end}}
"""
    checks=r"""
assert(Config.WalkSpeed==25,"walking starts at 25")
local plan={Forest={22.5,4,.96},Lake={33.75,15,.934},Desert={45,60,.866},Jungle={55,200,.927},Tundra={65,700,.859},Volcano={75,2500,.828},Cosmic={95,8000,.925},
    MysticGrove={110,16000,.927}} -- leash sim 2026-10-09 (tools/pacing-sim/leash-out.txt): first-try rider ~= guardian speed
for _,b in Config.Biomes do
    local want=plan[b.id]
    assert(math.abs(b.guardianSpeed-want[1])<1e-9,b.id.." guardian speed after the 1.25 scale")
    assert(b.baseIncome==want[2],b.id.." lowered base income")
    assert(Config.carryMult({biome=b.id})==want[3],b.id.." normal egg carry weight")
    local secret=Config.carryMult({biome=b.id,secret=true})
    assert(math.abs(secret-want[3]*.909)<1e-9 and secret<=want[3],b.id.." Secret Egg uses the approved Secret weight")
    assert(Config.carryMult({biome=b.id,lucky=true})==want[3],b.id.." Lucky Eggs use the normal weight")
end
assert(Config.Guardian.tiredMult==0.95,"guardians tire less")
assert(Config.Steal.carrierHold==0 and Config.Steal.takeBackHold==0,"stealing from a carrier and taking it back are instant taps")
local hatch={Forest=15,Lake=30,Desert=45,Jungle=68,Tundra=90,Volcano=135,Cosmic=180,MysticGrove=240}
for _,b in Config.Biomes do assert(b.hatchTime==hatch[b.id],b.id.." base hatch time spread x1.5") end
assert(Config.Nests.refillInterval==300 and Config.Nests.forestRefill==nil,"all nests refill together every 5 min")
assert(math.abs(Config.Costs.saddle(10)-100*1.85^10)<1e-6,"saddle price grows 1.85x per level")
assert(Config.Gear.priceSeconds==300 and Config.Gear.minPrice==500,"cash gear costs five minutes of income")
assert(math.abs(Config.Gear.soda.boost-0.10)<1e-9,"Speed Soda is +10%")
assert(math.abs(Config.BiomeById.Forest.mountBase-28.125)<0.001,"mount bases scale with walking")
local riding=Config.mountSpeed({species="Chick",rarity="Common"})
assert(math.abs(riding-30.125)<0.001,"mount base scales while its species bonus stays")
assert(SpeedService.base(player)==27,"saddle still adds to walking speed")
SpeedService.mountSpeedOf=function() return riding end
assert(SpeedService.base(player)==riding+2,"saddle still adds to mount speed")
SpeedService.multiply(player,"soda",1.25,20)
assert(SpeedService.current(player)==(riding+2)*1.25,"soda multiplier survives")
assert(math.abs(speedAttrs.BoostUntil-1020)<0.1,"HUD boost timer ends when the soda does (server time)")
assert(math.abs(speedAttrs.CurrentSpeed-math.floor((riding+2)*1.25*10+.5)/10)<1e-9,"speed pill gets the boosted speed")
SpeedService.multiply(player,"net",0.5,3)
assert(math.abs(speedAttrs.BoostUntil-1020)<0.1,"a slow-down is not a boost and doesn't move the timer")
assert(Config.Gear.buyLimit==5 and Config.Gear.restockSeconds==600,"gear: 5 buys per type, then a 10-minute restock")
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
assert(math.abs(SpeedService.current(carryPlayer)-free*.925*.909)<1e-9,"Cosmic Secret Egg keeps .925 x .909 of free speed")
assert(math.abs(SpeedService.allowed(carryPlayer)-SpeedService.base(carryPlayer)*Config.Abilities.Dash.speedMult*.925*.909)<1e-9,"carrier allowance uses the weighted straight-line maximum")
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
-- one connected loop: always walks forward along its own path, facing where it goes, never cutting across the middle
for seed=1,16 do
    local state=WalkCycle.newPenRoam(seed*104729,1.6)
    local minR, maxR, worst = math.huge, 0, 0
    for tick=1,3600 do
        local x,z=state.x,state.z
        WalkCycle.stepPenRoam(state,1/60,2.5)
        local dx,dz=state.x-x,state.z-z
        local r=math.sqrt(state.x^2+state.z^2)
        minR,maxR=math.min(minR,r),math.max(maxR,r)
        if dx*dx+dz*dz>1e-10 then
            local heading=math.atan2(-dx,-dz)
            worst=math.max(worst,math.abs(math.atan2(math.sin(heading-state.yaw),math.cos(heading-state.yaw))))
        end
    end
    assert(worst<.35,"pets face along their loop instead of sliding sideways or pivoting in place")
    assert(minR>.5 and maxR<=1.6,"the loop circles the pad rather than wandering through its middle")
end
local a,b=WalkCycle.newPenRoam(123,1.6),WalkCycle.newPenRoam(456,1.6)
for i=1,600 do WalkCycle.stepPenRoam(a,1/60,2);WalkCycle.stepPenRoam(b,1/60,2) end
assert(math.abs(a.x-b.x)+math.abs(a.z-b.z)>.1,"different pets should not march in sync")
local x,z,yaw,phase=a.x,a.z,a.yaw,a.phase
WalkCycle.stepPenRoam(a,0,2)
assert(a.x==x and a.z==z and a.yaw==yaw and a.phase==phase,"zero elapsed time cannot move a pet")
print("PASS: Pen roaming walks one smooth connected loop per pet: bounded, faces its path, pauses; slow frames and independent pets")
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
local workspace={Plaza={GearShop={GetPivot=function() return {Position="GearStall"} end},UpgradeShop={GetPivot=function() return {Position="UpgradeStall"} end}}}
local nestPosition=function(id) return id end
local Config={Costs={saddle=function() return 180 end},Plot={joinLock=30}}
local finishedAt
"""
    checks=r"""
local goal,msg=tutorialStep()
assert(msg and not msg:find("Upgrades"),"a player with no pen income should get an earning goal before shopping")
attrs.CashPerSecond=5; goal,msg=tutorialStep()
assert(msg and not msg:find("buy"),"a player below the upgrade price should not be told to buy it")
attrs.Cash=200; goal,msg=tutorialStep()
assert(msg and msg:find("Upgrades") and goal=="UpgradeStall","an affordable Saddle points to Sam's Upgrades stall")
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
local Config={MountSlotRebirth=6,Species={Chick={display="Chick"},Fox={display="Fox",ability="Jump"}},mountSpeed=function(c) return c.speed end}
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
data.Mounts={"a","b"}; data.Rebirths=5
MountService.trim(player)
assert(#data.Mounts==1 and data.Creatures.a and data.Creatures.b,"rebirth 3-5 saves: the 2nd mount returns to the stable, nothing deleted")
data.Mounts={"a","b"}; data.Rebirths=6
MountService.trim(player)
assert(#data.Mounts==2,"the rebirth-6 slot allows two mounts")
Config.Plot={stableSize=1}; local toasts=0
ReplicatedStorage.Remotes.Notify.FireClient=function() toasts+=1 end
CreatureService.stableCount=function() return 1 end
data.Mounts={"a","b"}
assert(MountService.unequip(player,"all")==false and #data.Mounts==2 and toasts==1,"full stable: Get off keeps mounts and says why")
CreatureService.stableCount=function() return 0 end
Config.Plot.stableSize=5; changed=0
assert(MountService.unequip(player,"all") and #data.Mounts==0 and changed==1 and attrs.Riding==nil,"Get off returns every mount and leaves the player on foot")
assert(MountService.unequip(player,"all")==false,"Get off on foot does nothing")
print("PASS: saved mounts trimmed to pass/rebirth slots on join, creatures kept; touch Get off returns all mounts")
"""
    return pre+"local MountService="+mount+checks


def get_off_harness():
    source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.luau").read_text(encoding="utf-8-sig")
    begin = source.index("local function onGetOff")
    end = source.index("local function syncAbilities", begin)
    flight = (ROOT / "src/StarterPlayer/StarterPlayerScripts/FlightController.luau").read_text(encoding="utf-8-sig")
    flight_begin = flight.index("local function action")
    flight_end = flight.index("for _, name in { \"Flying\"", flight_begin)
    return r'''
local Enum={UserInputState={Begin="Begin",End="End",Cancel="Cancel"},
 ContextActionResult={Sink="Sink",Pass="Pass"},KeyCode={R="R",F="F",ButtonY="ButtonY"}}
local riding,focused,sent=nil,nil,0
local player={GetAttribute=function() return riding end,GetAttributeChangedSignal=function() return {Connect=function() end} end}
local UserInputService={TouchEnabled=false,GetFocusedTextBox=function() return focused end}
local Remotes={UnequipMount={FireServer=function(_,who) assert(who=="all");sent+=1 end}}
local bindings={}
local ContextActionService={BindAction=function(_,name,callback,touch,key) bindings[name]={callback=callback,touch=touch,key=key} end,
 UnbindAction=function(_,name) bindings[name]=nil end,SetTitle=function() end,GetButton=function() return {Size={}} end}
local task={delay=function(_,callback) callback() end}
local UDim2={fromOffset=function() return {} end,new=function() return {} end}
local TouchButtons={place=function() end}
''' + source[begin:end] + r'''
assert(not bindings.GetOff,"Get off stays unbound on foot")
riding="Chick";syncGetOff()
assert(bindings.GetOff and bindings.GetOff.key=="F","riding PC player can use F without touch")
bindings.GetOff.callback("GetOff",Enum.UserInputState.Begin)
assert(sent==1,"F sends existing all-mount dismount request once")
bindings.GetOff.callback("GetOff",Enum.UserInputState.End)
assert(sent==1,"key release cannot send another dismount")
focused={}
assert(bindings.GetOff.callback("GetOff",Enum.UserInputState.Begin)==Enum.ContextActionResult.Pass and sent==1,"typing F never dismounts")
focused=nil;UserInputService.TouchEnabled=true;syncGetOff()
assert(bindings.GetOff.touch and bindings.GetOff.key=="F","touch Get off remains available alongside keyboards")
riding=nil;syncGetOff()
assert(not bindings.GetOff,"dismount removes shortcut until riding again")
riding="Chick";syncGetOff()
assert(bindings.GetOff,"remount binds shortcut again")
local Actions,Input=ContextActionService,UserInputService
Actions.SetPosition=function() end
local hint,boundFly,boundFlying={},false,false
local function updateHint() end
local toggles=0
local remote={FireServer=function(_,ability,verb) assert(ability=="Flight" and verb=="toggle");toggles+=1 end}
player.Character={FindFirstChild=function() return {GetAttribute=function() return true end} end,
 FindFirstChildOfClass=function() return {Health=100} end}
player.GetAttribute=function(_,name) if name=="Riding" then return riding end end
''' + flight[flight_begin:flight_end] + r'''
sync()
assert(bindings.RideFlight.key=="R" and bindings.GetOff.key=="F","flying mount has separate flight and Get off keys")
bindings.RideFlight.callback("RideFlight",Enum.UserInputState.Begin)
assert(toggles==1 and sent==1,"flight toggle does not send a dismount request")
focused={}
assert(bindings.RideFlight.callback("RideFlight",Enum.UserInputState.Begin)==Enum.ContextActionResult.Pass and toggles==1,"typing R never toggles flight")
print("PASS: F dismount and R flight use separate keys; one request per press, typing guards, touch preserved and remount lifecycle")
'''


def storm_harness():
    client = (ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.luau").read_text(encoding="utf-8-sig")
    weather = client[client.index("-- Weather:"):client.index("-- Plaza machines")]
    effects = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Effects.luau").read_text(encoding="utf-8-sig")
    sound = effects[effects.index("local thunderToken"):effects.index("local REGIONS")]
    pre = r'''
local objects,threads={},{}
local Instance={new=function(class)
 local obj={ClassName=class,Enabled=true}
 function obj:Destroy()
  for _,child in objects do if child.Parent==self then child:Destroy() end end
  self.Parent=nil
 end
 table.insert(objects,obj);return obj
end}
local function find(parent,class)
 for _,obj in objects do if obj.Parent==parent and obj.ClassName==class then return obj end end
end
local function named(parent,name)
 for _,obj in objects do if obj.Parent==parent and obj.Name==name then return obj end end
end
local function count(parent,class)
 local n=0;for _,obj in objects do if obj.Parent==parent and obj.ClassName==class then n+=1 end end;return n
end
local function vector(x,y,z)
 return setmetatable({X=x,Y=y,Z=z},{__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end})
end
local Vector3={new=vector,zero=vector(0,0,0)}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local Color3={new=function(r,g,b) return {R=r,G=g,B=b} end,fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local NumberRange={new=function(a,b) return {Min=a,Max=b or a} end}
local NumberSequence={new=function(v) return {value=v} end}
local NumberSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
local ColorSequence={new=function(v) return {value=v} end}
local Enum={NormalId={Bottom="Bottom",Top="Top"},ParticleOrientation={VelocityParallel="VelocityParallel",FacingCamera="FacingCamera",FacingCameraWorldUp="FacingCameraWorldUp"},EasingStyle={Quad="Quad"},EasingDirection={Out="Out"}}
local TweenInfo={new=function(...) return {...} end}
local cancels=0
local TweenService={Create=function(_,obj,info,goals)
 return {Play=function() for k,v in goals do obj[k]=v end end,Cancel=function() cancels+=1 end}
end}
local task={spawn=function(fn) local co=coroutine.create(fn);table.insert(threads,co);return co end,wait=function(n) coroutine.yield(n) end}
local sky={MoonAngularSize=11}
local initialAmbient,initialOutdoor=Color3.fromRGB(70,65,60),Color3.fromRGB(80,75,70)
local Lighting={ClockTime=14.5,Ambient=initialAmbient,OutdoorAmbient=initialOutdoor,FindFirstChildOfClass=function(_,class) if class=="Sky" then return sky end end}
local UserInputService={TouchEnabled=false,KeyboardEnabled=true}
local weatherName
local workspace={Terrain={},CurrentCamera={CFrame={Position=vector(10,20,30)}},GetAttribute=function() return weatherName end,
 GetAttributeChangedSignal=function() return {Connect=function() end} end}
local thunder,rainLoop=0,false
local function play(name) assert(name=="Thunder");thunder+=1 end
local SFX,SoundService={},{}
function SFX:FindFirstChild(name) return named(self,name) end
for _,name in {"AmbienceCosmic","AmbienceForest","AmbienceTundra"} do
 local s=Instance.new("Sound");s.Name,s.SoundId,s.Volume,s.Parent=name,"existing://"..name,.2,SFX
 function s:Clone()
  local clone=Instance.new("Sound");clone.SoundId,clone.Volume=self.SoundId,self.Volume;return clone
 end
end
local Config={Sounds={RarityReveal=1841391669},EggFX={themes={Cosmic={sound={9116418035,1.2,.5,3.2}}}}}
local mamaMix={Volume=1}
local loopStates,cues={},{}
local voiceFails=false
local function voice(entry)
 table.insert(cues,entry)
 if voiceFails then return end
 local s=Instance.new("Sound");s.Parent=SoundService;return s
end
local function loop(name,on,volume)
 loopStates[name]=on
 if name=="Rain" then rainLoop=on end
 return SFX:FindFirstChild(name)
end
local function resume(co) local ok,err=coroutine.resume(co);assert(ok,err) end
'''
    checks = r'''
assert(not find(workspace,"Part") and not find(workspace.Terrain,"Clouds"),"clear weather has no storm geometry")
weatherName="Thunderstorm";syncWeather();syncWeatherSound()
local part=find(workspace,"Part")
local drops=part and find(part,"ParticleEmitter")
assert(drops and drops.Texture=="rbxasset://textures/particles/SquareParticle.png" and drops.Squash.value>0,"rain uses thin streaks instead of sparkles")
assert(drops.Orientation=="VelocityParallel" and drops.Rotation.Min==90 and drops.Rate<=500 and drops.Lifetime.Max<=1.4,"rain streaks align vertically within native particle budget")
local clouds=find(workspace.Terrain,"Clouds")
assert(clouds and clouds.Cover>=.9 and clouds.Density>=.75 and clouds.Color.R<.45,"grey storm cloud cover")
assert(Lighting.Ambient.R>initialAmbient.R and Lighting.OutdoorAmbient.R>initialOutdoor.R and weatherTint.Brightness>-.1,"storm keeps the ground readable")
syncWeather()
assert(count(workspace,"Part")==1 and count(workspace.Terrain,"Clouds")==1,"repeated storm sync cannot stack emitters/clouds")
local pendingThunder=threads[#threads]
resume(pendingThunder);resume(pendingThunder)
assert(rainLoop and thunder==0,"lightning precedes thunder")
weatherName="GoldenHour";syncWeather();syncWeatherSound();resume(pendingThunder)
assert(thunder==0 and not rainLoop and cancels>0,"ending storm cancels delayed thunder and lightning fade")
assert(not named(workspace,"RainEmitter") and not find(workspace.Terrain,"Clouds"),"other weather removes rain and clouds")
local lightning
for _,obj in objects do if obj.Name=="StormLightning" then lightning=obj end end
assert(lightning and lightning.Brightness==0,"lightning brightness restored")
UserInputService.TouchEnabled=true;UserInputService.KeyboardEnabled=false
weatherName="Thunderstorm";syncWeather();syncWeatherSound()
assert(find(find(workspace,"Part"),"ParticleEmitter").Rate<=100 and find(workspace,"Part").Size.X<=40,"touch-only rain keeps its density within the mobile emission budget")
local currentThunder=threads[#threads]
resume(currentThunder);resume(currentThunder);resume(currentThunder)
assert(thunder==1,"storm plays thunder after its flash")
weatherName=nil;syncWeather();syncWeatherSound();resume(currentThunder)
assert(thunder==1 and not find(workspace.Terrain,"Clouds"),"no late thunder or clouds after clear weather")
UserInputService.TouchEnabled=false;UserInputService.KeyboardEnabled=true
weatherName="GoldenHour";syncWeather()
local gold=named(workspace,"WeatherMotes")
local rays=named(Lighting,"WeatherSunRays")
assert(gold and Lighting.ClockTime==17.5,"golden sunset and particles")
assert(Lighting.Ambient==initialAmbient and Lighting.OutdoorAmbient==initialOutdoor,"GoldenHour preserves ambient lighting")
assert(rays and rays.Enabled and rays.Intensity==.06,"gentle golden sun rays")
local particles=find(gold,"ParticleEmitter")
assert(particles.Rate*particles.Lifetime.Max<=36 and not gold.CanCollide and not gold.CanQuery and not gold.CanTouch,"desktop motes budget and inert holder")
syncWeather();assert(named(workspace,"WeatherMotes")==gold,"duplicate sync reuses holder")
local follow=threads[#threads]
workspace.CurrentCamera=nil;resume(follow)
workspace.CurrentCamera={CFrame={Position=vector(70,80,90)}};resume(follow)
assert(gold.Position.Y==80,"motes follow replacement camera at flight height")
weatherName="BloodMoon";syncWeather()
assert(gold.Parent==nil and sky.MoonAngularSize==16 and Lighting.ClockTime==21,"blood replaces golden")
assert(Lighting.Ambient.R>initialAmbient.R and Lighting.Ambient.G>initialAmbient.G and Lighting.OutdoorAmbient.R>initialOutdoor.R and Lighting.OutdoorAmbient.G>initialOutdoor.G,"BloodMoon lifts surface visibility without changing its night")
assert(not rays.Enabled,"blood has no sun rays")
resume(follow);assert(coroutine.status(follow)=="dead","old holder follow terminates")
weatherName="Thunderstorm";syncWeather()
assert(not named(workspace,"WeatherMotes") and sky.MoonAngularSize==11 and Lighting.ClockTime==14.5,"storm restores base sky")
assert(Lighting.Ambient.R>initialAmbient.R and Lighting.OutdoorAmbient.R>initialOutdoor.R,"storm replaces the blood fill with its own lift")
weatherName=nil;syncWeather()
assert(not named(workspace,"WeatherMotes") and not rays.Enabled and not named(workspace,"RainEmitter"),"clear removes weather geometry")
UserInputService.TouchEnabled=true;UserInputService.KeyboardEnabled=false
for _,name in {"GoldenHour","BloodMoon"} do
 weatherName=name;syncWeather()
 local holder=named(workspace,"WeatherMotes");local e=find(holder,"ParticleEmitter")
 assert(e.Rate*e.Lifetime.Max<=18 and holder.Size.X==24,"touch-only motes budget")
end
weatherName=nil;syncWeather();UserInputService.KeyboardEnabled=true
weatherName="GoldenHour";syncWeather()
assert(find(named(workspace,"WeatherMotes"),"ParticleEmitter").Rate==12,"hybrid input retains desktop budget")
weatherName="Unknown";syncWeather()
assert(Lighting.ClockTime==14.5 and sky.MoonAngularSize==11 and not rays.Enabled and not named(workspace,"WeatherMotes"),"unknown weather restores baseline")
assert(Lighting.Ambient==initialAmbient and Lighting.OutdoorAmbient==initialOutdoor,"unknown weather restores exact original ambient lighting")
weatherName="BloodMoon";syncWeather();weatherName="GoldenHour";syncWeather()
assert(Lighting.Ambient==initialAmbient and Lighting.OutdoorAmbient==initialOutdoor,"leaving BloodMoon for GoldenHour restores ambient lighting")
weatherName="BloodMoon";syncWeather();weatherName=nil;syncWeather()
assert(Lighting.Ambient==initialAmbient and Lighting.OutdoorAmbient==initialOutdoor,"ending BloodMoon restores ambient lighting")
weatherName="GoldenHour";syncWeatherSound()
assert(loopStates.GoldenWeatherLoop and not loopStates.BloodWeatherLoop and not rainLoop,"golden audio only")
assert(SFX:FindFirstChild("GoldenWeatherLoop") and SFX:FindFirstChild("BloodWeatherLoop"),"independent client ambience aliases exist")
local firstCue,firstCount=weatherCue,#cues
assert(firstCue and firstCue.SoundGroup==mamaMix and cues[firstCount][4]==3,"arrival shares Mama ducking and bounded lifetime")
syncWeatherSound();assert(#cues==firstCount,"identical weather does not replay cue")
weatherName="BloodMoon";syncWeatherSound()
assert(firstCue.Parent==nil and loopStates.BloodWeatherLoop and not loopStates.GoldenWeatherLoop,"blood replaces golden cue/loop")
assert(cues[#cues][2]<cues[firstCount][2],"blood entry tone lower than golden chime")
assert(SFX:FindFirstChild("AmbienceForest").Volume==.2 and SFX:FindFirstChild("AmbienceTundra").Volume==.2,"weather leaves region template volumes unchanged")
weatherName=nil;syncWeatherSound()
assert(not loopStates.GoldenWeatherLoop and not loopStates.BloodWeatherLoop and weatherCue==nil,"clear stops weather audio")
voiceFails=true;weatherName="GoldenHour";syncWeatherSound();assert(weatherCue==nil,"failed optional cue cannot block weather")
print("PASS: storm streaks/clouds/thunder; golden/blood moods, budgets, duplicate sync, camera replacement and cleanup")
'''
    join = pre.replace('local weatherName\n', 'local weatherName="BloodMoon"\n') + weather + sound + '''
assert(Lighting.ClockTime==21 and sky.MoonAngularSize==16 and named(workspace,"WeatherMotes"),"join during BloodMoon initializes visuals")
assert(Lighting.Ambient.R>initialAmbient.R and Lighting.OutdoorAmbient.R>initialOutdoor.R,"join during BloodMoon initializes visibility fill")
assert(loopStates.BloodWeatherLoop and #cues==1,"join during BloodMoon initializes audio once")
syncWeatherSound();assert(#cues==1,"joining active weather does not replay cue")
'''
    no_sky = pre.replace('if class=="Sky" then return sky end', 'if false then return sky end') + weather + '''
weatherName="BloodMoon";syncWeather();assert(named(workspace,"WeatherMotes"),"missing Sky retains particles safely")
weatherName=nil;syncWeather();assert(Lighting.ClockTime==14.5,"missing Sky restores clock safely")
'''
    missing_audio = pre + '''
for _,obj in objects do if obj.Parent==SFX then obj:Destroy() end end
''' + sound + '''
weatherName="GoldenHour";syncWeatherSound();weatherName="BloodMoon";syncWeatherSound()
weatherName=nil;syncWeatherSound();assert(weatherCue==nil,"missing ambience retains safe transition cleanup")
'''
    return "do\n" + pre + weather + sound + checks + "\nend\ndo\n" + join + "\nend\ndo\n" + no_sky + "\nend\ndo\n" + missing_audio + "\nend\n"


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
assert(G.leashBuffer==30,"leash buffer survives a ~0.25 s bump at spider speed (tools/pacing-sim/leash-bumps-out.txt)")
assert(G.burstMult==nil and G.windedMult==nil and G.rageMult==nil and G.rageDistance==nil and G.burstSeconds==nil,"old rage stages removed")
assert(GuardianService.nextPhase==nil and GuardianService.nearHome==nil,"old rage phase helpers removed")
local cf=GuardianService.chaseFactor
local function near(a,b) return math.abs(a-b)<1e-9 end
assert(near(cf(0,false,false),G.patrolSpeedMult),"a chase starts at patrol pace")
assert(cf(5,false,false)==1,"full speed after the wind-up")
assert(near(cf(G.tireAfter+1,false,false),G.tiredMult),"phase 1 still tires")
assert(cf(G.tireAfter+1,true,false)==1,"raging never tires")
local bm=G.bloodMoonMult
assert(near(cf(5,false,false,bm),bm),"Blood Moon speeds phase 1")
assert(cf(5,true,false,bm)==1,"Blood Moon does not boost a raging guardian")
assert(near(cf(5,true,true),G.noLaneSpeedMult),"no-lane penalty still applies")
local lo=GuardianService.leashOffset
assert(lo(3,4,10)==nil,"inside the leash: no snap")
local ox,oz=lo(0,30,10)
assert(near(ox,0) and near(oz,10),"snap keeps the direction, at exactly X")
ox,oz=lo(-30,40,20)
assert(near(ox,-12) and near(oz,16),"diagonal snap at exactly X")
ox,oz=lo(0,0,20)
assert(ox==nil,"on top of the target: nothing to snap")
local sv=GuardianService.snapIsVisible
assert(sv(0,30,10)==true,"a big jump back to X is a visible snap")
assert(sv(0,10+G.snapMin*0.5,10)==false,"a small per-frame leash correction is silent (no puff spam, no re-path)")
local kh=GuardianService.keepHunting
local prey={a=true,b=true}
assert(kh(prey,"a")==true and prey.a==nil and prey.b,"after a catch it keeps hunting the other carriers")
assert(kh(prey,"b")==false,"last carrier caught: it goes home")
local ip=GuardianService.inPhase2
assert(ip(false,"Lake","Lake")==false,"target inside the guardian's biome: phase 1")
assert(ip(false,"Lake","Forest")==true,"target left the biome: phase 2")
assert(ip(false,"Lake",nil)==true,"target in a gap between biomes: phase 2")
assert(ip(true,"Forest",nil)==false and ip(true,"Forest","Lake")==false,"the Chicken never leashes")
local pt=GuardianService.pickTarget
assert(pt("a",{a=50,b=10})=="a","lock-on keeps the current target")
assert(pt("a",{b=30,c=10})=="c","current target gone: nearest remaining carrier")
assert(pt(nil,{})==nil,"nobody left: no target")
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
print("PASS: leash helpers (offset, phase, lock-on), phase-1 tiredness/Blood Moon, rage never tires; sounds; patch warning ramp")
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
local CreatureService={priceIncomeOf=function() return income end} -- prices use the best-pen income
local DataService,SpeedService,ShopService,GuardianService={}, {}, {extraItems={}}, {}
local game={GetService=function() return {Remotes={Notify={}}} end}
"""
    checks=r"""
assert(GearService.price({})==500,"zero income pays the $500 floor")
income=1; assert(GearService.price({})==500,"low income still pays the floor")
income=10; assert(GearService.price({})==3000,"price is five minutes of income")
income=8000.5; assert(GearService.price({})==2400150,"high income: floor(income * 300)")
print("PASS: cash gear costs five minutes of income with a $500 floor")
local data={GearBuys={net={n=5,wait=100},soda={n=3}}}
assert(GearService.buys(data,"net",99).n==5,"sold out until the restock time")
assert(GearService.buys(data,"soda",99).n==3,"under the limit: no wait")
assert(GearService.buys(data,"net",100)==nil and data.GearBuys.net==nil,"restock clears the count")
assert(GearService.buys(data,"trap",0)==nil,"never bought: no record")
print("PASS: gear restock wait ends on time and resets the buy count")
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
    for _,name in {"Dash","RideFlight","RideUp","RideDown","GetOff"} do
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
print("PASS: Dash, flight and Get off touch buttons sit beside the jump button on phones and tablets without overlapping")
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
        'local ProximityPromptService = game:GetService("ProximityPromptService")':'local ProximityPromptService = {}',
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")':'local ReplicatedStorage = {Remotes={Notify={}}}',
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)':'local CreatureBuilder = {}',
        'local Format = require(ReplicatedStorage.Shared.Format)':'local Format = ' + module("ReplicatedStorage/Shared/Format.luau",{}),
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
assert(PlazaService.rebirthText(12)=="12 · Emerald Lord" and PlazaService.rebirthText(1)=="1 · Squire","Most Rebirths rows: count and title")
assert(PlazaService.indexCount({Fox_Rare=true,Fox_Epic=true,Chick_Common=true})==3 and PlazaService.indexCount(nil)==0,"Top Collectors counts Index entries")
assert(PlazaService.collectorText(1)=="1 entry" and PlazaService.collectorText(26)=="26 entries","Top Collectors rows")
print("PASS: Plaza showcase picks rarest per owner then fills; chest pays 10 min of income (min $1000) every 4 h; rebirth rows with titles; Top Collectors")
"""
    return pre+"local Config="+cfg+"\nlocal PlazaService="+mod+checks


def top_players_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    fmt=module("ReplicatedStorage/Shared/Format.luau",{})
    mod=module("ServerScriptService/Services/TopPlayersService.luau",{
        'local Players = game:GetService("Players")':'local Players = {}',
        'local PhysicsService = game:GetService("PhysicsService")':'local PhysicsService = {}',
        'local DataStoreService = game:GetService("DataStoreService")':'local DataStoreService = {}',
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")':'local ReplicatedStorage = {}',
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local Format = require(ReplicatedStorage.Shared.Format)':'',
        'local DataService = require(script.Parent.DataService)':'local DataService = {}',
        'local CreatureService = require(script.Parent.CreatureService)':'local CreatureService = {}'})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
"""
    checks=r"""
local T=TopPlayersService
local function e(key,r,i,inc,o) return {key=key,rebirths=r,index=i,income=inc,order=o} end
local top=T.rank({e("a",9,99,5,1),e("b",0,1,50,2),e("c",1,1,20,3),e("d",0,0,1,4)})
assert(#top==3 and top[1].key=="b" and top[2].key=="c" and top[3].key=="a","income first; only 3 shown")
top=T.rank({e("a",1,9,10,1),e("b",2,1,10,2)})
assert(#top==2 and top[1].key=="b" and top[2].key=="a","same income: more rebirths first; 2 players fill 2 cards")
top=T.rank({e("a",1,5,10,1),e("b",1,6,10,2)})
assert(top[1].key=="b","same income and rebirths: higher index first")
top=T.rank({e("a",1,5,10,2),e("b",1,5,10,1)})
assert(top[1].key=="b","full tie: lower order first")
assert(#T.rank({})==0,"nobody: empty board")
local input={e("a",1,1,1,1),e("b",2,1,1,2)}
T.rank(input)
assert(input[1].key=="a","rank never reorders the caller's list")
assert(T.indexCount({Fox_Rare=true,Fox_Epic=true,Chick_Common=true})==3 and T.indexCount(nil)==0,"index count = discovered species+rarity combos")
local t=T.cardText({name="KuroZen",rebirths=20,index=318,income=126400000})
assert(t.name=="KuroZen" and t.title=="Divine Overlord" and t.index=="Index 318" and t.income=="$126.40M/s","card rows: name, title, index, income")
assert(T.cardText({name="New",rebirths=1,index=0,income=0}).title=="Squire","0-1 rebirths: Squire")
assert(T.cardText({name="Old",rebirths=14,index=0,noIndex=true,income=5}).index=="","offline player with no saved info: index row left blank")
assert(Config.TopPlayers.refresh==3 and Config.TopPlayers.retry==30 and Config.TopPlayers.waiting=="Waiting for a challenger","board settings")
print("PASS: Top Players rank (income > rebirths > index > order, top 3), index count, card text")
"""
    return pre+"local Config="+cfg+"\nlocal Format="+fmt+"\nlocal TopPlayersService="+mod+checks

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


def guardian_fx_harness():
    cfg = module("ReplicatedStorage/Shared/Config.luau", {})
    source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Effects.luau").read_text(encoding="utf-8-sig")
    begin = source.find("local function guardianTier(")
    end = source.find("-- End guardian tier", begin)
    tier = source[begin:end] if begin >= 0 else ""
    pre = r'''
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local function model(attrs) return {GetAttribute=function(_,k) return attrs[k] end} end
'''
    checks = r'''
local FX=Config.GuardianFX
assert(FX and FX.distance>0,"guardian FX has a draw distance")
for _,key in {"rate","size","light"} do
    local t=FX.tiers[key]
    assert(#t==4 and t[1]==1,key.." scales over four tiers starting at 1")
    for i=2,4 do assert(t[i]>t[i-1],key.." grows with danger") end
end
for _,b in Config.Biomes do
    local s=FX.guardians[b.id]
    assert(s and #s.layers>0 and s.step and s.step.count>0,b.id.." guardian has an aura and a step burst")
    for _,l in s.layers do
        assert(l.texture~="" and l.rate>=0 and l.life>0 and (l.minTier or 1)<=4,b.id.." layer is complete")
    end
end
assert(guardianTier(model({}))==1,"patrolling = tier 1")
assert(guardianTier(model({OutOfBiome=true}))==1,"walking home outside its biome stays calm")
assert(guardianTier(model({ChaseTarget=1}))==2,"chasing in its biome = tier 2")
assert(guardianTier(model({ChaseTarget=1,OutOfBiome=true}))==3,"chasing outside its biome = tier 3")
assert(guardianTier(model({ChaseTarget=1,Raging=true}))==4,"enraged = tier 4")
assert(guardianTier(model({ChaseTarget=1,OutOfBiome=true,Raging=true}))==4,"rage wins over out-of-biome")
print("PASS: seven guardian signatures; patrol/chase/out-of-biome/rage tiers")
'''
    return pre + "local Config=" + cfg + "\n" + tier + checks


def fuse_ui_harness():
    source = (ROOT / "src/StarterGui/MainUI/StableUI.luau").read_text(encoding="utf-8-sig")
    begin = source.find("local function fuseGroups(creatures)")
    end = source.find("-- End fuse grouping", begin)
    grouping = source[begin:end] if begin >= 0 else ""
    render = source[source.index("local function renderFuse(inv)"):source.index("local refreshing, refreshAgain")]
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
''' + """
local fusePanel={}
local pendingText={}
local spinning={[fusePanel]={}}
local fuseList={GetChildren=function() return {} end}
local fuseActions={}
local fuseEmpty={}
local function syncFuseLocation() end
""" + render + """
renderFuse({creatures={}})
assert(fuseEmpty.Visible,"empty inventory renders without a removed Menu button")
print("PASS: dedicated Fuse recipes use 3 matching species/rarity, exclude mounts and top rarities, sort ready first; empty refresh works")
"""


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


def base_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    mod=module("ServerScriptService/Services/BaseService.luau",{
        'local HttpService = game:GetService("HttpService")':'local HttpService = {JSONEncode=function() return "{}" end}',
        'local Players = game:GetService("Players")':'local Players = {}',
        'local Debris = game:GetService("Debris")':'local Debris = {}',
        'local SoundService = game:GetService("SoundService")':'local SoundService = {}',
        'local TweenService = game:GetService("TweenService")':'local TweenService = {}',
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")':'',
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)':'local CreatureBuilder = {}',
        'local DataService = require(script.Parent.DataService)':'local DataService = {get=function() return data end}',
        'local PlotService = require(script.Parent.PlotService)':'local PlotService = {get=function() return nil end}'})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local data={Cash=0,Rebirths=0,Base={owned={},equipped={}}}
local workspace={HomeRow={Plots={GetChildren=function() return {} end}}}
"""
    checks=r"""
local tiers={}
for _,r in {0,1,2,3,5,6,9,10,99} do table.insert(tiers,Config.baseTier(r)) end
assert(table.concat(tiers,",")=="1,2,2,3,3,4,4,5,5","base tiers unlock at rebirth 0/1/3/6/10")
assert(BaseService.price(data,"nope")==nil,"unknown items are not for sale")
assert(BaseService.price(data,"colorDefault")==0 and BaseService.price(data,"seatingNone")==0,"defaults are free")
assert(BaseService.price(data,"colorOcean")==2500,"unowned items cost their price")
assert(BaseService.equipped(data,"plants")=="plantsNone" and BaseService.equipped(nil,"color")=="colorDefault","empty slots show the free default")
local Shop={extraItems={}}
BaseService.start(Shop)
local cost,apply=Shop.extraItems["base:colorOcean"](nil,data)
assert(cost==2500,"shop charges the item price")
apply()
assert(data.Base.owned.colorOcean and data.Base.equipped.color=="colorOcean","buying owns and equips")
assert(BaseService.price(data,"colorOcean")==0,"owned items re-equip for free")
local _,equipDefault=Shop.extraItems["base:colorDefault"](nil,data)
equipDefault()
assert(data.Base.equipped.color=="colorDefault" and data.Base.owned.colorDefault==nil and data.Base.owned.colorOcean,"switching back keeps the bought item")
data.Base.equipped.color="removedItem"
assert(BaseService.equipped(data,"color")=="colorDefault","a stale saved id falls back to the default")
local slots={}
for _,item in Config.Base.items do slots[item.slot]=(slots[item.slot] or 0)+(item.price==0 and 1 or 0) end
for _,slot in Config.Base.slots do assert(slots[slot.id]==1,"every slot has exactly one free default: "..slot.id) end
print("PASS: base tiers by rebirth; cosmetics priced, bought once, re-equip free, one free default per slot")
"""
    return pre+"local Config="+cfg+"\nlocal BaseService="+mod+checks


def rebirth_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    mod=module("ServerScriptService/Services/RebirthService.luau",{
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")':'',
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local Format = require(ReplicatedStorage.Shared.Format)':'',
        'local DataService = require(script.Parent.DataService)':'',
        'local CreatureService = require(script.Parent.CreatureService)':'',
        'local HatchService = require(script.Parent.HatchService)':'',
        'local MountService = require(script.Parent.MountService)':'',
        'local ShopService = require(script.Parent.ShopService)':''})
    fmt=module("ReplicatedStorage/Shared/Format.luau",{})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local game={GetService=function() return {} end}
local toasts={}
local ReplicatedStorage={Remotes={Notify={FireClient=function(_,_,_,msg) table.insert(toasts,msg) end},Rebirth={}}}
local data
local DataService={get=function() return data end,save=function() end}
local CreatureService={changed=function() end}
local eggs={}
local HatchService={onPlayerReady=function() end,give=function(_,egg) table.insert(eggs,egg) end}
local MountService={apply=function() end}
local ShopService={sync=function() end}
local attrs={BestBiome=7}
local player={GetAttribute=function(_,k) return attrs[k] end,SetAttribute=function(_,k,v) attrs[k]=v end}
"""
    checks=r"""
assert(Config.MaxRebirths==20 and Config.rebirth(21)==nil,"20 rebirths, none after")
local prev=0
for n=1,20 do local r=Config.rebirth(n); assert(r and r.cash>prev,"costs rise every rebirth "..n); prev=r.cash end
assert(Config.rebirth(1).cash==1e5 and Config.rebirth(10).cash==3e9 and Config.rebirth(20).cash==1.23e10,"simulated cost curve")
assert(Config.rebirth(3).reward=="incubator" and Config.rebirth(6).reward=="mount","mount slot moved from 3 to 6")
assert(Config.rebirth(10).reward=="luck" and Config.rebirth(20).reward=="luck","luck rewards at 10 and 20")
for n=11,19 do assert(Config.rebirth(n).reward=="lucky","R11-R19 give a Lucky Egg") end
assert(Config.MountSlotRebirth==6,"free 2nd mount slot at rebirth 6")
assert(Config.rebirthKeep(1)==1 and Config.rebirthKeep(3)==1 and Config.rebirthKeep(4)==2 and Config.rebirthKeep(8)==3 and Config.rebirthKeep(20)==6,"keep 1, +1 every 4 rebirths")
assert(Config.rebirthLuck(0)==0 and Config.rebirthLuck(9)==0 and Config.rebirthLuck(10)==0.05 and Config.rebirthLuck(19)==0.05 and Config.rebirthLuck(20)==0.10,"rebirth luck 5% at 10, 10% at 20")
assert(Config.rebirthTitle(0)=="Squire" and Config.rebirthTitle(1)=="Squire" and Config.rebirthTitle(2)=="Lesser Lord" and Config.rebirthTitle(3)=="Lesser Lord"
    and Config.rebirthTitle(10)=="Platinum Lord" and Config.rebirthTitle(20)=="Divine Overlord","a title every 2 rebirths")
local fixed=100*1.85^10
assert(Config.Costs.saddle(10)==fixed and Config.Costs.saddle(10,0)==fixed and Config.Costs.saddle(10,10)==fixed,"low income: today's saddle price")
assert(math.abs(Config.Costs.saddle(10,1e9)-1e9*8*1.15^10)<1,"late game: saddle costs 8 s of income x1.15^level")
local function same(a,b) for i=1,5 do if math.abs(a[i]-b[i])>1e-12 then return false end end return true end
local function sum(o) local s=0 for i=1,5 do s+=o[i] end return s end
assert(same(Config.hatchOdds(false,false,0),Config.hatchOdds()) and same(Config.hatchOdds(true,true,nil),Config.hatchOdds(true,true)),"no rebirth luck: odds unchanged")
assert(math.abs(sum(Config.hatchOdds(true,true,0.10))-1)<1e-9,"odds with pass + rebirth luck still sum to 100%")
local base=Config.hatchOdds(false,false,0.05)
assert(base[1]<Config.hatchOdds()[1] and base[5]>Config.hatchOdds()[5],"rebirth luck moves odds up")
local LP=Config.LuckyPassChance; Config.LuckyPassChance=0.15
local passOnly=Config.hatchOdds(false,true); Config.LuckyPassChance=LP
assert(same(Config.hatchOdds(false,true,0.05),passOnly),"pass 10% + rebirth 5% = one 15% up-chance (matches roll)")
local sp=Config.Biomes[#Config.Biomes].species[1]
local function fresh(rebirths,inc,pen)
    data={Rebirths=rebirths,Cash=1e12,Mounts={"m1","m2"},Pen={"p1"},PendingEggs={},Incubators={},IncubatorCount=inc,PenSlots=pen,SaddleLevel=3,Gear={},
        Creatures={m1={species=sp,rarity="Common"},m2={species=sp,rarity="Rare"},p1={species=sp,rarity="Epic"},s1={species=sp,rarity="Common"}}}
    table.clear(eggs); table.clear(toasts)
end
-- rebirth 1 (keep 1), no pick sent: the first ridden creature stays
fresh(0,2,6)
assert(RebirthService.rebirth(player),"rebirth 1 works")
assert(data.Creatures.m1 and not data.Creatures.m2 and not data.Creatures.p1 and not data.Creatures.s1,"default keeps ridden creatures up to the limit")
assert(#data.Mounts==1 and data.Mounts[1]=="m1" and #data.Pen==0 and data.IncubatorCount==3 and #eggs==0,"unkept mounts dropped, incubator reward given, no egg")
-- rebirth 4 (keep 2): pick a pen and a stable creature instead of the mounts
fresh(3,6,6)
assert(RebirthService.rebirth(player,{"p1","s1"}),"rebirth 4 with a pick works")
assert(data.Creatures.p1 and data.Creatures.s1 and not data.Creatures.m1 and #data.Mounts==0,"picked creatures stay, unpicked mounts go")
-- the base expansion survives rebirth (spec 2026-10-10)
fresh(9,6,20); data.BaseExpanded=true
assert(RebirthService.rebirth(player) and data.Rebirths==10 and data.BaseExpanded==true,"the base expansion is kept through rebirth")
-- too many picks or bogus uids
fresh(2,6,6)
assert(not RebirthService.rebirth(player,{"m1","m2","p1"}) and data.Rebirths==2 and data.Creatures.s1,"over the limit is refused and nothing resets")
fresh(0,2,6)
assert(RebirthService.rebirth(player,{"nope"}) and next(data.Creatures)==nil,"unknown uids keep nothing")
-- capped rewards become a Lucky Egg of the best biome
fresh(3,6,20) -- rebirth 4 = incubator, already 6
assert(RebirthService.rebirth(player) and data.IncubatorCount==6 and #eggs==1 and eggs[1].lucky and eggs[1].biome==Config.Biomes[7].id,"maxed incubator reward gives a Lucky Egg")
fresh(4,6,20) -- rebirth 5 = pen, already 20
assert(RebirthService.rebirth(player) and data.PenSlots==20 and #eggs==1,"maxed pen reward gives a Lucky Egg")
fresh(4,6,19)
assert(RebirthService.rebirth(player) and data.PenSlots==20 and #eggs==0,"a partly used pen reward is not replaced")
-- R11-R19: always a Lucky Egg
fresh(10,6,20)
assert(RebirthService.rebirth(player) and #eggs==1 and eggs[1].lucky,"rebirth 11 gives a Lucky Egg")
-- R10: luck, no egg, the toast says so
fresh(9,6,20)
assert(RebirthService.rebirth(player) and #eggs==0,"rebirth 10 gives luck, not an egg")
local said=table.concat(toasts," | ")
assert(said:find("5%% of hatches",1,false) and said:find("Platinum Lord",1,true),"rebirth 10 toast names the luck and the new title")
-- titles: a toast only when the title changes
fresh(1,2,6)
assert(RebirthService.rebirth(player) and table.concat(toasts," | "):find("You are now a Lesser Lord!",1,true),"rebirth 2: first title")
fresh(2,2,6)
assert(RebirthService.rebirth(player) and not table.concat(toasts," | "):find("You are now",1,true),"rebirth 3 keeps the same title: no title toast")
fresh(3,6,6)
assert(RebirthService.rebirth(player) and table.concat(toasts," | "):find("You are now an Iron Lord!",1,true),"an before a vowel")
-- R6: mount slot reward, nothing else given
fresh(5,6,20)
assert(RebirthService.rebirth(player) and #eggs==0 and data.IncubatorCount==6,"rebirth 6 gives the mount slot only")
-- Species Mastery
local index={}
for i,r in Config.Rarities do if i<#Config.Rarities then index[sp.."_"..r.id]=true end end
local c={species=sp,rarity="Common"}
assert(not Config.mastered(index,sp) and Config.income(c,0,index)==Config.income(c,0),"5 of 6 rarities: no mastery")
index[sp.."_Mythic"]=true
assert(Config.mastered(index,sp) and math.abs(Config.income(c,0,index)-Config.income(c,0)*1.25)<1e-6,"all 6: +25% income")
assert(Config.income(c,0,nil)==Config.income(c,0,{}),"no index = no mastery")
-- keep fee: 1 h of what the kept creatures earn after the rebirth
local m1={species=sp,rarity="Common"}
assert(Config.rebirthKeepFee({},3,nil)==0,"keeping nothing: no fee")
assert(Config.rebirthKeepFee({m1},3,nil)==math.floor(Config.income(m1,3)*3600),"fee = 3600 s of the kept creature's post-rebirth income")
fresh(0,2,6); data.Cash=Config.rebirth(1).cash
assert(not RebirthService.rebirth(player,{"m1"}) and data.Rebirths==0 and data.Creatures.m2,"cash for the rebirth but not the fee: refused, nothing resets")
assert(table.concat(toasts," | "):find("Keeping these creatures costs",1,true),"the toast names the fee")
fresh(0,2,6); data.Cash=Config.rebirth(1).cash
assert(RebirthService.rebirth(player,{}) and data.Rebirths==1,"keeping nothing needs only the rebirth cash")
fresh(0,2,6); data.Cash=Config.rebirth(1).cash+Config.rebirthKeepFee({data.Creatures.m1},1,nil)
assert(RebirthService.rebirth(player,{"m1"}) and data.Creatures.m1,"rebirth cash + fee: allowed")
print("PASS: 20 rebirths, keep 1 +1 per 4, mount slot at 6, luck 10/20, Lord titles, income saddle; keep picker + keep fee; capped rewards give a Lucky Egg; Species Mastery")
"""
    return pre+"local Config="+cfg+"\nlocal Format="+fmt+"\nlocal RebirthService="+mod+checks


def whats_new_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    mod=module("ServerScriptService/Services/RetentionService.luau",{
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")':'',
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local DataService = require(script.Parent.DataService)':'',
        'local CreatureService = require(script.Parent.CreatureService)':'',
        'local HatchService = require(script.Parent.HatchService)':''})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local game={GetService=function() return {JSONEncode=function() return "{}" end} end}
local ReplicatedStorage={Remotes={Notify={},ClaimDaily={},TipSeen={}}}
local data
local DataService={get=function() return data end,addCash=function() end}
local CreatureService={incomeOf=function() return 0 end}
local HatchService={readyCount=function() return 0 end}
local attrs
local player={GetAttribute=function(_,k) return attrs[k] end,SetAttribute=function(_,k,v) attrs[k]=v end}
"""
    checks=r"""
local W=Config.WhatsNew
assert(#W>0,"at least one update")
for i,u in W do
    assert(type(u.version)=="number" and u.title and #u.lines>0,"update "..i.." has a version, title and lines")
    assert(i==1 or u.version>W[i-1].version,"updates are listed oldest first with rising versions")
end
local v=W[#W].version
assert(v==5 and W[#W].title=="Top players","latest update is v5 Top players")
local since=Config.updatesSince
assert(#since(nil)==#W and #since(0)==#W,"never seen anything: every update")
assert(#since(v)==0,"seen the latest: nothing")
local fake={{version=1,title="a",lines={"x"}},{version=2,title="b",lines={"y"}},{version=3,title="c",lines={"z"}}}
local missed=since(1,fake)
assert(#missed==2 and missed[1].version==3 and missed[2].version==2,"missed two updates: both, newest first")
local function join(lastOnline) attrs={} RetentionService.onPlayerReady(player,lastOnline) return attrs.WhatsNew end
data={Tips={},LuckUntil=0,DailyStreak=0,LastDaily=0}
assert(join(os.time()-30)==0 and data.SeenUpdate==v,"returning player who never saw notes is sent 'seen 0': gets every update once")
assert(join(os.time()-30)==nil,"not again on the next join")
data.SeenUpdate=v-1
assert(join(os.time()-30)==v-1 and data.SeenUpdate==v,"client is told the last version seen, so it shows everything newer")
data={Tips={},LuckUntil=0,DailyStreak=0,LastDaily=0}
assert(join(0)==nil and data.SeenUpdate==v,"brand-new players skip the notes and never see this version")
print("PASS: What's New shows every missed update once to returning players, newest first, never to brand-new ones")
"""
    return pre+"local Config="+cfg+"\nlocal RetentionService="+mod+checks


def legacy_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    mod=module("ServerScriptService/Services/DataService.luau",{
        'local DataStoreService = game:GetService("DataStoreService")':'',
        'local Config = require(game:GetService("ReplicatedStorage").Shared.Config)':''})
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local stores={StealARide_v2={},StealARide_v1={}}
local failOld=false
local DataStoreService={GetDataStore=function(_,name) return {GetAsync=function(_,key)
    if name=="StealARide_v1" and failOld then error("outage") end
    return stores[name][key] end} end}
local warn=function() end
local function P(id) return {UserId=id,Name="p"..id,SetAttribute=function() end} end
"""
    checks=r"""
local function sp(biome) return Config.BiomeById[biome].species[1] end
stores.StealARide_v1.u_1={Creatures={a={species=sp("Forest")},b={species=sp(Config.Biomes[4].id)},c={species="Removed"}}}
stores.StealARide_v1.u_2={Cash=10}
local d=DataService.load(P(1))
assert(d.OG and d.LegacyGift==4 and d.LegacyChecked,"old save: OG, gift = best old biome (unknown species ignored)")
d=DataService.load(P(2))
assert(d.OG and d.LegacyGift==1,"old save without creatures: Forest egg")
d=DataService.load(P(3))
assert(not d.OG and not d.LegacyGift and d.LegacyChecked,"new player: no OG")
failOld=true
d=DataService.load(P(4))
assert(not d.LegacyChecked and not d.OG,"failed legacy read is retried next join")
stores.StealARide_v2.u_5={LegacyChecked=true,OG=true,LegacyGift=false}
stores.StealARide_v1.u_5={Cash=1}
failOld=false
d=DataService.load(P(5))
assert(d.OG and d.LegacyGift==false,"already granted: no second gift")
print("PASS: OG check (pre-reset save -> tag + one gift, retried on outage)")
"""
    return pre+"local Config="+cfg+"\nlocal DataService="+mod+checks


def expansion_harness():
    cfg=module("ReplicatedStorage/Shared/Config.luau",{})
    checks=r"""
-- Task 1: price, limits, slot prices
assert(Config.expansionPrice(0)==50e9 and Config.expansionPrice(2e6)==50e9,"lot price floor $50B")
assert(Config.expansionPrice(1e7)==1e7*21600,"lot price = 6 h of price income above the floor")
assert(Config.penMax(false)==20 and Config.penMax(true)==30 and Config.penMax(nil)==20,"pen limit")
assert(Config.incubatorMax(false)==6 and Config.incubatorMax(true)==8,"incubator limit")
assert(Config.Costs.penSlot(20)==250*3^13,"slots 7-20 unchanged")
assert(math.abs(Config.Costs.penSlot(21)-1.75e9)<1 and math.abs(Config.Costs.penSlot(30)-1.75e9*1.5^9)<1,"slots 21-30")
local total=0 for s=21,30 do total+=Config.Costs.penSlot(s) end
assert(total>190e9 and total<205e9,"all ten ~ $200B")
assert(Config.Costs.incubators[7]==10e9 and Config.Costs.incubators[8]==20e9,"incubators 7/8")
assert(Config.Plot.maxPen==20 and Config.Plot.maxIncubators==6,"pass caps stay at the base limits")
print("PASS: base expansion price, limits and slot prices")
"""
    shop_src=(ROOT/"src/ServerScriptService/Services/ShopService.luau").read_text(encoding="utf-8-sig")
    shop_items=shop_src[shop_src.index("local ITEMS = {"):shop_src.index("function ShopService.start()")]
    shop_checks=r"""
-- Task 2: Sam's pen/incubator limits follow the lot
local sdata={PenSlots=20,IncubatorCount=6,Cash=1e12,BaseExpanded=false,SaddleLevel=0}
local DataService={get=function() return sdata end,addCash=function(_,n) sdata.Cash+=n end}
local CreatureService={priceIncomeOf=function() return 0 end,changed=function() end}
local HatchService={onPlayerReady=function() end}
local SpeedService={refresh=function() end}
local sattrs={}
local splayer={SetAttribute=function(_,k,v) sattrs[k]=v end}
local ShopService={extraItems={},sync=function() end}
"""+shop_items+r"""
assert(ShopService.buy(splayer,"pen")==false and sdata.PenSlots==20,"pen slot 21 needs the lot")
assert(ShopService.buy(splayer,"incubator")==false and sdata.IncubatorCount==6,"incubator 7 needs the lot")
sdata.BaseExpanded=true
local before=sdata.Cash
assert(ShopService.buy(splayer,"pen") and sdata.PenSlots==21 and math.abs(before-sdata.Cash-1.75e9)<1,"slot 21 costs $1.75B")
before=sdata.Cash
assert(ShopService.buy(splayer,"incubator") and sdata.IncubatorCount==7 and before-sdata.Cash==10e9,"incubator 7 costs $10B")
sdata.PenSlots=30; sdata.IncubatorCount=8
assert(ShopService.buy(splayer,"pen")==false and ShopService.buy(splayer,"incubator")==false,"30 / 8 is the top")
print("PASS: Sam sells slots 21-30 and incubators 7-8 only after the lot")
"""
    ui_src=(ROOT/"src/StarterGui/MainUI/ShopUI.luau").read_text(encoding="utf-8-sig")
    ui_items=ui_src[ui_src.index("local lotLocked"):ui_src.index("local rows = {}")]
    ui_checks=r"""
-- Task 2: Sam's rows show the lot lock
local uattrs={PenSlots=20,IncubatorCount=6,BaseExpanded=false,Rebirths=12}
local player={GetAttribute=function(_,k) return uattrs[k] end}
local workspace={GetServerTimeNow=function() return 0 end}
"""+ui_items+r"""
local rowOf={} for _,it in ITEMS do rowOf[it.id]=it end
local desc,cost,locked=rowOf.pen.info()
assert(locked=="LOCKED" and desc:find("Needs the base expansion %(Rebirth 10%)"),"pen row locked without the lot")
desc,cost,locked=rowOf.incubator.info()
assert(locked=="LOCKED" and desc:find("Needs the base expansion"),"incubator row locked without the lot")
uattrs.BaseExpanded=true
desc,cost,locked=rowOf.pen.info()
assert(locked==nil and math.abs(cost-1.75e9)<1 and desc:find("20/30"),"pen row sells slot 21 after the lot")
desc,cost,locked=rowOf.incubator.info()
assert(locked==nil and cost==10e9 and desc:find("6/8"),"incubator row sells #7 after the lot")
uattrs.PenSlots=10; uattrs.BaseExpanded=false
desc,cost,locked=rowOf.pen.info()
assert(locked==nil and desc:find("10/20"),"below the base limit nothing changes")
print("PASS: Sam's rows say LOCKED until the base expansion, then sell up to 30 / 8")
"""
    steal_src=(ROOT/"src/ServerScriptService/Services/StealService.luau").read_text(encoding="utf-8-sig")
    inside=steal_src[steal_src.index("local function onFloor"):steal_src.index("local insidePlot = StealService.insidePlot")]
    inside_checks=r"""
-- Task 3: the lot counts as inside the base only once bought
local V={} V.__index=V
V.__sub=function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},V) end
local function v(x,y,z) return setmetatable({X=x,Y=y,Z=z},V) end
local StealService={}
"""+inside+r"""
assert(StealService.insidePlot,"StealService.insidePlot is exported")
local expanded=false
local plot={Floor={Position=v(-50,0,105),Size=v(58,1,58)},Expansion={Floor={Position=v(-95,0,105),Size=v(28,1,58)}},
    GetAttribute=function(_,k) if k=="Expanded" then return expanded end end}
assert(StealService.insidePlot(plot,v(-50,3,105)),"base floor is inside")
assert(not StealService.insidePlot(plot,v(-95,3,105)),"the lot is outside before it is bought")
expanded=true
assert(StealService.insidePlot(plot,v(-95,3,105)),"the bought lot is inside")
assert(StealService.insidePlot(plot,v(-50,3,105)),"base floor still inside")
assert(not StealService.insidePlot(plot,v(-120,3,105)) and not StealService.insidePlot(plot,v(-95,3,40)),"beyond the lot is outside")
plot.Expansion=nil
assert(not StealService.insidePlot(plot,v(-95,3,105)),"a plot without lot parts never counts the strip")
print("PASS: the base expansion counts as inside the base once bought")
"""
    exp_path=ROOT/"src/ServerScriptService/Services/ExpansionService.luau"
    exp=module("ServerScriptService/Services/ExpansionService.luau",{
        'local Players = game:GetService("Players")':'',
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")':'',
        'local Config = require(ReplicatedStorage.Shared.Config)':'',
        'local Format = require(ReplicatedStorage.Shared.Format)':'',
        'local DataService = require(script.Parent.DataService)':'',
        'local CreatureService = require(script.Parent.CreatureService)':'',
        'local PlotService = require(script.Parent.PlotService)':'',
        'local ShopService = require(script.Parent.ShopService)':'',
        'local HatchService = require(script.Parent.HatchService)':''}) if exp_path.exists() else "nil"
    exp_checks=r"""
-- Task 5: ExpansionService (sign, buy, locked/bought state)
local Format={number=function(n) return tostring(n) end}
local V3={} V3.__index=V3
V3.__sub=function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},V3) end
local function v3(x,y,z) return setmetatable({X=x,Y=y,Z=z},V3) end
local CFrame={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
local edata={Rebirths=10,Cash=0}
local DataService={get=function() return edata end,addCash=function(_,n) edata.Cash+=n end}
local CreatureService={priceIncomeOf=function() return 0 end,changed=function() end}
local HatchService={onPlayerReady=function() end}
local ShopService={sync=function() end}
local Players={GetPlayers=function() return {} end}
local Notify={FireClient=function() end}
local ReplicatedStorage={Remotes={Notify=Notify}}
local function inst(name,class,props,kids)
    local o={Name=name,ClassName=class,_kids=kids or {},_attrs={}}
    for k,v in props or {} do o[k]=v end
    for _,c in o._kids do o[c.Name]=c end
    function o:GetChildren() return self._kids end
    function o:GetDescendants() local t={} for _,c in self._kids do table.insert(t,c) for _,d in c:GetDescendants() do table.insert(t,d) end end return t end
    function o:FindFirstChild(n) return self[n] ~= nil and type(self[n])=="table" and self[n]._kids and self[n] or nil end
    function o:FindFirstChildWhichIsA(c) for _,k in self._kids do if k:IsA(c) then return k end end end
    function o:IsA(c) return c==class or (c=="BasePart" and class=="Part") or (c=="Light" and class=="PointLight") end
    function o:Destroy() self.Destroyed=true end
    function o:GetBoundingBox() return self.BoxCF, self.BoxSize end
    function o:GetAttribute(k) return self._attrs[k] end
    function o:SetAttribute(k,v) self._attrs[k]=v end
    return o
end
local function part(name,props,kids) return inst(name,"Part",props or {Transparency=0,CanCollide=true},kids) end
local label=inst("Line1","TextLabel",{Text=""})
local board=inst("Board","SurfaceGui",{Enabled=true},{label})
local prompt=inst("ExpansionPrompt","ProximityPrompt",{Enabled=true})
local sign=part("Sign",{Transparency=0,CanCollide=true},{board,prompt})
local lot=inst("Expansion","Model",{},{part("Floor",{Color="grey",Material="Concrete",Position=v3(-94,0.3,105),Size=v3(28,0.6,58)}),part("BackGap"),part("GapFence",{Transparency=0.3,CanCollide=true}),
    part("GapInvisible",{Transparency=1,CanCollide=true}),inst("Fence","Model",{},{part("Post"),part("Rail")}),sign,part("SignPost"),
    part("LotWall",{Color="grey",Material="Plastic",Transparency=0}),part("LotFence",{Color="grey",Transparency=0.3})})
local ped21=part("Pen21",{Transparency=0}); ped21._attrs.Slot=21
local ped20=part("Pen20",{Transparency=0}); ped20._attrs.Slot=20
local pad7=part("Incubator7",{Transparency=0,Position=v3(-102.5,1.2,96)},{part("Ring",{Transparency=0})}); pad7._attrs.Slot=7
local pad3=part("Incubator3",{Transparency=0,Position=v3(-33,1.2,100)},{part("Ring",{Transparency=0})}); pad3._attrs.Slot=3
local function box(x,y,z) return {Position=v3(x,y,z),XVector=v3(1,0,0),YVector=v3(0,1,0),ZVector=v3(0,0,1)} end
local dome7=part("Part",{Transparency=0.75,CanCollide=false,Position=v3(-102.5,3.6,96),CFrame=box(-102.5,3.6,96),Size=v3(6.6,6.6,6.6)})
local dome3=part("Part",{Transparency=0.75,CanCollide=false,Position=v3(-33,3.6,100),CFrame=box(-33,3.6,100),Size=v3(6.6,6.6,6.6)})
local doorBanner=part("Part",{Transparency=0,CanCollide=true,Position=v3(-78.8,6.6,105),CFrame=box(-78.8,6.6,105),Size=v3(0.2,6,4)})
local sideBanner=part("Part",{Transparency=0,CanCollide=true,Position=v3(-78.8,6.6,85),CFrame=box(-78.8,6.6,85),Size=v3(0.2,6,4)})
local wideBanner=part("Part",{Transparency=0,CanCollide=true,Position=v3(-78.8,6.6,92),CFrame=box(-78.8,6.6,92),Size=v3(0.2,6,8)})
local lampLight=inst("PointLight","PointLight",{Enabled=true})
local lampSwitch=inst("ProximityPrompt","ProximityPrompt",{Enabled=true})
local lampMusic=inst("Music","Sound",{Playing=true})
local lampPole=part("Pole",{Transparency=0,CanCollide=true,Position=v3(-78,5,108),CFrame=box(-78,5,108),Size=v3(0.6,9,0.6)},{lampLight,lampSwitch,lampMusic})
local lamp=inst("Lamp","Model",{BoxCF=box(-78,5,108),BoxSize=v3(1,9,1)},{lampPole})
local plot=inst("Plot1","Model",{},{lot,inst("BaseDecor","Folder",{},{doorBanner,sideBanner,wideBanner,lamp,dome7,dome3}),
    part("Floor",{Color="sand",Material="Marble",Position=v3(-50,0.3,105),Size=v3(58,0.6,58)}),part("Wall",{Color="red",Material="WoodPlanks",Transparency=0}),
    inst("Enclosure","Folder",{},{part("Fence",{Color="blue"})}),inst("Pen","Folder",{},{ped20,ped21}),inst("Incubators","Folder",{},{pad7,pad3})})
plot._attrs.OwnerUserId=7
plot._attrs.Side=-1
local moved={}
local PlotService={get=function() return plot end,teleport=function(character,cf) moved[character]=cf end}
local player={UserId=7,GetAttribute=function() return nil end,SetAttribute=function() end}
local visitorChar={FindFirstChild=function(_,n) return n=="HumanoidRootPart" and {Position=v3(-94,3,110)} or nil end}
local bystanderChar={FindFirstChild=function(_,n) return n=="HumanoidRootPart" and {Position=v3(-50,3,105)} or nil end}
Players.GetPlayers=function() return {{Character=visitorChar},{Character=bystanderChar},{Character=nil}} end
local ExpansionService="""+exp+r"""
assert(ExpansionService,"ExpansionService exists")
-- canBuy
local ok,why=ExpansionService.canBuy({Rebirths=9,Cash=1e12},50e9); assert(not ok and why=="rebirth","Rebirth 9 refused")
ok,why=ExpansionService.canBuy({Rebirths=10,Cash=49e9},50e9); assert(not ok and why=="cash","short of cash refused")
assert(ExpansionService.canBuy({Rebirths=10,Cash=50e9},50e9),"exact cash at Rebirth 10 buys")
ok,why=ExpansionService.canBuy({Rebirths=12,Cash=1e12,BaseExpanded=true},50e9); assert(not ok and why=="owned","second buy refused")
-- hidden lot slots
assert(Config.hiddenSlot(21,"pen",false) and not Config.hiddenSlot(21,"pen",true) and not Config.hiddenSlot(20,"pen",false),"pen 21+ hidden until the lot")
assert(Config.hiddenSlot(7,"incubator",false) and not Config.hiddenSlot(6,"incubator",false) and not Config.hiddenSlot(8,"incubator",true),"incubator 7+ hidden until the lot")
-- bought state
ExpansionService.setState(plot,true)
assert(plot:GetAttribute("Expanded")==true,"plot marked expanded")
assert(lot.BackGap.CanCollide==false and lot.BackGap.Transparency==1 and lot.GapInvisible.CanCollide==false and lot.GapFence.CanCollide==false,"the opening is open")
assert(lot.Fence.Post.Transparency==1 and lot.Sign.Transparency==1 and board.Enabled==false and lot.SignPost.Transparency==1,"fence and sign gone")
assert(lot.Floor.Color=="sand" and lot.Floor.Material=="Marble" and lot.LotWall.Color=="red" and lot.LotFence.Color=="blue","the lot takes the base's floor, wall and fence look")
assert(doorBanner.Transparency==1 and doorBanner.CanCollide==false,"base decor hanging in the new opening is cleared")
assert(sideBanner.Transparency==0 and sideBanner.CanCollide==true,"decor beside the opening stays")
assert(wideBanner.Transparency==1 and wideBanner.CanCollide==false,"wide decor reaching into the opening is cleared even when centred outside it")
assert(lampPole.Transparency==1 and lampLight.Enabled==false and lampMusic.Playing==false and lampSwitch.Destroyed and lamp.Name~="Lamp",
    "a lamp in the opening goes dark, loses its switch and is no longer relit by the Lights toggle")
-- reset (plot freed): locked again whatever the last owner had (Review Focus 1)
ExpansionService.reset(plot)
assert(moved[visitorChar] and moved[visitorChar].X==-50+36 and moved[visitorChar].Z==105,"someone standing in the lot is moved out to the front before it closes")
assert(moved[bystanderChar]==nil,"people in the base itself are not moved")
assert(prompt:GetAttribute("OnlyFor")==0,"a freed plot's buy prompt shows to nobody")
assert(plot:GetAttribute("Expanded")==false and lot.BackGap.CanCollide==true and lot.BackGap.Transparency==0 and lot.GapInvisible.CanCollide==true,"reset closes the opening")
assert(lot.Fence.Post.Transparency==0 and lot.Sign.Transparency==0 and board.Enabled==true and label.Text=="Unlocks at Rebirth 10","reset shows the For Sale sign")
assert(ped21.Transparency==1 and pad7.Transparency==1 and pad7.Ring.Transparency==1 and ped20.Transparency==0,"lot pens/pads hidden while locked, base pens untouched")
assert(dome7.Transparency==1 and dome3.Transparency==0.75,"a glass dome over a hidden lot pad is hidden too; base pad domes stay")
-- apply reads only the save flag, on whatever plot the player got (Review Focus 2)
edata={Rebirths=10,Cash=0,BaseExpanded=true}
ExpansionService.apply(player)
assert(plot:GetAttribute("Expanded")==true,"a returning owner's plot opens on join")
edata={Rebirths=3,Cash=0,BaseExpanded=false}
ExpansionService.apply(player)
assert(plot:GetAttribute("Expanded")==false and label.Text=="Unlocks at Rebirth 10","an owner without the lot sees it locked")
assert(prompt:GetAttribute("OnlyFor")==0,"below Rebirth 10 the prompt shows to nobody")
edata={Rebirths=10,Cash=0,BaseExpanded=false}
ExpansionService.apply(player)
assert(prompt:GetAttribute("OnlyFor")==7,"at Rebirth 10 only the owner sees the buy prompt")
-- the sign follows the price at once when VIP / friends / rebirths change (join sets VIP after the first apply)
local handlers={}
player.GetAttributeChangedSignal=function(_,name) return {Connect=function(_,f) handlers[name]=f end} end
ExpansionService.watch(player)
assert(handlers.VIPPass and handlers.FriendCount and handlers.Rebirths,"the sign watches VIP, friends and rebirths")
CreatureService.priceIncomeOf=function() return 1e7 end
handlers.VIPPass()
assert(label.Text=="Base Expansion  $"..tostring(1e7*21600),"VIP arriving after join updates the sign price immediately")
CreatureService.priceIncomeOf=function() return 0 end
-- buy: price from price income at trigger time, charged once (Review Focus 3)
edata={Rebirths=10,Cash=60e9,BaseExpanded=false}
local repaints=0
ExpansionService.onBought=function() repaints+=1 end
assert(ExpansionService.buy(player)==true and edata.BaseExpanded==true and edata.Cash==10e9,"buy charges the $50B floor once")
assert(repaints==1,"buying repaints the whole base (domes over the new pads come back)")
ExpansionService.setState(plot,true)
assert(prompt:GetAttribute("OnlyFor")==0,"a bought lot's prompt shows to nobody")
assert(ExpansionService.buy(player)==false and edata.Cash==10e9,"a second trigger charges nothing")
plot._attrs.OwnerUserId=8
edata={Rebirths=10,Cash=60e9,BaseExpanded=false}
assert(ExpansionService.buy(player)==false and edata.Cash==60e9,"only the plot owner can buy")
print("PASS: base expansion sign, buy once, bought/locked states, hidden lot slots")
"""
    mon_src=(ROOT/"src/ServerScriptService/Services/MonetizationService.luau").read_text(encoding="utf-8-sig")
    apply_pass=mon_src[mon_src.index("local function applyPass"):mon_src.index("function MonetizationService.onPlayerReady")]
    pass_checks=r"""
-- final review: a pass bought after the lot must never take slots away (cap +2 / +5 at 6 / 20, never lower)
local pdata={IncubatorCount=8,PenSlots=25,PassesApplied={}}
local DataService={get=function() return pdata end}
local HatchService={onPlayerReady=function() end}
local ShopService={sync=function() end}
local CreatureService={changed=function() end}
local MountService={apply=function() end}
local pplayer={SetAttribute=function() end}
"""+apply_pass+r"""
applyPass(pplayer,"Incubators"); applyPass(pplayer,"PenSlots")
assert(pdata.IncubatorCount==8 and pdata.PenSlots==25,"passes keep an expanded player's 8 incubators / 25 pen slots")
pdata={IncubatorCount=5,PenSlots=17,PassesApplied={}}
applyPass(pplayer,"Incubators"); applyPass(pplayer,"PenSlots")
assert(pdata.IncubatorCount==6 and pdata.PenSlots==20,"passes still cap at the base 6 / 20")
print("PASS: Incubators / Pen Slots passes never lower slots bought with the base expansion")
"""
    shop_checks=shop_checks+"\nend\ndo\n"+ui_checks+"\nend\ndo\n"+inside_checks+"\nend\ndo\n"+exp_checks+"\nend\ndo\n"+pass_checks
    pre=r"""
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local workspace={FindFirstChild=function() return nil end}
"""
    return pre+"local Config="+cfg+"\n"+checks+"\ndo\n"+shop_checks+"\nend\n"


def main():
    from run_flight_checks import harness as flight_harness
    from run_secret_checks import harness as secret_harness
    from run_seat_checks import harness as seat_harness
    from run_engagement_checks import likes, quests, friends, popups, leaderboard, steal_success
    from run_hud_checks import menu, hints, shop, popup, shield, event_layout
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", type=Path, required=True)
    args = parser.parse_args()
    exe = ".exe" if (args.runtime / "luau.exe").exists() else ""
    for rel in ("ServerScriptService/Services/GearService.luau", "StarterGui/MainUI/ShopUI.luau"):
        text = (ROOT / "src" / rel).read_text(encoding="utf-8-sig")
        assert "+25%" not in text, f"{rel}: Soda text must not show a percentage"
        assert "Speed Boost for 20s" in text, f"{rel}: Soda text should read 'Speed Boost for 20s'"
    with tempfile.TemporaryDirectory(prefix="mount-feedback-checks-") as scratch:
        script = Path(scratch) / "feedback.luau"
        script.write_text(harness(), encoding="utf-8")
        subprocess.run([str(args.runtime / ("luau" + exe)), str(script)], check=True)
        script.write_text(visual_harness(), encoding="utf-8")
        subprocess.run([str(args.runtime / ("luau" + exe)), str(script)], check=True)
        script.write_text(mama_harness(), encoding="utf-8")
        subprocess.run([str(args.runtime / ("luau" + exe)), str(script)], check=True)
        for extra in (flight_harness, secret_harness, seat_harness, movement_harness, pen_roam_harness, tutorial_harness, mount_harness, get_off_harness, storm_harness, guardian_harness, guardian_fx_harness, mama_fx_harness, egg_fx_harness, fuse_ui_harness, gear_harness, touch_buttons_harness, pacing_harness, plaza_harness, top_players_harness, base_harness, rebirth_harness, whats_new_harness, expansion_harness, legacy_harness, likes, quests, friends, popups, leaderboard, steal_success, menu, hints, shop, popup, shield, event_layout):
            script.write_text(extra(), encoding="utf-8")
            subprocess.run([str(args.runtime / ("luau" + exe)), str(script)], check=True)
    scripts = sorted((ROOT / "src").rglob("*.luau"))
    subprocess.run([str(args.runtime / ("luau-compile" + exe)), "--null", *map(str, scripts)], check=True, stdout=subprocess.DEVNULL)
    print(f"PASS: compiled {len(scripts)} Luau sources")


if __name__ == "__main__":
    main()
