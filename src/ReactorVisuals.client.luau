local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local TweenService=game:GetService('TweenService')
local RS=game:GetService('ReplicatedStorage')
local p=Players.LocalPlayer
local N=require(RS:WaitForChild('Modules').NumberFormatter)
local stages=require(RS.Modules.StageConfig)
local G=require(RS.Modules.GeneratorConfig)
local facility=workspace:WaitForChild('PowerFacility')
local anchor=facility:WaitForChild('ReactorAnchor')
local center=anchor.Position
facility:WaitForChild('PlaceholderCore').LocalTransparencyModifier=1
local gui=p:WaitForChild('PlayerGui'):WaitForChild('MainUI')
local feedback=gui:WaitForChild('VisualFeedback')
local visuals=Instance.new('Model'); visuals.Name='LocalReactor'; visuals.Parent=facility
local core; local light; local particles; local plasmaAttachment; local rings={}; local index=0; local pulse=0; local pulseTime=0; local initialized=false
local cyan=Color3.fromRGB(58,221,242)
local function part(parent,name,size,color,shape)
 local v=Instance.new('Part'); v.Name=name; v.Size=size; v.Color=color; v.Anchored=true; v.CanCollide=false; v.CanTouch=false; v.CanQuery=false; v.CastShadow=false; v.Material=Enum.Material.Neon; v.CFrame=CFrame.new(center)
 if shape then v.Shape=shape end
 v.Parent=parent; return v
end
local function ring(radius,color,rotation)
 local model=Instance.new('Model'); model.Name='PlasmaRing'; model.Parent=visuals
 local segments={}
 for i=1,32 do
  local a=i/32*math.pi*2
  local offset=CFrame.Angles(unpack(rotation))*CFrame.new(math.cos(a)*radius,0,math.sin(a)*radius)*CFrame.Angles(0,-a+math.pi/2,0)
  local s=part(model,'Arc',Vector3.new(radius*math.pi*2/32*0.92,0.18,0.45),color)
  s.CFrame=CFrame.new(center)*offset; table.insert(segments,{part=s,offset=offset})
 end
 table.insert(rings,{segments=segments,speed=#rings%2==0 and 0.38 or -0.28})
end
local function sound(name)
 local s=Instance.new('Sound'); s.Name=name; s.SoundId=''; s.Volume=0.3; s.Parent=anchor; return s
end
local sounds={tap=sound('TapSound'),purchase=sound('PurchaseSound'),evolve=sound('EvolutionSound')}
local billboard=Instance.new('BillboardGui'); billboard.Name='ProductionBillboard'; billboard.Adornee=anchor; billboard.Size=UDim2.fromOffset(320,82); billboard.StudsOffset=Vector3.new(0,9.5,0); billboard.AlwaysOnTop=true; billboard.MaxDistance=150; billboard.Parent=gui
local eps=Instance.new('TextLabel'); eps.Name='EnergyPerSecond'; eps.Size=UDim2.fromScale(1,0.6); eps.BackgroundTransparency=1; eps.TextColor3=cyan; eps.Font=Enum.Font.GothamBold; eps.TextSize=24; eps.TextStrokeTransparency=0.5; eps.Parent=billboard
local hint=Instance.new('TextLabel'); hint.Name='TapHint'; hint.Position=UDim2.fromScale(0,0.65); hint.Size=UDim2.fromScale(1,0.3); hint.BackgroundTransparency=1; hint.Text='Tap the reactor!'; hint.TextColor3=Color3.fromRGB(211,237,246); hint.Font=Enum.Font.Gotham; hint.TextSize=14; hint.Parent=billboard
local evo=Instance.new('TextLabel'); evo.Name='EvolutionNotice'; evo.AnchorPoint=Vector2.new(0.5,0.5); evo.Position=UDim2.fromScale(0.5,0.33); evo.Size=UDim2.new(0.86,0,0,82); evo.BackgroundTransparency=1; evo.TextColor3=cyan; evo.Font=Enum.Font.GothamBold; evo.TextSize=28; evo.TextWrapped=true; evo.TextStrokeTransparency=0.5; evo.Visible=false; evo.ZIndex=20; evo.Parent=gui
local evoScale=Instance.new('UIScale'); evoScale.Parent=evo
local evoVersion=0
local function pulseReactor(kind)
 pulse=kind=='tap' and 0.25 or 0.5; pulseTime=os.clock()
 if particles and kind~='tap' then particles:Emit(kind=='evolve' and 70 or 20) end
 local s=sounds[kind]; if s and s.SoundId~='' then s:Play() end
end
local function rebuild(stage,announce)
 index=stage
 visuals:ClearAllChildren(); rings={}
 local spec=stages[stage]; local size=({3.4,4.6,5.2,5.6,5.4})[stage]
 core=part(visuals,'Core',Vector3.one*size,spec.color,Enum.PartType.Ball)
 if stage==5 then core.Color=Color3.fromRGB(3,5,9); core.Material=Enum.Material.SmoothPlastic end
 light=Instance.new('PointLight'); light.Color=spec.color; light.Brightness=2; light.Range=26; light.Parent=core
 if stage>=2 then ring(5.2,spec.color,{0,0,0}) end
 if stage==3 then ring(6.5,spec.color,{math.rad(55),0,0}) end
 if stage==4 then ring(6.9,spec.color,{math.rad(65),0,math.rad(30)}); ring(7.7,Color3.fromRGB(199,232,255),{math.rad(-50),0,math.rad(-35)}) end
 if stage==5 then ring(6.7,spec.color,{0,0,0}); ring(7.8,Color3.fromRGB(255,229,184),{0,0,0}) end
 local attachment=Instance.new('Attachment'); attachment.Parent=core; plasmaAttachment=attachment
 particles=Instance.new('ParticleEmitter'); particles.Name='Plasma'; particles.Color=ColorSequence.new(spec.color); particles.LightEmission=1
 particles.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,0)})
 particles.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(1,1)})
 particles.Lifetime=NumberRange.new(0.5,1.2); particles.Speed=NumberRange.new(3,6); particles.SpreadAngle=Vector2.new(180,180); particles.Rate=stage>=3 and 12 or 0; particles.Parent=attachment
 if stage==5 then
  attachment.Position=Vector3.new(0,0,6)
  particles.EmissionDirection=Enum.NormalId.Back; particles.Acceleration=Vector3.new(0,0,-8); particles.Speed=NumberRange.new(1,3); particles.SpreadAngle=Vector2.new(30,30)
 end
 core:SetAttribute('BaseSize',size)
 eps.TextColor3=spec.color
 if announce then
  evoVersion+=1; local version=evoVersion
  evo.Text='REACTOR EVOLVED\n'..spec.name; evo.TextColor3=spec.color; evo.TextTransparency=0; evo.Visible=true; evoScale.Scale=0.8
  TweenService:Create(evoScale,TweenInfo.new(0.35,Enum.EasingStyle.Back),{Scale=1}):Play(); pulseReactor('evolve')
  task.delay(2.5,function()
   if version~=evoVersion then return end
   TweenService:Create(evo,TweenInfo.new(0.4),{TextTransparency=1}):Play()
   task.delay(0.45,function() if version==evoVersion then evo.Visible=false end end)
  end)
 end
end
local energyScreen=facility:WaitForChild('EnergyDisplay'):WaitForChild('EnergyScreen').Frame.Label
local function update()
 local run=p:GetAttribute('RunEnergy') or 0; local stage=1
 for i,s in ipairs(stages) do if run>=s.threshold then stage=i end end
 if stage~=index then rebuild(stage,initialized and stage>index) end
 if p:GetAttribute('DataReady') then initialized=true end
 eps.Text=N.Format(p:GetAttribute('EnergyPerSecond') or 1)..' ENERGY / SEC'
 energyScreen.Text='ENERGY RESERVE\n'..N.Format(p:GetAttribute('Energy') or 0)
 local owned=0; for _,g in ipairs(G) do owned+=p:GetAttribute('Gen_'..g.id) or 0 end
 TweenService:Create(hint,TweenInfo.new(0.3),{TextTransparency=owned>=5 and 1 or 0}):Play()
end
local queued=false
p.AttributeChanged:Connect(function() if queued then return end; queued=true; task.defer(function() queued=false; update() end) end)
feedback.Event:Connect(pulseReactor)
local start=os.clock()
RunService.RenderStepped:Connect(function()
 if not core then return end
 local time=os.clock()-start; local power=math.clamp(math.log10(math.max(1,p:GetAttribute('EnergyPerSecond') or 1)),0,12)
 local wave=(math.sin(time*(1.4+power*0.45))+1)/2
 local tapPulse=pulse*math.max(0,1-(os.clock()-pulseTime)/0.4)
 local scale=1+wave*(0.04+power*0.005)+tapPulse
 core.Size=Vector3.one*core:GetAttribute('BaseSize')*scale
 local bob=index>=4 and math.sin(time*1.1)*0.6 or 0
 core.CFrame=CFrame.new(center+Vector3.new(0,bob,0))
 light.Brightness=1.5+wave*(1+power*0.2)+tapPulse*5
 if index==4 then core.Color=Color3.fromHSV(0.48+(math.sin(time*0.25)+1)*0.09,0.45,1) end
 if index>=3 then
  local radius=index==5 and 7 or 5.5
  plasmaAttachment.Position=Vector3.new(math.cos(time*0.9)*radius,0,math.sin(time*0.9)*radius)
  if index==5 then particles.Acceleration=-plasmaAttachment.Position*2 end
 end
 for _,r in ipairs(rings) do
  local base=CFrame.new(center+Vector3.new(0,bob,0))*CFrame.Angles(0,time*r.speed*(1+power*0.1),0)
  for _,s in ipairs(r.segments) do s.part.CFrame=base*s.offset end
 end
end)
update()
