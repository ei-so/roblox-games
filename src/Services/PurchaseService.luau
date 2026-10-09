local Players=game:GetService('Players')
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
