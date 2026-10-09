-- Edit-time tool (not used at runtime): moves the three stalls to the Plaza's side edges, turned to face the centre aisle,
-- adds light festive decor in Plaza.Festive (bunting, planters, crates/barrels, stall lanterns, edge bushes) and the
-- Top Collectors board frame beside Top Income, Sam the Saddler's Upgrades stall (a recoloured copy of Gus's), and the
-- sandstone floor with terracotta fountain ring and aisle (Plaza.FloorDetail).
--   require(game.ServerStorage.BuildTools.BuildPlazaDecor)()
-- Run after BuildTopPlayers (that tool moves the Index stall back to its corner). Rerunning rebuilds Plaza.Festive and
-- re-places the stalls from their saved OriginalPivot attribute. Low-graphics friendly: no lights, particles or sounds;
-- every decor part is anchored, non-colliding, non-queryable and casts no shadow.
local rgb = Color3.fromRGB
local FLOOR = 0.4 -- top of Plaza.Floor
-- stall base centre and facing (yaw from the original -Z facing: 90 = faces -X, -90 = faces +X)
local STALLS = {
	GearShop = { x = 68, z = 163, yaw = 90 },
	UpgradeShop = { x = 68, z = 185, yaw = 90 }, -- Sam the Saddler, built from a copy of Gus's stall
	FuseMachine = { x = -68, z = 163, yaw = -90 },
	IndexBoard = { x = -68, z = 185, yaw = -90 },
}
local FLAGS = { rgb(230, 70, 70), rgb(255, 205, 80), rgb(70, 140, 230), rgb(90, 200, 110), rgb(245, 245, 245) }
local ROPE, WOOD, DARKWOOD, STONE = rgb(70, 50, 35), rgb(150, 105, 60), rgb(95, 65, 38), rgb(150, 145, 140)

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cframe, color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props or {} do p[k] = v end
	p.Parent = parent
	return p
end

-- a rope from a to b sagging `sag` studs in the middle, with diamond flags hanging along it
local function bunting(parent, a: Vector3, b: Vector3, sag: number, spacing: number)
	local mid = (a + b) / 2 - Vector3.new(0, sag, 0)
	for _, seg in { { a, mid }, { mid, b } } do
		local p0, p1 = seg[1], seg[2]
		part(parent, "Rope", Vector3.new(0.15, 0.15, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), ROPE)
	end
	local count = math.max(1, math.floor((b - a).Magnitude / spacing) - 1)
	for i = 1, count do
		local t = i / (count + 1)
		local pos = a:Lerp(b, t) - Vector3.new(0, sag * (1 - (2 * t - 1) ^ 2) + 0.6, 0) -- parabola through a, mid, b
		local along = CFrame.lookAt(pos, pos + (b - a).Unit)
		part(parent, "Flag", Vector3.new(0.1, 1, 1), along * CFrame.Angles(math.rad(45), 0, 0), -- thin across the rope, diamond
			FLAGS[(i - 1) % #FLAGS + 1])
	end
end

local function bush(parent, x: number, z: number, y: number)
	local source = workspace.Plaza.Decor:FindFirstChild("FlowerBush")
	if not source then return end
	local b = source:Clone()
	for _, d in b:GetDescendants() do
		if d:IsA("BasePart") then d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false end
	end
	local _, size = b:GetBoundingBox()
	b:PivotTo(CFrame.new(x, y + size.Y / 2, z) * (b:GetPivot() - b:GetPivot().Position))
	b.Parent = parent
end

local GREEN, DARKGREEN, GOLD = rgb(70, 175, 95), rgb(40, 95, 55), rgb(220, 170, 60)

-- Sam the Saddler: Gus's stall in green and gold, saddles on the shelf instead of soda bottles
local function buildUpgradeShop(plaza)
	local shop = plaza.GearShop:Clone() -- carries Gus's OriginalPivot, so it is placed like the other stalls below
	shop.Name = "UpgradeShop"
	for _, d in shop:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d:Destroy() -- PlazaService adds prompts at runtime
		elseif d:IsA("BasePart") and d.Parent.Name == "Stall" and (d.Name == "Soda" or d.Name == "Cap") then
			d:Destroy()
		elseif d:IsA("BasePart") and d.Color == rgb(235, 80, 80) then
			d.Color = GREEN -- awning stripes, counter, glow
		elseif d:IsA("BasePart") and d.Name == "BackWall" then
			d.Color = DARKGREEN
		elseif d:IsA("TextLabel") and d.Text == "Gear Shop" then
			d.Text = "Upgrades"
		elseif d:IsA("Humanoid") then
			d.DisplayName = "Sam the Saddler"
		elseif d:IsA("BodyColors") then
			d.TorsoColor3 = GOLD
		elseif d:IsA("BasePart") and (d.Name == "UpperTorso" or d.Name == "LowerTorso") then
			d.Color = GOLD
		elseif d:IsA("BasePart") and (d.Name == "HatTop" or d.Name == "HatBrim") then
			d.Color = rgb(110, 70, 40)
		end
	end
	local shelf = shop.Stall.Shelf
	for i = -1, 1 do -- saddles: a leather seat with a raised horn
		local at = shelf.CFrame * CFrame.new(i * 3, shelf.Size.Y / 2 + 0.35, 0)
		part(shop.Stall, "Saddle", Vector3.new(1.8, 0.5, 1.1), at, rgb(120, 70, 35), Enum.Material.Leather)
		part(shop.Stall, "SaddleHorn", Vector3.new(0.3, 0.6, 0.3), at * CFrame.new(-0.7, 0.5, 0), GOLD, Enum.Material.Metal)
	end
	shop.Parent = plaza
end

return function()
	local plaza = workspace.Plaza
	if not plaza:FindFirstChild("UpgradeShop") then
		buildUpgradeShop(plaza)
	end
	-- stalls: whole model (counter, keeper, prompt parts) moves and turns together
	for name, s in STALLS do
		local stall = plaza[name]
		if stall:GetAttribute("OriginalPivot") == nil then
			stall:SetAttribute("OriginalPivot", stall:GetPivot())
		end
		local original = stall:GetAttribute("OriginalPivot")
		local baseLocal = stall:GetPivot():ToObjectSpace(stall.Base.CFrame) -- the same wherever the stall stands
		local base = CFrame.new(s.x, stall.Base.Position.Y, s.z) * CFrame.Angles(0, math.rad(s.yaw), 0) * original.Rotation * baseLocal.Rotation
		stall:PivotTo(base * baseLocal:Inverse())
	end

	-- Top Collectors board: a copy of the Top Income board frame at x -60 (mirrors Top Bases at +60); PlazaService fills it.
	-- The back-left pine steps 3 studs out and back so it doesn't touch the board.
	local boards = plaza.Leaderboards
	if not boards:FindFirstChild("TopCollectors") then
		local board = boards.TopIncome:Clone()
		board.Name = "TopCollectors"
		for _, d in board:GetDescendants() do
			if d:IsA("SurfaceGui") then d:Destroy() end -- the runtime board GUI, if one was saved
		end
		board:PivotTo(boards.TopIncome:GetPivot() + Vector3.new(-30, 0, 0))
		board.Parent = boards
	end
	for _, tree in plaza.Decor:GetChildren() do
		if tree.Name == "Pine" and tree:GetPivot().Position.X < -60 and tree:GetPivot().Position.Z > 180 then
			if tree:GetAttribute("OriginalPivot") == nil then
				tree:SetAttribute("OriginalPivot", tree:GetPivot())
			end
			tree:PivotTo(tree:GetAttribute("OriginalPivot") + Vector3.new(-3, 0, -3))
		end
	end

	-- floor: warm sandstone paving (old colour kept in attr PrevColor), terracotta ring round the fountain and a
	-- terracotta aisle arch -> fountain -> Top Players board in the home road's colours, darker pads under the stalls.
	-- Colour-led so it still reads when low graphics drop textures.
	local floor = plaza.Floor
	if floor:GetAttribute("PrevColor") == nil then
		floor:SetAttribute("PrevColor", floor.Color)
	end
	floor.Color = rgb(214, 190, 150)
	local oldFloor = plaza:FindFirstChild("FloorDetail")
	if oldFloor then oldFloor:Destroy() end
	local fd = Instance.new("Folder")
	fd.Name = "FloorDetail"
	local TOP = floor.Position.Y + floor.Size.Y / 2
	local BRICK, EDGE = rgb(198, 96, 64), rgb(122, 74, 52)
	part(fd, "FountainRing", Vector3.new(0.06, 34, 34), CFrame.new(0, TOP + 0.03, 160) * CFrame.Angles(0, 0, math.rad(90)), BRICK,
		Enum.Material.Brick, { Shape = Enum.PartType.Cylinder })
	part(fd, "FountainRingEdge", Vector3.new(0.05, 36, 36), CFrame.new(0, TOP + 0.025, 160) * CFrame.Angles(0, 0, math.rad(90)), EDGE,
		Enum.Material.Slate, { Shape = Enum.PartType.Cylinder })
	for _, seg in { { 135, 143 }, { 177, 208 } } do -- arch -> ring, ring -> board
		local z0, z1 = seg[1], seg[2]
		local len, mid = z1 - z0, (z0 + z1) / 2
		part(fd, "Aisle", Vector3.new(12, 0.04, len), CFrame.new(0, TOP + 0.02, mid), BRICK, Enum.Material.Brick)
		for _, side in { -1, 1 } do
			part(fd, "AisleEdge", Vector3.new(1.5, 0.05, len), CFrame.new(side * 6.75, TOP + 0.025, mid), EDGE, Enum.Material.Slate)
		end
	end
	for name in STALLS do
		local b = plaza[name].Base.Position
		part(fd, "StallPad", Vector3.new(18, 0.02, 18), CFrame.new(b.X, TOP + 0.01, b.Z), rgb(184, 158, 118), Enum.Material.Pavement)
	end
	fd.Parent = plaza

	local old = plaza:FindFirstChild("Festive")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "Festive"

	-- bunting between the lamp posts (tops y 9.4) and under the arch title (pillars at x +-23, inner faces +-21.5)
	bunting(f, Vector3.new(-14, 9, 146), Vector3.new(14, 9, 146), 1.2, 2.6)
	bunting(f, Vector3.new(-14, 9, 200), Vector3.new(14, 9, 200), 1.2, 2.6)
	bunting(f, Vector3.new(-21.5, 15.5, 136), Vector3.new(21.5, 15.5, 136), 1.6, 3)

	-- planters where the stalls used to stand
	for _, x in { -48, 48 } do
		part(f, "Planter", Vector3.new(7, 1.6, 7), CFrame.new(x, FLOOR + 0.8, 172), STONE, Enum.Material.Slate)
		part(f, "Soil", Vector3.new(6, 0.2, 6), CFrame.new(x, FLOOR + 1.65, 172), rgb(85, 60, 40), Enum.Material.Ground)
		bush(f, x, 172, FLOOR + 1.6)
	end

	-- per stall: crates + barrel beside the counter, two lanterns hanging from the front posts
	for name, s in STALLS do
		local base = CFrame.new(s.x, FLOOR, s.z) * CFrame.Angles(0, math.rad(s.yaw), 0) -- local -Z = the stall's front
		local function at(x, y, z) return base * CFrame.new(x, y, z) end
		part(f, "Crate", Vector3.new(2.6, 2.6, 2.6), at(8.6, 1.3, -3.5) * CFrame.Angles(0, math.rad(12), 0), WOOD, Enum.Material.WoodPlanks)
		part(f, "Crate", Vector3.new(1.8, 1.8, 1.8), at(8.5, 3.5, -3.6) * CFrame.Angles(0, math.rad(-20), 0), WOOD, Enum.Material.WoodPlanks)
		part(f, "Barrel", Vector3.new(3, 2.2, 2.2), at(8.4, 1.5, -0.4) * CFrame.Angles(0, 0, math.rad(90)), DARKWOOD, Enum.Material.Wood,
			{ Shape = Enum.PartType.Cylinder })
		for _, side in { -1, 1 } do
			part(f, "LanternCap", Vector3.new(0.9, 0.3, 0.9), at(side * 5.2, 9.5, -5.2), rgb(40, 35, 30))
			part(f, "Lantern", Vector3.new(1.2, 1.2, 1.2), at(side * 5.2, 8.7, -5.2),
				name == "GearShop" and rgb(255, 120, 90) or name == "FuseMachine" and rgb(200, 130, 255)
					or name == "UpgradeShop" and rgb(255, 215, 90) or rgb(120, 180, 255),
				Enum.Material.Neon, { Shape = Enum.PartType.Ball })
		end
	end

	-- bushes along the side edges, between the stalls and the corner trees
	bush(f, 76, 192, FLOOR)
	bush(f, 76, 152, FLOOR)
	bush(f, -76, 200, FLOOR)

	f.Parent = plaza
	local n = 0
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
	end
	return ("Stalls moved to the edges; Plaza.Festive built (%d parts)"):format(n)
end
