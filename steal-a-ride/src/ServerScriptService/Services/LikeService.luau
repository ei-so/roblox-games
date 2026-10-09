-- Visitor likes are saved per owner, once each UTC day. Prompts resolve the current plot owner.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Notify = ReplicatedStorage.Remotes.Notify

local LikeService = {}
LikeService.onLiked = nil

function LikeService.sync(player)
	local data, plot = DataService.get(player), PlotService.get(player)
	if not data then return end
	player:SetAttribute("Likes", data.Likes or 0)
	local point = plot and plot:FindFirstChild("LikePoint")
	if point then
		point.LikePrompt:SetAttribute("Owner", player.UserId)
		point.LikePrompt.Enabled = true
		point.Count.Text.Text = ("♥ %d likes"):format(data.Likes or 0)
	end
end

function LikeService.like(visitor, plot): boolean
	local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId"))
	if not owner or owner == visitor or PlotService.get(owner) ~= plot then return false end
	local given, received = DataService.get(visitor), DataService.get(owner)
	local root = visitor.Character and visitor.Character:FindFirstChild("HumanoidRootPart")
	local hum = visitor.Character and visitor.Character:FindFirstChildOfClass("Humanoid")
	local point = plot:FindFirstChild("LikePoint")
	if not given or not received or visitor:GetAttribute("DataLoadFailed") or owner:GetAttribute("DataLoadFailed")
		or not root or not hum or hum.Health <= 0 or not point or (root.Position - point.Position).Magnitude > 14 then return false end
	local day, key = os.time() // 86400, tostring(owner.UserId)
	given.LikesGiven = given.LikesGiven or {}
	if given.LikesGiven[key] == day then
		Notify:FireClient(visitor, "toast", "You already liked this base today. Come back tomorrow!")
		return false
	end
	-- Earlier days no longer block anything; discard them so this save field stays small.
	for id, date in given.LikesGiven do if date ~= day then given.LikesGiven[id] = nil end end
	given.LikesGiven[key] = day
	received.Likes = (received.Likes or 0) + 1
	LikeService.sync(owner)
	Notify:FireClient(visitor, "toast", "Liked " .. owner.DisplayName .. "'s base!")
	if LikeService.onLiked then LikeService.onLiked(visitor, owner) end
	return true
end

function LikeService.start()
	for _, plot in workspace.HomeRow.Plots:GetChildren() do
		local board = plot.Sign.Board
		local point = Instance.new("Part")
		point.Name, point.Size = "LikePoint", Vector3.new(1, 1, 1)
		point.Position = Vector3.new(board.Position.X - plot:GetAttribute("Side") * 4, 3, board.Position.Z + 6)
		point.Anchored, point.Transparency, point.CanCollide, point.CanTouch, point.CanQuery = true, 1, false, false, false
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name, prompt.ActionText, prompt.ObjectText = "LikePrompt", "Like Base", "Once per day"
		prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Enabled = 0, 12, false, false
		prompt.Parent = point
		local count = Instance.new("BillboardGui")
		count.Name, count.Size, count.MaxDistance = "Count", UDim2.fromScale(8, 1.2), 85
		count.Adornee, count.StudsOffsetWorldSpace = board, Vector3.new(0, 3, 0)
		local text = Instance.new("TextLabel")
		text.Name, text.Size, text.BackgroundTransparency = "Text", UDim2.fromScale(1, 1), 1
		text.Font, text.TextScaled, text.TextColor3, text.TextStrokeTransparency = Enum.Font.FredokaOne, true, Color3.fromRGB(255, 160, 190), 0
		text.Text, text.Parent = "", count
		count.Parent, point.Parent = point, plot
		prompt.Triggered:Connect(function(visitor) LikeService.like(visitor, plot) end)
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId"))
			if owner then LikeService.sync(owner) else prompt.Enabled, text.Text = false, "" end
		end)
	end
end

return LikeService
