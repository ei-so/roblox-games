-- Daily and weekly goals share the existing Menu lock and compact, scrollable panel style.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared.Format)
local claim = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimQuest")
local player, gui = Players.LocalPlayer, script.Parent
local rgb = Color3.fromRGB
local WHITE, MUTED, NAVY, ROW = rgb(255, 255, 255), rgb(200, 210, 230), rgb(35, 38, 56), rgb(52, 56, 80)
local GREEN, BLUE, GREY = rgb(60, 185, 100), rgb(70, 140, 245), rgb(110, 115, 140)

local function new(class, props, parent)
	local o = Instance.new(class)
	for key, value in props do o[key] = value end
	o.Parent = parent
	return o
end
local function text(props, parent)
	local o = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true,
		TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left }, parent)
	for key, value in props do o[key] = value end
	new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5 }, o)
	return o
end
local function button(label, color, props, parent)
	local o = new("TextButton", { Text = label, BackgroundColor3 = color, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE }, parent)
	for key, value in props do o[key] = value end
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, o)
	new("UIStroke", { Color = rgb(25, 30, 40), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, o)
	return o
end

local menuButton = button("Quests", rgb(40, 150, 145), { Name = "QuestsButton", LayoutOrder = 9 }, gui:WaitForChild("LeftMenu"))
new("UIStroke", { Color = WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, menuButton)
local panel = new("Frame", { Name = "QuestsPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(560, 460), BackgroundColor3 = NAVY, Visible = false, ZIndex = 5 }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, panel)
new("UIStroke", { Color = WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
local panelScale = new("UIScale", {}, panel)
local uiScale = gui:WaitForChild("UIScale")
local function resize()
	panelScale.Scale = 1 / uiScale.Scale -- native pixel sizes keep every action at least 44 px tall
	panel.Size = UDim2.fromOffset(math.min(560, gui.AbsoluteSize.X - 24), math.min(460, gui.AbsoluteSize.Y - 24))
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
uiScale:GetPropertyChangedSignal("Scale"):Connect(resize)
resize()
local title = text({ Text = "Quests", Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -268, 0, 40) }, panel)
new("UISizeConstraint", { MaxSize = Vector2.new(170, 40) }, title)
local close = button("X", rgb(220, 70, 70), { Name = "Close", Position = UDim2.new(1, -58, 0, 10), Size = UDim2.fromOffset(44, 44) }, panel)
local invite = button("Invite Friends", BLUE, { Name = "InviteFriends", Position = UDim2.new(1, -236, 0, 10), Size = UDim2.fromOffset(168, 44) }, panel)
local inviteStatus = text({ Name = "InviteStatus", Text = "", Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.new(0.5, -14, 0, 16), TextColor3 = MUTED }, panel)
invite.Activated:Connect(function()
	invite.Interactable, invite.Text = false, "Checking..."
	local social = game:GetService("SocialService")
	local ok, allowed = pcall(social.CanSendGameInviteAsync, social, player)
	if ok and allowed then ok = pcall(social.PromptGameInvite, social, player) end
	inviteStatus.Text = ok and allowed and "" or "Invites unavailable here."
	invite.Interactable, invite.Text = true, "Invite Friends"
end)
local daily = button("Daily", BLUE, { Name = "Daily", Position = UDim2.fromOffset(14, 80), Size = UDim2.new(0.5, -18, 0, 44) }, panel)
local weekly = button("Weekly", ROW, { Name = "Weekly", Position = UDim2.new(0.5, 4, 0, 80), Size = UDim2.new(0.5, -18, 0, 44) }, panel)
local timer = text({ Name = "Reset", Text = "Loading quests...", Position = UDim2.fromOffset(16, 130), Size = UDim2.new(1, -32, 0, 24), TextColor3 = MUTED }, panel)
local list = new("ScrollingFrame", { Name = "List", Position = UDim2.fromOffset(14, 162), Size = UDim2.new(1, -28, 1, -176),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, panel)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local loading = text({ Text = "Loading quests...", Size = UDim2.new(1, -12, 0, 44), LayoutOrder = 0 }, list)
local bonus = text({ Name = "WeeklyBonus", Size = UDim2.new(1, -12, 0, 46), LayoutOrder = 4, TextColor3 = rgb(255, 210, 80), Visible = false }, list)

local period, state, pending = "daily", nil, nil
local rows = {}
local function refresh()
	loading.Visible = not state
	daily.BackgroundColor3, weekly.BackgroundColor3 = period == "daily" and BLUE or ROW, period == "weekly" and BLUE or ROW
	bonus.Visible = state ~= nil and period == "weekly"
	if not state then for _, row in rows do row.Visible = false end; return end
	bonus.Text = state.weeklyBonus and "Weekly bonus claimed: 15 minutes of Luck!" or "Claim all 3 weekly quests for 15 minutes of Luck."
	for i, row in rows do
		local goal = state[period][i]
		local spec = Config.Quests.byId[goal.id]
		row.Visible = true
		row.Title.Text = spec.title:format(Format.number(goal.target))
		row.Progress.Text = ("%s / %s  ·  Reward $%s"):format(Format.number(goal.progress), Format.number(goal.target), Format.number(state[period .. "Reward"]))
		row.Track.Fill.Size = UDim2.fromScale(math.clamp(goal.progress / goal.target, 0, 1), 1)
		local waiting = pending == period .. i
		if waiting and goal.claimed then pending, waiting = nil, false end
		local ready = goal.progress >= goal.target and not goal.claimed and not waiting
		row.Claim.Text = goal.claimed and "Claimed" or waiting and "Claiming..." or ready and "Claim" or "In progress"
		row.Claim.BackgroundColor3 = ready and GREEN or GREY
		row.Claim.Active, row.Claim.Interactable, row.Claim.AutoButtonColor = ready, ready, ready
	end
end

for i = 1, 3 do
	local row = new("Frame", { Name = "Quest" .. i, LayoutOrder = i, Size = UDim2.new(1, -12, 0, 96), BackgroundColor3 = ROW, Visible = false }, list)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, row)
	text({ Name = "Title", Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 28) }, row)
	text({ Name = "Progress", Position = UDim2.fromOffset(12, 43), Size = UDim2.new(1, -162, 0, 22), TextColor3 = MUTED }, row)
	local track = new("Frame", { Name = "Track", Position = UDim2.fromOffset(12, 77), Size = UDim2.new(1, -162, 0, 8), BackgroundColor3 = NAVY, BorderSizePixel = 0 }, row)
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = rgb(110, 235, 155), BorderSizePixel = 0 }, track)
	local action = button("In progress", GREY, { Name = "Claim", Position = UDim2.new(1, -140, 0, 42), Size = UDim2.fromOffset(128, 44) }, row)
	action.Activated:Connect(function()
		if not state or pending then return end
		local key = period .. i
		pending = key
		claim:FireServer(period, i, state[period == "daily" and "day" or "week"])
		refresh()
		task.delay(5, function() if pending == key then pending = nil; refresh() end end)
	end)
	rows[i] = row
end
local function decode()
	local ok, value = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Quests") or "")
	state = ok and type(value) == "table" and type(value.daily) == "table" and #value.daily == 3 and type(value.weekly) == "table" and #value.weekly == 3 and value or nil
	refresh()
end
daily.Activated:Connect(function() period = "daily"; list.CanvasPosition = Vector2.zero; refresh() end)
weekly.Activated:Connect(function() period = "weekly"; list.CanvasPosition = Vector2.zero; refresh() end)
menuButton.Activated:Connect(function()
	panel.Visible = true
	decode()
end)
close.Activated:Connect(function() panel.Visible = false end)
player:GetAttributeChangedSignal("Quests"):Connect(decode)
decode()
task.spawn(function()
	while true do
		if state and panel.Visible then
			local deadline = (period == "daily" and state.day + 1 or 4 + (state.week + 1) * 7) * 86400
			local left = math.max(0, deadline - math.floor(workspace:GetServerTimeNow()))
			timer.Text = ("Resets in %dd %02d:%02d:%02d (UTC)"):format(left // 86400, left % 86400 // 3600, left % 3600 // 60, left % 60)
		end
		task.wait(1)
	end
end)
