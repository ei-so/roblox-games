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
local PacingService = require(Services.PacingService)
local PlazaService = require(Services.PlazaService)
local BaseService = require(Services.BaseService)
local LikeService = require(Services.LikeService)
local QuestService = require(Services.QuestService)
local FriendService = require(Services.FriendService)

CreatureService.start()
HatchService.start()
EggService.start()
GuardianService.start(EggService)
MountService.start()
AbilityService.start()
FlightService.start()
ShopService.start()
BaseService.start(ShopService)
LikeService.start()
QuestService.start()
FriendService.start()
StealService.start()
GearService.start()
EventService.start()
RebirthService.start()
RetentionService.start()
MonetizationService.start()
MamaService.start()
PlazaService.start()
EggService.onGrab = GuardianService.wake
GuardianService.canEscape = AbilityService.canEscape
GuardianService.hasLane = function(player, biomeId)
	local lane = Config.BiomeById[biomeId].lane
	return lane == nil or MountService.hasAbility(player, lane)
end
AbilityService.onPenalty = EggService.drop
EggService.allowedSpeed = SpeedService.allowed
SpeedService.carryOf = EggService.getCarried
EggService.onCarryChanged = SpeedService.carryChanged
EggService.onDeposit = function(player, egg)
	PacingService.deposited(player, egg)
	QuestService.track(player, "deposit")
end
HatchService.onHatched = function(player, creature)
	QuestService.track(player, "hatch")
	if Config.RarityById[creature.rarity].index >= 3 then QuestService.track(player, "rareHatch") end
end
CreatureService.onFused = function(player) QuestService.track(player, "fuse") end
CreatureService.onRide = MountService.equip
PlazaService.onChest = function(player) QuestService.track(player, "chest") end
StealService.onStolen = function(player) QuestService.track(player, "steal") end
LikeService.onLiked = function(player) QuestService.track(player, "like") end
DataService.onEarned = function(player, amount) QuestService.track(player, "earn", amount) end
SpeedService.start()
EggService.onOrphanDrop = function(_player, egg)
	if egg.secret and egg.secretCFrame then
		EventService.returnSecret(egg)
	else
		StealService.returnToOwner(egg)
	end
end
GearService.isShielded = StealService.shielded
BaseService.incomeOf = CreatureService.incomeOf
RebirthService.afterRebirth = function(player)
	GearService.sync(player)
	BaseService.apply(player) -- rebirth tiers upgrade the base
end
MamaService.isShielded = StealService.shielded
MamaService.weatherBusy = function() return EventService.weatherBusy end

local function syncShieldTag(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local tag = head:FindFirstChild("ShieldedTag")
	if not player:GetAttribute("Shielded") then
		if tag then tag:Destroy() end
		return
	end
	if tag then return end
	tag = Instance.new("BillboardGui")
	tag.Name = "ShieldedTag"
	tag.Size = UDim2.fromScale(8, 1.1)
	tag.StudsOffset = Vector3.new(0, player:GetAttribute("OG") and 4.4 or 3.2, 0)
	tag.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "Shielded (new player)"
	label.TextColor3 = Color3.fromRGB(143, 211, 255)
	label.TextStrokeTransparency = 0.2
	label.Parent = tag
	tag.Parent = head
end

local function onCharacter(player, character)
	character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
	PlotService.spawn(player, character)
	if player:GetAttribute("OG") then
		local tag = Instance.new("BillboardGui")
		tag.Name = "OGTag"
		tag.Size = UDim2.fromScale(2.4, 0.9)
		tag.StudsOffset = Vector3.new(0, 3.2, 0)
		tag.MaxDistance = 80
		-- "corrupted" look from the buggy pre-reset build: red/cyan ghost copies + scanlines; OGGlitch (client) animates it
		for i, layer in { { "Red", Color3.fromRGB(255, 42, 79) }, { "Cyan", Color3.fromRGB(37, 232, 255) }, { "Main", Color3.new(1, 1, 1) } } do
			local label = Instance.new("TextLabel")
			label.Name = layer[1]
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.Text = "OG"
			label.TextColor3 = layer[2]
			label.TextTransparency = i < 3 and 0.2 or 0
			label.TextStrokeTransparency = i < 3 and 1 or 0.1
			label.ZIndex = i
			label.Parent = tag
		end
		for y = 0.3, 0.8, 0.25 do
			local line = Instance.new("Frame")
			line.Position = UDim2.fromScale(0.15, y)
			line.Size = UDim2.fromScale(0.7, 0.05)
			line.BackgroundColor3 = Color3.new(0, 0, 0)
			line.BackgroundTransparency = 0.75
			line.BorderSizePixel = 0
			line.ZIndex = 4
			line.Parent = tag
		end
		tag.Parent = character:WaitForChild("Head")
	end
	character:WaitForChild("Head")
	syncShieldTag(player)
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
	player:SetAttribute("OG", data.OG)
	PacingService.onPlayerReady(player) -- before anything adds playtime, so brand-new saves are recognised
	PlotService.assign(player)
	BaseService.apply(player)
	LikeService.sync(player)
	ShopService.sync(player)
	GearService.sync(player)
	CreatureService.changed(player)
	QuestService.sync(player)
	HatchService.onPlayerReady(player)
	StealService.onPlayerReady(player)
	MonetizationService.onPlayerReady(player) -- before the offline summary, so VIP counts
	MountService.trim(player) -- after the pass check, so Extra Mount owners keep their second mount
	RetentionService.onPlayerReady(player, lastOnline)
	FriendService.onPlayerReady(player) -- after offline cash: current friends cannot boost time spent away
	PlazaService.onPlayerReady(player)
	if data.LegacyGift then -- once, for players who played before the reset
		HatchService.give(player, { biome = Config.Biomes[data.LegacyGift].id, lucky = true })
		DataService.addCash(player, Config.LegacyGiftCash)
		data.LegacyGift = false
		task.delay(5, function() -- let the client UI load first
			game.ReplicatedStorage.Remotes.Notify:FireClient(player, "toast",
				("Welcome back, OG! Thanks for playing before the reset: a Lucky Egg + $%d"):format(Config.LegacyGiftCash))
		end)
	end
	player:GetAttributeChangedSignal("Shielded"):Connect(function()
		syncShieldTag(player)
		if DataService.get(player) then HatchService.onPlayerReady(player) end -- show/hide Empty/Locked pad hints
	end)
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
	PlazaService.onPlayerLeaving(player)
	CreatureService.cleanup(player)
	HatchService.cleanup(player)
	BaseService.reset(player)
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
			return RebirthService.rebirth(player, (...))
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
