-- Rebirth panel: shows what the next rebirth needs and gives, then a keep picker (ridden creatures pre-ticked) with a two-click confirm.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local gui = script.Parent
local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function styled(o, stroke)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, o)
	if stroke then new("UIStroke", { Color = WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
	if o:IsA("TextLabel") or o:IsA("TextButton") then new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5 }, o) end
	return o
end
local function text(props, parent)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE, RichText = true, Text = "" }, parent)
	for k, v in props do
		t[k] = v
	end
	return styled(t, false)
end

local menuButton = styled(new("TextButton", { Name = "RebirthButton", LayoutOrder = 4, Size = UDim2.new(0, 130, 0, 46), Text = "Rebirth",
	BackgroundColor3 = rgb(170, 90, 240), Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE }, gui:WaitForChild("LeftMenu")), true)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, menuButton)

local panel = styled(new("Frame", { Name = "RebirthPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.new(0, 520, 0, 394), BackgroundColor3 = rgb(35, 38, 56), Visible = false }, gui), true)
text({ Position = UDim2.new(0, 20, 0, 12), Size = UDim2.new(1, -90, 0, 40), Text = "Rebirth", TextXAlignment = Enum.TextXAlignment.Left }, panel)
local close = styled(new("TextButton", { Position = UDim2.new(1, -58, 0, 12), Size = UDim2.new(0, 44, 0, 40), Text = "X", BackgroundColor3 = rgb(220, 70, 70),
	Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE }, panel), false)
local body = text({ Position = UDim2.new(0, 24, 0, 64), Size = UDim2.new(1, -48, 0, 224), TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 22, TextWrapped = true }, panel)
local go = styled(new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(0, 260, 0, 56), Text = "Rebirth",
	BackgroundColor3 = rgb(170, 90, 240), Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE }, panel), false)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, go)

-- Keep picker: replaces the text body; rows toggle, the counter shows picked / limit
local counter = text({ Position = UDim2.new(0, 24, 0, 60), Size = UDim2.new(1, -48, 0, 26), TextColor3 = rgb(200, 210, 230),
	TextXAlignment = Enum.TextXAlignment.Left, Visible = false }, panel)
local list = new("ScrollingFrame", { Position = UDim2.new(0, 18, 0, 92), Size = UDim2.new(1, -36, 0, 172), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false }, panel)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local REWARDS = { incubator = "+1 incubator (a Lucky Egg if maxed)", pen = "+2 pen slots (a Lucky Egg if maxed)",
	mount = "2nd mount slot (ride two, get both abilities)", lucky = "a Lucky Egg of your best biome" }
local function rewardText(n, reward)
	if reward == "luck" then
		return ("Rebirth Luck: %d%% of hatches roll a rarity higher"):format(math.round(Config.rebirthLuck(n) * 100))
	end
	return REWARDS[reward]
end
local function titleLine(rebirths)
	local now, nextAt = Config.rebirthTitle(rebirths), (rebirths // 2 + 1) * 2
	local nextTitle = Config.rebirthTitle(nextAt)
	local line = ("<b>Title:</b> %s"):format(now or "none yet")
	if nextTitle and nextTitle ~= now then
		line ..= ("  ·  next: %s in %d"):format(nextTitle, nextAt - rebirths) -- one line even at "Divine Overlord"
	end
	return line
end
local armed = false
local picking, picked, limit = false, {}, 1
local fees = {} -- uid -> keep fee (server-computed, inventory keepFee)

local function pickedList()
	local uids = {}
	for uid in picked do table.insert(uids, uid) end
	return uids
end

local function refresh()
	local n = (player:GetAttribute("Rebirths") or 0) + 1
	local need = Config.rebirth(n)
	body.Visible, counter.Visible, list.Visible = not picking, picking, picking
	if picking then
		local count, fee = #pickedList(), 0
		for uid in picked do fee += fees[uid] or 0 end
		local afford = need ~= nil and (player:GetAttribute("Cash") or 0) >= need.cash + fee
		counter.Text = ("Pick creatures to keep: %d / %d   ·   keep fee %s$%s</font>"):format(count, limit,
			afford and '<font color="#7CFC9A">' or '<font color="#FF7B7B">', Format.number(fee))
		go.BackgroundColor3 = afford and rgb(170, 90, 240) or rgb(110, 115, 140)
		go.Text = armed and "Are you sure?" or ("Rebirth, keep %d"):format(count)
		return
	end
	if not need then
		body.Text = ("<b>Max rebirth reached!</b>\n\nYou're at rebirth %d of %d.\nIncome x%.1f for good."):format(n - 1, Config.MaxRebirths, 1 + Config.RebirthIncomeStep * (n - 1))
			.. "\n" .. titleLine(n - 1)
		go.BackgroundColor3 = rgb(110, 115, 140)
		go.Text = "Maxed"
		return
	end
	local cash = player:GetAttribute("Cash") or 0
	local hasBiome = (player:GetAttribute("BestBiome") or 0) >= Config.BiomeById[need.biome].index
	local cashOk = cash >= need.cash
	local function mark(ok) return ok and '<font color="#7CFC9A">✓</font>' or '<font color="#FF7B7B">✗</font>' end
	body.Text = titleLine(n - 1) .. "\n\n" .. ("<b>Rebirth %d needs:</b>\n%s $%s cash\n%s a creature from the %s (or deeper)\n\n<b>You get:</b> income x%.1f, %s, +10 s base lock\n<b>You keep:</b> %d creatures you pick (fee: 1 h of what they'll earn)\n<b>You lose:</b> cash, other creatures, eggs, saddle, gear")
		:format(n, mark(cashOk), Format.number(need.cash), mark(hasBiome), need.biome, 1 + Config.RebirthIncomeStep * n, rewardText(n, need.reward), Config.rebirthKeep(n))
	local ready = cashOk and hasBiome
	go.BackgroundColor3 = ready and rgb(170, 90, 240) or rgb(110, 115, 140)
	go.Text = armed and "Are you sure?" or "Rebirth"
end

local function showPicker()
	local inv = Remotes.GetInventory:InvokeServer()
	if not inv then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	limit = Config.rebirthKeep((player:GetAttribute("Rebirths") or 0) + 1)
	table.clear(picked)
	table.clear(fees)
	-- ridden first, then best income
	table.sort(inv.creatures, function(a, b)
		if (a.location == "Mount") ~= (b.location == "Mount") then return a.location == "Mount" end
		return a.income > b.income
	end)
	for i, c in inv.creatures do
		fees[c.uid] = c.keepFee
		if c.location == "Mount" and #pickedList() < limit then picked[c.uid] = true end
		local rarity = Config.RarityById[c.rarity]
		local row = styled(new("TextButton", { LayoutOrder = i, Size = UDim2.new(1, -12, 0, 44), BackgroundColor3 = rgb(52, 56, 80),
			AutoButtonColor = false, RichText = true, Font = Enum.Font.FredokaOne, TextSize = 20, TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, list), false)
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, row)
		local function paint()
			local on = picked[c.uid]
			row.BackgroundColor3 = on and rgb(110, 70, 170) or rgb(52, 56, 80)
			row.Text = ('%s  <font color="#%s">%s %s</font>%s   <font color="#C8D2E6">$%s/s</font>'):format(on and '<font color="#7CFC9A">✓</font>' or "   ",
				rarity.color:ToHex(), c.rarity, c.display, c.location == "Mount" and "  (riding)" or "", Format.number(c.income))
		end
		paint()
		row.Activated:Connect(function()
			if picked[c.uid] then
				picked[c.uid] = nil
			elseif #pickedList() < limit then
				picked[c.uid] = true
			end
			armed = false
			paint()
			refresh()
		end)
	end
	picking = true
	refresh()
end

go.Activated:Connect(function()
	if not picking then
		local need = Config.rebirth((player:GetAttribute("Rebirths") or 0) + 1)
		local ready = need and (player:GetAttribute("Cash") or 0) >= need.cash
			and (player:GetAttribute("BestBiome") or 0) >= Config.BiomeById[need.biome].index
		if ready then
			showPicker()
		elseif need then
			Remotes.Rebirth:FireServer() -- the server says what's missing
		end
		return
	end
	if not armed then
		armed = true
		refresh()
		task.delay(3, function() armed = false refresh() end)
		return
	end
	armed = false
	Remotes.Rebirth:FireServer(pickedList())
	panel.Visible = false
	picking = false
end)
menuButton.Activated:Connect(function() picking = false panel.Visible = not panel.Visible refresh() end)
close.Activated:Connect(function() panel.Visible = false picking = false end)
player.AttributeChanged:Connect(function() if panel.Visible then refresh() end end)
