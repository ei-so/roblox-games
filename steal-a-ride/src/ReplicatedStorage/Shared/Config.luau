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
		lane = "Swim", hatchTime = 30, baseIncome = 15, carry = 0.934, species = { "Duckling", "Frog", "Otter" },
		look = { floor = rgb(214, 200, 150), material = Enum.Material.Sand, accent = rgb(90, 190, 255),
			tint = rgb(235, 245, 255), atmosphere = rgb(190, 220, 240), density = 0.3, haze = 1 } },
	{ id = "Desert", guardian = "Scorpion", guardianSpeed = 36, depth = 260, minEscape = 22.2, mountBase = 36.25,
		lane = "Jump", hatchTime = 45, baseIncome = 60, carry = 0.866, species = { "Scarab", "Lizard", "Vulture" },
		look = { floor = rgb(226, 186, 120), material = Enum.Material.Sandstone, accent = rgb(255, 170, 60),
			tint = rgb(255, 240, 215), atmosphere = rgb(240, 215, 170), density = 0.35, haze = 2 } },
	{ id = "Jungle", guardian = "Tiger", guardianSpeed = 44, depth = 330, minEscape = 28.4, mountBase = 43.75,
		lane = "Swim", hatchTime = 68, baseIncome = 200, carry = 0.927, species = { "Monkey", "Parrot", "Panther" },
		look = { floor = rgb(52, 120, 58), material = Enum.Material.LeafyGrass, accent = rgb(60, 220, 120),
			tint = rgb(225, 255, 225), atmosphere = rgb(150, 200, 150), density = 0.45, haze = 1.5 } },
	{ id = "Tundra", guardian = "Yeti", guardianSpeed = 52, depth = 400, minEscape = 34.6, mountBase = 52.5,
		lane = "Glide", hatchTime = 90, baseIncome = 700, carry = 0.859, species = { "Penguin", "SnowOwl", "Mammoth" },
		look = { floor = rgb(236, 242, 250), material = Enum.Material.Snow, accent = rgb(170, 230, 255),
			tint = rgb(230, 240, 255), atmosphere = rgb(220, 235, 255), density = 0.4, haze = 1 } },
	{ id = "Volcano", guardian = "Hellhound", guardianSpeed = 60, depth = 480, minEscape = 41.6, mountBase = 63.75,
		lane = "Fireproof", hatchTime = 135, baseIncome = 2500, carry = 0.828, species = { "Salamander", "EmberBat", "Hellpup" },
		look = { floor = rgb(64, 48, 46), material = Enum.Material.Basalt, accent = rgb(255, 90, 40),
			tint = rgb(255, 220, 200), atmosphere = rgb(120, 60, 50), density = 0.5, haze = 2 } },
	{ id = "Cosmic", guardian = "Dragon", guardianSpeed = 76, depth = 580, minEscape = 50.4, mountBase = 75,
		lane = "Phase", hatchTime = 180, baseIncome = 8000, carry = 0.925, species = { "StarJelly", "CometFox", "BabyDragon" },
		look = { floor = rgb(30, 24, 60), material = Enum.Material.Glass, accent = rgb(190, 110, 255),
			tint = rgb(225, 215, 255), atmosphere = rgb(60, 40, 110), density = 0.45, haze = 1 } },
	{ id = "MysticGrove", guardian = "Giant Spider", guardianSpeed = 88, depth = 640, minEscape = 56, mountBase = 84,
		lane = "Jump", hatchTime = 240, baseIncome = 16000, carry = 0.927, species = { "Shroomling", "GlowDeer", "WispLynx" },
		look = { floor = rgb(45, 72, 65), material = Enum.Material.LeafyGrass, accent = rgb(100, 235, 205),
			tint = rgb(185, 225, 215), atmosphere = rgb(42, 75, 82), density = 0.44, haze = 2.1,
			brightness = -0.12, saturation = 0.12, contrast = 0.08 } },
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
	-- Mystic Grove: species weights remain 50 / 35 / 15, independently of rarity.
	Shroomling = { display = "Shroomling", ability = nil, shape = "Ball", size = 1.05, body = rgb(240, 226, 192), accent = rgb(130, 75, 195),
		head = false, legs = 4, features = { "mushroomCap" } },
	GlowDeer = { display = "Glow Deer", ability = "Jump", shape = "Block", size = 1.1, body = rgb(115, 205, 175), accent = rgb(210, 255, 200),
		legs = 4, eyeColor = rgb(35, 80, 75), features = { "ears:long", "muzzle", "antlers", "spots", "tail:puff" } },
	WispLynx = { display = "Wisp Lynx", ability = "Phase", shape = "Block", size = 1.1, body = rgb(135, 120, 195), accent = rgb(140, 245, 220),
		legs = 4, eyeColor = rgb(100, 250, 220), features = { "ears:tufts", "muzzle", "tail:puff", "spots" } },
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
	-- up quartz walls at 1.5x ride speed; a wall top cracks after 1.5 s; a rider who climbed keeps up to keepLead studs
	-- of lead past the Golem's normal leash when leaving the cave (pacing sim 2026-10-11, user-approved)
	Climb = { speedMult = 1.5, crackAfter = 1.5, keepLead = 20 },
}

-- noLane*: carriers without the biome's lane ability get no wake-up head start and a faster guardian
-- Escape patches (each biome's lane, split up). Stay on one too long and you sink: slowed, no jumping, unprotected.
-- warn: seconds on a patch before its outline flashes, the tick starts, and its particles go frantic (all before stuckAfter)
Config.Patch = { count = 5, width = 20, length = 30, stuckAfter = 4, stuckSeconds = 2, stuckSpeed = 0.2, sink = 1.5,
	warn = { flash = 2.5, tick = 3.2, frantic = 3.7 },
	messages = { Lake = "Dragged under!", Desert = "Quicksand! You're sinking!", Jungle = "The current sweeps you under!",
		Tundra = "The ice cracks under you!", Volcano = "The lava is melting your ride!", Cosmic = "The rift collapses on you!",
		MysticGrove = "The mushroom cap softens! You're sinking!" } }

-- wakeDelay: guardians are awake and patrolling, so it's just a reaction time
Config.Guardian = { wakeDelay = 0.2, sleepDistance = 12, catchRadius = 5, stun = 1.5, bloodMoonMult = 1.15,
	noLaneWakeDelay = 0, noLaneSpeedMult = 1,
	-- guardians walk a circle around their nest: radius = their catch reach + patrolGap. patrolClear: room the
	-- layout tools keep free around each nest (covers the biggest guardian's circle)
	patrolGap = 22, patrolClear = 45, patrolSpeedMult = 0.45,
	chaseRamp = 2, -- a chase starts at patrol pace and reaches full speed over this many seconds
	tireAfter = 12, tiredMult = 0.95, -- after this long chasing, it slows to this fraction (long runs home stay winnable)
	bumpReach = 1, -- carriers of other biomes' eggs are caught only on touching the body: body radius + about a player's half-width
	-- chasing around obstacles (flyers just fly over): re-path every pathEvery s as an agent of pathRadius (slimmer than
	-- the body, so it squeezes through gaps); straight at you within directRange when the line is clear
	pathEvery = 0.4, pathRadius = 6, directRange = 30,
	stuckSeconds = 1, -- barely moved for this long (trapped circling a mesa) -> pushes straight through for a moment
	catchUpRange = 50, catchUpMult = 1.1, -- far behind and can't see you: a little faster
	lungeRange = 15, lungeMult = 1.5, lungeSeconds = 0.4, lungeCooldown = 4, -- close and clear: a short burst (phase 1 only)
	leashBuffer = 30, -- out of its biome the guardian is never more than catch reach + this behind its target
	-- (30: a rider survives a ~0.25 s bump at spider speed; tools/pacing-sim/leash_bumps_pacing.py)
	snapMin = 3 } -- leash jumps longer than this puff and re-path (a faster rider only gets silent per-frame pulls)
Config.Nests = { forestEggs = 8, eggs = 6, refillInterval = 300, -- every nest restocks and reshuffles species together
	depth = 0.7, -- nests sit at x = 0, this far from the biome entrance toward its far end
	-- quieter servers stock fewer eggs: [players] = { Forest, other nests }; more players than rows = full nests
	byPlayers = { { 4, 3 }, { 5, 4 }, { 6, 5 }, { 6, 5 } } }

-- eggs a nest stocks with this many players in the server (never more than forestEggs / eggs)
function Config.nestEggs(biomeId: string, players: number): number
	local forest = biomeId == "Forest"
	local row = Config.Nests.byPlayers[math.max(1, players)]
	if not row then
		return forest and Config.Nests.forestEggs or Config.Nests.eggs
	end
	return forest and row[1] or row[2]
end

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
		{ id = "stick", title = "Stick" },
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
		-- base stun stick looks (StealService builds the Tool). incomeMinutes = price in minutes of the buyer's income; requires = previous tier
		{ id = "stickWood", slot = "stick", name = "Wooden Stick", price = 0, color = rgb(150, 105, 60), material = "Wood", burst = 10 },
		{ id = "stickIron", slot = "stick", name = "Iron Stick", incomeMinutes = 10, color = rgb(165, 170, 180), material = "Metal", burst = 15 },
		{ id = "stickGold", slot = "stick", name = "Gold Stick", incomeMinutes = 30, requires = "stickIron", color = rgb(255, 200, 60),
			material = "SmoothPlastic", trail = true, burst = 20 },
		{ id = "stickCrystal", slot = "stick", name = "Crystal Stick", incomeMinutes = 60, requires = "stickGold", color = rgb(130, 230, 255),
			material = "Glass", trail = true, burst = 30 },
		{ id = "stickGlitch", slot = "stick", name = "Glitch Stick", incomeMinutes = 120, requires = "stickCrystal", color = rgb(255, 42, 79),
			material = "Neon", trail = true, glitch = true, burst = 45 },
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
Config.Carry = { secretMult = 0.909, -- Secret Eggs keep this fraction of their biome's normal carry speed (leash sim 2026-10-09)
	turn = { sampleEvery = 0.1, minSpeed = 2, maxGap = 0.5, -- horizontal travel only; slower or gappier samples are ignored
		freeRate = 75, fullRate = 450, floor = 0.8, -- deg/s of heading change: free below 75, 20% slower at 450+
		recover = 0.25 } } -- per second of straight travel (0.8 s from the floor back to full)
function Config.carryMult(egg): number
	local biome = Config.BiomeById[egg.biome]
	return (biome and biome.carry or 1) * (egg.secret and Config.Carry.secretMult or 1)
end

Config.Gear = {
	priceSeconds = 300, minPrice = 500, -- five minutes of income
	buyLimit = 5, restockSeconds = 600, -- per gear type: the 5th buy starts a 10-minute wait, then the count resets
	net = { range = 40, slow = 0.5, duration = 3, cooldown = 20 },
	trap = { slow = 0.7, duration = 2, maxPlaced = 2, lifetime = 60 },
	soda = { boost = 0.10, duration = 20 },
}

-- Base stun stick: only inside your own base; hits a carrier of an egg stolen from you (StealService.swing)
Config.Stick = { range = 7, stun = 2, cooldown = 0.8 }

-- Base cosmetic price: fixed, or minutes of income for incomeMinutes items (stick tiers), never below the gear floor
function Config.basePrice(item, income: number): number
	if item.incomeMinutes then
		return math.max(Config.Gear.minPrice, math.floor(item.incomeMinutes * 60 * income))
	end
	return item.price
end

-- Plaza: free chest (every chestCooldown s, pays chestSeconds of income, at least chestMin), global boards, server showcase
Config.Plaza = { chestCooldown = 4 * 3600, chestSeconds = 600, chestMin = 1000, boardRefresh = 120, showcaseRefresh = 10 }
-- Top Players board (Plaza centre): this server's best 3, refreshed every `refresh` s; a failed avatar load retries after `retry` s
Config.TopPlayers = { refresh = 3, globalRefresh = 120, retry = 30, waiting = "Waiting for a challenger" }

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
	secretEggInterval = 420, secretHatch = 60,
	secretOdds = { 0, 0, 0, 90, 9, 1 }, -- lowest-biome fallback for older/test Secret Eggs
	secretOddsByBiome = { -- Epic / Legendary / Mythic chances improve with biome depth
		Desert = { 0, 0, 0, 90, 9, 1 },
		Jungle = { 0, 0, 0, 85, 12, 3 },
		Tundra = { 0, 0, 0, 80, 15, 5 },
		Volcano = { 0, 0, 0, 72, 20, 8 },
		Cosmic = { 0, 0, 0, 60, 25, 15 },
		MysticGrove = { 0, 0, 0, 55, 28, 17 },
	},
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
	saddleIncomeSeconds = 8, -- tools/pacing-sim/rebirth.py: keeps the saddle a real cost after rebirths
	saddle = function(level: number, income: number?): number -- cost of reaching this saddle level
		return math.max(100 * 1.85 ^ level, (income or 0) * Config.Costs.saddleIncomeSeconds * 1.15 ^ level)
	end,
	incubators = { [3] = 1e3, [4] = 25e3, [5] = 5e5, [6] = 1e7, [7] = 10e9, [8] = 20e9 }, -- 7-8 need the base expansion
	penSlot = function(slot: number): number -- slots 7..20; 21..30 (base expansion) grow x1.5 from $1.75B (~$198B for all ten)
		if slot > 20 then
			return 1.75e9 * 1.5 ^ (slot - 21)
		end
		return 250 * 3 ^ (slot - 7)
	end,
}

-- Base expansion: the lot behind a base (Rebirth 10). Its price uses price income (best pen anywhere), so moving
-- creatures out of the pen can't make it cheaper. The lot raises the pen / incubator limits; slots are bought at Sam's.
Config.Expansion = { rebirth = 10, minPrice = 50e9, incomeSeconds = 6 * 3600, maxPen = 30, maxIncubators = 8, gap = 20 }
function Config.expansionPrice(priceIncome: number): number
	return math.max(Config.Expansion.minPrice, priceIncome * Config.Expansion.incomeSeconds)
end
function Config.penMax(expanded: boolean?): number
	return expanded and Config.Expansion.maxPen or Config.Plot.maxPen
end
function Config.incubatorMax(expanded: boolean?): number
	return expanded and Config.Expansion.maxIncubators or Config.Plot.maxIncubators
end
-- lot pens (21+) and incubator pads (7+) stay fully hidden until the owner bought the lot
function Config.hiddenSlot(slot: number, kind: string, expanded: boolean?): boolean
	return not expanded and slot > (kind == "pen" and Config.Plot.maxPen or Config.Plot.maxIncubators)
end

Config.RebirthIncomeStep = 0.5
-- Rebirths: docs/superpowers/specs/2026-10-09-rebirth-20-design.md (tools/pacing-sim/rebirth.py: R20 ~31 h of play)
-- reward: incubator (+1) / pen (+2), a Lucky Egg once maxed; mount (2nd mount slot); luck (permanent hatch luck); lucky (a Lucky Egg)
local REBIRTHS = {
	{ cash = 1e5, biome = "Jungle", reward = "incubator" },
	{ cash = 1e6, biome = "Tundra", reward = "pen" },
	{ cash = 1e7, biome = "Volcano", reward = "incubator" },
	{ cash = 1e8, biome = "Cosmic", reward = "incubator" },
	{ cash = 4e8, biome = "Cosmic", reward = "pen" },
	{ cash = 6e8, biome = "Cosmic", reward = "mount" },
	{ cash = 9e8, biome = "Cosmic", reward = "pen" },
	{ cash = 1.35e9, biome = "Cosmic", reward = "incubator" },
	{ cash = 2e9, biome = "Cosmic", reward = "pen" },
	{ cash = 3e9, biome = "Cosmic", reward = "luck" },
	{ cash = 3.5e9, biome = "Cosmic", reward = "lucky" },
	{ cash = 4e9, biome = "Cosmic", reward = "lucky" },
	{ cash = 4.6e9, biome = "Cosmic", reward = "lucky" },
	{ cash = 5.3e9, biome = "Cosmic", reward = "lucky" },
	{ cash = 6.1e9, biome = "Cosmic", reward = "lucky" },
	{ cash = 7e9, biome = "Cosmic", reward = "lucky" },
	{ cash = 8.1e9, biome = "Cosmic", reward = "lucky" },
	{ cash = 9.3e9, biome = "Cosmic", reward = "lucky" },
	{ cash = 1.07e10, biome = "Cosmic", reward = "lucky" },
	{ cash = 1.23e10, biome = "Cosmic", reward = "luck" },
}
Config.MaxRebirths = #REBIRTHS
function Config.rebirth(n: number) -- requirements and reward for reaching rebirth n; nil past the max
	return REBIRTHS[n]
end
Config.MountSlotRebirth = 6 -- the free 2nd mount slot
-- creatures kept through rebirth n: 1, +1 every 4 rebirths (ridden ones are pre-picked)
function Config.rebirthKeep(n: number): number
	return 1 + n // 4
end
-- keep fee: rebirth n also costs this many seconds of what the kept creatures earn after it,
-- so keeping Mythics/Legendaries can't make the next rebirth take minutes
Config.RebirthKeepFeeSeconds = 3600
function Config.rebirthKeepFee(kept, n: number, index): number
	local total = 0
	for _, c in kept do
		total += Config.income(c, n, index)
	end
	return math.floor(total * Config.RebirthKeepFeeSeconds)
end
-- permanent rebirth luck: this share of normal hatches roll one rarity higher (added to the Lucky pass chance)
Config.RebirthLuck = { { at = 20, chance = 0.10 }, { at = 10, chance = 0.05 } }
function Config.rebirthLuck(n: number): number
	for _, step in Config.RebirthLuck do
		if n >= step.at then
			return step.chance
		end
	end
	return 0
end
-- a Lordship title every 2 rebirths (menu, rank-up toast, leaderboards, base sign); Squire before the first one
Config.RebirthTitles = { "Lesser Lord", "Iron Lord", "Silver Lord", "Golden Lord", "Platinum Lord",
	"Emerald Lord", "Royal Lord", "Mythic Lord", "Celestial Lord", "Divine Overlord" }
function Config.rebirthTitle(n: number): string
	return n < 2 and "Squire" or Config.RebirthTitles[math.min(n // 2, #Config.RebirthTitles)]
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
	MysticGrove = { scale = 3.5, gait = "spider", recipe = { shape = "Squat", headSize = 0.85, headLow = true,
		body = rgb(46, 42, 65), accent = rgb(140, 235, 210), eyeColor = rgb(150, 255, 190),
		legs = 0, features = { "spiderLegs", "spiderEyes", "fangs", "spots" } } },
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

-- "What's New" popup: returning players see every update they missed, newest first, once.
-- Oldest first; add a new entry with the next version for each published update (never edit a published one).
Config.WhatsNew = {
	{
		version = 1,
		title = "Rebirth 20!",
		lines = {
			"Rebirths now go up to <b>20</b>",
			"Earn a <b>Lord title</b> every 2 rebirths, shown on your base sign and the Top Rebirths board",
			"<b>Rebirth Luck</b> at Rebirth 10 and 20: more hatches roll a rarity higher, for good",
			"Rebirths 11-19 each give a <b>Lucky Egg</b>",
			"The free 2nd mount slot now unlocks at <b>Rebirth 6</b>. Riding two before that? Your other creature is safe in your Stable",
			"Keep 1 creature through a rebirth, +1 every 4 rebirths",
			"The Saddle now costs more as your income grows",
			"New <b>stun stick</b> in your base: whack a thief carrying your egg to send it straight home",
			"Guardians <b>burst with rage</b> when they leave their biome, then tire out",
			"Deeper guardians make their <b>final charge</b> as soon as you reach the Forest",
			"OG players get a new <b>glitchy OG badge</b>",
		},
	},
	{
		version = 2,
		title = "Mystic Grove!",
		lines = {
			"Explore <b>Mystic Grove</b> beyond Cosmic: glowing mushrooms and a Giant Spider guardian",
			"Hatch <b>Shroomling, Glow Deer and Wisp Lynx</b>",
			"Ride <b>Jump</b> to reach mushroom escape caps; leave before they soften",
			"The safe zone has a new <b>home road</b> to guide you back to your base",
		},
	},
	{
		version = 3,
		title = "Mystic Grove tune-up",
		lines = {
			"Mystic Grove has a <b>clear path</b> down the middle",
			"The <b>mushroom caps</b> now line the way to the exit: hop on one to catch your breath",
			"You can no longer get stuck under a mushroom cap",
		},
	},
	{
		version = 4,
		title = "Relentless guardians",
		lines = {
			"Leave a guardian's biome with its egg and it <b>follows you all the way home</b>, never far behind",
			"Once you're out of its biome it stays <b>enraged</b> until you're home or caught",
			"Faster rides win: upgrade your <b>Saddle</b> and pets to outrun it",
			"<b>Dash</b> can save you when it closes in",
			"Escape patches let you catch your breath, but the chase goes on",
			"Egg weights have been retuned for the new chase",
			"Speed Soda is now a <b>Speed Boost for 20s</b>",
		},
	},
	{
		version = 5,
		title = "Top players",
		lines = {
			"A new <b>Top Players</b> board in the Plaza shows the best three in the <b>whole game</b>, in their own outfits: top income, then rebirths, then Index",
			"New players are now <b>Squires</b> until their first title at 2 rebirths",
			"The Plaza leaderboards have a fresh wooden look",
			"Rebirthing now has a <b>keep fee</b>: about 1 hour of what the creatures you keep will earn",
			"Shop prices no longer drop when you move creatures out of your pen",
			"The Plaza got a festive makeover, and the shop stalls moved to the sides",
			"Gear sells out after <b>5 buys</b> of each kind and restocks 10 minutes later",
			"The speed meter now always shows your <b>real speed</b>, so you can check it against a guardian's",
			"A timer shows how long your <b>Speed Boost</b> lasts",
			"New <b>Top Collectors</b> board in the Plaza: the most Index entries in the whole game",
			"Upgrades moved to their own stall: <b>Sam the Saddler</b> sells Saddles, incubators and pen slots next to Gus's Gear Shop",
			"Rebirth 10 unlocks a <b>Base Expansion</b> behind your base: 10 more pen spots and 2 more incubators",
			"Nests hold <b>fewer eggs in quieter servers</b> and fill back up as players join",
			"<b>Enraged guardians</b> now flash a pulsing glow, kick up dust and let out a roar, and the Giant Spider drips venom",
		},
	},
}

-- the updates newer than `seen` (nil = never saw any), newest first
function Config.updatesSince(seen: number?, list: { any }?): { any }
	local out = {}
	list = list or Config.WhatsNew
	for i = #list, 1, -1 do
		if list[i].version > (seen or 0) then
			table.insert(out, list[i])
		end
	end
	return out
end

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
-- luck = roll twice, keep the better; luckyPass (LuckyPassChance) + rebirthUp (Config.rebirthLuck) = one chance to go one rarity up.
-- Shown in the Store before purchase (paid random item odds disclosure).
function Config.hatchOdds(luck: boolean?, luckyPass: boolean?, rebirthUp: number?): { number }
	local total, cum, odds = 0, 0, {}
	for i = 1, 5 do
		total += Config.Rarities[i].odds
	end
	for i = 1, 5 do
		local before = cum
		cum += Config.Rarities[i].odds / total
		odds[i] = if luck then cum ^ 2 - before ^ 2 else cum - before
	end
	local p = (luckyPass and Config.LuckyPassChance or 0) + (rebirthUp or 0)
	if p > 0 then
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
	AmbienceMysticGrove = 9112835068, -- existing authorised forest ambience, softer pitch in Studio
	-- escape patches: entry sound per lane ability, and the sink-warning tick
	PatchSwim = 9114455247, PatchJump = 2772396665, PatchGlide = 9113840530, PatchFireproof = 9114446852,
	PatchPhase = 9118158252, PatchTick = 134410911353980,
}
-- Escape soundtrack (APM Music): while you carry an egg through a biome its track plays over the ducked ambience,
-- calmer the closer to home; crossing the safe line with the egg plays the sting. Entry: { assetId, volume }
Config.EscapeMusic = {
	tracks = {
		MysticGrove = { 1842359824, 0.35 }, -- restrained drone under silk/chitter cues
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
		MysticGrove = { texture = eggSpark, color = rgb(130, 245, 210), color2 = rgb(195, 150, 245), size = { 0.24, 0.04 }, rate = 2, life = 2,
			speed = 0.65, light = 0.75, spread = 100, spin = 50, accel = 0.5, hatchCount = 24, sound = { 9116418035, 0.9, 0.45, 3 } },
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

-- Guardian signature VFX (client only, visual only). Tier 1 patrol, 2 chasing, 3 chasing outside its own biome,
-- 4 enraged; rate/size/light multiply each layer by tier. Layer fields as EggFX themes, plus: at = { x, y, z } attachment
-- offset as a fraction of the guardian's size (none = emit from the whole body), face = emit forward,
-- minTier, flare = extra particles when the tier rises, drag, trans = start transparency, locked = move with the body
-- (otherwise particles stream behind it).
-- step: burst at the feet on each footfall (count x tier); linger = seconds it keeps burning there from lingerTier.
-- rage: the enraged (tier 4) package EVERY guardian gets, so a new biome never ships without it. A biome's own
-- `rage` block only adds to it: extra layers, light color, its own roar sound and onset burst (Config.guardianRage).
local fx = "rbxasset://textures/particles/"
Config.GuardianFX = {
	distance = 260,
	tiers = { rate = { 1, 1.8, 2.7, 3.8 }, size = { 1, 1.12, 1.25, 1.45 }, light = { 1, 1.5, 2.2, 3.2 } },
	rage = {
		layers = { -- added to the guardian's own layers, tier 4 only (tier rate x3.8 applies)
			{ texture = fx .. "fire_sparks_main.dds", color = rgb(255, 210, 90), color2 = rgb(255, 40, 30), size = { 0.45, 0 },
				rate = 4, life = 1.3, speed = 6, spread = 180, accel = 5, light = 1, minTier = 4, flare = 40 },
			{ texture = fx .. "smoke_main.dds", color = rgb(150, 20, 20), color2 = rgb(60, 10, 10), size = { 2.4, 5 },
				rate = 0.8, life = 1.8, speed = 1, spread = 180, accel = 1, trans = 0.6, light = 0.2, locked = true, minTier = 4 },
		},
		light = { color = rgb(255, 50, 40), range = 30, brightness = 0.6, pulse = 0.4 }, -- pulses while enraged
		onset = { texture = fx .. "SquareParticle.png", color = rgb(255, 80, 50), color2 = rgb(255, 220, 120), size = { 1.6, 0 },
			count = 40, life = 0.6, speed = 45, spread = 180, drag = 5, light = 1, squash = 3 }, -- shockwave as it snaps
		sound = { 9113980319, 1.35, 0.55, 1.6 }, -- 3D roar from the guardian, heard by everyone nearby
		stepDust = 1.4, -- heavy dust under every footfall while enraged (x the guardian's normal puff), even light-footed ones
		chase = { pitch = 1.1, volume = 0.6 }, -- the chase loop speeds up and gets at least this loud
	},
	guardians = { -- sizes are tier 1; tier 4 is x1.45
		MysticGrove = { -- Spider: silk at the fangs, glowing spores around the abdomen, tiny chitin footsteps.
			layers = {
				{ texture = fx .. "smoke_main.dds", color = rgb(95, 235, 170), color2 = rgb(175, 100, 235), size = { 3.2, 6 },
					rate = 8, life = 2.6, speed = 1.2, spread = 160, light = 0.8, trans = 0.38, locked = true, flare = 16 },
				{ texture = fx .. "SquareParticle.png", color = rgb(220, 245, 235), color2 = rgb(120, 210, 190), size = { 1.4, 0.25 },
					rate = 14, life = 1.1, speed = 8, spread = 18, accel = -0.6, drag = 2, spin = 30, squash = 4,
					at = { 0, 0.08, -0.32 }, face = true, flare = 10, minTier = 2 },
				{ texture = fx .. "sparkles_main.dds", color = rgb(120, 245, 185), color2 = rgb(190, 125, 235), size = { 1.2, 0.15 },
					rate = 34, life = 2.8, speed = 2.2, spread = 160, accel = 0.4, light = 1, flare = 30 },
			},
			light = { color = rgb(115, 230, 185), range = 26, brightness = 0.8 },
			trail = { color = rgb(205, 255, 225), color2 = rgb(165, 105, 230), life = 0.65, minTier = 2 },
			step = { texture = fx .. "sparkles_main.dds", color = rgb(145, 225, 195), size = { 0.35, 0 }, count = 3,
				life = 0.55, speed = 4, spread = 35, accel = -4, light = 0.4 },
			rage = { -- venom drips off the fangs, a toxic violet haze, torn silk flung out as it snaps; a deep hiss
				layers = {
					{ texture = fx .. "sparkles_main.dds", color = rgb(170, 255, 90), color2 = rgb(60, 200, 80), size = { 0.6, 0.15 },
						rate = 6, life = 1, speed = 3, spread = 25, accel = -18, light = 1, at = { 0, 0.05, -0.36 }, face = true,
						minTier = 4, flare = 12 },
					{ texture = fx .. "smoke_main.dds", color = rgb(150, 60, 220), color2 = rgb(70, 220, 120), size = { 3, 7 },
						rate = 1.2, life = 2.2, speed = 1.5, spread = 180, accel = 0.5, trans = 0.55, light = 0.6, minTier = 4 },
				},
				light = { color = rgb(200, 60, 255) },
				onset = { texture = fx .. "SquareParticle.png", color = rgb(235, 255, 240), color2 = rgb(150, 255, 120), size = { 1.2, 0.2 },
					count = 36, life = 0.9, speed = 38, spread = 180, drag = 4, accel = -10, spin = 120, squash = 4 },
				sound = { 9125917896, 0.5, 0.8, 1.8 }, -- its own chitter, slowed into a hiss
			},
		},
		Forest = { -- Chicken: loose feathers drifting down
			layers = {
				{ texture = fx .. "SquareParticle.png", color = rgb(255, 252, 240), color2 = rgb(255, 200, 170), size = { 0.5, 0.4 },
					rate = 4, life = 3, speed = 6, spread = 180, accel = -1.6, drag = 1.6, spin = 160, squash = 0.6, flare = 8 },
			},
			step = { texture = fx .. "SquareParticle.png", color = rgb(255, 252, 240), size = { 0.5, 0.35 }, count = 2,
				life = 1.6, speed = 5, spread = 70, accel = -3, drag = 2, spin = 200, squash = 0.6 },
		},
		Lake = { -- Swan: a trail of glinting water drops
			layers = {
				{ texture = fx .. "sparkles_main.dds", color = rgb(120, 200, 255), color2 = rgb(220, 245, 255), size = { 1.1, 0.3 },
					rate = 14, life = 1.4, speed = 6, spread = 70, accel = -14, light = 1, flare = 14 },
			},
			step = { texture = fx .. "sparkles_main.dds", color = rgb(150, 215, 255), color2 = rgb(235, 250, 255), size = { 0.9, 0.2 },
				count = 8, life = 0.8, speed = 14, spread = 30, accel = -45, light = 1 },
		},
		Desert = { -- Scorpion: a haze of drifting sand and flying grains
			layers = {
				{ texture = fx .. "smoke_main.dds", color = rgb(220, 175, 105), color2 = rgb(200, 150, 90), size = { 2.8, 6.2 },
					rate = 3, life = 2.2, speed = 2, spread = 180, accel = 0.6, trans = 0.4, flare = 4 },
				{ texture = fx .. "SquareParticle.png", color = rgb(225, 180, 105), color2 = rgb(190, 140, 80), size = { 0.25, 0.17 },
					rate = 10, life = 1.2, speed = 7, spread = 90, accel = -14 },
			},
			step = { texture = fx .. "smoke_main.dds", color = rgb(225, 190, 130), size = { 2, 5 }, count = 4, life = 1.1,
				speed = 8, spread = 60, accel = -6, drag = 3, trans = 0.45 },
		},
		Jungle = { -- Tiger: falling leaves and a swarm of fireflies
			layers = {
				{ texture = fx .. "SquareParticle.png", color = rgb(120, 200, 60), color2 = rgb(230, 170, 50), size = { 0.55, 0.45 },
					rate = 5, life = 3, speed = 2.5, spread = 180, accel = -2, drag = 1.2, spin = 220, squash = 0.4, flare = 6 },
				{ texture = fx .. "sparkles_main.dds", color = rgb(240, 255, 120), size = { 0.75, 0 }, rate = 14, life = 2.4,
					speed = 4, spread = 180, light = 1, spin = 90, locked = true, flare = 10 },
			},
			step = { texture = fx .. "SquareParticle.png", color = rgb(120, 200, 60), color2 = rgb(230, 170, 50), size = { 0.55, 0.45 },
				count = 3, life = 1.8, speed = 7, spread = 70, accel = -6, drag = 2, spin = 260, squash = 0.4 },
		},
		Tundra = { -- Yeti: frosty breath and swirling snow
			layers = {
				{ texture = fx .. "smoke_main.dds", color = rgb(240, 250, 255), size = { 1.05, 3.8 }, rate = 5, life = 1.4,
					speed = 7, spread = 12, accel = 1.5, drag = 1.5, trans = 0.35, at = { 0, 0.12, -0.42 }, face = true, locked = true, flare = 6 },
				{ texture = fx .. "sparkles_main.dds", color = rgb(190, 225, 255), color2 = rgb(140, 200, 255), size = { 0.5, 0.07 },
					rate = 10, life = 2.6, speed = 3, spread = 180, accel = -2, light = 0.6, spin = 120, flare = 16 },
			},
			step = { texture = fx .. "sparkles_main.dds", color = rgb(200, 235, 255), size = { 0.7, 0.05 }, count = 10, life = 0.9,
				speed = 12, spread = 80, accel = -12, drag = 2, light = 0.8 },
		},
		Volcano = { -- Hellhound: a body on fire, rising embers, smoke, burning footprints
			layers = {
				{ texture = fx .. "fire_main.dds", color = rgb(255, 220, 110), color2 = rgb(220, 40, 10), size = { 3.1, 0.4 },
					rate = 30, life = 0.95, speed = 9, spread = 18, accel = 6, drag = 1, light = 0.15, spin = 60, trans = 0, flare = 30, locked = true },
				{ texture = fx .. "fire_sparks_main.dds", color = rgb(255, 210, 90), color2 = rgb(255, 90, 30), size = { 0.4, 0 },
					rate = 6, life = 2, speed = 7, spread = 60, accel = 7, light = 1, flare = 20 },
				{ texture = fx .. "smoke_main.dds", color = rgb(70, 45, 40), size = { 3.5, 8 }, rate = 1.5, life = 3,
					speed = 3, spread = 30, accel = 3, trans = 0.55, minTier = 2 },
			},
			light = { color = rgb(255, 120, 40), range = 26, brightness = 0.5 },
			step = { texture = fx .. "fire_main.dds", color = rgb(255, 200, 80), color2 = rgb(255, 70, 20), size = { 2.4, 0.4 },
				count = 6, life = 0.8, speed = 5, spread = 40, accel = 8, light = 1, linger = 2.5, lingerTier = 3, lingerRate = 10 },
		},
		Cosmic = { -- Dragon: a trail of stardust, nebula glow and wing streaks
			layers = {
				{ texture = fx .. "sparkles_main.dds", color = rgb(255, 225, 120), color2 = rgb(120, 230, 255), size = { 1.5, 0 },
					rate = 20, life = 2.4, speed = 1.2, spread = 180, light = 1, spin = 90, flare = 30 },
				{ texture = fx .. "smoke_main.dds", color = rgb(255, 120, 230), color2 = rgb(90, 160, 255), size = { 2.8, 6.2 },
					rate = 3, life = 3, speed = 0.8, spread = 180, light = 0.6, trans = 0.55, locked = true },
			},
			light = { color = rgb(170, 110, 255), range = 26, brightness = 0.5 },
			trail = { color = rgb(210, 150, 255), color2 = rgb(90, 200, 255), life = 0.5, minTier = 2 },
			step = { texture = fx .. "sparkles_main.dds", color = rgb(255, 225, 120), color2 = rgb(120, 230, 255), size = { 0.9, 0 },
				count = 12, life = 1.2, speed = 10, spread = 70, light = 1 },
		},
	},
}

-- a guardian's full enraged package: the shared one, plus (never instead of) its biome's own rage block
function Config.guardianRage(biomeId: string)
	local base, own = Config.GuardianFX.rage, (Config.GuardianFX.guardians[biomeId] or {}).rage or {}
	local layers = table.clone(base.layers)
	for _, l in own.layers or {} do table.insert(layers, l) end
	local light = table.clone(base.light)
	for k, v in own.light or {} do light[k] = v end
	-- the red shockwave always plays (the universal "it's enraged" read); its own voice replaces the generic roar
	return { layers = layers, light = light, onsets = { base.onset, own.onset }, sound = own.sound or base.sound,
		stepDust = own.stepDust or base.stepDust, chase = own.chase or base.chase }
end

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
	MysticGrove = { idle = { 9125917896, 0.65, 0.35, 1.8 }, alert = { 9119471684, 1.25, 0.65, 2 },
		chase = { 9119458695, 1.3, 0.35 }, step = { 9125914961, 1.6, 0.22 } }, -- familiar insect assets, lighter/faster spider mix
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
	{ key = "mystic", title = "Mystic Grove", body = "Beyond Cosmic, the Giant Spider guards Shroomling, Glow Deer and Wisp Lynx eggs. Ride Jump to leap onto raised mushroom caps. They hide you from guardians, but soften after 4 seconds. No Jump? Keep to the open paths and race home. Silk and glowing spores show the spider's chase intensity." },
	{ key = "basics", title = "How to play", body = "Steal an egg from a biome nest and run it home before the guardian catches you. Eggs incubate at home; when one says Ready, tap it to hatch. Creatures in your pen earn cash every second, and the one you ride sets your speed." },
	{ key = "controls", title = "Controls", body = "PC: F gets off all mounts, Q uses Dash, R takes off or lands a flying mount (Space up, Ctrl down). Phone/tablet: use the Get off, Fly and Dash buttons. Flyers: Vulture, Parrot, Snow Owl, Ember Bat and Baby Dragon. Carrying an egg forces a landing; deliver or drop it to fly again." },
	{ key = "creatures", title = "Stable, Pen and riding", body = "New creatures go to your Stable (holds 50), which earns nothing. Open the Stable and press Pen to put one to work, or Ride to mount it. Sell gives 60 seconds of its income. Mounted creatures don't earn." },
	{ key = "upgrades", title = "Saddle and upgrades", body = "At Sam's Upgrades stall in the Plaza, each Saddle level adds +1 speed to whatever you ride (up to 20). Buy more incubators to hatch more eggs at once, and more pen slots to earn from more creatures. From Rebirth 10 you can buy the lot behind your base for 10 more pen slots and 2 more incubators." },
	{ key = "nests", title = "Nests and guardians", body = "Every nest refills with new eggs every 5 minutes (the timer is top right). Deeper biomes give better creatures but heavier eggs: you carry slower and sharp turns slow you more. Leave a guardian's biome with its egg and it follows you all the way home, enraged and never far behind: outrun it, Dash when it closes in, or catch your breath on an escape patch." },
	{ key = "patches", when = "first visit to the Lake or deeper", title = "Escape patches", body = "From the Lake onward, each biome has patches the guardian can't reach you on, if you ride the right ability (Swim, Jump, Glide, Fireproof, Phase). Don't stay on one for more than 4 seconds or you sink and get stuck for 2." },
	{ key = "gear", title = "Gear", body = "Buy gear at the Gear Shop in the Plaza. Net Gun slows a player, Slip Trap slows whoever steps on it (guardians too), Speed Soda makes you faster for 20 seconds." },
	{ key = "pvp", when = "your new-player shield ends", title = "Stealing from players", body = "Your first 15 minutes are shielded: nobody can steal from you, and you can't steal. After that, tap Steal Egg near someone carrying an egg to take it, or walk into an unlocked base and hold Steal Egg on an incubator. Victims get 10 seconds to catch you and Take Back." },
	{ key = "robbed", when = "someone steals from you", title = "Protect your eggs", body = "Chase the thief and tap Take Back within 10 seconds. Press the red Lock button at your base to keep raiders out for 60 seconds (+10 per rebirth). Your base also locks for 30 seconds when you join." },
	{ key = "weather", when = "the first weather event", title = "Weather", body = "Thunderstorm, Golden Hour and Blood Moon give eggs you grab a chance of a mutation that boosts income and speed. Blood Moon also makes guardians faster." },
	{ key = "mama", when = "Mama Dragon's first warning", title = "Mama Dragon", body = "She snatches eggs from bases. Click her glowing weak spot, which moves every few seconds. Jump or run out of the red ring before she stomps. Hits knock eggs loose: grab them! Your hits earn 1.25x speed (50), 2x cash (75) and a Lucky Egg (100)." },
	{ key = "secret", when = "the first Secret Egg", title = "Secret Egg", body = "Every 7 minutes, a glowing egg appears from the Desert onward. It hatches Epic or better; deeper biomes give better Legendary and Mythic chances. Secret Eggs cut ordinary egg carry speed by another 20%, and carrying any egg grounds flyers. Every guardian in its biome hunts whoever takes it." },
	{ key = "fuse", title = "Fuse and Index", body = "At the Fuse Machine in the Plaza, fuse 3 of the same creature and rarity into 1 of the next rarity (not Legendary or Mythic). Each new Index entry pays cash; collect every rarity of a species to Master it for 1.25x income forever." },
	{ key = "rewards", title = "Free rewards", body = "Do Quests (daily and weekly) and claim your Daily streak (day 7 is a Luck Potion). Open the free Plaza chest every 4 hours. While you're offline, your pen earns at half rate for up to 8 hours." },
	{ key = "rebirth", when = "you can afford a rebirth", title = "Rebirth", body = "Rebirth needs cash and a creature from a deeper biome (shown in the Rebirth menu). It resets your cash, eggs, creatures, Saddle and gear for a permanent income boost and a reward. You keep bought incubators and pen slots, your Index, and the creatures you pick (1, +1 every 4 rebirths) for a keep fee of about 1 hour of their income. Every 2 rebirths earns a Lord title; rebirths 10 and 20 add permanent hatch luck." },
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
