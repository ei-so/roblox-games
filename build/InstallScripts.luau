local function folder(parent,name) local f=parent:FindFirstChild(name); if not f then f=Instance.new('Folder'); f.Name=name; f.Parent=parent end return f end
local RS=game:GetService('ReplicatedStorage'); local SSS=game:GetService('ServerScriptService'); local SG=game:GetService('StarterGui')
local modules=folder(RS,'Modules'); local remotes=folder(RS,'Remotes'); local services=folder(SSS,'Services')
for _,name in ipairs({'BuyGenerator','BuyUpgrade','Reboot'}) do if not remotes:FindFirstChild(name) then local r=Instance.new('RemoteEvent'); r.Name=name; r.Parent=remotes end end
local gui=SG:FindFirstChild('MainUI'); if not gui then gui=Instance.new('ScreenGui'); gui.Name='MainUI'; gui.Parent=SG end gui.ResetOnSpawn=false; gui.IgnoreGuiInset=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui:SetAttribute('PowerCoreOwned',true)
local function source(parent,name,class,code) local s=parent:FindFirstChild(name); if s then assert(s:GetAttribute('PowerCoreOwned'),'Refusing to replace unowned '..s:GetFullName()); s:Destroy() end s=Instance.new(class); s.Name=name; s.Source=code; s:SetAttribute('PowerCoreOwned',true); s.Parent=parent end
source(modules,'Formulas','ModuleScript',[====[local G=require(script.Parent.GeneratorConfig)
local U=require(script.Parent.UpgradeConfig)
local F={Generators={},Upgrades={}}
for _,g in ipairs(G) do F.Generators[g.id]=g end
for _,u in ipairs(U) do F.Upgrades[u.id]=u end
function F.Cost(id,owned,n)
 if n<=0 then return 0 end
 local g=F.Generators[id]
 if not g then return math.huge end
 return g.baseCost*1.15^owned*(1.15^n-1)/0.15
end
function F.MaxAffordable(id,owned,energy)
 local g=F.Generators[id]
 if not g or energy<=0 then return 0 end
 local nextCost=g.baseCost*1.15^owned
 if nextCost>energy then return 0 end
 local n=math.max(0,math.floor(math.log(energy*0.15/nextCost+1)/math.log(1.15)))
 while n>0 and F.Cost(id,owned,n)>energy do n-=1 end
 while F.Cost(id,owned,n+1)<=energy do n+=1 end
 return n
end
function F.GeneratorOutput(p,id,count)
 local mult=1
 for _,u in ipairs(U) do
  if p:GetAttribute('Upg_'..u.id) and (u.target==id or u.target=='generators') then mult*=u.mult end
 end
 return (count or p:GetAttribute('Gen_'..id) or 0)*F.Generators[id].perSecond*mult
end
function F.Multiplier(p,cores)
 local mult=1
 for _,u in ipairs(U) do if u.target=='all' and p:GetAttribute('Upg_'..u.id) then mult*=u.mult end end
 return mult*(1+0.25*(cores or p:GetAttribute('PowerCores') or 0))
end
function F.Production(p)
 local base=1
 for _,g in ipairs(G) do base+=F.GeneratorOutput(p,g.id) end
 return base*F.Multiplier(p)
end
function F.CoreReward(runEnergy)
 if runEnergy<1000000 then return 0 end
 return math.floor(3*math.sqrt(runEnergy/1000000))
end
return F
]====])
source(modules,'GeneratorConfig','ModuleScript',[====[return {
 {id='crank',name='Hand Crank',baseCost=10,perSecond=1},
 {id='battery',name='Battery Bank',baseCost=100,perSecond=5},
 {id='diesel',name='Diesel Generator',baseCost=1000,perSecond=25},
 {id='nuclear',name='Nuclear Reactor',baseCost=25000,perSecond=150},
 {id='fusion',name='Fusion Core',baseCost=500000,perSecond=1000},
 {id='quantum',name='Quantum Reactor',baseCost=10000000,perSecond=10000},
 {id='singularity',name='Singularity Reactor',baseCost=500000000,perSecond=250000},
 {id='dyson',name='Dyson Sphere',baseCost=100000000000,perSecond=5000000},
}
]====])
source(modules,'NumberFormatter','ModuleScript',[====[local suffixes={'K','M','B','T','Qa','Qi','Sx','Sp','Oc','No','Dc','Ud','Dd','Td','Qad','Qid'}
local N={}
function N.Integer(value) return string.format('%.0f',value) end
function N.Multiplier(value) return (string.format('%.2f',value):gsub('0+$',''):gsub('%.$','')) end
function N.Format(value)
 local v=tonumber(value) or 0
 if v~=v then return '0' end
 if v==math.huge then return '∞' end
 local sign=v<0 and '-' or ''; v=math.abs(v)
 if v<1000 then return sign..(string.format('%.1f',v):gsub('%.0$','')) end
 local power=math.floor(math.log10(v)/3)
 if power<=#suffixes then return sign..string.format('%.2f',v/1000^power)..suffixes[power] end
 local exponent=math.floor(math.log10(v))
 return sign..string.format('%.2f',v/10^exponent)..'e'..exponent
end
return N
]====])
source(modules,'StageConfig','ModuleScript',[====[return {
 {threshold=0,name='Basic Reactor',color=Color3.fromRGB(40,207,255)},
 {threshold=10000,name='Ringed Reactor',color=Color3.fromRGB(55,229,244)},
 {threshold=1000000,name='Fusion Reactor',color=Color3.fromRGB(135,245,223)},
 {threshold=100000000,name='Quantum Reactor',color=Color3.fromRGB(119,175,255)},
 {threshold=10000000000,name='Singularity Reactor',color=Color3.fromRGB(255,196,112)},
}
]====])
source(modules,'UpgradeConfig','ModuleScript',[====[return {
 {id='cranks',name='Reinforced Cranks',requires='crank',count=10,cost=300,target='crank',mult=2,effect='Hand Crank ×2'},
 {id='wiring',name='Improved Wiring',requires='battery',count=15,cost=20000,target='all',mult=2,effect='All production ×2'},
 {id='cooling',name='Efficient Cooling',requires='diesel',count=15,cost=150000,target='generators',mult=1.5,effect='All generators ×1.5'},
 {id='overclock',name='Overclocking',requires='nuclear',count=10,cost=300000,target='nuclear',mult=2,effect='Nuclear Reactor ×2'},
 {id='containment',name='Fusion Containment',requires='fusion',count=1,cost=750000,target='fusion',mult=2,effect='Fusion Core ×2'},
 {id='physics',name='Experimental Physics',requires='quantum',count=1,cost=25000000,target='quantum',mult=3,effect='Quantum Reactor ×3'},
 {id='artsing',name='Artificial Singularity',requires='singularity',count=1,cost=1000000000,target='all',mult=2,effect='All production ×2'},
}
]====])
source(services,'DataService','ModuleScript',[====[local Players=game:GetService('Players')
local DSS=game:GetService('DataStoreService')
local RS=game:GetService('ReplicatedStorage')
local F=require(RS.Modules.Formulas)
local G=require(RS.Modules.GeneratorConfig)
local U=require(RS.Modules.UpgradeConfig)
local N=require(RS.Modules.NumberFormatter)
local D={}; local profiles={}; local store
local function number(v,default,integer)
 if type(v)~='number' or v~=v or v<0 or v==math.huge then return default end
 return integer and math.floor(v) or v
end
function D.Apply(p,data,now)
 data=type(data)=='table' and data or {}
 p:SetAttribute('Energy',number(data.Energy,0))
 p:SetAttribute('RunEnergy',number(data.RunEnergy,0))
 p:SetAttribute('HighestEnergy',number(data.HighestEnergy,0))
 p:SetAttribute('PowerCores',number(data.PowerCores,0,true))
 p:SetAttribute('Reboots',number(data.Reboots,0,true))
 for _,g in ipairs(G) do
  local count=type(data.generators)=='table' and data.generators[g.id] or 0
  p:SetAttribute('Gen_'..g.id,number(count,0,true))
 end
 for _,u in ipairs(U) do p:SetAttribute('Upg_'..u.id,type(data.upgrades)=='table' and data.upgrades[u.id]==true) end
 local eps=F.Production(p); p:SetAttribute('EnergyPerSecond',eps)
 local offline=0
 if type(data.LastOnline)=='number' then
  offline=math.clamp((now or os.time())-number(data.LastOnline,now or os.time()),0,28800)*eps*0.5
 end
 p:SetAttribute('Energy',p:GetAttribute('Energy')+offline)
 p:SetAttribute('RunEnergy',p:GetAttribute('RunEnergy')+offline)
 p:SetAttribute('HighestEnergy',math.max(p:GetAttribute('HighestEnergy'),p:GetAttribute('Energy')))
 p:SetAttribute('OfflineEarned',offline)
end
function D.Serialize(p,now)
 local data={generators={},upgrades={},LastOnline=now or os.time()}
 for _,key in ipairs({'Energy','RunEnergy','HighestEnergy','PowerCores','Reboots'}) do data[key]=p:GetAttribute(key) or 0 end
 for _,g in ipairs(G) do data.generators[g.id]=p:GetAttribute('Gen_'..g.id) or 0 end
 for _,u in ipairs(U) do if p:GetAttribute('Upg_'..u.id) then data.upgrades[u.id]=true end end
 return data
end
function D.UpdateLeaderboard(p)
 local stats=p:FindFirstChild('leaderstats'); if not stats then return end
 stats.Energy.Value=N.Format(p:GetAttribute('Energy') or 0)
 stats.PowerCores.Value=math.min(2147483647,p:GetAttribute('PowerCores') or 0)
end
function D.Load(p)
 p:SetAttribute('DataReady',false)
 D.Apply(p,nil)
 local stats=Instance.new('Folder'); stats.Name='leaderstats'; stats.Parent=p
 local energy=Instance.new('StringValue'); energy.Name='Energy'; energy.Parent=stats
 local cores=Instance.new('IntValue'); cores.Name='PowerCores'; cores.Parent=stats
 local success,data=false,nil
 for attempt=1,3 do
  success,data=pcall(function() return store:GetAsync('u_'..p.UserId) end)
  if success then break end
  if attempt<3 then task.wait(attempt) end
 end
 if not p.Parent then return end
 profiles[p]={canSave=success,saving=false}
 p:SetAttribute('DataLoadFailed',not success)
 p:SetAttribute('DataSaveFailed',false)
 D.Apply(p,success and data or nil)
 D.UpdateLeaderboard(p)
 p:SetAttribute('DataReady',true)
 if not success then warn('[PowerCore] Data load unavailable; this session will not overwrite saved progress.') end
end
function D.Save(p)
 local profile=profiles[p]
 if p:GetAttribute('DataLoadFailed') or not profile or not profile.canSave or not p:GetAttribute('DataReady') then return false end
 while profile.saving do task.wait(0.05) end
 profile.saving=true
 local data=D.Serialize(p)
 local success=pcall(function() store:UpdateAsync('u_'..p.UserId,function() return data end) end)
 profile.saving=false
 p:SetAttribute('DataSaveFailed',not success)
 return success
end
function D.Start()
 local ok,result=pcall(function() return DSS:GetDataStore('PowerCore_v1') end)
 if ok then store=result end
 Players.PlayerAdded:Connect(function(p) task.spawn(D.Load,p) end)
 for _,p in ipairs(Players:GetPlayers()) do task.spawn(D.Load,p) end
 Players.PlayerRemoving:Connect(function(p) D.Save(p); profiles[p]=nil end)
 task.spawn(function() while task.wait(60) do for _,p in ipairs(Players:GetPlayers()) do task.spawn(D.Save,p) end end end)
 game:BindToClose(function()
  local remaining=0
  for _,p in ipairs(Players:GetPlayers()) do remaining+=1; task.spawn(function() D.Save(p); remaining-=1 end) end
  local deadline=os.clock()+25
  while remaining>0 and os.clock()<deadline do task.wait(0.1) end
 end)
end
return D
]====])
source(services,'EnergyService','ModuleScript',[====[local Players=game:GetService('Players')
local F=require(game.ReplicatedStorage.Modules.Formulas)
local D=require(script.Parent.DataService)
local E={}; local taps=setmetatable({},{__mode='k'})
function E.Refresh(p) p:SetAttribute('EnergyPerSecond',F.Production(p)); D.UpdateLeaderboard(p) end
function E.Add(p,amount)
 p:SetAttribute('Energy',(p:GetAttribute('Energy') or 0)+amount)
 p:SetAttribute('RunEnergy',(p:GetAttribute('RunEnergy') or 0)+amount)
 p:SetAttribute('HighestEnergy',math.max(p:GetAttribute('HighestEnergy') or 0,p:GetAttribute('Energy')))
 D.UpdateLeaderboard(p)
end
function E.Tap(p)
 if not p:GetAttribute('DataReady') then return false end
 local now=os.clock(); local recent=taps[p] or {}; taps[p]=recent
 while #recent>0 and now-recent[1]>=1 do table.remove(recent,1) end
 if #recent>=15 then return false end
 table.insert(recent,now); E.Add(p,1); return true
end
function E.TickPlayer(p)
 if p:GetAttribute('DataReady') then E.Add(p,p:GetAttribute('EnergyPerSecond') or 1) end
end
function E.Start()
 workspace.PowerFacility.ReactorHitbox.ClickDetector.MouseClick:Connect(E.Tap)
 task.spawn(function() while task.wait(1) do for _,p in ipairs(Players:GetPlayers()) do E.TickPlayer(p) end end end)
end
return E
]====])
source(services,'PrestigeService','ModuleScript',[====[local RS=game:GetService('ReplicatedStorage')
local F=require(RS.Modules.Formulas)
local G=require(RS.Modules.GeneratorConfig)
local U=require(RS.Modules.UpgradeConfig)
local E=require(script.Parent.EnergyService)
local D=require(script.Parent.DataService)
local P=require(script.Parent.PurchaseService)
local R={}
function R.Reboot(p)
 if not p:GetAttribute('DataReady') then return false end
 local reward=F.CoreReward(p:GetAttribute('RunEnergy') or 0)
 if reward<1 then return false end
 p:SetAttribute('PowerCores',(p:GetAttribute('PowerCores') or 0)+reward)
 p:SetAttribute('Reboots',(p:GetAttribute('Reboots') or 0)+1)
 p:SetAttribute('Energy',0); p:SetAttribute('RunEnergy',0)
 for _,g in ipairs(G) do p:SetAttribute('Gen_'..g.id,0) end
 for _,u in ipairs(U) do p:SetAttribute('Upg_'..u.id,false) end
 E.Refresh(p); task.spawn(D.Save,p); return true
end
function R.Start() RS.Remotes.Reboot.OnServerEvent:Connect(function(p) if P.AllowRequest(p) then R.Reboot(p) end end) end
return R
]====])
source(services,'PurchaseService','ModuleScript',[====[local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local F=require(RS.Modules.Formulas)
local E=require(script.Parent.EnergyService)
local P={}; local requests=setmetatable({},{__mode='k'})
function P.AllowRequest(p)
 local now=os.clock()
 if not p:GetAttribute('DataReady') or now-(requests[p] or -1)<0.1 then return false end
 requests[p]=now; return true
end
function P.BuyGenerator(p,id,amount)
 if not p:GetAttribute('DataReady') or type(id)~='string' or not F.Generators[id] then return false end
 if amount~=1 and amount~=10 and amount~=100 and amount~='max' then return false end
 local owned=p:GetAttribute('Gen_'..id) or 0; local energy=p:GetAttribute('Energy') or 0
 local n=amount=='max' and F.MaxAffordable(id,owned,energy) or amount
 if n<1 then return false end
 local cost=F.Cost(id,owned,n)
 if cost>energy or cost~=cost or cost==math.huge then return false end
 p:SetAttribute('Energy',math.max(0,energy-cost)); p:SetAttribute('Gen_'..id,owned+n)
 E.Refresh(p); return true
end
function P.BuyUpgrade(p,id)
 if not p:GetAttribute('DataReady') or type(id)~='string' then return false end
 local u=F.Upgrades[id]
 if not u or p:GetAttribute('Upg_'..id) or (p:GetAttribute('Gen_'..u.requires) or 0)<u.count then return false end
 local energy=p:GetAttribute('Energy') or 0
 if energy<u.cost then return false end
 p:SetAttribute('Energy',energy-u.cost); p:SetAttribute('Upg_'..id,true); E.Refresh(p); return true
end
function P.Start()
 RS.Remotes.BuyGenerator.OnServerEvent:Connect(function(p,id,amount) if P.AllowRequest(p) then P.BuyGenerator(p,id,amount) end end)
 RS.Remotes.BuyUpgrade.OnServerEvent:Connect(function(p,id) if P.AllowRequest(p) then P.BuyUpgrade(p,id) end end)
 Players.PlayerRemoving:Connect(function(p) requests[p]=nil end)
end
return P
]====])
source(gui,'UIController','LocalScript',[====[local Players=game:GetService('Players')
local TweenService=game:GetService('TweenService')
local UIS=game:GetService('UserInputService')
local RS=game:GetService('ReplicatedStorage')
local player=Players.LocalPlayer
local gui=script.Parent
local modules=RS:WaitForChild('Modules')
local G=require(modules.GeneratorConfig); local U=require(modules.UpgradeConfig)
local F=require(modules.Formulas); local N=require(modules.NumberFormatter); local stages=require(modules.StageConfig)
local remotes=RS:WaitForChild('Remotes')
local C={bg=Color3.fromRGB(12,20,30),panel=Color3.fromRGB(20,31,44),row=Color3.fromRGB(27,41,56),line=Color3.fromRGB(56,80,99),text=Color3.fromRGB(232,244,251),muted=Color3.fromRGB(161,186,203),cyan=Color3.fromRGB(58,221,242),amber=Color3.fromRGB(255,191,92),disabled=Color3.fromRGB(51,64,79)}
local function make(class,parent,name,props)
 local o=Instance.new(class); o.Name=name
 for k,v in pairs(props or {}) do o[k]=v end
 o.Parent=parent; return o
end
local function frame(parent,name,props)
 props=props or {}; props.BorderSizePixel=0
 return make('Frame',parent,name,props)
end
local function round(o,r) make('UICorner',o,'Corner',{CornerRadius=UDim.new(0,r or 8)}) end
local function stroke(o,color) return make('UIStroke',o,'Stroke',{Color=color or C.line,Thickness=1,Transparency=0.3}) end
local function label(parent,name,text,props)
 local defaults={BackgroundTransparency=1,Text=text,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=16,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,BorderSizePixel=0}
 for k,v in pairs(props or {}) do defaults[k]=v end
 return make('TextLabel',parent,name,defaults)
end
local function tween(o,props,time) return TweenService:Create(o,TweenInfo.new(time or 0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props) end
local function button(parent,name,text,callback,props)
 local b=make('TextButton',parent,name,{Text=text,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=C.bg,BackgroundColor3=C.cyan,BorderSizePixel=0,AutoButtonColor=false,Selectable=true})
 for k,v in pairs(props or {}) do b[k]=v end
 round(b,7)
 local scale=make('UIScale',b,'HoverScale',{Scale=1})
 b.MouseEnter:Connect(function() if b:GetAttribute('Enabled')~=false then tween(scale,{Scale=1.025}):Play() end end)
 b.MouseLeave:Connect(function() tween(scale,{Scale=1}):Play() end)
 b.Activated:Connect(function()
  if b:GetAttribute('Enabled')==false then return end
  scale.Scale=0.96; tween(scale,{Scale=1},0.12):Play(); callback()
 end)
 return b
end
local function enabled(b,value,accent)
 b:SetAttribute('Enabled',value); b.Active=value
 b.BackgroundColor3=value and (accent or C.cyan) or C.disabled
 b.TextColor3=value and C.bg or C.muted
end
local root=frame(gui,'HUD',{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
make('UIScale',root,'ResponsiveScale',{Scale=1})
local feedback=make('BindableEvent',gui,'VisualFeedback')
local top=frame(root,'TopBar',{BackgroundColor3=C.bg,Size=UDim2.new(0,660,0,78),Position=UDim2.new(0.5,0,0,14),AnchorPoint=Vector2.new(0.5,0)})
round(top); stroke(top)
local counters={}
for i,entry in ipairs({{'Energy','ENERGY',C.cyan},{'EnergyPerSecond','ENERGY / SEC',C.text},{'PowerCores','POWER CORES',C.amber}}) do
 local col=frame(top,entry[1],{BackgroundTransparency=1,Position=UDim2.fromScale((i-1)/3,0),Size=UDim2.fromScale(1/3,1)})
 label(col,'Caption',entry[2],{Position=UDim2.new(0,14,0,12),Size=UDim2.new(1,-28,0,16),TextSize=11,TextColor3=C.muted,Font=Enum.Font.GothamBold})
 counters[entry[1]]=label(col,'Value','0',{Position=UDim2.new(0,14,0,32),Size=UDim2.new(1,-28,0,32),TextSize=25,TextColor3=entry[3],Font=Enum.Font.GothamBold})
 if i>1 then frame(col,'Divider',{BackgroundColor3=C.line,Size=UDim2.new(0,1,0.55,0),Position=UDim2.fromScale(0,0.23)}) end
end
local progress=frame(root,'ReactorProgress',{BackgroundColor3=C.bg,BackgroundTransparency=0.12,Size=UDim2.new(0,490,0,45),Position=UDim2.new(0.5,0,0,102),AnchorPoint=Vector2.new(0.5,0)})
round(progress)
local progressText=label(progress,'Stage','Basic Reactor',{Size=UDim2.new(1,-24,0,25),Position=UDim2.new(0,12,0,3),TextSize=12,TextXAlignment=Enum.TextXAlignment.Center,TextColor3=C.muted})
local track=frame(progress,'Track',{Size=UDim2.new(1,-24,0,4),Position=UDim2.new(0,12,1,-10),BackgroundColor3=C.disabled}); round(track,3)
local fill=frame(track,'Fill',{Size=UDim2.fromScale(0,1),BackgroundColor3=C.cyan}); round(fill,3)
local multiplier=label(root,'Multiplier','PRODUCTION  ×1',{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-14),Size=UDim2.new(0,350,0,26),TextXAlignment=Enum.TextXAlignment.Center,TextColor3=C.cyan,Font=Enum.Font.GothamBold,TextSize=13})
local left=frame(root,'LeftNav',{BackgroundTransparency=1,Size=UDim2.new(0,140,0,110),Position=UDim2.new(0,22,0.36,0)})
local right=frame(root,'RightNav',{BackgroundTransparency=1,Size=UDim2.new(0,140,0,110),Position=UDim2.new(1,-162,0.36,0)})
local modal=frame(root,'Panel',{Visible=false,Size=UDim2.new(0,730,0.7,0),Position=UDim2.fromScale(0.5,0.54),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=C.panel,ZIndex=5})
round(modal,10); stroke(modal)
local heading=label(modal,'Heading','Generators',{Position=UDim2.new(0,20,0,15),Size=UDim2.new(1,-90,0,28),TextSize=23,Font=Enum.Font.GothamBold,ZIndex=6})
local subtitle=label(modal,'Subtitle','Turn Energy into passive production.',{Position=UDim2.new(0,20,0,47),Size=UDim2.new(1,-40,0,25),TextSize=12,TextColor3=C.muted,TextWrapped=true,ZIndex=6})
button(modal,'Close','×',function() modal.Visible=false end,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,12),Size=UDim2.new(0,44,0,44),BackgroundColor3=C.row,TextColor3=C.text,TextSize=24,ZIndex=6})
local amounts=frame(modal,'Amounts',{BackgroundTransparency=1,Position=UDim2.new(0,16,0,82),Size=UDim2.new(1,-32,0,42),ZIndex=6})
local selected=1; local amountButtons={}
local scroll=make('ScrollingFrame',modal,'Content',{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0,12,0,135),Size=UDim2.new(1,-24,1,-149),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=4,ScrollBarImageColor3=C.cyan,ZIndex=6})
make('UIPadding',scroll,'Padding',{PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,8)})
make('UIListLayout',scroll,'List',{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
local rows={}; local upgRows={}; local statRows={}; local current='Generators'; local refresh; local compactMode=false
local function row(name,order,height)
 local r=frame(scroll,name,{Size=UDim2.new(1,0,0,height or 94),BackgroundColor3=C.row,LayoutOrder=order,ZIndex=6}); round(r)
 return r
end
for i,g in ipairs(G) do
 local r=row('Generator_'..g.id,i)
 local title=label(r,'Name',g.name,{Position=UDim2.new(0,12,0,10),Size=UDim2.new(0.7,-12,0,23),TextSize=17,Font=Enum.Font.GothamBold,ZIndex=7})
 local owned=label(r,'Owned','0 owned',{Position=UDim2.new(0.7,0,0,10),Size=UDim2.new(0.3,-12,0,23),TextSize=12,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=7})
 local production=label(r,'Production','1 / sec each',{Position=UDim2.new(0,12,0,38),Size=UDim2.new(0.68,-12,0,20),TextSize=12,TextColor3=C.cyan,ZIndex=7})
 local cost=label(r,'Cost','10 Energy',{Position=UDim2.new(0,12,0,63),Size=UDim2.new(0.68,-12,0,19),TextSize=12,TextColor3=C.muted,ZIndex=7})
 local buy=button(r,'Buy','Buy',function() remotes.BuyGenerator:FireServer(g.id,selected) end,{Position=UDim2.new(0.71,0,0,40),Size=UDim2.new(0.27,-8,0,44),ZIndex=7})
 rows[g.id]={frame=r,title=title,owned=owned,production=production,cost=cost,buy=buy}
end
for i,u in ipairs(U) do
 local r=row('Upgrade_'..u.id,20+i,109)
 label(r,'Name',u.name,{Position=UDim2.new(0,12,0,10),Size=UDim2.new(1,-24,0,22),TextSize=16,Font=Enum.Font.GothamBold,ZIndex=7})
 label(r,'Effect',u.effect,{Position=UDim2.new(0,12,0,36),Size=UDim2.new(0.68,-12,0,20),TextSize=12,TextColor3=C.cyan,ZIndex=7})
 local gen=F.Generators[u.requires]
 label(r,'Requirement',u.count..' '..gen.name..(u.count>1 and 's' or ''),{Position=UDim2.new(0,12,0,58),Size=UDim2.new(0.68,-12,0,18),TextSize=11,TextColor3=C.muted,ZIndex=7})
 local cost=label(r,'Cost',N.Format(u.cost)..' Energy',{Position=UDim2.new(0,12,0,82),Size=UDim2.new(0.68,-12,0,18),TextSize=12,TextColor3=C.muted,ZIndex=7})
 local buy=button(r,'Buy','Buy',function() remotes.BuyUpgrade:FireServer(u.id) end,{Position=UDim2.new(0.71,0,0,52),Size=UDim2.new(0.27,-8,0,44),ZIndex=7})
 upgRows[u.id]={frame=r,buy=buy,cost=cost}
end
local empty=label(scroll,'Empty','No upgrades unlocked yet.\nOwn 10 Hand Cranks to unlock Reinforced Cranks.',{Size=UDim2.new(1,0,0,100),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center,TextColor3=C.muted,LayoutOrder=40,TextSize=15,ZIndex=7})
local statNames={{'Energy','Energy balance'},{'EnergyPerSecond','Energy per second'},{'RunEnergy','Energy earned this run'},{'HighestEnergy','Highest balance ever'},{'PowerCores','Permanent Power Cores'},{'Reboots','Reboots completed'},{'Multiplier','Production multiplier'}}
for i,entry in ipairs(statNames) do
 local r=row('Stat_'..entry[1],50+i,48)
 label(r,'Name',entry[2],{Position=UDim2.new(0,12,0,0),Size=UDim2.new(0.7,-12,1,0),TextColor3=C.muted,TextSize=13,ZIndex=7})
 local value=label(r,'Value','0',{Position=UDim2.fromScale(0.65,0),Size=UDim2.new(0.35,-12,1,0),TextXAlignment=Enum.TextXAlignment.Right,Font=Enum.Font.GothamBold,TextSize=16,ZIndex=7})
 statRows[entry[1]]={frame=r,value=value}
end
local rebootContent=row('RebootContent',70,310)
local rebootReward=label(rebootContent,'Reward','+3 Power Cores',{Position=UDim2.new(0,18,0,22),Size=UDim2.new(1,-36,0,54),TextColor3=C.amber,TextSize=26,TextScaled=true,TextWrapped=true,Font=Enum.Font.GothamBold,ZIndex=7})
make('UITextSizeConstraint',rebootReward,'TextLimit',{MinTextSize=12,MaxTextSize=26})
local rebootDetail=label(rebootContent,'Detail','',{Position=UDim2.new(0,18,0,74),Size=UDim2.new(1,-36,0,57),TextWrapped=true,TextSize=15,ZIndex=7})
label(rebootContent,'Resets','Resets Energy, this run, generators and upgrades.\nKeeps Power Cores, Reboots and your highest balance.',{Position=UDim2.new(0,18,0,139),Size=UDim2.new(1,-36,0,64),TextWrapped=true,TextSize=13,TextColor3=C.muted,ZIndex=7})
local confirmArmed=false
local confirm
confirm=button(rebootContent,'Confirm','Reboot facility',function()
 if not confirmArmed then confirmArmed=true; confirm.Text='Confirm Reboot'; return end
 remotes.Reboot:FireServer(); confirmArmed=false; modal.Visible=false
end,{Position=UDim2.new(0,18,0,219),Size=UDim2.new(1,-36,0,48),BackgroundColor3=C.amber,ZIndex=7})
label(rebootContent,'ConfirmationHint','Requires a second click to confirm.',{Position=UDim2.new(0,18,0,277),Size=UDim2.new(1,-36,0,19),TextColor3=C.muted,TextSize=11,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=7})
local nav={}
local function open(name)
 if name=='Reboot' and (player:GetAttribute('RunEnergy') or 0)<1e6 then return end
 current=name; confirmArmed=false; confirm.Text='Reboot facility'
 modal.Visible=true; scroll.CanvasPosition=Vector2.zero
 heading.Text=name; subtitle.Text=({Generators='Turn Energy into passive production.',Upgrades='Unlock technology. Amplify your production.',Reboot='Trade this run for permanent Power Cores.',Stats='Your facility at a glance.'})[name]
 refresh()
end
nav.Generators=button(left,'Generators','Generators',function() open('Generators') end,{Size=UDim2.new(1,0,0,48)})
nav.Upgrades=button(left,'Upgrades','Upgrades',function() open('Upgrades') end,{Size=UDim2.new(1,0,0,48),Position=UDim2.new(0,0,0,58),BackgroundColor3=C.panel,TextColor3=C.text})
nav.Reboot=button(right,'Reboot','Reboot',function() open('Reboot') end,{Size=UDim2.new(1,0,0,48),BackgroundColor3=C.amber})
local rebootStroke=stroke(nav.Reboot,C.amber)
nav.Stats=button(right,'Stats','Stats',function() open('Stats') end,{Size=UDim2.new(1,0,0,48),Position=UDim2.new(0,0,0,58),BackgroundColor3=C.panel,TextColor3=C.text})
local unlockPulse=TweenService:Create(rebootStroke,TweenInfo.new(0.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=0,Thickness=2})
local wasUnlocked=false
for i,amount in ipairs({1,10,100,'max'}) do
 local b=button(amounts,'Buy'..tostring(amount),'Buy '..tostring(amount=='max' and 'Max' or amount),function() selected=amount; refresh() end,{Size=UDim2.new(0.25,-6,1,0),Position=UDim2.new((i-1)*0.25,0,0,0),ZIndex=7})
 amountButtons[amount]=b
end
local warning=label(root,'SaveWarning','',{Visible=false,Position=UDim2.new(0.5,0,1,-44),AnchorPoint=Vector2.new(0.5,1),Size=UDim2.new(0.9,0,0,24),BackgroundTransparency=0.08,BackgroundColor3=C.bg,TextColor3=C.amber,TextWrapped=true,TextSize=11,ZIndex=12,TextXAlignment=Enum.TextXAlignment.Center})
round(warning)
local toast=label(root,'Toast','',{Visible=false,Size=UDim2.new(0.8,0,0,65),Position=UDim2.fromScale(0.5,0.75),AnchorPoint=Vector2.new(0.5,0.5),TextXAlignment=Enum.TextXAlignment.Center,TextColor3=C.cyan,TextWrapped=true,TextSize=18,Font=Enum.Font.GothamBold,ZIndex=15})
local toastVersion=0
local function notify(text,color)
 toastVersion+=1; local v=toastVersion; toast.Text=text; toast.TextColor3=color or C.cyan; toast.Visible=true; toast.TextTransparency=0
 task.delay(3,function() if v~=toastVersion then return end tween(toast,{TextTransparency=1},0.35):Play(); task.delay(0.4,function() if v==toastVersion then toast.Visible=false end end) end)
end
local counterValue=make('NumberValue',gui,'DisplayedEnergy',{Value=player:GetAttribute('Energy') or 0})
counterValue.Changed:Connect(function(value) counters.Energy.Text=N.Format(value) end)
local energyTween; local lastEnergy=-1
local function attr(name) return player:GetAttribute(name) or 0 end
local welcomeShown=false
refresh=function()
 local energy=attr('Energy'); local eps=attr('EnergyPerSecond'); local ready=player:GetAttribute('DataReady')==true
 if energy~=lastEnergy then
  lastEnergy=energy; if energyTween then energyTween:Cancel() end
  energyTween=tween(counterValue,{Value=energy},0.35); energyTween:Play()
 end
 counters.EnergyPerSecond.Text=N.Format(eps); counters.PowerCores.Text=N.Format(attr('PowerCores'))
 multiplier.Text='PRODUCTION  ×'..N.Multiplier(F.Multiplier(player))
 local index=1; local run=attr('RunEnergy')
 for i,s in ipairs(stages) do if run>=s.threshold then index=i end end
 local nextStage=stages[index+1]
 if nextStage then
  progressText.Text=nextStage.name..'  ·  '..N.Format(run)..' / '..N.Format(nextStage.threshold)
  tween(fill,{Size=UDim2.fromScale(math.clamp((run-stages[index].threshold)/(nextStage.threshold-stages[index].threshold),0,1),1)}):Play()
 else progressText.Text='Singularity Reactor  ·  Maximum evolution'; fill.Size=UDim2.fromScale(1,1) end
 amounts.Visible=current=='Generators'
 local contentTop=compactMode and (current=='Generators' and 92 or 44) or (current=='Generators' and 135 or 83)
 scroll.Position=UDim2.new(0,12,0,contentTop)
 scroll.Size=UDim2.new(1,-24,1,-contentTop-10)
 for amount,b in pairs(amountButtons) do b.BackgroundColor3=selected==amount and C.cyan or C.disabled; b.TextColor3=selected==amount and C.bg or C.text end
 for _,g in ipairs(G) do
  local r=rows[g.id]; local owned=attr('Gen_'..g.id)
  local n=selected=='max' and F.MaxAffordable(g.id,owned,energy) or selected
  local cost=F.Cost(g.id,owned,n)
  r.frame.Visible=current=='Generators'; r.owned.Text=N.Format(owned)..' owned'
  r.production.Text=N.Format(F.GeneratorOutput(player,g.id)*F.Multiplier(player))..' / sec total'
  r.cost.Text=n>0 and N.Format(cost)..' Energy' or 'Need '..N.Format(F.Cost(g.id,owned,1))..' Energy'
  r.buy.Text=selected=='max' and ('Buy '..n) or 'Buy'; enabled(r.buy,ready and n>0 and cost<=energy)
 end
 local available=0
 for _,u in ipairs(U) do
  local r=upgRows[u.id]; local bought=player:GetAttribute('Upg_'..u.id)==true
  local unlocked=attr('Gen_'..u.requires)>=u.count or bought
  r.frame.Visible=current=='Upgrades' and unlocked
  if unlocked then available+=1 end
  r.buy.Text=bought and 'Owned' or 'Buy'; r.cost.Text=bought and 'Purchased' or N.Format(u.cost)..' Energy'
  if r.frame:GetAttribute('Purchased')~=bought then
   r.frame:SetAttribute('Purchased',bought)
   tween(r.frame,{BackgroundColor3=bought and Color3.fromRGB(22,58,61) or C.row},0.3):Play()
  end
  enabled(r.buy,ready and unlocked and not bought and energy>=u.cost)
 end
 empty.Visible=current=='Upgrades' and available==0
 for key,r in pairs(statRows) do r.frame.Visible=current=='Stats'; r.value.Text=key=='Multiplier' and '×'..N.Multiplier(F.Multiplier(player)) or N.Format(attr(key)) end
 rebootContent.Visible=current=='Reboot'
 local reward=F.CoreReward(run); rebootReward.Text='+'..N.Integer(reward)..' Power Cores'
 rebootDetail.Text='Run earned: '..N.Format(run)..' Energy\nNew production multiplier: ×'..N.Multiplier(1+0.25*(attr('PowerCores')+reward))
 enabled(confirm,ready and reward>0,C.amber)
 enabled(nav.Reboot,ready and reward>0,C.amber)
 nav.Reboot.Text=reward>0 and 'Reboot  +'..N.Format(reward) or 'Reach 1M to Reboot'; nav.Reboot.TextWrapped=true
 local unlocked=ready and reward>0
 if unlocked~=wasUnlocked then
  wasUnlocked=unlocked
  if unlocked then unlockPulse:Play(); notify('REBOOT AVAILABLE  ·  Earn '..N.Format(reward)..' Power Cores',C.amber)
  else unlockPulse:Cancel(); rebootStroke.Transparency=0.7; rebootStroke.Thickness=1 end
 end
 warning.Visible=not ready or player:GetAttribute('DataLoadFailed')==true or player:GetAttribute('DataSaveFailed')==true
 warning.Text=not ready and 'Loading facility data…' or player:GetAttribute('DataLoadFailed')==true and 'Saving unavailable · This session will not save.' or 'Saving failed · Autosave will retry.'
 if ready and not welcomeShown then welcomeShown=true; if attr('OfflineEarned')>0 then notify('WELCOME BACK\nYou generated '..N.Format(attr('OfflineEarned'))..' Energy while offline.') end end
end
local queued=false
player.AttributeChanged:Connect(function()
 if queued then return end; queued=true
 task.defer(function() queued=false; refresh() end)
end)
local lastEPS=attr('EnergyPerSecond'); local lastReboots=attr('Reboots'); local counts={}
for _,g in ipairs(G) do counts['Gen_'..g.id]=attr('Gen_'..g.id) end
for _,u in ipairs(U) do counts['Upg_'..u.id]=player:GetAttribute('Upg_'..u.id)==true end
local purchaseQueued=false
player.AttributeChanged:Connect(function(key)
 if key=='Reboots' and attr('Reboots')>lastReboots then lastReboots=attr('Reboots'); notify('FACILITY REBOOTED  ·  Permanent power increased',C.amber) end
 if counts[key]==nil then return end
 local value=player:GetAttribute(key); local before=counts[key]; counts[key]=value
 if (type(value)=='number' and value>before) or (value==true and before==false) then
  local r=rows[key:sub(5)] or upgRows[key:sub(5)]
  if r then
   local bounce=r.frame:FindFirstChild('PurchaseScale') or make('UIScale',r.frame,'PurchaseScale',{Scale=1})
   bounce.Scale=0.985; tween(bounce,{Scale=1},0.25):Play()
  end
  if purchaseQueued then return end; purchaseQueued=true
  task.defer(function()
   purchaseQueued=false; local currentEPS=attr('EnergyPerSecond'); local gain=math.max(0,currentEPS-lastEPS); lastEPS=currentEPS
   if gain>0 then notify('+'..N.Format(gain)..' ENERGY / SEC'); feedback:Fire('purchase') end
  end)
 end
end)
player:GetAttributeChangedSignal('EnergyPerSecond'):Connect(function() if not purchaseQueued then lastEPS=attr('EnergyPerSecond') end end)
local function layout()
 local vp=root.AbsoluteSize; local compact=vp.Y<450; local phone=vp.X<760 and not compact
 compactMode=compact
 top.Size=phone and UDim2.new(0.94,0,0,compact and 64 or 74) or UDim2.new(0,660,0,compact and 64 or 78)
 if compact then top.Size=UDim2.new(0,math.min(660,vp.X-24),0,64) end
 top.Position=UDim2.new(0.5,0,0,compact and 6 or 14)
 progress.Size=compact and UDim2.new(0,math.min(490,vp.X-250),0,18) or phone and UDim2.new(0.88,0,0,43) or UDim2.new(0,490,0,45)
 progress.Position=UDim2.new(0.5,0,0,compact and 72 or phone and 98 or 102)
 progressText.Size=UDim2.new(1,-24,0,compact and 12 or 25); progressText.Position=UDim2.new(0,12,0,compact and 0 or 3); progressText.TextSize=compact and 10 or 12
 track.Position=UDim2.new(0,12,1,compact and -4 or -10)
 local panelTop=compact and 112 or phone and 210 or 156
 local bottomReserve=phone and 82 or compact and 0 or 80
 modal.Size=UDim2.new(phone and 0.94 or 0,phone and 0 or math.min(730,vp.X-(compact and 248 or 340)),0,math.max(140,vp.Y-panelTop-bottomReserve))
 modal.Position=UDim2.new(0.5,0,0,panelTop); modal.AnchorPoint=Vector2.new(0.5,0)
 subtitle.Visible=not compact; heading.TextSize=compact and 20 or 23; heading.Position=UDim2.new(0,20,0,compact and 8 or 15)
 amounts.Position=UDim2.new(0,16,0,compact and 40 or 82); amounts.Size=UDim2.new(1,compact and -88 or -32,0,44)
 left.Size=phone and UDim2.new(0.47,0,0,48) or UDim2.new(0,compact and 104 or 140,0,110)
 right.Size=left.Size
 left.Position=phone and UDim2.new(0.02,0,0,152) or compact and UDim2.new(0,10,0,112) or UDim2.new(0,22,0.36,0)
 right.Position=phone and UDim2.new(0.51,0,0,152) or compact and UDim2.new(1,-114,0,112) or UDim2.new(1,-162,0.36,0)
 warning.Position=compact and UDim2.new(0.5,0,0,91) or UDim2.new(0.5,0,1,-44)
 warning.AnchorPoint=Vector2.new(0.5,compact and 0 or 1)
 warning.Size=compact and UDim2.new(0.75,0,0,16) or phone and UDim2.new(0.46,0,0,24) or UDim2.new(0.9,0,0,24)
 for _,name in ipairs({'Generators','Upgrades','Reboot','Stats'}) do
  local b=nav[name]; local second=name=='Upgrades' or name=='Stats'
  b.Size=phone and UDim2.new(0.49,-2,1,0) or UDim2.new(1,0,0,48)
  b.Position=phone and UDim2.fromScale(second and 0.51 or 0,0) or UDim2.new(0,0,0,second and 58 or 0)
  b.TextSize=(phone or compact) and 11 or 14
 end
 for _,value in pairs(counters) do value.TextSize=(phone or compact) and 19 or 25 end
 for _,r in pairs(rows) do r.title.TextSize=(phone or compact) and 14 or 17 end
 refresh()
end
root:GetPropertyChangedSignal('AbsoluteSize'):Connect(layout)
UIS.InputBegan:Connect(function(input,processed) if not processed and input.KeyCode==Enum.KeyCode.Escape then modal.Visible=false end end)
local facility=workspace:WaitForChild('PowerFacility')
facility:WaitForChild('UpgradeTerminal'):WaitForChild('OpenPanel').Triggered:Connect(function(p) if p==nil or p==player then open('Upgrades') end end)
facility:WaitForChild('RebootTerminal'):WaitForChild('OpenPanel').Triggered:Connect(function(p) if p==nil or p==player then open('Reboot') end end)
facility.ReactorHitbox.ClickDetector.MouseClick:Connect(function(p)
 if p and p~=player then return end
 local pos=UIS:GetMouseLocation()
 local floating=label(root,'TapFeedback','+1',{Position=UDim2.fromOffset(pos.X-18,pos.Y-55),Size=UDim2.fromOffset(60,36),TextSize=24,TextColor3=C.cyan,Font=Enum.Font.GothamBold,ZIndex=14})
 tween(floating,{Position=floating.Position-UDim2.fromOffset(0,45),TextTransparency=1},0.65):Play()
 task.delay(0.7,function() floating:Destroy() end)
 feedback:Fire('tap')
end)
gui:SetAttribute('UIReady',true)
layout(); refresh()
]====])
source(game:GetService('StarterPlayer').StarterPlayerScripts,'ReactorVisuals','LocalScript',[====[local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local TweenService=game:GetService('TweenService')
local RS=game:GetService('ReplicatedStorage')
local p=Players.LocalPlayer
local N=require(RS:WaitForChild('Modules').NumberFormatter)
local stages=require(RS.Modules.StageConfig)
local G=require(RS.Modules.GeneratorConfig)
local facility=workspace:WaitForChild('PowerFacility')
local anchor=facility:WaitForChild('ReactorAnchor')
local center=anchor.Position
facility:WaitForChild('PlaceholderCore').LocalTransparencyModifier=1
local gui=p:WaitForChild('PlayerGui'):WaitForChild('MainUI')
local feedback=gui:WaitForChild('VisualFeedback')
local visuals=Instance.new('Model'); visuals.Name='LocalReactor'; visuals.Parent=facility
local core; local light; local particles; local plasmaAttachment; local rings={}; local index=0; local pulse=0; local pulseTime=0; local initialized=false
local cyan=Color3.fromRGB(58,221,242)
local function part(parent,name,size,color,shape)
 local v=Instance.new('Part'); v.Name=name; v.Size=size; v.Color=color; v.Anchored=true; v.CanCollide=false; v.CanTouch=false; v.CanQuery=false; v.CastShadow=false; v.Material=Enum.Material.Neon; v.CFrame=CFrame.new(center)
 if shape then v.Shape=shape end
 v.Parent=parent; return v
end
local function ring(radius,color,rotation)
 local model=Instance.new('Model'); model.Name='PlasmaRing'; model.Parent=visuals
 local segments={}
 for i=1,32 do
  local a=i/32*math.pi*2
  local offset=CFrame.Angles(unpack(rotation))*CFrame.new(math.cos(a)*radius,0,math.sin(a)*radius)*CFrame.Angles(0,-a+math.pi/2,0)
  local s=part(model,'Arc',Vector3.new(radius*math.pi*2/32*0.92,0.18,0.45),color)
  s.CFrame=CFrame.new(center)*offset; table.insert(segments,{part=s,offset=offset})
 end
 table.insert(rings,{segments=segments,speed=#rings%2==0 and 0.38 or -0.28})
end
local function sound(name)
 local s=Instance.new('Sound'); s.Name=name; s.SoundId=''; s.Volume=0.3; s.Parent=anchor; return s
end
local sounds={tap=sound('TapSound'),purchase=sound('PurchaseSound'),evolve=sound('EvolutionSound')}
local billboard=Instance.new('BillboardGui'); billboard.Name='ProductionBillboard'; billboard.Adornee=anchor; billboard.Size=UDim2.fromOffset(320,82); billboard.StudsOffset=Vector3.new(0,9.5,0); billboard.AlwaysOnTop=true; billboard.MaxDistance=150; billboard.Parent=gui
local eps=Instance.new('TextLabel'); eps.Name='EnergyPerSecond'; eps.Size=UDim2.fromScale(1,0.6); eps.BackgroundTransparency=1; eps.TextColor3=cyan; eps.Font=Enum.Font.GothamBold; eps.TextSize=24; eps.TextStrokeTransparency=0.5; eps.Parent=billboard
local hint=Instance.new('TextLabel'); hint.Name='TapHint'; hint.Position=UDim2.fromScale(0,0.65); hint.Size=UDim2.fromScale(1,0.3); hint.BackgroundTransparency=1; hint.Text='Tap the reactor!'; hint.TextColor3=Color3.fromRGB(211,237,246); hint.Font=Enum.Font.Gotham; hint.TextSize=14; hint.Parent=billboard
local evo=Instance.new('TextLabel'); evo.Name='EvolutionNotice'; evo.AnchorPoint=Vector2.new(0.5,0.5); evo.Position=UDim2.fromScale(0.5,0.33); evo.Size=UDim2.new(0.86,0,0,82); evo.BackgroundTransparency=1; evo.TextColor3=cyan; evo.Font=Enum.Font.GothamBold; evo.TextSize=28; evo.TextWrapped=true; evo.TextStrokeTransparency=0.5; evo.Visible=false; evo.ZIndex=20; evo.Parent=gui
local evoScale=Instance.new('UIScale'); evoScale.Parent=evo
local evoVersion=0
local function pulseReactor(kind)
 pulse=kind=='tap' and 0.25 or 0.5; pulseTime=os.clock()
 if particles and kind~='tap' then particles:Emit(kind=='evolve' and 70 or 20) end
 local s=sounds[kind]; if s and s.SoundId~='' then s:Play() end
end
local function rebuild(stage,announce)
 index=stage
 visuals:ClearAllChildren(); rings={}
 local spec=stages[stage]; local size=({3.4,4.6,5.2,5.6,5.4})[stage]
 core=part(visuals,'Core',Vector3.one*size,spec.color,Enum.PartType.Ball)
 if stage==5 then core.Color=Color3.fromRGB(3,5,9); core.Material=Enum.Material.SmoothPlastic end
 light=Instance.new('PointLight'); light.Color=spec.color; light.Brightness=2; light.Range=26; light.Parent=core
 if stage>=2 then ring(5.2,spec.color,{0,0,0}) end
 if stage==3 then ring(6.5,spec.color,{math.rad(55),0,0}) end
 if stage==4 then ring(6.9,spec.color,{math.rad(65),0,math.rad(30)}); ring(7.7,Color3.fromRGB(199,232,255),{math.rad(-50),0,math.rad(-35)}) end
 if stage==5 then ring(6.7,spec.color,{0,0,0}); ring(7.8,Color3.fromRGB(255,229,184),{0,0,0}) end
 local attachment=Instance.new('Attachment'); attachment.Parent=core; plasmaAttachment=attachment
 particles=Instance.new('ParticleEmitter'); particles.Name='Plasma'; particles.Color=ColorSequence.new(spec.color); particles.LightEmission=1
 particles.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,0)})
 particles.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(1,1)})
 particles.Lifetime=NumberRange.new(0.5,1.2); particles.Speed=NumberRange.new(3,6); particles.SpreadAngle=Vector2.new(180,180); particles.Rate=stage>=3 and 12 or 0; particles.Parent=attachment
 if stage==5 then
  attachment.Position=Vector3.new(0,0,6)
  particles.EmissionDirection=Enum.NormalId.Back; particles.Acceleration=Vector3.new(0,0,-8); particles.Speed=NumberRange.new(1,3); particles.SpreadAngle=Vector2.new(30,30)
 end
 core:SetAttribute('BaseSize',size)
 eps.TextColor3=spec.color
 if announce then
  evoVersion+=1; local version=evoVersion
  evo.Text='REACTOR EVOLVED\n'..spec.name; evo.TextColor3=spec.color; evo.TextTransparency=0; evo.Visible=true; evoScale.Scale=0.8
  TweenService:Create(evoScale,TweenInfo.new(0.35,Enum.EasingStyle.Back),{Scale=1}):Play(); pulseReactor('evolve')
  task.delay(2.5,function()
   if version~=evoVersion then return end
   TweenService:Create(evo,TweenInfo.new(0.4),{TextTransparency=1}):Play()
   task.delay(0.45,function() if version==evoVersion then evo.Visible=false end end)
  end)
 end
end
local energyScreen=facility:WaitForChild('EnergyDisplay'):WaitForChild('EnergyScreen').Frame.Label
local function update()
 local run=p:GetAttribute('RunEnergy') or 0; local stage=1
 for i,s in ipairs(stages) do if run>=s.threshold then stage=i end end
 if stage~=index then rebuild(stage,initialized and stage>index) end
 if p:GetAttribute('DataReady') then initialized=true end
 eps.Text=N.Format(p:GetAttribute('EnergyPerSecond') or 1)..' ENERGY / SEC'
 energyScreen.Text='ENERGY RESERVE\n'..N.Format(p:GetAttribute('Energy') or 0)
 local owned=0; for _,g in ipairs(G) do owned+=p:GetAttribute('Gen_'..g.id) or 0 end
 TweenService:Create(hint,TweenInfo.new(0.3),{TextTransparency=owned>=5 and 1 or 0}):Play()
end
local queued=false
p.AttributeChanged:Connect(function() if queued then return end; queued=true; task.defer(function() queued=false; update() end) end)
feedback.Event:Connect(pulseReactor)
local start=os.clock()
RunService.RenderStepped:Connect(function()
 if not core then return end
 local time=os.clock()-start; local power=math.clamp(math.log10(math.max(1,p:GetAttribute('EnergyPerSecond') or 1)),0,12)
 local wave=(math.sin(time*(1.4+power*0.45))+1)/2
 local tapPulse=pulse*math.max(0,1-(os.clock()-pulseTime)/0.4)
 local scale=1+wave*(0.04+power*0.005)+tapPulse
 core.Size=Vector3.one*core:GetAttribute('BaseSize')*scale
 local bob=index>=4 and math.sin(time*1.1)*0.6 or 0
 core.CFrame=CFrame.new(center+Vector3.new(0,bob,0))
 light.Brightness=1.5+wave*(1+power*0.2)+tapPulse*5
 if index==4 then core.Color=Color3.fromHSV(0.48+(math.sin(time*0.25)+1)*0.09,0.45,1) end
 if index>=3 then
  local radius=index==5 and 7 or 5.5
  plasmaAttachment.Position=Vector3.new(math.cos(time*0.9)*radius,0,math.sin(time*0.9)*radius)
  if index==5 then particles.Acceleration=-plasmaAttachment.Position*2 end
 end
 for _,r in ipairs(rings) do
  local base=CFrame.new(center+Vector3.new(0,bob,0))*CFrame.Angles(0,time*r.speed*(1+power*0.1),0)
  for _,s in ipairs(r.segments) do s.part.CFrame=base*s.offset end
 end
end)
update()
]====])
source(SSS,'PowerCoreChecks','ModuleScript',[====[-- Catches overspending, unvalidated amounts, incorrect multipliers, excessive taps,
-- lost prestige history, repeated offline rewards and saving after failed loads.
return function()
 local RS=game:GetService('ReplicatedStorage')
 local S=game:GetService('ServerScriptService').Services
 local F=require(RS.Modules.Formulas)
 local N=require(RS.Modules.NumberFormatter)
 local D=require(S.DataService)
 local E=require(S.EnergyService)
 local P=require(S.PurchaseService)
 local R=require(S.PrestigeService)
 local p=Instance.new('Folder'); p.Name='EconomyTest'
 D.Apply(p,nil); p:SetAttribute('DataReady',true)
 local passed=0
 local function check(v,msg) assert(v,msg); passed+=1 end
 local function near(a,b) return math.abs(a-b)<math.max(1,math.abs(b))*1e-9 end
 local large=Instance.new('Folder'); D.Apply(large,{generators={crank=5001}})
 check(large:GetAttribute('Gen_crank')==5001,'loading must preserve legitimately owned generators above 5000')
 large:Destroy()
 check(N.Integer(1003)=='1003','exact reboot integer')
 check(N.Multiplier(1.75)=='1.75' and N.Multiplier(2)=='2','quarter-step multiplier display')
 check(F.Production(p)==1,'starter EPS')
 check(near(F.Cost('crank',0,10),203.037182380527),'geometric bulk cost')
 check(F.MaxAffordable('crank',0,9)==0,'unaffordable max')
 check(F.MaxAffordable('crank',0,10)==1,'exact affordable max')
 for _,balance in ipairs({10,100,1000,1e15,1e50}) do
  local n=F.MaxAffordable('crank',0,balance)
  check(F.Cost('crank',0,n)<=balance,'Max cannot overspend')
  check(F.Cost('crank',0,n+1)>balance,'Max is maximal')
 end
 check(not P.BuyGenerator(p,'crank',10),'reject incomplete bulk purchase')
 check(not P.BuyGenerator(p,'missing',1),'reject unknown id')
 check(not P.BuyGenerator(p,'crank',-1),'reject negative amount')
 check(not P.BuyGenerator(p,'crank',0/0),'reject NaN amount')
 p:SetAttribute('Energy',1e12)
 for _,amount in ipairs({1,10,100}) do check(P.BuyGenerator(p,'crank',amount),'bulk purchase '..amount) end
 check(p:GetAttribute('Gen_crank')==111,'bulk counts')
 p:SetAttribute('Energy',1000); local count=p:GetAttribute('Gen_battery')
 check(P.BuyGenerator(p,'battery','max'),'buy max')
 check(p:GetAttribute('Gen_battery')>count and p:GetAttribute('Energy')>=0,'max balance')
 D.Apply(p,nil); p:SetAttribute('DataReady',true)
 for _=1,30 do E.Tap(p) end
 check(p:GetAttribute('Energy')==15 and p:GetAttribute('RunEnergy')==15,'15 taps/sec')
 D.Apply(p,nil); p:SetAttribute('DataReady',true)
 E.TickPlayer(p)
 check(p:GetAttribute('Energy')==1 and p:GetAttribute('RunEnergy')==1,'production tick')
 check(not P.BuyUpgrade(p,'cranks'),'upgrade requirement')
 p:SetAttribute('Gen_crank',10); p:SetAttribute('Energy',1e10)
 check(P.BuyUpgrade(p,'cranks'),'purchase upgrade')
 check(F.Production(p)==21,'crank upgrade output')
 check(not P.BuyUpgrade(p,'cranks'),'no duplicate upgrades')
 p:SetAttribute('Gen_battery',15); check(P.BuyUpgrade(p,'wiring'),'wiring')
 check(F.Production(p)==192,'all output includes starter')
 p:SetAttribute('Gen_diesel',15); check(P.BuyUpgrade(p,'cooling'),'cooling')
 check(F.Production(p)==1412,'cooling excludes starter')
 p:SetAttribute('PowerCores',3)
 check(F.Production(p)==2471 and F.Multiplier(p)==3.5,'core and global multiplier')
 local fixture=Instance.new('Folder')
 D.Apply(fixture,nil); fixture:SetAttribute('DataReady',true); fixture:SetAttribute('Energy',1e12)
 for _,g in ipairs(require(RS.Modules.GeneratorConfig)) do fixture:SetAttribute('Gen_'..g.id,1) end
 fixture:SetAttribute('Gen_nuclear',10)
 check(P.BuyUpgrade(fixture,'overclock'),'nuclear upgrade')
 check(F.GeneratorOutput(fixture,'nuclear')==3000,'nuclear doubles')
 check(P.BuyUpgrade(fixture,'containment'),'fusion upgrade')
 check(F.GeneratorOutput(fixture,'fusion')==2000,'fusion doubles')
 check(P.BuyUpgrade(fixture,'physics'),'quantum upgrade')
 check(F.GeneratorOutput(fixture,'quantum')==30000,'quantum triples')
 check(P.BuyUpgrade(fixture,'artsing'),'singularity upgrade')
 check(F.Multiplier(fixture)==2,'singularity global multiplier')
 fixture:SetAttribute('Gen_crank',1); fixture:SetAttribute('Gen_nuclear',1); fixture:SetAttribute('PowerCores',4)
 for _,u in ipairs(require(RS.Modules.UpgradeConfig)) do fixture:SetAttribute('Upg_'..u.id,true) end
 check(F.Production(fixture)==63387992,'all seven upgrades across all eight generators')
 fixture:Destroy()
 check(not R.Reboot(p),'reboot locked')
 p:SetAttribute('RunEnergy',1e6); p:SetAttribute('HighestEnergy',9e9)
 check(F.CoreReward(1e6)==3 and F.CoreReward(4e6)==6,'prestige rewards')
 check(R.Reboot(p),'reboot allowed')
 check(p:GetAttribute('PowerCores')==6 and p:GetAttribute('Reboots')==1,'permanent cores')
 check(p:GetAttribute('Energy')==0 and p:GetAttribute('RunEnergy')==0 and p:GetAttribute('Gen_crank')==0 and not p:GetAttribute('Upg_cranks'),'reset run')
 check(p:GetAttribute('HighestEnergy')==9e9 and p:GetAttribute('EnergyPerSecond')==2.5,'keep history and core EPS')
 local save=D.Serialize(p,100)
 check(save.LastOnline==100 and type(save.generators)=='table' and type(save.upgrades)=='table' and save.PowerCores==6,'save schema')
 local snapshot={Energy=100,RunEnergy=500,HighestEnergy=100,PowerCores=0,Reboots=0,generators={crank=1},upgrades={},LastOnline=100}
 D.Apply(p,snapshot,110)
 check(p:GetAttribute('Energy')==110 and p:GetAttribute('RunEnergy')==510 and p:GetAttribute('OfflineEarned')==10,'offline half EPS')
 D.Apply(p,snapshot,100000)
 check(p:GetAttribute('OfflineEarned')==28800,'8 hour cap')
 p:SetAttribute('DataLoadFailed',true)
 check(D.Save(p)==false,'failed load prohibits save')
 check(N.Format(0)=='0' and N.Format(12)=='12' and N.Format(1234567)=='1.23M','number display')
 check(N.Format(123.45)=='123.5' and N.Format(1000)=='1.00K','decimal precision')
 check(string.find(N.Format(1e51),'e51')~=nil,'scientific fallback')
 p:Destroy()
 print('POWER CORE TESTS PASSED: '..passed)
 return passed
end
]====])
source(SSS,'Main','Script',[====[local S=script.Parent.Services
require(S.DataService).Start()
require(S.EnergyService).Start()
require(S.PurchaseService).Start()
require(S.PrestigeService).Start()
print('[PowerCore] Facility economy online.')
]====])
return 'Power Core scripts installed.'