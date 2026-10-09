-- Player bases: the look upgrades with rebirths (Config.Base.tiers) and shows the owner's equipped cosmetics.
-- Cosmetics are bought with Cash through ShopService ("base:<itemId>"); buying an owned item just equips it.
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local BaseService = {}
local Base = Config.Base
local rgb = Color3.fromRGB
local DEFAULTS = {} -- [slot] = free default item id
for _, item in Base.items do
	if item.price == 0 then
		DEFAULTS[item.slot] = item.id
	end
end

-- Cost to take this item: nil = not for sale, 0 = owned or free (equip only)
function BaseService.price(data, itemId): number?
	local item = Base.itemById[itemId]
	if not item then
		return nil
	end
	return (item.price == 0 or data.Base.owned[itemId]) and 0 or item.price
end

function BaseService.equipped(data, slot: string): string
	local id = data and data.Base.equipped[slot]
	return id and Base.itemById[id] and id or DEFAULTS[slot]
end

local function part(parent, size, cframe, color, material, props, class)
	local p = Instance.new(class or "Part")
	p.Size, p.CFrame, p.Color = size, cframe, color
	p.Material = Enum.Material[material or "SmoothPlastic"]
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end
local function ball(parent, diameter, pos, color, material, props)
	local p = part(parent, Vector3.one * diameter, CFrame.new(pos), color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end
local function upright(parent, diameter, height, base: Vector3, color, material, props) -- cylinder standing on base
	local p = part(parent, Vector3.new(height, diameter, diameter), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function glow(p, color, range)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, range, 1.5
	light.Parent = p
end
local FLAT = { CanCollide = false, CanQuery = false, CanTouch = false }

-- Interaction feedback: a game SFX played at the part, and a one-shot particle burst
local function sfx(name: string, at: BasePart)
	local src = SoundService:FindFirstChild("SFX") and SoundService.SFX:FindFirstChild(name)
	if src then
		local sound = src:Clone()
		sound.Parent = at
		sound:Play()
		Debris:AddItem(sound, 6)
	end
end
local function burst(at: BasePart, color: Color3, count: number, speed: number)
	local e = Instance.new("ParticleEmitter")
	e.Color, e.LightEmission, e.Rate = ColorSequence.new(color), 0.4, 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Speed, e.Lifetime, e.SpreadAngle = NumberRange.new(speed * 0.6, speed), NumberRange.new(0.6, 1.1), Vector2.new(60, 60)
	e.EmissionDirection, e.Acceleration = Enum.NormalId.Top, Vector3.new(0, -20, 0)
	e.Parent = at
	e:Emit(count)
	Debris:AddItem(e, 2)
end
local function prompt(at: BasePart, action: string, onlyFor: number?, onTrigger)
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.HoldDuration, p.MaxActivationDistance, p.RequiresLineOfSight = action, 0, 8, false
	if onlyFor then
		p:SetAttribute("OnlyFor", onlyFor) -- ClientMain shows it only to this player
	end
	p.Triggered:Connect(onTrigger)
	p.Parent = at
	return p
end

-- a real Seat; a rider who bumps into one is stood back up (like the Plaza benches). onSit(seat, sitting) for walkers.
local function seat(parent, size, cframe, color, material, onSit)
	local s = part(parent, size, cframe, color, material, nil, "Seat")
	local seated = false
	s:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = s.Occupant
		local player = hum and Players:GetPlayerFromCharacter(hum.Parent)
		if player and player:GetAttribute("Riding") then
			local weld = s:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			hum.Sit = false
		elseif onSit and (hum ~= nil) ~= seated then
			seated = hum ~= nil
			onSit(s, seated)
		end
	end)
	return s
end

-- Base frame: d = studs in from the entrance wall, l = sideways (lock button is at l = +12), y = above the floor top
local function frame(plot)
	local floor = plot.Floor
	local inward = Vector3.new(plot:GetAttribute("Side"), 0, 0)
	local origin = floor.Position + Vector3.new(0, floor.Size.Y / 2, 0) - inward * (floor.Size.X / 2)
	return function(d, l, y)
		return origin + inward * d + Vector3.new(0, y or 0, l)
	end
end

-- Cosmetic builders: (folder, at, item, accent)
local BUILD = {}
local PLANT_SPOTS = { { 3, -26 }, { 3, 26 }, { 55, -26 }, { 55, 26 } }
local function eachPlant(fn) -- each spot is a "Plant" model pivoting at its base (watering bounces it)
	return function(folder, at)
		for _, s in PLANT_SPOTS do
			local plant = Instance.new("Model")
			plant.Name = "Plant"
			fn(plant, at(s[1], s[2]))
			plant.WorldPivot = CFrame.new(at(s[1], s[2]))
			plant.Parent = folder
		end
	end
end
BUILD.plantsFern = eachPlant(function(f, base)
	upright(f, 2.2, 1.6, base, rgb(190, 100, 60), "Slate")
	ball(f, 2.8, base + Vector3.new(0, 2.6, 0), rgb(70, 160, 70), "Grass")
end)
BUILD.plantsFlowers = eachPlant(function(f, base)
	part(f, Vector3.new(4, 0.8, 4), CFrame.new(base + Vector3.new(0, 0.4, 0)), rgb(120, 80, 50), "Wood")
	part(f, Vector3.new(3.4, 0.2, 3.4), CFrame.new(base + Vector3.new(0, 0.85, 0)), rgb(90, 60, 40), "Ground")
	for i, color in { rgb(255, 90, 120), rgb(255, 220, 80), rgb(170, 110, 255), rgb(255, 255, 255), rgb(255, 150, 60), rgb(90, 200, 255) } do
		local a = i * math.pi / 3
		ball(f, 0.9, base + Vector3.new(math.cos(a) * 1.1, 1.4, math.sin(a) * 1.1), color, "SmoothPlastic", FLAT)
	end
end)
BUILD.plantsPalm = eachPlant(function(f, base)
	upright(f, 1, 6, base, rgb(150, 110, 70), "Wood")
	for i = 1, 5 do
		local top = base + Vector3.new(0, 6, 0)
		part(f, Vector3.new(0.3, 1.4, 4.5), CFrame.new(top) * CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.Angles(math.rad(20), 0, 0)
			* CFrame.new(0, 0, -2), rgb(60, 170, 70), "Grass", FLAT)
	end
	ball(f, 0.8, base + Vector3.new(0.4, 5.6, 0.3), rgb(110, 75, 40), "Wood", FLAT)
end)
BUILD.plantsCrystal = eachPlant(function(f, base)
	upright(f, 2.4, 0.8, base, rgb(60, 60, 80), "Slate")
	for i = 1, 3 do
		local c = part(f, Vector3.new(0.9, 3 + i, 0.9), CFrame.new(base + Vector3.new(0, 2.2 + i * 0.3, 0)) * CFrame.Angles(0, i * 2.1, 0)
			* CFrame.Angles(math.rad(18), 0, 0), rgb(130, 230, 255), "Neon", FLAT)
		if i == 2 then
			glow(c, rgb(130, 230, 255), 10)
		end
	end
end)
BUILD.plantsCactus = eachPlant(function(f, base)
	local green = rgb(70, 150, 70)
	upright(f, 2.4, 0.8, base, rgb(230, 200, 140), "Sand")
	upright(f, 1.2, 4, base + Vector3.new(0, 0.8, 0), green, "Grass")
	for _, side in { -1, 1 } do
		part(f, Vector3.new(1.2, 0.7, 0.7), CFrame.new(base + Vector3.new(side * 0.9, 2.6 + side * 0.5, 0)), green, "Grass")
		upright(f, 0.7, 1.4, base + Vector3.new(side * 1.3, 2.6 + side * 0.5, 0), green, "Grass")
	end
	ball(f, 0.6, base + Vector3.new(0, 4.9, 0), rgb(255, 120, 170), "SmoothPlastic", FLAT) -- flower
end)
BUILD.plantsSakura = eachPlant(function(f, base)
	upright(f, 1, 5, base, rgb(110, 75, 55), "Wood")
	for _, o in { Vector3.new(0, 6.2, 0), Vector3.new(1.3, 5.5, 0.6), Vector3.new(-1.2, 5.6, -0.7), Vector3.new(0.2, 5.4, -1.4) } do
		ball(f, 3.2, base + o, rgb(255, 175, 205), "Grass", FLAT)
	end
end)

local SEAT_D, SEAT_L = 5, -18
local function seating(fn)
	return function(folder, at)
		local base = at(SEAT_D, SEAT_L)
		fn(folder, CFrame.lookAt(base, base + Vector3.new(0, 0, 1))) -- faces the middle of the base
	end
end
BUILD.seatingBench = seating(function(f, cf)
	local wood = rgb(150, 100, 60)
	for _, x in { -1.5, 1.5 } do
		seat(f, Vector3.new(3, 0.5, 2), cf * CFrame.new(x, 1.5, 0), wood, "WoodPlanks")
	end
	part(f, Vector3.new(6, 1.8, 0.4), cf * CFrame.new(0, 2.6, 0.9), wood, "WoodPlanks")
	for _, x in { -2.5, 2.5 } do
		part(f, Vector3.new(0.5, 1.3, 1.8), cf * CFrame.new(x, 0.65, 0), rgb(60, 60, 70), "Metal")
	end
end)
BUILD.seatingPicnic = seating(function(f, cf)
	local wood = rgb(170, 120, 75)
	part(f, Vector3.new(6, 0.4, 3), cf * CFrame.new(0, 2.6, -2.5), wood, "WoodPlanks")
	part(f, Vector3.new(1, 2.4, 1), cf * CFrame.new(0, 1.2, -2.5), wood, "Wood")
	for _, side in { cf, cf * CFrame.new(0, 0, -5) * CFrame.Angles(0, math.pi, 0) } do -- both benches face the table
		for _, x in { -1.5, 1.5 } do
			seat(f, Vector3.new(3, 0.4, 1.2), side * CFrame.new(x, 1.4, 0), wood, "WoodPlanks")
		end
	end
	part(f, Vector3.new(1.2, 0.6, 1.2), cf * CFrame.new(-1.5, 3.1, -2.5), rgb(230, 60, 60), "SmoothPlastic") -- picnic basket
end)
BUILD.seatingBeanbags = seating(function(f, cf)
	for i, color in { rgb(255, 110, 90), rgb(90, 170, 255), rgb(255, 210, 80) } do
		local p = seat(f, Vector3.new(3.2, 2, 3.2), cf * CFrame.new((i - 2) * 3.6, 1, 0), color, "Fabric", function(bag, sitting)
			local height = sitting and 1.3 or 2 -- squish while someone sits, keeping the bottom on the floor
			TweenService:Create(bag, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = Vector3.new(3.2, height, 3.2),
				CFrame = cf * CFrame.new((i - 2) * 3.6, height / 2, 0) }):Play()
		end)
		p.Shape = Enum.PartType.Ball
	end
end)
BUILD.seatingSofa = seating(function(f, cf)
	local fabric = rgb(70, 95, 170)
	part(f, Vector3.new(6, 1, 2.4), cf * CFrame.new(0, 0.5, 0.2), fabric, "Fabric")
	for _, x in { -1.5, 1.5 } do
		seat(f, Vector3.new(3, 0.5, 2), cf * CFrame.new(x, 1.25, 0), rgb(90, 120, 200), "Fabric")
	end
	part(f, Vector3.new(6, 2, 0.6), cf * CFrame.new(0, 2, 1.1), fabric, "Fabric")
	for _, x in { -3.2, 3.2 } do
		part(f, Vector3.new(0.6, 1.8, 2.4), cf * CFrame.new(x, 0.9, 0.2), fabric, "Fabric")
	end
end)
BUILD.seatingCampfire = seating(function(f, cf)
	local pit = cf * CFrame.new(0, 0, -3)
	for i = 1, 8 do
		local a = i * math.pi / 4
		ball(f, 0.9, (pit * CFrame.new(math.cos(a) * 1.4, 0.35, math.sin(a) * 1.4)).Position, rgb(120, 120, 125), "Slate")
	end
	for i = 1, 3 do
		part(f, Vector3.new(2.2, 0.4, 0.4), pit * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, i * math.pi / 3, 0), rgb(100, 65, 40), "Wood")
	end
	local flame = part(f, Vector3.new(0.6, 0.6, 0.6), pit * CFrame.new(0, 0.6, 0), rgb(255, 140, 40), "Neon",
		{ Name = "Lamp", Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	Instance.new("Fire", flame).Size = 4
	glow(flame, rgb(255, 150, 60), 18)
	for _, side in { cf, cf * CFrame.new(0, 0, -6) * CFrame.Angles(0, math.pi, 0) } do -- log seats face the fire
		local log = seat(f, Vector3.new(4, 1.2, 1.2), side * CFrame.new(0, 0.6, 0), rgb(120, 80, 50), "Wood")
		log.Shape = Enum.PartType.Cylinder
	end
end)
BUILD.seatingThrone = seating(function(f, cf)
	local gold, red = rgb(255, 200, 60), rgb(180, 25, 40)
	part(f, Vector3.new(4, 1.5, 4), cf * CFrame.new(0, 0.75, 0), gold, "Foil")
	seat(f, Vector3.new(3.4, 0.6, 3.4), cf * CFrame.new(0, 1.8, 0), red, "Fabric", function(cushion, sitting)
		if sitting then
			burst(cushion, gold, 40, 14)
			sfx("RarityReveal", cushion)
		end
	end)
	part(f, Vector3.new(4, 6, 0.8), cf * CFrame.new(0, 4, 1.6), gold, "Foil")
	part(f, Vector3.new(3, 4.5, 0.2), cf * CFrame.new(0, 3.9, 1.15), red, "Fabric")
	for _, x in { -1.8, 1.8 } do
		part(f, Vector3.new(0.5, 1.2, 3.4), cf * CFrame.new(x, 2.4, 0), gold, "Foil")
	end
	ball(f, 1.2, (cf * CFrame.new(0, 7.4, 1.6)).Position, rgb(255, 80, 120), "Neon")
end)

-- bases run along world X (d) with l along Z, so flat parts are sized (depth, height, width)
BUILD.rugMat = function(f, at, item)
	part(f, Vector3.new(4, 0.06, 6), CFrame.new(at(3.5, 0, 0.03)), item.color, "Fabric", FLAT)
end
BUILD.rugRound = function(f, at, item)
	upright(f, 11, 0.06, at(5, 0), item.color, "Fabric", FLAT)
	upright(f, 8, 0.07, at(5, 0), rgb(240, 220, 160), "Fabric", FLAT)
end
BUILD.rugCarpet = function(f, at, item)
	part(f, Vector3.new(9, 0.06, 7), CFrame.new(at(4.5, 0, 0.03)), item.color, "Fabric", FLAT)
	for _, l in { -3.7, 3.7 } do
		part(f, Vector3.new(9, 0.07, 0.4), CFrame.new(at(4.5, l, 0.035)), rgb(255, 200, 60), "Foil", FLAT)
	end
end
BUILD.rugRainbow = function(f, at)
	for i, color in { rgb(240, 70, 70), rgb(255, 160, 50), rgb(255, 225, 70), rgb(90, 200, 100), rgb(70, 140, 240), rgb(160, 90, 230) } do
		part(f, Vector3.new(1.3, 0.06, 7), CFrame.new(at(1.25 + i * 1.3, 0, 0.03)), color, "Fabric", FLAT)
	end
end
BUILD.rugGold = function(f, at, item)
	part(f, Vector3.new(9, 0.06, 7), CFrame.new(at(4.5, 0, 0.03)), item.color, "Fabric", FLAT)
	for _, l in { -3.7, 3.7 } do
		part(f, Vector3.new(9, 0.07, 0.4), CFrame.new(at(4.5, l, 0.035)), rgb(255, 255, 255), "Fabric", FLAT)
	end
end

local LIGHT_SPOTS = { { 2, -11 }, { 2, 11 }, { 56, -10 }, { 56, 10 } }
BUILD.lightsLanterns = function(f, at)
	for _, s in LIGHT_SPOTS do
		local base = at(s[1], s[2])
		upright(f, 0.4, 3, base, rgb(50, 45, 40), "Metal")
		local lamp = part(f, Vector3.new(1, 1.2, 1), CFrame.new(base + Vector3.new(0, 3.6, 0)), rgb(255, 200, 110), "Neon", { Name = "Lamp" })
		glow(lamp, rgb(255, 200, 120), 14)
	end
end
BUILD.lightsPosts = function(f, at)
	for _, s in LIGHT_SPOTS do
		local base = at(s[1], s[2])
		upright(f, 0.6, 7.5, base, rgb(40, 45, 55), "Metal")
		local lamp = ball(f, 1.6, base + Vector3.new(0, 8.1, 0), rgb(255, 245, 210), "Neon", { Name = "Lamp" })
		glow(lamp, rgb(255, 240, 200), 20)
	end
end
local STRIP = { Name = "Lamp", CanCollide = false, CanQuery = false, CanTouch = false }
BUILD.lightsNeon = function(f, at, _, accent)
	for _, l in { -28.6, 28.6 } do -- along both side walls, on the floor
		part(f, Vector3.new(57, 0.25, 0.4), CFrame.new(at(29, l, 0.12)), accent, "Neon", STRIP)
	end
	part(f, Vector3.new(0.4, 0.25, 57), CFrame.new(at(57.6, 0, 0.12)), accent, "Neon", STRIP)
end
BUILD.lightsTorches = function(f, at)
	for _, s in LIGHT_SPOTS do
		local base = at(s[1], s[2])
		upright(f, 0.5, 4, base, rgb(90, 60, 40), "Wood")
		local head = part(f, Vector3.new(0.9, 0.7, 0.9), CFrame.new(base + Vector3.new(0, 4.3, 0)), rgb(50, 45, 40), "Slate", { Name = "Lamp" })
		Instance.new("Fire", head).Size = 2.5
		glow(head, rgb(255, 150, 60), 14)
	end
end
local DISCO_SPIN = 1.5 -- rad/s
-- Players standing still near a lit disco ball dance (Roblox's default /e dance animations; played on the server so all see it)
local DANCES = { [Enum.HumanoidRigType.R15] = { 507771019, 507776043, 507777268 }, [Enum.HumanoidRigType.R6] = { 182435998, 182491037, 182491065 } }
local DANCE_RANGE, STILL_SPEED = 20, 1.5
local function danceTick(tracks, floor: Vector3, lit: boolean)
	for hum in tracks do -- forget characters that respawned or left
		if not hum.Parent then
			tracks[hum] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			local flat = Vector3.new(1, 0, 1)
			local want = lit and hum.Health > 0 and not hum.Sit and not player:GetAttribute("Riding")
				and ((root.Position - floor) * flat).Magnitude < DANCE_RANGE and (root.AssemblyLinearVelocity * flat).Magnitude < STILL_SPEED
			local track = tracks[hum]
			if want and not track then
				local ids = DANCES[hum.RigType]
				local anim = Instance.new("Animation")
				anim.AnimationId = "rbxassetid://" .. ids[math.random(#ids)]
				track = animator:LoadAnimation(anim)
				track.Priority, track.Looped = Enum.AnimationPriority.Action, true
				tracks[hum] = track
			end
			if track and want ~= track.IsPlaying then
				if want then
					track:Play(0.3)
				else
					track:Stop(0.3)
				end
			end
		end
	end
end
BUILD.lightsDisco = function(f, at)
	local base = at(53, 0) -- behind the Pen, in the middle
	local pole = upright(f, 0.5, 9, base, rgb(40, 45, 55), "Metal")
	local center = base + Vector3.new(0, 10.5, 0)
	local disco = ball(f, 3, center, rgb(220, 225, 235), "Foil", { Name = "Lamp", Anchored = false, CanCollide = false, Massless = true })
	disco:AddTag("DiscoBall") -- DiscoSpots (client) draws where its beams land
	-- six spotlights tilted down at two angles, spread around the ball: coloured spots sweep the floor as it spins
	local lights = {}
	for i = 1, 6 do
		local aim = Instance.new("Attachment")
		aim.CFrame = CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.Angles(math.rad(i % 2 == 0 and -40 or -65), 0, 0)
		aim.Parent = disco
		local light = Instance.new("SpotLight") -- shines along the attachment's front (-Z)
		light.Range, light.Brightness, light.Angle, light.Shadows = 28, 8, 30, true -- shadows: walls stop the beams
		light.Parent = aim
		lights[i] = light
	end
	local music = Instance.new("Sound") -- "Midnight Mirrorball" (DistroKid, free Creator Store audio); heard only near the base
	music.Name, music.SoundId, music.Looped, music.Volume = "Music", "rbxassetid://120757399216784", true, 0.4
	music.RollOffMode, music.RollOffMinDistance, music.RollOffMaxDistance = Enum.RollOffMode.InverseTapered, 15, 60
	music.Playing = true
	music.Parent = disco
	-- colours cycle through the rainbow, a third of the wheel apart, until the ball is removed (repaint/leave)
	-- the same loop makes nearby players dance while the lights are on
	local alive, tracks = true, {} -- [humanoid] = its dance track
	disco.Destroying:Connect(function()
		alive = false
		for _, track in tracks do
			track:Stop(0.3)
		end
	end)
	task.spawn(function()
		local hue = 0
		while alive do
			hue = (hue + 0.04) % 1
			for i, light in lights do
				light.Color = Color3.fromHSV((hue + i / 3) % 1, 0.75, 1)
			end
			danceTick(tracks, base, music.Playing)
			task.wait(0.2)
		end
	end)
	-- spun by a motor hinge on the pole (physics replicates smoothly); its spotlights sweep the base
	local hinge = Instance.new("HingeConstraint")
	for i, p in { pole, disco } do
		local a = Instance.new("Attachment")
		a.Parent = p
		a.WorldCFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)) -- hinge axis (attachment X) points up
		hinge[i == 1 and "Attachment0" or "Attachment1"] = a
	end
	hinge.ActuatorType, hinge.AngularVelocity, hinge.MotorMaxTorque = Enum.ActuatorType.Motor, DISCO_SPIN, math.huge
	hinge.Parent = disco
end

local STATUE_D, STATUE_L = 5, 19 -- right of the entrance, past the lock button
local function statue(fn)
	return function(folder, at, item, accent)
		local base = at(STATUE_D, STATUE_L)
		fn(folder, base, CFrame.lookAt(base, at(STATUE_D - 1, STATUE_L)), item, accent) -- faces the entrance
	end
end
local function pedestal(f, base)
	part(f, Vector3.new(4.4, 1.4, 4.4), CFrame.new(base + Vector3.new(0, 0.7, 0)), rgb(200, 200, 210), "Marble")
	return base + Vector3.new(0, 1.4, 0)
end
-- a creature model cast in one colour and material
local function cast(f, species: string, rarity: string, top: Vector3, facing: CFrame, height: number, color, material)
	local m = CreatureBuilder.build(species, rarity)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.Color, d.Material, d.CanQuery, d.CanTouch = true, color, Enum.Material[material], false, false
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		elseif d:IsA("Beam") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Decal")
			or d:IsA("SurfaceAppearance") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * height / size.Y)
	CreatureBuilder.placeOn(m, CFrame.new(top) * facing.Rotation)
	m.Name = "Statue"
	m.Parent = f
end
BUILD.statueGnome = statue(function(f, base)
	upright(f, 2, 2.2, base, rgb(60, 110, 200), "SmoothPlastic")
	ball(f, 1.6, base + Vector3.new(0, 2.8, 0), rgb(255, 205, 170), "SmoothPlastic")
	ball(f, 1.4, base + Vector3.new(0, 2.3, -0.5), rgb(245, 245, 245), "SmoothPlastic")
	for i, d in { 1.8, 1.3, 0.8, 0.35 } do
		upright(f, d, 0.55, base + Vector3.new(0, 3.2 + i * 0.5, 0), rgb(220, 50, 50), "SmoothPlastic")
	end
end)
BUILD.statueChick = statue(function(f, base, facing)
	cast(f, "Chick", "Common", pedestal(f, base), facing, 3.5, rgb(235, 235, 240), "Marble")
end)
BUILD.statueDragon = statue(function(f, base, facing)
	cast(f, "BabyDragon", "Legendary", pedestal(f, base), facing, 6, rgb(255, 200, 60), "SmoothPlastic")
end)
BUILD.statueTrophy = statue(function(f, base)
	local gold = rgb(255, 200, 60)
	local top = pedestal(f, base)
	upright(f, 2, 0.5, top, gold, "SmoothPlastic")
	upright(f, 0.6, 1.6, top + Vector3.new(0, 0.5, 0), gold, "SmoothPlastic")
	upright(f, 2.6, 2, top + Vector3.new(0, 2.1, 0), gold, "SmoothPlastic")
	for _, x in { -1.5, 1.5 } do
		ball(f, 0.8, top + Vector3.new(x, 3.2, 0), gold, "SmoothPlastic")
	end
	glow(ball(f, 0.9, top + Vector3.new(0, 4.6, 0), rgb(255, 245, 160), "Neon"), rgb(255, 230, 120), 10)
end)
BUILD.statueFountain = statue(function(f, base)
	local stone = rgb(200, 200, 210)
	upright(f, 5, 1, base, stone, "Marble")
	upright(f, 4.4, 0.1, base + Vector3.new(0, 0.95, 0), rgb(90, 170, 230), "Glass", { Transparency = 0.3 })
	upright(f, 0.8, 2.5, base + Vector3.new(0, 1, 0), stone, "Marble")
	local bowl = upright(f, 2.4, 0.5, base + Vector3.new(0, 3.5, 0), stone, "Marble")
	local spray = Instance.new("ParticleEmitter")
	spray.Color, spray.Rate, spray.Speed, spray.SpreadAngle = ColorSequence.new(rgb(150, 210, 255)), 30, NumberRange.new(5, 7), Vector2.new(25, 25)
	spray.Size = NumberSequence.new(0.25, 0.05)
	spray.Lifetime, spray.Acceleration = NumberRange.new(0.8, 1), Vector3.new(0, -25, 0)
	spray.EmissionDirection = Enum.NormalId.Right -- the bowl is a cylinder tipped up: its +X face points to the sky
	spray.Parent = bowl
end)

-- banners hang on the inside of the back wall, in the base colour unless the item has its own
BUILD.bannersPlain = function(f, at, item, accent)
	for _, l in { -15, 0, 15 } do
		part(f, Vector3.new(0.2, 6, 4), CFrame.new(at(57.8, l, 6)), item.color or accent, "Fabric")
		part(f, Vector3.new(0.3, 0.3, 4.6), CFrame.new(at(57.8, l, 9.1)), rgb(90, 60, 40), "Wood")
	end
end
BUILD.bannersRoyal = function(f, at, item)
	for _, l in { -15, 0, 15 } do
		part(f, Vector3.new(0.2, 6, 4), CFrame.new(at(57.8, l, 6)), item.color, "Fabric")
		part(f, Vector3.new(0.22, 6, 0.5), CFrame.new(at(57.8, l, 6)), rgb(255, 200, 60), "Fabric")
		part(f, Vector3.new(0.3, 0.3, 4.6), CFrame.new(at(57.8, l, 9.1)), rgb(255, 200, 60), "SmoothPlastic")
	end
end
BUILD.bannersStar = function(f, at, item)
	for _, l in { -15, 0, 15 } do
		part(f, Vector3.new(0.2, 6, 4), CFrame.new(at(57.8, l, 6)), item.color, "Fabric")
		glow(ball(f, 1.4, at(57.6, l, 6.5), rgb(255, 230, 120), "Neon"), rgb(255, 230, 120), 8)
		part(f, Vector3.new(0.3, 0.3, 4.6), CFrame.new(at(57.8, l, 9.1)), rgb(200, 200, 220), "Metal")
	end
end

-- Lamps (owner toggles, saved in data.Base.lightsOff) and plants (anyone waters: bounce + splash)
local function setLamps(folder, off: boolean?)
	for _, lamp in folder:GetChildren() do
		if lamp.Name == "Lamp" then
			if lamp:GetAttribute("OnMaterial") == nil then
				lamp:SetAttribute("OnMaterial", lamp.Material.Name)
			end
			lamp.Material = off and Enum.Material.SmoothPlastic or Enum.Material[lamp:GetAttribute("OnMaterial")]
			for _, glowing in lamp:GetDescendants() do -- disco spotlights sit on attachments
				if glowing:IsA("Light") or glowing:IsA("Fire") then
					glowing.Enabled = not off
				elseif glowing:IsA("HingeConstraint") then -- the disco ball stops with the lights
					glowing.AngularVelocity = off and 0 or DISCO_SPIN
				elseif glowing.Name == "Music" then -- ...and so does its music
					glowing.Playing = not off
				end
			end
			local p = lamp:FindFirstChildOfClass("ProximityPrompt")
			if p then
				p.ActionText = off and "Lights On" or "Lights Off"
			end
		end
	end
end
local function water(plant: Model, target: BasePart)
	if plant:GetAttribute("Bouncing") then
		return
	end
	plant:SetAttribute("Bouncing", true)
	burst(target, rgb(90, 200, 255), 25, 10)
	burst(target, rgb(110, 200, 90), 12, 8)
	sfx("PatchSwim", target)
	task.spawn(function()
		for i = 1, 12 do
			plant:ScaleTo(1 + 0.18 * math.sin(math.pi * i / 12))
			task.wait(0.03)
		end
		plant:ScaleTo(1)
		plant:SetAttribute("Bouncing", nil)
	end)
end
local function interactions(plot, folder, data)
	local owner = plot:GetAttribute("OwnerUserId")
	for _, d in folder:GetChildren() do
		if d.Name == "Lamp" and owner and owner ~= 0 then
			local switch = prompt(d, "Lights Off", owner, function(who)
				local ownerData = who.UserId == owner and DataService.get(who)
				if ownerData then
					ownerData.Base.lightsOff = not ownerData.Base.lightsOff or nil
					setLamps(folder, ownerData.Base.lightsOff)
					sfx(ownerData.Base.lightsOff and "Lock" or "Unlock", d)
				end
			end)
			switch.MaxActivationDistance = 12 -- the disco ball hangs about 11 studs up
		elseif d.Name == "Plant" then
			local target = d:FindFirstChildWhichIsA("BasePart")
			prompt(target, "Water", nil, function()
				water(d, target)
			end)
		end
	end
	setLamps(folder, data and data.Base.lightsOff)
end

local function paint(plot, tierIndex: number, data)
	local tier = Base.tiers[tierIndex]
	if plot:GetAttribute("DefaultColor") == nil then -- the plot's original colour, before any paint
		local wall = plot:FindFirstChild("Wall")
		plot:SetAttribute("DefaultColor", wall and wall.Color or rgb(235, 80, 80))
		plot:SetAttribute("DefaultFloor", plot.Floor.Color)
	end
	local colorItem = Base.itemById[BaseService.equipped(data, "color")]
	local accent = colorItem.color or plot:GetAttribute("DefaultColor")
	for _, p in plot:GetChildren() do
		if p.Name == "Wall" then
			p.Color, p.Material = accent, Enum.Material[tier.wall]
			p.Transparency = tier.wall == "Glass" and 0.25 or 0
		elseif p.Name == "Trim" then
			p.Color, p.Material = tier.trim, Enum.Material[tier.trimMat]
		end
	end
	for _, post in plot.Sign:GetChildren() do
		if post.Name == "Post" then
			post.Color = accent
		end
	end
	local enclosure = plot:FindFirstChild("Enclosure")
	for _, fence in enclosure and enclosure:GetChildren() or {} do
		if fence.Name == "Fence" then
			fence.Color = accent
		end
	end
	local floorItem = Base.itemById[BaseService.equipped(data, "floor")]
	plot.Floor.Color = floorItem.color or plot:GetAttribute("DefaultFloor")
	plot.Floor.Material = Enum.Material[floorItem.material or "Concrete"]
	for _, pad in plot.Pen:GetChildren() do
		pad.Color, pad.Material = tier.pad, Enum.Material[tier.padMat]
	end
	for _, pad in plot.Incubators:GetChildren() do
		pad.Ring.Color = tier.ring
	end

	local old = plot:FindFirstChild("BaseDecor")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "BaseDecor"
	local at = frame(plot)
	if tier.pillar then -- corner pillars grow with each tier
		for _, d in { -0.5, 58.5 } do
			for _, l in { -29.5, 29.5 } do
				local base = at(d, l)
				part(folder, Vector3.new(2.4, tier.pillar, 2.4), CFrame.new(base + Vector3.new(0, tier.pillar / 2, 0)), accent, tier.wall,
					{ Transparency = tier.wall == "Glass" and 0.25 or 0 })
				local cap = ball(folder, tier.orbs and 2.2 or 3, base + Vector3.new(0, tier.pillar + (tier.orbs and 2.4 or 1), 0), tier.cap,
					tier.capMat or "Slate", tier.orbs and FLAT or nil)
				if tier.light then
					glow(cap, tier.cap, 12)
				end
			end
		end
	end
	if tier.dome then -- glass pods over the incubators
		for _, pad in plot.Incubators:GetChildren() do
			ball(folder, 6.6, pad.Position + Vector3.new(0, 2.4, 0), tier.ring, "Glass", { Transparency = 0.75, CanCollide = false, CanQuery = false,
				CanTouch = false, CastShadow = false })
		end
	end
	for _, slot in Base.slots do
		local id = BaseService.equipped(data, slot.id)
		if BUILD[id] then
			BUILD[id](folder, at, Base.itemById[id], accent)
		end
	end
	interactions(plot, folder, data)
	folder.Parent = plot
end

local function sync(player, data)
	player:SetAttribute("BaseTier", Config.baseTier(data.Rebirths))
	player:SetAttribute("BaseOwned", HttpService:JSONEncode(data.Base.owned))
	player:SetAttribute("BaseEquipped", HttpService:JSONEncode(data.Base.equipped))
end

-- Repaint the player's base (join, rebirth, purchase)
function BaseService.apply(player)
	local data = DataService.get(player)
	local plot = PlotService.get(player)
	if data and plot then
		paint(plot, Config.baseTier(data.Rebirths), data)
		sync(player, data)
	end
end

-- Back to the plain look when the owner leaves
function BaseService.reset(player)
	local plot = PlotService.get(player)
	if plot then
		paint(plot, 1, nil)
	end
end

function BaseService.start(ShopService)
	for _, plot in workspace.HomeRow.Plots:GetChildren() do
		paint(plot, 1, nil)
	end
	for _, item in Base.items do
		ShopService.extraItems["base:" .. item.id] = function(player, data)
			local cost = BaseService.price(data, item.id)
			return cost, function()
				data.Base.owned[item.id] = item.price > 0 or nil
				data.Base.equipped[item.slot] = item.id
				BaseService.apply(player)
			end
		end
	end
end

return BaseService
