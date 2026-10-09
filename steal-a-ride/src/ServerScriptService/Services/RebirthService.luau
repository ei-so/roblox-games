-- Rebirth: needs cash (+ a keep fee for the picked creatures) + a creature from a biome. Resets cash, creatures (except the ones picked to keep), pen,
-- incubator contents, saddle, gear. Keeps picked creatures, rebirth rewards, bought incubators/pen slots and the Index.
-- An incubator/pen reward that is already maxed becomes a Lucky Egg.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
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

-- uids to keep: the client's pick (owned, unique, at most the limit), or the ridden ones when none is sent
local function keepSet(data, n, picked)
	local limit, keep, count = Config.rebirthKeep(n), {}, 0
	if type(picked) ~= "table" then
		picked = data.Mounts
	elseif #picked > limit then
		return nil
	end
	for _, uid in picked do
		if count < limit and type(uid) == "string" and data.Creatures[uid] and not keep[uid] then
			keep[uid] = true
			count += 1
		end
	end
	return keep
end

function RebirthService.rebirth(player, picked): boolean
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
	local keep = keepSet(data, n, picked)
	if not keep then
		Notify:FireClient(player, "toast", ("You can keep %d creatures"):format(Config.rebirthKeep(n)))
		return false
	end
	local kept = {}
	for uid in keep do
		table.insert(kept, data.Creatures[uid])
	end
	local fee = Config.rebirthKeepFee(kept, n, data.Index)
	if data.Cash < Config.rebirth(n).cash + fee then
		Notify:FireClient(player, "toast", ("Keeping these creatures costs $%s more"):format(Format.number(fee)))
		return false
	end
	local best = player:GetAttribute("BestBiome") or 0 -- before the reset, for a Lucky Egg
	for uid in data.Creatures do
		if not keep[uid] then
			data.Creatures[uid] = nil
		end
	end
	for i = #data.Mounts, 1, -1 do
		if not keep[data.Mounts[i]] then
			table.remove(data.Mounts, i)
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
	local maxed = false
	if reward == "incubator" then
		maxed = data.IncubatorCount >= Config.Plot.maxIncubators
		data.IncubatorCount = math.min(Config.Plot.maxIncubators, data.IncubatorCount + 1)
	elseif reward == "pen" then
		maxed = data.PenSlots >= Config.Plot.maxPen
		data.PenSlots = math.min(Config.Plot.maxPen, data.PenSlots + 2)
	end
	local luckyEgg = maxed or reward == "lucky" -- "mount" and "luck" are derived from data.Rebirths
	player:SetAttribute("Cash", 0)
	player:SetAttribute("Rebirths", n)
	HatchService.onPlayerReady(player)
	if luckyEgg then
		HatchService.give(player, { biome = Config.Biomes[math.max(1, best)].id, lucky = true })
	end
	MountService.apply(player)
	CreatureService.changed(player)
	ShopService.sync(player)
	if RebirthService.afterRebirth then
		RebirthService.afterRebirth(player)
	end
	DataService.save(player)
	local extra = (reward == "lucky" and " + a Lucky Egg") or (maxed and " + a Lucky Egg (already maxed)")
		or (reward == "luck" and (" + %d%% of hatches roll a rarity higher"):format(math.round(Config.rebirthLuck(n) * 100)))
		or (reward == "mount" and " + a 2nd mount slot") or ""
	Notify:FireClient(player, "toast", ("REBIRTH %d! Income x%.1f%s"):format(n, 1 + Config.RebirthIncomeStep * n, extra))
	local title = Config.rebirthTitle(n)
	if title and title ~= Config.rebirthTitle(n - 1) then
		Notify:FireClient(player, "toast", ("You are now %s %s!"):format(title:match("^[AEIOU]") and "an" or "a", title))
	end
	return true
end

function RebirthService.start()
	Remotes.Rebirth.OnServerEvent:Connect(RebirthService.rebirth)
end

return RebirthService
