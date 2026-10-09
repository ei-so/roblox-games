-- Stable panel: every creature you own, with Pen / Sell buttons (Ride arrives in Part 3, Fuse in Part 4).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local CreatureBuilder = require(Shared:WaitForChild("CreatureBuilder"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

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
local function round(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o)
end
local function outline(o, color, thickness)
	new("UIStroke", { Color = color or WHITE, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function text(name, props, parent)
	local t = new("TextLabel", { Name = name, BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true,
		TextColor3 = WHITE, RichText = true }, parent)
	for k, v in props do
		t[k] = v
	end
	new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5 }, t)
	return t
end
local function button(name, label, color, props, parent)
	local b = new("TextButton", { Name = name, Text = label, BackgroundColor3 = color, Font = Enum.Font.FredokaOne, TextScaled = true,
		TextColor3 = WHITE, AutoButtonColor = true }, parent)
	for k, v in props do
		b[k] = v
	end
	round(b, 10)
	new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5 }, b)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	return b
end

-- menu button
local menuButton = button("StableButton", "Stable", rgb(250, 165, 55), { LayoutOrder = 1, Size = UDim2.new(0, 130, 0, 46) }, gui:WaitForChild("LeftMenu"))
outline(menuButton, WHITE, 3)

-- panel
local panel = new("Frame", { Name = "StablePanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.new(0, 740, 0, 470), BackgroundColor3 = rgb(35, 38, 56), Visible = false, ZIndex = 5 }, gui)
round(panel, 18)
outline(panel, WHITE, 3)
text("Title", { Position = UDim2.new(0, 20, 0, 10), Size = UDim2.new(0, 200, 0, 40), Text = "Stable", TextXAlignment = Enum.TextXAlignment.Left }, panel)
local counts = text("Counts", { Position = UDim2.new(0, 220, 0, 16), Size = UDim2.new(1, -300, 0, 28), Text = "",
	TextColor3 = rgb(200, 210, 230) }, panel)
local close = button("Close", "X", rgb(220, 70, 70), { Position = UDim2.new(1, -58, 0, 10), Size = UDim2.new(0, 44, 0, 40) }, panel)
local list = new("ScrollingFrame", { Name = "List", Position = UDim2.new(0, 14, 0, 62), Size = UDim2.new(1, -28, 1, -76),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, panel)
new("UIGridLayout", { CellSize = UDim2.new(0, 168, 0, 236), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local empty = text("Empty", { Position = UDim2.new(0, 40, 0.4, 0), Size = UDim2.new(1, -80, 0, 36), Visible = false,
	Text = "No creatures yet. Steal an egg from the Forest nest!" }, panel)

local spinning = {} -- card models turning slowly while the panel is open
local function preview(viewport, c)
	local model = CreatureBuilder.build(c.species, c.rarity, c.mutation)
	model.Parent = viewport
	table.insert(spinning, { model = model, base = model:GetPivot() })
	local camera = new("Camera", { FieldOfView = 40 }, viewport)
	viewport.CurrentCamera = camera
	local boxCFrame, size = model:GetBoundingBox()
	local d = size.Magnitude
	camera.CFrame = CFrame.lookAt(boxCFrame.Position + Vector3.new(d * 0.7, d * 0.35, -d * 1.1), boxCFrame.Position)
end

local LOCATION_ORDER = { Mount = 0, Pen = 1, Stable = 2 }
local refreshing = false

local function refresh()
	if refreshing then
		return
	end
	refreshing = true
	local inv = Remotes.GetInventory:InvokeServer()
	refreshing = false
	if not inv then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(spinning)
	counts.Text = ("Pen %d/%d   ·   Stable %d/%d"):format(inv.penCount, inv.penSlots, inv.stableCount, inv.stableSize)
	empty.Visible = #inv.creatures == 0
	table.sort(inv.creatures, function(a, b)
		if a.location ~= b.location then
			return LOCATION_ORDER[a.location] < LOCATION_ORDER[b.location]
		end
		return a.income > b.income
	end)
	-- how many of each species+rarity you could fuse (mounts don't count)
	local fusable = {}
	for _, c in inv.creatures do
		if c.location ~= "Mount" then
			local key = c.species .. "_" .. c.rarity
			fusable[key] = (fusable[key] or 0) + 1
		end
	end
	for i, c in inv.creatures do
		local rarity = Config.RarityById[c.rarity]
		local card = new("Frame", { Name = c.uid, LayoutOrder = i, BackgroundColor3 = rgb(52, 56, 80) }, list)
		round(card, 14)
		outline(card, rarity.color, 3)
		local viewport = new("ViewportFrame", { Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(1, -12, 0, 96),
			BackgroundColor3 = rgb(70, 76, 105), Ambient = rgb(200, 200, 200), LightDirection = Vector3.new(-1, -2, 1) }, card)
		round(viewport, 10)
		preview(viewport, c)
		if c.location ~= "Stable" then
			text("Badge", { Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(0, 70, 0, 18),
				Text = c.location == "Pen" and "IN PEN" or "RIDING", TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = c.location == "Pen" and rgb(120, 255, 150) or rgb(120, 200, 255) }, card)
		end
		if c.location ~= "Mount" and rarity.index <= 4 and (fusable[c.species .. "_" .. c.rarity] or 0) >= 3 then
			button("Fuse", "Fuse 3", rgb(170, 90, 240), { Position = UDim2.new(1, -74, 0, 10), Size = UDim2.new(0, 64, 0, 26) }, card).Activated:Connect(function()
				Remotes.Fuse:FireServer(c.uid)
			end)
		end
		text("Name", { Position = UDim2.new(0, 6, 0, 104), Size = UDim2.new(1, -12, 0, 24), Text = c.display }, card)
		new("ImageLabel", { Name = "RarityIcon", BackgroundTransparency = 1, Image = (Config.Icons and Config.Icons.Rarities and Config.Icons.Rarities[c.rarity]) or "",
			Position = UDim2.new(0, 6, 0, 124), Size = UDim2.fromOffset(24, 24), ScaleType = Enum.ScaleType.Fit }, card)
		text("Rarity", { Position = UDim2.new(0, 34, 0, 128), Size = UDim2.new(1, -40, 0, 18),
			Text = c.rarity .. (c.mutation and (" · " .. c.mutation) or ""), TextColor3 = rarity.color }, card)
		text("Stats", { Position = UDim2.new(0, 6, 0, 148), Size = UDim2.new(1, -12, 0, 18),
			Text = ("$%s/s   ⚡%d"):format(Format.number(c.income), c.speed), TextColor3 = rgb(220, 230, 245) }, card)
		if c.ability then
			new("ImageLabel", { Name = "AbilityIcon", BackgroundTransparency = 1, Image = (Config.Icons and Config.Icons.Abilities and Config.Icons.Abilities[c.ability]) or "",
				Position = UDim2.new(0, 6, 0, 162), Size = UDim2.fromOffset(22, 22), ScaleType = Enum.ScaleType.Fit }, card)
		end
		text("Ability", { Position = UDim2.new(0, c.ability and 32 or 6, 0, 166), Size = UDim2.new(1, c.ability and -38 or -12, 0, 16),
			Text = c.ability and ("Ability: " .. c.ability) or "No ability (+2 speed)", TextColor3 = rgb(180, 190, 210) }, card)

		local row = new("Frame", { Position = UDim2.new(0, 6, 1, -46), Size = UDim2.new(1, -12, 0, 40), BackgroundTransparency = 1 }, card)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, row)
		local third = UDim2.new(1 / 3, -4, 1, 0)
		if c.location == "Mount" then
			button("Dismount", "Get off", rgb(110, 115, 140), { LayoutOrder = 0, Size = UDim2.new(1, 0, 1, 0) }, row).Activated:Connect(function()
				Remotes.UnequipMount:FireServer(c.uid)
			end)
		else
			button("Ride", "Ride", rgb(70, 140, 245), { LayoutOrder = 0, Size = third }, row).Activated:Connect(function()
				Remotes.EquipMount:FireServer(c.uid)
			end)
		end
		if c.location == "Pen" then
			button("Unpen", "Unpen", rgb(110, 115, 140), { LayoutOrder = 1, Size = third }, row).Activated:Connect(function()
				Remotes.RemoveFromPen:FireServer(c.uid)
			end)
		elseif c.location == "Stable" then
			local full = inv.penCount >= inv.penSlots
			button("Pen", full and "Full" or "Pen", full and rgb(110, 115, 140) or rgb(60, 185, 100),
				{ LayoutOrder = 1, Size = third }, row).Activated:Connect(function()
				if not full then
					Remotes.PlaceInPen:FireServer(c.uid)
				end
			end)
		end
		if c.location ~= "Mount" then
			local price = Format.number(c.income * Config.SellSeconds)
			local sell = button("Sell", "$" .. price, rgb(225, 85, 70), { LayoutOrder = 2, Size = third }, row)
			local armed = false
			sell.Activated:Connect(function()
				if rarity.index >= 4 and not armed then -- Epic and up ask twice
					armed = true
					sell.Text = "Sure?"
					task.delay(3, function()
						if sell.Parent then
							armed = false
							sell.Text = "$" .. price
						end
					end)
					return
				end
				Remotes.Sell:FireServer(c.uid)
			end)
		end
	end
end

game:GetService("RunService").RenderStepped:Connect(function()
	if panel.Visible then
		local turn = CFrame.Angles(0, os.clock() * 0.8, 0)
		for _, s in spinning do
			s.model:PivotTo(s.base * turn)
		end
	end
end)

menuButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh()
	end
end)
close.Activated:Connect(function()
	panel.Visible = false
end)
panel:GetAttributeChangedSignal("OpenRequest"):Connect(function() -- the Fuse Machine opens the Stable
	panel.Visible = true
	refresh()
end)
Remotes:WaitForChild("InventoryChanged").OnClientEvent:Connect(function()
	if panel.Visible then
		refresh()
	end
end)
