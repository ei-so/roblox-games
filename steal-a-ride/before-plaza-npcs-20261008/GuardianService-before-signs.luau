-- Guardians: patrol a circle around the nest, turn on a grabber almost instantly (Config.Guardian.wakeDelay), chase in a straight line,
-- catch + fling, then walk back to the circle.
-- A guardian hunts whoever grabs its egg all the way home (other biomes' carriers only get caught if they bump
-- into it): the chase only ends in the safe zone (past the Forest exit line), in a usable escape patch, or on a catch.
-- Anchored models moved with PivotTo on Heartbeat (no Humanoids). Walking guardians path around solid props and
-- patches like players have to; flyers go straight over. See chaseTarget for the anti-juke rules.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
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
GuardianService.hasLane = function(_player, _biomeId) -- rides the biome's lane ability? set by Main
	return true
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
	if g.state == "patrol" or g.state == "return" then
		g.state = "waking"
		local noLane = player and not GuardianService.hasLane(player, biomeId)
		g.wakeAt = os.clock() + (noLane and Config.Guardian.noLaneWakeDelay or Config.Guardian.wakeDelay)
	end
	if newPrey then -- roar + chase sting on the hunted player's client
		if not GuardianService.hasLane(player, biomeId) then
			Notify:FireClient(player, "toast", ("No %s ride: the %s reacts instantly and the escape patches won't hide you!"):format(g.biome.lane, g.biome.guardian))
		end
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
			local d = g.canFly and (root.Position - g.cf.Position).Magnitude or (flat(root.Position) - flat(g.cf.Position)).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	if g.model:GetAttribute("ChaseTarget") ~= (best and best.UserId) then
		g.model:SetAttribute("ChaseTarget", best and best.UserId)
	end
	return best, bestDist
end

-- prey nearly home: the guardian enrages for the rest of this chase (red glow for everyone, roar + warning for the prey)
local function enrage(g, player)
	g.raging = true
	g.model:SetAttribute("Raging", true)
	local glow = Instance.new("Highlight")
	glow.Name = "RageGlow"
	glow.FillColor, glow.OutlineColor = Color3.fromRGB(255, 40, 40), Color3.fromRGB(255, 200, 60)
	glow.FillTransparency = 0.45
	glow.Parent = g.model
	Notify:FireClient(player, "rage", g.biome.id)
end

local function goHome(g)
	if g.raging then
		g.raging = false
		g.model:SetAttribute("Raging", nil)
		local glow = g.model:FindFirstChild("RageGlow")
		if glow then glow:Destroy() end
	end
	g.model:SetAttribute("ChaseTarget", nil)
	g.state = "return"
	table.clear(g.prey) -- carriers still in its biome get picked up again by the pass-through check
end

local function patrolPoint(g): Vector3
	return g.center + Vector3.new(math.cos(g.angle) * g.patrolR, 0, math.sin(g.angle) * g.patrolR)
end

-- chase pace: winds up from patrol pace to full speed, tires on long runs, and rages near the safe line
function GuardianService.chaseFactor(chasing: number, raging: boolean?, noLane: boolean?): number
	local G = Config.Guardian
	local factor = math.min(1, G.patrolSpeedMult + (1 - G.patrolSpeedMult) * chasing / G.chaseRamp)
	if raging then
		factor *= G.rageMult
	elseif chasing > G.tireAfter then
		factor *= G.tiredMult
	end
	return noLane and factor * G.noLaneSpeedMult or factor
end

local function moveToward(g, target: Vector3, dt: number, mult: number?): number
	local pos = g.cf.Position -- the real position; the model shows it plus the walk bounce
	local altitude = g.canFly and g.state == "chase" and math.max(g.home.Position.Y, target.Y) or g.home.Position.Y
	local goal = Vector3.new(target.X, altitude, target.Z)
	local delta = goal - pos
	local dist = delta.Magnitude
	if dist < 0.05 then
		return 0
	end
	local speed = g.biome.guardianSpeed * GuardianService.speedMultiplier * (mult or 1)
	if g.state == "chase" then
		speed *= GuardianService.chaseFactor(os.clock() - g.chaseStart, g.raging, g.noLane)
	end
	if (g.slowUntil or 0) > os.clock() then
		speed *= g.slowFactor
	end
	local step = math.min(dist, speed * dt)
	local newPos = pos + delta.Unit * step
	g.cf = CFrame.lookAt(newPos, newPos + delta.Unit)
	g.moved += step
	return dist - step
end

-- solid props and patches: what walking guardians must go around (filled in start)
local blockers = RaycastParams.new()
blockers.FilterType = Enum.RaycastFilterType.Include
blockers.RespectCanCollide = true

local function clearLine(from: Vector3, to: Vector3): boolean
	local a, b = Vector3.new(from.X, 3, from.Z), Vector3.new(to.X, 3, to.Z)
	return workspace:Raycast(a, b - a, blockers) == nil
end

local function repath(g, goal: Vector3)
	g.computing = true
	task.spawn(function()
		local G = Config.Guardian
		local path = PathfindingService:CreatePath({ AgentRadius = G.pathRadius, AgentHeight = 8, AgentCanJump = false, WaypointSpacing = 6 })
		local ok = pcall(function()
			path:ComputeAsync(Vector3.new(g.cf.Position.X, 3, g.cf.Position.Z), goal)
		end)
		g.waypoints = ok and path.Status == Enum.PathStatus.Success and path:GetWaypoints() or nil
		g.wp, g.pathAt, g.computing = 2, os.clock(), false
	end)
end

-- Where a chasing guardian heads this frame, and a speed multiplier. Obstacles cost you distance, never the chase:
-- it always knows where you are, cuts straight in when close and clear, pushes through if it stops making progress,
-- speeds up a little when far behind and out of sight, and lunges when close.
local function chaseTarget(g, goal: Vector3, dist: number, now: number): (Vector3, number)
	local G = Config.Guardian
	if g.canFly then
		return goal, 1
	end
	local pos = g.cf.Position
	local see = clearLine(pos, goal)
	if see and dist <= G.lungeRange + g.radius and now >= (g.lungeReadyAt or 0) then
		g.lungeUntil, g.lungeReadyAt = now + G.lungeSeconds, now + G.lungeCooldown
	end
	if (g.lungeUntil or 0) > now then
		return goal, G.lungeMult
	end
	local mult = (dist > G.catchUpRange + g.radius and not see) and G.catchUpMult or 1
	if now - (g.windowAt or 0) >= G.stuckSeconds then
		if g.windowPos and (flat(pos) - flat(g.windowPos)).Magnitude < g.biome.guardianSpeed * G.stuckSeconds * 0.3 then
			g.pushUntil = now + G.stuckSeconds * 1.5
		end
		g.windowPos, g.windowAt = pos, now
	end
	if (see and dist <= G.directRange + g.radius) or (g.pushUntil or 0) > now then
		return goal, mult
	end
	if not g.computing and now - (g.pathAt or 0) >= G.pathEvery then
		repath(g, goal)
	end
	local wps = g.waypoints
	if not wps then
		return goal, mult -- no route found: straight at you
	end
	while wps[g.wp] and (flat(wps[g.wp].Position) - flat(pos)).Magnitude < 4 do
		g.wp += 1
	end
	return wps[g.wp] and wps[g.wp].Position or goal, mult
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
		if math.floor(g.phase) ~= before and not (g.canFly and g.cf.Position.Y > g.home.Position.Y + .5) then
			g.model:SetAttribute("Step", math.floor(g.phase))
		end
	end
	g.moved = 0
	local airborne = g.canFly and g.cf.Position.Y > g.home.Position.Y + .5
	local pose = airborne and WalkCycle.offset(now * 1.5, 1, g.height, "fly")
		or g.amount > 0 and WalkCycle.offset(g.phase, g.amount, g.height, g.gait) or WalkCycle.idle(now, g.height)
	g.model:SetAttribute("Airborne", airborne == true)
	g.model:PivotTo(g.cf * pose)
	WalkCycle.animateJoints(g.joints, g.phase, g.amount, now, g.gait, airborne == true)
end

local function step(dt: number)
	local now = os.clock()
	-- pass-through: a guardian hunts carriers of its own eggs anywhere in its biome; carriers of other biomes' eggs
	-- it ignores, but bump into it and you're caught (it's a moving obstacle to weave past on the way home)
	for _, player in Players:GetPlayers() do
		local root, biomeId = huntable(player)
		local g = root and biomeId and guardians[biomeId]
		if g and not g.prey[player] then
			if player:GetAttribute("CarryingEgg") == biomeId then
				GuardianService.wake(player, biomeId)
			elseif (flat(root.Position) - flat(g.cf.Position)).Magnitude <= Config.Guardian.bumpReach + g.radius then
				catch(g, player)
			end
		end
	end
	for _, g in guardians do
		if g.state == "waking" and now >= g.wakeAt then
			g.state, g.chaseStart = "chase", now
			g.waypoints, g.pathAt, g.windowPos, g.windowAt, g.pushUntil = nil, 0, nil, now, 0
		end
		if g.state == "chase" then
			local player, dist = findTarget(g)
			if not player then
				goHome(g)
			elseif dist <= Config.Guardian.catchRadius + g.radius
				and (g.canFly or math.abs(player.Character.HumanoidRootPart.Position.Y - g.cf.Position.Y) <= g.height * .5 + Config.Guardian.catchRadius) then
				catch(g, player)
			else
				g.noLane = not GuardianService.hasLane(player, g.biome.id)
				if not g.raging and safeZ - player.Character.HumanoidRootPart.Position.Z <= Config.Guardian.rageDistance then
					enrage(g, player)
				end
				local target, mult = chaseTarget(g, player.Character.HumanoidRootPart.Position, dist, now)
				moveToward(g, target, dt, mult)
			end
		elseif g.state == "return" then
			if moveToward(g, patrolPoint(g), dt) <= 1 then
				g.state = "patrol"
			end
		elseif g.state == "patrol" then
			local speed = g.biome.guardianSpeed * Config.Guardian.patrolSpeedMult
			g.angle += speed * dt / g.patrolR
			moveToward(g, patrolPoint(g), dt, Config.Guardian.patrolSpeedMult * 1.5) -- a bit of slack so it never lags the point
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
local joints = WalkCycle.bind(model)
	CreatureBuilder.placeOn(model, spot.CFrame)
	model.Name = "Guardian"
	model.Parent = biomeModel
	local _, size = model:GetBoundingBox()
	local nest = biomeModel:FindFirstChild("Nest")
	local home = model:GetPivot().Position
	local center = nest and Vector3.new(nest:GetPivot().Position.X, home.Y, nest:GetPivot().Position.Z) or home
	guardians[biomeId] = {
		center = center, angle = math.atan2(home.Z - center.Z, home.X - center.X),
		-- radius: body length, not wingspan. Mesh guardians carry the primitive's (BodyRadius) so catch distances stay as tested
		model = model, home = model:GetPivot(), radius = model:GetAttribute("BodyRadius") or size.Z / 2, state = "patrol",
		biome = Config.BiomeById[biomeId], prey = {},
		cf = model:GetPivot(), moved = 0, phase = 0, amount = 0, height = size.Y, stride = WalkCycle.stride(model),
		gait = Config.Guardians[biomeId].gait, joints = joints, canFly = Config.Guardians[biomeId].canFly == true,
	}
	local g = guardians[biomeId] -- patrol just outside its own catch reach, so grabbing behind its back is fair
	g.patrolR = Config.Guardian.catchRadius + g.radius + Config.Guardian.patrolGap
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
	local solid = {}
	for _, biome in Config.Biomes do
		for _, name in { "Props", "Patches" } do
			local folder = workspace.Biomes[biome.id]:FindFirstChild(name)
			if folder then table.insert(solid, folder) end -- the Forest has no patches
		end
	end
	blockers.FilterDescendantsInstances = solid
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
