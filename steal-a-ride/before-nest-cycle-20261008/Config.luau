-- All tuning numbers for Steal a Mount (formerly Steal a Ride) (see steal-a-ride.md). Change balance here, nowhere else.
local rgb = Color3.fromRGB

local Config = {}

-- Movement scale: walking, mount bases and guardians (below) move together, so every escape keeps its ratio.
-- Speeds below are written at the 20-walk tuning; 1.25 makes walking 25.
Config.SpeedScale = 1.25
Config.WalkSpeed = 20 * Config.SpeedScale
Config.DataStoreName = "StealARide_v2"
-- Pre-reset store: anyone with a save there is OG (overhead tag + one Lucky Egg of their best old biome + cash, once)
Config.LegacyDataStoreName = "StealARide_v1"
Config.LegacyGiftCash = 5000

-- Biomes in road order. minEscape = legacy chase metadata (not an enforced gate).
-- Pacing (tools/pacing-sim): guardians, hatch times, deep refill and saddle growth spread a fresh player's first Cosmic over ~2-3 h.
-- carry = speed fraction kept while carrying this biome's egg (deeper eggs are heavier; Secret Eggs heavier still).
Config.Biomes = {
	{ id = "Forest", guardian = "Chicken", guardianSpeed = 18, depth = 140, minEscape = 11.6, mountBase = 22.5,
		lane = nil, hatchTime = 15, baseIncome = 4, carry = 0.96, species = { "Chick", "Bunny", "Fox" },
		look = { floor = rgb(86, 160, 72), material = Enum.Material.Grass, accent = rgb(120, 230, 90),
			tint = rgb(240, 255, 240), atmosphere = rgb(199, 230, 199), density = 0.3, haze = 1 } },
	{ id = "Lake", guardian = "Swan", guardianSpeed = 27, depth = 200, minEscape = 16.9, mountBase = 28.75,
		lane = "Swim", hatchTime = 30, baseIncome = 15, carry = 0.94, species = { "Duckling", "Frog", "Otter" },
		look = { floor = rgb(214, 200, 150), material = Enum.Material.Sand, accent = rgb(90, 190, 255),
			tint = rgb(235, 245, 255), atmosphere = rgb(190, 220, 240), density = 0.3, haze = 1 } },
	{ id = "Desert", guardian = "Scorpion", guardianSpeed = 36, depth = 260, minEscape = 22.2, mountBase = 36.25,
		lane = "Jump", hatchTime = 45, baseIncome = 60, carry = 0.91, species = { "Scarab", "Lizard", "Vulture" },
		look = { floor = rgb(226, 186, 120), material = Enum.Material.Sandstone, accent = rgb(255, 170, 60),
			tint = rgb(255, 240, 215), atmosphere = rgb(240, 215, 170), density = 0.35, haze = 2 } },
	{ id = "Jungle", guardian = "Tiger", guardianSpeed = 44, depth = 330, minEscape = 28.4, mountBase = 43.75,
		lane = "Swim", hatchTime = 68, baseIncome = 200, carry = 0.88, species = { "Monkey", "Parrot", "Panther" },
		look = { floor = rgb(52, 120, 58), material = Enum.Material.LeafyGrass, accent = rgb(60, 220, 120),
			tint = rgb(225, 255, 225), atmosphere = rgb(150, 200, 150), density = 0.45, haze = 1.5 } },
	{ id = "Tundra", guardian = "Yeti", guardianSpeed = 52, depth = 400, minEscape = 34.6, mountBase = 52.5,
		lane = "Glide", hatchTime = 90, baseIncome = 700, carry = 0.85, species = { "Penguin", "SnowOwl", "Mammoth" },
		look = { floor = rgb(236, 242, 250), material = Enum.Material.Snow, accent = rgb(170, 230, 255),
			tint = rgb(230, 240, 255), atmosphere = rgb(220, 235, 255), density = 0.4, haze = 1 } },
	{ id = "Volcano", guardian = "Hellhound", guardianSpeed = 60, depth = 480, minEscape = 41.6, mountBase = 63.75,
		lane = "Fireproof", hatchTime = 135, baseIncome = 2500, carry = 0.82, species = { "Salamander", "EmberBat", "Hellpup" },
		look = { floor = rgb(64, 48, 46), material = Enum.Material.Basalt, accent = rgb(255, 90, 40),
			tint = rgb(255, 220, 200), atmosphere = rgb(120, 60, 50), density = 0.5, haze = 2 } },
	{ id = "Cosmic", guardian = "Dragon", guardianSpeed = 76, depth = 580, minEscape = 50.4, mountBase = 75,
		lane = "Phase", hatchTime = 180, baseIncome = 8000, carry = 0.8, species = { "StarJelly", "CometFox", "BabyDragon" },
		look = { floor = rgb(30, 24, 60), material = Enum.Material.Glass, accent = rgb(190, 110, 255),
			tint = rgb(225, 215, 255), atmosphere = rgb(60, 40, 110), density = 0.45, haze = 1 } },
}
Config.HomeLook = { tint = rgb(255, 255, 255), atmosphere = rgb(200, 220, 240), density = 0.25, haze = 0 }

Config.BiomeById = {}
for i, biome in Config.Biomes do
	biome.index = i
	Config.BiomeById[biome.id] = biome
	biome.guardianSpeed *= Config.SpeedScale
	biome.mountBase *= Config.SpeedScale
	biome.minEscape *= Config.SpeedScale
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

-- hatchX: hatch time multiplier (rarity is rolled when the egg goes into an incubator, kept hidden until it hatches)
Config.Rarities = {
	{ id = "Common", odds = 55, incomeX = 1, hatchX = 1, speed = 0, scale = 1.0, color = rgb(200, 200, 200) },
	{ id = "Uncommon", odds = 28, incomeX = 2, hatchX = 1.5, speed = 2, scale = 1.1, color = rgb(85, 200, 90) },
	{ id = "Rare", odds = 12, incomeX = 4, hatchX = 2, speed = 4, scale = 1.2, color = rgb(60, 140, 255) },
	{ id = "Epic", odds = 4, incomeX = 10, hatchX = 3, speed = 7, scale = 1.35, color = rgb(170, 80, 255) },
	{ id = "Legendary", odds = 1, incomeX = 25, hatchX = 5, speed = 12, scale = 1.5, color = rgb(255, 190, 40) },
	{ id = "Mythic", odds = 0, incomeX = 100, hatchX = 8, speed = 18, scale = 1.7, color = rgb(255, 80, 180) }, -- Secret Eggs only
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
-- warn: seconds on a patch before its outline flashes, the tick starts, and its particles go frantic (all before stuckAfter)
Config.Patch = { count = 5, width = 20, length = 30, stuckAfter = 4, stuckSeconds = 2, stuckSpeed = 0.2, sink = 1.5,
	warn = { flash = 2.5, tick = 3.2, frantic = 3.7 },
	messages = { Lake = "Dragged under!", Desert = "Quicksand! You're sinking!", Jungle = "The current sweeps you under!",
		Tundra = "The ice cracks under you!", Volcano = "The lava is melting your ride!", Cosmic = "The rift collapses on you!" } }

-- wakeDelay: guardians are awake and patrolling, so it's just a reaction time
Config.Guardian = { wakeDelay = 0.2, sleepDistance = 12, catchRadius = 5, stun = 1.5, bloodMoonMult = 1.15,
	noLaneWakeDelay = 0, noLaneSpeedMult = 1,
	-- guardians walk a circle around their nest: radius = their catch reach + patrolGap. patrolClear: room the
	-- layout tools keep free around each nest (covers the biggest guardian's circle)
	patrolGap = 22, patrolClear = 45, patrolSpeedMult = 0.45,
	chaseRamp = 2, -- a chase starts at patrol pace and reaches full speed over this many seconds
	tireAfter = 12, tiredMult = 0.95, -- after this long chasing, it slows to this fraction (long runs home stay winnable)
	rageDistance = 60, rageMult = 1.3, -- prey this close to the safe line: enraged, full speed x rageMult (ignores tiredness)
	bumpReach = 1, -- carriers of other biomes' eggs are caught only on touching the body: body radius + about a player's half-width
	-- chasing around obstacles (flyers just fly over): re-path every pathEvery s as an agent of pathRadius (slimmer than
	-- the body, so it squeezes through gaps); straight at you within directRange when the line is clear
	pathEvery = 0.4, pathRadius = 6, directRange = 30,
	stuckSeconds = 1, -- barely moved for this long (trapped circling a mesa) -> pushes straight through for a moment
	catchUpRange = 50, catchUpMult = 1.1, -- far behind and can't see you: a little faster
	lungeRange = 15, lungeMult = 1.5, lungeSeconds = 0.4, lungeCooldown = 4 } -- close and clear: a short burst
Config.Nests = { forestEggs = 8, forestRefill = 20, eggs = 6, refillInterval = 360,
	depth = 0.7 } -- nests sit at x = 0, this far from the biome entrance toward its far end

Config.Plot = {
	count = 8, startIncubators = 2, maxIncubators = 6, startPen = 6, maxPen = 20, stableSize = 50,
	lockSeconds = 60, lockPerRebirth = 10, joinLock = 30,
}

-- Base look: a new tier at these rebirth counts (walls, trim, corner pillars, pen pads, incubator pods).
-- Cosmetics are bought once with Cash and kept through rebirths; each slot shows one equipped item (price 0 = free default).
Config.Base = {
	tiers = {
		{ rebirths = 0, name = "Wooden", wall = "WoodPlanks", trim = rgb(115, 80, 50), trimMat = "Wood", pad = rgb(160, 115, 70), padMat = "Wood",
			ring = rgb(255, 190, 90) },
		{ rebirths = 1, name = "Stone", wall = "Slate", trim = rgb(105, 105, 115), trimMat = "Cobblestone", pad = rgb(150, 150, 160), padMat = "Slate",
			ring = rgb(120, 230, 255), pillar = 7, cap = rgb(130, 130, 140) },
		{ rebirths = 3, name = "Crystal", wall = "Glass", trim = rgb(90, 220, 255), trimMat = "Neon", pad = rgb(170, 235, 255), padMat = "Glass",
			ring = rgb(90, 220, 255), pillar = 9, cap = rgb(120, 235, 255), capMat = "Glass", dome = true, light = true },
		{ rebirths = 6, name = "Golden", wall = "Marble", trim = rgb(255, 200, 70), trimMat = "SmoothPlastic", pad = rgb(255, 210, 90), padMat = "SmoothPlastic",
			ring = rgb(255, 215, 90), pillar = 11, cap = rgb(255, 205, 70), capMat = "Neon", dome = true, light = true },
		{ rebirths = 10, name = "Cosmic", wall = "Glass", trim = rgb(170, 90, 255), trimMat = "Neon", pad = rgb(60, 30, 110), padMat = "Neon",
			ring = rgb(255, 120, 255), pillar = 13, cap = rgb(200, 130, 255), capMat = "Neon", dome = true, light = true, orbs = true },
	},
	slots = {
		{ id = "color", title = "Color" }, { id = "floor", title = "Floor" }, { id = "plants", title = "Plants" },
		{ id = "seating", title = "Seating" }, { id = "rug", title = "Rug" }, { id = "lights", title = "Lights" },
		{ id = "statue", title = "Statue" }, { id = "banners", title = "Banners" }, { id = "gate", title = "Gate" },
	},
	items = {
		{ id = "colorDefault", slot = "color", name = "Original", price = 0 },
		{ id = "colorOcean", slot = "color", name = "Ocean Blue", price = 2500, color = rgb(60, 140, 235) },
		{ id = "colorMint", slot = "color", name = "Mint", price = 2500, color = rgb(90, 215, 160) },
		{ id = "colorSunset", slot = "color", name = "Sunset", price = 10000, color = rgb(255, 140, 60) },
		{ id = "colorBubblegum", slot = "color", name = "Bubblegum", price = 10000, color = rgb(255, 120, 190) },
		{ id = "colorRoyal", slot = "color", name = "Royal Purple", price = 50000, color = rgb(140, 80, 220) },
		{ id = "colorMidnight", slot = "color", name = "Midnight", price = 50000, color = rgb(35, 40, 70) },
		{ id = "colorGold", slot = "color", name = "Gold", price = 250000, color = rgb(255, 200, 60) },
		{ id = "colorForest", slot = "color", name = "Forest Green", price = 25000, color = rgb(40, 130, 70) },
		{ id = "colorIce", slot = "color", name = "Ice White", price = 100000, color = rgb(225, 245, 255) },
		{ id = "colorObsidian", slot = "color", name = "Obsidian", price = 1000000, color = rgb(25, 20, 35) },
		{ id = "floorConcrete", slot = "floor", name = "Concrete", price = 0 },
		{ id = "floorWood", slot = "floor", name = "Wood Planks", price = 5000, color = rgb(185, 135, 85), material = "WoodPlanks" },
		{ id = "floorGrass", slot = "floor", name = "Grass", price = 5000, color = rgb(95, 175, 75), material = "Grass" },
		{ id = "floorCobble", slot = "floor", name = "Cobblestone", price = 25000, color = rgb(150, 145, 140), material = "Cobblestone" },
		{ id = "floorMarble", slot = "floor", name = "Marble", price = 100000, color = rgb(240, 238, 245), material = "Marble" },
		{ id = "floorDiamond", slot = "floor", name = "Diamond Plate", price = 1000000, color = rgb(175, 190, 205), material = "DiamondPlate" },
		{ id = "floorSand", slot = "floor", name = "Sand", price = 15000, color = rgb(230, 200, 140), material = "Sand" },
		{ id = "floorIce", slot = "floor", name = "Ice", price = 250000, color = rgb(170, 220, 245), material = "Ice" },
		{ id = "floorBasalt", slot = "floor", name = "Lava Rock", price = 2500000, color = rgb(60, 45, 45), material = "Basalt" },
		{ id = "plantsNone", slot = "plants", name = "None", price = 0 },
		{ id = "plantsFern", slot = "plants", name = "Potted Ferns", price = 2000 },
		{ id = "plantsFlowers", slot = "plants", name = "Flower Beds", price = 15000 },
		{ id = "plantsPalm", slot = "plants", name = "Mini Palms", price = 75000 },
		{ id = "plantsCrystal", slot = "plants", name = "Crystal Blooms", price = 500000 },
		{ id = "plantsCactus", slot = "plants", name = "Cacti", price = 30000 },
		{ id = "plantsSakura", slot = "plants", name = "Sakura Trees", price = 2000000 },
		{ id = "seatingNone", slot = "seating", name = "None", price = 0 },
		{ id = "seatingBench", slot = "seating", name = "Bench", price = 3000 },
		{ id = "seatingPicnic", slot = "seating", name = "Picnic Table", price = 20000 },
		{ id = "seatingBeanbags", slot = "seating", name = "Beanbags", price = 100000 },
		{ id = "seatingThrone", slot = "seating", name = "Royal Throne", price = 1000000 },
		{ id = "seatingSofa", slot = "seating", name = "Sofa", price = 50000 },
		{ id = "seatingCampfire", slot = "seating", name = "Campfire", price = 300000 },
		{ id = "rugNone", slot = "rug", name = "None", price = 0 },
		{ id = "rugMat", slot = "rug", name = "Welcome Mat", price = 1000, color = rgb(190, 90, 60) },
		{ id = "rugRound", slot = "rug", name = "Round Rug", price = 10000, color = rgb(70, 120, 200) },
		{ id = "rugCarpet", slot = "rug", name = "Red Carpet", price = 200000, color = rgb(200, 30, 45) },
		{ id = "rugRainbow", slot = "rug", name = "Rainbow Rug", price = 50000, color = rgb(255, 120, 200) },
		{ id = "rugGold", slot = "rug", name = "Gold Carpet", price = 2000000, color = rgb(255, 200, 60) },
		{ id = "lightsNone", slot = "lights", name = "None", price = 0 },
		{ id = "lightsLanterns", slot = "lights", name = "Lanterns", price = 5000 },
		{ id = "lightsPosts", slot = "lights", name = "Lamp Posts", price = 40000 },
		{ id = "lightsNeon", slot = "lights", name = "Neon Strips", price = 400000 },
		{ id = "lightsTorches", slot = "lights", name = "Torches", price = 15000 },
		{ id = "lightsDisco", slot = "lights", name = "Disco Ball", price = 2000000 },
		{ id = "statueNone", slot = "statue", name = "None", price = 0 },
		{ id = "statueGnome", slot = "statue", name = "Garden Gnome", price = 5000 },
		{ id = "statueChick", slot = "statue", name = "Chick Statue", price = 60000 },
		{ id = "statueFountain", slot = "statue", name = "Fountain", price = 400000 },
		{ id = "statueTrophy", slot = "statue", name = "Golden Trophy", price = 750000 },
		{ id = "statueDragon", slot = "statue", name = "Golden Dragon", price = 5000000 },
		{ id = "bannersNone", slot = "banners", name = "None", price = 0 },
		{ id = "bannersPlain", slot = "banners", name = "Banners", price = 20000 },
		{ id = "bannersRoyal", slot = "banners", name = "Royal Banners", price = 200000, color = rgb(180, 25, 40) },
		{ id = "bannersStar", slot = "banners", name = "Star Banners", price = 1500000, color = rgb(60, 30, 110) },
		{ id = "gateNone", slot = "gate", name = "Plain Posts", price = 0 },
		{ id = "gateLog", slot = "gate", name = "Log Archway", price = 3000, color = rgb(230, 160, 80) },
		{ id = "gateStone", slot = "gate", name = "Stone Pillars", price = 25000, color = rgb(180, 185, 200) },
		{ id = "gateTorii", slot = "gate", name = "Torii Gate", price = 100000, color = rgb(205, 45, 40) },
		{ id = "gateCrystal", slot = "gate", name = "Crystal Gate", price = 500000, color = rgb(130, 230, 255) },
		{ id = "gateGolden", slot = "gate", name = "Golden Gate", price = 2000000, color = rgb(255, 200, 60) },
		{ id = "gateCosmic", slot = "gate", name = "Cosmic Portal", price = 5000000, color = rgb(170, 90, 255) },
	},
}
Config.Base.itemById = {}
for _, item in Config.Base.items do
	Config.Base.itemById[item.id] = item
end
function Config.baseTier(rebirths: number): number -- index into Config.Base.tiers
	local tier = 1
	for i, t in Config.Base.tiers do
		if (rebirths or 0) >= t.rebirths then
			tier = i
		end
	end
	return tier
end

Config.Steal = {
	carrierHold = 0, carrierRange = 8, baseHold = 2, takeBackWindow = 10, takeBackHold = 0, takeBackRange = 10, -- 0 = tap E
	shieldSeconds = 15 * 60, robCooldown = 60, catchGrace = 3,
}

-- Carrying an egg: weight (Biomes[].carry) plus a short slowdown for sharp turns. Server-side speed only, never physics mass.
Config.Carry = { secretMult = 0.85, -- Secret Eggs keep this fraction of their biome's normal carry speed
	turn = { sampleEvery = 0.1, minSpeed = 2, maxGap = 0.5, -- horizontal travel only; slower or gappier samples are ignored
		freeRate = 75, fullRate = 450, floor = 0.8, -- deg/s of heading change: free below 75, 20% slower at 450+
		recover = 0.25 } } -- per second of straight travel (0.8 s from the floor back to full)
function Config.carryMult(egg): number
	local biome = Config.BiomeById[egg.biome]
	return (biome and biome.carry or 1) * (egg.secret and Config.Carry.secretMult or 1)
end

Config.Gear = {
	priceSeconds = 300, minPrice = 500, -- five minutes of income
	net = { range = 40, slow = 0.5, duration = 3, cooldown = 20 },
	trap = { slow = 0.7, duration = 2, maxPlaced = 2, lifetime = 60 },
	soda = { boost = 0.25, duration = 20 },
}

-- Plaza: free chest (every chestCooldown s, pays chestSeconds of income, at least chestMin), global boards, server showcase
Config.Plaza = { chestCooldown = 4 * 3600, chestSeconds = 600, chestMin = 1000, boardRefresh = 120, showcaseRefresh = 10 }

-- Three distinct goals from each pool. Income targets are fixed when assigned; cash rewards scale at claim.
Config.Quests = {
	daily = {
		{ id = "home5", event = "deposit", target = 5, title = "Bring home %s eggs" },
		{ id = "hatch3", event = "hatch", target = 3, title = "Hatch %s eggs" },
		{ id = "earnDaily", event = "earn", seconds = 600, min = 1000, title = "Earn $%s" },
		{ id = "chest", event = "chest", target = 1, title = "Open the Plaza chest" },
	},
	weekly = {
		{ id = "home30", event = "deposit", target = 30, title = "Bring home %s eggs" },
		{ id = "rare3", event = "rareHatch", target = 3, title = "Hatch %s Rare or better eggs" },
		{ id = "like5", event = "like", target = 5, title = "Like bases %s times" },
		{ id = "steal3", event = "steal", target = 3, title = "Steal %s eggs" },
		{ id = "earnWeekly", event = "earn", seconds = 3600, min = 5000, title = "Earn $%s" },
		{ id = "fuse2", event = "fuse", target = 2, title = "Fuse creatures %s times" },
	},
	dailyMin = 500, dailySeconds = 180, weeklyMin = 5000, weeklySeconds = 900,
}
Config.Quests.byId = {}
for _, pool in { Config.Quests.daily, Config.Quests.weekly } do
	for _, q in pool do Config.Quests.byId[q.id] = q end
end

Config.Events = {
	secretEggInterval = 300, secretHatch = 60,
	secretOdds = { 0, 0, 0, 72, 18, 10 }, -- rarity weights for Secret Eggs: Epic / Legendary / Mythic
	weatherInterval = 600, weatherDuration = 120,
	mamaInterval = 1200, mamaWarning = 30, mamaDuration = 120, mamaSnatchEvery = 6,
	mamaHpPerPlayer = 100, mamaMinHp = 100, mamaClickCap = 8, luckyHatch = 30,
	mamaScale = 6.5, mamaStompEvery = 1.2, mamaClickRange = 80, -- scale: ~1.6x the Cosmic guardian; 8 filled phone/tablet screens
	mamaBigStompEvery = 6, mamaStompWarn = 1.5, mamaStompRadius = 30, mamaStompStun = 1, -- red-ring stomp to dodge
	mamaWeakSwitch = 5, -- only one weak spot is open; it moves this often
	mamaDropEvery = 0.15, -- each 15% of her HP knocks one hoard egg onto the ground
	mamaSpeedHits = 50, mamaSpeedBoost = 1.25, mamaSpeedTime = 180, -- hit rewards: 50 hits = 1.25x speed for 3 min
	mamaCashHits = 75, mamaCashTime = 300, -- 75 hits = 2x cash for 5 min (online income only, not offline)
	mamaEggHits = 100, -- 100 hits = 1 Lucky Egg (a solo kill is exactly 100)
}

Config.Costs = {
	saddleMax = 20,
	saddle = function(level: number): number -- cost of reaching this saddle level
		return 100 * 1.85 ^ level
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
-- creatures kept through rebirth n: 1, +1 at rebirth 3, 6 and 9 (ridden ones are pre-picked)
function Config.rebirthKeep(n: number): number
	return 1 + n // 3
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

-- Species Mastery: every rarity of a species in the Index (Mythic comes from Secret Eggs) = that species earns more, forever
Config.MasteryIncomeX = 1.25
function Config.mastered(index, species: string): boolean
	for _, rarity in Config.Rarities do
		if not (index and index[species .. "_" .. rarity.id]) then
			return false
		end
	end
	return true
end

function Config.income(creature, rebirths: number?, index): number
	local spec = Config.Species[creature.species]
	local mutation = creature.mutation and Config.Mutations[creature.mutation]
	return Config.BiomeById[spec.biome].baseIncome * Config.RarityById[creature.rarity].incomeX
		* (mutation and mutation.incomeX or 1) * (1 + Config.RebirthIncomeStep * (rebirths or 0))
		* (Config.mastered(index, creature.species) and Config.MasteryIncomeX or 1)
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
	-- escape patches: entry sound per lane ability, and the sink-warning tick
	PatchSwim = 9114455247, PatchJump = 2772396665, PatchGlide = 9113840530, PatchFireproof = 9114446852,
	PatchPhase = 9118158252, PatchTick = 134410911353980,
}
-- Escape soundtrack (APM Music): while you carry an egg through a biome its track plays over the ducked ambience,
-- calmer the closer to home; crossing the safe line with the egg plays the sting. Entry: { assetId, volume }
Config.EscapeMusic = {
	tracks = {
		Cosmic = { 9042161703, 0.45 }, -- Silicon Circuits: building synths, cinematic techno
		Volcano = { 1837850904, 0.5 }, -- Hell's Canyon (percussion)
		Tundra = { 1842359824, 0.45 }, -- Aerodrone: stripped-back phasing drone
		Jungle = { 1838489774, 0.4 }, -- Gold Digger: adventurous
		Desert = { 9046834455, 0.4 }, -- Yal Aadra: desert colour
		Lake = { 9038713417, 0.4 }, -- C'est Ton Tour: bouncy ticking pizzicato
		Forest = { 9046175782, 0.4 }, -- Funny Farce: playful chase
	},
	sting = { 1841221383, 1, 0.8 }, -- You Did It (played like a guardian voice: id, pitch, volume)
	duck = 0.35, -- biome ambience volume while the escape track plays
}

-- Subtle biome egg motes + short hatch accents. Native textures, Pro Sound Effects audio.
local eggSpark = "rbxasset://textures/particles/sparkles_main.dds"
local eggSmoke = "rbxasset://textures/particles/smoke_main.dds"
Config.EggFX = {
	distance = 80, maxActive = 24,
	themes = {
		Forest = { texture = eggSpark, color = rgb(255, 235, 120), size = { 0.24, 0.03 }, rate = 2, life = 1.8,
			speed = 0.45, light = 1, spread = 35, spin = 20, accel = 0.35, hatchCount = 18, sound = { 9119383479, 1.15, 0.45, 1.8 } }, -- fireflies / birds
		Lake = { texture = eggSmoke, color = rgb(120, 210, 255), size = { 0.16, 0.38 }, rate = 2, life = 1.6,
			speed = 1, light = 0.25, spread = 22, accel = 0.2, fragment = "bubble", hatchCount = 18, sound = { 9125409840, 1, 0.6, 2 } },
		Desert = { texture = eggSmoke, color = rgb(235, 195, 120), size = { 0.25, 0.6 }, rate = 2, life = 1.2,
			speed = 1.3, light = 0, spread = 75, drift = 0.8, accel = -0.2, hatchCount = 24, sound = { 9118770347, 1.15, 0.65, 2.5 } }, -- sand
		Jungle = { texture = eggSpark, color = rgb(90, 220, 100), size = { 0.35, 0.12 }, rate = 1.5, life = 1.8,
			speed = 0.65, light = 0.1, spread = 65, spin = 140, accel = -0.2, drift = 0.3, squash = 1.3,
			fragment = "leaf", hatchCount = 18, sound = { 9114518386, 1.1, 0.6, 2 } },
		Tundra = { texture = eggSpark, color = rgb(215, 245, 255), size = { 0.3, 0.03 }, rate = 2, life = 1.7,
			speed = 0.7, light = 0.5, spread = 80, spin = 60, accel = -0.3, hatchCount = 22, sound = { 9114858588, 1.15, 0.6, 2.5 } }, -- frost
		Volcano = { texture = "rbxasset://textures/particles/fire_main.dds", color = rgb(255, 130, 35), size = { 0.35, 0.02 }, rate = 2, life = 1.2,
			speed = 1.1, light = 1, spread = 20, accel = 0.8, hatchCount = 22, sound = { 9117987278, 1, 0.65, 2 } }, -- embers
		Cosmic = { texture = eggSpark, color = rgb(200, 140, 255), color2 = rgb(120, 220, 255), size = { 0.32, 0 }, rate = 1.5, life = 2,
			speed = 0.45, light = 1, spread = 180, spin = 90, hatchCount = 24, sound = { 9116418035, 1.2, 0.5, 3.2 } }, -- stars
	},
}

-- Mama entrance (Pro Sound Effects). Sound entries: { assetId, pitch, volume, maxSeconds? }.
Config.MamaFX = {
	roar = { 9113980319, 0.62, 0.9, 10 }, -- giant creature roar, filtered/reverbed at a distance
	whoosh = { 9117034658, 0.75, 0.9, 5 }, -- huge airy sweep as her shadow passes
	step = { 9125404769, 0.75, 0.9, 2.4 }, -- giant dinosaur thump
	wingLoop = { 9125386814, 0.65, 0.45 }, -- slowed wing/scale rustle, 3D on Mama
	shadowImage = "", -- Creator Store silhouettes failed preload; use the dark oval fallback
	duck = 0.2, -- background loops stay at 20% through warning + active; restored at event end
}

-- Each guardian's voice: idle (3D call while patrolling nearby), alert (it spots you; also replayed louder on rage),
-- chase (loop while it hunts you, louder as it closes in), step (each footfall). Entry: { assetId, pitch, volume, maxSeconds? }
Config.GuardianSounds = {
	Forest = { idle = { 77584650945481, 1, 0.6 }, alert = { 139070736738965, 1, 0.7, 1.8 }, -- chicken cluck / squawk
		chase = { 85843458426701, 1.1, 0.5 }, step = { 133660791904965, 1.6, 0.5 } },
	Lake = { idle = { 107681596035862, 0.9, 0.6 }, alert = { 4139639790, 0.85, 0.9 }, -- swan honks
		chase = { 9114787449, 0.9, 0.45 }, step = { 9113444620, 0.8, 0.4 } },
	Desert = { idle = { 9125917896, 0.8, 0.6 }, alert = { 9119471684, 0.9, 0.8 }, -- scorpion clicks / tail rattle
		chase = { 9119458695, 0.8, 0.55 }, step = { 9125914961, 0.9, 0.4 } },
	Jungle = { idle = { 9120039247, 1, 0.6 }, alert = { 9120047949, 1, 0.9 }, -- tiger growl / roar
		chase = { 9113423075, 1, 0.45 }, step = { 9113525391, 0.6, 0.45 } },
	Tundra = { idle = { 9113983944, 0.8, 0.6 }, alert = { 911714442, 0.8, 0.9 }, -- yeti breathing / roar
		chase = { 9113984056, 0.75, 0.5 }, step = { 9113525391, 0.5, 0.55 } },
	Volcano = { idle = { 9120790555, 0.85, 0.6 }, alert = { 9120791326, 0.8, 0.9 }, -- hellhound snarls, fire
		chase = { 9079463756, 1, 0.5 }, step = { 9114444008, 1.3, 0.35 } },
	Cosmic = { idle = { 9113443896, 0.5, 0.6, 3 }, alert = { 122225901664901, 0.8, 1 }, -- dragon wings / roar, cosmic pulse
		chase = { 9125548740, 1, 0.5 }, step = { 9113444792, 0.45, 0.6 } },
}
Config.SellSeconds = 60

-- Tutorial: guide entries (in Guide order). `when` ones also pop up once, the first time it happens.
Config.Tips = {
	{ key = "basics", title = "How to play", body = "Steal an egg from a biome nest and run it home before the guardian catches you. Eggs incubate at home; when one says Ready, tap it to hatch. Creatures in your pen earn cash every second, and the one you ride sets your speed. PC: press F to get off all mounts. Phone/tablet: tap Get off. Your Stable needs free space." },
	{ key = "patches", when = "first visit to the Lake or deeper", title = "Escape patches", body = "Each biome has patches the guardian can't reach you on, if you ride the right ability (Swim, Jump, Glide, Fireproof, Phase). Don't stay on one for more than 4 seconds or you sink and get stuck for 2." },
	{ key = "gear", title = "Gear", body = "Buy gear at the Gear Shop in the Plaza. Net Gun slows a player, Slip Trap slows whoever steps on it (guardians too), Speed Soda makes you faster for 20 seconds." },
	{ key = "pvp", when = "your new-player shield ends", title = "Stealing from players", body = "Hold Steal Egg near someone carrying an egg to take it. Or walk into an unlocked base and hold Steal Egg on an incubator. Victims get 10 seconds to catch you and Take Back." },
	{ key = "robbed", when = "someone steals from you", title = "Protect your eggs", body = "Chase the thief and hold Take Back within 10 seconds. Press the red Lock button at your base to keep raiders out for a while." },
	{ key = "weather", when = "the first weather event", title = "Weather", body = "Thunderstorm, Golden Hour and Blood Moon give eggs you grab a chance of a mutation that boosts income and speed. Blood Moon also makes guardians faster." },
	{ key = "mama", when = "Mama Dragon's first warning", title = "Mama Dragon", body = "She snatches eggs from bases. Click her glowing weak spot, which moves every few seconds. Jump or run out of the red ring before she stomps. Hits knock eggs loose: grab them!" },
	{ key = "secret", when = "the first Secret Egg", title = "Secret Egg", body = "A glowing egg appears somewhere from the Desert onward. It always hatches Epic or better, sometimes Mythic. Every guardian in that biome hunts whoever takes it." },
	{ key = "rebirth", when = "you can afford a rebirth", title = "Rebirth", body = "Rebirth resets your cash, eggs and creatures for a permanent income boost and a reward. You pick which creatures to keep (1, +1 at rebirth 3, 6 and 9) and keep your Index." },
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
