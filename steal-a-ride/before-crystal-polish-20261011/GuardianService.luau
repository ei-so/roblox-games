-- Guardians: patrol a circle around the nest, turn on a grabber almost instantly (Config.Guardian.wakeDelay) and chase.
-- Phase 1 (target in its biome): wind-up, lunge, pathing, tiredness, Blood Moon. Phase 2 (target out of its biome,
-- never the Forest Chicken): enraged at steady full speed and leashed: never more than catch reach + leashBuffer behind,
-- teleporting back (Snap attribute; clients puff). Locks on to one target; escape patches only pause it (no advance,
-- no catch). The chase ends only in the safe zone or on a catch. Anchored models moved with PivotTo on Heartbeat.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local WalkCycle = require(ReplicatedStorage.Shared.WalkCycle)
local Climb = require(ReplicatedStorage.Shared.Climb)
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

-- a carrier who can still be chased: has an egg and isn't home yet. onPatch: standing on an escape patch they can use
-- (the guardian holds off while they stay there, but keeps them as its target)
local function huntable(player)
	local root = player.Parent and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not player:GetAttribute("CarryingEgg") or root.Position.Z > safeZ then
		return nil, nil, false
	end
	local biomeId = biomeAt(root.Position.Z)
	return root, biomeId, biomeId ~= nil and GuardianService.canEscape(player, biomeId)
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

-- phase 2 enrages it: red glow for everyone, roar + warning for the prey, until the chase ends
local function calm(g)
	g.model:SetAttribute("Raging", nil)
	local glow = g.model:FindFirstChild("RageGlow")
	if glow then glow:Destroy() end
end

local function enrage(g, player)
	calm(g)
	g.raging, g.lungeUntil = true, nil -- a lunge never carries into phase 2
	g.model:SetAttribute("Raging", true)
	local glow = Instance.new("Highlight")
	glow.Name = "RageGlow"
	glow.FillColor, glow.OutlineColor = Color3.fromRGB(255, 40, 40), Color3.fromRGB(255, 200, 60)
	glow.FillTransparency = 0.45
	glow.Parent = g.model
	Notify:FireClient(player, "rage", g.biome.id)
end

local function goHome(g)
	g.raging, g.target = false, nil
	calm(g)
	g.model:SetAttribute("ChaseTarget", nil)
	g.state = "return"
	table.clear(g.prey) -- carriers still in its biome get picked up again by the pass-through check
end

-- the locked-on target if still chaseable, else the nearest remaining carrier (drops the uncatchable from the list)
local function findTarget(g)
	local dists = {}
	for player in g.prey do
		local root = huntable(player)
		if not root then
			g.prey[player] = nil
		else
			dists[player] = g.canFly and (root.Position - g.cf.Position).Magnitude or (flat(root.Position) - flat(g.cf.Position)).Magnitude
		end
	end
	local target = GuardianService.pickTarget(g.target, dists)
	if target ~= g.target then
		g.target, g.chaseStart, g.leashFor = target, os.clock(), nil -- a new chase winds up from patrol pace
		g.raging = false
		calm(g)
	end
	if g.model:GetAttribute("ChaseTarget") ~= (target and target.UserId) then
		g.model:SetAttribute("ChaseTarget", target and target.UserId)
	end
	return target, target and dists[target]
end

local function patrolPoint(g): Vector3
	return g.center + Vector3.new(math.cos(g.angle) * g.patrolR, 0, math.sin(g.angle) * g.patrolR)
end

-- chase pace: winds up from patrol pace to full speed. Phase 1 (target in its biome) tires on long runs and takes the
-- Blood Moon boost; raging (phase 2) is steady full speed.
function GuardianService.chaseFactor(chasing: number, raging: boolean, noLane: boolean?, weather: number?): number
	local G = Config.Guardian
	local factor = math.min(1, G.patrolSpeedMult + (1 - G.patrolSpeedMult) * chasing / G.chaseRamp)
	if not raging then
		if chasing > G.tireAfter then
			factor *= G.tiredMult
		end
		factor *= weather or 1
	end
	return noLane and factor * G.noLaneSpeedMult or factor
end

-- leash: (dx, dz) = guardian minus target. Past x, the offset to teleport to (same direction, length x); else nil.
function GuardianService.leashOffset(dx: number, dz: number, x: number): (number?, number?)
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= x then
		return nil, nil
	end
	return dx / d * x, dz / d * x
end

-- a leash pull past x is a visible snap (puff, whoosh, fresh path) only when it jumps more than snapMin; the small
-- per-frame pulls behind a faster rider stay silent
function GuardianService.snapIsVisible(dx: number, dz: number, x: number): boolean
	return math.sqrt(dx * dx + dz * dz) - x > Config.Guardian.snapMin
end

-- after a catch: forget the caught carrier; true while other carriers of its eggs are still being hunted
function GuardianService.keepHunting(prey: { [any]: boolean }, caught: any): boolean
	prey[caught] = nil
	return next(prey) ~= nil
end

-- phase 2 = the target is out of the guardian's own biome (a gap between biomes counts); never for the Chicken
function GuardianService.inPhase2(isForestGuardian: boolean, ownBiome: string, targetBiome: string?): boolean
	return not isForestGuardian and targetBiome ~= ownBiome
end

-- lock-on: keep the current target while it is still chaseable, else the nearest remaining carrier
function GuardianService.pickTarget(current: any?, dists: { [any]: number }): any?
	if current ~= nil and dists[current] then
		return current
	end
	local best, bestD
	for who, d in dists do
		if not bestD or d < bestD then
			best, bestD = who, d
		end
	end
	return best
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
	local speed = g.biome.guardianSpeed * (mult or 1)
	if g.state == "chase" then
		speed *= GuardianService.chaseFactor(os.clock() - g.chaseStart, g.raging == true, g.noLane, GuardianService.speedMultiplier)
	else
		speed *= GuardianService.speedMultiplier
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
	if not g.raging and see and dist <= G.lungeRange + g.radius and now >= (g.lungeReadyAt or 0) then
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
	if g.state == "chase" and GuardianService.keepHunting(g.prey, player) then
		if g.target == player then
			g.target = nil -- lock on to the nearest remaining carrier next frame (phase 2 at once if they're out)
		end
	else
		goHome(g)
	end
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
	if g.gait == "spider" then
		local lunging = g.state == "chase" and (g.lungeUntil or 0) > now
		g.model:SetAttribute("Lunging", lunging or nil)
		if lunging then pose *= CFrame.new(0, -g.height * .08, 0) * CFrame.Angles(math.rad(-7), 0, 0) end
	end
	g.model:PivotTo(g.cf * pose)
	WalkCycle.animateJoints(g.joints, g.phase, g.amount, now, g.gait, airborne == true)
end

-- leash snap: teleport to exactly X behind the target (flyers at its height); a visible one puffs on clients and
-- restarts pathing
local function snap(g, targetPos: Vector3, ox: number, oz: number, visible: boolean)
	local from = g.cf.Position
	local y = g.canFly and math.max(g.home.Position.Y, targetPos.Y) or g.home.Position.Y
	local pos = Vector3.new(targetPos.X + ox, y, targetPos.Z + oz)
	g.cf = CFrame.lookAt(pos, Vector3.new(targetPos.X, y, targetPos.Z))
	if not visible then
		return
	end
	g.waypoints, g.pathAt, g.windowPos, g.windowAt, g.pushUntil = nil, 0, nil, os.clock(), 0
	g.model:SetAttribute("SnapFrom", from)
	g.model:SetAttribute("Snap", (g.model:GetAttribute("Snap") or 0) + 1)
end

local function step(dt: number)
	local now = os.clock()
	-- pass-through: a guardian hunts carriers of its own eggs anywhere in its biome; carriers of other biomes' eggs
	-- it ignores, but bump into it and you're caught (it's a moving obstacle to weave past on the way home)
	for _, player in Players:GetPlayers() do
		local root, biomeId, onPatch = huntable(player)
		local g = root and biomeId and guardians[biomeId]
		if g and not g.prey[player] then
			if player:GetAttribute("CarryingEgg") == biomeId then
				GuardianService.wake(player, biomeId)
			elseif not onPatch and (flat(root.Position) - flat(g.cf.Position)).Magnitude <= Config.Guardian.bumpReach + g.radius then
				catch(g, player)
			end
		end
	end
	for _, g in guardians do
		if g.state == "waking" and now >= g.wakeAt then
			g.state, g.chaseStart, g.target, g.leashFor = "chase", now, nil, nil
			g.waypoints, g.pathAt, g.windowPos, g.windowAt, g.pushUntil = nil, 0, nil, now, 0
		end
		if g.state == "chase" then
			local player, dist = findTarget(g)
			if not player then
				goHome(g)
			else
				local root, targetBiome, onPatch = huntable(player)
				local tpos = root.Position
				g.noLane = not GuardianService.hasLane(player, g.biome.id)
				if GuardianService.inPhase2(g.biome.id == Config.Biomes[1].id, g.biome.id, targetBiome) then
					if not g.raging then
						enrage(g, player)
					end
					local reach = Config.Guardian.catchRadius + g.radius + Config.Guardian.leashBuffer
					local dx, dz = g.cf.Position.X - tpos.X, g.cf.Position.Z - tpos.Z
					if g.leashFor ~= player then -- first pull on this target: a rider who climbed a wall keeps some lead
						local climbedAt = player:GetAttribute("ClimbedAt")
						g.leashFor = player
						g.leashExtra = Climb.keptLead(math.sqrt(dx * dx + dz * dz), reach, climbedAt ~= nil and climbedAt >= g.chaseStart)
					end
					reach += g.leashExtra
					local ox, oz = GuardianService.leashOffset(dx, dz, reach)
					if ox then
						snap(g, tpos, ox, oz, GuardianService.snapIsVisible(dx, dz, reach))
						dist = reach
					end
				end
				if onPatch then
					-- holding: stays on the target, no advance, no catch
				elseif dist <= Config.Guardian.catchRadius + g.radius
					and (g.canFly or math.abs(tpos.Y - g.cf.Position.Y) <= g.height * .5 + Config.Guardian.catchRadius) then
					catch(g, player)
				else
					local target, mult = chaseTarget(g, tpos, dist, now)
					moveToward(g, target, dt, mult)
				end
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
		local out = biomeAt(g.cf.Position.Z) ~= g.biome.id -- visual only: clients stoke its signature VFX
		if out ~= g.out then
			g.out = out
			g.model:SetAttribute("OutOfBiome", out or nil)
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
		-- the arch sign shows the guardian's real chase speed, so it follows any retune of Config
		local board = m:FindFirstChild("Arch") and m.Arch:FindFirstChild("SignBoard")
		for _, label in board and board:GetDescendants() or {} do
			if label:IsA("TextLabel") and label.Name == "Line2" then
				label.Text = ("%s speed: %d"):format(biome.guardian, math.round(biome.guardianSpeed))
			end
		end
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
