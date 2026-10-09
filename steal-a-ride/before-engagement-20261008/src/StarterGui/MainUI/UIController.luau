-- HUD: shows the server-owned values replicated as Player attributes.
local Players = game:GetService("Players")
local Format = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Format"))

local player = Players.LocalPlayer
local gui = script.Parent
local top = gui:WaitForChild("TopBar")
local cashLabel = top:WaitForChild("CashPill"):WaitForChild("Cash")
local perSecLabel = top.CashPill:WaitForChild("PerSec")
local speedLabel = top:WaitForChild("SpeedPill"):WaitForChild("Speed")
local warning = gui:WaitForChild("Warning")

-- Compact the existing HUD; keep the money/controller hierarchy and established colors.
top.AnchorPoint = Vector2.new(0, 0)
top.Position = UDim2.fromOffset(16, 8)
top.Size = UDim2.fromOffset(286, 48)
top.CashPill.Size = UDim2.fromOffset(180, 48)
cashLabel.Position = UDim2.fromOffset(10, 2)
cashLabel.Size = UDim2.new(1, -20, 0, 28)
cashLabel.TextScaled = false
cashLabel.TextSize = 26
perSecLabel.Position = UDim2.fromOffset(10, 30)
perSecLabel.Size = UDim2.new(1, -20, 0, 16)
perSecLabel.TextScaled = false
perSecLabel.TextSize = 18
top.SpeedPill.Size = UDim2.fromOffset(94, 44)
speedLabel.TextScaled = false
speedLabel.TextSize = 24
local layout = top:FindFirstChildOfClass("UIListLayout")
if layout then layout.Padding = UDim.new(0, 8) end


local function refresh()
	cashLabel.Text = "$" .. Format.number(player:GetAttribute("Cash") or 0)
	perSecLabel.Text = "+$" .. Format.number(player:GetAttribute("CashPerSecond") or 0) .. "/s"
	local speed = player:GetAttribute("CarryingEgg") and player:GetAttribute("CurrentSpeed") or player:GetAttribute("Speed")
	speedLabel.Text = "⚡ " .. Format.number(speed or 20) -- while carrying: the weighed-down speed
	warning.Visible = player:GetAttribute("DataLoadFailed") == true
end
player.AttributeChanged:Connect(refresh)
refresh()

-- Toasts: short messages from the server ("Caught by the Swan!", "Nests refilled!", hatches)
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0.5)
toast.Position = UDim2.new(0.5, 0, 0, 250) -- offset, so UIScale keeps it below the top Mama bar and status on phones
toast.Size = UDim2.new(0.8, 0, 0, 52)
toast.BackgroundTransparency = 1
toast.Font = Enum.Font.FredokaOne
toast.TextScaled = true
toast.RichText = true
toast.TextColor3 = Color3.new(1, 1, 1)
toast.TextTransparency = 1
local toastWidth = Instance.new("UISizeConstraint")
toastWidth.MaxSize = Vector2.new(700, 52)
toastWidth.Parent = toast
local toastStroke = Instance.new("UIStroke")
toastStroke.Thickness = 3
toastStroke.Color = Color3.fromRGB(25, 30, 40)
toastStroke.Transparency = 1
toastStroke.Parent = toast
toast.Parent = gui

local toastToken = 0
local function showToast(text: string)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextTransparency, toastStroke.Transparency = 0, 0
	toast.Size = UDim2.new(0.72, 0, 0, 46)
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0.8, 0, 0, 52) }):Play()
	task.delay(2.2, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(toastStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
end

game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Notify").OnClientEvent:Connect(function(kind, payload)
	if kind == "toast" then
		showToast(payload)
	elseif kind == "chase" then
		local biome = Config.BiomeById[payload]
		if biome then showToast('<font color="#ff7070">' .. biome.guardian .. " is chasing you! Run home!</font>") end
	elseif kind == "rage" then
		local biome = Config.BiomeById[payload]
		if biome then showToast('<font color="#ff4040">The ' .. biome.guardian .. " is ENRAGED! Run!</font>") end
	elseif kind == "alarm" then
		showToast('<font color="#ff7070">' .. payload .. "</font>")
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
		flash.BackgroundTransparency = 0.55
		flash.ZIndex = 50
		flash.Parent = gui
		TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		game:GetService("Debris"):AddItem(flash, 1.3) -- the alarm sound is played by Effects
	elseif kind == "hatched" then
		local rarity = Config.RarityById[payload.rarity]
		local mutation = payload.mutation and (payload.mutation .. " ") or ""
		local article = payload.rarity:match("^[AEIOU]") and "an" or "a"
		showToast(('You hatched %s <font color="#%s">%s %s%s</font>!'):format(article, rarity.color:ToHex(), payload.rarity, mutation,
			Config.Species[payload.species].display))
	end
end)

-- Status pills under the top bar: new-player shield, base lock timer
local status = Instance.new("TextLabel")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0, 84)
status.Size = UDim2.new(0, 420, 0, 26)
status.BackgroundTransparency = 1
status.Font = Enum.Font.FredokaOne
status.TextScaled = true
status.RichText = true
status.TextColor3 = Color3.new(1, 1, 1)
local statusStroke = Instance.new("UIStroke")
statusStroke.Thickness = 2
statusStroke.Color = Color3.fromRGB(25, 30, 40)
statusStroke.Parent = status
status.Parent = gui

-- Event banner (top right): weather countdown, Secret Egg location
local banner = Instance.new("TextLabel")
banner.Name = "EventBanner"
banner.AnchorPoint = Vector2.new(1, 0)
banner.Position = UDim2.new(1, -16, 0, 8)
banner.Size = UDim2.new(0, 230, 0, 48)
banner.BackgroundColor3 = Color3.fromRGB(30, 34, 50)
banner.BackgroundTransparency = 0.2
banner.Font = Enum.Font.FredokaOne
banner.TextScaled = true
banner.RichText = true
banner.TextColor3 = Color3.new(1, 1, 1)
banner.Visible = false
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 12)
bannerCorner.Parent = banner
local bannerPad = Instance.new("UIPadding")
bannerPad.PaddingTop, bannerPad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
bannerPad.PaddingLeft, bannerPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
bannerPad.Parent = banner
banner.Parent = gui

local WEATHER_TEXT = {
	Thunderstorm = '<font color="#7ec8ff">THUNDERSTORM</font>',
	GoldenHour = '<font color="#ffd25a">GOLDEN HOUR</font>',
	BloodMoon = '<font color="#ff5a5a">BLOOD MOON</font>',
}
-- Lines under the weather name: what grabbing an egg can give you right now
local WEATHER_TIP = {}
for mutation, m in Config.Mutations do
	WEATHER_TIP[m.event] = {
		("Grab eggs: %d%% %s"):format(math.round(m.chance * 100), mutation),
		("x%s income, +%s speed"):format(m.incomeX, m.speed),
	}
end
table.insert(WEATHER_TIP.BloodMoon, '<font color="#ff9a9a">Guardians are faster!</font>')
task.spawn(function()
	while true do
		local lines = {}
		local weather = workspace:GetAttribute("Weather")
		if weather then
			local left = math.max(0, (workspace:GetAttribute("WeatherEnds") or 0) - os.time())
			table.insert(lines, ("%s  %d:%02d"):format(WEATHER_TEXT[weather] or weather, left // 60, left % 60))
			for _, tip in WEATHER_TIP[weather] or {} do
				table.insert(lines, tip)
			end
		end
		local secret = workspace:GetAttribute("SecretEgg")
		if secret then
			table.insert(lines, '<font color="#ff8ae0">Secret Egg: ' .. secret .. "</font>")
		end
		banner.Visible = #lines > 0
		banner.Text = table.concat(lines, "\n")
		banner.Size = UDim2.new(0, 230, 0, 12 + 20 * #lines)
		local parts = {}
		if player:GetAttribute("Shielded") then
			table.insert(parts, '<font color="#8fd3ff">Shielded (new player)</font>')
		elseif (player:GetAttribute("LockLeft") or 0) > 0 then
			table.insert(parts, ('<font color="#ff9a9a">Base locked %ds</font>'):format(player:GetAttribute("LockLeft")))
		else
			table.insert(parts, '<font color="#ffd27a">Base unlocked! Press the red button to lock it</font>')
		end
		status.Text = table.concat(parts, "   ")
		status.Position = UDim2.new(0.5, 0, 0, workspace:GetAttribute("MamaPhase") and 108 or 84) -- below the top Mama bar
		task.wait(0.5)
	end
end)

-- One Menu toggle on every device discloses navigation on demand (phones keep the movement controls clear).
local camera = workspace.CurrentCamera
local uiScale = gui:WaitForChild("UIScale")
local UserInputService = game:GetService("UserInputService")
local menu = gui:WaitForChild("LeftMenu")
local menuLayout = menu:FindFirstChildOfClass("UIListLayout")
if menuLayout then menuLayout.Parent = nil end
menu.Visible, menu.Size = false, UDim2.fromOffset(188, 188)
local grid = Instance.new("UIGridLayout")
grid.CellSize, grid.CellPadding = UDim2.fromOffset(92, 44), UDim2.fromOffset(4, 4)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.FillDirectionMaxCells = 2
grid.Parent = menu
local menuScale = Instance.new("UIScale")
menuScale.Parent = menu
local toggle = Instance.new("TextButton")
toggle.Name, toggle.Text = "MenuToggle", "Menu"
toggle.Size, toggle.BackgroundColor3 = UDim2.fromOffset(84, 44), Color3.fromRGB(35, 38, 56)
toggle.Font, toggle.TextSize, toggle.TextColor3 = Enum.Font.FredokaOne, 18, Color3.new(1, 1, 1)
toggle.ZIndex, toggle.Parent = 4, gui
local corner = Instance.new("UICorner")
corner.CornerRadius, corner.Parent = UDim.new(0, 10), toggle
local toggleScale = Instance.new("UIScale")
toggleScale.Parent = toggle
local touch -- touch devices also hide the joystick/jump while navigation is open
local menuLocked = false
local GuiService = game:GetService("GuiService")
local savedTouchEnabled
local function syncTouchControls()
	if touch and (menu.Visible or menuLocked) then
		if savedTouchEnabled == nil then savedTouchEnabled = GuiService.TouchControlsEnabled end
		GuiService.TouchControlsEnabled = false
	elseif savedTouchEnabled ~= nil then
		GuiService.TouchControlsEnabled, savedTouchEnabled = savedTouchEnabled, nil
	end
end
menu:GetPropertyChangedSignal("Visible"):Connect(syncTouchControls)
local menuPanels = { StablePanel = true, FusePanel = true, ShopPanel = true, IndexPanel = true,
	RebirthPanel = true, StorePanel = true, GuidePanel = true, BasePanel = true }
local function syncMenuLock()
	menuLocked = false
	local openPanel
	for _, child in gui:GetChildren() do
		if menuPanels[child.Name] and child:IsA("GuiObject") and child.Visible then menuLocked, openPanel = true, child.Name; break end
	end
	gui:SetAttribute("OpenMenuPanel", openPanel)
	toggle.Active, toggle.Interactable, toggle.AutoButtonColor = not menuLocked, not menuLocked, not menuLocked
	toggle.TextColor3 = menuLocked and Color3.fromRGB(145, 150, 170) or Color3.new(1, 1, 1)
	for _, child in menu:GetChildren() do
		if child:IsA("TextButton") then
			child.Active, child.Interactable, child.AutoButtonColor = not menuLocked, not menuLocked, not menuLocked
		end
	end
	if menuLocked then menu.Visible, toggle.Text = false, "Menu" end
	syncTouchControls()
end
local function observePanel(child)
	if menuPanels[child.Name] and child:IsA("GuiObject") then
		child:GetPropertyChangedSignal("Visible"):Connect(syncMenuLock)
		syncMenuLock()
	end
end
gui.ChildAdded:Connect(observePanel)
for _, child in gui:GetChildren() do observePanel(child) end
local function closeMenu()
	menu.Visible, toggle.Text = false, "Menu"
end
local function connectButton(child)
	if child:IsA("TextButton") then
		child.Activated:Connect(closeMenu)
		child.Size = UDim2.fromOffset(92, 44)
		child.Active, child.Interactable, child.AutoButtonColor = not menuLocked, not menuLocked, not menuLocked
	end
end
menu.ChildAdded:Connect(connectButton)
for _, child in menu:GetChildren() do connectButton(child) end
toggle.Activated:Connect(function()
	if menuLocked then return end
	menu.Visible = not menu.Visible
	toggle.Text = menu.Visible and "Close" or "Menu"
end)
local function rescale()
	local scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.25)
	uiScale.Scale = scale
	touch = UserInputService.TouchEnabled
	menuScale.Scale, toggleScale.Scale = 1 / scale, 1 / scale -- toggle and entries keep real 44 px targets
	-- 12 px from the left edge, 8 px below the HUD's drawn bottom (the TopBar is scaled by uiScale)
	local hudBottom = (top.Position.Y.Offset + top.Size.Y.Offset) * scale
	toggle.Position = UDim2.fromOffset(12 / scale, (hudBottom + 8) / scale)
	menu.Position = UDim2.fromOffset(12 / scale, (hudBottom + 8 + 44 + 6) / scale)
	syncMenuLock()
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(rescale)
rescale()

