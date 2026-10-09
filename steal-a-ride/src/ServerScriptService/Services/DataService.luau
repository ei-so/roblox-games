-- Loads and saves player data. If a load fails, that player is NEVER saved this session,
-- so a DataStore outage can't overwrite real progress with a fresh save.
local DataStoreService = game:GetService("DataStoreService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local DataService = {}
DataService.onEarned = nil -- set by Main, successful cash gains except quest payouts

local store -- resolved lazily; GetDataStore errors in unpublished places
local profiles = {} -- [player] = { data, loadFailed, sessionMark }

local function defaults()
	return {
		Cash = 0, Rebirths = 0, PlaytimeSeconds = 0, LastOnline = 0,
		Creatures = {}, -- [uid] = { species, rarity, mutation }
		Pen = {}, Mounts = {},
		Incubators = { false, false }, -- { biome, mutation, secret, lucky, startedAt } or false
		PendingEggs = {}, -- eggs waiting for a free incubator
		IncubatorCount = Config.Plot.startIncubators, PenSlots = Config.Plot.startPen, SaddleLevel = 0,
		Gear = { net = 0, trap = 0, soda = 0 },
		Index = {}, -- ["Fox_Rare"] = true
		DailyStreak = 0, LastDaily = 0,
		LuckUntil = 0, -- free luck (day-7 daily reward)
		PaidLuckUntil = 0, -- Luck Potion (paid; off where paid random items are restricted)
		PassesApplied = {}, -- one-time pass rewards already granted (Incubators, PenSlots)
		Receipts = {}, -- processed developer-product purchase ids (idempotent ProcessReceipt)
		Tips = {}, -- ["mama"] = true: tutorial steps done / tips already shown
		LastChest = 0, -- os.time() the Plaza reward chest was last opened
		Likes = 0, LikesGiven = {}, -- total received; [ownerId string] = last UTC day liked
		Quests = {}, -- current UTC daily and Monday weekly assignments
		Base = { owned = {}, equipped = {} }, -- base cosmetics: owned[itemId] = true, equipped[slot] = itemId (kept through rebirth)
		LegacyChecked = false, OG = false, -- OG = had a save in the pre-reset store
		LegacyGift = false, -- best old biome index, waiting to be granted once (Main)
	}
end

-- Fill keys missing from an older save. Never overwrites existing values.
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
	return data
end

local function getStore()
	store = store or DataStoreService:GetDataStore(Config.DataStoreName)
	return store
end

local function keyFor(player)
	return "u_" .. player.UserId
end

-- Looks for a pre-reset save once. A failed read is retried next join, so nobody misses the gift.
local function checkLegacy(player, data)
	local ok, old = pcall(function()
		return DataStoreService:GetDataStore(Config.LegacyDataStoreName):GetAsync(keyFor(player))
	end)
	if not ok then
		warn("[DataService] legacy check failed for " .. player.Name .. ": " .. tostring(old))
		return
	end
	data.LegacyChecked = true
	if type(old) == "table" then
		local best = 1
		for _, c in type(old.Creatures) == "table" and old.Creatures or {} do
			local species = type(c) == "table" and Config.Species[c.species]
			local biome = species and Config.BiomeById[species.biome]
			best = biome and math.max(best, biome.index) or best
		end
		data.OG, data.LegacyGift = true, best
	end
end

function DataService.load(player)
	local saved, ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			saved = getStore():GetAsync(keyFor(player))
		end)
		if ok then
			break
		end
		warn(("[DataService] load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	local profile = {
		data = reconcile(ok and type(saved) == "table" and saved or {}, defaults()),
		loadFailed = not ok,
		sessionMark = os.time(),
	}
	if ok and not profile.data.LegacyChecked then
		checkLegacy(player, profile.data)
	end
	profiles[player] = profile
	player:SetAttribute("DataLoadFailed", profile.loadFailed)
	return profile.data
end

function DataService.get(player)
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.save(player): boolean
	local profile = profiles[player]
	if not profile or profile.loadFailed then
		return false
	end
	local data = profile.data
	local now = os.time()
	data.PlaytimeSeconds += now - profile.sessionMark
	profile.sessionMark = now
	data.LastOnline = now
	-- ponytail: no session locking; add it if players hop servers fast enough to race saves
	local ok, err = pcall(function()
		getStore():UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[DataService] save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

-- Saves everyone in parallel and waits (for BindToClose).
function DataService.saveAll()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			DataService.save(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

-- total playtime across sessions (for the new-player shield)
function DataService.playtime(player): number
	local profile = profiles[player]
	return profile and (profile.data.PlaytimeSeconds + os.time() - profile.sessionMark) or 0
end

function DataService.addCash(player, amount: number, skipEarned: boolean?)
	local data = DataService.get(player)
	if data then
		data.Cash += amount
		player:SetAttribute("Cash", data.Cash)
		if amount > 0 and not skipEarned and DataService.onEarned then DataService.onEarned(player, amount) end
	end
end

function DataService.release(player)
	profiles[player] = nil
end

function DataService._setStore(fake) -- tests only
	store = fake
end

-- tests only (Studio TestHooks): delete this player's save and stop saving them this session,
-- so leaving can't write the in-memory test data back
function DataService._deleteSave(player): boolean
	local profile = profiles[player]
	if profile then
		profile.loadFailed = true
	end
	return (pcall(function()
		getStore():RemoveAsync(keyFor(player))
	end))
end

return DataService
