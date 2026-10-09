-- Native CSG keeps the original textures, but its geometry is ephemeral.
-- Rebuild once per server from persistent mesh assets; no EditableMesh APIs.
local Geometry = game:GetService("GeometryService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Rig = {}

local legCuts = { Chick = .23, Duckling = .22, Penguin = .2, Monkey = .32, Scarab = .2, Frog = .25,
	Bunny = .29, Mammoth = .29, Parrot = .23, SnowOwl = .2, Vulture = .24 }
local flying = { Parrot = true, SnowOwl = true, Vulture = true, EmberBat = true, BabyDragon = true }
local wingCuts = { Parrot = .23, SnowOwl = .27, Vulture = .25, EmberBat = .2, BabyDragon = .25 }

local function cutter(body, low, high)
	local p = Instance.new("Part")
	p.Size = high - low
	p.CFrame = body.CFrame * CFrame.new((low + high) / 2)
	return p
end

local function finishPart(p, original, model, name)
	p.Name = name
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Color, p.Material, p.Transparency = original.Color, original.Material, original.Transparency
	p.TextureID = original.TextureID
	if not p:FindFirstChildOfClass("SurfaceAppearance") then
		local surface = original:FindFirstChildOfClass("SurfaceAppearance")
		if surface then surface:Clone().Parent = p end
	end
	p.Parent = model
	return p
end

function Rig.build(name, spec, original)
	if original:GetAttribute("Articulated") or original:GetAttribute("Rigged") then return original:Clone() end
	local model = original:Clone()
	local source = model.PrimaryPart
	local half = source.Size / 2
	local low, high = -half, half
	local legCount = spec.legs or 4
	local tentacles = name == "StarJelly"
	local cutY = low.Y + source.Size.Y * (tentacles and .38 or legCuts[name] or .28)
	local cuts, limbs = {}, {}
	-- Limbs reach this far up into the body, so a swinging limb hides its top instead of opening a seam.
	local overlap = source.Size.Y * .12
	local function limb(label, a, b, hinge, side, front, kind, tall)
		local box = cutter(source, a, b)
		local grab = tall and cutter(source, a, b + Vector3.new(0, overlap, 0)) or box
		local pieces = Geometry:IntersectAsync(source, { grab }, { SplitApart = false })
		if grab ~= box then grab:Destroy() end
		if #pieces == 0 then box:Destroy(); return end
		assert(#pieces == 1, name .. " " .. label .. ": unexpected split")
		local p = finishPart(pieces[1], source, model, label)
		table.insert(cuts, box)
		table.insert(limbs, { part = p, hinge = source.CFrame * CFrame.new(hinge), side = side, front = front, kind = kind })
	end
	-- ponytail: box cuts give rigid cartoon limbs; use weighted bones for smooth knees later.
	if legCount > 0 or tentacles then
		for _, side in { -1, 1 } do
			for _, front in (legCount == 2 and { 0 } or { -1, 1 }) do
				local x0, x1 = side < 0 and low.X - .02 or 0, side < 0 and 0 or high.X + .02
				local z0, z1 = front <= 0 and low.Z - .02 or 0, front >= 0 and high.Z + .02 or 0
				local label = (side < 0 and "Left" or "Right") .. (front == 0 and "Leg" or front < 0 and "FrontLeg" or "HindLeg")
				limb(label, Vector3.new(x0, low.Y - .02, z0), Vector3.new(x1, cutY, z1),
					Vector3.new(side * half.X * .45, cutY, front * half.Z * .35), side, front, tentacles and "Tentacle" or "Leg", true)
			end
		end
	end
	if flying[name] or name == "Guardian_Lake" or name == "Guardian_Cosmic" then
		local fraction = wingCuts[name] or .28
		for _, side in { -1, 1 } do
			local x0, x1 = side < 0 and low.X - .02 or source.Size.X * fraction, side < 0 and -source.Size.X * fraction or high.X + .02
			local wingLow = math.max(cutY, low.Y + source.Size.Y * .25)
			limb(side < 0 and "LeftWing" or "RightWing", Vector3.new(x0, wingLow, low.Z - .02), Vector3.new(x1, high.Y + .02, high.Z + .02),
				Vector3.new(side * source.Size.X * fraction, wingLow + source.Size.Y * .2, 0), side, 0, "Wing")
		end
	end
	assert(#limbs > 0, name .. ": no limbs were extracted")
	local torso = Geometry:SubtractAsync(source, cuts, { SplitApart = false })
	assert(#torso == 1, name .. ": missing torso")
	local body = finishPart(torso[1], source, model, "Body")
	for _, item in limbs do
		local motor = Instance.new("Motor6D")
		motor.Name = item.part.Name .. "Joint"
		motor.Part0, motor.Part1 = body, item.part
		motor.C0, motor.C1 = body.CFrame:ToObjectSpace(item.hinge), item.part.CFrame:ToObjectSpace(item.hinge)
		motor:SetAttribute("Side", item.side)
		motor:SetAttribute("Front", item.front)
		motor:SetAttribute("MotionKind", item.kind)
		motor.Parent = item.part
	end
	model.PrimaryPart = body
	source:Destroy()
	for _, p in cuts do p:Destroy() end
	model:SetAttribute("Articulated", true)
	model:SetAttribute("Rigged", true)
	model:SetAttribute("RestHeight", original:GetExtentsSize().Y)
	return model
end

function Rig.install()
	local RS = game.ReplicatedStorage
	local sources, templates = RS.CreatureMeshSources, RS.CreatureMeshes
	local function install(name, spec)
		local ok, model = pcall(Rig.build, name, spec, sources[name])
		if not ok then warn("[CreatureRig] " .. name .. ": " .. tostring(model));return end
		local old = templates:FindFirstChild(name)
		if old then old:Destroy() end
		model.Name, model.Parent = name, templates
	end
	for name, spec in Config.Species do install(name, spec) end
	for _, biome in Config.Biomes do install("Guardian_" .. biome.id, Config.Guardians[biome.id].recipe) end
	RS:SetAttribute("CreatureRigsReady", true)
end

return Rig
