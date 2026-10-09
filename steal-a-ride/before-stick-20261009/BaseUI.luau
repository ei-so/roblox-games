-- Base panel: the base's rebirth tier and cosmetics (wall colour, floor, plants, seating, rug, lights, statue, banners, gate) bought with Cash.
-- Bought items are kept forever; the server re-checks prices and ownership (ShopService "base:<itemId>").
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local gui = script.Parent
local rgb = Color3.fromRGB
local WHITE, MUTED, ROW, NAVY = rgb(255, 255, 255), rgb(200, 210, 230), rgb(52, 56, 80), rgb(35, 38, 56)
local GREEN, BLUE, GREY = rgb(60, 185, 100), rgb(70, 140, 245), rgb(110, 115, 140)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function text(props, parent)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left }, parent)
	for k, v in props do
		t[k] = v
	end
	new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5 }, t)
	return t
end
local function button(label, color, props, parent)
	local b = new("TextButton", { Text = label, BackgroundColor3 = color, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE }, parent)
	for k, v in props do
		b[k] = v
	end
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
	new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
	return b
end

local menuButton = button("Base", rgb(230, 110, 70), { Name = "BaseButton", LayoutOrder = 8, Size = UDim2.new(0, 130, 0, 46) }, gui:WaitForChild("LeftMenu"))
new("UIStroke", { Color = WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, menuButton)

local panel = new("Frame", { Name = "BasePanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.new(0, 560, 0, 440), BackgroundColor3 = NAVY, Visible = false, ZIndex = 5 }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, panel)
new("UIStroke", { Color = WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
text({ Position = UDim2.new(0, 20, 0, 10), Size = UDim2.new(0, 200, 0, 40), Text = "My Base" }, panel)
local tierLine = text({ Name = "Tier", Position = UDim2.new(0, 20, 0, 50), Size = UDim2.new(1, -90, 0, 22), TextColor3 = MUTED, Text = "" }, panel)
local close = button("X", rgb(220, 70, 70), { Position = UDim2.new(1, -58, 0, 10), Size = UDim2.new(0, 44, 0, 40) }, panel)

local tabs = new("Frame", { Name = "Tabs", Position = UDim2.new(0, 14, 0, 82), Size = UDim2.new(1, -28, 0, 86), BackgroundTransparency = 1 }, panel)
new("UIGridLayout", { CellSize = UDim2.new(0.2, -5, 0, 40), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabs)
local list = new("ScrollingFrame", { Name = "List", Position = UDim2.new(0, 14, 0, 178), Size = UDim2.new(1, -28, 1, -192), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, panel)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local current = Config.Base.slots[1].id
local tabButtons, rows = {}, {}
local defaults = {} -- [slot] = free default item id
for _, item in Config.Base.items do
	if item.price == 0 then
		defaults[item.slot] = item.id
	end
end

local function decode(attr)
	local ok, value = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(attr) or "{}")
	return ok and type(value) == "table" and value or {}
end

local function refresh()
	local tierIndex = player:GetAttribute("BaseTier") or 1
	local tier, nextTier = Config.Base.tiers[tierIndex], Config.Base.tiers[tierIndex + 1]
	tierLine.Text = nextTier and ("%s base  ·  %s at Rebirth %d"):format(tier.name, nextTier.name, nextTier.rebirths)
		or ("%s base  ·  top tier"):format(tier.name)
	for id, tab in tabButtons do
		tab.BackgroundColor3 = id == current and BLUE or ROW
	end
	local owned, equipped = decode("BaseOwned"), decode("BaseEquipped")
	local cash = player:GetAttribute("Cash") or 0
	for _, item in Config.Base.items do
		local row = rows[item.id]
		row.Visible = item.slot == current
		local isEquipped = (equipped[item.slot] or defaults[item.slot]) == item.id
		local isOwned = item.price == 0 or owned[item.id]
		if isEquipped then
			row.Buy.Text, row.Buy.BackgroundColor3, row.Desc.Text = "Equipped", GREY, "In your base now"
		elseif isOwned then
			row.Buy.Text, row.Buy.BackgroundColor3, row.Desc.Text = "Equip", BLUE, item.price == 0 and "Free" or "Owned"
		else
			row.Buy.Text = "$" .. Format.number(item.price)
			row.Buy.BackgroundColor3 = cash >= item.price and GREEN or GREY
			row.Desc.Text = cash >= item.price and "Yours forever, even after rebirth" or "Need more cash"
		end
	end
end

for i, slot in Config.Base.slots do
	local tab = button(slot.title, ROW, { Name = slot.id, LayoutOrder = i }, tabs)
	tab.Activated:Connect(function()
		current = slot.id
		list.CanvasPosition = Vector2.zero
		refresh()
	end)
	tabButtons[slot.id] = tab
end

for i, item in Config.Base.items do
	local row = new("Frame", { Name = item.id, LayoutOrder = i, Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = ROW }, list)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, row)
	local left = 14
	if item.color then -- colour, floor and rug items show their colour
		local swatch = new("Frame", { Name = "Swatch", Position = UDim2.new(0, 12, 0.5, -20), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = item.color }, row)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, swatch)
		new("UIStroke", { Color = WHITE, Thickness = 2 }, swatch)
		left = 64
	end
	text({ Name = "Title", Position = UDim2.new(0, left, 0, 6), Size = UDim2.new(1, -left - 150, 0, 28), Text = item.name }, row)
	text({ Name = "Desc", Position = UDim2.new(0, left, 0, 36), Size = UDim2.new(1, -left - 150, 0, 20), Text = "", TextColor3 = MUTED }, row)
	local buy = button("", GREEN, { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 130, 0, 46) }, row)
	buy.Activated:Connect(function()
		Remotes.Buy:FireServer("base:" .. item.id)
	end)
	rows[item.id] = row
end

menuButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	refresh()
end)
close.Activated:Connect(function()
	panel.Visible = false
end)
player.AttributeChanged:Connect(function()
	if panel.Visible then
		refresh()
	end
end)
refresh()
