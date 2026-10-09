-- Edit-time tool (not used at runtime): the base expansion lot behind every Home Row plot
-- (docs/superpowers/specs/2026-10-10-base-expansion-design.md).
--   require(game.ServerStorage.BuildTools.BuildBaseExpansion)()
-- Per plot: Plot.Expansion (lot floor, outer walls with fence + invisible walls like the base enclosure, a wooden
-- construction fence, the For Sale sign on the inside of the back wall), pen pedestals Pen21..30 (Plot.Pen) and pads
-- Incubator7..8 (Plot.Incubators), and a 20-stud gap in the back wall: the back Wall and its enclosure Fence/Invisible
-- slabs are split, the centre pieces are named BackGap / GapFence / GapInvisible (not Wall/Fence, so BaseService's paint
-- never re-shows them). Built in the locked state; ExpansionService toggles it per owner at runtime.
-- Rerunnable: removes what it built (attr ExpansionPart) and restores the split parts from their saved size/position.
local rgb = Color3.fromRGB
local GAP = 20
local LOT_DEPTH = 28 -- strip behind the back wall (x +-81..+-109)
local FENCE_TOP, WALL_TOP = 12, 150 -- same as BuildBases' enclosure

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cframe, color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props or {} do p[k] = v end
	p:SetAttribute("ExpansionPart", true)
	p.Parent = parent
	return p
end

-- undo a previous run: built parts go, split parts get their saved size/position back
local function clean(plot)
	for _, d in plot:GetDescendants() do
		if d:GetAttribute("ExpansionPart") then
			d:Destroy()
		elseif d:IsA("BasePart") and d:GetAttribute("SplitSize") then
			d.Size, d.Position = d:GetAttribute("SplitSize"), d:GetAttribute("SplitPos")
		end
	end
	local old = plot:FindFirstChild("Expansion")
	if old then old:Destroy() end
end

-- shrink a back-wall-line part (wall or enclosure slab, long side along Z) to its south piece; add the north piece
-- (same name) and the centre gap piece (gapName). Returns the gap piece.
local function split(p, gapName, parent)
	p:SetAttribute("SplitSize", p.Size)
	p:SetAttribute("SplitPos", p.Position)
	local len, z0 = p.Size.Z, p.Position.Z
	local side = (len - GAP) / 2
	local north = p:Clone()
	for _, c in north:GetChildren() do c:Destroy() end
	north:SetAttribute("SplitSize", nil)
	north:SetAttribute("SplitPos", nil)
	north:SetAttribute("ExpansionPart", true)
	p.Size = Vector3.new(p.Size.X, p.Size.Y, side)
	p.Position = Vector3.new(p.Position.X, p.Position.Y, z0 - GAP / 2 - side / 2)
	north.Size = p.Size
	north.Position = Vector3.new(p.Position.X, p.Position.Y, z0 + GAP / 2 + side / 2)
	north.Parent = p.Parent
	local gap = p:Clone()
	for _, c in gap:GetChildren() do c:Destroy() end
	gap.Name = gapName
	gap:SetAttribute("SplitSize", nil)
	gap:SetAttribute("SplitPos", nil)
	gap:SetAttribute("ExpansionPart", true)
	gap.Size = Vector3.new(p.Size.X, p.Size.Y, GAP)
	gap.Position = Vector3.new(p.Position.X, p.Position.Y, z0)
	gap.Parent = parent or p.Parent
	return gap
end

local function build(plot)
	clean(plot)
	local floor = plot.Floor
	local s = plot:GetAttribute("Side") -- -1: left row, the lot is toward -X
	local fx, fz, top = floor.Position.X, floor.Position.Z, floor.Position.Y + floor.Size.Y / 2
	local backX = fx + s * (floor.Size.X / 2 + 0.5) -- the back Wall line (x -79.5 on Plot1)
	local inward = CFrame.lookAt(Vector3.zero, Vector3.new(-s, 0, 0)) -- facing back into the base

	local lot = Instance.new("Model")
	lot.Name = "Expansion"
	local wall
	for _, p in plot:GetChildren() do
		if p.Name == "Wall" and math.abs(p.Position.X - backX) < 1 then wall = p end
	end
	local wallTop = wall.Position.Y + wall.Size.Y / 2
	local lotX = backX + s * (0.5 + LOT_DEPTH / 2)
	part(lot, "Floor", Vector3.new(LOT_DEPTH, floor.Size.Y, floor.Size.Z), CFrame.new(lotX, floor.Position.Y, fz), floor.Color, floor.Material)

	-- outer walls: far end + two sides, with the enclosure's fence and invisible wall on each
	local outerX = backX + s * (LOT_DEPTH + 1)
	local walls = {
		{ Vector3.new(1, wall.Size.Y, floor.Size.Z + 2), Vector3.new(outerX, wall.Position.Y, fz) },
		{ Vector3.new(LOT_DEPTH + 1, wall.Size.Y, 1), Vector3.new(lotX + s * 0.5, wall.Position.Y, fz - floor.Size.Z / 2 - 0.5) },
		{ Vector3.new(LOT_DEPTH + 1, wall.Size.Y, 1), Vector3.new(lotX + s * 0.5, wall.Position.Y, fz + floor.Size.Z / 2 + 0.5) },
	}
	for _, w in walls do
		part(lot, "LotWall", w[1], CFrame.new(w[2]), wall.Color, wall.Material)
		part(lot, "LotFence", Vector3.new(w[1].X, FENCE_TOP - wallTop, w[1].Z), CFrame.new(w[2].X, (wallTop + FENCE_TOP) / 2, w[2].Z),
			rgb(200, 230, 255), Enum.Material.ForceField, { Transparency = 0.3, CanQuery = false, CanTouch = false, CastShadow = false })
		part(lot, "LotInvisible", Vector3.new(w[1].X, WALL_TOP - FENCE_TOP, w[1].Z), CFrame.new(w[2].X, (FENCE_TOP + WALL_TOP) / 2, w[2].Z),
			rgb(200, 230, 255), Enum.Material.ForceField, { Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false })
	end

	-- the 20-stud opening: wall + enclosure slabs on the back line are split; their centre pieces close it until bought
	split(wall, "BackGap", lot)
	for _, slab in plot.Enclosure:GetChildren() do
		if (slab.Name == "Fence" or slab.Name == "Invisible") and math.abs(slab.Position.X - backX) < 1 and slab.Size.Z > GAP then
			split(slab, slab.Name == "Fence" and "GapFence" or "GapInvisible", lot)
		end
	end

	-- wooden construction fence just behind the opening (seen over the wall while the lot is for sale)
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	local fenceX = backX + s * 2
	for i = -2, 2 do
		part(fence, "Post", Vector3.new(0.5, 3.4, 0.5), CFrame.new(fenceX, top + 1.7, fz + i * (GAP / 4)), rgb(120, 78, 44), Enum.Material.Wood,
			{ CanCollide = false, CastShadow = false })
	end
	for _, y in { 1.2, 2.6 } do
		part(fence, "Rail", Vector3.new(0.3, 0.4, GAP + 0.5), CFrame.new(fenceX, top + y, fz), rgb(150, 105, 60), Enum.Material.WoodPlanks,
			{ CanCollide = false, CastShadow = false })
	end
	fence.Parent = lot

	-- For Sale sign on the base side of the back wall, readable from inside the base
	local signCF = CFrame.new(backX - s * 0.8, wallTop + 2.2, fz) * inward
	local sign = part(lot, "Sign", Vector3.new(12, 3.2, 0.4), signCF, rgb(70, 45, 26), Enum.Material.Wood, { CastShadow = false })
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = "Board", Enum.NormalId.Front,
		Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name, label.Size, label.BackgroundTransparency = "Line1", UDim2.fromScale(1, 1), 1
	label.Font, label.TextScaled, label.RichText, label.TextColor3 = Enum.Font.FredokaOne, true, true, rgb(255, 210, 80)
	label.Text = "Unlocks at Rebirth 10"
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = rgb(40, 22, 8), 2
	stroke.Parent = label
	label.Parent = gui
	for _, dz in { -5, 5 } do
		part(lot, "SignPost", Vector3.new(0.4, wallTop + 3.8 - top, 0.4), CFrame.new(backX - s * 0.8, (top + wallTop + 3.8) / 2, fz + dz),
			rgb(70, 45, 26), Enum.Material.Wood, { CanCollide = false, CastShadow = false })
	end

	-- pen pedestals 21-30 (2 columns x 5 rows, same spacing as the main pen) and incubator pads 7-8
	local pedestal = plot.Pen:FindFirstChildWhichIsA("BasePart")
	local slot = 21
	for _, col in { 7, 15 } do
		for _, dz in { -20, -10, 0, 10, 20 } do
			local p = pedestal:Clone()
			p.Name = "Pen" .. slot
			p:SetAttribute("Slot", slot)
			p:SetAttribute("ExpansionPart", true)
			p.Position = Vector3.new(backX + s * col, pedestal.Position.Y, fz + dz)
			p.Parent = plot.Pen
			slot += 1
		end
	end
	local pad = plot.Incubators:FindFirstChildWhichIsA("BasePart")
	for i, dz in { -9, 9 } do
		local p = pad:Clone()
		p.Name = "Incubator" .. (6 + i)
		p:SetAttribute("Slot", 6 + i)
		p:SetAttribute("ExpansionPart", true)
		local delta = Vector3.new(backX + s * 23, pad.Position.Y, fz + dz) - pad.Position
		for _, d in { p, unpack(p:GetDescendants()) } do -- the Ring is a child part: move it too
			if d:IsA("BasePart") then d.Position += delta end
		end
		p.Parent = plot.Incubators
	end
	lot.Parent = plot
end

return function()
	local n = 0
	for _, plot in workspace.HomeRow.Plots:GetChildren() do
		build(plot)
		n += 1
	end
	return ("Base expansion lots built on %d plots"):format(n)
end
