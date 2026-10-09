local Lighting=game:GetService('Lighting')
Lighting.ClockTime=14
Lighting.Brightness=3
Lighting.ExposureCompensation=0.1
Lighting.Ambient=Color3.fromRGB(125,140,160)
Lighting.OutdoorAmbient=Color3.fromRGB(155,170,190)

local facility=workspace:WaitForChild('PowerFacility')
assert(facility:GetAttribute('PowerCoreOwned'),'Expected the Power Core facility')
for _,part in ipairs(facility:GetDescendants()) do
 if part:IsA('BasePart') then
  if part.Color==Color3.fromRGB(16,24,36) then part.Color=Color3.fromRGB(52,65,80)
  elseif part.Color==Color3.fromRGB(39,54,67) then part.Color=Color3.fromRGB(88,106,124) end
 end
end

local fixtures=facility:FindFirstChild('OverheadLighting')
if not fixtures then fixtures=Instance.new('Folder'); fixtures.Name='OverheadLighting'; fixtures:SetAttribute('PowerCoreOwned',true); fixtures.Parent=facility end
assert(fixtures:GetAttribute('PowerCoreOwned'),'Refusing to change unrelated lights')
for _,column in ipairs(facility:GetChildren()) do
 if column.Name=='StructuralColumn' and column:IsA('BasePart') then
  local name=string.format('Lamp_%d_%d',column.Position.X,column.Position.Z)
  if not fixtures:FindFirstChild(name) then
   local lamp=Instance.new('Part'); lamp.Name=name; lamp.Size=Vector3.new(10,0.35,3)
   lamp.CFrame=CFrame.new(column.Position+Vector3.new(0,9,0)); lamp.Anchored=true
   lamp.CanCollide=false; lamp.CanTouch=false; lamp.CanQuery=false; lamp.CastShadow=false
   lamp.Material=Enum.Material.Neon; lamp.Color=Color3.fromRGB(185,213,230); lamp.Parent=fixtures
   local light=Instance.new('SurfaceLight'); light.Name='Downlight'; light.Face=Enum.NormalId.Bottom
   light.Color=Color3.fromRGB(225,237,255); light.Brightness=2; light.Range=44; light.Angle=120; light.Shadows=false; light.Parent=lamp
  end
 end
end
return 'Facility brightened with afternoon light and four overhead lamps.'
