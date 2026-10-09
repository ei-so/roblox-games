-- Same-server friends only. A new refresh invalidates older yielding API results.
local Players = game:GetService("Players")
local FriendService = {}
local versions = {}

function FriendService.refresh(player, leaving)
	versions[player] = (versions[player] or 0) + 1
	local version, count = versions[player], 0
	for _, other in Players:GetPlayers() do
		if other ~= player and other ~= leaving then
			local ok, friend = pcall(player.IsFriendsWithAsync, player, other.UserId)
			if ok and friend and other.Parent == Players then count += 1 end
		end
	end
	if player.Parent == Players and versions[player] == version then player:SetAttribute("FriendCount", count) end
end

function FriendService.onPlayerReady(player)
	player:SetAttribute("FriendCount", 0)
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("FriendCount") ~= nil then task.spawn(FriendService.refresh, other) end
	end
end

function FriendService.start()
	Players.PlayerRemoving:Connect(function(leaving)
		versions[leaving] = nil
		for _, player in Players:GetPlayers() do
			if player ~= leaving and player:GetAttribute("FriendCount") ~= nil then task.spawn(FriendService.refresh, player, leaving) end
		end
	end)
end

return FriendService
