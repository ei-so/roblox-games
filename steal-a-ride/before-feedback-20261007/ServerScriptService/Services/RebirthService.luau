-- Rebirth: needs cash + a creature from a biome. Resets cash, creatures (except mounts), pen, incubator
-- contents, saddle, gear. Keeps mounts, rebirth rewards, bought incubators/pen slots and the Index.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)
local HatchService = require(script.Parent.HatchService)
local MountService = require(script.Parent.MountService)
local ShopService = require(script.Parent.ShopService)

local Remotes = ReplicatedStorage.Remotes
local Notify = Remotes.Notify

local RebirthService = {}
RebirthService.afterRebirth = nil -- function(player), set by Main (gear sync etc.)

-- returns ok, reason
function RebirthService.check(player)
	local data = DataService.get(player)
	if not data then
		return false, nil
	end
	local need = Config.rebirth(data.Rebirths + 1)
	if not need then
		return false, "You've reached the max rebirth!"
	elseif data.Cash < need.cash then
		return false, "You need more cash to rebirth"
	end
	local index = Config.BiomeById[need.biome].index
	for _, c in data.Creatures do
		if Config.BiomeById[Config.Species[c.species].biome].index >= index then
			return true, nil
		end
	end
	return false, "You need a creature from the " .. need.biome .. " (or deeper)"
end

function RebirthService.rebirth(player): boolean
	local ok, reason = RebirthService.check(player)
	if not ok then
		if reason then
			Notify:FireClient(player, "toast", reason)
		end
		return false
	end
	local data = DataService.get(player)
	local n = data.Rebirths + 1
	local reward = Config.rebirth(n).reward
	for uid in data.Creatures do
		if not table.find(data.Mounts, uid) then
			data.Creatures[uid] = nil
		end
	end
	table.clear(data.Pen)
	table.clear(data.PendingEggs)
	for i = 1, #data.Incubators do
		data.Incubators[i] = false
	end
	data.Cash = 0
	data.SaddleLevel = 0
	data.Gear = { net = 0, trap = 0, soda = 0 }
	data.Rebirths = n
	if reward == "incubator" then
		data.IncubatorCount = math.min(Config.Plot.maxIncubators, data.IncubatorCount + 1)
	elseif reward == "pen" then
		data.PenSlots = math.min(Config.Plot.maxPen, data.PenSlots + 2)
	end
	player:SetAttribute("Cash", 0)
	player:SetAttribute("Rebirths", n)
	HatchService.onPlayerReady(player)
	MountService.apply(player)
	CreatureService.changed(player)
	ShopService.sync(player)
	if RebirthService.afterRebirth then
		RebirthService.afterRebirth(player)
	end
	DataService.save(player)
	Notify:FireClient(player, "toast", ("REBIRTH %d! Income x%.1f"):format(n, 1 + Config.RebirthIncomeStep * n))
	return true
end

function RebirthService.start()
	Remotes.Rebirth.OnServerEvent:Connect(RebirthService.rebirth)
end

return RebirthService
