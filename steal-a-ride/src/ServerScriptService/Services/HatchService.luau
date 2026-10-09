-- Incubators: normal eggs keep their chosen species; rarity rolls on deposit (hidden) and rarer eggs take longer to hatch.
-- A finished egg waits on its pad (still stealable) until the owner triggers its Hatch prompt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)

local Notify = ReplicatedStorage.Remotes.Notify
local rng = Random.new()

local HatchService = {}
HatchService.onHatched = nil
HatchService.onRaid = nil -- function(thief, owner, slot), set by Main (StealService)

-- Lucky Eggs stay a fast reward; others scale by their rolled rarity (eggs saved before rolling-on-deposit have no result)
function HatchService.hatchTime(egg): number
	if egg.lucky then
		return Config.Events.luckyHatch
	end
	local base = egg.secret and Config.Events.secretHatch or Config.BiomeById[egg.biome].hatchTime
	local rarity = egg.result and Config.RarityById[egg.result.rarity]
	return base * (rarity and rarity.hatchX or 1)
end
local hatchTime = HatchService.hatchTime

local function weighted(weights): number
	local total = 0
	for _, w in weights do
		total += w
	end
	local r = rng:NextNumber() * total
	for i, w in weights do
		r -= w
		if r <= 0 then
			return i
		end
	end
	return #weights
end

local RARITY_ODDS = {}
for i = 1, 5 do
	RARITY_ODDS[i] = Config.Rarities[i].odds
end

-- Assign only regular eggs; special rewards and old-save fallback keep their original rules.
function HatchService.assignSpecies(egg): string?
	if egg.secret or egg.lucky then return nil end
	local biome = Config.BiomeById[egg.biome]
	if not biome then return nil end
	if type(egg.species) ~= "string" or not table.find(biome.species, egg.species) then
		egg.species = biome.species[weighted(Config.SpeciesWeights)]
	end
	return egg.species
end

-- Pure rarity roll with a persistent regular-egg species: returns { species, rarity, mutation }
-- luck (Luck Potion / Server Luck): roll rarity twice, keep the better. luckyPass + rebirthUp: one chance to go one step up.
function HatchService.roll(egg, luck: boolean?, luckyPass: boolean?, rebirthUp: number?)
	local biome = Config.BiomeById[egg.biome]
	local species = HatchService.assignSpecies(egg) or biome.species[weighted(Config.SpeciesWeights)]
	local rarityIndex
	if egg.secret then
		rarityIndex = weighted(Config.Events.secretOddsByBiome[egg.biome] or Config.Events.secretOdds) -- original biome; Epic or better
	else
		rarityIndex = weighted(RARITY_ODDS)
		if luck then
			rarityIndex = math.max(rarityIndex, weighted(RARITY_ODDS))
		end
		local up = (luckyPass and Config.LuckyPassChance or 0) + (rebirthUp or 0)
		if up > 0 and rng:NextNumber() < up then
			rarityIndex = math.min(rarityIndex + 1, 5)
		end
		if egg.lucky then
			rarityIndex = math.clamp(rarityIndex + 1, 2, 5)
		end
	end
	return { species = species, rarity = Config.Rarities[rarityIndex].id, mutation = egg.mutation }
end

-- Luck Potion / paid luck / Server Luck, whether the Lucky pass may apply (paid luck respects PolicyService), and rebirth luck
local function luckOf(player, data, now: number)
	local paidOk = player:GetAttribute("PaidLuckBlocked") == false -- set by MonetizationService from PolicyService
	local luck = (data.LuckUntil or 0) > now
		or paidOk and ((data.PaidLuckUntil or 0) > now or (workspace:GetAttribute("ServerLuckUntil") or 0) > now)
	return luck, paidOk and player:GetAttribute("LuckyPass"), Config.rebirthLuck(data.Rebirths or 0)
end

local function eggFolder(plot)
	local folder = plot:FindFirstChild("IncubatorEggs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "IncubatorEggs"
		folder.Parent = plot
	end
	return folder
end

local function render(player)
	local plot = PlotService.get(player)
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	local folder = eggFolder(plot)
	folder:ClearAllChildren()
	local incubating = 0
	for _, pad in plot.Incubators:GetChildren() do
		local slot = pad:GetAttribute("Slot")
		local egg = data.Incubators[slot]
		pad.Transparency = slot <= data.IncubatorCount and 0 or 0.7
		pad.Ring.Transparency = slot <= data.IncubatorCount and 0 or 0.8
		if egg then
			incubating += 1
			local model = CreatureBuilder.buildEgg(egg.biome, egg.mutation, egg.secret, egg.species)
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
				end
			end
			model:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 2, 0)))
			model.Name = "Egg" .. slot
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "RaidPrompt"
			prompt.ActionText = "Steal Egg"
			prompt.ObjectText = player.DisplayName .. "'s egg"
			prompt.HoldDuration = Config.Steal.baseHold
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("Owner", player.UserId) -- the owner's client hides its own prompts
			prompt.Parent = model.PrimaryPart
			prompt.Triggered:Connect(function(thief)
				if HatchService.onRaid then
					HatchService.onRaid(thief, player, slot)
				end
			end)
			model.Parent = folder
		else
			-- Empty/Locked hints are only for new (shielded) players
			pad.Timer.Text.Text = not player:GetAttribute("Shielded") and "" or slot <= data.IncubatorCount and "Empty" or "Locked"
		end
	end
	player:SetAttribute("Incubating", incubating)
end

local function freeSlot(data): number?
	for slot = 1, data.IncubatorCount do
		if not data.Incubators[slot] then
			return slot
		end
	end
	return nil
end

-- Puts an egg { biome, mutation?, secret?, lucky? } into a free incubator. false if all are full.
function HatchService.deposit(player, egg, progress: number?): boolean
	local data = DataService.get(player)
	local slot = data and freeSlot(data)
	if not slot then
		return false
	end
	HatchService.assignSpecies(egg)
	local record = { biome = egg.biome, species = egg.species, mutation = egg.mutation, secret = egg.secret, lucky = egg.lucky,
		startedAt = os.time() - (progress or 0) }
	record.result = HatchService.roll(record, luckOf(player, data, os.time())) -- decides the hatch time; shown only on hatch
	data.Incubators[slot] = record
	render(player)
	return true
end

-- Take an egg out of an incubator (raids). Hatch progress is lost.
function HatchService.takeEgg(player, slot: number)
	local data = DataService.get(player)
	local egg = data and data.Incubators[slot]
	if not egg then
		return nil
	end
	data.Incubators[slot] = false
	render(player)
	return { biome = egg.biome, species = egg.species, mutation = egg.mutation, secret = egg.secret, lucky = egg.lucky }, os.time() - egg.startedAt
end

-- slots that still have an egg (Mama's Revenge picks from these)
function HatchService.filledSlots(player)
	local data = DataService.get(player)
	local slots = {}
	for slot = 1, data and data.IncubatorCount or 0 do
		if data.Incubators[slot] then
			table.insert(slots, slot)
		end
	end
	return slots
end

-- Owner hatches a finished egg: the creature goes to the pen (or stable). false if not ready or both are full.
function HatchService.hatch(player, slot: number): boolean
	local data = DataService.get(player)
	local plot = PlotService.get(player)
	local egg = data and plot and data.Incubators[slot]
	local now = os.time()
	if not egg or now - egg.startedAt < hatchTime(egg) then
		return false
	end
	egg.result = egg.result or HatchService.roll(egg, luckOf(player, data, now)) -- older saves roll here, once
	if not CreatureService.add(player, egg.result) then
		plot.Incubators["Incubator" .. slot].Timer.Text.Text = '<font color="#ff6b6b">Pen & stable full!</font>'
		Notify:FireClient(player, "toast", "Pen and Stable are full. Make room, then hatch your egg.")
		return false
	end
	if HatchService.onHatched then HatchService.onHatched(player, egg.result) end
	Notify:FireClient(player, "hatched", egg.result, slot)
	if Config.RarityById[egg.result.rarity].index >= 5 then
		Notify:FireAllClients("toast", ('%s hatched a <font color="#%s">%s %s</font>!'):format(player.DisplayName,
			Config.RarityById[egg.result.rarity].color:ToHex(), egg.result.rarity, Config.Species[egg.result.species].display))
	end
	data.Incubators[slot] = false
	render(player)
	return true
end

-- Instant Hatch (developer product): the purchase is the owner's action, so every egg hatches now
function HatchService.instantHatch(player)
	local data = DataService.get(player)
	for slot = 1, data and data.IncubatorCount or 0 do
		local egg = data.Incubators[slot]
		if egg then
			egg.startedAt = 0
			HatchService.hatch(player, slot)
		end
	end
end

-- eggs that will be ready to hatch the moment the player is back (offline summary)
function HatchService.readyCount(player): number
	local data = DataService.get(player)
	local n = 0
	for slot = 1, data and data.IncubatorCount or 0 do
		local egg = data.Incubators[slot]
		if egg and os.time() - egg.startedAt >= hatchTime(egg) then
			n += 1
		end
	end
	return n
end

-- Queue an egg for when an incubator frees up (Mama's Revenge returns, Lucky Eggs)
function HatchService.give(player, egg, progress: number?)
	if not HatchService.deposit(player, egg, progress) then
		local data = DataService.get(player)
		HatchService.assignSpecies(egg)
		table.insert(data.PendingEggs, { biome = egg.biome, species = egg.species, mutation = egg.mutation, secret = egg.secret, lucky = egg.lucky, progress = progress or 0 })
	end
end

local function tick(player)
	local data = DataService.get(player)
	local plot = PlotService.get(player)
	if not data or not plot then
		return
	end
	local now, dirty = os.time(), false
	local folder = eggFolder(plot)
	for slot = 1, data.IncubatorCount do
		local egg = data.Incubators[slot]
		if egg then
			local left = hatchTime(egg) - (now - egg.startedAt)
			local label = plot.Incubators["Incubator" .. slot].Timer.Text
			local model = folder:FindFirstChild("Egg" .. slot)
			if left > 0 then
				label.Text = ("%d:%02d"):format(left // 60, left % 60)
			elseif model and model.PrimaryPart and not model.PrimaryPart:FindFirstChild("HatchPrompt") then
				-- ready: only the owner sees Hatch (ClientMain OnlyFor); everyone else still sees Steal Egg
				label.Text = '<font color="#ffd75a">Ready! Hatch it</font>'
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "HatchPrompt"
				prompt.ActionText = "Hatch"
				prompt.ObjectText = "Your egg"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt:SetAttribute("OnlyFor", player.UserId)
				prompt.Parent = model.PrimaryPart
				prompt.Triggered:Connect(function(who)
					if who == player then
						HatchService.hatch(player, slot)
					end
				end)
			end
		end
	end
	while #data.PendingEggs > 0 and freeSlot(data) do
		local egg = table.remove(data.PendingEggs, 1)
		HatchService.deposit(player, egg, egg.progress)
		dirty = true
	end
	if dirty then
		render(player)
	end
end

function HatchService.onPlayerReady(player)
	local data = DataService.get(player)
	for slot = 1, data.IncubatorCount do -- older saves / new incubators
		if data.Incubators[slot] == nil then
			data.Incubators[slot] = false
		end
	end
	render(player)
end

function HatchService.cleanup(player)
	local plot = PlotService.get(player)
	if plot then
		eggFolder(plot):ClearAllChildren()
		for _, pad in plot.Incubators:GetChildren() do
			pad.Timer.Text.Text = ""
			pad.Transparency = 0
			pad.Ring.Transparency = 0
		end
	end
end

function HatchService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				task.spawn(tick, player)
			end
		end
	end)
end

return HatchService
