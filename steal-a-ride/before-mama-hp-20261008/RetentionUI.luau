-- Index panel, Store panel, daily reward popup, offline summary popup, Mama's Revenge HP bar, VIP chat tag.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local CreatureBuilder = require(Shared:WaitForChild("CreatureBuilder"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local gui = script.Parent
local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local PANEL = rgb(35, 38, 56)

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
	return o
end
local function outline(o, color, thickness)
	new("UIStroke", { Color = color or WHITE, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	return o
end
local function text(props, parent)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE,
		RichText = true, Text = "" }, parent)
	for k, v in props do
		t[k] = v
	end
	new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5 }, t)
	return t
end
local function button(label, color, props, parent)
	local b = new("TextButton", { Text = label, BackgroundColor3 = color, Font = Enum.Font.FredokaOne, TextScaled = true,
		TextColor3 = WHITE, AutoButtonColor = true }, parent)
	for k, v in props do
		b[k] = v
	end
	round(b, 10)
	new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5 }, b)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	return b
end
local function panel(name, size)
	local p = outline(round(new("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = size, BackgroundColor3 = PANEL, Visible = false, ZIndex = 5 }, gui), 18), WHITE, 3)
	return p
end
local function closeButton(p)
	button("X", rgb(220, 70, 70), { Position = UDim2.new(1, -58, 0, 10), Size = UDim2.new(0, 44, 0, 40) }, p).Activated:Connect(function()
		p.Visible = false
	end)
end
local function localToast(msg)
	-- reuse the HUD toast by faking a server toast locally
	local toast = gui:FindFirstChild("Toast")
	if toast then
		toast.Text = msg
		toast.TextTransparency = 0
		toast.UIStroke.Transparency = 0
		task.delay(2.2, function()
			if toast.Text == msg then
				toast.TextTransparency = 1
				toast.UIStroke.Transparency = 1
			end
		end)
	end
end

----------------------------------------------------------------------------- Index
local indexButton = outline(button("Index", rgb(40, 180, 170), { Name = "IndexButton", LayoutOrder = 3, Size = UDim2.new(0, 130, 0, 46) },
	gui:WaitForChild("LeftMenu")), WHITE, 3)
local indexPanel = panel("IndexPanel", UDim2.new(0, 760, 0, 480))
text({ Position = UDim2.new(0, 20, 0, 10), Size = UDim2.new(0, 160, 0, 40), Text = "Index", TextXAlignment = Enum.TextXAlignment.Left }, indexPanel)
local indexCount = text({ Position = UDim2.new(0, 180, 0, 16), Size = UDim2.new(1, -260, 0, 28), TextColor3 = rgb(200, 210, 230) }, indexPanel)
closeButton(indexPanel)
local indexList = new("ScrollingFrame", { Position = UDim2.new(0, 14, 0, 60), Size = UDim2.new(1, -28, 1, -74), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, indexPanel)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, indexList)

local rows = {} -- [species] = { viewport, chips = { [rarity] = frame } }
local order = 0
for _, biome in Config.Biomes do
	order += 1
	text({ LayoutOrder = order, Size = UDim2.new(1, -12, 0, 26), Text = biome.id, TextColor3 = biome.look.accent,
		TextXAlignment = Enum.TextXAlignment.Left }, indexList)
	for _, speciesId in biome.species do
		order += 1
		local row = round(new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -12, 0, 64), BackgroundColor3 = rgb(52, 56, 80) }, indexList), 12)
		local viewport = round(new("ViewportFrame", { Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(0, 70, 0, 56),
			BackgroundColor3 = rgb(70, 76, 105), Ambient = rgb(200, 200, 200), LightDirection = Vector3.new(-1, -2, 1) }, row), 10)
		local cam = new("Camera", { FieldOfView = 40 }, viewport)
		viewport.CurrentCamera = cam
		local name = text({ Position = UDim2.new(0, 86, 0, 8), Size = UDim2.new(0, 150, 0, 26), TextXAlignment = Enum.TextXAlignment.Left }, row)
		local spec = Config.Species[speciesId]
		local abilityIcon = new("ImageLabel", { Name = "AbilityIcon", BackgroundTransparency = 1,
			Image = spec.ability and (Config.Icons and Config.Icons.Abilities and Config.Icons.Abilities[spec.ability]) or "", Visible = false,
			Position = UDim2.new(0, 86, 0, 33), Size = UDim2.fromOffset(22, 22), ScaleType = Enum.ScaleType.Fit }, row)
		local ability = text({ Position = UDim2.new(0, spec.ability and 112 or 86, 0, 36), Size = UDim2.new(0, spec.ability and 124 or 150, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rgb(180, 190, 210) }, row)
		local chips = {}
		for i, rarity in Config.Rarities do
			local chip = round(new("Frame", { Position = UDim2.new(0, 246 + (i - 1) * 74, 0, 6), Size = UDim2.new(0, 68, 0, 52),
				BackgroundColor3 = rgb(40, 43, 62) }, row), 10)
			local icon = new("ImageLabel", { Name = "RarityIcon", BackgroundTransparency = 1, Image = (Config.Icons and Config.Icons.Rarities and Config.Icons.Rarities[rarity.id]) or "",
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(28, 28), ScaleType = Enum.ScaleType.Fit }, chip)
			local label = text({ Position = UDim2.new(0, 3, 0, 32), Size = UDim2.new(1, -6, 0, 16), Text = rarity.id }, chip)
			chips[rarity.id] = { frame = chip, label = label, icon = icon, color = rarity.color }
		end
		rows[speciesId] = { viewport = viewport, cam = cam, name = name, ability = ability, abilityIcon = abilityIcon, chips = chips }
	end
end

-- silhouette = the same model in flat black (neon parts would still glow under black lighting)
local function showModel(row, speciesId, discovered)
	if row.shown == discovered then
		return
	end
	row.shown = discovered
	if row.model then
		row.model:Destroy()
	end
	local model = CreatureBuilder.build(speciesId, "Common")
	for _, d in model:GetDescendants() do
		if not discovered and d:IsA("BasePart") then
			d.Color, d.Material, d.Transparency = rgb(10, 10, 14), Enum.Material.SmoothPlastic, d.Transparency < 1 and 0 or 1
		elseif not discovered and (d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Smoke")) then
			d:Destroy()
		end
	end
	model.Parent = row.viewport
	row.model = model
	local boxCFrame, size = model:GetBoundingBox()
	local dist = size.Magnitude
	row.cam.CFrame = CFrame.lookAt(boxCFrame.Position + Vector3.new(dist * 0.7, dist * 0.35, -dist * 1.1), boxCFrame.Position)
end

local function refreshIndex()
	local inv = Remotes.GetInventory:InvokeServer()
	if not inv then
		return
	end
	local found = {}
	for _, key in inv.index do
		found[key] = true
	end
	local total, have = 0, 0
	for speciesId, row in rows do
		local spec = Config.Species[speciesId]
		local any = false
		for rarityId, chip in row.chips do
			total += 1
			local got = found[speciesId .. "_" .. rarityId]
			if got then
				have += 1
				any = true
			end
			chip.frame.BackgroundColor3 = got and chip.color or rgb(40, 43, 62)
			chip.label.TextColor3 = got and WHITE or rgb(110, 115, 140)
			chip.icon.ImageTransparency = got and 0 or 0.75
		end
		-- silhouettes until discovered
		showModel(row, speciesId, any)
		row.name.Text = any and spec.display or "???"
		row.abilityIcon.Visible = any and spec.ability ~= nil
		row.ability.Text = any and (spec.ability and ("Ability: " .. spec.ability) or "No ability (+2 speed)") or "Not discovered"
	end
	indexCount.Text = ("Discovered %d / %d   ·   each new one pays %ds of its biome's income"):format(have, total, Config.IndexRewardSeconds)
end

indexButton.Activated:Connect(function()
	indexPanel.Visible = not indexPanel.Visible
	if indexPanel.Visible then
		refreshIndex()
	end
end)
Remotes:WaitForChild("InventoryChanged").OnClientEvent:Connect(function()
	if indexPanel.Visible then
		refreshIndex()
	end
end)
indexPanel:GetAttributeChangedSignal("OpenRequest"):Connect(function() -- Plaza Index Board
	indexPanel.Visible = true
	refreshIndex()
end)

----------------------------------------------------------------------------- Store
local storeButton = outline(button("Store", rgb(60, 185, 100), { Name = "StoreButton", LayoutOrder = 5, Size = UDim2.new(0, 130, 0, 46) },
	gui.LeftMenu), WHITE, 3)
local storePanel = panel("StorePanel", UDim2.new(0, 620, 0, 470))
text({ Position = UDim2.new(0, 20, 0, 10), Size = UDim2.new(0, 200, 0, 40), Text = "Store", TextXAlignment = Enum.TextXAlignment.Left }, storePanel)
local luckLabel = text({ Position = UDim2.new(0, 200, 0, 16), Size = UDim2.new(1, -280, 0, 28), TextColor3 = rgb(140, 255, 170) }, storePanel)
closeButton(storePanel)
local storeList = new("ScrollingFrame", { Position = UDim2.new(0, 14, 0, 60), Size = UDim2.new(1, -28, 1, -74), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, storePanel)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, storeList)

-- Hatch odds, shown before any purchase (paid random item disclosure)
local ODDS_COLUMNS = { { "Normal", false, false }, { "Luck", true, false }, { "Lucky pass", false, true }, { "Both", true, true } }
local oddsBox = new("Frame", { LayoutOrder = -1, Size = UDim2.new(1, -12, 0, 6 * 26 + 44), BackgroundTransparency = 1 }, storeList)
text({ Size = UDim2.new(1, 0, 0, 26), Text = "Hatch Odds (normal eggs)", TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = rgb(140, 255, 170) }, oddsBox)
local function oddsCell(row, col, label, color)
	text({ Position = UDim2.new(col / 5, 0, 0, 28 + row * 26), Size = UDim2.new(1 / 5, -4, 0, 24), Text = label,
		TextColor3 = color or WHITE }, oddsBox)
end
oddsCell(0, 0, "Rarity", rgb(190, 200, 220))
for c, column in ODDS_COLUMNS do
	oddsCell(0, c, column[1], rgb(190, 200, 220))
	local odds = Config.hatchOdds(column[2], column[3])
	for r = 1, 5 do
		oddsCell(r, c, ("%.2f%%"):format(odds[r] * 100))
	end
end
for r = 1, 5 do
	oddsCell(r, 0, Config.Rarities[r].id, Config.Rarities[r].color)
end
local secret = Config.Events.secretOdds
text({ Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = rgb(190, 200, 220), Text = ("Secret Egg: Epic %d%%, Legendary %d%%, Mythic %d%%. Luck: day-7 reward, Luck Potion, Server Luck.")
	:format(secret[4], secret[5], secret[6]) }, oddsBox)

local PAID_LUCK = { Lucky = true, LuckPotion = true, ServerLuck = true }
local luckButtons = {}
local PASS_ORDER = { "VIP", "ExtraMount", "Incubators", "PenSlots", "Lucky" }
local PRODUCT_ORDER = { "InstantHatch", "LuckPotion", "ServerLuck" }
local passButtons = {}
local function storeRow(i, item, isPass, key)
	local row = round(new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -12, 0, 70), BackgroundColor3 = rgb(52, 56, 80) }, storeList), 12)
	-- the pass / product icon uploaded in Creator Hub (owned by this experience)
	local icon = new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Image = "",
		Position = UDim2.new(0, 8, 0, 7), Size = UDim2.fromOffset(56, 56) }, row)
	if item.id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.id,
				isPass and Enum.InfoType.GamePass or Enum.InfoType.Product)
			if ok and info.IconImageAssetId and info.IconImageAssetId ~= 0 then
				icon.Image = "rbxassetid://" .. info.IconImageAssetId
			end
		end)
	end
	text({ Position = UDim2.new(0, 72, 0, 6), Size = UDim2.new(1, -248, 0, 30), Text = item.name, TextXAlignment = Enum.TextXAlignment.Left }, row)
	text({ Position = UDim2.new(0, 72, 0, 38), Size = UDim2.new(1, -248, 0, 22), Text = item.info, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = rgb(190, 200, 220) }, row)
	local buy = button(isPass and "Get Pass" or "Buy", isPass and rgb(250, 165, 55) or rgb(70, 140, 245),
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 150, 0, 48) }, row)
	buy.Activated:Connect(function()
		if item.id == 0 then
			return localToast("Coming soon!")
		end
		if PAID_LUCK[key] and player:GetAttribute("PaidLuckBlocked") ~= false then
			return localToast("Not available in your region")
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.id)
		else
			MarketplaceService:PromptProductPurchase(player, item.id)
		end
	end)
	if isPass then
		passButtons[key] = buy
	end
	if PAID_LUCK[key] then
		luckButtons[key] = buy
	end
end
text({ LayoutOrder = 0, Size = UDim2.new(1, -12, 0, 28), Text = "Game Passes", TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = rgb(255, 210, 90) }, storeList)
for i, key in PASS_ORDER do
	storeRow(i, Config.Monetization.passes[key], true, key)
end
text({ LayoutOrder = 10, Size = UDim2.new(1, -12, 0, 28), Text = "Boosts", TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = rgb(140, 200, 255) }, storeList)
for i, key in PRODUCT_ORDER do
	storeRow(10 + i, Config.Monetization.products[key], false, key)
end

local function refreshStore()
	for key, b in passButtons do
		local owned = player:GetAttribute(key .. "Pass") == true
		b.Text = owned and "Owned" or "Get Pass"
		b.BackgroundColor3 = owned and rgb(110, 115, 140) or rgb(250, 165, 55)
		b.Active = not owned
	end
	local blocked = player:GetAttribute("PaidLuckBlocked") ~= false
	for key, b in luckButtons do
		if blocked and not (passButtons[key] and player:GetAttribute(key .. "Pass")) then
			b.Text = "Not available"
			b.BackgroundColor3 = rgb(110, 115, 140)
			b.Active = false
		end
	end
	local now = os.time()
	local mine = math.max(0, (player:GetAttribute("LuckUntil") or 0) - now)
	local paid = if blocked then 0 else math.max(0, (player:GetAttribute("PaidLuckUntil") or 0) - now,
		(workspace:GetAttribute("ServerLuckUntil") or 0) - now)
	local left = math.max(mine, paid)
	luckLabel.Text = left > 0 and ("Luck active: %d:%02d"):format(left // 60, left % 60) or ""
end
storeButton.Activated:Connect(function()
	storePanel.Visible = not storePanel.Visible
	refreshStore()
end)

----------------------------------------------------------------------------- Daily reward
local daily = panel("DailyPanel", UDim2.new(0, 640, 0, 300))
daily.ZIndex = 8
text({ Position = UDim2.new(0, 20, 0, 12), Size = UDim2.new(1, -40, 0, 40), Text = "Daily Reward" }, daily)
local tiles = new("Frame", { Position = UDim2.new(0, 20, 0, 66), Size = UDim2.new(1, -40, 0, 130), BackgroundTransparency = 1 }, daily)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tiles)
local dayTiles = {}
for day, reward in Config.Daily do
	local tile = round(new("Frame", { LayoutOrder = day, Size = UDim2.new(1 / 7, -7, 1, 0), BackgroundColor3 = rgb(52, 56, 80) }, tiles), 12)
	text({ Position = UDim2.new(0, 4, 0, 8), Size = UDim2.new(1, -8, 0, 26), Text = "Day " .. day }, tile)
	text({ Position = UDim2.new(0, 4, 0, 46), Size = UDim2.new(1, -8, 0, 60), Text = reward.luckMinutes and "🍀\nLuck" or "💰\nCash" }, tile)
	dayTiles[day] = tile
end
local claim = button("Claim!", rgb(60, 185, 100), { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(0, 240, 0, 60) }, daily)
claim.Activated:Connect(function()
	Remotes.ClaimDaily:FireServer()
	daily.Visible = false
end)
local function syncDaily()
	local day = player:GetAttribute("DailyDay")
	daily.Visible = day ~= nil
	for d, tile in dayTiles do
		tile.BackgroundColor3 = d == day and rgb(60, 185, 100) or (day and d < day and rgb(90, 95, 120) or rgb(52, 56, 80))
	end
end
player:GetAttributeChangedSignal("DailyDay"):Connect(syncDaily)
syncDaily()

----------------------------------------------------------------------------- Offline summary
local offline = panel("OfflinePanel", UDim2.new(0, 520, 0, 250))
offline.ZIndex = 9
text({ Position = UDim2.new(0, 20, 0, 14), Size = UDim2.new(1, -40, 0, 40), Text = "Welcome back!" }, offline)
local offlineBody = text({ Position = UDim2.new(0, 24, 0, 66), Size = UDim2.new(1, -48, 0, 90), TextColor3 = rgb(220, 235, 255) }, offline)
button("Nice!", rgb(70, 140, 245), { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(0, 200, 0, 54) }, offline)
	.Activated:Connect(function()
		offline.Visible = false
	end)
local function syncOffline()
	local raw = player:GetAttribute("OfflineSummary")
	if not raw then
		return
	end
	local s = HttpService:JSONDecode(raw)
	local h, m = s.seconds // 3600, (s.seconds % 3600) // 60
	local away = h > 0 and ("%dh %dm"):format(h, m) or ("%dm"):format(m)
	offlineBody.Text = ("While you were away (%s):\n<font color=\"#7CFC9A\">+$%s</font> and <font color=\"#ffd25a\">%d egg%s hatched!</font>")
		:format(away, Format.number(s.cash), s.hatched, s.hatched == 1 and "" or "s")
	offline.Visible = true
end
player:GetAttributeChangedSignal("OfflineSummary"):Connect(syncOffline)
syncOffline()

----------------------------------------------------------------------------- Mama's Revenge bar
-- top middle, so it never sits over Mama while players aim at her weak spots
local mama = outline(round(new("Frame", { Name = "MamaBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0.76, 0, 0, 96), BackgroundColor3 = rgb(40, 20, 50), BackgroundTransparency = 0.15, Visible = false }, gui), 14), rgb(255, 90, 110), 3)
new("UISizeConstraint", { MaxSize = Vector2.new(480, 96) }, mama) -- 480 clears the cash/speed pills on 16:9 phones
local mamaTitle = text({ Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 30) }, mama)
local hpBack = round(new("Frame", { Position = UDim2.new(0, 12, 0, 40), Size = UDim2.new(1, -24, 0, 24), BackgroundColor3 = rgb(25, 15, 30) }, mama), 8)
local hpFill = round(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 70, 90) }, hpBack), 8)
local hpText = text({ Size = UDim2.fromScale(1, 1), ZIndex = 2 }, hpBack)
local mamaInfo = text({ Position = UDim2.new(0, 12, 0, 68), Size = UDim2.new(1, -24, 0, 22), TextColor3 = rgb(230, 210, 240) }, mama)
local mamaTop = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 76), Size = UDim2.new(0, 220, 0, 80),
	TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 20, Visible = false }, gui)

task.spawn(function()
	while true do
		local phase = workspace:GetAttribute("MamaPhase")
		local left = math.max(0, (workspace:GetAttribute("MamaEnds") or 0) - os.time())
		mama.Visible = phase ~= nil
		mamaTop.Visible = phase == "active" and gui.AbsoluteSize.X >= 1000
		if phase == "warning" then
			mamaTitle.Text = '<font color="#ff6b80">MAMA DRAGON IS COMING!</font> Defend your eggs!'
			hpFill.Size = UDim2.fromScale(1, 1)
			hpText.Text = ("Arrives in %d"):format(left)
			mamaInfo.Text = "Hold on the glowing red weak spot; keep aiming and dodge the red ring"
		elseif phase == "active" then
			local hp, max = workspace:GetAttribute("MamaHP") or 0, workspace:GetAttribute("MamaMaxHP") or 1
			mamaTitle.Text = '<font color="#ff6b80">MAMA DRAGON</font>'
			hpFill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
			hpText.Text = ("%d / %d  ·  Hold on red orb"):format(hp, max)
			local damage = player:GetAttribute("MamaDamage") or 0
			local reward = damage >= Config.Events.mamaRewardMinDamage and "Lucky Eggs if defeated" or ("%d more hits for reward"):format(Config.Events.mamaRewardMinDamage - damage)
			mamaInfo.Text = ("%d:%02d left · Your hits: %d · %s"):format(left // 60, left % 60, damage, reward)
			local top = workspace:GetAttribute("MamaTop") or ""
			mamaTop.Text = top ~= "" and ("<b>Top damage</b>\n" .. top) or ""
		end
		refreshStore()
		task.wait(0.2)
	end
end)

-- big result banner
local result = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 165), Size = UDim2.new(0.85, 0, 0, 70), Visible = false, ZIndex = 20 }, gui)
Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, payload)
	if kind ~= "mama" then
		return
	end
	local msg
	if payload.phase == "defeated" then
		msg = '<font color="#7CFC9A">MAMA DEFEATED!</font>'
	elseif payload.phase == "escaped" then
		msg = ('<font color="#ff6b80">Mama escaped with %d egg%s…</font>'):format(payload.eggs, payload.eggs == 1 and "" or "s")
	end
	if msg then
		result.Text = msg
		result.Visible = true
		result.Size = UDim2.new(0.75, 0, 0, 60)
		TweenService:Create(result, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.new(0.85, 0, 0, 70) }):Play()
		task.delay(4, function()
			if result.Text == msg then
				result.Visible = false
			end
		end)
	end
end)

----------------------------------------------------------------------------- VIP chat tag
local ok, TextChatService = pcall(game.GetService, game, "TextChatService")
if ok and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local sender = message.TextSource and Players:GetPlayerByUserId(message.TextSource.UserId)
		if sender and sender:GetAttribute("VIPPass") then
			props.PrefixText = '<font color="#ffd25a">[VIP]</font> ' .. message.PrefixText
		end
		return props
	end
end
