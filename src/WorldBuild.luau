local old=workspace:FindFirstChild('PowerFacility')
if old then assert(old:GetAttribute('PowerCoreOwned'),'Existing PowerFacility is not owned by this build'); old:Destroy() end
local model=Instance.new('Model'); model.Name='PowerFacility'; model:SetAttribute('PowerCoreOwned',true); model.Parent=workspace
local cyan=Color3.fromRGB(42,221,245); local dark=Color3.fromRGB(52,65,80); local steel=Color3.fromRGB(88,106,124)
local origin=Vector3.new(0,0,-32)
local function part(name,size,pos,color,material,shape)
 local p=Instance.new('Part'); p.Name=name; p.Size=size; p.CFrame=CFrame.new(origin+pos); p.Color=color or steel
 p.Material=material or Enum.Material.Metal; p.Anchored=true; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
 if shape then p.Shape=shape end
 p.Parent=model; return p
end
local function cylinder(name,diameter,height,pos,color,material)
 local p=part(name,Vector3.new(height,diameter,diameter),pos,color,material,Enum.PartType.Cylinder)
 p.CFrame*=CFrame.Angles(0,0,math.pi/2); return p
end
local floor=part('FacilityDeck',Vector3.new(92,1,88),Vector3.new(0,0,0),dark)
for _,x in ipairs({-45,45}) do part('DeckTrim',Vector3.new(0.3,0.15,88),Vector3.new(x,0.6,0),cyan,Enum.Material.Neon) end
for _,z in ipairs({-43,43}) do part('DeckTrim',Vector3.new(92,0.15,0.3),Vector3.new(0,0.6,z),cyan,Enum.Material.Neon) end
for x=-36,36,12 do part('FloorSeam',Vector3.new(0.08,0.02,80),Vector3.new(x,0.52,0),steel) end
for z=-36,36,12 do part('FloorSeam',Vector3.new(84,0.02,0.08),Vector3.new(0,0.52,z),steel) end
cylinder('ReactorPlinth',24,1.4,Vector3.new(0,1.2,0),steel)
cylinder('ReactorPlinthLight',22,0.15,Vector3.new(0,2,0),cyan,Enum.Material.Neon)
cylinder('ReactorPlatform',20,0.8,Vector3.new(0,2.4,0),dark)
for i=1,8 do
 local angle=i*math.pi/4; local x,z=math.cos(angle)*11,math.sin(angle)*11
 local support=part('ContainmentFin',Vector3.new(1.4,4,2),Vector3.new(x,3.5,z),steel); support.CFrame*=CFrame.Angles(0,-angle,0)
 part('FinLight',Vector3.new(0.25,2.8,0.25),Vector3.new(x,3.9,z),cyan,Enum.Material.Neon)
end
local placeholder=part('PlaceholderCore',Vector3.new(4,4,4),Vector3.new(0,6,0),cyan,Enum.Material.Neon,Enum.PartType.Ball)
placeholder.CanCollide=false
local anchor=part('ReactorAnchor',Vector3.new(1,1,1),Vector3.new(0,6,0),dark); anchor.Transparency=1; anchor.CanCollide=false
local hitbox=part('ReactorHitbox',Vector3.new(20,18,20),Vector3.new(0,9,0)); hitbox.Transparency=1; hitbox.CanCollide=false; hitbox.CanTouch=false
local detector=Instance.new('ClickDetector'); detector.MaxActivationDistance=100; detector.Parent=hitbox
local spawn=Instance.new('SpawnLocation'); spawn.Name='FacilitySpawn'; spawn.Size=Vector3.new(8,0.3,8); spawn.CFrame=CFrame.new(origin+Vector3.new(0,0.8,27)); spawn.Anchored=true; spawn.Neutral=true; spawn.Duration=0; spawn.Transparency=1; spawn.Parent=model
for i=1,4 do
 local pos=Vector3.new(-31,2,(i-2.5)*14)
 part('GeneratorHousing',Vector3.new(9,3,9),pos,steel)
 part('GeneratorTop',Vector3.new(8,0.6,8),pos+Vector3.new(0,1.8,0),dark)
 for j=-1,1 do
  cylinder('PowerCellBase',1.8,0.4,pos+Vector3.new(j*2.4,2.6,0),dark)
  cylinder('PowerCellCap',1.8,0.4,pos+Vector3.new(j*2.4,5.4,0),dark)
  cylinder('PowerCellLight',1.5,2.4,pos+Vector3.new(j*2.4,4,0),cyan,Enum.Material.Neon)
 end
 part('PowerConduit',Vector3.new(18,0.14,0.25),Vector3.new(-18,0.65,pos.Z),cyan,Enum.Material.Neon)
end
for _,z in ipairs({-32,32}) do
 for _,x in ipairs({-39,39}) do
  part('StructuralColumn',Vector3.new(2,17,2),Vector3.new(x,9,z),steel)
  part('ColumnLight',Vector3.new(0.3,12,0.3),Vector3.new(x-1.05,9,z),cyan,Enum.Material.Neon)
 end
end
local function screen(host,name,text,color)
 local gui=Instance.new('SurfaceGui'); gui.Name=name; gui.Face=Enum.NormalId.Back; gui.CanvasSize=Vector2.new(800,400); gui.LightInfluence=0; gui.Parent=host
 local bg=Instance.new('Frame'); bg.Size=UDim2.fromScale(1,1); bg.BackgroundColor3=dark; bg.BorderSizePixel=0; bg.Parent=gui
 local label=Instance.new('TextLabel'); label.Name='Label'; label.Size=UDim2.fromScale(0.92,0.8); label.Position=UDim2.fromScale(0.04,0.1); label.BackgroundTransparency=1; label.Text=text; label.TextColor3=color; label.Font=Enum.Font.GothamBold; label.TextScaled=true; label.Parent=bg
 return gui
end
local energyScreen=part('EnergyDisplay',Vector3.new(20,8,0.6),Vector3.new(0,9,-38),dark)
screen(energyScreen,'EnergyScreen','POWER CORE\nFACILITY ONLINE',cyan)
local function terminal(name,pos,label,color)
 local base=part(name,Vector3.new(7,4,4),pos,steel)
 local display=part(name..'Display',Vector3.new(6,3,0.4),pos+Vector3.new(0,2,-0.5),dark)
 screen(display,'TerminalScreen',label,color)
 part(name..'Trim',Vector3.new(7,0.2,4),pos+Vector3.new(0,2.05,0),color,Enum.Material.Neon)
 local prompt=Instance.new('ProximityPrompt'); prompt.Name='OpenPanel'; prompt.ActionText='Open'; prompt.ObjectText=label; prompt.HoldDuration=0; prompt.MaxActivationDistance=12; prompt.RequiresLineOfSight=false; prompt.Parent=base
end
terminal('UpgradeTerminal',Vector3.new(29,2.8,-10),'UPGRADES',cyan)
terminal('RebootTerminal',Vector3.new(29,2.8,14),'REBOOT',Color3.fromRGB(255,188,84))
local sign=part('FacilitySign',Vector3.new(22,3,0.4),Vector3.new(0,3,39),dark)
screen(sign,'Sign','POWER CORE  /  ENERGY LAB',cyan)
local Lighting=game:GetService('Lighting')
Lighting.ClockTime=14; Lighting.Brightness=3; Lighting.ExposureCompensation=0.1
Lighting.Ambient=Color3.fromRGB(125,140,160); Lighting.OutdoorAmbient=Color3.fromRGB(155,170,190)
local fixtures=Instance.new('Folder'); fixtures.Name='OverheadLighting'; fixtures:SetAttribute('PowerCoreOwned',true); fixtures.Parent=model
for _,column in ipairs(model:GetChildren()) do
 if column.Name=='StructuralColumn' then
  local lamp=Instance.new('Part'); lamp.Name=string.format('Lamp_%d_%d',column.Position.X,column.Position.Z)
  lamp.Size=Vector3.new(10,0.35,3); lamp.CFrame=CFrame.new(column.Position+Vector3.new(0,9,0)); lamp.Anchored=true
  lamp.CanCollide=false; lamp.CanTouch=false; lamp.CanQuery=false; lamp.CastShadow=false
  lamp.Material=Enum.Material.Neon; lamp.Color=Color3.fromRGB(185,213,230); lamp.Parent=fixtures
  local light=Instance.new('SurfaceLight'); light.Name='Downlight'; light.Face=Enum.NormalId.Bottom
  light.Color=Color3.fromRGB(225,237,255); light.Brightness=2; light.Range=44; light.Angle=120; light.Shadows=false; light.Parent=lamp
 end
end
workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(55,43,30),origin+Vector3.new(0,4,0))
return 'PowerFacility built: '..#model:GetDescendants()..' instances; original baseplate and spawn preserved.'
