-- Guardians: sleep by the nest, wake 1.5 s after a grab, chase in a straight line, catch + fling, then walk home.
-- A guardian hunts whoever grabs its egg AND any carrier who passes through its biome, at full speed, all the
-- way home: the chase only ends in the safe zone (past the Forest exit line), in a usable escape lane, or on a catch.
-- Anchored models moved with PivotTo on Heartbeat: no Humanoids, no pathfinding (the ground is flat).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local WalkCycle = require(ReplicatedStorage.Shared.WalkCycle)
local SpeedService = require(script.Parent.SpeedService)

local Notify = ReplicatedStorage.Remotes.Notify

local GuardianService = {}
GuardianService.speedMultiplier = 1 -- Blood Moon raises this
GuardianService.canEscape = function(_player, _biomeId) -- escape lanes hook (Part 3)
	return false
end

local guardians = {} -- [biomeId] = { model, home, radius, state, wakeAt, biome, prey, slowUntil, slowFactor, ... }
GuardianService.caughtAt = {} -- [player] = os.clock() of their last catch (no stealing right after)
local eggService

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local zones = {} -- { id, entranceZ, farZ } per biome
local safeZ -- the Forest exit line: anyone past it (toward home) is safe

local function biomeAt(z: number): string?
	for _, zone in zones do
		if z <= zone.entranceZ and z >= zone.farZ then
			return zone.id
		end
	end
	return nil
end

-- a carrier who can still be chased: has an egg, isn't home yet, isn't in an escape lane they can use
local function huntable(player)
	local root = player.Parent and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not player:GetAttribute("CarryingEgg") or root.Position.Z > safeZ then
		return nil, nil
	end
	local biomeId = biomeAt(root.Position.Z)
	if biomeId and GuardianService.canEscape(player, biomeId) then
		return nil, nil
	end
	return root, biomeId
end

function GuardianService.wake(player, biomeId: string)
	local g = guardians[biomeId]
	if not g then
		return
	end
	local newPrey = player and not g.prey[player]
	if player then
		g.prey[player] = true
	end
	if g.state == "sleep" or g.state == "return" then
		g.state = "waking"
		g.wakeAt = os.clock() + Config.Guardian.wakeDelay
	end
	if newPrey then -- roar + chase sting on the hunted player's client
		task.delay(math.max(0, (g.wakeAt or 0) - os.clock()), function()
			if player.Parent and g.prey[player] then
				Notify:FireClient(player, "chase", biomeId)
			end
		end)
	end
end

-- nearest hunted player who is still huntable (drops the rest from the list)
local function findTarget(g)
	local best, bestDist
	for player in g.prey do
		local root = huntable(player)
		if not root then
			g.prey[player] = nil
		else
			local d = (flat(root.Position) - flat(g.cf.Position)).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	return best, bestDist
end

local function goHome(g)
	g.state = "return"
	table.clear(g.prey) -- carriers still in its biome get picked up again by the pass-through check
end

local function moveToward(g, target: Vector3, dt: number): number
	local pos = g.cf.Position -- the real position; the model shows it plus the walk bounce
	local goal = Vector3.new(target.X, g.home.Position.Y, target.Z)
	local delta = goal - pos
	local dist = delta.Magnitude
	if dist < 0.05 then
		return 0
	end
	local speed = g.biome.guardianSpeed * GuardianService.speedMultiplier
	if (g.slowUntil or 0) > os.clock() then
		speed *= g.slowFactor
	end
	local step = math.min(dist, speed * dt)
	local newPos = pos + delta.Unit * step
	g.cf = CFrame.lookAt(newPos, newPos + delta.Unit)
	g.moved += step
	return dist - step
end

local function catch(g, player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	eggService.drop(player)
	GuardianService.caughtAt[player] = os.clock()
	if root then
		local away = flat(root.Position - g.cf.Position)
		away = away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 0, 1)
		Notify:FireClient(player, "fling", away * 70 + Vector3.new(0, 55, 0))
	end
	SpeedService.stun(player, Config.Guardian.stun)
	Notify:FireClient(player, "toast", ("Caught by the %s!"):format(g.biome.guardian))
	goHome(g)
end

-- the cartoon walk: steps follow distance travelled; each footfall sets the Step attribute (clients puff dust)
local function animate(g, now: number, dt: number)
	local moving = g.moved > 0
	g.amount = math.clamp(g.amount + (moving and dt or -dt) * 5, 0, 1)
	if moving then
		local before = math.floor(g.phase)
		g.phase += g.moved / g.stride
		if math.floor(g.phase) ~= before then
			g.model:SetAttribute("Step", math.floor(g.phase))
		end
	end
	g.moved = 0
	local pose = g.amount > 0 and WalkCycle.offset(g.phase, g.amount, g.height, g.gait) or WalkCycle.idle(now, g.height)
	g.model:PivotTo(g.cf * pose)
	-- rigged guardians: swing the legs, opposite sides in opposite directions, one swing per step
	local swing = math.sin(math.pi * g.phase) * math.rad(35) * g.amount
	for _, hip in g.hips do
		hip.motor.C0 = hip.base * CFrame.Angles(swing * hip.side, 0, 0)
	end
end

local function step(dt: number)
	local now = os.clock()
	-- pass-through: a carrier inside a biome is hunted by that biome's guardian too
	for _, player in Players:GetPlayers() do
		local root, biomeId = huntable(player)
		local g = root and biomeId and guardians[biomeId]
		if g and not g.prey[player] then
			GuardianService.wake(player, biomeId)
		end
	end
	for _, g in guardians do
		if g.state == "waking" and now >= g.wakeAt then
			g.state = "chase"
		end
		if g.state == "chase" then
			local player, dist = findTarget(g)
			if not player then
				goHome(g)
			elseif dist <= Config.Guardian.catchRadius + g.radius then
				catch(g, player)
			else
				moveToward(g, player.Character.HumanoidRootPart.Position, dt)
			end
		elseif g.state == "return" then
			if moveToward(g, g.home.Position, dt) <= 0.1 then
				g.state = "sleep"
			end
		elseif g.state == "sleep" then
			g.cf = g.home
		end
		animate(g, now, dt)
	end
end

function GuardianService.spawn(biomeId: string)
	local biomeModel = workspace.Biomes[biomeId]
	local spot = biomeModel:FindFirstChild("GuardianSpot")
	if not spot or guardians[biomeId] then
		return
	end
	local model = CreatureBuilder.buildGuardian(biomeId)
	local rigged = model:GetAttribute("Rigged")
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = not rigged or p == model.PrimaryPart -- rigged: legs hang off the anchored body by their joints
		end
	end
	local hips = {}
	for _, m in model:GetDescendants() do
		if m:IsA("Motor6D") and m:GetAttribute("Side") then
			table.insert(hips, { motor = m, base = m.C0, side = m:GetAttribute("Side") })
		end
	end
	CreatureBuilder.placeOn(model, spot.CFrame)
	model.Name = "Guardian"
	model.Parent = biomeModel
	local _, size = model:GetBoundingBox()
	guardians[biomeId] = {
		-- radius: body length, not wingspan. Mesh guardians carry the primitive's (BodyRadius) so catch distances stay as tested
		model = model, home = model:GetPivot(), radius = model:GetAttribute("BodyRadius") or size.Z / 2, state = "sleep",
		biome = Config.BiomeById[biomeId], prey = {},
		cf = model:GetPivot(), moved = 0, phase = 0, amount = 0, height = size.Y, stride = WalkCycle.stride(model),
		gait = Config.Guardians[biomeId].gait, hips = hips,
	}
end

-- Slip Trap: slow the guardian standing on it
function GuardianService.trapNear(pos: Vector3, factor: number, seconds: number): boolean
	for _, g in guardians do
		if (flat(g.cf.Position) - flat(pos)).Magnitude <= g.radius + 3 then
			g.slowUntil, g.slowFactor = os.clock() + seconds, factor
			return true
		end
	end
	return false
end

-- wake every guardian in a biome (Secret Egg grab) -- there's one per biome
GuardianService.wakeAll = function(player, biomeId)
	GuardianService.wake(player, biomeId)
end

function GuardianService.state(biomeId: string): string?
	return guardians[biomeId] and guardians[biomeId].state
end

function GuardianService.start(eggs)
	eggService = eggs
	for _, biome in Config.Biomes do
		local m = workspace.Biomes[biome.id]
		table.insert(zones, { id = biome.id, entranceZ = m:GetAttribute("EntranceZ"), farZ = m:GetAttribute("FarZ") })
		GuardianService.spawn(biome.id)
	end
	safeZ = workspace.Biomes[Config.Biomes[1].id]:GetAttribute("EntranceZ")
	Players.PlayerRemoving:Connect(function(player)
		for _, g in guardians do
			g.prey[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return GuardianService
