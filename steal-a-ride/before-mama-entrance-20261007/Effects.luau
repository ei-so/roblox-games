-- Client effects: hatch burst, catch burst, Mama's stomp shake / sky / defeat burst, and the SFX helper.
-- Sounds live in SoundService.SFX; a blank SoundId just plays nothing (filled in Part 6).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CreatureBuilder = require(ReplicatedStorage.Shared:WaitForChild("CreatureBuilder"))
local WalkCycle = require(ReplicatedStorage.Shared:WaitForChild("WalkCycle"))

local player = Players.LocalPlayer
local SFX = SoundService:WaitForChild("SFX")

local function play(name: string, pitch: number?)
	local s = SFX:FindFirstChild(name)
	if s and s.SoundId ~= "" then
		if pitch then
			s = s:Clone()
			s.PlaybackSpeed = pitch
			s.Parent = SoundService
			s.Ended:Once(function() s:Destroy() end)
			s:Play()
		else
			SoundService:PlayLocalSound(s)
		end
	end
end

-- guardian voices (Config.GuardianSounds): one shot at the entry's pitch/volume; 3D from the guardian when given a part
local GS = Config.GuardianSounds
local function voice(entry, part: BasePart?, volumeScale: number?)
	if not entry then return end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. entry[1]
	s.PlaybackSpeed, s.Volume = entry[2], entry[3] * (volumeScale or 1)
	if part then s.RollOffMinDistance, s.RollOffMaxDistance = 10, 90 end
	s.Parent = part or SoundService
	s.Ended:Once(function() s:Destroy() end)
	s:Play()
	if entry[4] then task.delay(entry[4], function() if s.Parent then s:Destroy() end end) end
end

-- looping sounds (ambience, music, rain, heartbeat): a local copy we fade in and out
local loops = {}
local function loop(name: string, on: boolean, volume: number?)
	local template = SFX:FindFirstChild(name)
	if not template or template.SoundId == "" then
		return nil
	end
	local s = loops[name]
	if not s then
		s = template:Clone()
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		loops[name] = s
	end
	local target = on and (volume or template.Volume) or 0
	if on and not s.IsPlaying then
		s:Play()
	end
	local fade = TweenService:Create(s, TweenInfo.new(1.2), { Volume = target })
	fade.Completed:Once(function(state)
		if not on and state == Enum.PlaybackState.Completed and s.Volume < 0.01 then s:Stop() end
	end)
	fade:Play()
	return s
end

local function burst(position: Vector3, color: Color3, count: number, speed: number, size: number)
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = position
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Rate = 0
	e.Parent = holder
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, size * 8, 4
	light.Parent = holder
	holder.Parent = workspace
	e:Emit(count)
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	game:GetService("Debris"):AddItem(holder, 2)
end

-- camera shake: nudges Humanoid.CameraOffset for a moment
local shakeUntil, shakePower = 0, 0
local function shake(power: number, seconds: number)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
	shakePower = math.max(shakePower, power)
end
RunService.RenderStepped:Connect(function()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if os.clock() < shakeUntil then
		humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shakePower
	elseif shakePower > 0 then
		shakePower = 0
		humanoid.CameraOffset = Vector3.zero
	end
end)

local function myPlot()
	return workspace.HomeRow.Plots:FindFirstChild(player:GetAttribute("Plot") or "")
end

-- ground dust ring (footsteps, Mama's stomps)
local function dustPuff(position: Vector3, size: number, count: number)
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = position
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(215, 200, 175))
	e.Size = NumberSequence.new(size * 0.3, size)
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(size * 1.2, size * 2)
	e.SpreadAngle = Vector2.new(5, 180)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -size, 0)
	e.Drag = 4
	e.Rate = 0
	e.Parent = holder
	holder.Parent = workspace
	e:Emit(count)
	game:GetService("Debris"):AddItem(holder, 1.5)
end

local function anchorAll(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery = true, false, false
		end
	end
	return model
end

-- Hatch moment (local only): the egg wobbles 1.5 s and cracks, the camera eases in if you're nearby,
-- a burst in the rarity color goes off and the creature pops out with a scale bounce.
local cinematicBusy = false -- several eggs can hatch on the same tick; only one gets the camera
local function hatchMoment(pad: BasePart, result, rarity)
	local top = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	local egg = anchorAll(CreatureBuilder.buildEgg(Config.Species[result.species].biome, result.mutation))
	egg:PivotTo(CFrame.new(top + Vector3.new(0, 1.6, 0)))
	egg.Parent = workspace
	local cam = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local cinematic = not cinematicBusy and root and (root.Position - top).Magnitude < 45 and not player:GetAttribute("CarryingEgg")
	local restore
	if cinematic then
		cinematicBusy = true
		restore = cam.CFrame
		cam.CameraType = Enum.CameraType.Scriptable
		-- look from the player's side of the incubator, so the pen and its beams stay behind the egg
		local away = (root.Position - top) * Vector3.new(1, 0, 1)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
		local goal = CFrame.lookAt(top + away * 9 + Vector3.new(0, 5, 0), top + Vector3.new(0, 1.5, 0))
		TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { CFrame = goal }):Play()
	end
	local base = egg:GetPivot()
	local t0 = os.clock()
	while os.clock() - t0 < 1.5 do
		local t = os.clock() - t0
		egg:PivotTo(base * CFrame.Angles(0, 0, math.sin(t * (14 + t * 10)) * math.rad(6 + t * 10)))
		RunService.RenderStepped:Wait()
	end
	egg:Destroy()
	play("HatchCrack")
	play("RarityReveal")
	burst(top + Vector3.new(0, 2, 0), rarity.color, 30 + rarity.index * 15, 10 + rarity.index * 4, 0.8 + rarity.index * 0.2)
	local creature = anchorAll(CreatureBuilder.build(result.species, result.rarity, result.mutation))
	local face = root and (root.Position - top) * Vector3.new(1, 0, 1) or Vector3.new(0, 0, 1)
	face = face.Magnitude > 0.1 and face.Unit or Vector3.new(0, 0, 1)
	CreatureBuilder.placeOn(creature, CFrame.lookAt(top, top + face))
	local scale0 = creature:GetScale()
	creature.Parent = workspace
	local t1 = os.clock()
	while os.clock() - t1 < 0.45 do -- 0.2 -> 1.15 -> 1
		local a = (os.clock() - t1) / 0.45
		local s = a < 0.7 and 0.2 + (1.15 - 0.2) * (a / 0.7) or 1.15 - 0.15 * ((a - 0.7) / 0.3)
		creature:ScaleTo(scale0 * s)
		CreatureBuilder.placeOn(creature, CFrame.lookAt(top, top + face))
		RunService.RenderStepped:Wait()
	end
	creature:ScaleTo(scale0)
	CreatureBuilder.placeOn(creature, CFrame.lookAt(top, top + face))
	task.wait(1.4)
	creature:Destroy()
	if cinematic then
		local back = TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { CFrame = restore })
		back:Play()
		back.Completed:Wait()
		cam.CameraType = Enum.CameraType.Custom
		cinematicBusy = false
	end
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify").OnClientEvent:Connect(function(kind, payload, extra)
	if kind == "hatched" then
		local rarity = Config.RarityById[payload.rarity]
		local plot = myPlot()
		local pad = extra and plot and plot.Incubators:FindFirstChild("Incubator" .. extra)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if pad then
			task.spawn(hatchMoment, pad, payload, rarity)
		else -- fuse results etc.: just the burst
			if root then
				burst(root.Position, rarity.color, 30 + rarity.index * 15, 10 + rarity.index * 4, 0.8 + rarity.index * 0.2)
			end
			play("RarityReveal")
		end
	elseif kind == "chase" then -- alert: this guardian's own "you've been noticed" call
		voice(GS[payload] and GS[payload].alert)
		play("ChaseSting")
	elseif kind == "rage" then -- the guardian enrages as you near the safe zone: its alert again, louder
		voice(GS[payload] and GS[payload].alert, nil, 1.3)
		shake(0.8, 0.3)
	elseif kind == "fling" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			burst(root.Position, Color3.fromRGB(255, 240, 160), 40, 18, 1)
		end
		shake(1.2, 0.35)
		play("CatchFling")
	elseif kind == "alarm" then
		play("RaidAlarm")
	elseif kind == "stomp" then
		dustPuff(Vector3.new(payload.X, 0.5, payload.Z), 9, 60)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local d = root and (root.Position - payload).Magnitude or math.huge
		if d < 260 then
			shake(1.6 * (1 - d / 260), 0.25)
			play("MamaStomp")
		end
	elseif kind == "mama" then
		if payload.phase == "warning" then
			play("MamaSiren")
		elseif payload.phase == "defeated" then
			burst(payload.position + Vector3.new(0, 20, 0), Color3.fromRGB(255, 210, 80), 200, 60, 4)
			burst(payload.position + Vector3.new(0, 20, 0), Color3.fromRGB(190, 110, 255), 150, 45, 3)
			play("MamaDefeated")
		end
	end
end)

----------------------------------------------------------------------------- chase pressure
-- while carrying an egg: heartbeat volume and a red screen-edge vignette grow as that biome's guardian gets close
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainUI")
local vignette = Instance.new("Frame")
vignette.Name = "ChaseVignette"
vignette.BackgroundTransparency = 1
vignette.Size = UDim2.fromScale(1, 1)
vignette.ZIndex = 40
vignette.Active = false
local edge = Instance.new("UIStroke")
edge.Color = Color3.fromRGB(255, 20, 30)
edge.Thickness = 70
edge.Transparency = 1
edge.Parent = vignette
vignette.Parent = gui

local function guardianOf(biomeId)
	local b = workspace.Biomes:FindFirstChild(biomeId)
	return b and b:FindFirstChild("Guardian")
end

local lastCash, lastRebirths, lastLock = player:GetAttribute("Cash") or 0, player:GetAttribute("Rebirths") or 0, player:GetAttribute("LockLeft") or 0
player:GetAttributeChangedSignal("CarryingEgg"):Connect(function()
	if player:GetAttribute("CarryingEgg") then
		play("EggGrab")
	end
end)
player:GetAttributeChangedSignal("Cash"):Connect(function()
	local cash, rebirths = player:GetAttribute("Cash") or 0, player:GetAttribute("Rebirths") or 0
	if cash < lastCash and rebirths == lastRebirths then -- spent (a rebirth reset isn't a purchase)
		play("Purchase")
	end
	lastCash, lastRebirths = cash, rebirths
end)
-- escape patches: the lane's own sound on stepping on (watery, boing, wind, fire, reversed), then a rising tick before you sink
local function laneAt(z: number): string?
	for _, b in Config.Biomes do
		local m = workspace.Biomes:FindFirstChild(b.id)
		if m and z <= m:GetAttribute("EntranceZ") + 10 and z >= m:GetAttribute("FarZ") - 10 then return b.lane end
	end
	return nil
end
player:GetAttributeChangedSignal("PatchSince"):Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local lane = player:GetAttribute("PatchSince") and root and laneAt(root.Position.Z)
	if lane then
		play("Patch" .. lane)
	end
end)
local nextTick = 0
RunService.Heartbeat:Connect(function()
	local since = player:GetAttribute("PatchSince")
	if not since then return end
	local warn, elapsed = Config.Patch.warn, workspace:GetServerTimeNow() - since
	if elapsed >= warn.tick and os.clock() >= nextTick then
		local k = math.clamp((elapsed - warn.tick) / (Config.Patch.stuckAfter - warn.tick), 0, 1)
		play("PatchTick", 1 + 0.6 * k)
		nextTick = os.clock() + 0.18 - 0.08 * k
	end
end)
player:GetAttributeChangedSignal("LockLeft"):Connect(function()
	local left = player:GetAttribute("LockLeft") or 0
	if left > lastLock + 1 then
		play("Lock")
	elseif left == 0 and lastLock > 0 then
		play("Unlock")
	end
	lastLock = left
end)

-- the hunting guardian's chase loop: fades in when it starts hunting you, louder as it closes in, out when it stops
local chaseLoop, chaseBiome
local function setHunter(biomeId)
	if biomeId == chaseBiome then return end
	if chaseLoop then
		local old = chaseLoop
		TweenService:Create(old, TweenInfo.new(0.8), { Volume = 0 }):Play()
		task.delay(0.9, function() old:Destroy() end)
	end
	chaseLoop, chaseBiome = nil, biomeId
	local entry = biomeId and GS[biomeId] and GS[biomeId].chase
	if entry then
		chaseLoop = Instance.new("Sound")
		chaseLoop.SoundId, chaseLoop.Looped = "rbxassetid://" .. entry[1], true
		chaseLoop.PlaybackSpeed, chaseLoop.Volume = entry[2], 0
		chaseLoop.Parent = SoundService
		chaseLoop:Play()
	end
end

RunService.Heartbeat:Connect(function()
	local carrying = player:GetAttribute("CarryingEgg")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local intensity, raging, hunter, hunterIntensity = 0, false, nil, -1
	if carrying and root then -- any guardian may be hunting a carrier: react to the nearest one
		for _, b in Config.Biomes do
			local g = guardianOf(b.id)
			if g and g:GetAttribute("ChaseTarget") == player.UserId then
				local d = (g:GetPivot().Position - root.Position) * Vector3.new(1, 0, 1)
				local closeness = math.clamp(1 - (d.Magnitude - 8) / 70, 0, 1)
				intensity = math.max(intensity, closeness)
				raging = raging or g:GetAttribute("Raging") == true
				if closeness > hunterIntensity then hunter, hunterIntensity = b.id, closeness end
			end
		end
	end
	setHunter(hunter)
	if chaseLoop then
		chaseLoop.Volume = GS[chaseBiome].chase[3] * (0.35 + 0.65 * hunterIntensity)
	end
	if raging then -- enraged: a stronger pulsing edge however far behind it is
		intensity = math.max(intensity, 0.6)
		edge.Transparency = 1 - (0.55 + 0.35 * math.abs(math.sin(os.clock() * 8)))
	else
		edge.Transparency = 1 - intensity * 0.65
	end
	local hb = loops.Heartbeat or (intensity > 0 and loop("Heartbeat", true, 0))
	if hb then
		hb.Volume = intensity * 0.9
		hb.PlaybackSpeed = 1 + intensity * 0.35
	end
end)

----------------------------------------------------------------------------- walk cycles
local function near(position: Vector3, range: number): boolean
	return (workspace.CurrentCamera.CFrame.Position - position).Magnitude < range
end

-- guardians walk on the server; each footfall bumps their Step attribute: dust + that guardian's own step here.
-- While patrolling (not hunting anyone) they also call now and then, heard from the guardian itself.
local function watchGuardian(g: Model, biomeId: string)
	local _, size = g:GetBoundingBox()
	local sounds = GS[biomeId]
	g:GetAttributeChangedSignal("Step"):Connect(function()
		local pos = g:GetPivot().Position
		if near(pos, 160) then
			dustPuff(Vector3.new(pos.X, pos.Y - size.Y / 2 + 0.5, pos.Z), math.clamp(size.Y * 0.18, 1.5, 4), 14)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local d = root and (root.Position - pos).Magnitude or 999
			if d < 90 then
				voice(sounds.step, nil, 1 - d / 90)
			end
		end
	end)
	task.spawn(function()
		while g.Parent do
			task.wait(4 + math.random() * 4)
			local body = g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart", true)
			if body and g:GetAttribute("ChaseTarget") == nil and near(g:GetPivot().Position, 100) then
				voice(sounds.idle, body)
			end
		end
	end)
end
for _, b in Config.Biomes do
	task.spawn(function()
		local g = workspace:WaitForChild("Biomes"):WaitForChild(b.id):WaitForChild("Guardian", 30)
		if g then
			watchGuardian(g, b.id)
		end
	end)
end

-- mounts: animate every rider's MountWeld locally (steps follow the rider's ground speed)
-- pen creatures: gentle breathing for the pens near the camera
local mountState = setmetatable({}, { __mode = "k" })
local penBase = setmetatable({}, { __mode = "k" })
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for _, p in Players:GetPlayers() do
		local ch = p.Character
		local weld = ch and ch:FindFirstChild("Mount") and ch.Mount:FindFirstChild("MountWeld", true)
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if weld and root and weld:GetAttribute("BaseC0") and near(root.Position, 250) then
			local st = mountState[weld]
			if not st then
				st = { phase = 0, amount = 0, seed = math.random() * 10, joints = WalkCycle.bind(ch.Mount), turn = 0, look = root.CFrame.LookVector }
				mountState[weld] = st
			end
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			st.amount = math.clamp(st.amount + (speed > 1 and dt or -dt) * 5, 0, 1)
			st.phase += speed * dt / (weld:GetAttribute("Stride") or 3)
			local h = weld:GetAttribute("Height") or 4
			local humanoid = ch:FindFirstChildOfClass("Humanoid")
			local airborne = ch.Mount:GetAttribute("CanFly") and (p:GetAttribute("Flying") or humanoid and humanoid.FloorMaterial == Enum.Material.Air)
			local gait = airborne and "fly" or weld:GetAttribute("Gait")
			local pose = airborne and WalkCycle.offset(now * 1.5, 1, h, "fly")
				or st.amount > .02 and WalkCycle.offset(st.phase, st.amount, h, gait) or WalkCycle.idle(now, h, st.seed)
			local turn = st.look:Cross(root.CFrame.LookVector).Y / math.max(dt, .001)
			st.look = root.CFrame.LookVector
			st.turn += (math.clamp(turn * .08, -.22, .22) - st.turn) * math.min(1, dt * 8)
			if airborne then pose *= CFrame.Angles(0, 0, -st.turn) end
			weld.C0 = weld:GetAttribute("BaseC0") * pose
			WalkCycle.animateJoints(st.joints, st.phase, st.amount, now, gait, airborne == true)
		end
	end
	for _, plot in workspace.HomeRow.Plots:GetChildren() do
		local pens = plot:FindFirstChild("PenModels")
		if pens and near(plot.Floor.Position, 180) then
			for _, m in pens:GetChildren() do
				local base = penBase[m]
				if not base then
					local _, size = m:GetBoundingBox()
					base = { cf = m:GetPivot(), h = m:GetAttribute("RestHeight") or size.Y, seed = math.random() * 10, joints = WalkCycle.bind(m) }
					penBase[m] = base
				end
				local floating = m:GetAttribute("CanFly") or m:GetAttribute("Gait") == "float"
				local pose = floating and CFrame.new(0, base.h * .2, 0) * WalkCycle.offset(now * .8 + base.seed, 1, base.h, "float")
					or WalkCycle.idle(now, base.h, base.seed)
				m:PivotTo(base.cf * pose)
				WalkCycle.animateJoints(base.joints, now * .5 + base.seed, 0, now + base.seed, m:GetAttribute("Gait") or "quad", m:GetAttribute("CanFly") == true)
			end
		end
	end
end)

----------------------------------------------------------------------------- mount dust (every rider, while moving)
task.spawn(function()
	while true do
		for _, p in Players:GetPlayers() do
			local ch = p.Character
			local mount = ch and ch:FindFirstChild("Mount")
			local dust = mount and mount:FindFirstChild("Dust", true)
			local root = ch and ch:FindFirstChild("HumanoidRootPart")
			if dust and root then
				local v = root.AssemblyLinearVelocity
				local humanoid = ch:FindFirstChildOfClass("Humanoid")
				dust.Enabled = not p:GetAttribute("Flying") and mount:GetAttribute("Gait") ~= "float"
					and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air
					and Vector3.new(v.X, 0, v.Z).Magnitude > 4 and math.abs(v.Y) < 2
			end
		end
		task.wait(0.2)
	end
end)

----------------------------------------------------------------------------- weather + region sounds
local biomes = workspace:WaitForChild("Biomes")
local thunderToken = 0
local function syncWeatherSound()
	local storm = workspace:GetAttribute("Weather") == "Thunderstorm"
	loop("Rain", storm)
	thunderToken += 1
	local token = thunderToken
	if storm then
		task.spawn(function()
			while token == thunderToken do
				task.wait(math.random(6, 14))
				if token == thunderToken then
					play("Thunder")
				end
			end
		end)
	end
end
workspace:GetAttributeChangedSignal("Weather"):Connect(syncWeatherSound)
syncWeatherSound()

local REGIONS = { Home = "HomeMusic" }
for _, b in Config.Biomes do
	REGIONS[b.id] = "Ambience" .. b.id
end
-- escape soundtrack: while carrying an egg, the biome's track crossfades in over its (ducked) ambience
local EM = Config.EscapeMusic
local escapeSound, escapeBiome
local function setEscape(biomeId)
	if biomeId == escapeBiome then return end
	if escapeSound then
		local old = escapeSound
		TweenService:Create(old, TweenInfo.new(2), { Volume = 0 }):Play()
		task.delay(2.1, function() old:Destroy() end)
	end
	escapeSound, escapeBiome = nil, biomeId
	local track = biomeId and EM.tracks[biomeId]
	if track then
		escapeSound = Instance.new("Sound")
		escapeSound.SoundId, escapeSound.Looped, escapeSound.Volume = "rbxassetid://" .. track[1], true, 0
		escapeSound.Parent = SoundService
		escapeSound:Play()
		TweenService:Create(escapeSound, TweenInfo.new(2), { Volume = track[2] }):Play()
	end
end

local currentRegion, ducked
task.spawn(function()
	local firstEntrance = biomes:WaitForChild(Config.Biomes[1].id):GetAttribute("EntranceZ")
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local z = root.Position.Z
			local region = z > firstEntrance and "Home" or currentRegion
			for _, b in Config.Biomes do
				local m = biomes:FindFirstChild(b.id)
				if m and z <= m:GetAttribute("EntranceZ") + 10 and z >= m:GetAttribute("FarZ") - 10 then
					region = b.id
				end
			end
			local carrying = player:GetAttribute("CarryingEgg") ~= nil
			local escaping = carrying and region ~= "Home" and region or nil
			if carrying and region == "Home" and currentRegion and currentRegion ~= "Home" then
				voice(EM.sting) -- crossed the safe line with the egg: made it!
			end
			if region ~= currentRegion or (escaping ~= nil) ~= ducked then
				if currentRegion and region ~= currentRegion then
					loop(REGIONS[currentRegion], false)
				end
				currentRegion, ducked = region, escaping ~= nil
				local ambience = SFX:FindFirstChild(REGIONS[region])
				loop(REGIONS[region], true, ambience and ducked and ambience.Volume * EM.duck or nil)
			end
			setEscape(escaping)
		end
		task.wait(0.5)
	end
end)

-- Mama's Revenge darkens the sky while she's coming and while she's here
local mamaTint = Instance.new("ColorCorrectionEffect")
mamaTint.Name = "MamaTint"
mamaTint.Parent = Lighting
local function syncMama()
	local on = workspace:GetAttribute("MamaPhase") ~= nil
	TweenService:Create(mamaTint, TweenInfo.new(2), {
		Brightness = on and -0.15 or 0, Saturation = on and -0.25 or 0, TintColor = on and Color3.fromRGB(220, 200, 255) or Color3.new(1, 1, 1),
	}):Play()
end
workspace:GetAttributeChangedSignal("MamaPhase"):Connect(syncMama)
syncMama()
