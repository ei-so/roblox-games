-- Edit-time tool (not used at runtime): builds the Plaza's leaderboards, showcase, reward chest and town-square decor.
--   require(game.ServerStorage.BuildTools.BuildPlaza)()
-- Rerunning replaces only what it built (Leaderboards, Showcase, RewardChest, Decor, each shop's Stall + Keeper). PlazaService makes them work.
local Players = game:GetService("Players")
local rgb = Color3.fromRGB
local FLOOR = 0.4 -- top of Plaza.Floor
local DARK, NAVY, GOLD = rgb(40, 40, 55), rgb(35, 38, 56), rgb(255, 210, 80)

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cframe, color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props or {} do p[k] = v end
	p.Parent = parent
	return p
end
-- vertical cylinder standing on y (Roblox cylinders run along X, so tip them up)
local function disc(parent, name, diameter, height, x, y, z, color, material, props)
	local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(x, y + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local function sign(target, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = face, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, 0
	gui.Parent = target
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundColor3, t.Font, t.TextScaled, t.TextColor3, t.Text = UDim2.fromScale(1, 1), NAVY, Enum.Font.FredokaOne, true, GOLD, text
	t.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0.12, 0), UDim.new(0.12, 0), UDim.new(0.04, 0), UDim.new(0.04, 0)
	pad.Parent = t
end
local function prop(parent, biome, name, scale, x, z, yaw)
	local src = workspace.Biomes[biome].Props:FindFirstChild(name)
	if not src then return end
	local m = src:Clone()
	m:ScaleTo(m:GetScale() * scale)
	local box, size = m:GetBoundingBox()
	local pivotToBottom = m:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	m:PivotTo(CFrame.new(x, FLOOR + pivotToBottom, z) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	m.Parent = parent
end

local function weldTo(base, p)
	p.Anchored, p.CanCollide, p.Massless = false, false, true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = base, p, p
end
-- Shopkeeper rig standing behind the counter (faces -Z); PlazaService plays its idle and wave animations
local function keeper(shop, spec, x, z)
	local d = Instance.new("HumanoidDescription")
	d.HeadColor, d.LeftArmColor, d.RightArmColor = spec.skin, spec.skin, spec.skin
	d.TorsoColor, d.LeftLegColor, d.RightLegColor = spec.shirt, spec.pants, spec.pants
	local rig = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	rig.Name = "Keeper"
	local hum, root = rig.Humanoid, rig.HumanoidRootPart
	hum.DisplayName, hum.DisplayDistanceType, hum.NameDisplayDistance = spec.name, Enum.HumanoidDisplayDistanceType.Viewer, 45
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = hum end
	root.Anchored = true
	rig:ScaleTo(1.15)
	rig:PivotTo(CFrame.new(x, FLOOR + 1 + hum.HipHeight + root.Size.Y / 2, z))
	local head, torso = rig.Head, rig.UpperTorso
	local brim = part(rig, "HatBrim", Vector3.new(0.2, 2, 2), head.CFrame * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), spec.hat)
	brim.Shape = Enum.PartType.Cylinder
	local top = part(rig, "HatTop", Vector3.new(0.9, 1.3, 1.3), head.CFrame * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90)), spec.hat)
	top.Shape = Enum.PartType.Cylinder
	local apron = part(rig, "Apron", Vector3.new(1.7, 1.9, 0.15), torso.CFrame * CFrame.new(0, -0.45, -torso.Size.Z / 2 - 0.05), spec.apron)
	for _, p in { brim, top } do weldTo(head, p) end
	weldTo(torso, apron)
	rig.Parent = shop
end
-- Turns a shop kiosk into an open stall: Body becomes the counter (prompts stay on it), the keeper stands behind it
local SHOPS = {
	GearShop = { name = "Gus the Gearsmith", skin = rgb(234, 184, 146), shirt = rgb(200, 60, 60), pants = rgb(60, 60, 80),
		hat = rgb(60, 60, 80), apron = rgb(110, 75, 50), goods = "soda" },
	FuseMachine = { name = "Fizz the Fuser", skin = rgb(160, 110, 80), shirt = rgb(140, 80, 210), pants = rgb(45, 40, 70),
		hat = rgb(120, 60, 200), apron = rgb(230, 230, 240), goods = "orbs" },
	IndexBoard = { name = "Professor Page", skin = rgb(250, 215, 180), shirt = rgb(60, 120, 220), pants = rgb(90, 70, 50),
		hat = rgb(40, 40, 55), apron = rgb(180, 150, 100), goods = "books" },
}
local function stall(shop, spec)
	for _, name in { "Stall", "Keeper" } do
		local old = shop:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local body = shop.Body
	local x, z = shop.Base.Position.X, shop.Base.Position.Z
	local color = body.Color
	body.Size, body.CFrame = Vector3.new(10, 2.6, 2.5), CFrame.new(x, FLOOR + 1 + 1.3, z - 3.5)
	shop.Glow.Size, shop.Glow.CFrame = Vector3.new(10.4, 0.4, 2.9), CFrame.new(x, FLOOR + 1 + 2.8, z - 3.5)
	local m = model(shop, "Stall")
	part(m, "BackWall", Vector3.new(11, 8.5, 0.6), CFrame.new(x, FLOOR + 1 + 4.25, z + 4.7), color:Lerp(rgb(30, 30, 40), 0.45))
	part(m, "Shelf", Vector3.new(9, 0.3, 1.2), CFrame.new(x, FLOOR + 1 + 5.2, z + 3.9), rgb(150, 100, 60), Enum.Material.Wood)
	for _, dx in { -5.2, 5.2 } do
		part(m, "Post", Vector3.new(0.6, 8.5, 0.6), CFrame.new(x + dx, FLOOR + 1 + 4.25, z - 4.7), DARK)
	end
	-- striped awning: alternating strips in the shop color and white, sloping down toward the front
	for i = 0, 5 do
		part(m, "Awning", Vector3.new(11.6 / 6, 0.4, 10.6), CFrame.new(x - 5.8 + 11.6 / 12 * (2 * i + 1), FLOOR + 1 + 8.7, z)
			* CFrame.Angles(math.rad(-6), 0, 0), i % 2 == 0 and color or rgb(245, 245, 250))
	end
	-- goods on the counter ({dx, dz, height}) and the back shelf
	local spots = { { -3.5, -3.5, 3 }, { -2.3, -3.5, 3 }, { 3, -3.5, 3 }, { -3, 3.9, 5.35 }, { -1, 3.9, 5.35 }, { 1, 3.9, 5.35 }, { 3, 3.9, 5.35 } }
	for i, at in spots do
		local cf = CFrame.new(x + at[1], FLOOR + 1 + at[3], z + at[2])
		if spec.goods == "soda" then
			local c = i % 2 == 0 and rgb(80, 220, 120) or rgb(90, 170, 255)
			disc(m, "Soda", 0.7, 1.4, cf.X, cf.Y, cf.Z, c, Enum.Material.Glass, { Transparency = 0.15 })
			disc(m, "Cap", 0.5, 0.2, cf.X, cf.Y + 1.4, cf.Z, rgb(230, 230, 235), Enum.Material.Metal)
		elseif spec.goods == "orbs" then
			local c = ({ rgb(255, 120, 220), rgb(140, 200, 255), rgb(255, 215, 90) })[i % 3 + 1]
			part(m, "Orb", Vector3.new(1, 1, 1), cf * CFrame.new(0, 0.5, 0), c, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
		else
			local c = ({ rgb(170, 50, 50), rgb(50, 110, 170), rgb(60, 140, 70), rgb(200, 150, 50) })[i % 4 + 1]
			part(m, "Book", Vector3.new(0.4, 1.5, 1.1), cf * CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad((i % 3 - 1) * 8)), c)
		end
	end
	keeper(shop, spec, x, z + 1.2)
end

return function()
	local plaza = workspace.Plaza
	for shopName, spec in SHOPS do
		stall(plaza[shopName], spec)
	end
	for _, name in { "Leaderboards", "Showcase", "RewardChest", "Decor" } do
		local old = plaza:FindFirstChild(name)
		if old then old:Destroy() end
	end

	-- Leaderboards face the spawn / walkway (-Z).
	local boards = Instance.new("Folder")
	boards.Name = "Leaderboards"
	boards.Parent = plaza
	for _, spec in { { "TopIncome", -30 }, { "TopRebirths", 30 }, { "TopBases", 60 } } do
		local m = model(boards, spec[1])
		local x, z = spec[2], 211
		part(m, "Screen", Vector3.new(16, 10, 0.6), CFrame.new(x, FLOOR + 3 + 5, z), NAVY)
		part(m, "Frame", Vector3.new(16.8, 10.8, 0.4), CFrame.new(x, FLOOR + 8, z + 0.45), GOLD, Enum.Material.Neon)
		for _, dx in { -8.4, 8.4 } do
			part(m, "Post", Vector3.new(0.8, 13.5, 0.8), CFrame.new(x + dx, FLOOR + 6.75, z + 0.2), DARK)
		end
		m.PrimaryPart = m.Screen
	end

	-- Showcase: three pedestals at the front-left, creatures face the middle of the square (+X); sign hangs high behind them
	local show = model(plaza, "Showcase")
	for i, x in { -58, -46, -34 } do
		part(show, "Pedestal" .. i, Vector3.new(6, 2, 6), CFrame.new(x, FLOOR + 1, 150), rgb(240, 240, 248), Enum.Material.Marble)
		part(show, "Trim" .. i, Vector3.new(6.4, 0.3, 6.4), CFrame.new(x, FLOOR + 0.15, 150), GOLD, Enum.Material.Neon)
	end
	local board = part(show, "Sign", Vector3.new(22, 3, 0.5), CFrame.new(-46, FLOOR + 12, 155), NAVY)
	sign(board, Enum.NormalId.Front, "Rarest in this server")
	sign(board, Enum.NormalId.Back, "Rarest in this server")
	for _, dx in { -10.6, 10.6 } do
		part(show, "SignPost", Vector3.new(0.6, 13.5, 0.6), CFrame.new(-46 + dx, FLOOR + 6.75, 155), DARK)
	end

	-- Reward chest: front-right, near the Gear Shop
	local chest = model(plaza, "RewardChest")
	local body = part(chest, "Body", Vector3.new(5, 3, 3.5), CFrame.new(46, FLOOR + 1.5, 150), rgb(150, 95, 50), Enum.Material.Wood)
	part(chest, "Lid", Vector3.new(5.2, 1.2, 3.7), CFrame.new(46, FLOOR + 3.6, 150), rgb(125, 75, 40), Enum.Material.Wood)
	part(chest, "Band", Vector3.new(5.3, 0.4, 3.8), CFrame.new(46, FLOOR + 3, 150), GOLD, Enum.Material.Neon)
	part(chest, "Lock", Vector3.new(0.9, 1, 0.3), CFrame.new(46, FLOOR + 3, 150 + 1.95), GOLD, Enum.Material.Metal)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture, sparkle.Rate, sparkle.Lifetime, sparkle.Speed = "rbxasset://textures/particles/sparkles_main.dds", 6, NumberRange.new(1, 1.6), NumberRange.new(1, 2)
	sparkle.Color, sparkle.LightEmission, sparkle.Size = ColorSequence.new(GOLD), 0.6, NumberSequence.new(0.5, 0)
	sparkle.Parent = body
	chest.PrimaryPart = body

	-- Town-square decor: fountain in the middle, benches, lamps, trees and flowers
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = plaza
	local stone, water = rgb(200, 195, 185), rgb(90, 170, 230)
	disc(decor, "FountainBase", 18, 1.6, 0, FLOOR, 160, stone, Enum.Material.Concrete)
	disc(decor, "FountainWater", 16, 0.3, 0, FLOOR + 1.4, 160, water, Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	part(decor, "FountainPillar", Vector3.new(2, 5, 2), CFrame.new(0, FLOOR + 1.6 + 2.5, 160), stone, Enum.Material.Concrete)
	disc(decor, "FountainBowl", 6, 0.8, 0, FLOOR + 6.6, 160, stone, Enum.Material.Concrete)
	disc(decor, "FountainBowlWater", 5.4, 0.2, 0, FLOOR + 7.25, 160, water, Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	-- running water: a jet shooting up from the bowl, curtains spilling over its rim (Beams whose streak texture scrolls), splashes below
	local function nozzle(name, cframe)
		return part(decor, name, Vector3.new(0.2, 0.2, 0.2), cframe, water, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	local function droplets(parent, rate, life, speed, spread, size, transparency)
		local e = Instance.new("ParticleEmitter")
		e.Texture, e.Rate, e.Lifetime, e.Speed = "rbxasset://textures/particles/smoke_main.dds", rate, life, speed
		e.SpreadAngle, e.Acceleration, e.LightEmission = spread, Vector3.new(0, -30, 0), 0.2
		e.Color, e.Transparency, e.Size = ColorSequence.new(rgb(200, 232, 255)), transparency, size
		e.EmissionDirection, e.Parent = Enum.NormalId.Front, parent
	end
	droplets(nozzle("FountainJet", CFrame.new(0, FLOOR + 7.4, 160) * CFrame.Angles(math.rad(90), 0, 0)), 90, NumberRange.new(0.7, 0.9),
		NumberRange.new(11, 13), Vector2.new(5, 5), NumberSequence.new(0.6, 0.9), NumberSequence.new(0.1, 0.8))
	local center = Vector3.new(0, FLOOR, 160)
	local anchor = nozzle("FountainFlow", CFrame.new(center))
	for i = 1, 12 do
		local out = Vector3.new(math.cos(math.rad(i * 30)), 0, math.sin(math.rad(i * 30)))
		local function at(radius, y)
			local a = Instance.new("Attachment")
			a.Parent = anchor
			local pos = center + out * radius + Vector3.new(0, y, 0)
			a.WorldCFrame = CFrame.lookAt(pos, pos + out) -- beam curves outward over the rim
			return a
		end
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = at(3.05, 7.35), at(4.4, 1.75)
		b.Texture, b.TextureMode, b.TextureLength, b.TextureSpeed = "rbxassetid://135793337190488", Enum.TextureMode.Wrap, 4, 1.6
		b.Color, b.LightEmission, b.LightInfluence = ColorSequence.new(rgb(120, 190, 255)), 0.2, 0.6
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 0.65) })
		b.Width0, b.Width1, b.Segments, b.CurveSize0, b.FaceCamera = 1.8, 2.4, 12, 1.4, true
		b.Parent = anchor
		local land = center + out * 4.4 + Vector3.new(0, 1.75, 0)
		droplets(nozzle("FountainSplash", CFrame.lookAt(land, land + Vector3.yAxis, out)), 12, NumberRange.new(0.3, 0.4),
			NumberRange.new(3, 5), Vector2.new(40, 40), NumberSequence.new(0.4, 0.9), NumberSequence.new(0.2, 1))
	end
	local sound = Instance.new("Sound")
	sound.Name, sound.SoundId, sound.Looped, sound.Volume = "FountainSound", "rbxassetid://9120552550", true, 0.35
	sound.RollOffMode, sound.RollOffMinDistance, sound.RollOffMaxDistance = Enum.RollOffMode.InverseTapered, 8, 55
	sound.Playing = true
	sound.Parent = decor.FountainPillar
	for _, x in { -13, 13 } do
		local face = x < 0 and 90 or -90
		local seat = CFrame.new(x, FLOOR + 1.6, 160) * CFrame.Angles(0, math.rad(face), 0)
		for _, dx in { -1.5, 1.5 } do -- two real Seats per bench; PlazaService stands up anyone who sits while riding
			local s = Instance.new("Seat")
			s.Name, s.Size, s.CFrame, s.Color, s.Material = "BenchSeat", Vector3.new(3, 0.5, 2), seat * CFrame.new(dx, 0, 0), rgb(150, 100, 60), Enum.Material.Wood
			s.Anchored, s.TopSurface, s.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			s.Parent = decor
		end
		part(decor, "BenchBack", Vector3.new(6, 1.6, 0.4), seat * CFrame.new(0, 1, 1), rgb(150, 100, 60), Enum.Material.Wood)
		for _, dx in { -2.5, 2.5 } do
			part(decor, "BenchLeg", Vector3.new(0.4, 1.4, 1.6), seat * CFrame.new(dx, -0.95, 0), DARK)
		end
	end
	for _, at in { { -14, 146 }, { 14, 146 }, { -14, 200 }, { 14, 200 } } do
		part(decor, "LampPost", Vector3.new(0.5, 9, 0.5), CFrame.new(at[1], FLOOR + 4.5, at[2]), DARK, Enum.Material.Metal)
		local bulb = part(decor, "LampBulb", Vector3.new(1.4, 1.4, 1.4), CFrame.new(at[1], FLOOR + 9.6, at[2]), rgb(255, 230, 170), Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = 16, 1.2, rgb(255, 225, 170)
		light.Parent = bulb
	end
	prop(decor, "Forest", "Oak", 0.55, -70, 140, 20)
	prop(decor, "Forest", "Pine", 0.6, 70, 140, 0)
	prop(decor, "Forest", "Pine", 0.6, -72, 206, 45)
	prop(decor, "Forest", "Oak", 0.55, 72, 206, -30)
	for _, at in { { -22, 197 }, { 22, 197 }, { 30, 150 }, { -18, 150 } } do
		prop(decor, "Forest", "FlowerBush", 0.7, at[1], at[2], math.random(0, 359))
	end
	return "Plaza built: shop stalls + keepers, leaderboards, showcase, reward chest, decor"
end
