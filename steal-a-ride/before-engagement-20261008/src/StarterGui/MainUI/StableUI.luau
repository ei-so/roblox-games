-- Rarity-filtered Stable and a separate Fuse recipe panel; server remains authoritative.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local CreatureBuilder = require(Shared:WaitForChild("CreatureBuilder"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = script.Parent
local player = game:GetService("Players").LocalPlayer
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
local panel = new("Frame", { Name = "StablePanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 740, 0, 470), BackgroundColor3 = rgb(35, 38, 56), Visible = false, ZIndex = 5 }, gui)
round(panel, 18)
outline(panel, WHITE, 3)
text("Title", { Position = UDim2.new(0, 20, 0, 10), Size = UDim2.new(0, 120, 0, 36), Text = "Stable", TextXAlignment = Enum.TextXAlignment.Left }, panel)
local counts = text("Counts", { Position = UDim2.new(0, 20, 0, 54), Size = UDim2.new(1, -40, 0, 20), Text = "", TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = rgb(200, 210, 230) }, panel)
local openFuse = button("FuseButton", "Fuse", rgb(170, 90, 240), { LayoutOrder = 7, Size = UDim2.fromOffset(130, 46) }, gui:WaitForChild("LeftMenu"))
outline(openFuse, WHITE, 3)
local close = button("Close", "X", rgb(220, 70, 70), { Position = UDim2.new(1, -58, 0, 10), Size = UDim2.new(0, 44, 0, 44) }, panel)
local categories = new("ScrollingFrame", { Name = "RarityCategories", Position = UDim2.fromOffset(14, 82), Size = UDim2.new(1, -28, 0, 48),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X }, panel)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, categories)
local selectedRarity, categoryButtons = "All", {}
local list = new("ScrollingFrame", { Name = "List", Position = UDim2.new(0, 14, 0, 140), Size = UDim2.new(1, -28, 1, -154),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, panel)
local cardGrid = new("UIGridLayout", { CellSize = UDim2.new(0, 168, 0, 242), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local empty = text("Empty", { Position = UDim2.new(0, 24, 0, 154), Size = UDim2.new(1, -48, 0, 70), Visible = true, TextWrapped = true,
	Text = "Loading inventory…" }, panel)

local fusePanel = new("Frame", { Name = "FusePanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(620, 470), BackgroundColor3 = rgb(35, 38, 56), Visible = false, ZIndex = 5 }, gui)
round(fusePanel, 18)
outline(fusePanel, WHITE, 3)
text("Title", { Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -90, 0, 36), Text = "Fuse creatures", TextXAlignment = Enum.TextXAlignment.Left }, fusePanel)
local fuseClose = button("Close", "X", rgb(220, 70, 70), { Position = UDim2.new(1, -58, 0, 10), Size = UDim2.fromOffset(44, 44) }, fusePanel)
text("Rules", { Position = UDim2.fromOffset(20, 58), Size = UDim2.new(1, -40, 0, 40), Text = "3 matching species + rarity = 1 rarer creature. Best mutation kept.",
	TextWrapped = true, TextColor3 = rgb(200, 210, 230) }, fusePanel)
local fuseLocation = text("Location", { Position = UDim2.fromOffset(20, 102), Size = UDim2.new(1, -40, 0, 26), Text = "Visit the Fuse Machine in the Plaza", TextColor3 = rgb(255, 215, 130) }, fusePanel)
local fuseList = new("ScrollingFrame", { Name = "Recipes", Position = UDim2.fromOffset(14, 140), Size = UDim2.new(1, -28, 1, -154),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, fusePanel)
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, fuseList)
local fuseEmpty = text("Empty", { Position = UDim2.fromOffset(24, 154), Size = UDim2.new(1, -48, 0, 100), TextWrapped = true,
	Text = "Collect 3 matching creatures to fuse. Equipped mounts do not count. Legendary and Mythic cannot be fused.", Visible = false }, fusePanel)
local inventory
local spinning = { [panel] = {}, [fusePanel] = {} }
local function preview(viewport, c, owner)
	local model = CreatureBuilder.build(c.species, c.rarity, c.mutation)
	model.Parent = viewport
	table.insert(spinning[owner or panel], { model = model, base = model:GetPivot() })
	local camera = new("Camera", { FieldOfView = 40 }, viewport)
	viewport.CurrentCamera = camera
	local boxCFrame, size = model:GetBoundingBox()
	local d = size.Magnitude
	camera.CFrame = CFrame.lookAt(boxCFrame.Position + Vector3.new(d * 0.7, d * 0.35, -d * 1.1), boxCFrame.Position)
end

local LOCATION_ORDER = { Mount = 0, Pen = 1, Stable = 2 }
local function renderStable(inv)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(spinning[panel])
	counts.Text = ("Pen %d/%d   ·   Stable %d/%d"):format(inv.penCount, inv.penSlots, inv.stableCount, inv.stableSize)
	local rarityCounts = { All = #inv.creatures }
	for _, c in inv.creatures do rarityCounts[c.rarity] = (rarityCounts[c.rarity] or 0) + 1 end
	for id, b in categoryButtons do
		b.Text = (selectedRarity == id and ("[" .. id .. "]") or id) .. " " .. (rarityCounts[id] or 0)
		b.BackgroundColor3 = selectedRarity == id and rgb(105, 110, 155) or rgb(52, 56, 80)
		b:SetAttribute("Selected", selectedRarity == id)
	end
	empty.Visible = (rarityCounts[selectedRarity] or 0) == 0
	empty.Text = #inv.creatures == 0 and "No creatures yet. Steal an egg from the Forest nest!"
		or ("No " .. selectedRarity .. " creatures yet. Choose another rarity or hatch more eggs.")
	table.sort(inv.creatures, function(a, b)
		if a.rarity ~= b.rarity then return Config.RarityById[a.rarity].index > Config.RarityById[b.rarity].index end
		if a.location ~= b.location then
			return LOCATION_ORDER[a.location] < LOCATION_ORDER[b.location]
		end
		return a.income > b.income
	end)
	for i, c in inv.creatures do
		if selectedRarity ~= "All" and c.rarity ~= selectedRarity then continue end
		local compact = panel:GetAttribute("CompactCards")
		local cardHeight = cardGrid.CellSize.Y.Offset
		local rarity = Config.RarityById[c.rarity]
		local card = new("Frame", { Name = c.uid, LayoutOrder = i, BackgroundColor3 = rgb(52, 56, 80) }, list)
		round(card, 14)
		outline(card, rarity.color, 3)
		local viewport = new("ViewportFrame", { Position = UDim2.new(0, 6, 0, 6), Size = compact and UDim2.fromOffset(56, 50) or UDim2.new(1, -12, 0, 96),
			BackgroundColor3 = rgb(70, 76, 105), Ambient = rgb(200, 200, 200), LightDirection = Vector3.new(-1, -2, 1) }, card)
		round(viewport, 10)
		preview(viewport, c)
		if c.location ~= "Stable" then
			text("Badge", { Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(0, compact and 52 or 70, 0, compact and 12 or 18),
				Text = c.location == "Pen" and "IN PEN" or "RIDING", TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = c.location == "Pen" and rgb(120, 255, 150) or rgb(120, 200, 255) }, card)
		end
		text("Name", { Position = compact and UDim2.fromOffset(70, 6) or UDim2.new(0, 6, 0, 104),
			Size = compact and UDim2.new(1, -76, 0, 20) or UDim2.new(1, -12, 0, 24), Text = c.display }, card)
		new("ImageLabel", { Name = "RarityIcon", BackgroundTransparency = 1, Image = (Config.Icons and Config.Icons.Rarities and Config.Icons.Rarities[c.rarity]) or "",
			Position = UDim2.new(0, 6, 0, 124), Size = UDim2.fromOffset(24, 24), ScaleType = Enum.ScaleType.Fit, Visible = not compact }, card)
		text("Rarity", { Position = compact and UDim2.fromOffset(70, 28) or UDim2.new(0, 34, 0, 128),
			Size = UDim2.new(1, compact and -76 or -40, 0, 18),
			Text = c.rarity .. (c.mutation and (" · " .. c.mutation) or ""), TextColor3 = rarity.color }, card)
		text("Stats", { Position = compact and UDim2.fromOffset(70, 48) or UDim2.new(0, 6, 0, 148), Size = UDim2.new(1, compact and -76 or -12, 0, compact and 12 or 18),
			Text = ("%s $%s/s · ⚡%d"):format(c.location == "Pen" and "Earns" or "Pen:", Format.number(c.income), c.speed), TextColor3 = rgb(220, 230, 245) }, card)
		if c.ability and not compact then
			new("ImageLabel", { Name = "AbilityIcon", BackgroundTransparency = 1, Image = (Config.Icons and Config.Icons.Abilities and Config.Icons.Abilities[c.ability]) or "",
				Position = UDim2.new(0, 6, 0, 162), Size = UDim2.fromOffset(22, 22), ScaleType = Enum.ScaleType.Fit }, card)
		end
		text("Ability", { Position = compact and UDim2.fromOffset(6, cardHeight - 62) or UDim2.new(0, c.ability and 32 or 6, 0, 166),
			Size = UDim2.new(1, (not compact and c.ability) and -38 or -12, 0, compact and 10 or 16),
			Text = c.ability and ("Ability: " .. c.ability) or "No ability (+2 speed)", TextColor3 = rgb(180, 190, 210) }, card)

		local row = new("Frame", { Position = UDim2.new(0, 6, 1, -50), Size = UDim2.new(1, -12, 0, 44), BackgroundTransparency = 1 }, card)
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

local function fuseGroups(creatures)
	local byKey, groups, ready = {}, {}, 0
	for _, c in creatures do
		if c.location ~= "Mount" and Config.RarityById[c.rarity].index < 5 then
			local key = c.species .. "_" .. c.rarity
			local group = byKey[key]
			if not group then
				group = { creature = c, count = 0 }
				byKey[key] = group
				table.insert(groups, group)
			end
			group.count += 1
		end
	end
	for _, group in groups do if group.count >= 3 then ready += 1 end end
	table.sort(groups, function(a, b)
		if (a.count >= 3) ~= (b.count >= 3) then return a.count >= 3 end
		local ar, br = Config.RarityById[a.creature.rarity].index, Config.RarityById[b.creature.rarity].index
		if ar ~= br then return ar > br end
		return a.creature.species < b.creature.species
	end)
	return groups, ready
end
-- End fuse grouping

local fuseActions, fusing, fuseRequest = {}, false, 0
local function nearFuseMachine()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local plaza = workspace:FindFirstChild("Plaza")
	local machine = plaza and plaza:FindFirstChild("FuseMachine")
	local body = machine and machine:FindFirstChild("Body")
	return root and body and (root.Position - body.Position).Magnitude <= 30 or false
end
local function syncFuseLocation()
	local near = nearFuseMachine()
	fuseLocation.Text = near and "At Fuse Machine · ready to fuse" or "Visit the Fuse Machine in the Plaza"
	fuseLocation.TextColor3 = near and rgb(120, 255, 150) or rgb(255, 215, 130)
	for _, item in fuseActions do
		local enabled = near and item.count >= 3 and not fusing
		item.button.Active, item.button.AutoButtonColor = enabled, enabled
		item.button.BackgroundColor3 = enabled and rgb(170, 90, 240) or rgb(85, 90, 115)
		item.button.Text = fusing and "Fusing…" or item.count < 3 and ("Need " .. (3 - item.count)) or near and "Fuse 3" or "At machine"
	end
end
local function renderFuse(inv)
	for _, child in fuseList:GetChildren() do if child:IsA("Frame") then child:Destroy() end end
	table.clear(spinning[fusePanel])
	table.clear(fuseActions)
	local groups, ready = fuseGroups(inv.creatures)
	openFuse.Text = ready > 0 and ("Fuse " .. ready) or "Fuse"
	fuseEmpty.Visible = #groups == 0
	fuseEmpty.Text = "Collect 3 matching creatures to fuse. Equipped mounts do not count. Legendary and Mythic cannot be fused."
	for i, group in groups do
		local c = group.creature
		local rarity = Config.RarityById[c.rarity]
		local nextRarity = Config.Rarities[rarity.index + 1]
		local row = new("Frame", { Name = c.species .. "_" .. c.rarity, LayoutOrder = i, Size = UDim2.new(1, -10, 0, 130), BackgroundColor3 = rgb(52, 56, 80) }, fuseList)
		round(row, 12)
		outline(row, rarity.color, 2)
		local viewport = new("ViewportFrame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(78, 74), BackgroundTransparency = 1, Ambient = rgb(200, 200, 200) }, row)
		preview(viewport, c, fusePanel)
		text("Name", { Position = UDim2.fromOffset(94, 10), Size = UDim2.new(1, -104, 0, 26), Text = c.display, TextXAlignment = Enum.TextXAlignment.Left }, row)
		text("Recipe", { Position = UDim2.fromOffset(94, 40), Size = UDim2.new(1, -104, 0, 36), TextWrapped = true,
			Text = c.rarity .. " → " .. nextRarity.id, TextColor3 = rarity.color, TextXAlignment = Enum.TextXAlignment.Left }, row)
		text("Count", { Position = UDim2.fromOffset(12, 88), Size = UDim2.new(1, -136, 0, 28), Text = group.count .. "/3 available", TextXAlignment = Enum.TextXAlignment.Left }, row)
		local action = button("Fuse", "Fuse 3", rgb(170, 90, 240), { Position = UDim2.new(1, -120, 1, -50), Size = UDim2.fromOffset(108, 44) }, row)
		table.insert(fuseActions, { button = action, count = group.count })
		action.Activated:Connect(function()
			if not fusing and group.count >= 3 and nearFuseMachine() then
				fusing = true
				fuseRequest += 1
				local request = fuseRequest
				syncFuseLocation()
				Remotes.Fuse:FireServer(c.uid)
				task.delay(3, function()
					if request == fuseRequest then fusing = false; syncFuseLocation() end
				end)
			end
		end)
	end
	syncFuseLocation()
end

local refreshing, refreshAgain = false, false
local function refresh()
	if refreshing then refreshAgain = true; return end
	refreshing = true
	local request = fuseRequest
	local ok, inv = pcall(function() return Remotes.GetInventory:InvokeServer() end)
	refreshing = false
	if ok and inv then
		if request == fuseRequest then fusing = false end
		inventory = inv
		renderStable(inv)
		renderFuse(inv)
	else
		empty.Visible, fuseEmpty.Visible = true, true
		empty.Text, fuseEmpty.Text = "Inventory unavailable. Close and reopen to retry.", "Inventory unavailable. Close and reopen to retry."
	end
	if refreshAgain then refreshAgain = false; task.defer(refresh) end
end
local function category(id, order, color)
	local b = button(id, id, rgb(52, 56, 80), { LayoutOrder = order, Size = UDim2.fromOffset(110, 44) }, categories)
	outline(b, color, 2)
	categoryButtons[id] = b
	b.Activated:Connect(function()
		selectedRarity = id
		list.CanvasPosition = Vector2.zero
		if inventory then renderStable(inventory) end
	end)
end
category("All", 0, WHITE)
for i, rarity in Config.Rarities do category(rarity.id, i, rarity.color) end

-- Fit these management panels to the safe viewport; mobile cards keep usable controls.
local panelScale = new("UIScale", {}, panel)
local fuseScale = new("UIScale", {}, fusePanel)
local rootScale = gui:WaitForChild("UIScale")
local function fitPanels()
	local touch = game:GetService("UserInputService").TouchEnabled
	local scale = touch and 1 or rootScale.Scale
	panelScale.Scale, fuseScale.Scale = scale / rootScale.Scale, scale / rootScale.Scale
	local viewport = gui.AbsoluteSize
	if viewport.X <= 0 or viewport.Y <= 0 then return end
	local width, height = math.min(740, viewport.X / scale - 24), math.min(470, viewport.Y / scale - 24)
	panel.Size = UDim2.fromOffset(width, height)
	fusePanel.Size = UDim2.fromOffset(math.min(620, width), height)
	local columns = math.max(1, math.floor((width - 28) / 178))
	local compact = touch and height < 370
	panel:SetAttribute("CompactCards", compact)
	cardGrid.CellSize = UDim2.fromOffset(math.floor((width - 38 - (columns - 1) * 10) / columns), compact and math.clamp(height - 154, 124, 132) or 242)
	if inventory then renderStable(inventory) end
end
rootScale:GetPropertyChangedSignal("Scale"):Connect(fitPanels)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanels)
fitPanels()

game:GetService("RunService").RenderStepped:Connect(function()
	local turn = CFrame.Angles(0, os.clock() * 0.8, 0)
	for owner, models in spinning do
		if owner.Visible then for _, s in models do s.model:PivotTo(s.base * turn) end end
	end
end)
task.spawn(function()
	while true do
		if fusePanel.Visible then syncFuseLocation() end
		task.wait(0.5)
	end
end)

menuButton.Activated:Connect(function()
	fusePanel.Visible = false
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh()
	end
end)
close.Activated:Connect(function()
	panel.Visible = false
end)
panel:GetAttributeChangedSignal("OpenRequest"):Connect(function()
	fusePanel.Visible = false
	panel.Visible = true
	refresh()
end)
local function showFuse()
	local current = gui:GetAttribute("OpenMenuPanel")
	if current and current ~= "FusePanel" then return end
	panel.Visible, fusePanel.Visible = false, true
	if inventory then renderFuse(inventory) end
	refresh()
end
openFuse.Activated:Connect(showFuse)
fusePanel:GetAttributeChangedSignal("OpenRequest"):Connect(showFuse)
fuseClose.Activated:Connect(function() fusePanel.Visible = false end)
Remotes:WaitForChild("InventoryChanged").OnClientEvent:Connect(function()
	if fusing then fuseRequest += 1 end -- invalidate its timeout; unlock after fresh inventory
	if panel.Visible or fusePanel.Visible then
		refresh()
	end
end)
