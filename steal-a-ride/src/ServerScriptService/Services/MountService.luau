-- Riding: equip/unequip mounts, show the fastest one under the player, set speed and abilities.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local WalkCycle = require(ReplicatedStorage.Shared.WalkCycle)
local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local CreatureService = require(script.Parent.CreatureService)

local Remotes = ReplicatedStorage.Remotes
local Notify = Remotes.Notify

local MountService = {}

-- Riders sit (the client plays the sit animation): root center to thigh underside in the sit pose.
-- ponytail: measured on a default-scale R15 avatar; per-avatar measuring if scaled avatars look off
local SEAT_DROP = { [Enum.HumanoidRigType.R15] = 1.6, [Enum.HumanoidRigType.R6] = 1.0 }

function MountService.slots(player): number
	local data = DataService.get(player)
	return 1 + ((data and data.Rebirths >= Config.MountSlotRebirth) and 1 or 0) + (player:GetAttribute("ExtraMountPass") and 1 or 0)
end

-- the mount you're shown riding: the fastest equipped one
local function best(data)
	local top, topSpeed
	for _, uid in data.Mounts do
		local c = data.Creatures[uid]
		if c and (not topSpeed or Config.mountSpeed(c) > topSpeed) then
			top, topSpeed = c, Config.mountSpeed(c)
		end
	end
	return top, topSpeed
end

SpeedService.mountSpeedOf = function(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local _, speed = best(data)
	return speed
end

function MountService.hasAbility(player, ability: string?): boolean
	if not ability then
		return false
	end
	local data = DataService.get(player)
	for _, uid in data and data.Mounts or {} do
		local c = data.Creatures[uid]
		if c and Config.Species[c.species].ability == ability then
			return true
		end
	end
	return false
end

local function render(player, data)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	if humanoid:GetAttribute("BaseHipHeight") == nil then
		humanoid:SetAttribute("BaseHipHeight", humanoid.HipHeight)
		humanoid:SetAttribute("BaseJump", humanoid.UseJumpPower and humanoid.JumpPower or humanoid.JumpHeight)
	end
	local baseHip = humanoid:GetAttribute("BaseHipHeight")
	local old = character:FindFirstChild("Mount")
	if old then
		old:Destroy()
	end

	local jump = humanoid:GetAttribute("BaseJump") * (MountService.hasAbility(player, "Jump") and Config.Abilities.Jump.jumpMult or 1)
	if humanoid.UseJumpPower then
		humanoid.JumpPower = jump
	else
		humanoid.JumpHeight = jump
	end

	local c = best(data)
	if not c then
		humanoid.HipHeight = baseHip
		return
	end
	local model = CreatureBuilder.build(c.species, c.rarity, c.mutation)
	model.Name = "Mount"
	model:SetAttribute("RiderRootHeight", 0)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	-- the mount stands on the ground and the player sits on its back (top of the Body part, or a SeatHeight attribute)
	CreatureBuilder.placeOn(model, CFrame.new())
	local body = model.PrimaryPart
	local seat = model:GetAttribute("SeatHeight") or (body.Position.Y + body.Size.Y / 2)
	local rootHeight = seat + (SEAT_DROP[humanoid.RigType] or 1.6)
	local leg = humanoid.RigType == Enum.HumanoidRigType.R6 and character:FindFirstChild("Left Leg")
	humanoid.HipHeight = rootHeight - root.Size.Y / 2 - (leg and leg.Size.Y or 0)
	model:SetAttribute("RiderRootHeight", rootHeight)
	-- mesh mounts: shift the creature forward so the rider sits behind its head (SeatForward = fraction of its length)
	local _, mountSize = model:GetBoundingBox()
	local forward = (model:GetAttribute("SeatForward") or 0) * mountSize.Z
	CreatureBuilder.placeOn(model, root.CFrame * CFrame.new(0, -rootHeight, -forward))
	-- a Weld (not WeldConstraint) so every client can animate C0 locally for the walk cycle
	local weld = Instance.new("Weld")
	weld.Name = "MountWeld"
	weld.Part0 = root
	weld.Part1 = body
	weld.C0 = root.CFrame:ToObjectSpace(body.CFrame)
	weld:SetAttribute("BaseC0", weld.C0)
	weld:SetAttribute("Gait", WalkCycle.gaitOf(c.species))
	weld:SetAttribute("Stride", WalkCycle.stride(model))
	weld:SetAttribute("Height", mountSize.Y)
	weld.Parent = body
	-- rarity-colored trail + foot dust (the client turns the dust on while the mount is moving)
	local color = Config.RarityById[c.rarity].color
	local boxCFrame, size = model:GetBoundingBox()
	local function attach(name, offset)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = body -- parent first: WorldPosition is relative to the parent part
		a.WorldPosition = (boxCFrame * CFrame.new(offset)).Position
		return a
	end
	local trail = Instance.new("Trail")
	trail.Name = "RarityTrail"
	trail.Attachment0 = attach("TrailTop", Vector3.new(0, size.Y * 0.1, size.Z * 0.45))
	trail.Attachment1 = attach("TrailBottom", Vector3.new(0, -size.Y * 0.35, size.Z * 0.45))
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Lifetime = 0.4
	trail.LightEmission = 0.6
	trail.Parent = body
	-- rarity aura: colored outline + glow + rising sparkles around the mount, stronger per tier (Common gets none)
	local tier = Config.RarityById[c.rarity].index - 1
	if tier > 0 then
		if not model:FindFirstChildOfClass("Highlight") then -- Golden/Cursed mutations already tint with one
			local outline = Instance.new("Highlight")
			outline.Name = "RarityOutline"
			outline.FillColor = color
			outline.FillTransparency = 1 - tier * 0.04
			outline.OutlineColor = color
			outline.OutlineTransparency = 0.5 - tier * 0.1
			outline.DepthMode = Enum.HighlightDepthMode.Occluded
			outline.Parent = model
		end
		local center = attach("Aura", Vector3.zero)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 0.6 + tier * 0.4
		light.Range = math.max(size.X, size.Z) + 4 + tier * 2
		light.Parent = center
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "RarityAura"
		aura.Color = ColorSequence.new(color, Color3.new(1, 1, 1):Lerp(color, 0.5))
		aura.LightEmission = 1
		aura.LightInfluence = 0
		aura.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.5 + tier * 0.15),
			NumberSequenceKeypoint.new(1, 0),
		})
		aura.Transparency = NumberSequence.new(0, 1)
		aura.Lifetime = NumberRange.new(0.8, 1.4)
		aura.Speed = NumberRange.new(math.max(size.X, size.Z) * 0.6)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Drag = 4
		aura.Acceleration = Vector3.new(0, 2 + tier, 0)
		aura.Rotation = NumberRange.new(0, 360)
		aura.RotSpeed = NumberRange.new(-90, 90)
		aura.Rate = 8 + tier * 8
		aura.LockedToPart = false
		aura.Parent = center
	end
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Color = ColorSequence.new(Color3.fromRGB(205, 190, 165))
	dust.Size = NumberSequence.new(0.6, 1.6)
	dust.Transparency = NumberSequence.new(0.4, 1)
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(1, 3)
	dust.SpreadAngle = Vector2.new(40, 40)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Rate = 18
	dust.Enabled = false
	dust.Parent = attach("Feet", Vector3.new(0, -size.Y / 2, size.Z * 0.2))
	model.Parent = character
end

-- Re-applies everything after a mount change or respawn
function MountService.apply(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local abilities = {}
	for _, uid in data.Mounts do
		local c = data.Creatures[uid]
		local ability = c and Config.Species[c.species].ability
		if ability and not table.find(abilities, ability) then
			table.insert(abilities, ability)
		end
	end
	player:SetAttribute("Abilities", table.concat(abilities, ","))
	local c = best(data)
	player:SetAttribute("Flying", false)
	player:SetAttribute("FlightLanding", false)
	player:SetAttribute("FlightCeiling", nil)
	player:SetAttribute("Riding", c and Config.Species[c.species].display or nil)
	render(player, data)
	SpeedService.refresh(player)
end

function MountService.equip(player, uid): boolean
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" or not data.Creatures[uid] or table.find(data.Mounts, uid) then
		return false
	end
	if #data.Mounts >= MountService.slots(player) then
		-- swap: the oldest mount goes to the stable. Taking the new one from the stable frees a spot;
		-- taking it from the pen doesn't, so that case needs stable room.
		if table.find(data.Pen, uid) and CreatureService.stableCount(data) >= Config.Plot.stableSize then
			return false
		end
		table.remove(data.Mounts, 1)
	end
	local penIndex = table.find(data.Pen, uid)
	if penIndex then
		table.remove(data.Pen, penIndex)
	end
	table.insert(data.Mounts, uid)
	MountService.apply(player)
	CreatureService.changed(player)
	Notify:FireClient(player, "toast", "Riding " .. Config.Species[data.Creatures[uid].species].display .. "!")
	return true
end

-- On join, after passes are checked: saved mounts beyond the current slots go back to the stable (oldest first, like a swap).
-- ponytail: may push the stable over its size; nothing is lost and equip/unequip still enforce the cap
function MountService.trim(player)
	local data = DataService.get(player)
	if not data or #data.Mounts <= MountService.slots(player) then
		return
	end
	while #data.Mounts > MountService.slots(player) do
		table.remove(data.Mounts, 1)
	end
	MountService.apply(player)
	CreatureService.changed(player)
end

function MountService.unequip(player, uid): boolean
	local data = DataService.get(player)
	if data and uid == "all" then -- touch "Get off" button: every mount back to the stable, while it has room
		local moved = false
		while #data.Mounts > 0 and CreatureService.stableCount(data) < Config.Plot.stableSize do
			table.remove(data.Mounts)
			moved = true
		end
		if #data.Mounts > 0 then
			Notify:FireClient(player, "toast", "Your stable is full!")
		end
		if moved then
			MountService.apply(player)
			CreatureService.changed(player)
		end
		return moved
	end
	local index = data and type(uid) == "string" and table.find(data.Mounts, uid)
	if not index or CreatureService.stableCount(data) >= Config.Plot.stableSize then
		return false
	end
	table.remove(data.Mounts, index)
	MountService.apply(player)
	CreatureService.changed(player)
	return true
end

function MountService.start()
	Remotes.EquipMount.OnServerEvent:Connect(MountService.equip)
	Remotes.UnequipMount.OnServerEvent:Connect(MountService.unequip)
end

return MountService
