-- Top Players board (Plaza centre back): the 3 best players in this server by rebirths, then creature index, then
-- income. The board is map parts (ServerStorage.BuildTools.BuildTopPlayers); this service writes each card and stands
-- the player's own avatar on their card's ledge.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)

local TopPlayersService = {}

-- entries: { key, rebirths, index, income, order }; returns a new list of the best 3, best first
function TopPlayersService.rank(entries)
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		if a.rebirths ~= b.rebirths then return a.rebirths > b.rebirths end
		if a.index ~= b.index then return a.index > b.index end
		if a.income ~= b.income then return a.income > b.income end
		return a.order < b.order
	end)
	local top = {}
	for i = 1, math.min(3, #list) do
		top[i] = list[i]
	end
	return top
end

-- discovered species + rarity combos (keys of data.Index)
function TopPlayersService.indexCount(index): number
	local n = 0
	for _ in index or {} do
		n += 1
	end
	return n
end

function TopPlayersService.cardText(e)
	return { name = e.name, title = Config.rebirthTitle(e.rebirths), index = "Index " .. e.index,
		income = "$" .. Format.number(e.income) .. "/s" }
end

local T = Config.TopPlayers
local rgb = Color3.fromRGB
local MEDAL = { rgb(255, 205, 80), rgb(205, 212, 225), rgb(214, 135, 80) }
local MEDAL_TEXT = { rgb(70, 45, 5), rgb(40, 44, 55), rgb(60, 28, 10) }
local cards = {} -- [rank] = { part, ledge, waiting, name, title, index, income }
local figures = {} -- [userId] = Model standing on a ledge
local building, retryAt = {}, {} -- [userId] = true while CreateHumanoidModelFromUserId runs / os.clock() of the next try
local joined, joinCount = {}, 0
local current = {} -- [rank] = userId on the board

local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency, t.Font, t.TextScaled, t.TextColor3 = 1, Enum.Font.FredokaOne, true, rgb(255, 255, 255)
	for k, v in props do t[k] = v end
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = rgb(30, 18, 10), 2
	stroke.Parent = t
	t.Parent = parent
	return t
end

-- card face (fractions from the top): badge 0-0.14, figure zone 0.14-0.58 (the ledge top sits at 0.58), then from 0.635 name,
-- title, index and income rows
local function buildCard(rank, part, ledge)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud = "Card", Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
	gui.LightInfluence, gui.MaxDistance = 0, 150
	gui.Parent = part
	local badge = Instance.new("Frame")
	badge.AnchorPoint, badge.Position, badge.Size = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.015), UDim2.fromScale(0.26, 0.11)
	badge.BackgroundColor3 = MEDAL[rank]
	badge.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = badge
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = badge
	label(badge, { Size = UDim2.fromScale(1, 1), Text = tostring(rank), TextColor3 = MEDAL_TEXT[rank] })
	local function row(y, h, color)
		return label(gui, { Position = UDim2.fromScale(0.06, y), Size = UDim2.fromScale(0.88, h), Text = "", TextColor3 = color })
	end
	cards[rank] = {
		part = part, ledge = ledge,
		waiting = row(0.3, 0.12, rgb(190, 170, 150)),
		name = row(0.635, 0.08, MEDAL[rank]),
		title = row(0.725, 0.07, rgb(205, 190, 255)),
		index = row(0.81, 0.07, rgb(245, 235, 220)),
		income = row(0.895, 0.075, rgb(255, 225, 140)),
	}
end

local function setText(card, text)
	card.waiting.Text = text and "" or T.waiting
	card.name.Text = text and text.name or ""
	card.title.Text = text and text.title or ""
	card.index.Text = text and text.index or ""
	card.income.Text = text and text.income or ""
end

-- stand the figure on its card's ledge, scaled to the card's figure zone; destroy it if its player left the board
local function place(userId)
	local fig = figures[userId]
	if not fig then return end
	local rank = table.find(current, userId)
	if not rank then
		fig:Destroy()
		figures[userId] = nil
		return
	end
	local card = cards[rank]
	local maxH = card.part.Size.Y * 0.44
	fig.Parent = workspace.Plaza.TopPlayers -- joints only lay the body out once it is in the world: measure after
	fig:ScaleTo(1)
	local _, size = fig:GetBoundingBox()
	fig:ScaleTo(math.min(1, maxH / size.Y))
	local box, scaled = fig:GetBoundingBox()
	local pivotToBottom = fig:GetPivot().Position.Y - (box.Position.Y - scaled.Y / 2)
	local top = card.ledge.Position + Vector3.new(0, card.ledge.Size.Y / 2, 0)
	fig:PivotTo(CFrame.new(top.X, top.Y + pivotToBottom, top.Z)) -- default orientation looks -Z, at the arch
end

local function build(player)
	local userId = player.UserId
	if figures[userId] or building[userId] or os.clock() < (retryAt[userId] or 0) then return end
	building[userId] = true
	task.spawn(function()
		local ok, fig = pcall(Players.CreateHumanoidModelFromUserId, Players, userId)
		building[userId] = nil
		if not ok or not fig then
			retryAt[userId] = os.clock() + T.retry
			return
		end
		fig.Name = "Figure_" .. userId
		for _, d in fig:GetDescendants() do
			if d:IsA("BaseScript") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, true
				d.CollisionGroup = "TopPlayersFigures" -- the Humanoid keeps its torso CanCollide on; the group never collides
			end
		end
		local hum = fig:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			hum.EvaluateStateMachine = false -- a statue: no states, so it never turns its parts' collision back on
			local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = hum
			fig.HumanoidRootPart.Anchored = true
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://507766666" -- default R15 idle, as the shopkeepers use
			local idle = animator:LoadAnimation(anim)
			idle.Looped = true
			idle:Play()
		elseif fig.PrimaryPart then
			fig.PrimaryPart.Anchored = true
		end
		figures[userId] = fig
		place(userId) -- destroys it if the player dropped off the board while it was building
	end)
end

local function entries()
	local list = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			table.insert(list, { key = player, name = player.DisplayName, rebirths = data.Rebirths or 0,
				index = TopPlayersService.indexCount(data.Index), income = CreatureService.incomeOf(player),
				order = joined[player] or math.huge })
		end
	end
	return list
end

function TopPlayersService.refresh()
	if #cards < 3 then return end
	local top = TopPlayersService.rank(entries())
	local was = current
	current = {}
	for rank = 1, 3 do
		local e = top[rank]
		current[rank] = e and e.key.UserId
		setText(cards[rank], e and TopPlayersService.cardText(e))
	end
	for _, userId in was do
		if not table.find(current, userId) and figures[userId] then
			figures[userId]:Destroy()
			figures[userId] = nil
		end
	end
	for rank = 1, 3 do
		local e = top[rank]
		if e then
			if figures[e.key.UserId] then
				if was[rank] ~= e.key.UserId then place(e.key.UserId) end
			else
				build(e.key)
			end
		end
	end
end

function TopPlayersService.start()
	PhysicsService:RegisterCollisionGroup("TopPlayersFigures")
	PhysicsService:CollisionGroupSetCollidable("TopPlayersFigures", "Default", false)
	local function join(player)
		joinCount += 1
		joined[player] = joinCount
	end
	for _, player in Players:GetPlayers() do join(player) end
	Players.PlayerAdded:Connect(function(player)
		join(player)
		TopPlayersService.refresh()
	end)
	Players.PlayerRemoving:Connect(function(player)
		joined[player], retryAt[player.UserId] = nil, nil
		task.defer(TopPlayersService.refresh) -- after the player is gone from GetPlayers
	end)
	task.spawn(function() -- waits for the board off the startup path, so a missing board never delays Main
		local board = workspace:WaitForChild("Plaza"):WaitForChild("TopPlayers", 30)
		if not board then
			warn("TopPlayersService: workspace.Plaza.TopPlayers is missing (run ServerStorage.BuildTools.BuildTopPlayers)")
			return
		end
		for rank = 1, 3 do
			buildCard(rank, board:WaitForChild("Card" .. rank), board:WaitForChild("Ledge" .. rank))
		end
		while true do
			TopPlayersService.refresh()
			task.wait(T.refresh)
		end
	end)
end

return TopPlayersService
