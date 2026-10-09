-- Edit-time tool (not used at runtime): builds the Plaza's leaderboards, showcase, reward chest and town-square decor.
--   require(game.ServerStorage.BuildTools.BuildPlaza)()
-- Rerunning replaces only what it built (Leaderboards, Showcase, RewardChest, Decor). PlazaService makes them work.
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

return function()
	local plaza = workspace.Plaza
	for _, name in { "Leaderboards", "Showcase", "RewardChest", "Decor" } do
		local old = plaza:FindFirstChild(name)
		if old then old:Destroy() end
	end

	-- Leaderboards: two boards flanking the Index Board, facing the spawn / walkway (-Z)
	local boards = Instance.new("Folder")
	boards.Name = "Leaderboards"
	boards.Parent = plaza
	for _, spec in { { "TopIncome", -30 }, { "TopRebirths", 30 } } do
		local m = model(boards, spec[1])
		local x, z = spec[2], 211
		part(m, "Screen", Vector3.new(16, 10, 0.6), CFrame.new(x, FLOOR + 3 + 5, z), NAVY)
		part(m, "Frame", Vector3.new(16.8, 10.8, 0.4), CFrame.new(x, FLOOR + 8, z + 0.45), GOLD, Enum.Material.Neon)
		for _, dx in { -8.4, 8.4 } do
			part(m, "Post", Vector3.new(0.8, 13.5, 0.8), CFrame.new(x + dx, FLOOR + 6.75, z + 0.2), DARK)
		end
		m.PrimaryPart = m.Screen
	end

	-- Showcase: three pedestals at the front-left, creatures face the spawn (+Z); sign behind them
	local show = model(plaza, "Showcase")
	for i, x in { -58, -46, -34 } do
		part(show, "Pedestal" .. i, Vector3.new(6, 2, 6), CFrame.new(x, FLOOR + 1, 150), rgb(240, 240, 248), Enum.Material.Marble)
		part(show, "Trim" .. i, Vector3.new(6.4, 0.3, 6.4), CFrame.new(x, FLOOR + 0.15, 150), GOLD, Enum.Material.Neon)
	end
	local board = part(show, "Sign", Vector3.new(18, 3, 0.5), CFrame.new(-46, FLOOR + 6, 144), NAVY)
	sign(board, Enum.NormalId.Back, "Rarest in this server")
	for _, dx in { -8.6, 8.6 } do
		part(show, "SignPost", Vector3.new(0.6, 7.5, 0.6), CFrame.new(-46 + dx, FLOOR + 3.75, 144), DARK)
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
	local bowl = disc(decor, "FountainBowl", 6, 0.8, 0, FLOOR + 6.6, 160, stone, Enum.Material.Concrete)
	local spray = Instance.new("ParticleEmitter")
	spray.Texture, spray.Rate, spray.Lifetime, spray.Speed = "rbxasset://textures/particles/smoke_main.dds", 40, NumberRange.new(0.8, 1.2), NumberRange.new(6, 9)
	spray.SpreadAngle, spray.Acceleration = Vector2.new(18, 18), Vector3.new(0, -14, 0)
	spray.Color, spray.Transparency, spray.Size = ColorSequence.new(rgb(200, 235, 255)), NumberSequence.new(0.3, 1), NumberSequence.new(0.6, 1.2)
	spray.EmissionDirection, spray.Parent = Enum.NormalId.Right, bowl -- the tipped cylinder's +X points up
	for _, x in { -13, 13 } do
		local face = x < 0 and 90 or -90
		local seat = CFrame.new(x, FLOOR + 1.6, 160) * CFrame.Angles(0, math.rad(face), 0)
		part(decor, "BenchSeat", Vector3.new(6, 0.5, 2), seat, rgb(150, 100, 60), Enum.Material.Wood)
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
	return "Plaza built: leaderboards, showcase, reward chest, decor"
end
