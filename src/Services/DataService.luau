local Players=game:GetService('Players')
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
