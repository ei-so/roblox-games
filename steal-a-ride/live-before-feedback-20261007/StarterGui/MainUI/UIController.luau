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

local function refresh()
	cashLabel.Text = "$" .. Format.number(player:GetAttribute("Cash") or 0)
	perSecLabel.Text = "+$" .. Format.number(player:GetAttribute("CashPerSecond") or 0) .. "/s"
	speedLabel.Text = "⚡ " .. Format.number(player:GetAttribute("Speed") or 16)
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
toast.Position = UDim2.new(0.5, 0, 0, 250) -- offset, so UIScale keeps it below the Mama bar on phones
toast.Size = UDim2.new(0, 620, 0, 52)
toast.BackgroundTransparency = 1
toast.Font = Enum.Font.FredokaOne
toast.TextScaled = true
toast.RichText = true
toast.TextColor3 = Color3.new(1, 1, 1)
toast.TextTransparency = 1
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
	toast.Size = UDim2.new(0, 560, 0, 46)
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0, 620, 0, 52) }):Play()
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
banner.Size = UDim2.new(0, 300, 0, 60)
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
task.spawn(function()
	while true do
		local lines = {}
		local weather = workspace:GetAttribute("Weather")
		if weather then
			local left = math.max(0, (workspace:GetAttribute("WeatherEnds") or 0) - os.time())
			table.insert(lines, ("%s  %d:%02d"):format(WEATHER_TEXT[weather] or weather, left // 60, left % 60))
		end
		local secret = workspace:GetAttribute("SecretEgg")
		if secret then
			table.insert(lines, '<font color="#ff8ae0">Secret Egg: ' .. secret .. "</font>")
		end
		banner.Visible = #lines > 0
		banner.Text = table.concat(lines, "\n")
		local parts = {}
		if player:GetAttribute("Shielded") then
			table.insert(parts, '<font color="#8fd3ff">Shielded (new player)</font>')
		elseif (player:GetAttribute("LockLeft") or 0) > 0 then
			table.insert(parts, ('<font color="#ff9a9a">Base locked %ds</font>'):format(player:GetAttribute("LockLeft")))
		else
			table.insert(parts, '<font color="#ffd27a">Base unlocked! Press the red button to lock it</font>')
		end
		status.Text = table.concat(parts, "   ")
		task.wait(0.5)
	end
end)

-- Scale the whole UI with screen height so phones get a smaller HUD
local camera = workspace.CurrentCamera
local uiScale = gui:WaitForChild("UIScale")
local function rescale()
	uiScale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.25)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

