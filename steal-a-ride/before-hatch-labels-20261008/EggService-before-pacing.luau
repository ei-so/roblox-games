-- Nest eggs, grabbing, carrying (egg welded above the head), and dropping off at your plot's incubators.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local PlotService = require(script.Parent.PlotService)
local HatchService = require(script.Parent.HatchService)

local Notify = ReplicatedStorage.Remotes.Notify

local EggService = {}
EggService.onGrab = nil -- function(player, biomeId), set by Main (wakes the guardian)
EggService.onOrphanDrop = nil -- function(player, egg) for eggs with no nest spot (secret / raided), set by Main
EggService.onCarryChanged = nil -- function(player) after an egg is attached or taken, set by Main (egg weight)
EggService.rollMutation = function(_biomeId) -- replaced by EventService during weather
	return nil
end

local carried = {} -- [player] = { biome, mutation, secret, spot, model, diedConn }
local nests = {} -- [biomeId] = { [spotPart] = eggModel | false }
local lastFullWarning = {}
local lastPos = {} -- [carrier] = { pos, t }: anti speed-hack samples, cleared whenever an egg leaves a player

local function anchorAll(model, anchored)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = anchored
			p.CanCollide = false
			p.Massless = true
		end
	end
end

local function updateStock(biomeId)
	local nest = workspace.Biomes[biomeId]:FindFirstChild("Nest")
	local stock = 0
	for _, model in nests[biomeId] do
		if model then stock += 1 end
	end
	nest:SetAttribute("EggStock", stock)
end

local function spawnNestEgg(biomeId: string, spot: BasePart, returnedEgg)
	local egg = returnedEgg or { biome = biomeId }
	HatchService.assignSpecies(egg)
	local model = CreatureBuilder.buildEgg(biomeId, nil, false, egg.species)
	model:SetAttribute("EggSpecies", egg.species)
	anchorAll(model, true)
	model:PivotTo(spot.CFrame)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal Egg"
	prompt.ObjectText = biomeId .. " Egg"
	prompt.HoldDuration = 0 -- tap to grab
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		EggService.grab(player, biomeId, spot)
	end)
	model.Parent = spot.Parent.Parent -- the Nest model
	nests[biomeId][spot] = model
	updateStock(biomeId)
end

function EggService.isCarrying(player): boolean
	return carried[player] ~= nil
end

function EggService.getCarried(player)
	return carried[player]
end

-- Weld an egg above the player's head and mark them as a carrier
function EggService.attach(player, egg)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid or humanoid.Health <= 0 or carried[player] then
		return false
	end
	local model = CreatureBuilder.buildEgg(egg.biome, egg.mutation, egg.secret, egg.species)
	anchorAll(model, false)
	model:PivotTo(head.CFrame * CFrame.new(0, 2.6, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Name = "CarriedEgg"
	model.Parent = character
	egg.model = model
	egg.diedConn = humanoid.Died:Connect(function()
		EggService.drop(player)
	end)
	carried[player] = egg
	player:SetAttribute("CarryingEgg", egg.biome)
	if EggService.onCarryChanged then
		EggService.onCarryChanged(player)
	end
	return true
end

-- Remove the carried egg and return it (without sending it anywhere)
function EggService.take(player)
	local egg = carried[player]
	if not egg then
		return nil
	end
	carried[player] = nil
	if egg.diedConn then
		egg.diedConn:Disconnect()
	end
	if egg.model then
		egg.model:Destroy()
	end
	egg.model, egg.diedConn = nil, nil
	lastPos[player] = nil
	player:SetAttribute("CarryingEgg", nil)
	if EggService.onCarryChanged then
		EggService.onCarryChanged(player)
	end
	return egg
end

-- Carrier caught, died or left: the egg goes back to its nest spot (or to whoever owns it)
function EggService.drop(player)
	local egg = EggService.take(player)
	if not egg then
		return nil
	end
	if egg.spot then
		if nests[egg.biome] and not nests[egg.biome][egg.spot] then
			spawnNestEgg(egg.biome, egg.spot, egg)
		end
	elseif EggService.onOrphanDrop then
		EggService.onOrphanDrop(player, egg)
	end
	return egg
end

function EggService.carriers()
	return carried
end

-- An egg lying on the ground with its own prompt (Secret Eggs, eggs knocked out of Mama's hoard). Returns the model.
function EggService.spawnLoose(egg, cframe: CFrame, actionText: string)
	local model = CreatureBuilder.buildEgg(egg.biome, egg.mutation, egg.secret, egg.species)
	anchorAll(model, true)
	model:ScaleTo(1.4)
	model:PivotTo(cframe)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = egg.secret and "Secret Egg" or egg.biome .. " Egg"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not model.Parent or carried[player] or not root or (root.Position - cframe.Position).Magnitude > 16 then
			return
		end
		if EggService.attach(player, egg) then
			model:Destroy()
			if EggService.onGrab and not egg.fromMama then -- Mama's eggs lie on Home Row: no guardian to wake
				EggService.onGrab(player, egg.biome)
			end
		end
	end)
	model.Parent = workspace
	return model
end

function EggService.grab(player, biomeId: string, spot: BasePart)
	local model = nests[biomeId] and nests[biomeId][spot]
	if not model or carried[player] then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - spot.Position).Magnitude > 14 then
		return
	end
	local egg = { biome = biomeId, species = model:GetAttribute("EggSpecies"),
		mutation = EggService.rollMutation(biomeId), secret = false, spot = spot }
	nests[biomeId][spot] = false
	updateStock(biomeId)
	model:Destroy()
	if not EggService.attach(player, egg) then
		spawnNestEgg(biomeId, spot, egg)
		return
	end
	if EggService.onGrab then
		EggService.onGrab(player, biomeId)
	end
end

local function insidePlot(plot, pos: Vector3): boolean
	local floor = plot.Floor
	local offset = pos - floor.Position
	return math.abs(offset.X) < floor.Size.X / 2 and math.abs(offset.Z) < floor.Size.Z / 2
end

local function refill(biomeId: string, maxEggs: number): number
	local added = 0
	for spot, egg in nests[biomeId] do
		if not egg and added < maxEggs then
			spawnNestEgg(biomeId, spot)
			added += 1
		end
	end
	return added
end

function EggService.registerNest(biomeId: string)
	local nest = workspace.Biomes[biomeId]:FindFirstChild("Nest")
	if not nest or nests[biomeId] then
		return
	end
	nests[biomeId] = {}
	local spots = nest.EggSpots:GetChildren()
	table.sort(spots, function(a, b) return a.Name < b.Name end)
	local capacity = biomeId == "Forest" and Config.Nests.forestEggs or Config.Nests.eggs
	for i, spot in spots do
		if i <= capacity then nests[biomeId][spot] = false end
	end
	nest:SetAttribute("EggCapacity", math.min(capacity, #spots))
	nest:SetAttribute("NextRefill", workspace:GetServerTimeNow() + (biomeId == "Forest" and Config.Nests.forestRefill or Config.Nests.refillInterval))
	refill(biomeId, math.huge)
end

function EggService.start()
	for _, biome in Config.Biomes do
		EggService.registerNest(biome.id)
	end

	-- drop-off check: carriers standing on their own plot
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, egg in carried do
				local plot = PlotService.get(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if plot and root and insidePlot(plot, root.Position) then
					if HatchService.deposit(player, egg) then
						EggService.take(player)
						Notify:FireClient(player, "toast", "Egg in the incubator!")
					elseif os.clock() - (lastFullWarning[player] or 0) > 4 then
						lastFullWarning[player] = os.clock()
						Notify:FireClient(player, "toast", "Incubators full!")
					end
				end
			end
		end
	end)

	-- anti speed-hack: a carrier moving faster than the server allows drops the egg
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player in carried do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local pos = Vector3.new(root.Position.X, 0, root.Position.Z)
					local prev = lastPos[player]
					if prev and EggService.allowedSpeed then
						local speed = (pos - prev.pos).Magnitude / (os.clock() - prev.t)
						if speed > EggService.allowedSpeed(player) * 1.4 + 5 then
							EggService.drop(player)
							Notify:FireClient(player, "toast", "You dropped the egg: moving too fast!")
						end
					end
					lastPos[player] = { pos = pos, t = os.clock() }
				end
			end
			for player in lastPos do
				if not carried[player] then
					lastPos[player] = nil
				end
			end
		end
	end)

	-- Forest trickles back one egg at a time so new players never get stuck
	task.spawn(function()
		while true do
			task.wait(Config.Nests.forestRefill)
			refill("Forest", 1)
			workspace.Biomes.Forest.Nest:SetAttribute("NextRefill", workspace:GetServerTimeNow() + Config.Nests.forestRefill)
		end
	end)
	-- every other nest refills together
	task.spawn(function()
		while true do
			task.wait(Config.Nests.refillInterval)
			local added = 0
			for biomeId in nests do
				if biomeId ~= "Forest" then
					added += refill(biomeId, math.huge)
					workspace.Biomes[biomeId].Nest:SetAttribute("NextRefill", workspace:GetServerTimeNow() + Config.Nests.refillInterval)
				end
			end
			if added > 0 then
				Notify:FireAllClients("toast", "Nests refilled!")
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		EggService.drop(player)
		lastFullWarning[player] = nil
	end)
end

return EggService
