-- Tutorial tips: a one-time card the first time something new happens, and a Guide panel listing every tip.
-- The guided first steps (beam + hint) live in ClientMain; both save progress through Remotes.TipSeen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local gui = script.Parent
local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local GOLD = rgb(255, 235, 140) -- same as the tutorial hint
local PANEL = rgb(35, 38, 56)
local CARD_SECONDS = 12

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function styled(o, stroke)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, o)
	if stroke then new("UIStroke", { Color = WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
	if o:IsA("TextLabel") or o:IsA("TextButton") then new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5 }, o) end
	return o
end
local function label(props, parent)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextColor3 = WHITE, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, parent)
	for k, v in props do t[k] = v end
	return styled(t, false)
end
local function button(props, parent)
	local b = new("TextButton", { Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE }, parent)
	for k, v in props do b[k] = v end
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, b)
	return styled(b, false)
end

local TIP = {}
for _, tip in Config.Tips do TIP[tip.key] = tip end

----------------------------------------------------------------------------- one-time tip card
local card = styled(new("Frame", { Name = "TipCard", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), -- below the cash bar and its warning line
	Size = UDim2.new(0.9, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = PANEL, Visible = false }, gui), true)
new("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge) }, card)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, card)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, card)
local cardTitle = label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), TextScaled = true, TextColor3 = GOLD }, card)
local cardBody = label({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 18 }, card)
local gotIt = button({ LayoutOrder = 3, Size = UDim2.new(0, 140, 0, 40), Text = "Got it", BackgroundColor3 = rgb(80, 190, 100) }, card)

local queue, showing, cardToken = {}, nil, nil
local triggered = {}

local function seen(key)
	return triggered[key] or table.find(string.split(player:GetAttribute("Tips") or "", ","), key) ~= nil
end

local showNext
local function hide()
	card.Visible, showing, cardToken = false, nil, nil
	showNext()
end
function showNext()
	if showing or #queue == 0 then
		return
	end
	showing = table.remove(queue, 1)
	cardTitle.Text, cardBody.Text = showing.title, showing.body
	card.Visible = true
	local token = {}
	cardToken = token
	task.delay(CARD_SECONDS, function()
		if cardToken == token then hide() end
	end)
end
gotIt.Activated:Connect(hide)

-- show a tip once per player, ever (saved on the server)
local function trigger(key)
	if player:GetAttribute("Tips") == nil or seen(key) then
		return
	end
	triggered[key] = true
	Remotes.TipSeen:FireServer(key)
	table.insert(queue, TIP[key])
	showNext()
end

local function inPatchBiome(): boolean -- the Lake or deeper (the biomes with escape patches)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for i = 2, #Config.Biomes do
		local m = workspace.Biomes:FindFirstChild(Config.Biomes[i].id)
		if m and root.Position.Z <= m:GetAttribute("EntranceZ") and root.Position.Z >= m:GetAttribute("FarZ") then
			return true
		end
	end
	return false
end

local function canRebirth(): boolean
	local need = Config.rebirth((player:GetAttribute("Rebirths") or 0) + 1)
	return need ~= nil and (player:GetAttribute("Cash") or 0) >= need.cash
		and (player:GetAttribute("BestBiome") or 0) >= Config.BiomeById[need.biome].index
end

Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, payload)
	if kind == "alarm" and type(payload) == "string" and not payload:find("Mama") then
		trigger("robbed")
	end
end)

task.spawn(function()
	while true do
		if workspace:GetAttribute("MamaPhase") then trigger("mama") end
		if workspace:GetAttribute("Weather") then trigger("weather") end
		if workspace:GetAttribute("SecretEgg") then trigger("secret") end
		if player:GetAttribute("Shielded") == false then trigger("pvp") end
		if inPatchBiome() then trigger("patches") end
		if canRebirth() then trigger("rebirth") end
		task.wait(0.5)
	end
end)

----------------------------------------------------------------------------- Guide panel
local menuButton = styled(new("TextButton", { Name = "GuideButton", LayoutOrder = 6, Size = UDim2.new(0, 130, 0, 46), Text = "Guide",
	BackgroundColor3 = rgb(235, 165, 40), Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE }, gui:WaitForChild("LeftMenu")), true)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, menuButton)

local panel = styled(new("Frame", { Name = "GuidePanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.new(0.92, 0, 0.7, 0), BackgroundColor3 = PANEL, Visible = false }, gui), true)
new("UISizeConstraint", { MaxSize = Vector2.new(560, 460) }, panel)
label({ Position = UDim2.new(0, 20, 0, 12), Size = UDim2.new(1, -90, 0, 40), TextScaled = true, Text = "Guide" }, panel)
local close = button({ Position = UDim2.new(1, -58, 0, 12), Size = UDim2.new(0, 44, 0, 40), Text = "X", BackgroundColor3 = rgb(220, 70, 70) }, panel)
local list = new("ScrollingFrame", { Position = UDim2.new(0, 16, 0, 64), Size = UDim2.new(1, -32, 1, -80), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, panel)
new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, list)
for i, tip in Config.Tips do
	local entry = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, list)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, entry)
	label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), TextScaled = true, TextColor3 = GOLD, Text = tip.title }, entry)
	label({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 17, Text = tip.body }, entry)
end

menuButton.Activated:Connect(function() panel.Visible = not panel.Visible end)
close.Activated:Connect(function() panel.Visible = false end)
