local RS=game:GetService('ReplicatedStorage')
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
