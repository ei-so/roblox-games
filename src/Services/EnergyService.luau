local Players=game:GetService('Players')
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
