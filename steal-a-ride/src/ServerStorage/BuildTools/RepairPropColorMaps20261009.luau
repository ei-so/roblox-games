-- Run once in Edit; repairs legacy color-map binding without replacing artwork.
return function()
 assert(game.PlaceId==123937616497204,"Wrong place")
 local ids={["125044648419231"]=true,["131061910080831"]=true,["122011786600329"]=true,["94249006429540"]=true,["70813581236152"]=true,["75222360347123"]=true,["109372690056240"]=true,["81466087174936"]=true,["101889128183429"]=true,["78901186973973"]=true,["113248353583891"]=true,["108953306778845"]=true,["104998855158634"]=true,["72086932192197"]=true,["121896819250278"]=true,["110284982019002"]=true,["87851396695357"]=true,["79913899603657"]=true,["111484754966387"]=true}
 local ss=game:GetService("ServerStorage")
 local backup=ss:FindFirstChild("PropTextureBindingBackup20261009")
 if not backup then backup=Instance.new("Folder");backup.Name="PropTextureBindingBackup20261009";backup.Parent=ss end
 local added,checked=0,0
 for _,root in {workspace.Biomes,ss.PropMeshes} do
  for _,p in root:GetDescendants() do
   if p:IsA("MeshPart") and ids[p.TextureID:match("%d+")] then
    local sa=p:FindFirstChildOfClass("SurfaceAppearance")
    assert(not sa or (sa.Name=="SAMPropColorMap" and sa.ColorMap==p.TextureID),"Unexpected existing surface: "..p:GetFullName())
    if not sa then
     local record=Instance.new("ObjectValue")
     record.Name="Binding"..tostring(#backup:GetChildren()+1);record.Value=p
     record:SetAttribute("OriginalPath",p:GetFullName())
     record:SetAttribute("TextureID",p.TextureID)
     record:SetAttribute("CFrame",p.CFrame)
     record:SetAttribute("Size",p.Size)
     record:SetAttribute("Color",p.Color)
     record:SetAttribute("CanCollide",p.CanCollide)
     record.Parent=backup
     sa=Instance.new("SurfaceAppearance");sa.Name="SAMPropColorMap";sa.ColorMap=p.TextureID;sa.Parent=p
     added+=1
    end
    assert(sa.ColorMap==p.TextureID)
    checked+=1
   end
  end
 end
 assert(checked==354,"Unexpected target count "..checked)
 for _,r in backup:GetChildren() do
  local p=r.Value
  assert(p and p.TextureID==r:GetAttribute("TextureID") and p.CFrame==r:GetAttribute("CFrame") and p.Size==r:GetAttribute("Size") and p.Color==r:GetAttribute("Color") and p.CanCollide==r:GetAttribute("CanCollide"),"Prop geometry changed")
 end
 return {added=added,checked=checked,backups=#backup:GetChildren()}
end