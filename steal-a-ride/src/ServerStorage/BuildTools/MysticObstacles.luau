-- Mystic-only obstacle dressing; central 28-stud return corridor stays open.
return function(biome)
 assert(game.PlaceId==123937616497204 and biome.Name=="MysticGrove")
 if biome:FindFirstChild("RootObstacles") then return "Already built" end
 local folder=Instance.new("Folder"); folder.Name="RootObstacles"; folder.Parent=biome
 local function part(name,size,cf,color,material,collide,parent)
  local p=Instance.new("Part"); p.Name=name; p.Size=size; p.CFrame=cf
  p.Color=color; p.Material=material; p.Anchored=true; p.CanCollide=collide; p.CanTouch=false; p.Parent=parent
  return p
 end
 for i,z in {-2775,-2845,-2925,-3000,-3075,-3230,-3300} do
  local side=i%2==0 and -1 or 1
  local m=Instance.new("Model"); m.Name="TangledRoots"; m.Parent=folder
  local x=side*43
  for j=-1,1 do
   part("Root",Vector3.new(48,3+j*.3,3),CFrame.new(x,2.1+math.abs(j),z+j*5)*CFrame.Angles(0,math.rad(j*8),math.rad(j*3)),
    Color3.fromRGB(73,62,82),Enum.Material.Wood,true,m).Shape=Enum.PartType.Cylinder
  end
  for j=1,3 do
   local rock=part("MossRock",Vector3.new(7+j,5,8),CFrame.new(side*(65+j*6),2.5,z+j*8),
    Color3.fromRGB(54,88,78),Enum.Material.Slate,true,m)
   rock.Shape=Enum.PartType.Ball
  end
  local cluster=game.ServerStorage.MysticGroveAssets20261009.MushroomCluster:Clone()
  cluster.Name="MysticMushroom"; cluster:ScaleTo(cluster:GetScale()*.55); cluster:PivotTo(CFrame.new())
  local cf,sz=cluster:GetBoundingBox()
  cluster:PivotTo(CFrame.new(-side*36,.3-cf.Position.Y+sz.Y/2,z+18))
  for _,d in cluster:GetDescendants() do if d:IsA("BasePart") then d.Anchored=true;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false end end
  cluster.Parent=biome.Props
 end
 return "Added seven root obstacles and seven mushroom clusters"
end