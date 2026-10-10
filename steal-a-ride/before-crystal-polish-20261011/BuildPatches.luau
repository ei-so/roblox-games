-- Edit-time tool (not used at runtime): splits each biome's single escape lane into Config.Patch.count patches
-- spread over the floor. The old EscapeLane / Lane / Props go to ServerStorage.LayoutBackup_20261007/<Biome> (once).
--   require(game.ServerStorage.BuildTools.BuildPatches)()  then  require(game.ServerStorage.BuildTools.ScatterProps)()
-- Every lane part keeps its height and is squeezed into the patch footprint; tiny decor (lily pads) just moves.
-- Tundra gets its shelf + a ramp (the old ramp/pit don't survive squeezing); Cosmic gets a 4th phase wall.
local Config = require(game.ReplicatedStorage.Shared.Config)
local P = Config.Patch

local function backup(biome)
	local root = game.ServerStorage:FindFirstChild("LayoutBackup_20261007") or Instance.new("Folder")
	root.Name = "LayoutBackup_20261007"
	root.Parent = game.ServerStorage
	local store = root:FindFirstChild(biome.Name)
	if not store then
		store = Instance.new("Folder")
		store.Name = biome.Name
		for _, name in { "EscapeLane", "Lane", "Props" } do
			local x = biome:FindFirstChild(name)
			if x then x:Clone().Parent = store end
		end
		store.Parent = root
	end
	return store
end

local function spots(biome, rng)
	local far, entrance = biome:GetAttribute("FarZ"), biome:GetAttribute("EntranceZ")
	local nest = biome.Nest:GetPivot().Position -- keep clear of the guardian's patrol circle
	local list = {}
	for _ = 1, 400 do
		if #list >= P.count then break end
		local x = rng:NextNumber(-110 + P.width, 110 - P.width)
		local z = rng:NextNumber(far + P.length, entrance - P.length)
		local ok = (Vector2.new(x, z) - Vector2.new(nest.X, nest.Z)).Magnitude > Config.Guardian.patrolClear + 25
		for _, s in list do
			ok = ok and (math.abs(s.X - x) > P.width + 12 or math.abs(s.Z - z) > P.length + 12)
		end
		if ok then table.insert(list, Vector3.new(x, 0, z)) end
	end
	return list
end

local function build(biomeId: string)
	local biome = workspace.Biomes[biomeId]
	local store = backup(biome)
	local zone = store:FindFirstChild("EscapeLane")
	if not zone then
		return biomeId .. ": no lane"
	end
	for _, name in { "EscapeLane", "Lane", "Patches" } do
		local x = biome:FindFirstChild(name)
		if x then x:Destroy() end
	end
	local center, sx, sz = zone.Position, P.width / zone.Size.X, P.length / zone.Size.Z
	local parts = { zone }
	local lane = store:FindFirstChild("Lane")
	for _, p in lane and lane:GetChildren() or {} do
		if biomeId ~= "Tundra" or p.Name == "Shelf" then table.insert(parts, p) end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Patches"
	folder.Parent = biome
	for i, at in spots(biome, Random.new(Config.BiomeById[biomeId].index * 31)) do
		local patch = Instance.new("Model")
		patch.Name = "Patch" .. i
		for _, src in parts do
			local p = src:Clone()
			local tiny = math.max(src.Size.X, src.Size.Z) < 3
			local off = src.Position - center
			p.Position = Vector3.new(at.X + off.X * sx, src.Position.Y, at.Z + off.Z * sz)
			if not tiny then
				local wallX = src.Size.X <= 1.5 -- side phase walls stay thin
				local wallZ = src.Size.Z <= 1.5 -- end walls stay thin
				p.Size = Vector3.new(wallX and src.Size.X or src.Size.X * sx, src.Size.Y, wallZ and src.Size.Z or src.Size.Z * sz)
			end
			p.Parent = patch
		end
		if biomeId == "Cosmic" then -- close the pocket on the home side too
			for _, w in patch:GetChildren() do
				if w.Name == "EnergyWall" and w.Size.Z <= 1.5 then
					local near = w:Clone()
					near.Position = Vector3.new(w.Position.X, w.Position.Y, at.Z + (at.Z - w.Position.Z))
					near.Parent = patch
				end
			end
		elseif biomeId == "Tundra" then -- ramp up to the shelf from the far side
			local shelf = patch:FindFirstChild("Shelf")
			local top = shelf.Position.Y + shelf.Size.Y / 2
			local ramp = Instance.new("WedgePart")
			ramp.Name = "Ramp"
			ramp.Anchored = true
			ramp.Material, ramp.Color = Enum.Material.Ice, shelf.Color
			ramp.Size = Vector3.new(P.width, top, 20)
			-- WedgePart's high edge is at its +Z face, so it rises toward the shelf / home
			ramp.CFrame = CFrame.new(at.X, top / 2, shelf.Position.Z - P.length / 2 - 10)
			ramp.Parent = patch
		end
		patch.Parent = folder
	end
	return ("%s: %d patches"):format(biomeId, #folder:GetChildren())
end

return function()
	local out = {}
	for _, b in Config.Biomes do
		if b.lane then table.insert(out, build(b.id)) else backup(workspace.Biomes[b.id]) end
	end
	return table.concat(out, "\n")
end
