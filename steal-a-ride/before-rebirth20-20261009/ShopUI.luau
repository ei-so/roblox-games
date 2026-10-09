-- Shop panel: saddle (+1 speed), incubators, pen slots. Prices come from Config; the server re-checks everything.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
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
	new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5 }, b)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
	return b
end


local panel = new("Frame", { Name = "ShopPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.new(0, 560, 0, 400), BackgroundColor3 = rgb(35, 38, 56), Visible = false, ZIndex = 5 }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, panel)
new("UIStroke", { Color = WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
text({ Position = UDim2.new(0, 20, 0, 10), Size = UDim2.new(0, 200, 0, 40), Text = "Shop" }, panel)
local close = button("X", rgb(220, 70, 70), { Position = UDim2.new(1, -58, 0, 10), Size = UDim2.new(0, 44, 0, 40) }, panel)
local list = new("ScrollingFrame", { Name = "List", Position = UDim2.new(0, 14, 0, 62), Size = UDim2.new(1, -28, 1, -76), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, panel)
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)

-- each item: id (server item), title, description, level text, cost (nil = maxed)
local ITEMS = {
	{ id = "saddle", title = "Saddle", info = function()
		local level = player:GetAttribute("SaddleLevel") or 0
		local cost = level < Config.Costs.saddleMax and Config.Costs.saddle(level + 1) or nil
		return ("+1 speed on foot or riding  ·  Level %d/%d"):format(level, Config.Costs.saddleMax), cost
	end },
	{ id = "incubator", title = "Incubator", info = function()
		local n = player:GetAttribute("IncubatorCount") or Config.Plot.startIncubators
		return ("Hatch more eggs at once  ·  %d/%d"):format(n, Config.Plot.maxIncubators), Config.Costs.incubators[n + 1]
	end },
	{ id = "pen", title = "Pen Slot", info = function()
		local n = player:GetAttribute("PenSlots") or Config.Plot.startPen
		return ("Earn from more creatures  ·  %d/%d"):format(n, Config.Plot.maxPen), n < Config.Plot.maxPen and Config.Costs.penSlot(n + 1) or nil
	end },
	{ id = "net", title = "Net Gun", info = function()
		return ("Slow a player 50%% for 3 s  ·  You have %d"):format(player:GetAttribute("GearNet") or 0), player:GetAttribute("GearPrice") or 50
	end },
	{ id = "trap", title = "Slip Trap", info = function()
		return ("Slows the first player or guardian on it  ·  You have %d"):format(player:GetAttribute("GearTrap") or 0), player:GetAttribute("GearPrice") or 50
	end },
	{ id = "soda", title = "Speed Soda", info = function()
		return ("+25%% speed for 20 s  ·  You have %d"):format(player:GetAttribute("GearSoda") or 0), player:GetAttribute("GearPrice") or 50
	end },
}
local rows = {}

local function refresh()
	local cash = player:GetAttribute("Cash") or 0
	for _, item in ITEMS do
		local row = rows[item.id]
		local desc, cost = item.info()
		row.Desc.Text = desc
		if cost then
			row.Buy.Text = "$" .. Format.number(cost)
			row.Buy.BackgroundColor3 = cash >= cost and rgb(60, 185, 100) or rgb(110, 115, 140)
		else
			row.Buy.Text = "MAX"
			row.Buy.BackgroundColor3 = rgb(110, 115, 140)
		end
	end
end

for i, item in ITEMS do
	local row = new("Frame", { Name = item.id, LayoutOrder = i, Size = UDim2.new(1, -10, 0, 78), BackgroundColor3 = rgb(52, 56, 80) }, list)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, row)
	local art = (Config.Icons and Config.Icons.Gear and Config.Icons.Gear[item.id])
	-- upgrades reuse their game pass icon (owned by this experience)
	local pass = ({ saddle = "ExtraMount", incubator = "Incubators", pen = "PenSlots" })[item.id]
	local icon = new("ImageLabel", { Name = "GearIcon", BackgroundTransparency = 1, Image = art or "", ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.new(0, 10, 0, 13), Size = UDim2.fromOffset(52, 52) }, row)
	if pass then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, Config.Monetization.passes[pass].id, Enum.InfoType.GamePass)
			if ok and info.IconImageAssetId and info.IconImageAssetId ~= 0 then
				icon.Image = "rbxassetid://" .. info.IconImageAssetId
			end
		end)
	end
	local left = 72
	text({ Name = "Title", Position = UDim2.new(0, left, 0, 8), Size = UDim2.new(1, -left - 156, 0, 30), Text = item.title }, row)
	text({ Name = "Desc", Position = UDim2.new(0, left, 0, 42), Size = UDim2.new(1, -left - 156, 0, 24), Text = "", TextColor3 = rgb(200, 210, 230) }, row)
	local buy = button("$0", rgb(60, 185, 100), { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 130, 0, 46) }, row)
	buy.Activated:Connect(function()
		Remotes.Buy:FireServer(item.id)
	end)
	rows[item.id] = row
end

close.Activated:Connect(function()
	panel.Visible = false
end)
panel:GetAttributeChangedSignal("OpenRequest"):Connect(function() -- Plaza Gear Shop: open on the gear rows
	panel.Visible = true
	refresh()
	task.defer(function()
		list.CanvasPosition = Vector2.new(0, rows.net.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y)
	end)
end)
player.AttributeChanged:Connect(function()
	if panel.Visible then
		refresh()
	end
end)
refresh()
