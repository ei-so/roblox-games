-- Extend only the shared road's old end boundary for Mystic Grove.
return function(biome)
 assert(game.PlaceId==123937616497204 and biome.Name=="MysticGrove")
 local road=workspace.BiomeRoad
 if road:FindFirstChild("MysticRoadExtension") then return "Already extended" end
 local oldEnd
 for _,p in road:GetChildren() do
  if p:IsA("BasePart") and p.Name=="Boundary" and p.Size.X>200 and p.Position.Z<0 then
   assert(not oldEnd,"Ambiguous road end");oldEnd=p
  end
 end
 assert(oldEnd and math.abs(oldEnd.Position.Z+2700.5)<1,"Unexpected original road end")
 oldEnd:SetAttribute("MysticOriginalCFrame",oldEnd.CFrame)
 local newEnd=biome:GetAttribute("FarZ")-15.5
 oldEnd.CFrame=CFrame.new(0,30,newEnd)
 local folder=Instance.new("Folder");folder.Name="MysticRoadExtension";folder.Parent=road
 local from=-2700
 local length=from-(newEnd+.5)
 local center=(from+newEnd+.5)/2
 local function p(name,size,position,transparent)
  local o=Instance.new("Part");o.Name=name;o.Size=size;o.Position=position;o.Anchored=true
  o.Transparency=transparent and 1 or 0;o.Color=biome.Floor.Color;o.Material=biome.Floor.Material;o.Parent=folder
 end
 p("Ground",Vector3.new(220,2,length),Vector3.new(0,-1,center),false)
 for _,x in {-110.5,110.5} do p("Boundary",Vector3.new(1,60,length),Vector3.new(x,30,center),true) end
 return "Road boundary extended to "..newEnd
end