-- All tuning numbers for Steal a Mount (formerly Steal a Ride) (see steal-a-ride.md). Change balance here, nowhere else.
local rgb = Color3.fromRGB

local Config = {}

Config.WalkSpeed = 16
Config.DataStoreName = "StealARide_v1"

-- Biomes in road order. minEscape = slowest speed that escapes on the main road (from the chase calc).
Config.Biomes = {
	{ id = "Forest", guardian = "Chicken", guardianSpeed = 14, depth = 140, minEscape = 11.6, mountBase = 18,
		lane = nil, hatchTime = 10, baseIncome = 5, species = { "Chick", "Bunny", "Fox" },
		look = { floor = rgb(86, 160, 72), material = Enum.Material.Grass, accent = rgb(120, 230, 90),
			tint = rgb(240, 255, 240), atmosphere = rgb(199, 230, 199), density = 0.3, haze = 1 } },
	{ id = "Lake", guardian = "Swan", guardianSpeed = 20, depth = 200, minEscape = 16.9, mountBase = 23,
		lane = "Swim", hatchTime = 20, baseIncome = 30, species = { "Duckling", "Frog", "Otter" },
		look = { floor = rgb(214, 200, 150), material = Enum.Material.Sand, accent = rgb(90, 190, 255),
			tint = rgb(235, 245, 255), atmosphere = rgb(190, 220, 240), density = 0.3, haze = 1 } },
	{ id = "Desert", guardian = "Scorpion", guardianSpeed = 26, depth = 260, minEscape = 22.2, mountBase = 29,
		lane = "Jump", hatchTime = 30, baseIncome = 150, species = { "Scarab", "Lizard", "Vulture" },
		look = { floor = rgb(226, 186, 120), material = Enum.Material.Sandstone, accent = rgb(255, 170, 60),
			tint = rgb(255, 240, 215), atmosphere = rgb(240, 215, 170), density = 0.35, haze = 2 } },
	{ id = "Jungle", guardian = "Tiger", guardianSpeed = 33, depth = 330, minEscape = 28.4, mountBase = 35,
		lane = "Swim", hatchTime = 45, baseIncome = 800, species = { "Monkey", "Parrot", "Panther" },
		look = { floor = rgb(52, 120, 58), material = Enum.Material.LeafyGrass, accent = rgb(60, 220, 120),
			tint = rgb(225, 255, 225), atmosphere = rgb(150, 200, 150), density = 0.45, haze = 1.5 } },
	{ id = "Tundra", guardian = "Yeti", guardianSpeed = 40, depth = 400, minEscape = 34.6, mountBase = 42,
		lane = "Glide", hatchTime = 60, baseIncome = 4000, species = { "Penguin", "SnowOwl", "Mammoth" },
		look = { floor = rgb(236, 242, 250), material = Enum.Material.Snow, accent = rgb(170, 230, 255),
			tint = rgb(230, 240, 255), atmosphere = rgb(220, 235, 255), density = 0.4, haze = 1 } },
	{ id = "Volcano", guardian = "Hellhound", guardianSpeed = 48, depth = 480, minEscape = 41.6, mountBase = 51,
		lane = "Fireproof", hatchTime = 90, baseIncome = 20000, species = { "Salamander", "EmberBat", "Hellpup" },
		look = { floor = rgb(64, 48, 46), material = Enum.Material.Basalt, accent = rgb(255, 90, 40),
			tint = rgb(255, 220, 200), atmosphere = rgb(120, 60, 50), density = 0.5, haze = 2 } },
	{ id = "Cosmic", guardian = "Dragon", guardianSpeed = 58, depth = 580, minEscape = 50.4, mountBase = 60,
		lane = "Phase", hatchTime = 120, baseIncome = 100000, species = { "StarJelly", "CometFox", "BabyDragon" },
		look = { floor = rgb(30, 24, 60), material = Enum.Material.Glass, accent = rgb(190, 110, 255),
			tint = rgb(225, 215, 255), atmosphere = rgb(60, 40, 110), density = 0.45, haze = 1 } },
}
Config.HomeLook = { tint = rgb(255, 255, 255), atmosphere = rgb(200, 220, 240), density = 0.25, haze = 0 }

Config.BiomeById = {}
for i, biome in Config.Biomes do
	biome.index = i
	Config.BiomeById[biome.id] = biome
end

-- Hatch weight of a biome's 1st / 2nd / 3rd species
Config.SpeciesWeights = { 50, 35, 15 }
Config.NoAbilitySpeedBonus = 2

-- Species build recipes for CreatureBuilder.
-- features: "name" or "name:style". legs: 0, 2 or 4. head = false puts the eyes on the body.
Config.Species = {
	-- Forest
	Chick = { display = "Chick", ability = nil, shape = "Ball", size = 0.8, body = rgb(255, 221, 64), accent = rgb(255, 140, 30),
		head = false, legs = 2, features = { "beak", "wings:small" } },
	Bunny = { display = "Bunny", ability = "Jump", shape = "Ball", size = 0.9, body = rgb(245, 245, 245), accent = rgb(255, 170, 190),
		legs = 4, features = { "ears:long", "tail:puff", "nose" } },
	Fox = { display = "Fox", ability = "Dash", shape = "Block", size = 1, body = rgb(235, 120, 40), accent = rgb(250, 245, 235),
		legs = 4, features = { "ears:pointy", "muzzle", "tail:bushy" } },
	-- Lake
	Duckling = { display = "Duckling", ability = "Swim", shape = "Ball", size = 0.85, body = rgb(255, 236, 140), accent = rgb(255, 150, 40),
		legs = 2, features = { "beak:flat", "wings:small" } },
	Frog = { display = "Frog", ability = "Jump", shape = "Squat", size = 0.95, body = rgb(90, 200, 80), accent = rgb(200, 240, 140),
		head = false, legs = 4, features = { "bigEyes", "belly" } },
	Otter = { display = "Otter", ability = "Swim", shape = "Block", size = 1, body = rgb(125, 85, 55), accent = rgb(215, 185, 145),
		legs = 4, features = { "ears:small", "muzzle", "tail:flat" } },
	-- Desert
	Scarab = { display = "Scarab", ability = nil, shape = "Ball", size = 0.9, body = rgb(30, 110, 110), accent = rgb(240, 190, 60),
		headSize = 0.7, legs = 4, features = { "shell", "horns:single" } },
	Lizard = { display = "Lizard", ability = "Dash", shape = "Block", size = 1, body = rgb(215, 165, 85), accent = rgb(90, 160, 70),
		legs = 4, features = { "spikes", "tail:long" } },
	Vulture = { display = "Vulture", ability = "Glide", shape = "Ball", size = 1.05, body = rgb(85, 60, 45), accent = rgb(230, 200, 150),
		headColor = rgb(225, 140, 140), headSize = 0.8, legs = 2, features = { "wings:big", "beak:hooked" } },
	-- Jungle
	Monkey = { display = "Monkey", ability = "Jump", shape = "Ball", size = 1, body = rgb(120, 75, 40), accent = rgb(230, 190, 140),
		legs = 4, features = { "ears:round", "muzzle", "tail:curly" } },
	Parrot = { display = "Parrot", ability = "Glide", shape = "Ball", size = 0.95, body = rgb(225, 40, 45), accent = rgb(40, 120, 230),
		footColor = rgb(110, 110, 120), legs = 2, features = { "wings", "beak:yellow", "tail:feather" } },
	Panther = { display = "Panther", ability = "Dash", shape = "Block", size = 1.1, body = rgb(28, 28, 34), accent = rgb(70, 70, 85),
		eyeColor = rgb(255, 210, 40), legs = 4, features = { "ears:pointy", "tail:long" } },
	-- Tundra
	Penguin = { display = "Penguin", ability = "Swim", shape = "Ball", size = 0.95, body = rgb(30, 32, 45), accent = rgb(255, 150, 40),
		headColor = rgb(30, 32, 45), bellyColor = rgb(250, 250, 250), legs = 2, features = { "belly", "beak", "wings:flippers" } },
	SnowOwl = { display = "Snow Owl", ability = "Glide", shape = "Ball", size = 0.95, body = rgb(245, 248, 255), accent = rgb(255, 200, 60),
		eyeColor = rgb(255, 200, 40), legs = 2, features = { "ears:tufts", "beak", "wings" } },
	Mammoth = { display = "Mammoth", ability = nil, shape = "Block", size = 1.35, body = rgb(110, 70, 45), accent = rgb(245, 235, 210),
		legs = 4, features = { "ears:floppy", "horns:tusks", "trunk" } },
	-- Volcano
	Salamander = { display = "Salamander", ability = "Fireproof", shape = "Block", size = 1, body = rgb(230, 70, 30), accent = rgb(255, 215, 50),
		legs = 4, glow = true, features = { "spots", "tail:long" } },
	EmberBat = { display = "Ember Bat", ability = "Glide", shape = "Ball", size = 0.9, body = rgb(70, 35, 70), accent = rgb(255, 120, 30),
		legs = 0, glow = true, features = { "wings:bat", "ears:pointy" } },
	Hellpup = { display = "Hellpup", ability = "Dash", shape = "Block", size = 1, body = rgb(140, 25, 25), accent = rgb(255, 130, 20),
		legs = 4, glow = true, features = { "ears:pointy", "horns", "tail:long", "flame" } },
	-- Cosmic
	StarJelly = { display = "Star Jelly", ability = "Phase", shape = "Ball", size = 1, body = rgb(200, 140, 255), accent = rgb(120, 230, 255),
		head = false, legs = 0, glow = true, translucent = true, features = { "tentacles" } },
	CometFox = { display = "Comet Fox", ability = "Dash", shape = "Block", size = 1, body = rgb(150, 210, 255), accent = rgb(80, 240, 255),
		legs = 4, glow = true, features = { "ears:pointy", "tail:bushy" } },
	BabyDragon = { display = "Baby Dragon", ability = "Phase", shape = "Block", size = 1.1, body = rgb(40, 170, 150), accent = rgb(255, 210, 80),
		legs = 4, features = { "wings:big", "horns", "tail:long", "belly" } },
}
for _, biome in Config.Biomes do
	for _, speciesId in biome.species do
		Config.Species[speciesId].biome = biome.id
	end
end

-- Movement is independent of special abilities and anatomical leg count.
for _, id in { "Vulture", "Parrot", "SnowOwl", "EmberBat", "BabyDragon" } do
	Config.Species[id].canFly = true
end
Config.Species.Bunny.locomotion = "hop"
Config.Species.Frog.locomotion = "hop"
Config.Species.Penguin.locomotion = "waddle"
Config.Species.Duckling.locomotion = "waddle"
Config.Species.Mammoth.locomotion = "heavy"
Config.Flight = { verticalSpeed = 16, landingSpeed = 10, maxHeight = 48, takeoffSeconds = .6 }

Config.Rarities = {
	{ id = "Common", odds = 55, incomeX = 1, speed = 0, scale = 1.0, color = rgb(200, 200, 200) },
	{ id = "Uncommon", odds = 28, incomeX = 2, speed = 2, scale = 1.1, color = rgb(85, 200, 90) },
	{ id = "Rare", odds = 12, incomeX = 4, speed = 4, scale = 1.2, color = rgb(60, 140, 255) },
	{ id = "Epic", odds = 4, incomeX = 10, speed = 7, scale = 1.35, color = rgb(170, 80, 255) },
	{ id = "Legendary", odds = 1, incomeX = 25, speed = 12, scale = 1.5, color = rgb(255, 190, 40) },
	{ id = "Mythic", odds = 0, incomeX = 100, speed = 18, scale = 1.7, color = rgb(255, 80, 180) }, -- Secret Eggs only
}
Config.RarityById = {}
for i, rarity in Config.Rarities do
	rarity.index = i
	Config.RarityById[rarity.id] = rarity
end

Config.Mutations = {
	Shocked = { event = "Thunderstorm", chance = 0.30, incomeX = 1.5, speed = 1 },
	Golden = { event = "GoldenHour", chance = 0.15, incomeX = 2, speed = 2 },
	Cursed = { event = "BloodMoon", chance = 0.10, incomeX = 3, speed = 3 },
}

Config.Abilities = {
	Dash = { speedMult = 2, duration = 1.5, cooldown = 8 },
	Jump = { jumpMult = 2 },
	Glide = { gravityCancel = 0.8 },
	Swim = { nonSwimmerMult = 0.5 }, -- riders without Swim move at half speed in water
	Fireproof = {},
	Phase = {},
}

-- noLane*: carriers without the biome's lane ability get no wake-up head start and a faster guardian
-- Escape patches (each biome's lane, split up). Stay on one too long and you sink: slowed, no jumping, unprotected.
Config.Patch = { count = 5, width = 20, length = 30, stuckAfter = 4, stuckSeconds = 2, stuckSpeed = 0.2, sink = 1.5,
	messages = { Lake = "Dragged under!", Desert = "Quicksand! You're sinking!", Jungle = "The current sweeps you under!",
		Tundra = "The ice cracks under you!", Volcano = "The lava is melting your ride!", Cosmic = "The rift collapses on you!" } }

-- wakeDelay: guardians are awake and patrolling, so it's just a reaction time
Config.Guardian = { wakeDelay = 0.2, sleepDistance = 12, catchRadius = 5, stun = 1.5, bloodMoonMult = 1.15,
	noLaneWakeDelay = 0, noLaneSpeedMult = 1,
	-- guardians walk a circle around their nest: radius = their catch reach + patrolGap. patrolClear: room the
	-- layout tools keep free around each nest (covers the biggest guardian's circle)
	patrolGap = 22, patrolClear = 45, patrolSpeedMult = 0.45,
	chaseRamp = 2, -- a chase starts at patrol pace and reaches full speed over this many seconds
	tireAfter = 12, tiredMult = 0.8, -- after this long chasing, it slows to this fraction (long runs home stay winnable)
	-- chasing around obstacles (flyers just fly over): re-path every pathEvery s as an agent of pathRadius (slimmer than
	-- the body, so it squeezes through gaps); straight at you within directRange when the line is clear
	pathEvery = 0.4, pathRadius = 6, directRange = 30,
	stuckSeconds = 1, -- barely moved for this long (trapped circling a mesa) -> pushes straight through for a moment
	catchUpRange = 50, catchUpMult = 1.1, -- far behind and can't see you: a little faster
	lungeRange = 15, lungeMult = 1.5, lungeSeconds = 0.4, lungeCooldown = 4 } -- close and clear: a short burst
Config.Nests = { forestEggs = 8, forestRefill = 20, eggs = 6, refillInterval = 180,
	depth = 0.7 } -- nests sit at x = 0, this far from the biome entrance toward its far end

Config.Plot = {
	count = 8, startIncubators = 2, maxIncubators = 6, startPen = 6, maxPen = 20, stableSize = 50,
	lockSeconds = 60, lockPerRebirth = 10, joinLock = 30,
}

Config.Steal = {
	carrierHold = 0.7, carrierRange = 8, baseHold = 2, takeBackWindow = 10, takeBackHold = 0.5, takeBackRange = 10,
	shieldSeconds = 15 * 60, robCooldown = 60, catchGrace = 3,
}

Config.Gear = {
	priceSeconds = 30, minPrice = 50,
	net = { range = 40, slow = 0.5, duration = 3, cooldown = 20 },
	trap = { slow = 0.7, duration = 2, maxPlaced = 2, lifetime = 60 },
	soda = { boost = 0.25, duration = 20 },
}

Config.Events = {
	secretEggInterval = 300, secretHatch = 60,
	secretOdds = { 0, 0, 0, 72, 18, 10 }, -- rarity weights for Secret Eggs: Epic / Legendary / Mythic
	weatherInterval = 600, weatherDuration = 120,
	mamaInterval = 1200, mamaWarning = 30, mamaDuration = 120, mamaSnatchEvery = 6,
	mamaHpPerPlayer = 150, mamaMinHp = 300, mamaClickCap = 8, mamaRewardMinDamage = 10, luckyHatch = 30,
	mamaScale = 8, mamaStompEvery = 1.2, mamaClickRange = 80, -- scale: 2x the Cosmic guardian so she towers over Home Row
	mamaBigStompEvery = 6, mamaStompWarn = 1.5, mamaStompRadius = 30, mamaStompStun = 1, -- red-ring stomp to dodge
	mamaWeakSwitch = 5, -- only one weak spot is open; it moves this often
	mamaDropEvery = 0.15, -- each 15% of her HP knocks one hoard egg onto the ground
	mamaRewardShareStep = 0.15, mamaRewardMax = 4, -- Lucky Eggs = 1 + one per 15% damage share, max 4
}

Config.Costs = {
	saddleMax = 20,
	saddle = function(level: number): number -- cost of reaching this saddle level
		return 100 * 1.8 ^ level
	end,
	incubators = { [3] = 1e3, [4] = 25e3, [5] = 5e5, [6] = 1e7 },
	penSlot = function(slot: number): number -- slots 7..20
		return 250 * 3 ^ (slot - 7)
	end,
}

Config.RebirthIncomeStep = 0.5
local REBIRTHS = {
	{ cash = 1e5, biome = "Jungle", reward = "incubator" },
	{ cash = 1e6, biome = "Tundra", reward = "pen" },
	{ cash = 1e7, biome = "Volcano", reward = "mount" },
	{ cash = 1e8, biome = "Cosmic", reward = "incubator" },
	{ cash = 4e8, biome = "Cosmic", reward = "pen" },
	{ cash = 1.6e9, biome = "Cosmic", reward = "incubator" },
	{ cash = 6.4e9, biome = "Cosmic", reward = "pen" },
	{ cash = 2.56e10, biome = "Cosmic", reward = "incubator" },
	{ cash = 1e11, biome = "Cosmic", reward = "pen" },
	{ cash = 4e11, biome = "Cosmic", reward = "pen" },
}
Config.MaxRebirths = #REBIRTHS
function Config.rebirth(n: number) -- requirements and reward for reaching rebirth n; nil past the max
	return REBIRTHS[n]
end

-- Guardians use CreatureBuilder recipes at a big scale
Config.Guardians = {
	Forest = { scale = 2.6, gait = "biped", recipe = { shape = "Ball", body = rgb(250, 250, 245), accent = rgb(230, 50, 40), footColor = rgb(255, 160, 40),
		legs = 2, features = { "beak:yellow", "wings:small", "horns:single" } } },
	Lake = { scale = 2.8, gait = "biped", recipe = { shape = "Ball", body = rgb(250, 250, 255), accent = rgb(255, 140, 40), footColor = rgb(40, 40, 45),
		headSize = 0.8, legs = 2, features = { "beak", "wings:big" } } },
	Desert = { scale = 3, gait = "quad", recipe = { shape = "Block", body = rgb(120, 40, 30), accent = rgb(30, 25, 25),
		headSize = 0.8, legs = 4, features = { "spikes", "tail:long", "horns" } } },
	Jungle = { scale = 3.2, gait = "quad", recipe = { shape = "Block", body = rgb(240, 140, 40), accent = rgb(250, 245, 235),
		eyeColor = rgb(120, 220, 80), legs = 4, features = { "ears:round", "muzzle", "tail:long" } } },
	Tundra = { scale = 3.6, gait = "biped", recipe = { shape = "Ball", body = rgb(225, 235, 250), accent = rgb(130, 150, 180),
		legs = 2, features = { "ears:small", "muzzle", "horns" } } },
	Volcano = { scale = 3.4, gait = "quad", recipe = { shape = "Block", body = rgb(30, 25, 30), accent = rgb(255, 60, 30), eyeColor = rgb(255, 80, 40),
		legs = 4, glow = true, features = { "ears:pointy", "horns", "tail:long", "flame" } } },
	Cosmic = { scale = 4, gait = "quad", recipe = { shape = "Block", body = rgb(110, 60, 200), accent = rgb(255, 210, 80),
		legs = 4, glow = true, features = { "wings:big", "horns", "tail:long", "belly" } } },
}

Config.Guardians.Lake.canFly = true
Config.Guardians.Cosmic.canFly = true

function Config.income(creature, rebirths: number?): number
	local spec = Config.Species[creature.species]
	local mutation = creature.mutation and Config.Mutations[creature.mutation]
	return Config.BiomeById[spec.biome].baseIncome * Config.RarityById[creature.rarity].incomeX
		* (mutation and mutation.incomeX or 1) * (1 + Config.RebirthIncomeStep * (rebirths or 0))
end

function Config.mountSpeed(creature): number
	local spec = Config.Species[creature.species]
	local mutation = creature.mutation and Config.Mutations[creature.mutation]
	return Config.BiomeById[spec.biome].mountBase + Config.RarityById[creature.rarity].speed
		+ (mutation and mutation.speed or 0) + (spec.ability and 0 or Config.NoAbilitySpeedBonus)
end

Config.Offline = { rate = 0.5, capSeconds = 8 * 3600 }

-- 7-day login streak: cash = N seconds of income (with a floor); day 7 gives a 15-min Luck Potion
Config.Daily = {
	{ seconds = 60, min = 100 }, { seconds = 90, min = 200 }, { seconds = 120, min = 300 }, { seconds = 180, min = 500 },
	{ seconds = 240, min = 800 }, { seconds = 300, min = 1200 }, { luckMinutes = 15 },
}
Config.LuckSeconds = 15 * 60 -- Luck Potion / Server Luck: each hatch rolls rarity twice and keeps the better one

-- Placeholder IDs: replace the 0s with your real game pass / developer product IDs from Creator Hub.
Config.Monetization = {
	passes = {
		VIP = { id = 2009138282, name = "VIP", info = "+50% cash and a VIP chat tag" },
		ExtraMount = { id = 2006037890, name = "Extra Mount Slot", info = "Ride two creatures: speed of the faster, both abilities" },
		Incubators = { id = 2008886448, name = "+2 Incubators", info = "Hatch two more eggs at once (max 6)" },
		PenSlots = { id = 2006001857, name = "+5 Pen Slots", info = "Five more earning spots (max 20)" },
		Lucky = { id = 2008862492, name = "Lucky", info = "10% of hatches roll one rarity higher" },
	},
	products = {
		InstantHatch = { id = 3716940270, name = "Instant Hatch", info = "Hatch every egg in your incubators now" },
		LuckPotion = { id = 3716940345, name = "Luck Potion", info = "15 minutes: every hatch rolls rarity twice" },
		ServerLuck = { id = 3716940466, name = "Server Luck", info = "15 minutes of luck for everyone in the server" },
	},
}
Config.LuckyPassChance = 0.10

-- Exact chance (0..1) of each rarity 1..5 from a normal egg, matching HatchService.roll.
-- luck = roll twice, keep the better; luckyPass = LuckyPassChance of rolls go one rarity up.
-- Shown in the Store before purchase (paid random item odds disclosure).
function Config.hatchOdds(luck: boolean?, luckyPass: boolean?): { number }
	local total, cum, odds = 0, 0, {}
	for i = 1, 5 do
		total += Config.Rarities[i].odds
	end
	for i = 1, 5 do
		local before = cum
		cum += Config.Rarities[i].odds / total
		odds[i] = if luck then cum ^ 2 - before ^ 2 else cum - before
	end
	if luckyPass then
		local p = Config.LuckyPassChance
		for i = 5, 1, -1 do -- descending so odds[i - 1] is still the unshifted value
			odds[i] = odds[i] * (if i == 5 then 1 else 1 - p) + (if i > 1 then odds[i - 1] * p else 0)
		end
	end
	return odds
end

-- Free Creator Store audio used by SoundService.SFX (record of what's set there; swap IDs in both places)
Config.Sounds = {
	EggGrab = 134633278315554, Roar = 9113985445, ChaseSting = 1837950656, Heartbeat = 9043365842,
	CatchFling = 111237552536869, HatchCrack = 9113959343, RarityReveal = 1841391669, Purchase = 93529351909119,
	Lock = 9120484518, Unlock = 9119730203, RaidAlarm = 7939429566, MamaSiren = 792323017, MamaStomp = 9113552058,
	MamaDefeated = 9045808549, Rain = 9112854469, Thunder = 9113169432, HomeMusic = 1839578771,
	AmbienceForest = 9112835068, AmbienceLake = 9126195224, AmbienceDesert = 551546110, AmbienceJungle = 9113048424,
	AmbienceTundra = 4175285709, AmbienceVolcano = 9112823197, AmbienceCosmic = 9119413402,
}
Config.RoarPitch = { Forest = 1.6, Lake = 1.4, Desert = 1.15, Jungle = 1, Tundra = 0.85, Volcano = 0.8, Cosmic = 0.7 } -- one roar, per-guardian pitch
Config.SellSeconds = 60

-- Tutorial: guide entries (in Guide order). `when` ones also pop up once, the first time it happens.
Config.Tips = {
	{ key = "basics", title = "How to play", body = "Steal an egg from a biome nest and run it home before the guardian catches you. Eggs hatch in your incubators. Creatures in your pen earn cash every second, and the one you ride sets your speed." },
	{ key = "patches", when = "first visit to the Lake or deeper", title = "Escape patches", body = "Each biome has patches the guardian can't reach you on, if you ride the right ability (Swim, Jump, Glide, Fireproof, Phase). Don't stay on one for more than 4 seconds or you sink and get stuck for 2." },
	{ key = "gear", title = "Gear", body = "Buy gear at the Gear Shop in the Plaza. Net Gun slows a player, Slip Trap slows whoever steps on it (guardians too), Speed Soda makes you faster for 20 seconds." },
	{ key = "pvp", when = "your new-player shield ends", title = "Stealing from players", body = "Hold Steal Egg near someone carrying an egg to take it. Or walk into an unlocked base and hold Steal Egg on an incubator. Victims get 10 seconds to catch you and Take Back." },
	{ key = "robbed", when = "someone steals from you", title = "Protect your eggs", body = "Chase the thief and hold Take Back within 10 seconds. Press the red Lock button at your base to keep raiders out for a while." },
	{ key = "weather", when = "the first weather event", title = "Weather", body = "Thunderstorm, Golden Hour and Blood Moon give eggs you grab a chance of a mutation that boosts income and speed. Blood Moon also makes guardians faster." },
	{ key = "mama", when = "Mama Dragon's first warning", title = "Mama Dragon", body = "She snatches eggs from bases. Click her glowing weak spot, which moves every few seconds. Jump or run out of the red ring before she stomps. Hits knock eggs loose: grab them!" },
	{ key = "secret", when = "the first Secret Egg", title = "Secret Egg", body = "A glowing egg appears somewhere from the Desert onward. It always hatches Epic or better, sometimes Mythic. Every guardian in that biome hunts whoever takes it." },
	{ key = "rebirth", when = "you can afford a rebirth", title = "Rebirth", body = "Rebirth resets your cash, eggs and non-ridden creatures for a permanent income boost and a reward. You keep the creatures you ride and your Index." },
}
-- guided-step keys the client may also mark done
Config.TutorialSteps = { "rode", "saddle", "lock", "gear", "done" }
Config.IndexRewardSeconds = 60

-- Existing uploaded PNGs: Documents/Roblox Games/art/roblox-icons.json.
Config.Icons = {
	Gear = {
		net = "rbxassetid://120484893325439",
		trap = "rbxassetid://112266707955455",
		soda = "rbxassetid://126370761984703",
	},
	Abilities = {
		Dash = "rbxassetid://88116956031926",
		Jump = "rbxassetid://130376445182667",
		Glide = "rbxassetid://77826991161811",
		Swim = "rbxassetid://100279436902805",
		Fireproof = "rbxassetid://135382872676979",
		Phase = "rbxassetid://108030336595358",
	},
	Rarities = {
		Common = "rbxassetid://139228409390857",
		Uncommon = "rbxassetid://89889109594855",
		Rare = "rbxassetid://93378435828847",
		Epic = "rbxassetid://100499275303932",
		Legendary = "rbxassetid://87554946714292",
		Mythic = "rbxassetid://91004116836378",
	},
}

return Config

