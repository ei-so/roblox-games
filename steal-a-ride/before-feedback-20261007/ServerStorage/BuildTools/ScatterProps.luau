-- Edit-time tool (not used at runtime): scatters the generated prop meshes in ServerStorage.PropMeshes/<Biome>
-- over the whole floor of each biome (obstacle field), keeping the escape patches, nest, guardian spot and exit lines clear.
-- Run BuildPatches first so the patches exist.
-- The old primitive props move to ServerStorage.PrimitiveProps/<Biome> as the fallback.
--   require(game.ServerStorage.BuildTools.ScatterProps)("Forest")  -- or no argument for every biome
local Config = require(game.ReplicatedStorage.Shared.Config)

local BIG = 9 -- props taller than this are "big": they collide (small ones are walk-through)
local FLOAT = { Asteroid = true, Planet = true } -- Cosmic floaters hover
local WEIGHT = { Rowboat = 0.15, Skull = 0.4, Snowman = 0.3, Planet = 0.5, LilyPad = 0.6 } -- novelty props stay rare (default 1)

local function pick(list, rng)
	local total = 0
	for _, t in list do
		total += WEIGHT[t.Name] or 1
	end
	local r = rng:NextNumber() * total
	for _, t in list do
		r -= WEIGHT[t.Name] or 1
		if r <= 0 then
			return t
		end
	end
	return list[#list]
end

local function place(template: Model, cf: CFrame, scale: number, parent: Instance, collide: boolean)
	local m = template:Clone()
	m:ScaleTo(scale)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = collide
			p.CanTouch = false
			p.CanQuery = collide
		end
	end
	m:PivotTo(CFrame.new())
	local box, size = m:GetBoundingBox()
	m:PivotTo(cf * CFrame.new(-box.Position.X, size.Y / 2 - box.Position.Y, -box.Position.Z))
	m.Parent = parent
	return m
end

local function scatter(biomeId: string)
	local biome = workspace.Biomes[biomeId]
	local templates = game.ServerStorage.PropMeshes:FindFirstChild(biomeId)
	if not templates or #templates:GetChildren() == 0 then
		return biomeId .. ": no meshes yet"
	end
	local big, small = {}, {}
	for _, t in templates:GetChildren() do
		local _, size = t:GetBoundingBox()
		table.insert(size.Y > BIG and not FLOAT[t.Name] and big or small, t)
	end
	if #big == 0 then big = small end
	if #small == 0 then small = big end

	-- primitive props -> fallback storage (once)
	local store = game.ServerStorage:FindFirstChild("PrimitiveProps") or Instance.new("Folder")
	store.Name = "PrimitiveProps"
	store.Parent = game.ServerStorage
	local old = biome:FindFirstChild("Props")
	if old and not store:FindFirstChild(biomeId) then
		old.Name = biomeId
		old.Parent = store
	elseif old then
		old:Destroy() -- an earlier mesh scatter
	end
	local folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = biome

	local rng = Random.new(Config.BiomeById[biomeId].index * 7919)
	local z0, z1 = biome:GetAttribute("FarZ") + 6, biome:GetAttribute("EntranceZ") - 10
	local placed = {}
	local nest = biome.Nest:GetPivot().Position -- the nest and the guardian's whole patrol circle stay clear
	table.insert(placed, { x = nest.X, z = nest.Z, r = Config.Guardian.patrolClear })
	for _, patch in biome:FindFirstChild("Patches") and biome.Patches:GetChildren() or {} do
		local box, size = patch:GetBoundingBox()
		for dz = -size.Z / 2, size.Z / 2, 8 do -- a row of circles covers the long patch
			table.insert(placed, { x = box.Position.X, z = box.Position.Z + dz, r = size.X / 2 + 3 })
		end
	end
	local function free(x, z, r)
		for _, p in placed do
			if (p.x - x) ^ 2 + (p.z - z) ^ 2 < (p.r + r) ^ 2 then
				return false
			end
		end
		return true
	end
	local function drop(list, xMin, xMax, count, collide, radius, sMin, sMax)
		for _ = 1, count * 4 do
			if count <= 0 then break end
			local x, z = rng:NextNumber(xMin, xMax), rng:NextNumber(z0, z1)
			if free(x, z, radius) then
				local t = pick(list, rng)
				local y = biome.Floor.Position.Y + biome.Floor.Size.Y / 2
				if FLOAT[t.Name] then y += rng:NextNumber(10, 26) end
				place(t, CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(sMin, sMax), folder, collide and not FLOAT[t.Name])
				table.insert(placed, { x = x, z = z, r = radius })
				count -= 1
			end
		end
	end
	local depth = z1 - z0
	-- spread over the whole floor. Solid props are kept sparse and smallish: guardians go straight through them
	-- while a rider has to steer, so a dense field makes chases unwinnable
	drop(big, -104, 104, math.floor(depth / 9), true, 7, 0.9, 1.3)
	drop(small, -104, 104, math.floor(depth / 5) + math.floor(depth / 12), false, 4, 1, 1.8)
	return ("%s: %d props from %d types"):format(biomeId, #folder:GetChildren(), #templates:GetChildren())
end

return function(biomeId: string?)
	if biomeId then
		return scatter(biomeId)
	end
	local out = {}
	for _, b in Config.Biomes do
		table.insert(out, scatter(b.id))
	end
	return table.concat(out, "\n")
end
