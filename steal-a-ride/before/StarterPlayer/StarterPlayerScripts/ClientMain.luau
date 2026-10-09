-- Client: swaps the lighting look (atmosphere + tint) as the player moves between biomes.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local biomes = workspace:WaitForChild("Biomes")
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local tint = Lighting:FindFirstChild("BiomeTint")
local TWEEN = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
local firstEntrance = biomes:WaitForChild(Config.Biomes[1].id):GetAttribute("EntranceZ")

local function biomeAt(z)
	for _, biome in Config.Biomes do
		local m = biomes:FindFirstChild(biome.id)
		if m and z <= m:GetAttribute("EntranceZ") and z >= m:GetAttribute("FarZ") then
			return biome
		end
	end
	return nil
end

-- Guardian catch fling: the client owns its character's physics, so the server asks us to apply it
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, payload)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if kind == "fling" and root then
		root.AssemblyLinearVelocity = payload
	end
end)

-- Abilities that move the character (the client owns its physics): Dash key, Glide, Phase walls
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")

local function hasAbility(name)
	return table.find(string.split(player:GetAttribute("Abilities") or "", ","), name) ~= nil
end

local function onDash(_, state)
	if state == Enum.UserInputState.Begin then
		Remotes.UseAbility:FireServer("Dash")
	end
	return Enum.ContextActionResult.Sink
end

local function syncAbilities()
	if hasAbility("Dash") then
		ContextActionService:BindAction("Dash", onDash, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle("Dash", "Dash")
		ContextActionService:SetPosition("Dash", UDim2.new(1, -170, 1, -170))
	else
		ContextActionService:UnbindAction("Dash")
	end
	local phase = hasAbility("Phase")
	for _, wall in CollectionService:GetTagged("PhaseWall") do
		wall.CanCollide = not phase -- local only: lets this player's own character through
	end
end
player:GetAttributeChangedSignal("Abilities"):Connect(syncAbilities)
syncAbilities()

-- Glide: while falling, cancel most of gravity
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local force = root:FindFirstChild("GlideForce")
	if not force then
		local attachment = Instance.new("Attachment")
		attachment.Name = "GlideAttachment"
		attachment.Parent = root
		force = Instance.new("VectorForce")
		force.Name = "GlideForce"
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Parent = root
	end
	local gliding = hasAbility("Glide") and humanoid:GetState() == Enum.HumanoidStateType.Freefall and root.AssemblyLinearVelocity.Y < 0
	force.Force = gliding and Vector3.new(0, root.AssemblyMass * workspace.Gravity * Config.Abilities.Glide.gravityCancel, 0) or Vector3.zero
end)

-- Riding pose: sit on the mount instead of running on top of it (Action4 overrides the run/jump/fall animations)
local SIT_FALLBACK = { [Enum.HumanoidRigType.R15] = "rbxassetid://2506281703", [Enum.HumanoidRigType.R6] = "rbxassetid://178130996" }
local sitTrack
local function syncRidePose()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local riding = player:GetAttribute("Riding") ~= nil
	if sitTrack and not riding then
		sitTrack:Stop(0.2)
		sitTrack = nil
	end
	if riding and animator and not sitTrack then
		local animate = character:FindFirstChild("Animate")
		local sit = animate and animate:FindFirstChild("sit")
		local anim = sit and sit:FindFirstChildOfClass("Animation")
		if not anim then
			anim = Instance.new("Animation")
			anim.AnimationId = SIT_FALLBACK[humanoid.RigType]
		end
		sitTrack = animator:LoadAnimation(anim)
		sitTrack.Priority = Enum.AnimationPriority.Action4
		sitTrack.Looped = true
		sitTrack:Play(0.2)
	end
end
player:GetAttributeChangedSignal("Riding"):Connect(syncRidePose)
local function onRideCharacter(character)
	sitTrack = nil -- the old track died with the old character
	character:WaitForChild("Humanoid"):WaitForChild("Animator")
	syncRidePose()
end
player.CharacterAdded:Connect(onRideCharacter)
if player.Character then
	task.spawn(onRideCharacter, player.Character)
end

-- Steal prompts: never show your own (your eggs, your incubators); Take Back only for the victim
local function filterPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local owner, onlyFor = prompt:GetAttribute("Owner"), prompt:GetAttribute("OnlyFor")
	if onlyFor then
		prompt.Enabled = onlyFor == player.UserId
	elseif owner then
		prompt.Enabled = owner ~= player.UserId
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		task.defer(filterPrompt, d) -- attributes arrive with the instance
	end
end)
for _, d in workspace:GetDescendants() do
	filterPrompt(d)
end

-- Weather: tint the world while it lasts (on top of the biome look); rain during thunderstorms
local weatherTint = Instance.new("ColorCorrectionEffect")
weatherTint.Name = "WeatherTint"
weatherTint.Parent = Lighting
local WEATHER_LOOK = {
	Thunderstorm = { tint = Color3.fromRGB(170, 185, 215), brightness = -0.1 },
	GoldenHour = { tint = Color3.fromRGB(255, 225, 160), brightness = 0.05 },
	BloodMoon = { tint = Color3.fromRGB(255, 120, 120), brightness = -0.12 },
}
local rain
local function syncWeather()
	local look = WEATHER_LOOK[workspace:GetAttribute("Weather") or ""]
	TweenService:Create(weatherTint, TweenInfo.new(2), {
		TintColor = look and look.tint or Color3.new(1, 1, 1), Brightness = look and look.brightness or 0,
	}):Play()
	if workspace:GetAttribute("Weather") == "Thunderstorm" and not rain then
		rain = Instance.new("Part")
		rain.Name = "RainEmitter"
		rain.Anchored, rain.CanCollide, rain.CanQuery, rain.CanTouch = true, false, false, false
		rain.Transparency = 1
		rain.Size = Vector3.new(120, 1, 120)
		local drops = Instance.new("ParticleEmitter")
		drops.Rate = 400
		drops.Lifetime = NumberRange.new(1, 1.4)
		drops.Speed = NumberRange.new(70, 90)
		drops.EmissionDirection = Enum.NormalId.Bottom
		drops.Size = NumberSequence.new(0.12)
		drops.Color = ColorSequence.new(Color3.fromRGB(190, 210, 255))
		drops.Transparency = NumberSequence.new(0.3)
		drops.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		drops.Parent = rain
		rain.Parent = workspace
		task.spawn(function()
			while rain and rain.Parent do
				local cam = workspace.CurrentCamera
				rain.Position = cam.CFrame.Position + Vector3.new(0, 40, 0)
				task.wait(0.1)
			end
		end)
	elseif workspace:GetAttribute("Weather") ~= "Thunderstorm" and rain then
		rain:Destroy()
		rain = nil
	end
end
workspace:GetAttributeChangedSignal("Weather"):Connect(syncWeather)
syncWeather()

-- Fuse Machine prompt opens the Stable
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name == "FuseMachinePrompt" then
		local panel = player.PlayerGui:FindFirstChild("MainUI") and player.PlayerGui.MainUI:FindFirstChild("StablePanel")
		local button = player.PlayerGui.MainUI.LeftMenu:FindFirstChild("StableButton")
		if panel and not panel.Visible and button then
			panel:SetAttribute("OpenRequest", os.clock())
		end
	end
end)

-- First-session tutorial: a beam to the next goal + a one-line hint
local beamTarget = Instance.new("Part")
beamTarget.Name = "TutorialTarget"
beamTarget.Anchored, beamTarget.CanCollide, beamTarget.CanQuery, beamTarget.CanTouch = true, false, false, false
beamTarget.Transparency = 1
beamTarget.Size = Vector3.new(1, 1, 1)
beamTarget.Parent = workspace
local targetAttachment = Instance.new("Attachment")
targetAttachment.Parent = beamTarget
local beam = Instance.new("Beam")
beam.Attachment1 = targetAttachment
beam.Color = ColorSequence.new(Color3.fromRGB(255, 225, 80))
beam.LightEmission = 1
beam.Width0, beam.Width1 = 1.2, 0.6
beam.FaceCamera = true
beam.Segments = 20
beam.Transparency = NumberSequence.new(0.15)
beam.Parent = beamTarget

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -24)
hint.Size = UDim2.new(0, 640, 0, 40)
hint.BackgroundColor3 = Color3.fromRGB(30, 34, 50)
hint.BackgroundTransparency = 0.25
hint.Font = Enum.Font.FredokaOne
hint.TextScaled = true
hint.TextColor3 = Color3.fromRGB(255, 235, 140)
hint.Visible = false
local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 12)
hintCorner.Parent = hint
local hintPad = Instance.new("UIPadding")
hintPad.PaddingTop, hintPad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
hintPad.Parent = hint
hint.Parent = player:WaitForChild("PlayerGui"):WaitForChild("MainUI")

local function nestPosition(biomeId)
	local nest = biomes:FindFirstChild(biomeId) and biomes[biomeId]:FindFirstChild("Nest")
	return nest and nest:GetPivot().Position + Vector3.new(0, 3, 0)
end

-- returns (goal position or nil, hint text or nil); nil, nil = tutorial finished
local function tutorialStep()
	if (player:GetAttribute("BestBiome") or 0) >= 2 then
		return nil, nil
	end
	if player:GetAttribute("CarryingEgg") then
		local plot = workspace.HomeRow.Plots:FindFirstChild(player:GetAttribute("Plot") or "")
		return plot and plot.Spawn.Position, "Run it home before the guardian catches you!"
	end
	if (player:GetAttribute("CreatureCount") or 0) == 0 then
		if (player:GetAttribute("Incubating") or 0) > 0 then
			return nil, "Your egg is hatching. Watch the timer on your incubator!"
		end
		return nestPosition("Forest"), "Steal an egg from the Forest nest!"
	end
	if not player:GetAttribute("Riding") then
		return nil, "Ride your new creature! Open the Stable and press Ride."
	end
	return nestPosition("Lake"), "Now you're fast enough: steal an egg from the Lake!"
end

local function updateTutorial(root)
	local goal, text = tutorialStep()
	hint.Visible = text ~= nil
	hint.Text = text or ""
	beam.Enabled = goal ~= nil and root ~= nil
	if goal and root then
		beamTarget.Position = goal
		local a0 = root:FindFirstChild("TutorialAttachment")
		if not a0 then
			a0 = Instance.new("Attachment")
			a0.Name = "TutorialAttachment"
			a0.Parent = root
		end
		beam.Attachment0 = a0
	end
end

local current
while true do
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	updateTutorial(root)
	if root then
		local z = root.Position.Z
		local biome = biomeAt(z)
		-- in the short gaps between biomes, keep the last look instead of flashing back to Home
		local id = biome and biome.id or (z > firstEntrance and "Home" or current)
		if id ~= current then
			current = id
			local look = biome and biome.look or Config.HomeLook
			if atmosphere then
				TweenService:Create(atmosphere, TWEEN, { Color = look.atmosphere, Density = look.density, Haze = look.haze }):Play()
			end
			if tint then
				TweenService:Create(tint, TWEEN, { TintColor = look.tint }):Play()
			end
		end
	end
	task.wait(0.5)
end
