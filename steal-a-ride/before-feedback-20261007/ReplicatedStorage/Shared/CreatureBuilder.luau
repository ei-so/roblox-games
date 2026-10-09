-- Builds creature Models from primitives using the recipes in Config.Species.
--   CreatureBuilder.build(speciesId, rarityId?, mutationId?) -> Model (unanchored, welded to PrimaryPart "Body")
--   CreatureBuilder.placeOn(model, groundCFrame) -> stands the model on a surface
-- Front of every creature is -Z.
local Config = require(script.Parent.Config)

local CreatureBuilder = {}

local rgb = Color3.fromRGB
local BLACK, WHITE = rgb(20, 20, 25), rgb(255, 255, 255)
local GOLD, CURSE, SHOCK = rgb(255, 200, 60), rgb(70, 0, 10), rgb(120, 200, 255)

local BODY = {
	Ball = { size = Vector3.new(3, 3, 3), round = true },
	Block = { size = Vector3.new(2.6, 2.3, 3.6), round = false },
	Squat = { size = Vector3.new(3.4, 2.2, 3.2), round = true },
}

local function darken(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function part(model: Model, name: string, size: Vector3, color: Color3, cf: CFrame, round: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.CFrame = cf
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	if round then -- Ball parts must be uniform, so ellipsoids are blocks with a sphere mesh
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = model
	return p
end
local function blob(m, n, s, c, cf) return part(m, n, s, c, cf, true) end
local function box(m, n, s, c, cf) return part(m, n, s, c, cf, false) end

local function glow(ctx, p: BasePart)
	if ctx.spec.glow then
		p.Material = Enum.Material.Neon
	end
end

local function eyes(ctx)
	local C, r = ctx.c, ctx.r
	for _, sx in { -1, 1 } do
		local pos = C + Vector3.new(sx * 0.4 * r, 0.15 * r, -0.85 * r)
		blob(ctx.model, "Eye", Vector3.new(0.42, 0.5, 0.25) * r, ctx.spec.eyeColor or BLACK, CFrame.new(pos))
		if ctx.spec.eyeColor then
			blob(ctx.model, "EyePupil", Vector3.new(0.2, 0.3, 0.1) * r, BLACK, CFrame.new(pos + Vector3.new(0, 0, -0.12 * r)))
		end
		blob(ctx.model, "EyeShine", Vector3.new(0.12, 0.12, 0.06) * r, WHITE, CFrame.new(pos + Vector3.new(0.07 * r, 0.1 * r, -0.19 * r)))
	end
end

local F = {}

function F.beak(ctx, style)
	local size, color, tilt = Vector3.new(0.55, 0.4, 0.6) * ctx.k, ctx.accent, 0
	if style == "flat" then
		size = Vector3.new(0.95, 0.25, 0.8) * ctx.k
	elseif style == "hooked" then
		size, tilt, color = Vector3.new(0.5, 0.55, 0.75) * ctx.k, -25, rgb(240, 225, 190)
	elseif style == "yellow" then
		color = rgb(255, 210, 60)
	end
	box(ctx.model, "Beak", size, color,
		CFrame.new(ctx.c + Vector3.new(0, -0.1 * ctx.r, -ctx.r - size.Z * 0.3)) * CFrame.Angles(math.rad(tilt), 0, 0))
end

function F.wings(ctx, style)
	local color = darken(ctx.bodyColor, 0.88)
	local size, x, y, roll = Vector3.new(0.25, 1.1, 1.7), ctx.hw + 0.05, 0.25, 25
	if style == "small" then
		size, roll = Vector3.new(0.2, 0.8, 1.2), 20
	elseif style == "big" then
		size, x, y, roll = Vector3.new(0.25, 2.2, 3.0), ctx.hw + 0.7, 0.9, 50
	elseif style == "bat" then
		size, x, y, roll, color = Vector3.new(0.15, 1.9, 2.5), ctx.hw + 0.8, 0.7, 45, darken(ctx.bodyColor, 0.65)
	elseif style == "flippers" then
		size, x, y, roll, color = Vector3.new(0.2, 1.4, 0.65), ctx.hw + 0.05, -0.2, -15, ctx.bodyColor
	end
	for _, sx in { -1, 1 } do
		blob(ctx.model, "Wing", size, color, CFrame.new(sx * x, y, 0.2) * CFrame.Angles(0, 0, math.rad(-sx * roll)))
	end
end

function F.ears(ctx, style)
	local C, r, k = ctx.c, ctx.r, ctx.k
	for _, sx in { -1, 1 } do
		if style == "long" then
			local cf = CFrame.new(C + Vector3.new(sx * 0.4 * r, r + 0.75 * k, 0.1 * r)) * CFrame.Angles(0, 0, math.rad(-sx * 8))
			blob(ctx.model, "Ear", Vector3.new(0.5, 2.0, 0.35) * k, ctx.bodyColor, cf)
			blob(ctx.model, "EarInner", Vector3.new(0.28, 1.5, 0.12) * k, ctx.accent, cf * CFrame.new(0, 0, -0.14 * k))
		elseif style == "pointy" then
			box(ctx.model, "Ear", Vector3.new(0.75, 0.75, 0.3) * k, ctx.bodyColor,
				CFrame.new(C + Vector3.new(sx * 0.5 * r, 0.8 * r, 0.1 * r)) * CFrame.Angles(0, 0, math.rad(45)))
		elseif style == "round" then
			local cf = CFrame.new(C + Vector3.new(sx * 0.9 * r, 0.55 * r, 0.1 * r))
			blob(ctx.model, "Ear", Vector3.new(0.9, 0.9, 0.3) * k, ctx.bodyColor, cf)
			blob(ctx.model, "EarInner", Vector3.new(0.55, 0.55, 0.1) * k, ctx.accent, cf * CFrame.new(0, 0, -0.12 * k))
		elseif style == "small" then
			blob(ctx.model, "Ear", Vector3.new(0.5, 0.5, 0.3) * k, darken(ctx.bodyColor, 0.85),
				CFrame.new(C + Vector3.new(sx * 0.62 * r, 0.75 * r, 0.15 * r)))
		elseif style == "tufts" then
			box(ctx.model, "Ear", Vector3.new(0.3, 0.75, 0.3) * k, ctx.bodyColor,
				CFrame.new(C + Vector3.new(sx * 0.55 * r, 0.95 * r, 0)) * CFrame.Angles(0, 0, math.rad(-sx * 25)))
		elseif style == "floppy" then
			blob(ctx.model, "Ear", Vector3.new(0.3, 1.9, 1.7) * k, darken(ctx.bodyColor, 0.85),
				CFrame.new(C + Vector3.new(sx * (r + 0.1), -0.1 * r, 0.2 * r)))
		end
	end
end

function F.tail(ctx, style)
	local back = ctx.back
	if style == "puff" then
		blob(ctx.model, "Tail", Vector3.new(1, 1, 1), ctx.bodyColor, CFrame.new(0, 0.2, back + 0.25))
	elseif style == "bushy" then
		local cf = CFrame.new(0, 0.6, back + 0.9) * CFrame.Angles(math.rad(-35), 0, 0)
		blob(ctx.model, "Tail", Vector3.new(1, 1, 2.4), ctx.bodyColor, cf)
		glow(ctx, blob(ctx.model, "TailTip", Vector3.new(0.85, 0.85, 1), ctx.accent, cf * CFrame.new(0, 0, 1.15)))
	elseif style == "long" then
		blob(ctx.model, "Tail", Vector3.new(0.5, 0.5, 3), ctx.bodyColor,
			CFrame.new(0, 0, back + 1.3) * CFrame.Angles(math.rad(-10), 0, 0))
	elseif style == "feather" then
		blob(ctx.model, "Tail", Vector3.new(0.8, 0.2, 2.4), ctx.accent,
			CFrame.new(0, 0.2, back + 1.1) * CFrame.Angles(math.rad(-15), 0, 0))
	elseif style == "curly" then
		local cf = CFrame.new(0, -0.2, back + 0.9) * CFrame.Angles(math.rad(-25), 0, 0)
		blob(ctx.model, "Tail", Vector3.new(0.4, 0.4, 1.8), ctx.bodyColor, cf)
		blob(ctx.model, "TailTip", Vector3.new(0.4, 0.9, 0.4), ctx.bodyColor, cf * CFrame.new(0, 0.35, 0.8))
	elseif style == "flat" then
		blob(ctx.model, "Tail", Vector3.new(0.9, 0.3, 2.2), darken(ctx.bodyColor, 0.85),
			CFrame.new(0, -0.6, back + 0.9) * CFrame.Angles(math.rad(10), 0, 0))
	end
end

function F.nose(ctx)
	blob(ctx.model, "Nose", Vector3.new(0.35, 0.28, 0.25) * ctx.k, ctx.accent,
		CFrame.new(ctx.c + Vector3.new(0, -0.15 * ctx.r, -0.97 * ctx.r)))
end

function F.muzzle(ctx)
	local pos = ctx.c + Vector3.new(0, -0.32 * ctx.r, -0.78 * ctx.r)
	blob(ctx.model, "Muzzle", Vector3.new(1.1, 0.75, 0.6) * ctx.k, ctx.accent, CFrame.new(pos))
	blob(ctx.model, "Nose", Vector3.new(0.32, 0.25, 0.2) * ctx.k, BLACK, CFrame.new(pos + Vector3.new(0, 0.12 * ctx.k, -0.3 * ctx.k)))
end

function F.belly(ctx)
	local s = ctx.bodySize
	blob(ctx.model, "Belly", Vector3.new(s.X * 0.7, s.Y * 0.7, 0.5), ctx.spec.bellyColor or ctx.accent,
		CFrame.new(0, -0.15, ctx.front + 0.15))
end

function F.shell(ctx)
	local s = ctx.bodySize
	local shell = blob(ctx.model, "Shell", Vector3.new(s.X * 1.12, s.Y * 0.75, s.Z * 1.08), ctx.accent,
		CFrame.new(0, ctx.top * 0.45, 0.15))
	shell.Reflectance = 0.25
end

function F.horns(ctx, style)
	local C, r, k = ctx.c, ctx.r, ctx.k
	if style == "single" then
		box(ctx.model, "Horn", Vector3.new(0.35, 1.1, 0.35) * k, ctx.accent,
			CFrame.new(C + Vector3.new(0, 0.55 * r, -0.85 * r)) * CFrame.Angles(math.rad(-35), 0, 0))
	elseif style == "tusks" then
		for _, sx in { -1, 1 } do
			blob(ctx.model, "Tusk", Vector3.new(0.35, 0.35, 2.0) * k, ctx.accent,
				CFrame.new(C + Vector3.new(sx * 0.5 * r, -0.6 * r, -1.1 * r)) * CFrame.Angles(math.rad(20), sx * math.rad(10), 0))
		end
	else
		for _, sx in { -1, 1 } do
			box(ctx.model, "Horn", Vector3.new(0.3, 0.9, 0.3) * k, ctx.accent,
				CFrame.new(C + Vector3.new(sx * 0.28 * r, 0.95 * r, 0.15 * r)) * CFrame.Angles(math.rad(20), 0, math.rad(-sx * 15)))
		end
	end
end

function F.trunk(ctx)
	blob(ctx.model, "Trunk", Vector3.new(0.6, 0.6, 2.0) * ctx.k, ctx.bodyColor,
		CFrame.new(ctx.c + Vector3.new(0, -0.75 * ctx.r, -1.05 * ctx.r)) * CFrame.Angles(math.rad(-37), 0, 0))
end

function F.spikes(ctx)
	local step = (ctx.back - ctx.front) * 0.6 / 3
	for i = 0, 3 do
		box(ctx.model, "Spike", Vector3.new(0.5, 0.5, 0.5), ctx.accent,
			CFrame.new(0, ctx.top + 0.05, ctx.front * 0.6 + i * step) * CFrame.Angles(0, 0, math.rad(45)))
	end
end

function F.spots(ctx)
	for _, off in { Vector3.new(-0.5, 0, -0.9), Vector3.new(0.5, 0, -0.2), Vector3.new(-0.4, 0, 0.5), Vector3.new(0.45, 0, 1.1) } do
		glow(ctx, blob(ctx.model, "Spot", Vector3.new(0.6, 0.15, 0.6), ctx.accent, CFrame.new(off + Vector3.new(0, ctx.top + 0.02, 0))))
	end
end

function F.tentacles(ctx)
	for i = 1, 6 do
		local a = math.rad(i * 60)
		glow(ctx, blob(ctx.model, "Tentacle", Vector3.new(0.35, 1.8, 0.35), ctx.accent,
			CFrame.new(math.cos(a) * 0.85, -ctx.top - 0.5, math.sin(a) * 0.85)))
	end
end

function F.bigEyes(ctx)
	for _, sx in { -1, 1 } do
		local pos = Vector3.new(sx * 0.7, ctx.top - 0.05, ctx.front * 0.45)
		blob(ctx.model, "EyeWhite", Vector3.new(1.1, 1.1, 1.1), WHITE, CFrame.new(pos))
		blob(ctx.model, "EyePupil", Vector3.new(0.55, 0.6, 0.3), BLACK, CFrame.new(pos + Vector3.new(0, 0.05, -0.45)))
		blob(ctx.model, "EyeShine", Vector3.new(0.18, 0.18, 0.08), WHITE, CFrame.new(pos + Vector3.new(0.1, 0.18, -0.6)))
	end
	box(ctx.model, "Mouth", Vector3.new(1.6, 0.1, 0.1), darken(ctx.bodyColor, 0.5), CFrame.new(0, -0.15, ctx.front + 0.02))
end

function F.flame(ctx)
	local holder = box(ctx.model, "FlameHolder", Vector3.new(0.2, 0.2, 0.2), ctx.accent, CFrame.new(ctx.c + Vector3.new(0, ctx.r * 0.9, 0.1)))
	holder.Transparency = 1
	local fire = Instance.new("Fire")
	fire.Color = ctx.accent
	fire.SecondaryColor = ctx.bodyColor
	fire.Size = 2.5
	fire.Heat = 6
	fire.Parent = holder
end

local function recolor(model: Model, target: Color3, alpha: number, material: Enum.Material?)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not p.Name:find("^Eye") and p.Transparency < 1 then
			p.Color = p.Color:Lerp(target, alpha)
			if material then
				p.Material = material
			end
		end
	end
end

local function applyMutation(model: Model, body: BasePart, mutation: string?)
	if mutation == "Golden" then
		recolor(model, GOLD, 0.75, Enum.Material.Foil)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = GOLD
		sparkles.Parent = body
	elseif mutation == "Cursed" then
		recolor(model, CURSE, 0.6)
		local smoke = Instance.new("Smoke")
		smoke.Color = rgb(40, 0, 0)
		smoke.Opacity = 0.2
		smoke.RiseVelocity = 1.5
		smoke.Size = 1.5
		smoke.Parent = body
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 40, 40)
		light.Range = 8
		light.Parent = body
	elseif mutation == "Shocked" then
		recolor(model, SHOCK, 0.15)
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(SHOCK)
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(0.35, 0)
		sparks.Lifetime = NumberRange.new(0.2, 0.4)
		sparks.Rate = 12
		sparks.Speed = NumberRange.new(3, 6)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Parent = body
	end
end

local function assemble(name: string, spec, scale: number, mutation: string?): Model
	local model = Instance.new("Model")
	model.Name = name
	local shape = BODY[spec.shape]
	local s = shape.size
	local body = part(model, "Body", s, spec.body, CFrame.new(), shape.round)
	if spec.translucent then
		body.Material = Enum.Material.Glass
		body.Transparency = 0.25
	end
	model.PrimaryPart = body

	local ctx = {
		model = model, spec = spec, bodySize = s, bodyColor = spec.body, accent = spec.accent,
		hw = s.X / 2, top = s.Y / 2, front = -s.Z / 2, back = s.Z / 2,
	}
	if spec.head == false then
		ctx.c, ctx.r = Vector3.new(0, 0.1, 0), math.min(s.X, s.Y, s.Z) / 2
	else
		local d = 2.2 * (spec.headSize or 1)
		ctx.c, ctx.r = Vector3.new(0, ctx.top * 0.75 + d * 0.35, ctx.front - d * 0.05), d / 2
		blob(model, "Head", Vector3.new(d, d, d), spec.headColor or spec.body, CFrame.new(ctx.c))
	end
	ctx.k = ctx.r / 1.1

	local hasBigEyes = table.find(spec.features, "bigEyes") ~= nil
	if not hasBigEyes then
		eyes(ctx)
	end

	local legs = spec.legs or 4
	local footColor = spec.footColor or (legs == 2 and spec.accent or darken(spec.body, 0.75))
	if legs == 4 then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				blob(model, "Foot", Vector3.new(0.9, 0.8, 1.0), footColor, CFrame.new(sx * (ctx.hw - 0.5), -ctx.top - 0.15, sz * (ctx.back - 0.8)))
			end
		end
	elseif legs == 2 then
		for _, sx in { -1, 1 } do
			blob(model, "Foot", Vector3.new(0.8, 0.45, 1.1), footColor, CFrame.new(sx * 0.6, -ctx.top - 0.05, -0.2))
		end
	end

	for _, feature in spec.features do
		local name, style = string.match(feature, "^(%w+):?(%w*)$")
		local fn = F[name]
		assert(fn, name .. ": unknown feature " .. feature)
		fn(ctx, style ~= "" and style or nil)
	end

	if spec.glow then
		local light = Instance.new("PointLight")
		light.Color = spec.accent
		light.Range = 10
		light.Brightness = 1.2
		light.Parent = body
	end
	applyMutation(model, body, mutation)

	model:ScaleTo(scale)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = p
			weld.Parent = p
		end
	end
	return model
end

-- Generated meshes (Part 6): ReplicatedStorage.CreatureMeshes/<SpeciesId> and /Guardian_<Biome>.
-- Each template is already scaled to the Common (or guardian) size, faces -Z, and may carry SeatFrac
-- (rider seat height as a fraction of its height). Missing template = the primitive recipe above.
local Meshes = script.Parent.Parent:FindFirstChild("CreatureMeshes")

local function fromMesh(template: Model, name: string, scale: number, mutation: string?, spec): Model
	local model = template:Clone()
	model.Name = name
	model:ScaleTo(template:GetScale() * scale)
	local body = model.PrimaryPart
	local jointed = {} -- rigged templates (Motor6D legs) keep their joints instead of a weld
	for _, m in model:GetDescendants() do
		if m:IsA("Motor6D") then
			jointed[m.Part1] = true
		end
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch = false, false, false
			if p ~= body and not jointed[p] then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = body, p
				weld.Parent = p
			end
		end
	end
	if spec and spec.glow then
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = spec.accent, 10, 1.2
		light.Parent = body
	end
	-- textures ignore part Color, so Golden / Cursed also get a tinted Highlight
	-- ponytail: Roblox renders at most 31 Highlights at once; past that the extras just don't show
	if mutation == "Golden" or mutation == "Cursed" then
		local h = Instance.new("Highlight")
		h.FillColor = mutation == "Golden" and GOLD or rgb(150, 0, 20)
		h.FillTransparency = mutation == "Golden" and 0.45 or 0.35
		h.OutlineColor = mutation == "Golden" and rgb(255, 240, 160) or rgb(255, 40, 40)
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
	end
	applyMutation(Instance.new("Model"), body, mutation) -- particles / smoke / light only (nothing to recolor)
	local _, size = model:GetBoundingBox()
	model:SetAttribute("SeatHeight", (template:GetAttribute("SeatFrac") or 0.5) * size.Y)
	model:SetAttribute("SeatForward", template:GetAttribute("SeatForward") or 0.3)
	return model
end

function CreatureBuilder.build(speciesId: string, rarityId: string?, mutation: string?): Model
	local spec = Config.Species[speciesId]
	assert(spec, "unknown species " .. tostring(speciesId))
	local rarity = Config.RarityById[rarityId or "Common"]
	assert(rarity, "unknown rarity " .. tostring(rarityId))
	local mesh = Meshes and Meshes:FindFirstChild(speciesId)
	local model = mesh and fromMesh(mesh, speciesId, rarity.scale, mutation, spec)
		or assemble(speciesId, spec, (spec.size or 1) * rarity.scale, mutation)
	model:SetAttribute("RestHeight", model:GetExtentsSize().Y)
	model:SetAttribute("CanFly", spec.canFly == true)
	model:SetAttribute("Gait", spec.locomotion or (spec.legs == 0 and "float" or spec.legs == 2 and "biped" or "quad"))
	model:SetAttribute("Species", speciesId)
	model:SetAttribute("Rarity", rarity.id)
	model:SetAttribute("Mutation", mutation)
	return model
end

function CreatureBuilder.buildGuardian(biomeId: string, scale: number?): Model
	local g = Config.Guardians[biomeId]
	assert(g, "no guardian for " .. tostring(biomeId))
	local mesh = Meshes and Meshes:FindFirstChild("Guardian_" .. biomeId)
	if mesh then
		return fromMesh(mesh, Config.BiomeById[biomeId].guardian, (scale or g.scale) / g.scale, nil, g.recipe)
	end
	return assemble(Config.BiomeById[biomeId].guardian, g.recipe, scale or g.scale, nil)
end

-- Eggs are colored by biome; secret eggs glow
function CreatureBuilder.buildEgg(biomeId: string, mutation: string?, secret: boolean?): Model
	local accent = Config.BiomeById[biomeId].look.accent
	local model = Instance.new("Model")
	model.Name = biomeId .. "Egg"
	local shell = blob(model, "Shell", Vector3.new(2, 2.6, 2), accent:Lerp(WHITE, 0.45), CFrame.new())
	model.PrimaryPart = shell
	for i, off in { Vector3.new(0.6, 0.5, -0.75), Vector3.new(-0.7, -0.2, -0.55), Vector3.new(0.2, -0.7, 0.85), Vector3.new(-0.5, 0.7, 0.7) } do
		blob(model, "Spot" .. i, Vector3.new(0.6, 0.6, 0.25), darken(accent, 0.8), CFrame.lookAt(off, off * 2))
	end
	if secret then
		shell.Material = Enum.Material.Neon
		shell.Color = rgb(255, 120, 220)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 150, 230)
		light.Range = 14
		light.Brightness = 2
		light.Parent = shell
	end
	applyMutation(model, shell, mutation)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= shell then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = shell
			weld.Part1 = p
			weld.Parent = p
		end
	end
	model:SetAttribute("Biome", biomeId)
	return model
end

-- Puts the model's lowest point on groundCFrame, facing groundCFrame's -Z.
function CreatureBuilder.placeOn(model: Model, groundCFrame: CFrame)
	model:PivotTo(CFrame.new())
	local boxCFrame, size = model:GetBoundingBox()
	local lift = -(boxCFrame.Position.Y - size.Y / 2)
	model:PivotTo(groundCFrame * CFrame.new(0, lift, 0))
end

return CreatureBuilder
