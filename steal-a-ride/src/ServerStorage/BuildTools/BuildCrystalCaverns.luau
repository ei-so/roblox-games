-- Edit-time only. Adds Crystal Caverns (biome 9) after Mystic Grove without moving any existing biome.
-- Placement comes from CrystalCavernsLayout (generated from assets/crystal-caverns/layout.json, the same layout the
-- Blender preview used); meshes come from ServerStorage.CrystalCavernsAssets20261010.
-- Gameplay geometry: the floor, 4 invisible wall colliders (tag ClimbWall) with a ClimbTop zone each, the road
-- boundary. Everything else is decoration: CanCollide / CanQuery / CanTouch off, in the Scenery folder, so it never
-- blocks the Golem (GuardianService raycasts Props + Patches only), riders, or the Climb raycast.
local CS = game:GetService("CollectionService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.CrystalCavernsLayout)
local rgb, V3 = Color3.fromRGB, Vector3.new
local NEON = { cyan = rgb(120, 240, 255), amber = rgb(255, 176, 70), violet = rgb(175, 120, 255), blue = rgb(90, 150, 255) }
local SHADOWLESS = { Handhold = true, WallCrest = true, GlowCluster = true, GlowClusterBig = true, ShardDebris = true,
	WallGrowth = true, FloorMound = true, Stalactites = true }

return function()
	assert(game.PlaceId == 123937616497204, "Wrong game")
	assert(not workspace.Biomes:FindFirstChild("CrystalCaverns"), "Crystal Caverns exists; do not overwrite it")
	local C = Config.BiomeById.CrystalCaverns
	assert(C and C.shortcuts, "Install the Crystal Caverns Config first")
	local assets = game.ServerStorage:FindFirstChild("CrystalCavernsAssets20261010")
	assert(assets, "Crystal Caverns assets missing")
	local previous = workspace.Biomes.MysticGrove
	local entrance = previous:GetAttribute("FarZ") - 20 -- same 20-stud transition as every biome before it
	local far = entrance - C.depth
	local nestZ = entrance - C.depth * Config.Nests.depth
	assert(math.abs(Layout.NestY - C.depth * Config.Nests.depth) < .01 and Layout.D == C.depth, "Layout is stale: rerun layout.py")
	local function world(x, y, z) return V3(x, z, entrance - y) end

	local biome = Instance.new("Model") biome.Name = "CrystalCaverns"
	biome:SetAttribute("Index", 9) biome:SetAttribute("EntranceZ", entrance) biome:SetAttribute("FarZ", far)
	biome:SetAttribute("NestZ", nestZ) biome:SetAttribute("CrystalBuildVersion", 1)
	local props = Instance.new("Folder") props.Name = "Props" props.Parent = biome -- solid: GuardianService blockers
	local scenery = Instance.new("Folder") scenery.Name = "Scenery" scenery.Parent = biome
	local tops = Instance.new("Folder") tops.Name = "ClimbTops" tops.Parent = biome
	local function part(parent, name, size, cf, color, material, solid)
		local p = Instance.new("Part") p.Name = name p.Size = size p.CFrame = typeof(cf) == "CFrame" and cf or CFrame.new(cf)
		p.Color = color p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true p.CanCollide = solid == true p.CanQuery = solid == true p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth p.Parent = parent
		return p
	end

	-- floor (same height as the road) + dark shell behind the formations, ceiling slabs with the crack openings
	part(biome, "Floor", V3(220, .4, C.depth + 20), V3(0, .1, (entrance + far) / 2 + 10), C.look.floor, C.look.material, true)
	local shell = rgb(34, 38, 52)
	for _, side in { -1, 1 } do
		part(scenery, "ShellWall", V3(10, Layout.H + 20, C.depth + 80), world(side * (Layout.W / 2 + 40), Layout.D / 2, Layout.H / 2), shell, Enum.Material.Slate)
	end
	part(scenery, "ShellWall", V3(Layout.W + 80, Layout.H + 20, 10), world(0, Layout.D + 40, Layout.H / 2), shell, Enum.Material.Slate)
	local cracks = table.clone(Layout.cracks)
	table.sort(cracks)
	table.insert(cracks, Layout.D + 40)
	local y0 = -40
	for i, c in cracks do
		local half = i < #cracks and 13 or 0
		if c - half > y0 then
			part(scenery, "Ceiling", V3(Layout.W + 80, 8, c - half - y0), world(0, (y0 + c - half) / 2, Layout.H + 18), shell, Enum.Material.Slate)
		end
		y0 = c + half
	end

	-- the climb walls: one invisible collider per row (exact 10-stud slab, clean faces for the Climb raycast)
	for row, w in Layout.walls do
		local span, cx = w.x1 - w.x0, (w.x0 + w.x1) / 2
		local wall = part(props, "QuartzWall" .. row, V3(span, 40, 10), world(cx, w.y, 20), rgb(180, 210, 245), nil, true)
		wall.Transparency = 1
		CS:AddTag(wall, "ClimbWall")
		local top = part(tops, "ClimbTop" .. row, V3(span, 1, 10), world(cx, w.y, 40.5), C.look.accent, nil, false)
		top.Transparency = 1
		top:SetAttribute("Headroom", 8) top:SetAttribute("GroundY", .3)
		CS:AddTag(top, "ClimbTop")
		assert(Layout.Gap >= 2 * Config.Guardian.pathRadius + 8, "wall gap too narrow for the Golem")
	end

	-- every authored piece from the layout
	local count = { mesh = 0, light = 0 }
	for _, l in Layout.lights do
		local x, y, z, c, range, brightness = table.unpack(l)
		local p = part(scenery, "CrystalLight", V3(1, 1, 1), world(x, y, z), NEON[c], nil, false)
		p.Transparency = 1
		local light = Instance.new("PointLight") light.Color = NEON[c] light.Range = range light.Brightness = brightness
		light.Shadows = false light.Parent = p
		count.light += 1
	end
	for _, sh in Layout.shafts do
		local x, y, z, height, width = table.unpack(sh)
		local p = part(scenery, "LightShaft", V3(height, width * .6, width * .6),
			CFrame.new(world(x, y, z)) * CFrame.Angles(0, 0, math.rad(90)), rgb(215, 232, 255), Enum.Material.Neon, false)
		p.Shape = Enum.PartType.Cylinder p.Transparency = .92 p.CastShadow = false
	end
	for _, it in Layout.items do
		local name, glow, x, y, z, rot, s, sx = table.unpack(it)
		local template = assets:FindFirstChild(name)
		assert(template and Layout.O[name], "missing asset " .. name)
		local m = template:Clone()
		local scale = V3((sx or 1) * s, s, s)
		m.Size = template.Size * scale
		local o = Layout.O[name]
		m.CFrame = CFrame.new(world(x, y, z)) * CFrame.Angles(0, math.rad(rot + 180), 0) * CFrame.new(V3(o[1], o[2], o[3]) * scale)
		m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch = true, false, false, false
		m.CastShadow = not SHADOWLESS[name]
		if glow then
			m.Material = Enum.Material.Neon m.Color = NEON[glow] m.TextureID = ""
		end
		m.Parent = scenery
		count.mesh += 1
		if count.mesh % 100 == 0 then task.wait() end
	end

	-- entrance sign, exit line, nest, guardian spot (same pieces as every biome)
	local arch = previous.Arch:Clone() arch.Name = "Arch"
	arch:PivotTo(CFrame.new(0, 12.75, entrance)) arch.Parent = biome
	for _, p in arch:GetDescendants() do
		if p:IsA("BasePart") then p.Color = p.Material == Enum.Material.Neon and C.look.accent or rgb(60, 68, 92)
		elseif p:IsA("TextLabel") then
			p.Text = p.Name == "Line2" and ("%s speed: %d"):format(C.guardian, math.round(C.guardianSpeed)) or "CRYSTAL CAVERNS"
		end
	end
	local line = previous.ExitLine:Clone() line.CFrame = CFrame.new(0, 6, entrance) line.Parent = biome
	local nest = previous.Nest:Clone() nest.Name = "Nest"
	nest:PivotTo(CFrame.new(0, .8, nestZ) * previous.Nest:GetPivot().Rotation) nest.Parent = biome
	for _, p in nest:GetDescendants() do if p:IsA("BasePart") and p.Transparency < 1 then p.Color = rgb(70, 80, 110) end end
	local spot = part(biome, "GuardianSpot", V3(1, 1, 1), V3(32, .3, nestZ), C.look.accent, nil, false) spot.Transparency = 1

	-- crystal chimes: three soft spot sounds (nest crown + two side seams)
	for i, at in { world(0, Layout.NestY + 50, 10), world(-90, 200, 12), world(90, 560, 12) } do
		local p = part(scenery, "ChimeSpot" .. i, V3(1, 1, 1), at, C.look.accent, nil, false) p.Transparency = 1
		local s = Instance.new("Sound") s.SoundId = "rbxassetid://9120749909" s.Looped = true s.Volume = .35
		s.RollOffMaxDistance = 90 s.RollOffMinDistance = 12 s.Playing = true s.Parent = p
	end

	biome.Parent = workspace.Biomes

	-- the shared road and Mystic's end bank used to close the world at Mystic's far end: move both to the cave's end
	local road = workspace.BiomeRoad
	if not road:FindFirstChild("CrystalRoadExtension") then
		local oldEnd
		for _, p in road:GetChildren() do
			if p:IsA("BasePart") and p.Name == "Boundary" and p.Size.X > 200 and p.Position.Z < 0 then
				assert(not oldEnd, "Ambiguous road end") oldEnd = p
			end
		end
		assert(oldEnd and math.abs(oldEnd.Position.Z - (previous:GetAttribute("FarZ") - 15.5)) < 1, "Unexpected road end")
		oldEnd:SetAttribute("CrystalOriginalCFrame", oldEnd.CFrame)
		local newEnd = far - 15.5
		local from = oldEnd.Position.Z + .5
		oldEnd.CFrame = CFrame.new(0, 30, newEnd)
		local folder = Instance.new("Folder") folder.Name = "CrystalRoadExtension" folder.Parent = road
		local length, center = from - (newEnd + .5), (from + newEnd + .5) / 2
		local ground = part(folder, "Ground", V3(220, 2, length), V3(0, -1, center), C.look.floor, C.look.material, true)
		ground.CanTouch = true
		for _, x in { -110.5, 110.5 } do
			local b = part(folder, "Boundary", V3(1, 60, length), V3(x, 30, center), C.look.floor, C.look.material, true)
			b.Transparency = 1
		end
	end
	local bank = previous:FindFirstChild("Border") and previous.Border:FindFirstChild("EndBank")
	if bank and not bank:GetAttribute("CrystalOriginalCFrame") then
		bank:SetAttribute("CrystalOriginalCFrame", bank.CFrame)
		bank.CFrame = CFrame.new(0, 10, far - 5)
	end

	local sfx = game.SoundService.SFX
	if not sfx:FindFirstChild("AmbienceCrystalCaverns") then
		local sound = sfx.AmbienceForest:Clone() sound.Name = "AmbienceCrystalCaverns"
		sound.SoundId = "rbxassetid://" .. Config.Sounds.AmbienceCrystalCaverns sound.PlaybackSpeed = 1 sound.Volume = .3
		sound.Parent = sfx
	end
	return ("Crystal Caverns built: %d to %d, nest %d; %d meshes, %d lights; previous biomes preserved")
		:format(entrance, far, nestZ, count.mesh, count.light)
end
