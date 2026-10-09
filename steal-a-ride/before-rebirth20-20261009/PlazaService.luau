-- Plaza: Gear Shop / Index Board prompts, global leaderboards, the server showcase, the free reward chest,
-- shopkeeper animations and bench seats.
-- The structures are map parts (ServerStorage.BuildTools.BuildPlaza); this service makes them work.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)

local Notify = ReplicatedStorage.Remotes.Notify
local P = Config.Plaza
local rgb = Color3.fromRGB

local PlazaService = {}
PlazaService.onChest = nil

-- Rarest first, then income; one creature per owner before anyone gets a second pedestal.
-- entries: { owner, uid, creature, income }; returns up to `count` of them.
function PlazaService.pickShowcase(entries, count: number)
	table.sort(entries, function(a, b)
		local ra, rb = Config.RarityById[a.creature.rarity].index, Config.RarityById[b.creature.rarity].index
		if ra ~= rb then return ra > rb end
		if a.income ~= b.income then return a.income > b.income end
		return a.uid < b.uid
	end)
	local picked, owners = {}, {}
	for _, e in entries do
		if #picked < count and not owners[e.owner] then
			owners[e.owner] = true
			table.insert(picked, e)
		end
	end
	for _, e in entries do
		if #picked < count and not table.find(picked, e) then
			table.insert(picked, e)
		end
	end
	return picked
end

function PlazaService.chestReward(incomePerSecond: number): number
	return math.max(P.chestMin, math.floor(incomePerSecond * P.chestSeconds))
end

local function prompt(part, name, action, object)
	local p = Instance.new("ProximityPrompt")
	p.Name, p.ActionText, p.ObjectText = name, action, object
	p.HoldDuration, p.MaxActivationDistance, p.RequiresLineOfSight = 0, 14, false
	p.Parent = part
	return p
end

local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency, t.Font, t.TextScaled, t.TextColor3, t.RichText = 1, Enum.Font.FredokaOne, true, rgb(255, 255, 255), true
	for k, v in props do t[k] = v end
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = rgb(25, 30, 40), 2
	stroke.Parent = t
	t.Parent = parent
	return t
end

----------------------------------------------------------------------------- leaderboards
local boards = {} -- { store, rows, valueOf, format, written = {[userId] = value} }
local names = {}
local function nameOf(userId: number): string
	if not names[userId] then
		local player = Players:GetPlayerByUserId(userId)
		local ok, name = pcall(function() return player and player.DisplayName or Players:GetNameFromUserIdAsync(userId) end)
		names[userId] = ok and name or "Player"
	end
	return names[userId]
end

local MEDALS = { rgb(255, 210, 80), rgb(215, 225, 240), rgb(225, 150, 90) }
local function buildBoard(model, title: string)
	local screen = model:WaitForChild("Screen")
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud = "Board", Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
	gui.LightInfluence, gui.MaxDistance = 0, 150
	gui.Parent = screen
	local frame = Instance.new("Frame")
	frame.Size, frame.BackgroundColor3 = UDim2.fromScale(1, 1), rgb(35, 38, 56)
	frame.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0), UDim.new(0.05, 0), UDim.new(0.05, 0)
	pad.Parent = frame
	label(frame, { Size = UDim2.fromScale(1, 0.15), Text = title, TextColor3 = rgb(255, 210, 80) })
	local rows = {}
	for i = 1, 10 do
		rows[i] = label(frame, { Position = UDim2.fromScale(0, 0.17 + (i - 1) * 0.083), Size = UDim2.fromScale(1, 0.075),
			TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = MEDALS[i] or rgb(225, 230, 245) })
	end
	rows[1].Text = "Loading..."
	return rows
end

local function refreshBoard(board)
	local ok, page = pcall(function() return board.store:GetSortedAsync(false, 10):GetCurrentPage() end)
	if not ok then
		board.rows[1].Text = board.rows[1].Text == "Loading..." and "Leaderboard unavailable right now" or board.rows[1].Text
		return
	end
	for i = 1, 10 do
		local entry = page[i]
		board.rows[i].Text = entry and ("%d.  %s  —  %s"):format(i, nameOf(tonumber(entry.key)), board.format(entry.value))
			or (i == 1 and "No one yet. Be the first!" or "")
	end
end

local function writeScore(board, player, data)
	local value = math.floor(board.valueOf(player, data))
	if value <= 0 or board.written[player.UserId] == value or player:GetAttribute("DataLoadFailed") then return end
	local ok = pcall(function()
		if board.monotonic then
			board.store:UpdateAsync(tostring(player.UserId), function(old) return math.max(old or 0, value) end)
		else
			board.store:SetAsync(tostring(player.UserId), value)
		end
	end)
	if ok then board.written[player.UserId] = value end
end

local function writeScores()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			for _, board in boards do writeScore(board, player, data) end
		end
	end
end

function PlazaService.onPlayerLeaving(player)
	local data = DataService.get(player) -- before Main releases the profile
	for _, board in boards do
		if data then writeScore(board, player, data) end
		board.written[player.UserId] = nil
	end
	names[player.UserId] = nil
end

----------------------------------------------------------------------------- showcase
local shown = {} -- [pedestal] = key of what's on it
local function showcase()
	local pedestals = workspace.Plaza.Showcase:GetChildren()
	local list = {}
	for _, p in pedestals do if p.Name:match("^Pedestal%d$") then table.insert(list, p) end end
	table.sort(list, function(a, b) return a.Name < b.Name end)
	local entries = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		for uid, c in data and data.Creatures or {} do
			table.insert(entries, { owner = player, uid = uid, creature = c, income = Config.income(c, data.Rebirths, data.Index) })
		end
	end
	local picked = PlazaService.pickShowcase(entries, #list)
	for i, pedestal in list do
		local e = picked[i]
		local key = e and (e.owner.UserId .. ":" .. e.uid .. ":" .. e.creature.rarity) or ""
		if shown[pedestal] ~= key then
			shown[pedestal] = key
			local old = pedestal:FindFirstChild("Display")
			if old then old:Destroy() end
			local tag = pedestal:FindFirstChild("Tag") or Instance.new("BillboardGui")
			tag.Name, tag.Size, tag.StudsOffsetWorldSpace, tag.MaxDistance = "Tag", UDim2.fromScale(8, 2.4), Vector3.new(0, 1.5, 0), 90
			tag.Adornee, tag.Parent = pedestal, pedestal
			local text = tag:FindFirstChild("Text") or label(tag, { Name = "Text", Size = UDim2.fromScale(1, 1) })
			if e then
				local c, rarity = e.creature, Config.RarityById[e.creature.rarity]
				local model = CreatureBuilder.build(c.species, c.rarity, c.mutation)
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then part.Anchored, part.CanCollide = true, false end
				end
				local top = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
				CreatureBuilder.placeOn(model, CFrame.lookAt(top, top + Vector3.new(1, 0, 0))) -- face the middle of the square
				model.Name = "Display"
				model.Parent = pedestal
				local box, size = model:GetBoundingBox()
				tag.StudsOffsetWorldSpace = Vector3.new(0, box.Position.Y + size.Y / 2 - pedestal.Position.Y + 1.5, 0)
				text.Text = ('%s\n<font color="#%s">%s%s %s</font>'):format(e.owner.DisplayName, rarity.color:ToHex(),
					c.mutation and (c.mutation .. " ") or "", rarity.id, Config.Species[c.species].display)
			else
				tag.StudsOffsetWorldSpace = Vector3.new(0, pedestal.Size.Y / 2 + 1.5, 0)
				text.Text = "" -- empty spots stay unlabeled
			end
		end
	end
end

----------------------------------------------------------------------------- reward chest
local function syncChest(player)
	local data = DataService.get(player)
	if data then
		player:SetAttribute("ChestReadyAt", (data.LastChest or 0) + P.chestCooldown)
	end
end

local function openChest(player)
	local data = DataService.get(player)
	if not data then return end
	local left = (data.LastChest or 0) + P.chestCooldown - os.time()
	if left > 0 then
		return Notify:FireClient(player, "toast", ("The chest refills in %dh %02dm"):format(left // 3600, left % 3600 // 60))
	end
	local reward = PlazaService.chestReward(CreatureService.incomeOf(player))
	data.LastChest = os.time()
	DataService.addCash(player, reward)
	if PlazaService.onChest then PlazaService.onChest(player) end
	syncChest(player)
	Notify:FireClient(player, "toast", ("Plaza chest: +$%s!"):format(Format.number(reward)))
end

function PlazaService.onPlayerReady(player)
	syncChest(player)
end

-- Shopkeepers idle behind their counters and wave when someone uses their stall (Roblox's default R15 animations)
local function startKeepers(plaza)
	local waves = {}
	for _, shop in { plaza.GearShop, plaza.FuseMachine, plaza.IndexBoard } do
		local hum = shop:FindFirstChild("Keeper") and shop.Keeper:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			local function load(id)
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				return animator:LoadAnimation(anim)
			end
			local idle = load("rbxassetid://507766666")
			idle.Looped = true
			idle:Play()
			waves[shop] = load("rbxassetid://507770239")
			waves[shop].Priority = Enum.AnimationPriority.Action
		end
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local wave = prompt.Parent and waves[prompt.Parent.Parent]
		if wave and not wave.IsPlaying then wave:Play() end
	end)
end

-- Bench seats are for walkers: a rider who bumps into one is stood back up
local function guardSeats(plaza)
	for _, seat in plaza.Decor:GetChildren() do
		if seat:IsA("Seat") then
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				local hum = seat.Occupant
				local player = hum and Players:GetPlayerFromCharacter(hum.Parent)
				if player and player:GetAttribute("Riding") then
					local weld = seat:FindFirstChild("SeatWeld")
					if weld then weld:Destroy() end
					hum.Sit = false
				end
			end)
		end
	end
end

function PlazaService.start()
	local plaza = workspace:WaitForChild("Plaza")
	startKeepers(plaza)
	guardSeats(plaza)
	-- the client opens the matching panel when these are triggered (like the Fuse Machine)
	prompt(plaza.GearShop.Body, "GearShopPrompt", "Open Gear Shop", "Nets, traps, speed soda")
	prompt(plaza.IndexBoard.Body, "IndexBoardPrompt", "Open Index", "Every creature you've found")
	local chest = plaza.RewardChest.Body
	prompt(chest, "RewardChestPrompt", "Open Chest", "Free cash every 4 hours").Triggered:Connect(openChest)
	local timer = Instance.new("BillboardGui") -- each client writes its own countdown into Text
	timer.Name, timer.Size, timer.StudsOffset, timer.MaxDistance = "Timer", UDim2.fromScale(10, 1.6), Vector3.new(0, chest.Size.Y / 2 + 2.5, 0), 90
	timer.Parent = chest
	label(timer, { Name = "Text", Size = UDim2.fromScale(1, 1), Text = "" })

	boards = {
		{ rows = buildBoard(plaza.Leaderboards.TopIncome, "Top Income"), written = {},
			store = DataStoreService:GetOrderedDataStore(Config.DataStoreName .. "_TopIncome"),
			valueOf = function(player) return CreatureService.incomeOf(player) end,
			format = function(v) return "$" .. Format.number(v) .. "/s" end },
		{ rows = buildBoard(plaza.Leaderboards.TopRebirths, "Most Rebirths"), written = {},
			store = DataStoreService:GetOrderedDataStore(Config.DataStoreName .. "_TopRebirths"),
			valueOf = function(_, data) return data.Rebirths or 0 end,
			format = function(v) return Format.number(v) .. (v == 1 and " rebirth" or " rebirths") end },
		{ rows = buildBoard(plaza.Leaderboards.TopBases, "Top Bases"), written = {}, monotonic = true,
			store = DataStoreService:GetOrderedDataStore(Config.DataStoreName .. "_TopLikes"),
			valueOf = function(_, data) return data.Likes or 0 end,
			format = function(v) return Format.number(v) .. (v == 1 and " like" or " likes") end },
	}
	task.spawn(function()
		while true do
			writeScores()
			for _, board in boards do refreshBoard(board) end
			task.wait(P.boardRefresh)
		end
	end)
	task.spawn(function()
		while true do
			pcall(showcase) -- a bad save entry must never stop the loop
			task.wait(P.showcaseRefresh)
		end
	end)
	game:BindToClose(writeScores)
end

return PlazaService
