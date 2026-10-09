-- Incubators: eggs hatch on os.time() timers (so they keep hatching offline), then roll species + rarity.
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
HatchService.onRaid = nil -- function(thief, owner, slot), set by Main (StealService)

local function hatchTime(egg): number
	if egg.lucky then
		return Config.Events.luckyHatch
	elseif egg.secret then
		return Config.Events.secretHatch
	end
	return Config.BiomeById[egg.biome].hatchTime
end

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

-- Pure roll so it can be tested: returns { species, rarity, mutation }
-- luck (Luck Potion / Server Luck): roll rarity twice, keep the better. luckyPass: 10% of rolls go one step up.
function HatchService.roll(egg, luck: boolean?, luckyPass: boolean?)
	local biome = Config.BiomeById[egg.biome]
	local species = biome.species[weighted(Config.SpeciesWeights)]
	local rarityIndex
	if egg.secret then
		rarityIndex = weighted(Config.Events.secretOdds) -- Epic or better, sometimes Mythic
	else
		rarityIndex = weighted(RARITY_ODDS)
		if luck then
			rarityIndex = math.max(rarityIndex, weighted(RARITY_ODDS))
		end
		if luckyPass and rng:NextNumber() < Config.LuckyPassChance then
			rarityIndex = math.min(rarityIndex + 1, 5)
		end
		if egg.lucky then
			rarityIndex = math.clamp(rarityIndex + 1, 2, 5)
		end
	end
	return { species = species, rarity = Config.Rarities[rarityIndex].id, mutation = egg.mutation }
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
			local model = CreatureBuilder.buildEgg(egg.biome, egg.mutation, egg.secret)
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
			pad.Timer.Text.Text = slot <= data.IncubatorCount and "Empty" or "Locked"
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
	data.Incubators[slot] = { biome = egg.biome, mutation = egg.mutation, secret = egg.secret, lucky = egg.lucky,
		startedAt = os.time() - (progress or 0) }
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
	return { biome = egg.biome, mutation = egg.mutation, secret = egg.secret, lucky = egg.lucky }, os.time() - egg.startedAt
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

-- Instant Hatch (developer product): every egg finishes on the next tick
function HatchService.instantHatch(player)
	local data = DataService.get(player)
	for slot = 1, data and data.IncubatorCount or 0 do
		local egg = data.Incubators[slot]
		if egg then
			egg.startedAt = 0
		end
	end
end

-- eggs that will be ready the moment the player is back (offline summary)
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
		table.insert(data.PendingEggs, { biome = egg.biome, mutation = egg.mutation, secret = egg.secret, lucky = egg.lucky, progress = progress or 0 })
	end
end

local function tick(player)
	local data = DataService.get(player)
	local plot = PlotService.get(player)
	if not data or not plot then
		return
	end
	local now, dirty = os.time(), false
	for slot = 1, data.IncubatorCount do
		local egg = data.Incubators[slot]
		if egg then
			local left = hatchTime(egg) - (now - egg.startedAt)
			local label = plot.Incubators["Incubator" .. slot].Timer.Text
			if left > 0 then
				label.Text = ("%d:%02d"):format(left // 60, left % 60)
			else
				local paidOk = player:GetAttribute("PaidLuckBlocked") == false -- set by MonetizationService from PolicyService
				local luck = (data.LuckUntil or 0) > now
					or paidOk and ((data.PaidLuckUntil or 0) > now or (workspace:GetAttribute("ServerLuckUntil") or 0) > now)
				egg.result = egg.result or HatchService.roll(egg, luck, paidOk and player:GetAttribute("LuckyPass")) -- roll once, even if it waits for room
				if CreatureService.add(player, egg.result) then
					Notify:FireClient(player, "hatched", egg.result, slot)
					if Config.RarityById[egg.result.rarity].index >= 5 then
						Notify:FireAllClients("toast", ('%s hatched a <font color="#%s">%s %s</font>!'):format(player.DisplayName,
							Config.RarityById[egg.result.rarity].color:ToHex(), egg.result.rarity, Config.Species[egg.result.species].display))
					end
					data.Incubators[slot] = false
					dirty = true
				else
					label.Text = '<font color="#ff6b6b">Pen & stable full!</font>'
				end
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
