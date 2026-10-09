-- Server events: weather every 10 min (mutates grabbed eggs; Blood Moon speeds up guardians)
-- and a Secret Egg every 5 min somewhere from the Desert onward.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local EggService = require(script.Parent.EggService)
local GuardianService = require(script.Parent.GuardianService)

local Notify = ReplicatedStorage.Remotes.Notify
local rng = Random.new()

local EventService = {}
EventService.weatherBusy = false -- Mama's Revenge waits for weather to end

local WEATHERS = {}
for mutation, m in Config.Mutations do
	WEATHERS[m.event] = mutation
end
local NAMES = { Thunderstorm = "THUNDERSTORM", GoldenHour = "GOLDEN HOUR", BloodMoon = "BLOOD MOON" }

EggService.rollMutation = function(_biomeId)
	local weather = workspace:GetAttribute("Weather")
	local mutation = weather and WEATHERS[weather]
	if mutation and rng:NextNumber() < Config.Mutations[mutation].chance then
		return mutation
	end
	return nil
end

function EventService.startWeather(name: string?)
	if not name then
		local list = {}
		for event in WEATHERS do
			table.insert(list, event)
		end
		table.sort(list)
		name = list[rng:NextInteger(1, #list)]
	end
	EventService.weatherBusy = true
	workspace:SetAttribute("Weather", name)
	workspace:SetAttribute("WeatherEnds", os.time() + Config.Events.weatherDuration)
	GuardianService.speedMultiplier = name == "BloodMoon" and Config.Guardian.bloodMoonMult or 1
	Notify:FireAllClients("toast", NAMES[name] .. "! Eggs grabbed now can mutate.")
	task.delay(Config.Events.weatherDuration, function()
		if workspace:GetAttribute("Weather") == name then
			workspace:SetAttribute("Weather", nil)
			workspace:SetAttribute("WeatherEnds", nil)
			GuardianService.speedMultiplier = 1
			EventService.weatherBusy = false
		end
	end)
end

local secretModel
function EventService.spawnSecret(biomeId: string?)
	if secretModel and secretModel.Parent then
		secretModel:Destroy()
	end
	biomeId = biomeId or Config.Biomes[rng:NextInteger(3, #Config.Biomes)].id
	local m = workspace.Biomes[biomeId]
	-- somewhere on the floor that isn't inside a prop or an escape patch
	local blockers = OverlapParams.new()
	blockers.FilterType = Enum.RaycastFilterType.Include
	blockers.FilterDescendantsInstances = { m:FindFirstChild("Props"), m:FindFirstChild("Patches") }
	blockers.RespectCanCollide = false
	local pos
	for _ = 1, 30 do
		pos = Vector3.new(rng:NextNumber(-100, 100), 2.5, rng:NextNumber(m:GetAttribute("FarZ") + 20, m:GetAttribute("EntranceZ") - 20))
		if #workspace:GetPartBoundsInRadius(pos, 5, blockers) == 0 then
			break
		end
	end
	local egg = { biome = biomeId, secret = true, secretCFrame = CFrame.new(pos) }
	secretModel = EggService.spawnLoose(egg, egg.secretCFrame, "Steal Secret Egg")
	-- rainbow beacon visible across the map
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Anchored, beacon.CanCollide, beacon.CanQuery, beacon.CanTouch = true, false, false, false
	beacon.Size = Vector3.new(3, 400, 3)
	beacon.Position = pos + Vector3.new(0, 200, 0)
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(255, 120, 220)
	beacon.Transparency = 0.45
	beacon.Parent = secretModel
	workspace:SetAttribute("SecretEgg", biomeId)
	Notify:FireAllClients("toast", "A SECRET EGG appeared in the " .. biomeId .. "!")
	return secretModel
end

-- a dropped Secret Egg goes back to where it was lying
function EventService.returnSecret(egg)
	if egg.secretCFrame then
		secretModel = EggService.spawnLoose(egg, egg.secretCFrame, "Steal Secret Egg")
	end
end

function EventService.start()
	task.spawn(function()
		while true do
			task.wait(Config.Events.secretEggInterval)
			EventService.spawnSecret()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Events.weatherInterval)
			EventService.startWeather()
		end
	end)
end

return EventService
