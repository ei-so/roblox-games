-- Climb: on a Climb mount, push into a quartz wall (tag ClimbWall) and you run straight up it, then carry on over
-- the top. The server times the wall top (AbilityService). Client-side, like Jump/Glide/Phase: it owns its physics.
-- A LinearVelocity holds the climb speed every physics step, so a slow egg carrier never stalls at a low frame rate.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Climb = require(ReplicatedStorage.Shared.Climb)

local player = Players.LocalPlayer
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local mover, depthOf = nil, setmetatable({}, { __mode = "k" }) -- [mount model] = its longest horizontal side

local function hasClimb()
	return table.find(string.split(player:GetAttribute("Abilities") or "", ","), "Climb") ~= nil
end

local function moverOn(root: BasePart)
	if not mover or mover.Parent ~= root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "ClimbAttachment"
		attachment.Parent = root
		mover = Instance.new("LinearVelocity")
		mover.Name = "ClimbVelocity"
		mover.Attachment0 = attachment
		mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
		mover.LineDirection = Vector3.yAxis
		mover.RelativeTo = Enum.ActuatorRelativeTo.World
		mover.MaxForce = math.huge
		mover.Enabled = false
		mover.Parent = root
	end
	return mover
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local climbing = false
	if humanoid.Health > 0 and hasClimb() and not player:GetAttribute("Flying") then
		local mount = character:FindFirstChild("Mount")
		local depth = 2
		if mount then
			if not depthOf[mount] then
				local _, size = mount:GetBoundingBox()
				depthOf[mount] = math.max(size.X, size.Z)
			end
			depth = depthOf[mount]
		end
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.01 then
			params.FilterDescendantsInstances = { character }
			local hit = workspace:Raycast(root.Position, look.Unit * (depth / 2 + 2), params)
			climbing = hit ~= nil and CollectionService:HasTag(hit.Instance, "ClimbWall")
				and humanoid.MoveDirection:Dot(hit.Normal) < -0.3
		end
	end
	if climbing or (mover and mover.Parent == root) then
		local m = moverOn(root)
		if climbing then
			m.LineVelocity = Climb.lift(humanoid.WalkSpeed)
		end
		m.Enabled = climbing
	end
end)
