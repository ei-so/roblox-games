"""Real-source engagement checks; Roblox boundaries only are stubbed."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import re
from run_feedback_checks import ROOT, module


def likes():
    path = "ServerScriptService/Services/LikeService.luau"
    assert (ROOT / "src" / path).exists(), "LikeService must implement daily visitor likes"
    prelude = '''
local now=86400*100
local os={time=function() return now end}
local attrs={}
local function player(id)
 return {UserId=id,DisplayName="P"..id,Parent=true,SetAttribute=function(self,k,v) attrs[id..k]=v end,
 GetAttribute=function(self,k) return attrs[id..k] end,
 Character={FindFirstChild=function() return {Position=0} end,FindFirstChildOfClass=function() return {Health=100} end}}
end
local visitor,owner=player(1),player(2)
local point={Position=setmetatable({}, {__sub=function() return {Magnitude=0} end}),
 LikePrompt={SetAttribute=function() end},Count={Text={}}}
-- Vector distance is a Roblox boundary; the real service still decides ownership and daily limits.
visitor.Character.FindFirstChild=function() return {Position=point.Position} end
local plot={GetAttribute=function() return 2 end,FindFirstChild=function(_,name) return name=="LikePoint" and point or nil end}
local profiles={[visitor]={LikesGiven={}},[owner]={Likes=0}}
local DataService={get=function(p) return profiles[p] end}
local PlotService={get=function(p) return p==owner and plot or nil end}
local Players={GetPlayerByUserId=function(_,id) return id==2 and owner or nil end}
local Notify={FireClient=function() end}
local ReplicatedStorage={Remotes={Notify=Notify}}
local game={GetService=function(_,name) return name=="Players" and Players or ReplicatedStorage end}
'''
    source = module(path, {
        "local DataService = require(script.Parent.DataService)": "",
        "local PlotService = require(script.Parent.PlotService)": "",
    })
    return prelude + "local LikeService=" + source + '''
local events=0
LikeService.onLiked=function() events+=1 end
assert(not LikeService.like(owner,plot),"owner cannot like their own base")
assert(LikeService.like(visitor,plot),"visitor can like another base")
assert(profiles[owner].Likes==1 and events==1,"one persisted like and one quest event")
assert(not LikeService.like(visitor,plot) and profiles[owner].Likes==1,"repeat same day refused")
now+=86400
assert(LikeService.like(visitor,plot) and profiles[owner].Likes==2,"next UTC day allows a like")
assert(profiles[visitor].LikesGiven["2"]==101,"saved owner key is a string")
attrs["1DataLoadFailed"]=true
now+=86400
assert(not LikeService.like(visitor,plot),"failed-load visitor cannot write likes")
attrs["1DataLoadFailed"]=nil
point.Position=setmetatable({}, {__sub=function() return {Magnitude=100} end})
assert(not LikeService.like(visitor,plot),"distant visitor refused server-side")
print("PASS: likes reject owner, duplicates, failed loads and distance; persist totals and reset UTC")
'''


def quests():
    path = "ServerScriptService/Services/QuestService.luau"
    assert (ROOT / "src" / path).exists(), "QuestService must implement period quests and authoritative claims"
    prelude = '''
local now=86400*101 -- Sunday: first Monday day 4 + 14 weeks - 1
local os={time=function() return now end}
local Random={new=function(seed) return {NextInteger=function(_,a,b) seed=(seed*48271)%2147483647; return a+seed%(b-a+1) end} end}
local Color3={fromRGB=function() return {} end}
local Enum=setmetatable({}, {__index=function() return {} end})
local attrs={}
local p={UserId=15,SetAttribute=function(_,k,v) attrs[k]=v end,GetAttribute=function(_,k) return attrs[k] end}
local data={Cash=0,LuckUntil=0}
local payouts,earnedEvents=0,0
local DataService={get=function() return data end,addCash=function(_,n,suppress) data.Cash+=n;payouts+=1;if not suppress then earnedEvents+=1 end end}
local income=0
local CreatureService={incomeOf=function() return income end}
local HttpService={JSONEncode=function(_,value) return "encoded" end}
local Players={}
local ReplicatedStorage={Remotes={Notify={FireClient=function() end}}}
local game={GetService=function(_,name) return name=="HttpService" and HttpService or name=="Players" and Players or ReplicatedStorage end}
'''
    source = module(path, {
        "local Config = require(ReplicatedStorage.Shared.Config)": "",
        "local DataService = require(script.Parent.DataService)": "",
        "local CreatureService = require(script.Parent.CreatureService)": "",
    })
    return prelude + "local Config=" + module("ReplicatedStorage/Shared/Config.luau", {}) + "\nlocal QuestService=" + source + '''
QuestService.sync(p)
assert(#data.Quests.daily==3 and #data.Quests.weekly==3,"3 quests each period")
local day,week=data.Quests.day,data.Quests.week
local first=data.Quests.daily[1].id
QuestService.sync(p)
assert(data.Quests.daily[1].id==first,"assignments persist through sync")
local unique={}
for _,q in data.Quests.daily do assert(not unique[q.id],"no duplicate assignments");unique[q.id]=true end
assert(not QuestService.claim(p,"daily",1,day),"unfinished quest cannot claim")
local q=data.Quests.daily[1]
local event=Config.Quests.byId[q.id].event
QuestService.track(p,event,q.target)
assert(q.progress==q.target,"correct event advances quest")
income=20
assert(QuestService.claim(p,"daily",1,day) and data.Cash==3600,"daily reward uses income at claim")
assert(not QuestService.claim(p,"daily",1,day) and payouts==1,"no double claim")
assert(earnedEvents==0,"quest payout cannot complete an earn quest")
for _,w in data.Quests.weekly do w.progress=w.target end
for i=1,3 do assert(QuestService.claim(p,"weekly",i,week)) end
assert(data.LuckUntil==now+900 and data.Quests.weeklyBonus,"weekly completion adds 15 minutes luck once")
local cash=data.Cash
assert(not QuestService.claim(p,"weekly",3,week) and data.Cash==cash,"bonus and cash do not repeat")
assert(not QuestService.claim(p,"daily",0,day) and not QuestService.claim(p,"daily",0/0,day),"invalid slot refused")
assert(not QuestService.claim(p,"bogus",1,day),"invalid period refused")
now+=86400 -- Monday
QuestService.sync(p)
assert(data.Quests.day==102 and data.Quests.week==week+1,"UTC daily and Monday weekly reset")
assert(not data.Quests.weeklyBonus and data.Quests.daily[1].progress==0,"new quests start empty")
assert(not QuestService.claim(p,"daily",1,day),"stale panel cannot claim new day's quests")
local weekly=data.Quests.weekly
now+=86400
QuestService.sync(p)
assert(data.Quests.weekly==weekly,"Tuesday preserves weekly progress")
attrs.DataLoadFailed=true
data.Quests.daily[1].progress=data.Quests.daily[1].target
assert(not QuestService.claim(p,"daily",1,data.Quests.day),"failed load cannot claim")
print("PASS: deterministic 3+3 quests, event progress, UTC/Monday reset, scaled claims, stale/duplicate guards, weekly luck")
'''


def friends():
    path = "ServerScriptService/Services/FriendService.luau"
    assert (ROOT / "src" / path).exists(), "FriendService must count same-server friends"
    prelude = '''
local Color3={fromRGB=function() return {} end}
local Enum=setmetatable({}, {__index=function() return {} end})
local profiles={}
local function player(id)
 local attrs={}
 return {UserId=id,Parent=true,SetAttribute=function(_,k,v) attrs[k]=v end,GetAttribute=function(_,k) return attrs[k] end,
 IsFriendsWithAsync=function(_,other) return other>=2 and other<=5 end}
end
local p,a,b,c,d,stranger=player(1),player(2),player(3),player(4),player(5),player(6)
local list={p,a,b,c,d,stranger}
local Players={GetPlayers=function() return list end}
local ReplicatedStorage={Remotes={}}
local HttpService={}
local DataService={get=function(who) return profiles[who] end}
local PlotService,Format,CreatureBuilder={},{},{}
local game={GetService=function(_,name) return name=="Players" and Players or name=="HttpService" and HttpService or ReplicatedStorage end}
for _,who in list do who.Parent=Players end
'''
    source = module(path, {})
    creature = module("ServerScriptService/Services/CreatureService.luau", {
        "local Config = require(ReplicatedStorage.Shared.Config)": "",
        "local Format = require(ReplicatedStorage.Shared.Format)": "",
        "local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)": "",
        "local DataService = require(script.Parent.DataService)": "",
        "local PlotService = require(script.Parent.PlotService)": "",
    })
    return prelude + "local Config=" + module("ReplicatedStorage/Shared/Config.luau", {}) + "\nlocal FriendService=" + source + "\nlocal CreatureService=" + creature + '''
profiles[p]={Pen={"x"},Creatures={x={species="Chick",rarity="Common"}},Rebirths=0,Index={}}
p:SetAttribute("VIPPass",true)
FriendService.refresh(p)
assert(p:GetAttribute("FriendCount")==4,"self and stranger excluded; four friends counted")
assert(math.abs(CreatureService.incomeOf(p)-7.8)<1e-9,"four friends capped at 30%, stacks with VIP")
list={p,b,stranger}
FriendService.refresh(p)
assert(p:GetAttribute("FriendCount")==1 and math.abs(CreatureService.incomeOf(p)-6.6)<1e-9,"leave removes bonus")
FriendService.refresh(p,b)
assert(p:GetAttribute("FriendCount")==0 and CreatureService.incomeOf(p)==6,"departing friend excluded before removal")
p.IsFriendsWithAsync=function() error("network outage") end
FriendService.refresh(p)
assert(p:GetAttribute("FriendCount")==0,"lookup failure grants no bonus")
local once=true
p.IsFriendsWithAsync=function() if once then once=false;coroutine.yield() end;return true end
local old=coroutine.create(function() FriendService.refresh(p) end)
assert(coroutine.resume(old))
list={p}
FriendService.refresh(p)
assert(coroutine.resume(old))
assert(p:GetAttribute("FriendCount")==0,"late yielding lookup cannot overwrite newer count")
print("PASS: same-server friends, self/stranger exclusion, join/leave, API failure, stale lookup, 30% cap + VIP income")
'''


def popups():
    source = (ROOT / "src/StarterGui/MainUI/RetentionUI.luau").read_text(encoding="utf-8")
    match = re.search(r"local function canShowPopup\(\)(.*?)\nend\n", source, re.S)
    assert match, "Daily/Offline popups must check actual visible panels before opening"
    controller = (ROOT / "src/StarterGui/MainUI/UIController.luau").read_text(encoding="utf-8-sig")
    resize = re.search(r"local function rescale\(\)(.*?)\nend\n", controller, re.S)
    assert resize, "Menu must resize with the viewport"
    return '''
local list={}
local gui={LeftMenu={Visible=false},GetChildren=function() return list end}
''' + match.group() + '''
local function panel(name,visible) return {Name=name,Visible=visible,IsA=function(_,class) return class=="GuiObject" end} end
assert(canShowPopup(),"empty UI allows popup")
gui.LeftMenu.Visible=true
assert(not canShowPopup(),"expanded menu blocks popup")
gui.LeftMenu.Visible=false
list={panel("QuestsPanel",true)}
assert(not canShowPopup(),"quest panel blocks reward popup even before deferred attributes update")
list={panel("DailyPanel",true),panel("OfflinePanel",false)}
assert(not canShowPopup(),"daily and offline summaries do not stack")
list={panel("QuestsPanel",false),panel("TopBar",true)}
assert(canShowPopup(),"hidden panels and HUD do not block")
''' + '''
local camera={ViewportSize={Y=374}}
local uiScale,menuScale,toggleScale,toggle,menu={},{},{},{},{}
local UserInputService={TouchEnabled=true}
local top={Position={Y={Offset=8}},Size={Y={Offset=48}}}
gui.AbsoluteSize={X=665,Y=316}
local UDim2={fromOffset=function(x,y) return {X=x,Y=y} end}
local function syncMenuLock() end
''' + resize.group() + '''
rescale()
assert(menu.Position.X*uiScale.Scale==104,"short-phone Menu opens beside toggle")
assert(menu.Position.Y*uiScale.Scale+188<=gui.AbsoluteSize.Y,"all seven 44-pixel Menu buttons fit")
assert(menu.Position.Y*uiScale.Scale>=56*uiScale.Scale+8,"Menu clears HUD")
camera.ViewportSize.Y=900;gui.AbsoluteSize.Y=842
rescale()
assert(menu.Position.X==12 and menu.Position.Y==114,"tall screens keep Menu below toggle")
print("PASS: popups wait for Menu/panels; seven Menu controls fit short-phone and tall viewports")
'''


def steal_success():
    source = (ROOT / "src/ServerScriptService/Services/StealService.luau").read_text(encoding="utf-8-sig")
    hand = re.search(r"local function hand\(thief, victim, egg\)(.*?)\nend\n", source, re.S)
    assert hand, "StealService shared hand must report successful steals"
    return '''
local events=0
local StealService={onStolen=function() events+=1 end}
local succeeds=false
local EggService={attach=function() return succeeds end}
local robbedAt={}
local Notify={FireClient=function() end}
''' + hand.group() + '''
hand({}, {}, {})
assert(events==0,"failed egg attachment cannot advance a steal quest")
succeeds=true
hand({}, {}, {})
assert(events==1,"successful carrier or base hand emits one steal quest event")
print("PASS: shared steal success callback requires an attached egg")
'''


def leaderboard():
    prelude = '''
local Color3={fromRGB=function() return {} end}
local player={UserId=12,GetAttribute=function() return false end}
local data={Likes=2}
local stored=1
local writes=0
local board={written={[12]=1},monotonic=true,valueOf=function(_,d) return d.Likes end,
 store={UpdateAsync=function(_,key,update) assert(key=="12");stored=update(stored);writes+=1 end}}
local testBoards={board}
local DataService={get=function() return data end}
local Players={GetPlayers=function() return {player} end}
local ReplicatedStorage={Remotes={}}
local game={GetService=function(_,name) return name=="Players" and Players or ReplicatedStorage end}
local Config,CreatureBuilder,Format,CreatureService={},{},{},{}
'''
    source = module("ServerScriptService/Services/PlazaService.luau", {
        "local Config = require(ReplicatedStorage.Shared.Config)": "",
        "local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)": "",
        "local Format = require(ReplicatedStorage.Shared.Format)": "",
        "local DataService = require(script.Parent.DataService)": "",
        "local CreatureService = require(script.Parent.CreatureService)": "",
        "local boards = {}": "local boards = testBoards",
    })
    return prelude + "local PlazaService=" + source + '''
assert(type(PlazaService.onPlayerLeaving)=="function","departing owner must flush final likes")
PlazaService.onPlayerLeaving(player)
assert(stored==2 and writes==1,"like received after refresh reaches board before owner leaves")
data.Likes=1;board.written[12]=nil
PlazaService.onPlayerLeaving(player)
assert(stored==2,"an older in-flight write cannot lower all-time likes")
data=nil
PlazaService.onPlayerLeaving(player)
assert(writes==2,"released or unloaded profiles never write")
local main=MAIN_SOURCE
assert(main:find("PlazaService.onPlayerLeaving(player)",1,true),"real lifecycle must flush before profile release")
local leaving=main:sub((main:find("Players.PlayerRemoving:Connect",1,true)))
assert(leaving:find("DataService.save(player)",1,true)<leaving:find("PlazaService.onPlayerLeaving(player)",1,true),"leaderboard I/O cannot delay starting the authoritative profile save")
print("PASS: final departing likes flush; stale writes cannot lower all-time Top Bases")
'''.replace("MAIN_SOURCE", '[=[' + (ROOT / "src/ServerScriptService/Main.luau").read_text(encoding="utf-8-sig") + ']=]')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--group", choices=("likes", "quests", "friends", "popups", "leaderboard", "steal", "all"), default="all")
    args = parser.parse_args()
    exe = ".exe" if (args.runtime / "luau.exe").exists() else ""
    with tempfile.TemporaryDirectory(prefix="sam-engagement-") as temp:
        script = Path(temp) / "check.luau"
        for name, harness in (("likes", likes), ("quests", quests), ("friends", friends), ("popups", popups), ("leaderboard", leaderboard), ("steal", steal_success)):
            if args.group in (name, "all"):
                script.write_text(harness(), encoding="utf-8")
                subprocess.run([str(args.runtime / ("luau" + exe)), str(script)], check=True)


if __name__ == "__main__":
    main()
