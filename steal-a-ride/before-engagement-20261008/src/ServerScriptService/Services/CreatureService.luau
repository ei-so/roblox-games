-- Owned creatures: pen (earns cash), stable (storage), mounts (Part 3). Renders pen models on the plot.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local Remotes = ReplicatedStorage.Remotes

local CreatureService = {}

local function locationOf(data, uid): string
	if table.find(data.Pen, uid) then
		return "Pen"
	elseif table.find(data.Mounts, uid) then
		return "Mount"
	end
	return "Stable"
end

function CreatureService.stableCount(data): number
	local n = 0
	for uid in data.Creatures do
		if locationOf(data, uid) == "Stable" then
			n += 1
		end
	end
	return n
end

function CreatureService.incomeOf(player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, uid in data.Pen do
		local c = data.Creatures[uid]
		if c then
			total += Config.income(c, data.Rebirths, data.Index)
		end
	end
	return total * (player:GetAttribute("VIPPass") and 1.5 or 1)
end

local function renderPen(player)
	local plot = PlotService.get(player)
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	local folder = plot:FindFirstChild("PenModels")
	if folder then
		folder:ClearAllChildren()
	else
		folder = Instance.new("Folder")
		folder.Name = "PenModels"
		folder.Parent = plot
	end
	local face = Vector3.new(-plot:GetAttribute("Side"), 0, 0)
	for _, pedestal in plot.Pen:GetChildren() do
		local slot = pedestal:GetAttribute("Slot")
		local uid = data.Pen[slot]
		local c = uid and data.Creatures[uid]
		pedestal.Transparency = slot <= data.PenSlots and 0 or 0.75
		local label = pedestal.Info.Text
		if c then
			local model = CreatureBuilder.build(c.species, c.rarity, c.mutation)
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = not model:GetAttribute("Rigged") or p == model.PrimaryPart
				end
			end
			local top = pedestal.Position + Vector3.new(0, 0.5, 0)
			CreatureBuilder.placeOn(model, CFrame.lookAt(top, top - face))
			model:SetAttribute("PenGround", model:GetPivot()) -- grounded home pose, recorded before the rarity beam is added
			-- name tag rides just above the creature's head (follows its roaming; floaters bob up to 0.6 studs)
			local box, size = model:GetBoundingBox()
			pedestal.Info.Adornee = model.PrimaryPart
			pedestal.Info.StudsOffsetWorldSpace = Vector3.new(0, box.Position.Y + size.Y / 2 - model.PrimaryPart.Position.Y + 2, 0)
			model.Parent = folder
			local rarity = Config.RarityById[c.rarity]
			if rarity.index >= 4 then -- Epic and up: a light beam in the rarity color, visible from down the avenue
				local beam = Instance.new("Part")
				beam.Name = "RarityBeam"
				beam.Shape = Enum.PartType.Cylinder
				beam.Size = Vector3.new(40, 2.5, 2.5)
				beam.CFrame = CFrame.new(top + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90))
				beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch = true, false, false, false
				beam.Material = Enum.Material.Neon
				beam.Color = rarity.color
				beam.Transparency = 0.65
				beam.CastShadow = false
				beam.Parent = model
			end
			label.Text = ('<font color="#%s">%s</font>\n$%s/s'):format(rarity.color:ToHex(), Config.Species[c.species].display,
				Format.number(Config.income(c, data.Rebirths, data.Index)))
		else
			pedestal.Info.Adornee = nil
			label.Text = "" -- empty and locked pedestals stay unlabeled; locked ones are faded
		end
	end
end

-- Call after any change to a player's creatures
function CreatureService.changed(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local count, best = 0, 0
	for _, c in data.Creatures do
		count += 1
		best = math.max(best, Config.BiomeById[Config.Species[c.species].biome].index)
	end
	player:SetAttribute("CreatureCount", count)
	player:SetAttribute("BestBiome", best)
	player:SetAttribute("CashPerSecond", CreatureService.incomeOf(player))
	renderPen(player)
	Remotes.InventoryChanged:FireClient(player)
end

-- Adds a hatched creature: pen if there's room, else stable. Returns the uid, or nil if both are full.
function CreatureService.add(player, creature)
	local data = DataService.get(player)
	local uid = HttpService:GenerateGUID(false)
	if #data.Pen < data.PenSlots then
		data.Creatures[uid] = creature
		table.insert(data.Pen, uid)
	elseif CreatureService.stableCount(data) < Config.Plot.stableSize then
		data.Creatures[uid] = creature
	else
		return nil
	end
	local key = creature.species .. "_" .. creature.rarity
	local firstTime = not data.Index[key]
	data.Index[key] = true
	CreatureService.changed(player)
	if firstTime then -- each new Index entry pays 60 s of that biome's Common income
		local reward = Config.IndexRewardSeconds * Config.income({ species = creature.species, rarity = "Common" }, data.Rebirths)
		DataService.addCash(player, reward)
		ReplicatedStorage.Remotes.Notify:FireClient(player, "toast", ("New Index entry! +$%s"):format(Format.number(reward)))
		if Config.mastered(data.Index, creature.species) then
			ReplicatedStorage.Remotes.Notify:FireClient(player, "toast",
				("%s Mastery! Every %s earns +%d%% forever"):format(Config.Species[creature.species].display,
					Config.Species[creature.species].display, math.round((Config.MasteryIncomeX - 1) * 100)))
		end
	end
	return uid
end

function CreatureService.inventory(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local list = {}
	for uid, c in data.Creatures do
		local spec = Config.Species[c.species]
		table.insert(list, {
			uid = uid, species = c.species, display = spec.display, rarity = c.rarity, mutation = c.mutation,
			biome = spec.biome, ability = spec.ability, income = Config.income(c, data.Rebirths, data.Index),
			speed = Config.mountSpeed(c), location = locationOf(data, uid),
		})
	end
	local index = {}
	for key in data.Index do
		table.insert(index, key)
	end
	return {
		creatures = list, index = index, penSlots = data.PenSlots, penCount = #data.Pen,
		stableSize = Config.Plot.stableSize, stableCount = CreatureService.stableCount(data),
	}
end

local function validUid(player, uid)
	local data = DataService.get(player)
	return data and type(uid) == "string" and data.Creatures[uid] ~= nil, data
end

function CreatureService.start()
	Remotes.GetInventory.OnServerInvoke = CreatureService.inventory

	Remotes.PlaceInPen.OnServerEvent:Connect(function(player, uid)
		local ok, data = validUid(player, uid)
		if ok and locationOf(data, uid) == "Stable" and #data.Pen < data.PenSlots then
			table.insert(data.Pen, uid)
			CreatureService.changed(player)
		end
	end)

	Remotes.RemoveFromPen.OnServerEvent:Connect(function(player, uid)
		local ok, data = validUid(player, uid)
		local index = ok and table.find(data.Pen, uid)
		if index and CreatureService.stableCount(data) < Config.Plot.stableSize then
			table.remove(data.Pen, index)
			CreatureService.changed(player)
		end
	end)

	Remotes.Sell.OnServerEvent:Connect(function(player, uid)
		local ok, data = validUid(player, uid)
		if not ok or locationOf(data, uid) == "Mount" then
			return
		end
		local value = Config.SellSeconds * Config.income(data.Creatures[uid], data.Rebirths, data.Index)
		local index = table.find(data.Pen, uid)
		if index then
			table.remove(data.Pen, index)
		end
		data.Creatures[uid] = nil
		DataService.addCash(player, value)
		CreatureService.changed(player)
	end)

	-- Fuse Machine (Plaza): 3 of the same species + rarity -> 1 of the next rarity, keeping the best mutation
	local machine = workspace.Plaza.FuseMachine.Body
	local fusePrompt = Instance.new("ProximityPrompt")
	fusePrompt.Name = "FuseMachinePrompt"
	fusePrompt.ActionText = "Open Fuse Machine"
	fusePrompt.ObjectText = "3 of a kind = 1 rarer"
	fusePrompt.HoldDuration = 0
	fusePrompt.MaxActivationDistance = 14
	fusePrompt.RequiresLineOfSight = false
	fusePrompt.Parent = machine -- the client opens the Stable when this is triggered

	Remotes.Fuse.OnServerEvent:Connect(function(player, uid)
		local ok, data = validUid(player, uid)
		if not ok or table.find(data.Mounts, uid) then
			return
		end
		local notify = ReplicatedStorage.Remotes.Notify
		local c = data.Creatures[uid]
		local rarity = Config.RarityById[c.rarity]
		if rarity.index >= 5 then
			return notify:FireClient(player, "toast", "Legendary and Mythic creatures can't be fused")
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - machine.Position).Magnitude > 30 then
			return notify:FireClient(player, "toast", "Go to the Fuse Machine in the Plaza to fuse!")
		end
		local picks = { uid }
		for other, oc in data.Creatures do
			if #picks < 3 and other ~= uid and oc.species == c.species and oc.rarity == c.rarity and not table.find(data.Mounts, other) then
				table.insert(picks, other)
			end
		end
		if #picks < 3 then
			return notify:FireClient(player, "toast", "You need 3 of the same creature and rarity")
		end
		local bestMutation, bestX = nil, 1
		for _, pick in picks do
			local m = data.Creatures[pick].mutation
			if m and Config.Mutations[m].incomeX > bestX then
				bestMutation, bestX = m, Config.Mutations[m].incomeX
			end
			local penIndex = table.find(data.Pen, pick)
			if penIndex then
				table.remove(data.Pen, penIndex)
			end
			data.Creatures[pick] = nil
		end
		local result = { species = c.species, rarity = Config.Rarities[rarity.index + 1].id, mutation = bestMutation }
		CreatureService.add(player, result)
		notify:FireClient(player, "hatched", result)
	end)

	-- income tick
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in game:GetService("Players"):GetPlayers() do
				if DataService.get(player) then
					local boost = (player:GetAttribute("CashBoostUntil") or 0) > os.time() and 2 or 1 -- Mama 75-hit reward
					local perSecond = CreatureService.incomeOf(player) * boost
					player:SetAttribute("CashPerSecond", perSecond) -- HUD shows the doubled rate while boosted
					DataService.addCash(player, perSecond)
				end
			end
		end
	end)
end

function CreatureService.cleanup(player)
	local plot = PlotService.get(player)
	local folder = plot and plot:FindFirstChild("PenModels")
	if folder then
		folder:ClearAllChildren()
	end
	if plot then
		for _, pedestal in plot.Pen:GetChildren() do
			pedestal.Info.Text.Text = ""
			pedestal.Transparency = 0
		end
	end
end

return CreatureService
