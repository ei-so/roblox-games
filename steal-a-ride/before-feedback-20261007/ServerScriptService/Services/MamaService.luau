-- Mama's Revenge (every 20 min): a co-op boss. Mama Dragon walks Home Row and back (2 min), snatching an incubator egg
-- every 6 s from the nearest unshielded plot. Players click her one open weak spot (it moves every 5 s) and dodge her
-- red-ring stomps. Every 15% of her HP knocks a hoard egg onto the ground for anyone to grab. Beat her and the rest
-- go home plus Lucky Eggs by damage share; let her escape and her hoard is lost.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local WalkCycle = require(ReplicatedStorage.Shared.WalkCycle)
local PlotService = require(script.Parent.PlotService)
local HatchService = require(script.Parent.HatchService)
local EggService = require(script.Parent.EggService)
local SpeedService = require(script.Parent.SpeedService)

local Notify = ReplicatedStorage.Remotes.Notify
local E = Config.Events

local MamaService = {}
MamaService.isShielded = function(_player) return false end -- set by Main (StealService.shielded)
MamaService.weatherBusy = function() return false end -- set by Main (EventService)

local START = Vector3.new(0, 0.4, -150) -- Biome Road end of Home Row
local FINISH = Vector3.new(0, 0.4, 135) -- Plaza edge
local ORBS = { Head = "Head", Chest = "Belly", Tail = "Tail" } -- weak spot -> body part it sits on
-- a generated mesh has no named parts: weak spots go at these bounding-box spots instead (fractions of size, front = -Z)
local ORB_SPOTS = { Head = Vector3.new(0, 0.3, -0.48), Chest = Vector3.new(0, -0.05, -0.38), Tail = Vector3.new(0, 0.05, 0.5) }

local active -- the running event, or nil
local ORB_ON, ORB_OFF = Color3.fromRGB(255, 70, 90), Color3.fromRGB(90, 80, 100)

local function setAttr(name, value)
	workspace:SetAttribute(name, value)
end

local function topList(fight)
	local list = {}
	for player, dmg in fight.damage do
		if player.Parent then
			table.insert(list, { player = player, dmg = dmg })
		end
	end
	table.sort(list, function(a, b) return a.dmg > b.dmg end)
	return list
end

local function publishTop(fight)
	local lines = {}
	for i, row in topList(fight) do
		if i > 3 then break end
		table.insert(lines, ("%d. %s  %d"):format(i, row.player.DisplayName, row.dmg))
	end
	setAttr("MamaTop", table.concat(lines, "\n"))
end

-- only one weak spot is open (glowing, clickable) at a time
local function setActive(fight, orb)
	fight.activeOrb = orb
	for _, o in fight.orbs do
		local on = o == orb
		o.Color = on and ORB_ON or ORB_OFF
		o.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		o.Transparency = on and 0 or 0.5
		o.PointLight.Enabled = on
		o.ClickDetector.MaxActivationDistance = on and E.mamaClickRange or 0
	end
end

local function switchOrb(fight)
	local choices = {}
	for _, o in fight.orbs do
		if o ~= fight.activeOrb then table.insert(choices, o) end
	end
	if #choices > 0 then
		setActive(fight, choices[math.random(#choices)])
	end
end

-- a hoard egg falls on the ground near her; anyone can grab it and carry it home
local function knockLoose(fight)
	local item = table.remove(fight.hoard, math.random(#fight.hoard))
	if item.shown then
		item.shown:Destroy()
	end
	setAttr("MamaHoard", #fight.hoard)
	local pos = fight.model:GetPivot().Position
	local angle = math.random() * math.pi * 2
	local spot = Vector3.new(pos.X + math.cos(angle) * 20, 2.5, pos.Z + math.sin(angle) * 20)
	-- owner: if a carrier drops it (or it's still lying here at the end) it goes back to whoever Mama took it from
	local egg = { biome = item.egg.biome, mutation = item.egg.mutation, secret = item.egg.secret, lucky = item.egg.lucky,
		owner = item.owner, fromMama = true }
	table.insert(fight.loose, { model = EggService.spawnLoose(egg, CFrame.new(spot), "Grab Egg"), egg = egg, progress = item.progress })
	Notify:FireAllClients("toast", "An egg fell from Mama's hoard! Grab it!")
end

local function afterDamage(fight)
	setAttr("MamaHP", math.max(0, fight.hp))
	while fight.maxHp - fight.hp >= fight.nextDrop do
		fight.nextDrop += fight.maxHp * E.mamaDropEvery
		if #fight.hoard > 0 and fight.hp > 0 then
			knockLoose(fight)
		end
	end
	if fight.hp <= 0 then
		fight.over = "defeated"
	end
end

-- red ring under her, then the slam: grounded players inside get knocked back and stunned
local function bigStomp(fight)
	local pos = fight.model:GetPivot().Position
	local center = Vector3.new(pos.X, START.Y + 0.05, pos.Z)
	local ring = Instance.new("Part")
	ring.Name = "MamaStompRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 40, 40)
	ring.Transparency = 0.55
	ring.Size = Vector3.new(0.2, E.mamaStompRadius * 2, E.mamaStompRadius * 2)
	ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	task.wait(E.mamaStompWarn)
	ring:Destroy()
	if fight.over then
		return
	end
	Notify:FireAllClients("stomp", center)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local state = humanoid and humanoid:GetState()
		local airborne = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
		local away = root and Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
		if away and away.Magnitude <= E.mamaStompRadius and not airborne then
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
			Notify:FireClient(player, "fling", away * 60 + Vector3.new(0, 35, 0))
			SpeedService.stun(player, E.mamaStompStun)
			Notify:FireClient(player, "toast", "Stomped! Jump or get out of the red ring!")
		end
	end
end

local function onHit(fight, player, orb)
	if fight.over or not player.Character or orb ~= fight.activeOrb then
		return
	end
	-- cap clicks per player per second
	local now = os.clock()
	local clicks = fight.clicks[player] or {}
	fight.clicks[player] = clicks
	while clicks[1] and now - clicks[1] > 1 do
		table.remove(clicks, 1)
	end
	if #clicks >= E.mamaClickCap then
		return
	end
	table.insert(clicks, now)
	fight.damage[player] = (fight.damage[player] or 0) + 1
	fight.hp -= 1
	fight.flinchUntil = now + 0.15
	orb.Color = Color3.new(1, 1, 1)
	task.delay(0.1, function()
		if fight.activeOrb == orb then orb.Color = ORB_ON end
	end)
	afterDamage(fight)
end

local function buildMama(fight)
	local model = CreatureBuilder.buildGuardian("Cosmic", E.mamaScale)
	model.Name = "MamaDragon"
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = not model:GetAttribute("Rigged") or p == model.PrimaryPart
		end
	end
	CreatureBuilder.placeOn(model, CFrame.lookAt(START, FINISH))
	local boxCFrame, boxSize = model:GetBoundingBox()
	fight.orbs = {}
	for orbName, partName in ORBS do
		local host = model:FindFirstChild(partName)
		if host or model.PrimaryPart then
			local orb = Instance.new("Part")
			orb.Name = "WeakSpot" .. orbName
			orb.Shape = Enum.PartType.Ball
			orb.Size = Vector3.new(6, 6, 6)
			orb.Material = Enum.Material.Neon
			orb.Color = Color3.fromRGB(255, 70, 90)
			orb.Anchored, orb.CanCollide, orb.CanTouch = true, false, false
			-- sit on the surface of the host part that faces out (front for head/chest, top for the tail)
			if host then
				local out = orbName == "Tail" and host.CFrame.UpVector or host.CFrame.LookVector
				orb.Position = host.Position + out * (orbName == "Tail" and host.Size.Y / 2 or host.Size.Z / 2)
			else
				orb.Position = (boxCFrame * CFrame.new(ORB_SPOTS[orbName] * boxSize)).Position
			end
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = orb.Color, 16, 3
			light.Parent = orb
			local click = Instance.new("ClickDetector")
			click.MaxActivationDistance = E.mamaClickRange
			click.Parent = orb
			click.MouseClick:Connect(function(player)
				onHit(fight, player, orb)
			end)
			orb.Parent = model
			table.insert(fight.orbs, orb)
		end
	end
	model.Parent = workspace
	setActive(fight, fight.orbs[math.random(#fight.orbs)])
	return model
end

-- nearest plot (to her) whose owner has an incubating egg and isn't shielded
local function snatch(fight)
	local pos = fight.model:GetPivot().Position
	local best, bestDist
	for _, player in Players:GetPlayers() do
		local plot = PlotService.get(player)
		if plot and not MamaService.isShielded(player) and #HatchService.filledSlots(player) > 0 then
			local d = (plot.Floor.Position - pos).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	if not best then
		return
	end
	local slots = HatchService.filledSlots(best)
	local slot = slots[math.random(#slots)]
	local pad = PlotService.get(best).Incubators["Incubator" .. slot]
	local egg, progress = HatchService.takeEgg(best, slot)
	if not egg then
		return
	end
	local item = { owner = best, egg = egg, progress = progress }
	table.insert(fight.hoard, item)
	setAttr("MamaHoard", #fight.hoard)
	-- claw beam from her head to the incubator for a moment
	local head = fight.model:FindFirstChild("Head") or fight.model.PrimaryPart
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = head, pad
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Color = ColorSequence.new(Color3.fromRGB(190, 110, 255))
	beam.LightEmission, beam.Width0, beam.Width1, beam.FaceCamera = 1, 3, 1, true
	beam.Parent = head
	task.delay(0.7, function() beam:Destroy() a0:Destroy() a1:Destroy() end)
	-- the egg lands on her back (glowing hoard pile)
	local shown = CreatureBuilder.buildEgg(egg.biome, egg.mutation, egg.secret)
	for _, p in shown:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery = true, false, false
		end
	end
	shown:ScaleTo(1.6)
	local n = #fight.hoard - 1
	local body = fight.model.PrimaryPart
	shown:PivotTo(body.CFrame * CFrame.new(((n % 3) - 1) * 3.5, body.Size.Y / 2 + 2 + (n // 3) * 3, 3 + (n // 3)))
	shown.Name = "HoardEgg"
	shown.Parent = fight.model
	item.shown = shown
	Notify:FireClient(best, "alarm", "Mama Dragon snatched an egg from your base! Hit her weak spots!")
end

local function finish(fight)
	local pos = fight.model:GetPivot().Position
	if fight.over == "defeated" then
		for _, item in fight.hoard do
			if item.owner.Parent then
				HatchService.give(item.owner, item.egg, item.progress)
			end
		end
		local top = topList(fight)
		local total = 0
		for _, row in top do
			total += row.dmg
		end
		for _, row in top do
			if row.dmg >= E.mamaRewardMinDamage then
				local best = row.player:GetAttribute("BestBiome") or 0
				local biome = Config.Biomes[math.max(1, best)].id
				local count = math.min(E.mamaRewardMax, 1 + math.floor(row.dmg / total / E.mamaRewardShareStep))
				for _ = 1, count do
					HatchService.give(row.player, { biome = biome, lucky = true })
				end
				Notify:FireClient(row.player, "toast", ("You got %d Lucky Egg%s!"):format(count, count > 1 and "s" or ""))
			end
		end
		Notify:FireAllClients("mama", { phase = "defeated", position = pos, eggs = #fight.hoard })
	else
		Notify:FireAllClients("mama", { phase = "escaped", eggs = #fight.hoard })
	end
	for _, loose in fight.loose do -- knocked-loose eggs nobody picked up go back to their owners
		if loose.model.Parent then
			loose.model:Destroy()
			if loose.egg.owner.Parent then
				HatchService.give(loose.egg.owner, loose.egg, loose.progress)
			end
		end
	end
	fight.model:Destroy()
	for _, name in { "MamaPhase", "MamaHP", "MamaMaxHP", "MamaEnds", "MamaTop", "MamaHoard" } do
		setAttr(name, nil)
	end
	active = nil
	return fight.over
end

-- Runs one full event and returns "defeated" or "escaped". opts (tests): warning, duration in seconds.
function MamaService.run(opts)
	if active then
		return nil
	end
	opts = opts or {}
	local fight = { damage = {}, clicks = {}, hoard = {}, loose = {}, flinchUntil = 0 }
	active = fight
	local warning = opts.warning or E.mamaWarning
	setAttr("MamaPhase", "warning")
	setAttr("MamaEnds", os.time() + warning)
	Notify:FireAllClients("mama", { phase = "warning" })
	task.wait(warning)

	local duration = opts.duration or E.mamaDuration
	fight.hp = math.max(E.mamaMinHp, E.mamaHpPerPlayer * #Players:GetPlayers())
	fight.maxHp, fight.nextDrop = fight.hp, fight.hp * E.mamaDropEvery
	fight.model = buildMama(fight)
	setAttr("MamaMaxHP", fight.hp)
	setAttr("MamaHP", fight.hp)
	setAttr("MamaHoard", 0)
	setAttr("MamaTop", "")
	setAttr("MamaEnds", os.time() + duration)
	setAttr("MamaPhase", "active")
	Notify:FireAllClients("mama", { phase = "active" })

	local ground = fight.model:GetPivot().Y - START.Y
	local _, mamaSize = fight.model:GetBoundingBox()
	local joints = WalkCycle.bind(fight.model)
	local started = os.clock()
	local nextSnatch, nextStomp = started + E.mamaSnatchEvery, started + E.mamaStompEvery
	local nextBigStomp, nextSwitch = started + E.mamaBigStompEvery, started + E.mamaWeakSwitch
	while not fight.over do
		local dt = RunService.Heartbeat:Wait()
		local now = os.clock()
		local t = (now - started) / duration
		if t >= 1 then
			fight.over = "escaped"
			break
		end
		-- out to the Plaza in the first half, back to the road in the second
		local outbound = t < 0.5
		local a = outbound and t * 2 or (t - 0.5) * 2
		local from, to = outbound and START or FINISH, outbound and FINISH or START
		local pos = from:Lerp(to, a) + Vector3.new(0, ground, 0)
		-- heavy walk: one step per stomp, so each camera-shake stomp lands as a foot comes down
		local cf = CFrame.lookAt(pos, pos + (to - from).Unit)
			* WalkCycle.offset((now - started) / E.mamaStompEvery, 1, mamaSize.Y, "heavy")
		if fight.flinchUntil > now then
			cf *= CFrame.Angles(math.rad(6), 0, 0)
		end
		fight.model:PivotTo(cf)
		WalkCycle.animateJoints(joints, (now - started) / E.mamaStompEvery, 1, now, "heavy", false)
		if now >= nextStomp then
			nextStomp += E.mamaStompEvery
			Notify:FireAllClients("stomp", pos)
		end
		if now >= nextSnatch then
			nextSnatch += E.mamaSnatchEvery
			task.spawn(snatch, fight)
		end
		if now >= nextBigStomp then
			nextBigStomp += E.mamaBigStompEvery
			task.spawn(bigStomp, fight)
		end
		if now >= nextSwitch then
			nextSwitch += E.mamaWeakSwitch
			switchOrb(fight)
		end
		if math.floor(now * 4) ~= math.floor((now - dt) * 4) then
			publishTop(fight)
		end
	end
	return finish(fight)
end

function MamaService.isActive(): boolean
	return active ~= nil
end

function MamaService.damage(player, amount: number) -- tests: deal damage as if clicked
	if active and active.hp then
		active.damage[player] = (active.damage[player] or 0) + amount
		active.hp -= amount
		afterDamage(active)
	end
end

function MamaService.start()
	task.spawn(function()
		while true do
			task.wait(E.mamaInterval)
			while MamaService.weatherBusy() do -- never during a weather event
				task.wait(5)
			end
			MamaService.run()
		end
	end)
end

return MamaService
