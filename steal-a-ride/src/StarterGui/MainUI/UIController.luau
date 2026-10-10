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
top.CashPill.Size = UDim2.fromOffset(206, 48) -- 34 px icon well on the left (added with the event cards below)
cashLabel.Position = UDim2.fromOffset(44, 2)
cashLabel.Size = UDim2.new(1, -52, 0, 28)
cashLabel.TextScaled = false
cashLabel.TextSize = 26
perSecLabel.Position = UDim2.fromOffset(44, 30)
perSecLabel.Size = UDim2.new(1, -52, 0, 16)
perSecLabel.TextScaled = false
perSecLabel.TextSize = 18
top.SpeedPill.Size = UDim2.fromOffset(132, 44)
top.Size = UDim2.fromOffset(346, 48)
speedLabel.TextScaled = false
speedLabel.TextSize = 24
speedLabel.Position, speedLabel.Size = UDim2.fromOffset(42, 8), UDim2.new(1, -50, 1, -16)
local layout = top:FindFirstChildOfClass("UIListLayout")
if layout then layout.Padding = UDim.new(0, 8) end

-- Boost timer: a gold chip under the speed pill while a Speed Soda / Mama speed-up runs (server attr BoostUntil)
local boostChip = Instance.new("TextLabel")
boostChip.Name = "BoostTimer"
boostChip.Position = UDim2.fromOffset(16 + 206 + 8, 8 + 48 + 6)
boostChip.Size = UDim2.fromOffset(150, 26)
boostChip.BackgroundColor3 = Color3.fromRGB(255, 176, 46)
boostChip.Font = Enum.Font.FredokaOne
boostChip.TextSize = 17
boostChip.TextColor3 = Color3.new(1, 1, 1)
boostChip.Visible = false
Instance.new("UICorner", boostChip).CornerRadius = UDim.new(0, 12)
local chipBorder = Instance.new("UIStroke")
chipBorder.Color, chipBorder.Thickness, chipBorder.ApplyStrokeMode = Color3.new(1, 1, 1), 3, Enum.ApplyStrokeMode.Border
chipBorder.Parent = boostChip
local chipText = Instance.new("UIStroke")
chipText.Color, chipText.Thickness = Color3.fromRGB(110, 60, 0), 1.5
chipText.Parent = boostChip
boostChip.Parent = gui

local function speedText(speed: number): string -- one decimal only when it matters, to compare with guardian speeds
	return speed % 1 == 0 and tostring(speed) or ("%.1f"):format(speed)
end

local boostTicking = false
local function tickBoost()
	local left = (player:GetAttribute("BoostUntil") or 0) - workspace:GetServerTimeNow()
	boostChip.Visible = left > 0
	if left <= 0 then
		boostTicking = false
		return
	end
	local s = math.ceil(left)
	boostChip.Text = ("Speed Boost %d:%02d"):format(s // 60, s % 60)
	task.delay(0.25, tickBoost)
end

local function refresh()
	cashLabel.Text = "$" .. Format.number(player:GetAttribute("Cash") or 0)
	perSecLabel.Text = "+$" .. Format.number(player:GetAttribute("CashPerSecond") or 0) .. "/s"
	-- always the real speed right now (mount, saddle, boosts, Dash, carrying, water), same units as guardian speeds
	local speed = player:GetAttribute("CurrentSpeed") or player:GetAttribute("Speed") or 20
	speedLabel.Text = speedText(speed)
	warning.Visible = player:GetAttribute("DataLoadFailed") == true
	if not boostTicking and (player:GetAttribute("BoostUntil") or 0) > workspace:GetServerTimeNow() then
		boostTicking = true
		tickBoost()
	end
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

local function showFriendBonus()
	local friends = player:GetAttribute("FriendCount") or 0
	if friends > 0 then
		showToast(("Friends: +%d%% income (%d in this server)"):format(math.min(3, friends) * 10, friends))
	end
end
player:GetAttributeChangedSignal("FriendCount"):Connect(showFriendBonus)
showFriendBonus()

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

-- Base lock and nest refill: compact cards under the event cards (built with them below).
local status = Instance.new("Frame")
status.Name = "Status"
status.Size = UDim2.fromOffset(244, 0)
status.AutomaticSize = Enum.AutomaticSize.Y
status.BackgroundTransparency = 1
local statusList = Instance.new("UIListLayout")
statusList.SortOrder = Enum.SortOrder.LayoutOrder
statusList.Padding = UDim.new(0, 6)
statusList.Parent = status
status.Parent = gui

-- Event column (top right): Weather, Mama Dragon and Secret Egg cards (the EventBanner), then Mama's Top damage
-- and the base lock / nest refill cards, stacked by UIListLayouts. Every time is a server attribute on the
-- GetServerTimeNow basis, so all clients count down to the same instant and late joiners see the true time left.
local WEATHER_TEXT = {
	Thunderstorm = '<font color="#a9dcff">THUNDERSTORM</font>',
	GoldenHour = '<font color="#ffd25a">GOLDEN HOUR</font>',
	BloodMoon = '<font color="#ff7a7a">BLOOD MOON</font>',
}
-- Lines under the weather name: what grabbing an egg can give you right now
local WEATHER_TIP = {}
for mutation, m in Config.Mutations do
	WEATHER_TIP[m.event] = {
		("Grab eggs: %d%% %s"):format(math.round(m.chance * 100), mutation),
		("x%s income, +%s speed"):format(m.incomeX, m.speed),
	}
end
table.insert(WEATHER_TIP.BloodMoon, '<font color="#ffb0b0">Guardians are faster!</font>')

-- Pure helpers below are run as actual source by tests/run_hud_checks.py.
-- M:SS, or H:MM:SS from an hour; rounds up so a timer never shows 0:00 while time is left
local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	if s >= 3600 then
		return ("%d:%02d:%02d"):format(s // 3600, s // 60 % 60, s % 60)
	end
	return ("%d:%02d"):format(s // 60, s % 60)
end
-- What the Weather card says now (get = workspace attribute reader); nil hides the card
local function weatherView(get, now: number)
	local weather = get("Weather")
	if weather then
		local ends = get("WeatherEnds")
		return { key = weather, icon = weather, title = WEATHER_TEXT[weather] or string.upper(weather),
			detail = not ends and "Happening now" or ends > now and "Ends in " .. clock(ends - now) or "Clearing up…",
			tips = WEATHER_TIP[weather] }
	end
	local nextAt = get("NextWeather")
	if not nextAt then
		return nil
	end
	return { key = "clear", icon = "Clear", title = "Clear skies",
		detail = nextAt > now and "Next weather in " .. clock(nextAt - now) or "Weather on the way…" }
end
-- What the Mama Dragon card says now; the HP bar and Top damage stay in RetentionUI
local function mamaView(get, now: number)
	local phase, ends = get("MamaPhase"), get("MamaEnds")
	if phase == "warning" then
		return { key = "warning", alert = true, detail = ends and ends > now and "Arriving in " .. clock(ends - now) or "Arriving now!" }
	elseif phase then
		return { key = "active", alert = true,
			detail = ends and ends > now and "Here now! " .. clock(ends - now) .. " left" or "Here now!" }
	elseif get("MamaWaiting") then
		return { key = "waiting", detail = "Waiting for weather…" }
	end
	local nextAt = get("NextMama")
	if not nextAt then
		return nil
	end
	return { key = "scheduled", detail = nextAt > now and "Next in " .. clock(nextAt - now) or "Arriving soon…" }
end
-- Column top (unscaled px): 8, or just below anything drawn above the column's x-range (cash/speed pills,
-- boost chip, Mama bar on narrow screens). Boxes are absolute pixels; scale is the MainUI UIScale.
local function columnTop(x0: number, x1: number, boxes, scale: number, originY: number): number
	local y = 8
	for _, b in boxes do
		if b.x0 < x1 and b.x1 > x0 then
			y = math.max(y, (b.y1 - originY) / scale + 8)
		end
	end
	return y
end
-- The Secret Egg card: where it is now (if out) and when the next one spawns
local function secretView(get, now: number)
	local biome, nextAt = get("SecretEgg"), get("NextSecretEgg")
	if biome then
		local nextText = nextAt and (nextAt > now and "Next one in " .. clock(nextAt - now) or "Next one soon")
		return { key = nextText and "out" or "outOnly", icon = "SecretEgg", title = "Secret Egg is out!",
			detail = "In the " .. biome, tips = nextText and { nextText } }
	elseif not nextAt then
		return nil
	end
	return { key = "next", icon = "SecretEgg", title = "Secret Egg",
		detail = nextAt > now and "Next in " .. clock(nextAt - now) or "Appearing soon…" }
end
-- Compact cards: your base lock (tone picks the card colours) and the nest refill
local function baseView(shielded, lockLeft)
	if shielded then
		return { key = "shield", tone = "shield", icon = "Lock", detail = "Base protected" }
	elseif lockLeft and lockLeft > 0 then
		return { key = "locked", tone = "locked", icon = "Lock", detail = ("Base locked %ds"):format(lockLeft) }
	end
	return { key = "open", tone = "open", icon = "LockOpen", detail = "Base unlocked" }
end
local function refillView(get, now: number)
	local at = get("NextNestRefill")
	if not at then
		return nil
	end
	return { key = "refill", icon = "Egg", detail = at > now and "Eggs refill in " .. clock(at - now) or "Eggs refilling…" }
end
-- Seconds until the soonest shown countdown changes digit (times round up, so a digit flips as T - now crosses a whole
-- second). Waking right then keeps the text exact and every client flips at the same server instant.
local function nextTick(now: number, targets): number
	local wait = 1
	for _, at in targets do
		if at > now then
			wait = math.min(wait, (at - now) % 1)
		end
	end
	return wait + 0.02
end
-- End of pure helpers.

local column = Instance.new("Frame")
column.Name = "EventColumn"
column.AnchorPoint = Vector2.new(1, 0)
column.Position = UDim2.new(1, -16, 0, 8)
column.Size = UDim2.fromOffset(244, 0)
column.AutomaticSize = Enum.AutomaticSize.Y
column.BackgroundTransparency = 1
local columnList = Instance.new("UIListLayout")
columnList.SortOrder = Enum.SortOrder.LayoutOrder
columnList.HorizontalAlignment = Enum.HorizontalAlignment.Right
columnList.Padding = UDim.new(0, 8)
columnList.Parent = column
column.Parent = gui

local banner = Instance.new("Frame")
banner.Name = "EventBanner"
banner.LayoutOrder = 1
banner.Size = UDim2.fromOffset(244, 0)
banner.AutomaticSize = Enum.AutomaticSize.Y
banner.BackgroundTransparency = 1
local bannerList = Instance.new("UIListLayout")
bannerList.SortOrder = Enum.SortOrder.LayoutOrder
bannerList.Padding = UDim.new(0, 6)
bannerList.Parent = banner
banner.Parent = column
status.LayoutOrder = 3
status.Parent = column

local function dot(parent, color: Color3, size: number, x: number, y: number, z: number?)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z or 2
	Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	f.Parent = parent
	return f
end
local function cloud(parent, color: Color3, x: number, y: number)
	dot(parent, color, 14, x - 6, y + 2, 3)
	dot(parent, color, 18, x + 2, y - 2, 3)
	dot(parent, color, 12, x + 10, y + 3, 3)
	local base = Instance.new("Frame")
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.Position = UDim2.fromOffset(x + 2, y + 6)
	base.Size = UDim2.fromOffset(26, 8)
	base.BackgroundColor3 = color
	base.BorderSizePixel = 0
	base.ZIndex = 3
	Instance.new("UICorner", base).CornerRadius = UDim.new(1, 0)
	base.Parent = parent
end
local function lock(parent, open: boolean)
	local shackle = Instance.new("Frame")
	shackle.AnchorPoint = Vector2.new(0.5, 0.5)
	shackle.Position = UDim2.fromOffset(open and 22 or 17, open and 10 or 13)
	shackle.Size = UDim2.fromOffset(12, 14)
	shackle.BackgroundTransparency = 1
	shackle.ZIndex = 2
	Instance.new("UICorner", shackle).CornerRadius = UDim.new(1, 0)
	local ring = Instance.new("UIStroke")
	ring.Thickness, ring.Color = 3, Color3.new(1, 1, 1)
	ring.Parent = shackle
	shackle.Parent = parent
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromOffset(17, 22)
	body.Size = UDim2.fromOffset(20, 14)
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	body.BorderSizePixel = 0
	body.ZIndex = 3
	Instance.new("UICorner", body).CornerRadius = UDim.new(0, 4)
	body.Parent = parent
	dot(parent, Color3.fromRGB(60, 50, 70), 5, 17, 21, 4)
end
local function egg(parent, shell: Color3)
	local e = Instance.new("Frame")
	e.AnchorPoint = Vector2.new(0.5, 0.5)
	e.Position = UDim2.fromOffset(17, 18)
	e.Size = UDim2.fromOffset(20, 25)
	e.BackgroundColor3 = shell
	e.BorderSizePixel = 0
	e.ZIndex = 2
	Instance.new("UICorner", e).CornerRadius = UDim.new(1, 0)
	e.Parent = parent
end
-- Small flat icons drawn from rounded frames (34 x 34), so they stay crisp at every UIScale
local ICONS = {
	Clear = function(p)
		dot(p, Color3.fromRGB(255, 214, 90), 20, 21, 12)
		cloud(p, Color3.fromRGB(245, 250, 255), 13, 21)
	end,
	Thunderstorm = function(p)
		cloud(p, Color3.fromRGB(150, 170, 200), 16, 13)
		for i, spot in { { 16, 25, -25 }, { 13, 30, 25 } } do
			local bolt = Instance.new("Frame")
			bolt.AnchorPoint = Vector2.new(0.5, 0.5)
			bolt.Position = UDim2.fromOffset(spot[1], spot[2])
			bolt.Size = UDim2.fromOffset(4, 9)
			bolt.Rotation = spot[3]
			bolt.BackgroundColor3 = Color3.fromRGB(255, 220, 70)
			bolt.BorderSizePixel = 0
			bolt.ZIndex = 4 + i
			bolt.Parent = p
		end
	end,
	GoldenHour = function(p)
		dot(p, Color3.fromRGB(255, 160, 60), 28, 17, 17)
		dot(p, Color3.fromRGB(255, 214, 90), 20, 17, 17)
		dot(p, Color3.fromRGB(255, 240, 170), 8, 13, 13)
	end,
	BloodMoon = function(p)
		dot(p, Color3.fromRGB(230, 60, 70), 26, 17, 17)
		dot(p, Color3.fromRGB(170, 30, 45), 8, 12, 13)
		dot(p, Color3.fromRGB(170, 30, 45), 5, 22, 22)
		dot(p, Color3.fromRGB(170, 30, 45), 4, 22, 11)
	end,
	Mama = function(p) -- a dragon eye: amber iris, slit pupil, highlight
		dot(p, Color3.fromRGB(255, 120, 40), 30, 17, 17)
		dot(p, Color3.fromRGB(255, 196, 60), 22, 17, 17)
		local pupil = Instance.new("Frame")
		pupil.AnchorPoint = Vector2.new(0.5, 0.5)
		pupil.Position = UDim2.fromOffset(17, 17)
		pupil.Size = UDim2.fromOffset(6, 20)
		pupil.BackgroundColor3 = Color3.fromRGB(40, 16, 10)
		pupil.ZIndex = 4
		Instance.new("UICorner", pupil).CornerRadius = UDim.new(1, 0)
		pupil.Parent = p
		dot(p, Color3.new(1, 1, 1), 5, 12, 11, 5)
	end,
	Lock = function(p)
		lock(p, false)
	end,
	LockOpen = function(p)
		lock(p, true)
	end,
	Egg = function(p)
		egg(p, Color3.fromRGB(255, 246, 220))
		dot(p, Color3.fromRGB(110, 190, 90), 6, 13, 14, 3)
		dot(p, Color3.fromRGB(110, 190, 90), 4, 21, 22, 3)
	end,
	SecretEgg = function(p)
		egg(p, Color3.fromRGB(255, 150, 225))
		dot(p, Color3.new(1, 1, 1), 5, 13, 13, 3)
		dot(p, Color3.fromRGB(255, 240, 140), 4, 21, 21, 3)
		dot(p, Color3.new(1, 1, 1), 3, 21, 11, 3)
	end,
	Coin = function(p)
		dot(p, Color3.fromRGB(230, 160, 30), 24, 17, 17)
		dot(p, Color3.fromRGB(255, 214, 90), 18, 17, 17, 3)
		dot(p, Color3.fromRGB(255, 244, 190), 6, 13, 13, 4)
	end,
	Bolt = function(p)
		for i, s in { { 19, 10, 6, 13, 20 }, { 17, 17, 13, 5, -20 }, { 15, 24, 6, 13, 20 } } do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position, f.Size, f.Rotation = UDim2.fromOffset(s[1], s[2]), UDim2.fromOffset(s[3], s[4]), s[5]
			f.BackgroundColor3, f.BorderSizePixel, f.ZIndex = Color3.fromRGB(255, 220, 70), 0, 2 + i
			f.Parent = p
		end
	end,
	Menu = function(p)
		for _, y in { 11, 17, 23 } do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position, f.Size = UDim2.fromOffset(17, y), UDim2.fromOffset(18, 3)
			f.BackgroundColor3, f.BorderSizePixel, f.ZIndex = Color3.new(1, 1, 1), 0, 2
			Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
			f.Parent = p
		end
	end,
}

local function label(parent, size: number, color: Color3, y: number, h: number)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(42, y)
	t.Size = UDim2.new(1, -42, 0, h)
	t.Font = Enum.Font.FredokaOne
	t.TextSize = size
	t.TextColor3 = color
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.RichText = true
	t.TextTruncate = Enum.TextTruncate.AtEnd
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Color = 1.5, Color3.fromRGB(20, 24, 40)
	stroke.Parent = t
	t.Parent = parent
	return t
end
-- One HUD kit on both sides: bright fill, 3 px white border, 12 px corners, a dark icon well, outlined white text
local WHITE, WELL = Color3.new(1, 1, 1), Color3.fromRGB(20, 24, 40)
-- One rounded card: icon well on the left, title + countdown on the right, optional tip lines underneath.
-- A compact card has one line beside the icon.
local function card(name: string, order: number, fill: Color3, parent: Instance, compact: boolean?)
	local f = Instance.new("Frame")
	f.Name, f.LayoutOrder = name, order
	f.Size = UDim2.fromOffset(244, compact and 46 or 56)
	f.BackgroundColor3, f.BackgroundTransparency = fill, 0.08
	f.Visible = false
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode, border.Thickness, border.Color = Enum.ApplyStrokeMode.Border, 3, WHITE
	border.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, compact and 6 or 8), UDim.new(0, compact and 6 or 8)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 10)
	pad.Parent = f
	local pop = Instance.new("UIScale")
	pop.Parent = f
	local well = Instance.new("Frame")
	well.Name = "Icon"
	well.Size = UDim2.fromOffset(34, 34)
	well.Position = UDim2.fromOffset(0, 1)
	well.BackgroundColor3, well.BackgroundTransparency = WELL, 0.7
	well.ClipsDescendants = true
	Instance.new("UICorner", well).CornerRadius = UDim.new(0, 10)
	well.Parent = f
	local title = label(f, 19, WHITE, -1, 21)
	local detail = label(f, 16, WHITE, 20, 19)
	local tips = label(f, 15, WHITE, 44, 0)
	tips.Position, tips.Size = UDim2.fromOffset(2, 44), UDim2.new(1, -2, 0, 0)
	tips.TextYAlignment, tips.TextTruncate, tips.LineHeight = Enum.TextYAlignment.Top, Enum.TextTruncate.None, 1.05
	tips.Visible = false
	if compact then
		title.Visible = false
		well.Position = UDim2.new()
		detail.Position, detail.Size, detail.TextSize = UDim2.fromOffset(42, 0), UDim2.new(1, -42, 0, 34), 17
	end
	f.Parent = parent
	return { frame = f, border = border, pop = pop, well = well, title = title, detail = detail, tips = tips,
		compact = compact }
end
local MAMA_FILL = Color3.fromRGB(230, 110, 45)
local weatherCard = card("WeatherCard", 1, Color3.fromRGB(64, 135, 245), banner)
local mamaCard = card("MamaCard", 2, MAMA_FILL, banner)
mamaCard.title.Text = "Mama Dragon"
ICONS.Mama(mamaCard.well)
local secretCard = card("SecretCard", 3, Color3.fromRGB(190, 75, 175), banner)
local baseCard = card("BaseCard", 1, Color3.fromRGB(215, 160, 40), status, true)
local refillCard = card("RefillCard", 2, Color3.fromRGB(47, 175, 92), status, true)
-- the base card's colours follow its state: gold unlocked, red locked, blue protected
local TONES = {
	open = Color3.fromRGB(215, 160, 40),
	locked = Color3.fromRGB(215, 60, 70),
	shield = Color3.fromRGB(40, 170, 170),
}
-- the same dark icon well for the left side's pills and Menu button
local function iconWell(parent, x: number, y: number, icon: string)
	local well = Instance.new("Frame")
	well.Name = "Icon"
	well.Position, well.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(34, 34)
	well.BackgroundColor3, well.BackgroundTransparency = WELL, 0.7
	well.ClipsDescendants = true
	Instance.new("UICorner", well).CornerRadius = UDim.new(0, 10)
	ICONS[icon](well)
	well.Parent = parent
	return well
end
iconWell(top.CashPill, 7, 7, "Coin")
iconWell(top.SpeedPill, 5, 5, "Bolt")
for _, pill in { top.CashPill, top.SpeedPill } do
	local round = pill:FindFirstChildOfClass("UICorner")
	if round then round.CornerRadius = UDim.new(0, 12) end
end

local POP = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function show(c, view)
	local was = c.frame.Visible and c.key
	c.frame.Visible = view ~= nil
	if not view then
		c.key = nil
		return
	end
	if view.key ~= was then -- a new state: one small pop, nothing per second
		c.key = view.key
		c.pop.Scale = 0.92
		TweenService:Create(c.pop, POP, { Scale = 1 }):Play()
		if view.icon then
			c.well:ClearAllChildren()
			Instance.new("UICorner", c.well).CornerRadius = UDim.new(0, 10)
			local draw = ICONS[view.icon] or ICONS.Clear
			draw(c.well)
		end
		if view.title then c.title.Text = view.title end
		local tone = TONES[view.tone]
		if tone then
			c.frame.BackgroundColor3 = tone
		end
		c.border.Color = view.alert and Color3.fromRGB(255, 96, 96) or WHITE
		c.tips.Visible = view.tips ~= nil
		c.tips.Size = UDim2.new(1, -2, 0, view.tips and 18 * #view.tips or 0)
		if not c.compact then
			c.frame.Size = UDim2.fromOffset(244, 56 + (view.tips and 4 + 18 * #view.tips or 0))
		end
	end
	c.detail.Text = view.detail
	c.tips.Text = view.tips and table.concat(view.tips, "\n") or ""
end

local mamaTop -- RetentionUI's "Top damage" list; it joins the column so it never overlaps the cards
local OBSTACLES = { "TopBar", "BoostTimer", "MamaBar", "MenuToggle" }
local function placeColumn()
	if not mamaTop then
		mamaTop = gui:FindFirstChild("MamaTop")
		if mamaTop then
			mamaTop.LayoutOrder = 2
			-- the same orange card as Mama's, sized to its lines; no box (and no gap) until someone has hit her
			mamaTop.Size, mamaTop.AutomaticSize = UDim2.fromOffset(244, 0), Enum.AutomaticSize.Y
			mamaTop.TextXAlignment, mamaTop.TextSize = Enum.TextXAlignment.Left, 16
			mamaTop.BackgroundColor3 = MAMA_FILL
			Instance.new("UICorner", mamaTop).CornerRadius = UDim.new(0, 12)
			local border = Instance.new("UIStroke")
			border.ApplyStrokeMode, border.Thickness, border.Color, border.Transparency =
				Enum.ApplyStrokeMode.Border, 3, WHITE, 0
			border.Parent = mamaTop
			local pad = Instance.new("UIPadding")
			pad.Parent = mamaTop
			local function fill()
				local empty = mamaTop.ContentText == ""
				local inset = UDim.new(0, empty and 0 or 8)
				mamaTop.BackgroundTransparency, border.Enabled = empty and 1 or 0.08, not empty
				pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = inset, inset, inset, inset
			end
			mamaTop:GetPropertyChangedSignal("ContentText"):Connect(fill)
			fill()
			mamaTop.Parent = column
		end
	end
	local boxes = {}
	for _, name in OBSTACLES do
		local o = gui:FindFirstChild(name)
		if o and o:IsA("GuiObject") and o.Visible then
			table.insert(boxes, { x0 = o.AbsolutePosition.X, x1 = o.AbsolutePosition.X + o.AbsoluteSize.X,
				y1 = o.AbsolutePosition.Y + o.AbsoluteSize.Y })
		end
	end
	local scale = gui:FindFirstChildOfClass("UIScale")
	local x0 = column.AbsolutePosition.X
	column.Position = UDim2.new(1, -16, 0, columnTop(x0, x0 + column.AbsoluteSize.X, boxes, scale and scale.Scale or 1,
		gui.AbsolutePosition.Y))
end

local function getAttr(name: string)
	return workspace:GetAttribute(name)
end
local function render()
	local now = workspace:GetServerTimeNow()
	show(weatherCard, weatherView(getAttr, now))
	show(mamaCard, mamaView(getAttr, now))
	show(secretCard, secretView(getAttr, now))
	show(baseCard, baseView(player:GetAttribute("Shielded"), player:GetAttribute("LockLeft")))
	show(refillCard, refillView(getAttr, now))
	placeColumn()
end
-- Re-render at once when an event changes, otherwise only when a shown countdown changes digit (about once a
-- second), so every client flips its countdowns at the same moment and nothing updates per frame.
local renderQueued = false
local function queueRender()
	if not renderQueued then
		renderQueued = true
		task.defer(function()
			renderQueued = false
			render()
		end)
	end
end
for _, name in { "Weather", "WeatherEnds", "NextWeather", "MamaPhase", "MamaEnds", "MamaWaiting", "NextMama",
	"SecretEgg", "NextSecretEgg", "NextNestRefill" } do
	workspace:GetAttributeChangedSignal(name):Connect(queueRender)
end
for _, name in { "Shielded", "LockLeft" } do
	player:GetAttributeChangedSignal(name):Connect(queueRender)
end
local function watchObstacle(child)
	if table.find(OBSTACLES, child.Name) then
		for _, prop in { "Visible", "AbsolutePosition", "AbsoluteSize" } do
			child:GetPropertyChangedSignal(prop):Connect(queueRender)
		end
		queueRender()
	elseif child.Name == "MamaTop" then -- RetentionUI made it: move it into the column
		queueRender()
	end
end
gui.ChildAdded:Connect(watchObstacle)
for _, child in gui:GetChildren() do watchObstacle(child) end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(queueRender)
local TIMERS = { "WeatherEnds", "NextWeather", "MamaEnds", "NextMama", "NextNestRefill", "NextSecretEgg" }
task.spawn(function()
	while true do
		render()
		local targets = {}
		for _, name in TIMERS do
			local at = workspace:GetAttribute(name)
			if type(at) == "number" then table.insert(targets, at) end
		end
		task.wait(nextTick(workspace:GetServerTimeNow(), targets))
	end
end)

-- One Menu toggle on every device discloses navigation on demand (phones keep the movement controls clear).
local camera = workspace.CurrentCamera
local uiScale = gui:WaitForChild("UIScale")
local UserInputService = game:GetService("UserInputService")
local menu = gui:WaitForChild("LeftMenu")
local menuLayout = menu:FindFirstChildOfClass("UIListLayout")
if menuLayout then menuLayout.Parent = nil end
menu.Visible, menu.Size, menu.ZIndex = false, UDim2.fromOffset(188, 188), 30
local grid = Instance.new("UIGridLayout")
grid.CellSize, grid.CellPadding = UDim2.fromOffset(92, 44), UDim2.fromOffset(4, 4)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.FillDirectionMaxCells = 2
grid.Parent = menu
local menuScale = Instance.new("UIScale")
menuScale.Parent = menu
local toggle = Instance.new("TextButton")
toggle.Name, toggle.Text = "MenuToggle", "Menu"
toggle.Size, toggle.BackgroundColor3 = UDim2.fromOffset(112, 44), Color3.fromRGB(35, 38, 56)
toggle.Font, toggle.TextSize, toggle.TextColor3 = Enum.Font.FredokaOne, 20, Color3.new(1, 1, 1)
toggle.ZIndex, toggle.Parent = 30, gui
local corner = Instance.new("UICorner")
corner.CornerRadius, corner.Parent = UDim.new(0, 12), toggle
iconWell(toggle, 5, 5, "Menu")
toggle.TextXAlignment = Enum.TextXAlignment.Right -- the label sits right of the icon well
local togglePad = Instance.new("UIPadding")
togglePad.PaddingRight, togglePad.Parent = UDim.new(0, 14), toggle
-- the same white border and text outline as the entries it opens (normalizeEntry)
local toggleBorder = Instance.new("UIStroke")
toggleBorder.Color, toggleBorder.Thickness, toggleBorder.ApplyStrokeMode = Color3.new(1, 1, 1), 3, Enum.ApplyStrokeMode.Border
toggleBorder.Parent = toggle
local toggleText = Instance.new("UIStroke")
toggleText.Color, toggleText.Thickness = Color3.fromRGB(25, 30, 40), 1.5
toggleText.Parent = toggle
local toggleScale = Instance.new("UIScale")
toggleScale.Parent = toggle
local menuPanels = { StablePanel = true, FusePanel = true, ShopPanel = true, IndexPanel = true,
	RebirthPanel = true, StorePanel = true, GuidePanel = true, BasePanel = true, QuestsPanel = true,
	DailyPanel = true, OfflinePanel = true }
local function syncMenuLock()
	local openPanel
	for _, child in gui:GetChildren() do
		if menuPanels[child.Name] and child:IsA("GuiObject") and child.Visible then openPanel = child.Name; break end
	end
	gui:SetAttribute("OpenMenuPanel", openPanel)
end
-- Scaled text sizes each label to its own word length; give every label of one role (same box and parent shape)
-- the largest size that fits all of them, so short words never render bigger than their neighbours.
local TextService = game:GetService("TextService")
local function localScale(t)
	local s, node = 1, t
	while node and node ~= gui.Parent do
		local scale = node:FindFirstChildOfClass("UIScale")
		if scale then s *= scale.Scale end
		node = node.Parent
	end
	return s
end
local function fitSize(t, s)
	local pad = t:FindFirstChildOfClass("UIPadding")
	local w, h = t.AbsoluteSize.X / s - 2, t.AbsoluteSize.Y / s - 2
	if pad then
		w -= pad.PaddingLeft.Offset + pad.PaddingRight.Offset + (pad.PaddingLeft.Scale + pad.PaddingRight.Scale) * w
		h -= pad.PaddingTop.Offset + pad.PaddingBottom.Offset + (pad.PaddingTop.Scale + pad.PaddingBottom.Scale) * h
	end
	local size = math.clamp(math.floor(h), 8, 100)
	while size > 8 do
		local b = TextService:GetTextSize(t.ContentText, size, t.Font, Vector2.new(t.TextWrapped and math.max(1, w) or 10000, 10000))
		if b.X <= w and b.Y <= h then break end
		size -= 1
	end
	return size
end
local watched = setmetatable({}, { __mode = "k" })
local queueFit
local function uniformText(panel)
	local groups = {}
	for _, t in panel:GetDescendants() do
		if not ((t:IsA("TextLabel") or t:IsA("TextButton")) and (t.TextScaled or t:GetAttribute("UniformText"))) then continue end
		if not watched[t] then
			watched[t] = true
			t:GetPropertyChangedSignal("ContentText"):Connect(function() queueFit(panel) end)
		end
		if t.ContentText == "X" then -- every panel's close button reads the same
			t:SetAttribute("UniformText", true)
			t.TextScaled, t.TextSize = false, 24
		elseif t.ContentText ~= "" and t.AbsoluteSize.X > 0 and t.Parent:IsA("GuiBase2d") then
			local s = localScale(t)
			local key = table.concat({ t.ClassName, math.round(t.AbsoluteSize.Y / s), tostring(t.TextWrapped),
				t.Parent.ClassName, math.round(t.Parent.AbsoluteSize.Y / s) }, "|")
			local group = groups[key] or { size = 100 }
			groups[key] = group
			group.size = math.min(group.size, fitSize(t, s))
			table.insert(group, t)
		end
	end
	for _, group in groups do
		for _, t in ipairs(group) do -- skip the group's size field
			t:SetAttribute("UniformText", true)
			t.TextScaled, t.TextSize = false, group.size
		end
	end
end
local fitQueued = {}
function queueFit(panel)
	if fitQueued[panel] or not panel.Visible or panel.Name == "StablePanel" or panel.Name == "FusePanel" then return end
	fitQueued[panel] = true
	task.delay(0.05, function() -- after the panel's own rebuild and one layout pass
		fitQueued[panel] = nil
		if panel.Visible then uniformText(panel) end
	end)
end
local function observePanel(child)
	if menuPanels[child.Name] and child:IsA("GuiObject") then
		child.DescendantAdded:Connect(function() queueFit(child) end)
		child.DescendantRemoving:Connect(function() queueFit(child) end)
		child:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() queueFit(child) end)
		child:GetPropertyChangedSignal("Visible"):Connect(function()
			queueFit(child)
			if child.Visible then
				for _, other in gui:GetChildren() do
					if other ~= child and menuPanels[other.Name] and other:IsA("GuiObject") then other.Visible = false end
				end
				menu.Visible, toggle.Text = false, "Menu"
			end
			syncMenuLock()
		end)
		syncMenuLock()
	end
end
gui.ChildAdded:Connect(observePanel)
for _, child in gui:GetChildren() do observePanel(child) end
local function closeMenu()
	menu.Visible, toggle.Text = false, "Menu"
end
-- Entries come from several modules; give them one type size and one stroke set so no label shrinks to fit.
local function normalizeEntry(b)
	for _, c in b:GetChildren() do
		if c:IsA("UIStroke") or c:IsA("UIPadding") then c:Destroy() end
	end
	b.Font, b.TextScaled, b.TextWrapped, b.TextSize = Enum.Font.FredokaOne, false, false, 20
	local border = Instance.new("UIStroke")
	border.Color, border.Thickness, border.ApplyStrokeMode = Color3.new(1, 1, 1), 3, Enum.ApplyStrokeMode.Border
	border.Parent = b
	local textStroke = Instance.new("UIStroke")
	textStroke.Color, textStroke.Thickness = Color3.fromRGB(25, 30, 40), 1.5
	textStroke.Parent = b
end
local function connectButton(child)
	if child:IsA("TextButton") then
		child.Activated:Connect(closeMenu)
		child.Size = UDim2.fromOffset(92, 44)
		child.Active, child.Interactable, child.AutoButtonColor, child.ZIndex = true, true, true, 31
		task.defer(normalizeEntry, child) -- after the owning module finishes adding its strokes/padding
	end
end
menu.ChildAdded:Connect(connectButton)
for _, child in menu:GetChildren() do connectButton(child) end
toggle.Activated:Connect(function()
	menu.Visible = not menu.Visible
	toggle.Text = menu.Visible and "Close" or "Menu"
end)
local function rescale()
	local scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.25)
	uiScale.Scale = scale
	menuScale.Scale, toggleScale.Scale = 1 / scale, 1 / scale -- toggle and entries keep real 44 px targets
	-- 12 px from the left edge, 8 px below the HUD's drawn bottom (the TopBar is scaled by uiScale)
	local hudBottom = (top.Position.Y.Offset + top.Size.Y.Offset) * scale
	toggle.Position = UDim2.fromOffset(12 / scale, (hudBottom + 8) / scale)
	local menuX, menuY = 12, hudBottom + 8 + 44 + 6
	if camera.ViewportSize.Y < 500 or menuY + 188 > gui.AbsoluteSize.Y then menuX, menuY = 132, hudBottom + 8 end -- short landscape: clear the thumbstick
	menu.Position = UDim2.fromOffset(menuX / scale, menuY / scale)
	syncMenuLock()
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(rescale)
rescale()

-- Roblox's thumbstick/jump: under open panels on phones (panels fill the screen), on top and usable on tablets.
local playerGui = gui.Parent
local function layerTouchControls()
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if touchGui then
		local size = camera.ViewportSize
		touchGui.DisplayOrder = math.min(size.X, size.Y) < 500 and -1 or 1
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(layerTouchControls)
playerGui.ChildAdded:Connect(layerTouchControls)
layerTouchControls()

