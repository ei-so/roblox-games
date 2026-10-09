-- Hold the mouse/touch on Mama's open weak spot; keep aiming while moving and dodging.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer
-- MamaHit is created after every server service starts, which can take a while; wait without the infinite-yield warning.
local remote = ReplicatedStorage:WaitForChild("Remotes", math.huge):WaitForChild("MamaHit", math.huge)

local held, pointer, nextHit = nil, nil, 0
-- GetMouseLocation is in viewport space; ScreenPointToRay, GetGuiObjectsAtPosition and touch positions use GUI space.
local function mouseAt() return UIS:GetMouseLocation() - GuiService:GetGuiInset() end
local function stop()
	held, pointer, nextHit = nil, nil, 0
end

local function aim(position)
	if workspace:GetAttribute("MamaPhase") ~= "active" then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not humanoid or humanoid.Health <= 0 or not root or not camera then return end
	for _, gui in player.PlayerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if gui.Active then return end -- a button/panel under the pointer owns this input
	end
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * (Config.Events.mamaClickRange + math.min(256, player.CameraMaxZoomDistance + 4)), params)
	local orb = result and result.Instance
	if orb and orb.Parent and orb.Parent.Name == "MamaDragon"
		and orb:GetAttribute("ActiveWeakSpot") == true
		and (root.Position - orb.Position).Magnitude <= Config.Events.mamaClickRange then
		return orb, ray
	end
end

UIS.InputBegan:Connect(function(input, processed)
	if processed or held then return end
	local mouse = input.UserInputType == Enum.UserInputType.MouseButton1
	if not mouse and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local position = mouse and mouseAt() or Vector2.new(input.Position.X, input.Position.Y)
	if aim(position) then held, pointer, nextHit = input, position, 0 end
end)
UIS.TouchMoved:Connect(function(input)
	if input == held then pointer = Vector2.new(input.Position.X, input.Position.Y) end
end)
UIS.InputEnded:Connect(function(input)
	if input == held or held and held.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseButton1 then stop() end
end)
UIS.WindowFocusReleased:Connect(stop)
player.CharacterRemoving:Connect(stop)
workspace:GetAttributeChangedSignal("MamaPhase"):Connect(stop)

RunService.Heartbeat:Connect(function()
	if not held then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then stop() return end
	local now = os.clock()
	if now < nextHit then return end
	nextHit = now + 1 / Config.Events.mamaClickCap
	local position = held.UserInputType == Enum.UserInputType.MouseButton1 and mouseAt() or pointer
	local orb, ray = aim(position)
	if orb then remote:FireServer(orb, ray.Origin, ray.Direction) end
end)
