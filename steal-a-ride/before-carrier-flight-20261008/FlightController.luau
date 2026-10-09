-- Native keyboard, controller and touch actions; character physics stay with the owning client.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Actions = game:GetService("ContextActionService")
local Input = game:GetService("UserInputService")
local Config = require(RS.Shared.Config)
local Motion = require(RS.Shared.WalkCycle)
local TouchButtons = require(RS.Shared:WaitForChild("TouchButtons"))
TouchButtons.follow({ "RideFlight", "RideUp", "RideDown" })
local player = Players.LocalPlayer
local remote = RS.Remotes.UseAbility
local up, down = false, false
local currentRoot, velocity, orientation, attachment, currentHumanoid, oldRotate
local started = 0
local boundFly, boundFlying = false, false

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "FlightControls", false
gui.Parent = player:WaitForChild("PlayerGui")
local hint = Instance.new("TextLabel")
hint.Name = "FlightHint"
hint.AnchorPoint = Vector2.new(.5, 1)
hint.Position, hint.Size = UDim2.new(.5, 0, 1, -150), UDim2.new(.65, 0, 0, 34)
hint.BackgroundColor3, hint.BackgroundTransparency = Color3.fromRGB(30, 34, 50), .1
hint.TextColor3, hint.Font = Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne
hint.TextScaled, hint.Visible = true, false
hint.Parent = gui
local corner = Instance.new("UICorner");corner.CornerRadius = UDim.new(0, 8);corner.Parent = hint
local pad = Instance.new("UIPadding");pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10);pad.Parent = hint
local limit = Instance.new("UITextSizeConstraint");limit.MinTextSize, limit.MaxTextSize = 12, 16;limit.Parent = hint

-- Touch, gamepad or keyboard wording; touch is narrower so it clears the thumbstick and the flight buttons
local hintToken, lastHint = 0, nil
local function updateHint()
	local touch = Input.TouchEnabled and not Input.KeyboardEnabled
	local controller = Input:GetLastInputType().Name:find("Gamepad") ~= nil
	local flying = player:GetAttribute("Flying")
	local glide = table.find(string.split(player:GetAttribute("Abilities") or "", ","), "Glide") ~= nil
	hint.Size = UDim2.new(touch and .45 or .65, 0, 0, 34)
	if player:GetAttribute("FlightLanding") then hint.Text = "Landing..."
	elseif touch then hint.Text = flying and "Hold Up / Down for height   |   Tap Land" or "Tap Fly to take off"
	elseif controller then hint.Text = flying and "Y: land   |   RT: up   |   LT: down" or "Y: take off"
	else hint.Text = flying and "R: land   |   Space: up   |   Ctrl: down" or "R: take off" end
	if glide and not flying and not player:GetAttribute("FlightLanding") then hint.Text ..= "   |   You glide when falling" end
	if boundFly and hint.Text ~= lastHint then
		lastHint, hint.Visible = hint.Text, true
		hintToken += 1
		local token = hintToken
		task.delay(4, function()
			if token == hintToken then hint.Visible = false end
		end)
	end
end

local function clearPhysics()
	if velocity then velocity:Destroy() end
	if orientation then orientation:Destroy() end
	if attachment then attachment:Destroy() end
	if currentHumanoid and currentHumanoid.Parent then
		currentHumanoid.AutoRotate = oldRotate
		if currentHumanoid.Health > 0 then currentHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
	end
	currentRoot, currentHumanoid, velocity, orientation, attachment = nil, nil, nil, nil, nil
	up, down = false, false
end

local function action(name, state)
	if Input:GetFocusedTextBox() and state ~= Enum.UserInputState.End and state ~= Enum.UserInputState.Cancel then
		return Enum.ContextActionResult.Pass
	end
	if name == "RideFlight" then
		if state == Enum.UserInputState.Begin then remote:FireServer("Flight", "toggle") end
	elseif name == "RideUp" then
		up = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
	elseif name == "RideDown" then
		down = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
	end
	return Enum.ContextActionResult.Sink
end

local function sync()
	local character = player.Character
	local mount = character and character:FindFirstChild("Mount")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local canFly = (mount and mount:GetAttribute("CanFly") and humanoid and humanoid.Health > 0) == true
	local flying = canFly and player:GetAttribute("Flying") == true
	if canFly ~= boundFly then
		if canFly then Actions:BindAction("RideFlight", action, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
		else Actions:UnbindAction("RideFlight") end
		boundFly = canFly
	end
	if flying ~= boundFlying then
		up, down = false, false
		if flying then
			Actions:BindActionAtPriority("RideUp", action, true, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonR2)
			Actions:BindActionAtPriority("RideDown", action, true, 3000, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL2)
		else Actions:UnbindAction("RideUp");Actions:UnbindAction("RideDown") end
		boundFlying = flying
	end
	if canFly then
		Actions:SetTitle("RideFlight", flying and "Land" or "Fly")
		Actions:SetPosition("RideFlight", UDim2.new(1, -240, 1, -175))
	end
	if flying then
		Actions:SetTitle("RideUp", "Up");Actions:SetTitle("RideDown", "Down")
		Actions:SetPosition("RideUp", UDim2.new(1, -170, 1, -175))
		Actions:SetPosition("RideDown", UDim2.new(1, -100, 1, -175))
	end
	-- Roblox creates its touch buttons asynchronously after BindAction.
	if Input.TouchEnabled and canFly then
		task.delay(.2, function()
			for _, name in { "RideFlight", "RideUp", "RideDown" } do
				if (name == "RideFlight" and boundFly) or (name ~= "RideFlight" and boundFlying) then
					local button = Actions:GetButton(name)
					if button then button.Size = UDim2.fromOffset(58, 58) end
					TouchButtons.place(name) -- in a row above the jump button, never over it
				end
			end
		end)
	end
	if not canFly then
		hintToken += 1
		hint.Visible, lastHint = false, nil
	end
	updateHint()
end

for _, name in { "Flying", "FlightLanding", "Riding", "Abilities" } do player:GetAttributeChangedSignal(name):Connect(sync) end
Input.LastInputTypeChanged:Connect(updateHint)
local function characterAdded(character)
	clearPhysics()
	character.ChildAdded:Connect(function(c) if c.Name == "Mount" then task.defer(sync) end end)
	character.ChildRemoved:Connect(function(c) if c.Name == "Mount" then clearPhysics();task.defer(sync) end end)
	character:WaitForChild("Humanoid").Died:Connect(function() clearPhysics();sync() end)
	sync()
end
player.CharacterAdded:Connect(characterAdded)
if player.Character then task.spawn(characterAdded, player.Character) end

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local mount = character and character:FindFirstChild("Mount")
	if not player:GetAttribute("Flying") or not root or not humanoid or humanoid.Health <= 0 or not mount or not mount:GetAttribute("CanFly") then
		if currentRoot then clearPhysics() end
		return
	end
	if currentRoot ~= root then
		clearPhysics()
		currentRoot, currentHumanoid, oldRotate, started = root, humanoid, humanoid.AutoRotate, os.clock()
		attachment = Instance.new("Attachment");attachment.Name = "FlightAttachment";attachment.Parent = root
		velocity = Instance.new("LinearVelocity");velocity.Name = "FlightVelocity"
		velocity.Attachment0, velocity.RelativeTo = attachment, Enum.ActuatorRelativeTo.World
		velocity.MaxForce = root.AssemblyMass * workspace.Gravity * 8
		velocity.Parent = root
		orientation = Instance.new("AlignOrientation");orientation.Name = "FlightOrientation"
		orientation.Mode, orientation.Attachment0 = Enum.OrientationAlignmentMode.OneAttachment, attachment
		orientation.MaxTorque, orientation.Responsiveness = 1e6, 12
		orientation.CFrame = root.CFrame.Rotation;orientation.Parent = root
		humanoid.AutoRotate = false
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	local landing = player:GetAttribute("FlightLanding")
	local vertical = (up and 1 or 0) - (down and 1 or 0)
	if os.clock() - started < Config.Flight.takeoffSeconds then vertical = 1 end
	if landing then vertical = -Config.Flight.landingSpeed / Config.Flight.verticalSpeed end
	local ceiling = player:GetAttribute("FlightCeiling")
	if ceiling and root.Position.Y >= ceiling and vertical > 0 then vertical = 0 end
	velocity.VectorVelocity = Motion.flightVelocity(humanoid.MoveDirection, humanoid.WalkSpeed, vertical)
	local direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	if direction.Magnitude > .05 then orientation.CFrame = CFrame.lookAt(Vector3.zero, direction).Rotation end
end)
