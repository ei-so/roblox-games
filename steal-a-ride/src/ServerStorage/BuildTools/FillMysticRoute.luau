-- Mystic-only centre and nest driveway obstacles; keep multiple mounted weaving routes.
return function(biome)
 assert(game.PlaceId==123937616497204 and biome.Name=="MysticGrove")
 if biome:FindFirstChild("RouteObstacles") then return "Already filled" end
 local folder=Instance.new("Folder");folder.Name="RouteObstacles";folder.Parent=biome
 local rgb,V3=Color3.fromRGB,Vector3.new
 local function part(parent,name,size,cf,color,material,shape)
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=material
  p.Anchored=true;p.CanTouch=false;p.Shape=shape or Enum.PartType.Block;p.Parent=parent;return p
 end
 local function rock(parent,x,z,w,h)
  part(parent,"MossBoulder",V3(w,h,w*.85),CFrame.new(x,.3+h/2,z),rgb(55,84,79),Enum.Material.Slate,Enum.PartType.Ball)
  local cap=part(parent,"MossCrown",V3(w*.82,.6,w*.68),CFrame.new(x,.3+h*.89,z),rgb(72,118,92),Enum.Material.Grass,Enum.PartType.Ball)
  cap.CanCollide=false
 end
 local layout={{0,-2770,"rock"},{-12,-2820,"shroom"},{0,-2870,"root"},{-10,-2925,"rock"},
 {0,-2970,"rock"},{-16,-3020,"tree"},{0,-3070,"shroom"},{0,-3110,"rock"},
 {16,-3200,"root"},{-10,-3255,"shroom"},{14,-3305,"tree"}}
 for i,row in layout do
  local x,z,kind=table.unpack(row)
  local m=Instance.new("Model");m.Name="RouteCluster"..i;m.Parent=folder
  if kind=="rock" then rock(m,x,z,16+i%3*2,9+i%2*3)
  elseif kind=="root" then
   for j=-1,1 do
    part(m,"FallenRoot",V3(32,4,4),CFrame.new(x,2.7+math.abs(j),z+j*4)*CFrame.Angles(0,math.rad(j*18),0),rgb(76,58,85),Enum.Material.Wood,Enum.PartType.Cylinder)
   end
   part(m,"RootStump",V3(10,10,10),CFrame.new(x+8,5.3,z),rgb(72,55,80),Enum.Material.Wood,Enum.PartType.Cylinder).CFrame=CFrame.new(x+8,5.3,z)*CFrame.Angles(0,0,math.pi/2)
  else
   local tree=kind=="tree"
   local copy=(tree and game.ServerStorage.MysticGroveAssets20261009.GroveTree or game.ServerStorage.MysticGroveAssets20261009.MushroomCluster):Clone()
   copy.Name=tree and "MysticRootTree" or "MysticMushroom"
   copy:ScaleTo(copy:GetScale()*(tree and 1.3 or 1.25));copy:PivotTo(CFrame.new())
   local cf,sz=copy:GetBoundingBox()
   copy:PivotTo(CFrame.new(x,.3-cf.Position.Y+sz.Y/2,z)*CFrame.Angles(0,math.rad(i*97),0))
   for _,p in copy:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false end end
   copy.Parent=biome.Props
   local trunk=part(m,"VisibleRootBase",V3(tree and 8 or 12,tree and 14 or 10,tree and 8 or 10),
    CFrame.new(x,tree and 7.3 or 5.3,z),rgb(90,98,91),Enum.Material.Wood,Enum.PartType.Cylinder)
   trunk.CFrame*=CFrame.Angles(0,0,math.pi/2)
   for side=-1,1,2 do
    part(m,"ExposedRoot",V3(tree and 26 or 20,3,3),CFrame.new(x,1.9,z+side*4)*CFrame.Angles(0,math.rad(side*22),0),
     rgb(74,67,83),Enum.Material.Wood,Enum.PartType.Cylinder)
   end
  end
  -- Small clusters on both sides fill the middle without closing the refuge approaches.
  for side=-1,1,2 do
   local sx=side*(37+(i%3)*5);local sz=z+side*12
   for j=1,3 do rock(m,sx+side*(j-2)*5,sz+j*4,4+j,2.5+j*.8) end
  end
 end
 biome:SetAttribute("MysticRouteDensity",1)
 return "Added 11 large route clusters and 66 small moss boulders"
end