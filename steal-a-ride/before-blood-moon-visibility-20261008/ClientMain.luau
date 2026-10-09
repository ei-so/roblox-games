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
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TouchButtons = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("TouchButtons"))
TouchButtons.follow({ "Dash", "GetOff" })

local function hasAbility(name)
	return table.find(string.split(player:GetAttribute("Abilities") or "", ","), name) ~= nil
end

local function onDash(_, state)
	if state == Enum.UserInputState.Begin then
		Remotes.UseAbility:FireServer("Dash")
	end
	return Enum.ContextActionResult.Sink
end

-- F or touch "Get off": every mount back to the stable, subject to the server's capacity check.
local function onGetOff(_, state)
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		Remotes.UnequipMount:FireServer("all")
	end
	return Enum.ContextActionResult.Sink
end

local function syncGetOff()
	if player:GetAttribute("Riding") then
		ContextActionService:BindAction("GetOff", onGetOff, true, Enum.KeyCode.F)
		ContextActionService:SetTitle("GetOff", "Get off")
		task.delay(0.2, function()
			local button = ContextActionService:GetButton("GetOff")
			if button then button.Size = UDim2.fromOffset(58, 58) end
			TouchButtons.place("GetOff") -- left end of the flight row above the jump button
		end)
	else
		ContextActionService:UnbindAction("GetOff")
	end
end
player:GetAttributeChangedSignal("Riding"):Connect(syncGetOff)
syncGetOff()

local function syncAbilities()
	if hasAbility("Dash") then
		ContextActionService:BindAction("Dash", onDash, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle("Dash", "Dash")
		ContextActionService:SetPosition("Dash", UDim2.new(1, -170, 1, -170))
		task.delay(0.2, TouchButtons.place, "Dash") -- touch: beside the jump button (tablets make it bigger)
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
	local gliding = not player:GetAttribute("Flying") and hasAbility("Glide") and humanoid:GetState() == Enum.HumanoidStateType.Freefall and root.AssemblyLinearVelocity.Y < 0
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
		d:GetAttributeChangedSignal("Owner"):Connect(function() filterPrompt(d) end)
		d:GetAttributeChangedSignal("OnlyFor"):Connect(function() filterPrompt(d) end)
	end
end)
for _, d in workspace:GetDescendants() do
	filterPrompt(d)
	if d:IsA("ProximityPrompt") then
		d:GetAttributeChangedSignal("Owner"):Connect(function() filterPrompt(d) end)
		d:GetAttributeChangedSignal("OnlyFor"):Connect(function() filterPrompt(d) end)
	end
end

-- Weather: local moods over the biome look; restore the native sky between events.
local weatherTint = Instance.new("ColorCorrectionEffect")
weatherTint.Name = "WeatherTint"
weatherTint.Parent = Lighting
local WEATHER_LOOK = {
	Thunderstorm = { tint = Color3.fromRGB(170, 185, 215), brightness = -0.18 },
	GoldenHour = { tint = Color3.fromRGB(255, 225, 160), brightness = 0.05 },
	BloodMoon = { tint = Color3.fromRGB(255, 120, 120), brightness = 0.03 }, -- night supplies the darkness; keep routes visible
}
local sky = Lighting:FindFirstChildOfClass("Sky")
local baseClock = Lighting.ClockTime
local baseMoonSize = sky and sky.MoonAngularSize
local rays = Instance.new("SunRaysEffect")
rays.Name, rays.Enabled, rays.Intensity, rays.Spread = "WeatherSunRays", false, 0.06, 0.8
rays.Parent = Lighting
local MOODS = {
	GoldenHour = { clock = 17.5, color = Color3.fromRGB(255, 215, 110), rate = 12 },
	BloodMoon = { clock = 21, color = Color3.fromRGB(230, 65, 95), rate = 8 },
}
local rain, stormClouds, motes, clockFade, tintFade, moonFade
local activeWeather, weatherInitialized
local function syncWeather()
	local weather = workspace:GetAttribute("Weather") or ""
	if weatherInitialized and weather == activeWeather then return end
	activeWeather, weatherInitialized = weather, true
	local look, mood = WEATHER_LOOK[weather], MOODS[weather]
	if tintFade then tintFade:Cancel() end
	if clockFade then clockFade:Cancel() end
	if moonFade then moonFade:Cancel() end
	tintFade = TweenService:Create(weatherTint, TweenInfo.new(2), {
		TintColor = look and look.tint or Color3.new(1, 1, 1), Brightness = look and look.brightness or 0,
	})
	tintFade:Play()
	clockFade = TweenService:Create(Lighting, TweenInfo.new(2), { ClockTime = mood and mood.clock or baseClock })
	clockFade:Play()
	if sky then
		moonFade = TweenService:Create(sky, TweenInfo.new(2), { MoonAngularSize = weather == "BloodMoon" and 16 or baseMoonSize })
		moonFade:Play()
	end
	rays.Enabled = weather == "GoldenHour"
	if motes then motes:Destroy(); motes = nil end
	if mood then
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local width = touchOnly and 24 or 32
		motes = Instance.new("Part")
		motes.Name = "WeatherMotes"
		motes.Anchored, motes.CanCollide, motes.CanTouch, motes.CanQuery = true, false, false, false
		motes.Transparency, motes.Size = 1, Vector3.new(width, touchOnly and 10 or 12, width)
		local cam = workspace.CurrentCamera
		if cam then motes.Position = cam.CFrame.Position end
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name, emitter.Texture = "WeatherDrift", "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(mood.color)
		emitter.Rate, emitter.Lifetime = mood.rate * (touchOnly and 0.5 or 1), NumberRange.new(2, 3)
		emitter.Speed, emitter.Acceleration = NumberRange.new(0.3, 0.8), Vector3.new(0, 0.15, 0)
		emitter.EmissionDirection, emitter.SpreadAngle = Enum.NormalId.Top, Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.45), NumberSequenceKeypoint.new(1, 1),
		})
		emitter.LightEmission, emitter.LightInfluence = 0.65, 0
		emitter.Parent, motes.Parent = motes, workspace
		local holder = motes
		task.spawn(function()
			while holder.Parent do
				local current = workspace.CurrentCamera
				if current then holder.Position = current.CFrame.Position end
				task.wait(0.1)
			end
		end)
	end
	if weather == "Thunderstorm" and not rain then
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local width = touchOnly and 32 or 48
		stormClouds = Instance.new("Clouds")
		stormClouds.Name = "StormClouds"
		stormClouds.Cover, stormClouds.Density = 0.94, 0.85
		stormClouds.Color = Color3.fromRGB(65, 72, 88)
		stormClouds.Parent = workspace.Terrain
		rain = Instance.new("Part")
		rain.Name = "RainEmitter"
		rain.Anchored, rain.CanCollide, rain.CanQuery, rain.CanTouch = true, false, false, false
		rain.Transparency = 1
		rain.Size = Vector3.new(width, 1, width)
		local cam = workspace.CurrentCamera
		if cam then rain.Position = cam.CFrame.Position + Vector3.new(0, 32, 0) end
		local drops = Instance.new("ParticleEmitter")
		drops.Name = "RainStreaks"
		drops.Texture = "rbxasset://textures/particles/SquareParticle.png"
		drops.Rate = touchOnly and 100 or 400
		drops.Lifetime = NumberRange.new(0.7, 0.9)
		drops.Speed = NumberRange.new(80, 100)
		drops.Acceleration = Vector3.new(6, -20, 0)
		drops.EmissionDirection = Enum.NormalId.Bottom
		drops.Size = NumberSequence.new(0.4)
		drops.Squash = NumberSequence.new(4) -- thin streaks using the built-in white texture
		drops.Rotation = NumberRange.new(90) -- VelocityParallel aligns the texture's horizontal axis with travel
		drops.Color = ColorSequence.new(Color3.fromRGB(190, 210, 255))
		drops.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(0.1, 0.2), NumberSequenceKeypoint.new(1, 0.8),
		})
		drops.LightInfluence = 0
		drops.Orientation = Enum.ParticleOrientation.VelocityParallel
		drops.Parent = rain
		rain.Parent = workspace
		local emitterPart = rain
		task.spawn(function()
			while emitterPart.Parent do
				local cam = workspace.CurrentCamera
				if cam then emitterPart.Position = cam.CFrame.Position + Vector3.new(0, 32, 0) end
				task.wait(0.1)
			end
		end)
	elseif weather ~= "Thunderstorm" and rain then
		rain:Destroy()
		rain = nil
		stormClouds:Destroy()
		stormClouds = nil
	end
end
workspace:GetAttributeChangedSignal("Weather"):Connect(syncWeather)
syncWeather()

-- Plaza machines open their panels (close the current tab first, like the Menu).
local PLAZA_PANELS = { FuseMachinePrompt = "FusePanel", GearShopPrompt = "ShopPanel", IndexBoardPrompt = "IndexPanel" }
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	local panelName = PLAZA_PANELS[prompt.Name]
	if panelName then
		local main = player.PlayerGui:FindFirstChild("MainUI")
		if main and main:GetAttribute("OpenMenuPanel") then return end
		local panel = main and main:FindFirstChild(panelName)
		if panel then
			panel:SetAttribute("OpenRequest", os.clock())
		end
	end
end)

-- Plaza chest: this player's own countdown on the shared chest (local text only)
task.spawn(function()
	local chest = workspace:WaitForChild("Plaza"):WaitForChild("RewardChest"):WaitForChild("Body")
	local board = chest:WaitForChild("Timer", 120) -- made by PlazaService once the server finishes starting
	local timer = board and board:WaitForChild("Text", 10)
	if not timer then return end
	while true do
		local left = math.ceil((player:GetAttribute("ChestReadyAt") or 0) - workspace:GetServerTimeNow())
		timer.Text = left <= 0 and '<font color="#7dff9a">Free chest ready!</font>'
			or ("Free chest in %d:%02d:%02d"):format(left // 3600, left % 3600 // 60, left % 60)
		task.wait(1)
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
hint.Size = UDim2.new(0.7, 0, 0, 48)
hint.TextWrapped = true
local hintMax = Instance.new("UISizeConstraint")
hintMax.MaxSize = Vector2.new(640, 48)
hintMax.Parent = hint
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

-- tutorial progress is saved server-side; "Tips" lists the keys already done (nil until data loads)
local marked = {}
local function done(key)
	return marked[key] or table.find(string.split(player:GetAttribute("Tips") or "", ","), key) ~= nil
end
local function mark(key)
	if not done(key) then
		marked[key] = true
		Remotes.TipSeen:FireServer(key)
	end
end
local finishedAt -- show "complete" for a few seconds

local function myPlot()
	return workspace.HomeRow.Plots:FindFirstChild(player:GetAttribute("Plot") or "")
end

-- returns (goal position or nil, hint text or nil); nil, nil = tutorial finished
local function tutorialStep()
	if player:GetAttribute("Tips") == nil then
		return nil, nil
	end
	if done("done") then
		if finishedAt and os.clock() - finishedAt < 6 then
			return nil, "Tutorial complete! Open the Guide any time for help."
		end
		return nil, nil
	end
	if (player:GetAttribute("Rebirths") or 0) > 0 or (player:GetAttribute("BestBiome") or 0) >= 3 then
		mark("done") -- veterans from before the tutorial existed
		return nil, nil
	end
	if player:GetAttribute("CarryingEgg") then
		local plot = myPlot()
		return plot and plot.Spawn.Position, "Run it home before the guardian catches you!"
	end
	if not done("rode") then
		if (player:GetAttribute("CreatureCount") or 0) == 0 then
			if (player:GetAttribute("Incubating") or 0) > 0 then
				return nil, "Your egg is hatching. Watch the timer on your incubator!"
			end
			return nestPosition("Forest"), "Steal an egg from the Forest nest!"
		end
		if not player:GetAttribute("Riding") then
			return nil, "Ride your new creature! Open the Stable and press Ride."
		end
		mark("rode")
	end
	if not done("saddle") then
		if (player:GetAttribute("SaddleLevel") or 0) < 1 then
			if (player:GetAttribute("CashPerSecond") or 0) <= 0 then
				if (player:GetAttribute("Incubating") or 0) > 0 then
					return nil, "Let your next egg hatch. Keep that creature in the pen to earn cash!"
				end
				return nestPosition("Forest"), "Steal another egg! Your ride is for speed; pen creatures earn cash."
			end
			local price = Config.Costs.saddle(1)
			if (player:GetAttribute("Cash") or 0) < price then
				return nil, ("Your pen is earning! Save $%.0f for your first Saddle upgrade."):format(price)
			end
			return nil, "Open the Shop and get your first Saddle upgrade!"
		end
		mark("saddle")
	end
	if not done("lock") then
		-- a manual lock lasts longer than the free join lock, so that's how we spot the button press
		if (player:GetAttribute("LockLeft") or 0) <= Config.Plot.joinLock then
			local plot = myPlot()
			local button = plot and plot:FindFirstChild("LockButton")
			return button and button.Position, "Protect your eggs: press the red Lock button at your base."
		end
		mark("lock")
	end
	if not done("gear") then
		local owned = (player:GetAttribute("GearNet") or 0) + (player:GetAttribute("GearTrap") or 0) + (player:GetAttribute("GearSoda") or 0)
		if owned == 0 then
			return workspace.Plaza.GearShop:GetPivot().Position, "Visit the Gear Shop in the Plaza: nets, traps and speed soda."
		end
		mark("gear")
	end
	if (player:GetAttribute("BestBiome") or 0) < 2 then
		return nestPosition("Lake"), "Steal a Lake egg! Swim riders can hide from the Swan on the water patches."
	end
	mark("done")
	finishedAt = os.clock()
	return nil, "Tutorial complete! Open the Guide any time for help."
end

local function updateTutorial(root)
	local goal, text = tutorialStep()
	local fighting = workspace:GetAttribute("MamaPhase") == "active"
	hint.Parent:SetAttribute("TutorialActive", text ~= nil and not fighting)
	if fighting then text, goal = nil, nil end
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
