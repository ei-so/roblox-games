-- Server entry point: starts the services and wires the player lifecycle to them.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local rigModule = game.ReplicatedStorage.Shared:FindFirstChild("CreatureRig")
if rigModule then
	local ok, err = pcall(function() require(rigModule).install() end)
	if not ok then warn("[CreatureRig] Using original models: " .. tostring(err)) end
else
	warn("[CreatureRig] Module missing; using original models")
end
local Services = script.Parent:WaitForChild("Services")
local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local SpeedService = require(Services.SpeedService)
local CreatureService = require(Services.CreatureService)
local HatchService = require(Services.HatchService)
local EggService = require(Services.EggService)
local GuardianService = require(Services.GuardianService)
local MountService = require(Services.MountService)
local AbilityService = require(Services.AbilityService)
local FlightService = require(Services.FlightService)
local ShopService = require(Services.ShopService)
local StealService = require(Services.StealService)
local GearService = require(Services.GearService)
local EventService = require(Services.EventService)
local RebirthService = require(Services.RebirthService)
local RetentionService = require(Services.RetentionService)
local MonetizationService = require(Services.MonetizationService)
local MamaService = require(Services.MamaService)

CreatureService.start()
HatchService.start()
EggService.start()
GuardianService.start(EggService)
MountService.start()
AbilityService.start()
FlightService.start()
ShopService.start()
StealService.start()
GearService.start()
EventService.start()
RebirthService.start()
RetentionService.start()
MonetizationService.start()
MamaService.start()
EggService.onGrab = GuardianService.wake
GuardianService.canEscape = AbilityService.canEscape
GuardianService.hasLane = function(player, biomeId)
	local lane = Config.BiomeById[biomeId].lane
	return lane == nil or MountService.hasAbility(player, lane)
end
AbilityService.onPenalty = EggService.drop
EggService.allowedSpeed = SpeedService.allowed
EggService.onOrphanDrop = function(_player, egg)
	if egg.secret and egg.secretCFrame then
		EventService.returnSecret(egg)
	else
		StealService.returnToOwner(egg)
	end
end
GearService.isShielded = StealService.shielded
RebirthService.afterRebirth = GearService.sync
MamaService.isShielded = StealService.shielded
MamaService.weatherBusy = function() return EventService.weatherBusy end

local function onCharacter(player, character)
	character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
	PlotService.spawn(player, character)
	task.wait(0.1) -- let the spawn teleport land before the mount is welded on
	MountService.apply(player)
end

local function onPlayerAdded(player)
	local data = DataService.load(player)
	if not player.Parent then -- left while loading
		DataService.release(player)
		return
	end
	local lastOnline = data.LastOnline -- read before the first save overwrites it
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("CashPerSecond", 0)
	player:SetAttribute("Rebirths", data.Rebirths)
	PlotService.assign(player)
	ShopService.sync(player)
	GearService.sync(player)
	CreatureService.changed(player)
	HatchService.onPlayerReady(player)
	StealService.onPlayerReady(player)
	MonetizationService.onPlayerReady(player) -- before the offline summary, so VIP counts
	MountService.trim(player) -- after the pass check, so Extra Mount owners keep their second mount
	RetentionService.onPlayerReady(player, lastOnline)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	EggService.drop(player)
	DataService.save(player)
	CreatureService.cleanup(player)
	HatchService.cleanup(player)
	PlotService.release(player)
	SpeedService.release(player)
	DataService.release(player)
end)

game:BindToClose(function()
	DataService.saveAll()
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.save, player)
		end
	end
end)

-- Studio-only hooks so automated tests can drive the real services (never exists in live servers)
if RunService:IsStudio() then
	local hooks = Instance.new("BindableFunction")
	hooks.Name = "TestHooks"
	hooks.OnInvoke = function(action, ...)
		local player = Players:GetPlayers()[1]
		local data = DataService.get(player)
		if action == "give" then
			local species, rarity, mutation = ...
			return CreatureService.add(player, { species = species, rarity = rarity or "Common", mutation = mutation })
		elseif action == "mount" then
			return MountService.equip(player, (...))
		elseif action == "dismountAll" then
			while #data.Mounts > 0 do
				table.remove(data.Mounts, 1)
			end
			MountService.apply(player)
			CreatureService.changed(player)
			return true
		elseif action == "grab" then -- attach a biome egg as if grabbed, and wake that guardian
			local biome = ...
			local ok = EggService.attach(player, { biome = biome, secret = false })
			GuardianService.wake(player, biome)
			return ok
		elseif action == "cash" then
			DataService.addCash(player, (...))
			return data.Cash
		elseif action == "wipe" then -- clear creatures/eggs/upgrades for a clean test
			for k in data.Creatures do data.Creatures[k] = nil end
			table.clear(data.Pen); table.clear(data.Mounts); table.clear(data.PendingEggs)
			for i = 1, #data.Incubators do data.Incubators[i] = false end
			data.SaddleLevel = 0
			MountService.apply(player); CreatureService.changed(player); HatchService.onPlayerReady(player); ShopService.sync(player)
			return true
		elseif action == "canEscape" then
			return AbilityService.canEscape(player, (...))
		elseif action == "guardian" then
			return GuardianService.state((...))
		elseif action == "weather" then
			EventService.startWeather((...))
			return workspace:GetAttribute("Weather")
		elseif action == "secret" then
			return EventService.spawnSecret((...)) ~= nil
		elseif action == "rebirth" then
			return RebirthService.rebirth(player)
		elseif action == "setPlaytime" then
			data.PlaytimeSeconds = (...)
			return DataService.playtime(player)
		elseif action == "buy" then
			return ShopService.buy(player, (...))
		elseif action == "carrying" then
			local egg = EggService.getCarried(player)
			return egg and game:GetService("HttpService"):JSONEncode({ biome = egg.biome, species = egg.species, mutation = egg.mutation, secret = egg.secret })
		elseif action == "incubators" then -- saved incubator + queued eggs, to check species survive moves
			return game:GetService("HttpService"):JSONEncode({ incubators = data.Incubators, pending = data.PendingEggs })
		elseif action == "save" then
			return DataService.save(player)
		elseif action == "mutationRolls" then
			local counts = {}
			for _ = 1, (...) do
				local m = EggService.rollMutation("Forest") or "none"
				counts[m] = (counts[m] or 0) + 1
			end
			return game:GetService("HttpService"):JSONEncode(counts)
		elseif action == "mama" then -- start Mama now; opts { warning, duration }
			task.spawn(MamaService.run, (...))
			return true
		elseif action == "mamaDamage" then
			MamaService.damage(player, (...))
			return workspace:GetAttribute("MamaHP")
		elseif action == "fillIncubators" then -- every unlocked incubator gets an egg of this biome
			local n = 0
			while HatchService.deposit(player, { biome = (...) }) do n += 1 end
			return n
		elseif action == "setIncubators" then
			data.IncubatorCount = (...)
			HatchService.onPlayerReady(player)
			return true
		elseif action == "hatchRolls" then -- rarity/species counts over n rolls of a biome egg
			local biome, n, luck = ...
			local counts = {}
			for _ = 1, n do
				local r = HatchService.roll({ biome = biome }, luck)
				counts[r.rarity] = (counts[r.rarity] or 0) + 1
				counts[r.species] = (counts[r.species] or 0) + 1
			end
			return game:GetService("HttpService"):JSONEncode(counts)
		elseif action == "offline" then -- pretend the player was away for n seconds
			RetentionService.onPlayerReady(player, os.time() - (...))
			return data.Cash
		elseif action == "setDaily" then -- streak, seconds since last claim
			local streak, ago = ...
			data.DailyStreak, data.LastDaily = streak, ago and os.time() - ago or 0
			RetentionService.sync(player)
			return player:GetAttribute("DailyDay")
		elseif action == "receipt" then -- fake a developer-product receipt: (productKey, purchaseId)
			local key, purchaseId = ...
			local product = require(game.ReplicatedStorage.Shared.Config).Monetization.products[key]
			local old = product.id
			product.id = 999
			local result = MonetizationService.processReceipt({ PlayerId = player.UserId, ProductId = 999, PurchaseId = purchaseId })
			product.id = old
			return result.Name
		elseif action == "deleteSave" then -- reset to a brand-new player on next join
			return DataService._deleteSave(player)
		elseif action == "json" then
			return game:GetService("HttpService"):JSONEncode(data)
		end
	end
	hooks.Parent = game:GetService("ServerStorage")
end
