local G=require(script.Parent.GeneratorConfig)
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
