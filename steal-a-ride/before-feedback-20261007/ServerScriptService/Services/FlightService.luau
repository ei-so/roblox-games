-- Server grants flight only to the creature actually being ridden.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local SpeedService = require(script.Parent.SpeedService)
local FlightService = {}
local active, requestedAt = {}, {}

local function reset(player)
	active[player] = nil
	player:SetAttribute("Flying", false)
	player:SetAttribute("FlightLanding", false)
	player:SetAttribute("FlightCeiling", nil)
end

local function groundNear(character, root, height)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	return workspace:Raycast(root.Position, Vector3.new(0, -height - .8, 0), params) ~= nil
end

function FlightService.request(player, action)
	if action ~= "toggle" and action ~= "landed" then return false end
	local now = os.clock()
	if now - (requestedAt[player] or -math.huge) < .15 then return false end
	requestedAt[player] = now
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local mount = character and character:FindFirstChild("Mount")
	if not root or not humanoid or humanoid.Health <= 0 or not mount or not mount:GetAttribute("CanFly") then
		reset(player)
		return false
	end
	if action == "landed" then
		if active[player] and groundNear(character, root, mount:GetAttribute("RiderRootHeight") or 5) then reset(player); return true end
		return false
	end
	if active[player] then
		player:SetAttribute("FlightLanding", true)
		return true
	end
	if SpeedService.current(player) <= 0 then return false end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local ground = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), params)
	local ceiling = (ground and ground.Position.Y or 0) + (mount:GetAttribute("RiderRootHeight") or 5) + Config.Flight.maxHeight
	active[player] = { mount = mount, started = now, ceiling = ceiling }
	player:SetAttribute("FlightCeiling", active[player].ceiling)
	player:SetAttribute("FlightLanding", false)
	player:SetAttribute("Flying", true)
	return true
end

function FlightService.start()
	RS.Remotes.UseAbility.OnServerEvent:Connect(function(player, ability, action)
		if ability == "Flight" then FlightService.request(player, action) end
	end)
	RunService.Heartbeat:Connect(function()
		for player, state in active do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not player.Parent or not root or not humanoid or humanoid.Health <= 0 or character:FindFirstChild("Mount") ~= state.mount
				or not player:GetAttribute("Flying") then
				reset(player)
			elseif root.Position.Y > state.ceiling + 3 then
				root.CFrame = root.CFrame + Vector3.new(0, state.ceiling - root.Position.Y, 0)
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(v.X, math.min(v.Y, 0), v.Z)
			elseif player:GetAttribute("FlightLanding") and os.clock() - state.started > Config.Flight.takeoffSeconds
				and groundNear(character, root, state.mount:GetAttribute("RiderRootHeight") or 5) then
				reset(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) active[player], requestedAt[player] = nil, nil end)
end

return FlightService
