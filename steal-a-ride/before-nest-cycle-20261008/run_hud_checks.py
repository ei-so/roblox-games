"""Actual-source checks for Menu switching, brief hints and stall-only gear purchases."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / "src" / path).read_text(encoding="utf-8-sig")


def menu():
    source = read("StarterGui/MainUI/UIController.luau")
    start = source.index("local function syncMenuLock()")
    stop = source.index("local function closeMenu()", start)
    return """
local function signal()
 local callbacks={}
 return {Connect=function(_,fn) table.insert(callbacks,fn) end,
 Fire=function() for _,fn in callbacks do fn() end end}
end
local function panel(name)
 local properties={Name=name,Visible=false};local changed=signal()
 return setmetatable({IsA=function(_,class) return class=="GuiObject" end,
 GetPropertyChangedSignal=function() return changed end}, {
 __index=properties,__newindex=function(_,key,value)
  local previous=properties[key];properties[key]=value
  if key=="Visible" and previous~=value then changed.Fire() end
 end})
end
local stable,index,quests=panel("StablePanel"),panel("IndexPanel"),panel("QuestsPanel")
local children={stable,index,quests}
local gui={ChildAdded=signal(),GetChildren=function() return children end,
 SetAttribute=function(self,key,value) self[key]=value end}
local menu={Visible=true,GetChildren=function() return {} end}
local toggle={Active=true,Interactable=true,AutoButtonColor=true,Text="Close"}
local menuLocked=false
local touch=true
local GuiService={TouchControlsEnabled=true}
local Color3={fromRGB=function() return {} end,new=function() return {} end}
local function syncTouchControls()
 if touch and (menu.Visible or menuLocked) then GuiService.TouchControlsEnabled=false end
end
local menuPanels={StablePanel=true,IndexPanel=true,QuestsPanel=true}
""" + source[start:stop] + """
stable.Visible=true
assert(toggle.Active and toggle.Interactable,"opening Stable must keep Menu available")
assert(GuiService.TouchControlsEnabled,"opening a panel must preserve movement/jump")
menu.Visible=true
index.Visible=true
assert(index.Visible and not stable.Visible,"opening Index must close Stable")
assert(gui.OpenMenuPanel=="IndexPanel","popup queue must track the current panel")
assert(not menu.Visible,"selection closes the dropdown")
quests.Visible=true
assert(quests.Visible and not index.Visible,"Quests must replace Index")
quests.Visible=false
assert(gui.OpenMenuPanel==nil,"closing the last panel clears navigation state")
print("PASS: direct Menu switching, one open panel and active play controls")
"""


def hints():
    flight = read("StarterPlayer/StarterPlayerScripts/FlightController.luau")
    start = flight.index("-- Touch, gamepad")
    stop = flight.index("local function clearPhysics()", start)
    return """
local attrs={Abilities="Flight,Glide",Flying=false}
local player={GetAttribute=function(_,key) return attrs[key] end}
local Input={TouchEnabled=true,KeyboardEnabled=false,GetLastInputType=function() return {Name="Touch"} end}
local UDim2={new=function(...) return {...} end}
local hint={Visible=false,Text=""}
local boundFly=true
local delays={}
local task={delay=function(seconds,fn) assert(seconds>0 and seconds<=6);table.insert(delays,fn) end}
""" + flight[start:stop] + """
updateHint()
assert(hint.Visible and hint.Text:find("Tap Fly"),"new rider receives a touch instruction")
local first=delays[1]
attrs.Flying=true;updateHint()
first()
assert(hint.Visible and hint.Text:find("Tap Land"),"old timer cannot hide a newer flight state")
delays[#delays]()
assert(not hint.Visible,"flight instruction must expire")
updateHint()
assert(not hint.Visible,"unchanged state must not replay a hidden instruction")
""" + """
local now=100
local os={clock=function() return now end}
local tutorialText="Your egg is hatching"
local tutorialStep=function() return nil,tutorialText end
local gui={SetAttribute=function(self,key,value) self[key]=value end}
hint={Parent=gui,Visible=false}
local workspace={GetAttribute=function() return nil end}
local beam={}
local beamTarget={}
local Instance={}
""" + tutorial_hint_source() + """
updateTutorial(nil);assert(hint.Visible,"new tutorial step shows briefly")
now+=7;updateTutorial(nil)
assert(not hint.Visible,"unchanged hatching reminder must expire")
assert(gui.TutorialActive,"hiding copy must preserve guided progress and popup rules")
tutorialText="Visit the Gear Shop";updateTutorial(nil)
assert(hint.Visible,"a new goal displays its instruction")
print("PASS: brief flight/tutorial instructions; unchanged states do not replay")
"""


def tutorial_hint_source():
    source = read("StarterPlayer/StarterPlayerScripts/ClientMain.luau")
    start = source.index("local function updateTutorial(root)")
    prefix = source[source.rfind("\nend", 0, start) + 4:start]
    return prefix + source[start:source.index("\nlocal current", start)]


def shop():
    source = read("ServerScriptService/Services/ShopService.luau")
    start = source.index("function ShopService.buy(")
    stop = source.index("function ShopService.start()", start)
    return """
local data={Cash=1000}
local purchased=0
local DataService={get=function() return data end,addCash=function(_,n) data.Cash+=n end}
local ShopService={extraItems={},sync=function() end}
local function item() return 100,function() purchased+=1 end end
local ITEMS={saddle=item}
for _,id in {"net","trap","soda"} do ShopService.extraItems[id]=item end
local distance=100
local root={Position=setmetatable({}, {__sub=function() return {Magnitude=distance} end})}
local humanoid={Health=100}
local player={Character={FindFirstChild=function() return root end,FindFirstChildOfClass=function() return humanoid end}}
local body={Position={}}
local stall={FindFirstChild=function() return body end}
local plaza={FindFirstChild=function() return stall end}
local workspace={FindFirstChild=function() return plaza end}
""" + source[start:stop] + """
for _,id in {"net","trap","soda"} do
 assert(not ShopService.buy(player,id),"gear must be refused away from the stall")
end
assert(data.Cash==1000 and purchased==0,"remote purchases cannot deduct money away from the stall")
distance=30
assert(ShopService.buy(player,"soda") and data.Cash==900 and purchased==1,"gear buys at the stall")
humanoid.Health=0
assert(not ShopService.buy(player,"net"),"dead players cannot buy gear")
humanoid.Health=100;body=nil
assert(not ShopService.buy(player,"trap"),"missing stall cannot authorize a purchase")
body={Position={}};player.Character=nil
assert(not ShopService.buy(player,"net"),"missing character cannot authorize a purchase")
assert(not ShopService.buy(player,{}) and not ShopService.buy(player,"unknown"),"item validation remains intact")
assert(ShopService.buy(player,"saddle"),"non-gear upgrade paths remain valid")
data.Cash=0;player.Character={FindFirstChild=function() return root end,FindFirstChildOfClass=function() return humanoid end}
assert(not ShopService.buy(player,"net"),"insufficient cash cannot buy gear")
print("PASS: server-authoritative stall distance, alive character, money and item validation")
"""


def popup():
    source = read("StarterGui/MainUI/RetentionUI.luau")
    start = source.index("local function showDaily()")
    stop = source.index("local function syncDaily()", start)
    return """
local pendingDaily=true
local daily={Visible=false}
local blocked=false
local function canShowPopup() return not blocked and not daily.Visible end
local clicked
local claim={Activated={Connect=function(_,fn) clicked=fn end}}
local calls=0
local Remotes={ClaimDaily={FireServer=function() calls+=1 end}}
""" + source[start:stop] + """
showDaily();assert(daily.Visible,"eligible reward opens")
blocked=true;daily.Visible=false
showDaily();assert(not daily.Visible,"another tab owns the screen")
blocked=false;showDaily()
assert(daily.Visible,"unclaimed reward must reopen after tab switching")
clicked();showDaily()
assert(not daily.Visible and calls==1,"claim closes reward while server acknowledges it")
print("PASS: unclaimed Daily Reward survives tab switching; claim does not reopen it")
"""


def shield():
    source = read("ServerScriptService/Main.luau")
    start = source.find("local function syncShieldTag(player)")
    stop = source.find("local function onCharacter(", start)
    assert start >= 0, "Shielded needs a replicated overhead tag"
    return """
local function head()
 local children={}
 return {children=children,FindFirstChild=function(_,name) return children[name] end}
end
local attrs={Shielded=true,OG=true}
local currentHead=head()
local og={};currentHead.children.OGTag=og
local player={GetAttribute=function(_,name) return attrs[name] end,
 Character={FindFirstChild=function() return currentHead end}}
local created=0
local Instance={new=function(class)
 created+=1
 local props={ClassName=class,children={}}
 return setmetatable({Destroy=function(self)
  if props.Parent then props.Parent.children[props.Name]=nil end
 end}, {__index=props,__newindex=function(self,key,value)
  props[key]=value
  if key=="Parent" and value then value.children[props.Name or class]=self end
 end})
end}
local UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
local Vector3={new=function(...) return {...} end}
local Color3={fromRGB=function(...) return {...} end}
local Enum={Font={FredokaOne="FredokaOne"}}
""" + source[start:stop] + """
syncShieldTag(player)
local tag=currentHead.children.ShieldedTag
assert(tag and tag.children.TextLabel.Text=="Shielded (new player)","shielded descriptor sits above the head")
local count=created
syncShieldTag(player);assert(created==count,"repeated refresh cannot duplicate tags")
attrs.Shielded=false;syncShieldTag(player)
assert(currentHead.children.ShieldedTag==nil,"shield expiry removes the descriptor")
assert(currentHead.children.OGTag==og,"shield expiry preserves the OG tag")
attrs.Shielded=true;currentHead=head();syncShieldTag(player)
assert(currentHead.children.ShieldedTag,"respawn receives the current shield status")
player.Character=nil;syncShieldTag(player)
print("PASS: overhead shield tag, no duplicates, expiry, respawn and preserved OG")
"""


def event_layout():
    source = read("StarterGui/MainUI/UIController.luau")
    banner = source[source.index("local narrow ="):source.index("local parts =")]
    status = source[source.index("local statusY ="):source.index("task.wait(0.5)")]
    return """
local phase="active"
local top={Visible=false}
local gui={AbsoluteSize={X=401},FindFirstChild=function() return top end}
local workspace={GetAttribute=function() return phase end}
local UDim2={new=function(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end}
local banner={Visible=true,Size={Y={Offset=92}}}
local status={}
local function layout()
""" + banner + status + """
end
layout()
assert(banner.Position.Y.Offset>=220+8,"portrait weather clears the Mama bar")
assert(status.Position.Y.Offset>=banner.Position.Y.Offset+92+8,"base status clears weather")
phase=nil;layout()
assert(banner.Position.Y.Offset==64,"portrait weather clears the cash HUD without Mama")
phase="active";gui.AbsoluteSize.X=1920;top.Visible=true;layout()
assert(top.Position.Y.Offset>=banner.Position.Y.Offset+92+8,"Top damage clears weather on desktop")
assert(status.Position.Y.Offset>=top.Position.Y.Offset+80+8,"base status clears Top damage")
banner.Visible=false;layout()
assert(top.Position.Y.Offset==76 and status.Position.Y.Offset==164,"desktop empty-weather placement stays compact")
print("PASS: concurrent Mama/weather/Top damage/base status do not overlap")
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="sam-hud-") as temp:
        script = Path(temp) / "check.luau"
        for harness in (menu, hints, shop, popup, shield, event_layout):
            script.write_text(harness(), encoding="utf-8")
            subprocess.run([str(args.runtime / "luau.exe"), str(script)], check=True)


if __name__ == "__main__":
    main()
