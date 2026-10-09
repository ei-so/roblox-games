-- Gear hotbar (bottom center): Net Gun / Slip Trap / Speed Soda, keys 1-2-3. Empty slots open the Shop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local gui = script.Parent
local rgb = Color3.fromRGB

local bar = Instance.new("Frame")
bar.Name = "GearBar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -74)
bar.Size = UDim2.new(0, 330, 0, 64)
bar.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bar
bar.Parent = gui

-- nearest other player within Net Gun range
local function nearestTarget()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local best, bestDist
	for _, other in Players:GetPlayers() do
		local r = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and r then
			local d = (r.Position - root.Position).Magnitude
			if d <= Config.Gear.net.range and (not bestDist or d < bestDist) then
				best, bestDist = other, d
			end
		end
	end
	return best
end

local GEAR = {
	{ id = "net", label = "Net", attr = "GearNet", key = Enum.KeyCode.One, color = rgb(80, 160, 245) },
	{ id = "trap", label = "Trap", attr = "GearTrap", key = Enum.KeyCode.Two, color = rgb(245, 200, 50) },
	{ id = "soda", label = "Soda", attr = "GearSoda", key = Enum.KeyCode.Three, color = rgb(240, 90, 160) },
}
local buttons = {}

local function useGear(g)
	if (player:GetAttribute(g.attr) or 0) <= 0 then
		local shop = gui:FindFirstChild("ShopPanel")
		if shop then
			shop.Visible = true
		end
		return
	end
	Remotes.UseGear:FireServer(g.id, g.id == "net" and nearestTarget() or nil)
end

for i, g in GEAR do
	local b = Instance.new("TextButton")
	b.Name = g.label
	b.LayoutOrder = i
	b.Size = UDim2.new(0, 100, 1, 0)
	b.BackgroundColor3 = g.color
	b.Font = Enum.Font.FredokaOne
	b.Text = ""
	b.TextColor3 = rgb(255, 255, 255)
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 14); corner.Parent = b
	local stroke = Instance.new("UIStroke"); stroke.Color = rgb(255, 255, 255); stroke.Thickness = 3; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Parent = b
	local textStroke = Instance.new("UIStroke"); textStroke.Color = rgb(25, 30, 40); textStroke.Thickness = 1.5; textStroke.Parent = b
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6); pad.Parent = b
	b.Activated:Connect(function() useGear(g) end)
	b.Parent = bar
	local icon = Instance.new("ImageLabel")
	icon.Name = "GearIcon"
	icon.BackgroundTransparency = 1
	icon.Image = Config.Icons.Gear[g.id]
	icon.ScaleType = Enum.ScaleType.Fit
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, -4)
	icon.Size = UDim2.fromOffset(40, 40)
	icon.Parent = b
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 3, 1, -18)
	label.Size = UDim2.new(1, -6, 0, 18)
	label.Font = b.Font
	label.TextColor3 = b.TextColor3
	label.TextScaled = true
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Color = rgb(25, 30, 40)
	labelStroke.Thickness = 1.5
	labelStroke.Parent = label
	label.Parent = b
	buttons[g.id] = b
	ContextActionService:BindAction("Gear" .. g.label, function(_, state)
		if state == Enum.UserInputState.Begin then useGear(g) end
		return Enum.ContextActionResult.Pass
	end, false, g.key)
end

local function refresh()
	for i, g in GEAR do
		local n = player:GetAttribute(g.attr) or 0
		buttons[g.id].Label.Text = ("%d  %s  x%d"):format(i, g.label, n)
		buttons[g.id].BackgroundTransparency = n > 0 and 0 or 0.5
	end
end
player.AttributeChanged:Connect(refresh)
refresh()
