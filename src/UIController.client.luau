local Players=game:GetService('Players')
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
