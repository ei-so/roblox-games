-- Base expansion: the lot behind each base (docs/superpowers/specs/2026-10-10-base-expansion-design.md). Rebirth 10 +
-- max($50B, 6 h of price income), bought at the For Sale sign on the back wall. The map parts are built once by
-- ServerStorage.BuildTools.BuildBaseExpansion; this service only switches a plot between locked and bought for its owner.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local HatchService = require(script.Parent.HatchService)

local Notify = ReplicatedStorage.Remotes.Notify
local E = Config.Expansion

local ExpansionService = {}
-- after a purchase: repaint the whole base so tier decor (glass domes) appears over the new pads too. Main sets it to
-- BaseService.apply, whose afterApply calls ExpansionService.apply.
ExpansionService.onBought = function(player) ExpansionService.apply(player) end

-- pure purchase rule; reason: "rebirth" | "owned" | "cash"
function ExpansionService.canBuy(data, price: number): (boolean, string?)
	if data.BaseExpanded then
		return false, "owned"
	elseif (data.Rebirths or 0) < E.rebirth then
		return false, "rebirth"
	elseif data.Cash < price then
		return false, "cash"
	end
	return true
end

local function priceOf(player): number
	return Config.expansionPrice(CreatureService.priceIncomeOf(player))
end

local function show(p, visible: boolean, solid: boolean?)
	p.Transparency = visible and 0 or 1
	if solid ~= nil then
		p.CanCollide = solid
	end
end

-- world-space half extents of an oriented box
local function extents(cf, size)
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	return math.abs(x.X) * size.X / 2 + math.abs(y.X) * size.Y / 2 + math.abs(z.X) * size.Z / 2,
		math.abs(x.Y) * size.X / 2 + math.abs(y.Y) * size.Y / 2 + math.abs(z.Y) * size.Z / 2,
		math.abs(x.Z) * size.X / 2 + math.abs(y.Z) * size.Y / 2 + math.abs(z.Z) * size.Z / 2
end

-- does this decor item (Model or part) reach into the back-wall opening: within 2 studs of the wall line, across the
-- opening's width, below topY
local function blocksOpening(item, backX, centreZ, topY): boolean
	local cf, size
	if item:IsA("Model") then
		cf, size = item:GetBoundingBox()
	elseif item:IsA("BasePart") then
		cf, size = item.CFrame, item.Size
	else
		return false
	end
	local hx, hy, hz = extents(cf, size)
	local c = cf.Position
	return math.abs(c.X - backX) < hx + 2 and math.abs(c.Z - centreZ) < hz + E.gap / 2 and c.Y - hy < topY
end

-- hide a decor item for good (until BaseService repaints): invisible, walk-through, dark and silent, no prompts, and
-- renamed so the owner's Lights toggle (it relights children named "Lamp") skips it
local function clearDecor(item)
	for _, d in { item, unpack(item:GetDescendants()) } do
		if d:IsA("BasePart") then
			d.Transparency, d.CanCollide = 1, false
		elseif d:IsA("Light") or d:IsA("Fire") or d:IsA("ParticleEmitter") or d:IsA("Beam") then
			d.Enabled = false
		elseif d:IsA("Sound") then
			d.Playing = false
		elseif d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	item.Name = "ClearedDecor"
end

-- locked: opening closed, fence + sign up, lot pens/pads hidden. bought: opening open, fence + sign gone, the lot takes
-- the base's look (renderPen / HatchService then show its pens and pads as owned or not).
function ExpansionService.setState(plot, expanded: boolean)
	local lot = plot:FindFirstChild("Expansion")
	if not lot then
		return
	end
	plot:SetAttribute("Expanded", expanded)
	local wall, fence
	for _, p in plot:GetChildren() do
		if p.Name == "Wall" then wall = p end
	end
	for _, p in plot:FindFirstChild("Enclosure") and plot.Enclosure:GetChildren() or {} do
		if p.Name == "Fence" then fence = p end
	end
	lot.BackGap.CanCollide = not expanded
	lot.BackGap.Transparency = expanded and 1 or (wall and wall.Transparency or 0)
	lot.GapFence.CanCollide = not expanded
	lot.GapFence.Transparency = expanded and 1 or 0.3
	lot.GapInvisible.CanCollide = not expanded
	for _, p in lot.Fence:GetDescendants() do
		if p:IsA("BasePart") then show(p, not expanded) end
	end
	show(lot.Sign, not expanded, not expanded)
	lot.Sign.Board.Enabled = not expanded
	local prompt = lot.Sign:FindFirstChild("ExpansionPrompt")
	if prompt then
		prompt:SetAttribute("OnlyFor", 0) -- nobody until setSign offers it to an owner at Rebirth 10
	end
	for _, p in lot:GetChildren() do
		if p.Name == "SignPost" then show(p, not expanded) end
	end
	lot.Floor.Color, lot.Floor.Material, lot.Floor.MaterialVariant = plot.Floor.Color, plot.Floor.Material, plot.Floor.MaterialVariant
	for _, p in lot:GetChildren() do
		if p.Name == "LotWall" and wall then
			p.Color, p.Material, p.Transparency = wall.Color, wall.Material, wall.Transparency
		elseif (p.Name == "LotFence" or p.Name == "GapFence") and fence then
			p.Color = fence.Color
		end
	end
	if wall then
		lot.BackGap.Color, lot.BackGap.Material = wall.Color, wall.Material
	end
	local decor = plot:FindFirstChild("BaseDecor") -- rebuilt by BaseService's paint, which always runs before this
	if expanded and decor then
		-- base cosmetics on the back wall (banners, lamps) that reach into the new opening are cleared, whole item at once
		local floor = plot.Floor
		local backX = floor.Position.X + plot:GetAttribute("Side") * (floor.Size.X / 2 + 0.5)
		for _, item in decor:GetChildren() do
			if blocksOpening(item, backX, floor.Position.Z, floor.Position.Y + 15) then
				clearDecor(item)
			end
		end
	end
	if not expanded then
		for _, ped in plot.Pen:GetChildren() do
			if Config.hiddenSlot(ped:GetAttribute("Slot") or 0, "pen", false) then show(ped, false) end
		end
		for _, pad in plot.Incubators:GetChildren() do
			if Config.hiddenSlot(pad:GetAttribute("Slot") or 0, "incubator", false) then
				show(pad, false)
				if pad:FindFirstChild("Ring") then show(pad.Ring, false) end
				-- tier decor drawn over every pad (glass domes) would float in the closed lot
				for _, p in decor and decor:GetDescendants() or {} do
					local d = p:IsA("BasePart") and p.Position - pad.Position
					if d and math.abs(d.X) < 1 and math.abs(d.Z) < 1 then
						p.Transparency = 1
					end
				end
			end
		end
	end
end

local function setSign(plot, data, player)
	local lot = plot:FindFirstChild("Expansion")
	if not lot or data.BaseExpanded then
		return
	end
	local ready = (data.Rebirths or 0) >= E.rebirth
	lot.Sign.Board.Line1.Text = ready and ("Base Expansion  $" .. Format.number(priceOf(player))) or "Unlocks at Rebirth 10"
	local prompt = lot.Sign:FindFirstChild("ExpansionPrompt")
	if prompt then
		-- ClientMain shows an OnlyFor prompt only to that player: the owner, once they can buy
		prompt:SetAttribute("OnlyFor", ready and player.UserId or 0)
	end
end

-- a plot nobody owns (or a new owner's plot before apply) shows the lot for sale. Anyone still standing in the lot
-- goes to the front of the base first: the closed lot is walled in up to the flight ceiling.
function ExpansionService.reset(plot)
	local lot = plot:FindFirstChild("Expansion")
	if lot and plot:GetAttribute("Expanded") then
		local floor, lotFloor = plot.Floor, lot.Floor
		for _, other in Players:GetPlayers() do
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local d = root and root.Position - lotFloor.Position
			if d and math.abs(d.X) < lotFloor.Size.X / 2 + 0.5 and math.abs(d.Z) < lotFloor.Size.Z / 2 + 0.5 then
				-- same spot StealService's locked-base push-out uses
				PlotService.teleport(other.Character, CFrame.new(floor.Position.X - plot:GetAttribute("Side") * 36, 4, floor.Position.Z))
			end
		end
	end
	ExpansionService.setState(plot, false)
	local lot = plot:FindFirstChild("Expansion")
	if lot then
		lot.Sign.Board.Line1.Text = "Unlocks at Rebirth 10"
	end
end

-- the owner's state on whatever plot they got: only the save flag decides
function ExpansionService.apply(player)
	local plot = PlotService.get(player)
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	ExpansionService.setState(plot, data.BaseExpanded == true)
	setSign(plot, data, player)
	CreatureService.changed(player) -- lot pens show as owned / not owned
	HatchService.onPlayerReady(player) -- lot incubator pads too
end

-- refresh the owner's sign as soon as something that changes the price or the unlock changes (VIP and friend bonus
-- arrive after the join's first apply; the 2 s loop still covers creature changes)
function ExpansionService.watch(player)
	local function refresh()
		local plot, data = PlotService.get(player), DataService.get(player)
		if plot and data then
			setSign(plot, data, player)
		end
	end
	for _, key in { "VIPPass", "FriendCount", "Rebirths" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
end

function ExpansionService.buy(player): boolean
	local plot = PlotService.get(player)
	local data = DataService.get(player)
	if not plot or not data or plot:GetAttribute("OwnerUserId") ~= player.UserId then
		Notify:FireClient(player, "toast", "This lot belongs to another player")
		return false
	end
	local price = priceOf(player)
	local ok, why = ExpansionService.canBuy(data, price)
	if not ok then
		if why == "rebirth" then
			Notify:FireClient(player, "toast", "The Base Expansion unlocks at Rebirth 10")
		elseif why == "cash" then
			Notify:FireClient(player, "toast", ("The Base Expansion costs $%s"):format(Format.number(price)))
		end
		return false
	end
	DataService.addCash(player, -price)
	data.BaseExpanded = true
	ShopService.sync(player)
	ExpansionService.onBought(player)
	Notify:FireClient(player, "toast", "Your base expanded! Buy new pen slots and incubators at Sam's Upgrades stall.")
	return true
end

function ExpansionService.start()
	for _, plot in workspace.HomeRow.Plots:GetChildren() do
		local lot = plot:FindFirstChild("Expansion")
		if lot then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name, prompt.ActionText, prompt.ObjectText = "ExpansionPrompt", "Buy Base Expansion", "10 pen spots + 2 incubators"
			prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.5, 12, false
			prompt.Parent = lot.Sign
			prompt.Triggered:Connect(function(player)
				-- the prompt sits on every plot: only a trigger on your own plot can buy
				if PlotService.get(player) == plot then
					ExpansionService.buy(player)
				else
					Notify:FireClient(player, "toast", "This lot belongs to another player")
				end
			end)
			ExpansionService.reset(plot)
		end
	end
	Players.PlayerAdded:Connect(ExpansionService.watch)
	for _, player in Players:GetPlayers() do
		ExpansionService.watch(player)
	end
	task.spawn(function() -- live price on each owner's sign (price income changes with their creatures)
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local plot, data = PlotService.get(player), DataService.get(player)
				if plot and data then
					setSign(plot, data, player)
				end
			end
		end
	end)
end

return ExpansionService
