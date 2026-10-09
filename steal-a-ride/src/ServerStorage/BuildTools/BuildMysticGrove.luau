-- Edit-time only. Adds Mystic Grove without rebuilding or moving any existing biome.
local Config = require(game.ReplicatedStorage.Shared.Config)
local rgb,V3=Color3.fromRGB,Vector3.new
return function()
 assert(game.PlaceId==123937616497204,"Wrong game")
 assert(not workspace.Biomes:FindFirstChild("MysticGrove"),"Mystic Grove exists; do not overwrite it")
 local C=Config.BiomeById.MysticGrove
 assert(C,"Install Mystic Config first")
 local previous=workspace.Biomes.Cosmic
 local entrance=previous:GetAttribute("FarZ")-20
 local far=entrance-C.depth
 local nestZ=entrance-C.depth*Config.Nests.depth
 local biome=Instance.new("Model") biome.Name="MysticGrove"
 biome:SetAttribute("Index",8) biome:SetAttribute("EntranceZ",entrance) biome:SetAttribute("FarZ",far)
 biome:SetAttribute("NestZ",nestZ) biome:SetAttribute("MysticBuildVersion",1)
 local props=Instance.new("Folder") props.Name="Props" props.Parent=biome
 local border=Instance.new("Folder") border.Name="Border" border.Parent=biome
 local patches=Instance.new("Folder") patches.Name="Patches" patches.Parent=biome
 local function part(parent,name,size,at,color,material,collide)
  local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=typeof(at)=="CFrame" and at or CFrame.new(at)
  p.Color=color p.Material=material or Enum.Material.SmoothPlastic
  p.Anchored=true p.CanCollide=collide~=false p.CanTouch=false p.CanQuery=collide~=false
  p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth p.Parent=parent
  return p
 end
 local function blob(parent,name,size,at,color,material,collide)
  local p=part(parent,name,size,at,color,material,collide)
  local mesh=Instance.new("SpecialMesh") mesh.MeshType=Enum.MeshType.Sphere mesh.Parent=p
  return p
 end
 local function beam(parent,name,a,b,width,color,material,collide)
  return part(parent,name,V3(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),color,material,collide)
 end
 -- Same floor height as the existing road, including the 20-stud transition.
 part(biome,"Floor",V3(220,0.4,C.depth+20),V3(0,0.1,(entrance+far)/2+10),C.look.floor,C.look.material)
 part(biome,"ReturnPath",V3(24,0.08,C.depth+20),V3(0,0.34,(entrance+far)/2+10),rgb(79,101,87),Enum.Material.Ground,false)
 for _,side in {-1,1} do
  for i=0,21 do
   local z=entrance- i*C.depth/21
   local h=18+(i%4)*3
   local p=part(border,"RootBank",V3(10,h,32),V3(side*115,h/2,z),rgb(54,77,64),Enum.Material.Slate)
   blob(border,"Moss",V3(12,2,32),V3(side*115,h,z),rgb(76,116,83),Enum.Material.Grass)
  end
 end
 part(border,"EndBank",V3(220,20,10),V3(0,10,far-5),rgb(54,77,64),Enum.Material.Slate)
 -- The existing readable entrance sign design, recoloured only on this clone.
 local arch=previous.Arch:Clone() arch.Name="Arch"
 arch:PivotTo(CFrame.new(0,12.75,entrance)) arch.Parent=biome
 for _,p in arch:GetDescendants() do
  if p:IsA("BasePart") then p.Color=p.Material==Enum.Material.Neon and C.look.accent or rgb(72,95,77)
  elseif p:IsA("TextLabel") then
   if p.Name=="Line2" then p.Text="Giant Spider speed: "..math.round(C.guardianSpeed)
   else p.Text="MYSTIC GROVE" end
  end
 end
 local line=previous.ExitLine:Clone() line.CFrame=CFrame.new(0,6,entrance) line.Parent=biome
 local nest=previous.Nest:Clone() nest.Name="Nest"
 -- The nest pivot is the rotated cylinder; preserve its authored rotation when translating.
 nest:PivotTo(CFrame.new(0,0.8,nestZ)*previous.Nest:GetPivot().Rotation) nest.Parent=biome
 for _,p in nest:GetDescendants() do if p:IsA("BasePart") and p.Transparency<1 then p.Color=rgb(180,203,170) end end
 local spot=part(biome,"GuardianSpot",V3(1,1,1),V3(32,0.3,nestZ),C.look.accent,nil,false) spot.Transparency=1
 local function mushroom(parent,x,z,height,radius,capColor)
  local m=Instance.new("Model") m.Name="MysticMushroom" m.Parent=parent
  local stem=blob(m,"Stem",V3(radius*.48,height,radius*.48),V3(x,height/2+.3,z),rgb(182,191,160),Enum.Material.SmoothPlastic)
  local cap=blob(m,"Cap",V3(radius*2,height*.28,radius*1.8),V3(x,height+.3,z),capColor,Enum.Material.SmoothPlastic)
  blob(m,"Gills",V3(radius*1.9,.35,radius*1.7),V3(x,height-height*.1+.3,z),rgb(136,207,175),Enum.Material.Neon,false)
  for i=1,4 do
   local angle=i*math.pi/2
   blob(m,"GlowDot",V3(radius*.24,.12,radius*.24),V3(x+math.cos(angle)*radius*.5,height+height*.11,z+math.sin(angle)*radius*.45),
    rgb(145,245,206),Enum.Material.Neon,false)
  end
  m.PrimaryPart=stem
  return m
 end
 local function tree(x,z,height)
  local m=Instance.new("Model") m.Name="MysticRootTree" m.Parent=props
  local a,b,c=V3(x,.3,z),V3(x+3,height*.5,z+2),V3(x-2,height,z)
  beam(m,"Trunk",a,b,4,rgb(80,78,69),Enum.Material.Wood)
  beam(m,"Trunk",b,c,3,rgb(80,78,69),Enum.Material.Wood)
  for _,side in {-1,1} do
   beam(m,"Branch",b,V3(x+side*10,height*.85,z+5),2,rgb(80,78,69),Enum.Material.Wood,false)
   blob(m,"Canopy",V3(20,5,16),V3(x+side*6,height,z+3),rgb(47,104,84),Enum.Material.Grass,false)
   beam(m,"Root",a,V3(x+side*8,.7,z+7),2.4,rgb(80,78,69),Enum.Material.Wood,false)
  end
 end
 -- A deterministic layout leaves the center path and a 65-stud nest/patrol area clear.
 local rng=Random.new(808)
 for _,side in {-1,1} do
  for i=1,14 do
   local z=entrance-35-i*39
   local x=side*(58+rng:NextNumber(0,32))
   if (V3(x,0,z)-V3(0,0,nestZ)).Magnitude>70 then
    mushroom(props,x,z,rng:NextNumber(9,21),rng:NextNumber(5,9),i%2==0 and rgb(110,83,159) or rgb(56,142,126))
    if i%3==0 then tree(side*97,z-10,rng:NextNumber(22,31)) end
   end
  end
 end
 -- Raised, visibly distinct caps: normal Jump cannot reach the top; Jump riders can.
 local locations={{-42,entrance-95},{43,entrance-195},{-48,entrance-300},{48,entrance-405},{-58,entrance-535}}
 for i,at in locations do
  local m=Instance.new("Model") m.Name="Patch"..i m.Parent=patches
  blob(m,"MushroomStem",V3(8,8,8),V3(at[1],4.3,at[2]),rgb(185,200,163))
  local cap=part(m,"MushroomCap",V3(20,1.5,30),V3(at[1],9.05,at[2]),rgb(111,78,150),Enum.Material.SmoothPlastic)
  -- Native cap collision is flat and reliable; decorative rounded lobes do not affect it.
  blob(m,"CapLobe",V3(23,3,32),V3(at[1],8.55,at[2]),rgb(111,78,150),nil,false)
  part(m,"Gills",V3(20,.25,30),V3(at[1],8.25,at[2]),C.look.accent,Enum.Material.Neon,false)
  for j=1,3 do blob(m,"CapSpot",V3(2.4,.12,2.4),V3(at[1]-5+j*3,9.86,at[2]-6+j*4),rgb(169,243,207),Enum.Material.Neon,false) end
  local lane=part(m,"EscapeLane",V3(20,1,30),V3(at[1],10.3,at[2]),C.look.accent,nil,false)
  lane.Transparency=1 lane:SetAttribute("Ability","Jump") lane:SetAttribute("Headroom",12)
  m.PrimaryPart=cap
  local board=part(m,"PatchSign",V3(8,2.2,.25),V3(at[1],4,at[2]+17),rgb(43,65,56),nil,false)
  local gui=Instance.new("SurfaceGui") gui.Face=Enum.NormalId.Back gui.CanvasSize=Vector2.new(640,180) gui.Parent=board
  local label=Instance.new("TextLabel") label.Size=UDim2.fromScale(1,1) label.BackgroundTransparency=1 label.Text="JUMP · LEAVE BEFORE 4s"
  label.Font=Enum.Font.FredokaOne label.TextSize=40 label.TextColor3=rgb(200,255,225) label.Parent=gui
 end
 biome.Parent=workspace.Biomes
 local extendRoad=script.Parent:FindFirstChild("ExtendMysticRoad")
 if extendRoad then require(extendRoad)(biome) end
 local dress=script.Parent:FindFirstChild("DressMysticGrove")
 if dress then require(dress)(biome) end
 local obstacles=script.Parent:FindFirstChild("MysticObstacles")
 if obstacles then require(obstacles)(biome) end
 local fill=script.Parent:FindFirstChild("FillMysticRoute")
 if fill then require(fill)(biome) end
 -- Studio preview is separate from the runtime guardian (spawned by GuardianService).
 local preview=Instance.new("Folder") preview.Name="MysticPreview20261009" preview.Parent=game.ServerStorage
 local B=require(game.ReplicatedStorage.Shared.CreatureBuilder)
 local spider=B.buildGuardian("MysticGrove")
 B.placeOn(spider,spot.CFrame)
 for _,p in spider:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true end end
 spider.Name="SpiderPreview" spider.Parent=preview
 local sfx=game.SoundService.SFX
 if not sfx:FindFirstChild("AmbienceMysticGrove") then
  local sound=sfx.AmbienceForest:Clone() sound.Name="AmbienceMysticGrove" sound.PlaybackSpeed=.8 sound.Volume=.25 sound.Parent=sfx
 end
 return "Mystic Grove built: "..entrance.." to "..far..", nest "..nestZ.."; previous biomes preserved"
end
