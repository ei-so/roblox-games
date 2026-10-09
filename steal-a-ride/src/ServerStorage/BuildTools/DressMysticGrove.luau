-- Applies generated visual assets only inside the newly authored Mystic Grove.
return function(biome)
 assert(game.PlaceId==123937616497204 and biome.Name=="MysticGrove","Wrong game or biome")
 assert(biome:GetAttribute("MysticBuildVersion"),"Not the authored Mystic map")
 if biome:GetAttribute("MysticGeneratedScenery") then return "Already dressed" end
 local assets=game.ServerStorage:FindFirstChild("MysticGroveAssets20261009")
 assert(assets and assets.MushroomCluster and assets.GroveTree,"Mystic assets missing")
 local native=Instance.new("Folder") native.Name="NativeMysticScenery"
 native.Parent=game.ServerStorage.MysticGroveBackup20261009
 local count=0
 for _,m in ipairs(biome.Props:GetChildren()) do
  local mushroom=m.Name=="MysticMushroom"
  if mushroom or m.Name=="MysticRootTree" then
   local cf,size=m:GetBoundingBox()
   local x,z=m.PrimaryPart and m.PrimaryPart.Position.X or cf.Position.X,m.PrimaryPart and m.PrimaryPart.Position.Z or cf.Position.Z
   local template=mushroom and assets.MushroomCluster or assets.GroveTree
   local copy=template:Clone()
   copy.Name=mushroom and "MysticMushroom" or "MysticRootTree"
   copy:ScaleTo(template:GetScale()*(mushroom and math.clamp(size.Y/18,.65,1.25) or 1))
   copy:PivotTo(CFrame.new())
   local box,s=copy:GetBoundingBox()
   copy:PivotTo(CFrame.new(x,.3-(box.Position.Y-s.Y/2),z)*CFrame.Angles(0,math.rad(count*137),0))
   for _,p in copy:GetDescendants() do if p:IsA("BasePart") then
    p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
   end end
   local collider=Instance.new("Part") collider.Name="TrunkCollider"
   collider.Size=Vector3.new(mushroom and 4 or 5,mushroom and s.Y*.7 or 20,mushroom and 4 or 5)
   collider.CFrame=CFrame.new(x,collider.Size.Y/2+.3,z)
   collider.Anchored=true collider.Transparency=1 collider.CanTouch=false collider.Parent=copy
   copy.Parent=biome.Props m.Parent=native count+=1
  end
 end
 biome:SetAttribute("MysticGeneratedScenery",true)
 return "Dressed Mystic Grove with "..count.." generated scenery instances"
end
