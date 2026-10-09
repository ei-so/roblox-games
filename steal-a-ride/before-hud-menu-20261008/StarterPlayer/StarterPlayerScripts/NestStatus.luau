-- Nearby nest stock and server-timed refill; individual egg prompts remain the selection controls.
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local biomes = workspace:WaitForChild("Biomes")
local labels = {}
for _, biome in Config.Biomes do
	local world = biomes:WaitForChild(biome.id)
	local nest = world:WaitForChild("Nest")
	local anchor = Instance.new("Part")
	anchor.Name = "NestStatusAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Position = nest:GetPivot().Position + Vector3.new(0, 6, 0)
	anchor.Parent = nest
	local gui = Instance.new("BillboardGui")
	gui.Name = "NestStatus"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(170, 38)
	gui.MaxDistance = 70
	gui.AlwaysOnTop = false
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(30, 34, 50)
	text.BackgroundTransparency = 0.2
	text.TextColor3 = Color3.fromRGB(255, 235, 140)
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 18
	text.TextWrapped = true
	text.Text = ""
	text.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = text
	table.insert(labels, { nest = nest, text = text })
end
while true do
	local now = workspace:GetServerTimeNow()
	for _, entry in labels do
		local stock, capacity = entry.nest:GetAttribute("EggStock"), entry.nest:GetAttribute("EggCapacity")
		local deadline = entry.nest:GetAttribute("NextRefill")
		if stock ~= nil and capacity ~= nil and deadline then
			local left = math.max(0, math.ceil(deadline - now))
			entry.text.Text = stock == capacity and ("%d/%d eggs"):format(stock, capacity)
				or ("%d/%d eggs · %d:%02d"):format(stock, capacity, left // 60, left % 60)
		end
	end
	task.wait(0.25)
end

