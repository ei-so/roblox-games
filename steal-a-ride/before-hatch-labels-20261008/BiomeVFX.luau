-- Client-only biome life: ambient particles around the camera, swaying / bobbing props, living patches
-- (water bubbles, lava embers + glow, ice glints, phase swirls), nest sparkles, and per-biome bloom / sun rays.
-- Only the biome the player is in animates. Purely visual: nothing here touches gameplay or replicates.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local biomes = workspace:WaitForChild("Biomes")
local rgb = Color3.fromRGB
local V3 = Vector3.new

-- built-in particle textures: ship with the client, no asset permissions needed
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function ns(a, b)
	return NumberSequence.new(a, b or a)
end
local function fade(peak)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, peak),
		NumberSequenceKeypoint.new(0.8, peak), NumberSequenceKeypoint.new(1, 1) })
end

-- particles that fill the air around the camera, per biome
local AIR = {
	Forest = {
		{ Texture = SPARK, Color = rgb(255, 240, 120), Size = ns(0.7, 0.4), Rate = 16, Life = 6, Speed = 0.6, Light = 1, Spread = 180 }, -- fireflies
		{ Texture = SMOKE, Color = rgb(110, 180, 70), Size = ns(0.9, 0.7), Rate = 12, Life = 9, Speed = 1, Accel = V3(0.4, -0.7, 0), Rot = 120 }, -- leaves
	},
	Lake = {
		{ Texture = SMOKE, Color = rgb(235, 245, 255), Size = ns(8, 12), Rate = 3, Life = 10, Speed = 0.4, Peak = 0.8, Low = true }, -- mist
		{ Texture = SPARK, Color = rgb(180, 230, 255), Size = ns(0.5, 0.2), Rate = 14, Life = 4, Speed = 0.3, Light = 0.6 }, -- glints
	},
	Desert = {
		{ Texture = SMOKE, Color = rgb(225, 195, 140), Size = ns(3, 6), Rate = 10, Life = 5, Speed = 9, Dir = V3(1, 0.05, 0), Peak = 0.7, Low = true }, -- blowing sand
		{ Texture = SPARK, Color = rgb(255, 230, 170), Size = ns(0.3), Rate = 35, Life = 3, Speed = 10, Dir = V3(1, 0.1, 0) }, -- grit
	},
	Jungle = {
		{ Texture = SPARK, Color = rgb(220, 255, 120), Size = ns(0.5, 0.3), Rate = 24, Life = 7, Speed = 0.5, Light = 0.8, Spread = 180 }, -- pollen
		{ Texture = SMOKE, Color = rgb(170, 220, 170), Size = ns(8, 11), Rate = 2, Life = 10, Speed = 0.3, Peak = 0.9, Low = true }, -- humid haze
		{ Texture = SMOKE, Color = rgb(210, 235, 220), Size = ns(0.25, 0.12), Rate = 12, Life = 1.5, Speed = 10, Dir = V3(0, -1, 0), Accel = V3(0, -8, 0), Peak = 0.3 }, -- canopy drips
	},
	Tundra = {
		{ Texture = SMOKE, Color = rgb(255, 255, 255), Size = ns(0.8, 0.6), Rate = 80, Life = 6, Speed = 2, Dir = V3(0.3, -1, 0.1), Accel = V3(0.6, -1.5, 0), Peak = 0.05, Rot = 60 }, -- snow
	},
	Volcano = {
		{ Texture = SPARK, Color = rgb(255, 145, 45), Size = ns(0.6, 0.15), Rate = 35, Life = 4, Speed = 3, Dir = V3(0, 1, 0), Accel = V3(0.3, 1.5, 0), Light = 1, Spread = 25, Low = true }, -- embers
		{ Texture = SMOKE, Color = rgb(160, 145, 135), Size = ns(0.55, 0.3), Rate = 18, Life = 6, Speed = 1, Accel = V3(0.2, -0.8, 0), Peak = 0.2 }, -- ash
	},
	Cosmic = {
		{ Texture = SPARK, Color = rgb(200, 150, 255), Size = ns(0.8, 0), Rate = 35, Life = 4, Speed = 0.2, Light = 1, Twinkle = true }, -- stars
		{ Texture = SPARK, Color = rgb(120, 200, 255), Size = ns(0.5, 0), Rate = 18, Life = 6, Speed = 1.5, Light = 1, Spread = 180 }, -- drifting motes
	},
}

-- per-biome glow and sun rays (on top of ClientMain's atmosphere + tint)
local LIGHT = {
	Forest = { bloom = 0.5, threshold = 0.9, rays = 0.15 },
	Lake = { bloom = 0.55, threshold = 0.9, rays = 0.1 },
	Desert = { bloom = 0.6, threshold = 0.85, rays = 0.22 },
	Jungle = { bloom = 0.5, threshold = 0.9, rays = 0.18 },
	Tundra = { bloom = 0.8, threshold = 0.8, rays = 0.08 },
	Volcano = { bloom = 1.1, threshold = 0.7, rays = 0 },
	Cosmic = { bloom = 1.3, threshold = 0.65, rays = 0 },
}

-- what rises off each biome's escape patches (one shared idea: a glowing outline + rising, biome-themed particles)
local PATCH = {
	Lake = { Texture = SMOKE, Color = rgb(220, 240, 255), Size = ns(0.6, 0.2), Rate = 4, Life = 1.5, Speed = 3, Dir = V3(0, 1, 0), Peak = 0.3 }, -- bubbles
	Desert = { Texture = SMOKE, Color = rgb(235, 205, 150), Size = ns(1.2, 2.5), Rate = 6, Life = 1.6, Speed = 6, Dir = V3(0, 1, 0), Peak = 0.55, Spread = 12 }, -- updraft dust
	Jungle = { Texture = SMOKE, Color = rgb(200, 240, 220), Size = ns(0.6, 0.2), Rate = 4, Life = 1.5, Speed = 3, Dir = V3(0, 1, 0), Peak = 0.3 },
	Tundra = { Texture = SMOKE, Color = rgb(245, 250, 255), Size = ns(0.5, 0.2), Rate = 10, Life = 1.8, Speed = 5, Dir = V3(0, 1, 0), Accel = V3(1.5, 0, 0), Peak = 0.2, Spread = 10 }, -- snow streamers
	Volcano = { Texture = FIRE, Color = rgb(255, 120, 30), Size = ns(1.2, 0.2), Rate = 8, Life = 1.2, Speed = 5, Dir = V3(0, 1, 0), Light = 1, Spread = 20 }, -- lava spits
	Cosmic = { Texture = SMOKE, Color = rgb(210, 170, 255), Size = ns(1.5, 3), Rate = 5, Life = 2.5, Speed = 2.5, Dir = V3(0, 1, 0), Light = 0.6, Peak = 0.75 }, -- ghost wisps
}

local function emitter(spec, parent)
	local e = Instance.new("ParticleEmitter")
	e.Name = "BiomeVFX"
	e.Texture = spec.Texture
	e.Color = ColorSequence.new(spec.Color)
	e.Size = spec.Size
	e.Rate = spec.Rate
	e.Lifetime = NumberRange.new(spec.Life * 0.7, spec.Life)
	e.Speed = NumberRange.new(spec.Speed * 0.5, spec.Speed)
	e.Transparency = spec.Twinkle and NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(0.7, 0), NumberSequenceKeypoint.new(1, 1) }) or fade(spec.Peak or 0)
	e.LightEmission = spec.Light or 0
	e.Acceleration = spec.Accel or Vector3.zero
	e.EmissionDirection = spec.Dir and (spec.Dir.Y < -0.5 and Enum.NormalId.Bottom
		or spec.Dir.X > 0.5 and Enum.NormalId.Right) or Enum.NormalId.Top
	local spread = spec.Spread or (spec.Dir and 15 or 180)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.RotSpeed = NumberRange.new(-(spec.Rot or 0), spec.Rot or 0)
	e.Rotation = NumberRange.new(0, spec.Rot and 360 or 0)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Enabled = false
	e.Parent = parent
	return e
end

-- Two small emission volumes follow the camera; directional effects use native EmissionDirection.
local function airHost(name, low)
	local box = Instance.new("Part")
	box.Name = name
	box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch = true, false, false, false
	box.Transparency = 1
	box.Size = low and V3(32, 6, 32) or V3(40, 22, 40)
	box:SetAttribute("AirHost", true)
	box:SetAttribute("Low", low)
	box.Parent = workspace.CurrentCamera
	return box
end
local airBox, lowBox = airHost("BiomeAir", false), airHost("BiomeAirLow", true)

local air = {}
for id, specs in AIR do
	air[id] = {}
	for _, spec in specs do
		local host = spec.Low and lowBox or airBox
		local e = emitter(spec, host)
		e:SetAttribute("Biome", id)
		table.insert(air[id], e)
	end
end

-- lighting
-- reuse the place's own Bloom / SunRays; their authored values are the Home look
local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect", Lighting)
local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect", Lighting)
LIGHT.Home = { bloom = bloom.Intensity, threshold = bloom.Threshold, rays = rays.Intensity }
local TWEEN = TweenInfo.new(1.5, Enum.EasingStyle.Sine)

-- props that move: tall things sway from their base, crystals / floaty things bob
local movers = {} -- [biomeId] = { { inst, base CFrame, bottom, phase, kind } }
local SWAY = { Oak = true, Pine = true, FlowerBush = true, Mushrooms = true, Willow = true, Reeds = true,
	Shrub = true, BarrelCactus = true, Saguaro = true, Palm = true, Monstera = true, Rafflesia = true,
	Bamboo = true, SnowPine = true, FrozenTree = true, CharredTree = true, FireShrooms = true, AlienTree = true, AlienShroom = true }
local function collectMovers(id)
	if movers[id] then
		return movers[id]
	end
	local list = {}
	local biome = biomes:FindFirstChild(id)
	local props = biome and biome:FindFirstChild("Props")
	if props then
		for _, p in props:GetChildren() do
			local cf, box, size
			if p:IsA("Model") then
				cf = p:GetPivot()
				box, size = p:GetBoundingBox()
			elseif p:IsA("BasePart") then
				cf, box, size = p.CFrame, p.CFrame, p.Size
			end
			local name = p.Name:lower()
			local kind = (name:find("crystal") or name:find("asteroid") or name:find("orb")) and "bob" or SWAY[p.Name] and "sway"
			if cf and kind then
				table.insert(list, { inst = p, cf = cf, bottom = CFrame.new(box.Position - V3(0, size.Y / 2, 0)), h = size.Y, phase = math.random() * math.pi * 2, kind = kind,
					speed = 0.6 + math.random() * 0.5, amp = math.rad(1.2 + math.random() * 1.6) / math.max(1, size.Y / 18) })
			end
		end
	end
	movers[id] = list
	return list
end

-- Keep gameplay geometry fixed; only nearby, noncolliding client copies move.
local motion = Instance.new("Folder")
motion.Name, motion.Parent = "BiomeMotion", workspace.CurrentCamera
local function releaseVisual(m)
	if not m.visual then return end
	m.visual:Destroy()
	m.visual = nil
	for part, transparency in m.hidden do
		if part.Parent then part.LocalTransparencyModifier = transparency end
	end
	m.hidden = nil
end
local function showVisual(m)
	if m.visual then return m.visual end
	local copy = m.inst:Clone()
	if not copy then return nil end
	local parts = copy:GetDescendants()
	if copy:IsA("BasePart") then table.insert(parts, copy) end
	for _, part in parts do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		end
	end
	m.hidden = {}
	parts = m.inst:GetDescendants()
	if m.inst:IsA("BasePart") then table.insert(parts, m.inst) end
	for _, part in parts do
		if part:IsA("BasePart") then
			m.hidden[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	copy.Parent = motion
	m.visual = copy
	return copy
end
local function restore(id)
	for _, m in movers[id] or {} do releaseVisual(m) end
end

-- patches and nests: emitters + lava glow, built once, only enabled in the current biome
local local_fx = {} -- [biomeId] = { emitters, lights, flows }
local function buildLocalFx(id)
	if local_fx[id] then
		return local_fx[id]
	end
	local fx = { emitters = {}, lights = {}, flows = {}, patches = {} }
	local biome = biomes:FindFirstChild(id)
	if biome then
		local spec = PATCH[id]
		local accent = Config.BiomeById[id] and Config.BiomeById[id].look.accent or rgb(255, 255, 255)
		for _, d in biome:GetDescendants() do
			if spec and d:IsA("BasePart") and d.Name == "EscapeLane" then
				-- EscapeLane can be an invisible gameplay volume; effects belong on the visible surface.
				local surface = d.Parent:FindFirstChild("River") or d.Parent:FindFirstChild("Lava")
					or d.Parent:FindFirstChild("Shelf") or d.Parent:FindFirstChild("MesaTop") or d
				local host = surface
				if surface.Transparency < 1 then
					host = Instance.new("Part")
					host.Name = "BiomeVFXSurface"
					host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch = true, false, false, false
					host.Transparency = 1
					host.Size = V3(surface.Size.X, 0.05, surface.Size.Z)
					host.CFrame = surface.CFrame * CFrame.new(0, surface.Size.Y / 2 + 0.05, 0)
					host.Parent = surface
				end
				local e = emitter(spec, host)
				e:SetAttribute("Biome", id)
				table.insert(fx.emitters, e)
				-- the shared "safe spot" look: a soft outline in the biome's accent colour (the whole patch model when it has one)
				local glow = Instance.new("Highlight")
				glow.Name = "PatchGlow"
				glow.Adornee = d.Parent:IsA("Model") and d.Parent or surface
				glow.FillColor, glow.OutlineColor = accent, accent
				glow.FillTransparency, glow.OutlineTransparency = 1, 0.45
				glow.DepthMode = Enum.HighlightDepthMode.Occluded
				glow.Enabled = false
				glow.Parent = host
				table.insert(fx.patches, { lane = d, emitter = e, glow = glow, rate = spec.Rate, speed = e.Speed })
				if id == "Lake" or id == "Jungle" or id == "Volcano" then
					local texture = Instance.new("Texture")
					texture.Name, texture.Face = "BiomeFlow", Enum.NormalId.Top
					texture.Texture = id == "Volcano" and FIRE or SMOKE
					texture.Color3 = id == "Volcano" and rgb(255, 205, 85) or rgb(210, 235, 245)
					texture.StudsPerTileU, texture.StudsPerTileV = 8, 8
					texture.Transparency = 1
					texture.Parent = surface
					table.insert(fx.flows, { texture = texture, speed = id == "Volcano" and 0.35 or 0.7,
						transparency = id == "Volcano" and 0.65 or 0.82 })
				end
				if id == "Volcano" then
					local light = Instance.new("PointLight")
					light.Color = rgb(255, 110, 40)
					light.Range = 18
					light.Brightness = 1.5
					light.Enabled = false
					light.Parent = host
					table.insert(fx.lights, light)
				end
			elseif d.Name == "Nest" and (d:IsA("BasePart") or d:IsA("Model")) then
				local host = d:IsA("Model") and (d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart", true)) or d
				if host then
					table.insert(fx.emitters, emitter({ Texture = SPARK, Color = rgb(255, 235, 150), Size = ns(0.5, 0), Rate = 5,
						Life = 2, Speed = 1.5, Dir = V3(0, 1, 0), Light = 1, Spread = 60 }, host))
				end
			end
		end
	end
	local_fx[id] = fx
	return fx
end

local function biomeAt(z)
	for _, b in Config.Biomes do
		local m = biomes:FindFirstChild(b.id)
		if m and z <= m:GetAttribute("EntranceZ") + 10 and z >= m:GetAttribute("FarZ") - 10 then
			return b.id
		end
	end
	return nil
end

local current
local function setBiome(id)
	if id == current then
		return
	end
	if current then
		for _, e in air[current] or {} do
			e.Enabled = false
			e:Clear()
		end
		local old = local_fx[current]
		if old then
			for _, e in old.emitters do
				e.Enabled = false
				e:Clear()
			end
			for _, flow in old.flows do flow.texture.Transparency = 1 end
			for _, pt in old.patches do pt.glow.Enabled = false end
			for _, l in old.lights do
				l.Enabled = false
			end
		end
		restore(current)
	end
	current = id
	for _, e in air[id] or {} do
		e.Enabled = true
	end
	if id ~= "Home" then
		local fx = buildLocalFx(id)
		for _, e in fx.emitters do
			e.Enabled = true
		end
		for _, l in fx.lights do
			l.Enabled = true
		end
		collectMovers(id)
	end
	local look = LIGHT[id] or LIGHT.Home
	TweenService:Create(bloom, TWEEN, { Intensity = look.bloom, Threshold = look.threshold }):Play()
	TweenService:Create(rays, TWEEN, { Intensity = look.rays }):Play()
end

task.spawn(function()
	local firstEntrance = biomes:WaitForChild(Config.Biomes[1].id):GetAttribute("EntranceZ")
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local z = root and root.Position.Z or workspace.CurrentCamera.CFrame.Position.Z
		setBiome(biomeAt(z) or (z > firstEntrance and "Home" or current or "Home"))
		task.wait(0.5)
	end
end)

-- per frame: carry the air boxes with the camera, sway nearby props, pulse lava light, warn on patches
local MAX_MOVERS, NEAR = 60, 160
local WARN = Config.Patch.warn
local function onLane(lane: BasePart, pos: Vector3): boolean -- same test as AbilityService's inside()
	local p, s = lane.CFrame:PointToObjectSpace(pos), lane.Size
	return math.abs(p.X) <= s.X / 2 and math.abs(p.Z) <= s.Z / 2 and p.Y >= -s.Y / 2 - 1
		and p.Y <= s.Y / 2 + (lane:GetAttribute("Headroom") or 12)
end
local frame = 0
RunService.RenderStepped:Connect(function()
	local camPos = workspace.CurrentCamera.CFrame.Position
	local biome = current and biomes:FindFirstChild(current)
	local floor = biome and biome:FindFirstChild("Floor")
	local ground = floor and floor.Position.Y + floor.Size.Y / 2 or camPos.Y - 6
	for _, box in workspace.CurrentCamera:GetChildren() do
		if box:GetAttribute("AirHost") then
			local low = box:GetAttribute("Low")
			box.Position = V3(camPos.X, low and ground + box.Size.Y / 2 + 0.05
				or math.max(camPos.Y + 5, ground + box.Size.Y / 2 + 0.05), camPos.Z)
		end
	end
	frame += 1
	if frame % 2 == 1 or not current or current == "Home" then
		return
	end
	local t = os.clock()
	local n = 0
	for _, m in movers[current] or {} do
		local p = m.cf.Position
		if n < MAX_MOVERS and (p - camPos).Magnitude < NEAR and m.inst.Parent then
			n += 1
			local wave = math.sin(t * m.speed + m.phase)
			local cf
			if m.kind == "bob" then
				cf = m.cf * CFrame.new(0, wave * 0.6, 0) * CFrame.Angles(0, t * 0.3 + m.phase, 0)
			else
				local base = m.bottom
				cf = base * CFrame.Angles(wave * m.amp, 0, math.cos(t * m.speed * 0.8 + m.phase) * m.amp) * base:Inverse() * m.cf
			end
			local visual = showVisual(m)
			if visual then visual:PivotTo(cf) end
		else
			releaseVisual(m)
		end
	end
	local fx = local_fx[current]
	if fx then
		for _, e in fx.emitters do
			e.Enabled = (e.Parent.Position - camPos).Magnitude < NEAR
		end
		for _, flow in fx.flows do
			local texture = flow.texture
			local nearby = (texture.Parent.Position - camPos).Magnitude < NEAR
			texture.Transparency = nearby and flow.transparency or 1
			if nearby then
				texture.OffsetStudsU = (t * flow.speed) % texture.StudsPerTileU
				texture.OffsetStudsV = (t * flow.speed * 0.4) % texture.StudsPerTileV
			end
		end
		for i, l in fx.lights do
			l.Enabled = (l.Parent.Position - camPos).Magnitude < NEAR
			l.Brightness = 1.2 + 0.6 * math.sin(t * 2.2 + i)
		end
		-- sink warning on the patch you're standing on (the server stamps PatchSince; it sinks you at stuckAfter)
		local since = player:GetAttribute("PatchSince")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local elapsed = since and root and workspace:GetServerTimeNow() - since
		for _, pt in fx.patches do
			pt.glow.Enabled = (pt.emitter.Parent.Position - camPos).Magnitude < NEAR
			local mine = elapsed and onLane(pt.lane, root.Position)
			if mine and elapsed >= WARN.flash then
				local pulse = 0.5 + 0.5 * math.sin(t * 12)
				pt.glow.OutlineTransparency, pt.glow.FillTransparency = 0.05 + 0.35 * pulse, 0.75 + 0.2 * pulse
			else
				pt.glow.OutlineTransparency, pt.glow.FillTransparency = 0.45, 1
			end
			local frantic = mine and elapsed >= WARN.frantic
			if frantic ~= (pt.emitter.Rate > pt.rate) then
				pt.emitter.Rate = frantic and pt.rate * 4 or pt.rate
				pt.emitter.Speed = frantic and NumberRange.new(pt.speed.Min * 2, pt.speed.Max * 2) or pt.speed
			end
		end
	end
end)
