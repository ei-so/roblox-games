"""Check actual Secret Egg rarity rolls against hand-chosen biome odds."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from run_feedback_checks import module


def harness():
    config = module('ReplicatedStorage/Shared/Config.luau', {})
    hatch = module('ServerScriptService/Services/HatchService.luau', {
        'local Config = require(ReplicatedStorage.Shared.Config)': '',
        'local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)': '',
        'local DataService = require(script.Parent.DataService)': '',
        'local PlotService = require(script.Parent.PlotService)': '',
        'local CreatureService = require(script.Parent.CreatureService)': '',
    })
    root = Path(__file__).resolve().parents[1] / 'src'
    event = (root / 'ServerScriptService/Services/EventService.luau').read_text(encoding='utf-8-sig')
    schedule = event[event.index('function EventService.start()'):event.index('\nreturn EventService')]
    ui = (root / 'StarterGui/MainUI/UIController.luau').read_text(encoding='utf-8-sig')
    helpers = ui[ui.index('-- Pure helpers below'):ui.index('-- End of pure helpers.')]
    return r'''
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(_,k) return k end}) end})
local nextValues, calls = {}, 0
local Random={new=function() return {NextNumber=function() calls+=1;return nextValues[calls] or .3 end} end}
local game={GetService=function() return {Remotes={Notify={}}} end}
''' + 'local Config=' + config + '\nlocal HatchService=' + hatch + r'''
local expected={Desert={900,90,10},Jungle={850,120,30},Tundra={800,150,50},Volcano={720,200,80},Cosmic={600,250,150},Forest={900,90,10},Lake={900,90,10}}
for biome, want in expected do
    local counts={Epic=0,Legendary=0,Mythic=0}
    for i=1,1000 do
        calls=0;nextValues={.3,(i-.5)/1000}
        local r=HatchService.roll({biome=biome,secret=true,mutation='Golden'},true,true)
        assert(counts[r.rarity]~=nil,'Secret Eggs must remain Epic or better')
        assert(r.mutation=='Golden' and Config.Species[r.species].biome==biome,'biome/species/mutation survive')
        counts[r.rarity]+=1
    end
    assert(counts.Epic==want[1] and counts.Legendary==want[2] and counts.Mythic==want[3],biome..' must use its biome odds')
end
for _,biome in Config.Biomes do
    local counts={Common=0,Uncommon=0,Rare=0,Epic=0,Legendary=0}
    for i=1,1000 do
        calls=0;nextValues={(i-.5)/1000}
        local result=HatchService.roll({biome=biome.id,species=biome.species[1]})
        counts[result.rarity]+=1
    end
    assert(counts.Common==550 and counts.Uncommon==280 and counts.Rare==120 and counts.Epic==40 and counts.Legendary==10,'ordinary rarity odds unchanged')
end
assert(Config.Events.secretEggInterval==420 and Config.Events.secretHatch==60,'7-minute spawn interval and preserved base hatch time')
for _,biome in Config.Biomes do
    assert(math.abs(Config.carryMult({biome=biome.id,secret=true}) / Config.carryMult({biome=biome.id}) - .909)<1e-9,'Secret Eggs use the approved Secret weight')
end
print('PASS: Secret biome rarity distributions, lower-biome fallback, original biome/species/mutation, ordinary odds,7min timer')
''' + r'''
local now, spawned = 100, 0
local attrs={NextNestRefill=400}
local workspace={SetAttribute=function(_,k,v) attrs[k]=v end,GetAttribute=function(_,k) return attrs[k] end,GetServerTimeNow=function() return now end}
local routines={}
local task={spawn=function(fn) local co=coroutine.create(fn);table.insert(routines,co);assert(coroutine.resume(co)) end,wait=function(seconds) return coroutine.yield(seconds) end}
local EventService={spawnSecret=function() spawned+=1 end,startWeather=function() end}
''' + schedule + r'''
EventService.start()
assert(attrs.NextSecretEgg==520,'next Secret spawn is replicated at server startup')
now=520;assert(coroutine.resume(routines[1]))
assert(spawned==1 and attrs.NextSecretEgg==940,'scheduled spawn refreshes countdown for the next7min cycle')
local WEATHER_TEXT,WEATHER_TIP={},{}
''' + helpers + r'''
local function get(k) return attrs[k] end
assert(secretView(get,520).detail=='Next in 7:00','Secret countdown card at the new cycle')
assert(secretView(get,521).detail=='Next in 6:59','timer advances with server time')
assert(secretView(get,942).detail=='Appearing soon…','overdue countdown never becomes negative')
assert(refillView(get,942).detail=='Eggs refilling…' and baseView(nil,nil).detail=='Base unlocked','base/nest cards stay')
attrs.NextSecretEgg=nil;assert(secretView(get,942)==nil,'missing replication hides the Secret card')
assert(refillView(get,100).detail=='Eggs refill in 5:00','nest card unaffected')
print('PASS: scheduled Secret timestamp initializes/resets; Secret card counts down, clamps and tolerates missing replication')
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='sam-secret-') as temp:
        script = Path(temp) / 'secret.luau'
        script.write_text(harness(), encoding='utf-8')
        subprocess.run([str(args.runtime / 'luau.exe'), str(script)], check=True)


if __name__ == '__main__':
    main()
