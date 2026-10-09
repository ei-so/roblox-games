-- Run as a temporary LocalScript in PlayerScripts during a Studio playtest.
-- Checks real transitions, grounded particles, fixed collision, visual motion, and audio cleanup.
task.wait(1) -- Let Studio finish the camera guard before this injected check starts.
local Players, Lighting = game:GetService("Players"), game:GetService("Lighting")
local SoundService, HttpService = game:GetService("SoundService"), game:GetService("HttpService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
assert(not player:GetAttribute("CarryingEgg"), "Run without carrying an egg")
local camera, start, anchored = workspace.CurrentCamera, character:GetPivot(), root.Anchored
local cameraType, cameraFrame = camera.CameraType, camera.CFrame
-- Start snapshots after Home has released any visuals from a previous run.
root.Anchored = true
camera.CameraType = Enum.CameraType.Scriptable
character:PivotTo(CFrame.new(0, 4, 0))
camera.CFrame = CFrame.new(0, 8, 18)
task.wait(.7)
local failures, results, originals = {}, {}, {}
for _, b in workspace.Biomes:GetChildren() do
	local props = b:FindFirstChild("Props")
	if props then
		for _, d in props:GetDescendants() do
			if d:IsA("BasePart") then
				originals[d] = { cf = d.CFrame, collide = d.CanCollide, query = d.CanQuery, transparency = d.LocalTransparencyModifier }
			end
		end
	end
end
local frames, elapsed = 0, 0
local frameCounter = game:GetService("RunService").RenderStepped:Connect(function(dt)
	frames += 1
	elapsed += dt
end)
local function check(ok, message)
	if not ok and not table.find(failures, message) then table.insert(failures, message) end
end
local function audibleRegion(id)
	local target = id == "Home" and "HomeMusic" or "Ambience" .. id
	local playing, loaded = 0, false
	for _, s in SoundService:GetChildren() do
		if s:IsA("Sound") and (s.Name == "HomeMusic" or s.Name:sub(1, 8) == "Ambience") then
			if s.IsPlaying then playing += 1 end
			if s.Name == target then loaded = s.IsLoaded and s.IsPlaying and s.Volume > .01 end
		end
	end
	check(loaded, id .. ": ambience did not load/play")
	check(playing == 1, id .. ": inactive ambience loops keep playing")
end
local ok, err = pcall(function()
	for _, id in { "Forest", "Lake", "Desert", "Jungle", "Tundra", "Volcano", "Cosmic" } do
		local b = workspace.Biomes[id]
		local z = (b:GetAttribute("EntranceZ") + b:GetAttribute("FarZ")) / 2
		local floorTop = b.Floor.Position.Y + b.Floor.Size.Y / 2
		character:PivotTo(CFrame.new(-15, floorTop + 55, z)) -- Keep the test character above gameplay hazard volumes.
		camera.CFrame = CFrame.lookAt(Vector3.new(-15, floorTop + 8, z + 18), Vector3.new(-15, floorTop + 4, z - 40))
		task.wait(2.2)
		local airCount = 0
		for _, h in camera:GetChildren() do
			if h:IsA("BasePart") and h:GetAttribute("AirHost") then
				check(h.Position.Y - h.Size.Y / 2 >= floorTop - .02, id .. ": particles spawn below floor")
				for _, e in h:GetChildren() do
					if e:IsA("ParticleEmitter") and e.Enabled then
						airCount += 1
						check(e:GetAttribute("Biome") == id, id .. ": wrong biome's air emitter enabled")
					end
				end
			end
		end
		check(math.abs(root.Position.Z - z) < 1, id .. ": gameplay displaced the test character")
		check(airCount > 0, id .. ": no ambient particles")
		local motion = camera:FindFirstChild("BiomeMotion")
		local visuals = motion and motion:GetChildren() or {}
		check(#visuals > 0 and #visuals <= 60, id .. ": nearby visual motion missing/over cap")
		for _, v in visuals do
			for _, part in v:GetDescendants() do
				if part:IsA("BasePart") then
					check(not part.CanCollide and not part.CanQuery and not part.CanTouch, id .. ": visual clone affects collision/query")
				end
			end
			if v:IsA("BasePart") then check(not v.CanCollide and not v.CanQuery and not v.CanTouch, id .. ": visual part affects collision") end
		end
		local visual = visuals[1]
		if id == "Cosmic" then
			visual = nil
			for _, v in visuals do
				local name = v.Name:lower()
				if name:find("crystal") or name:find("asteroid") then visual = v break end
			end
			check(visual ~= nil, "Cosmic: no nearby crystal/asteroid motion")
		end
		local pose = visual and visual:GetPivot()
		camera.CFrame = CFrame.lookAt(Vector3.new(-15, floorTop + 2, z + 18), Vector3.new(-15, floorTop + 2, z - 40))
		task.wait(.3)
		for _, h in camera:GetChildren() do
			if h:IsA("BasePart") and h:GetAttribute("AirHost") then
				check(h.Position.Y - h.Size.Y / 2 >= floorTop - .02, id .. ": low camera puts particles below floor")
			end
		end
		check(not visual or visual:GetPivot() ~= pose, id .. ": visual prop is frozen")
		for part, state in originals do
			check(part.CFrame == state.cf and part.CanCollide == state.collide and part.CanQuery == state.query,
				id .. ": original prop collision moved/changed")
		end
		audibleRegion(id)
		local bloom, rays = Lighting:FindFirstChildOfClass("BloomEffect"), Lighting:FindFirstChildOfClass("SunRaysEffect")
		check(bloom and bloom.Enabled and rays and rays.Enabled, id .. ": lighting disabled")
		if id == "Lake" or id == "Jungle" or id == "Volcano" then
			local texture
			for _, d in b:GetDescendants() do
				if d:IsA("Texture") and d.Name == "BiomeFlow" then
					texture = d
					break
				end
			end
			check(texture ~= nil, id .. ": no animated patch surface")
			if texture then
				local surface = texture.Parent
				camera.CFrame = CFrame.lookAt(surface.Position + Vector3.new(0, 8, 18), surface.Position)
				task.wait(.3)
				local offset = texture.OffsetStudsU
				local host = surface:FindFirstChild("BiomeVFXSurface")
				local light = host and host:FindFirstChildOfClass("PointLight")
				local brightness = light and light.Brightness
				task.wait(.3)
				check(texture.Transparency < 1, id .. ": nearby patch flow is hidden")
				if id == "Volcano" then
					check(light and light.Enabled and light.Brightness ~= brightness, "Volcano: lava light does not pulse")
				end
				check(math.abs(texture.OffsetStudsU - offset) > .005, id .. ": patch surface is frozen")
				check(texture.Parent.Transparency < 1, id .. ": patch texture is on an invisible trigger")
			end
		end
		camera.CFrame = CFrame.new(500, floorTop + 8, z)
		task.wait(.3)
		check(not motion or #motion:GetChildren() == 0, id .. ": distant visual clones remain active")
		for part, state in originals do
			check(part.LocalTransparencyModifier == state.transparency, id .. ": distant original prop remains hidden")
		end
		table.insert(results, { biome = id, position = tostring(root.Position), activeAir = airCount, bloom = bloom and bloom.Intensity, rays = rays and rays.Intensity })
	end
	character:PivotTo(CFrame.new(0, 4, 0))
	camera.CFrame = CFrame.new(0, 8, 18)
	task.wait(2.2)
	for _, d in camera:GetDescendants() do
		if d:IsA("ParticleEmitter") then check(not d.Enabled, "Home: biome particles remain enabled") end
	end
	for _, b in workspace.Biomes:GetChildren() do
		for _, d in b:GetDescendants() do
			if d:IsA("ParticleEmitter") and d.Name == "BiomeVFX" then check(not d.Enabled, "Home: patch/nest particles remain enabled") end
		end
	end
	check(not camera:FindFirstChild("BiomeMotion") or #camera.BiomeMotion:GetChildren() == 0, "Home: visual motion remains active")
	audibleRegion("Home")
end)
character:PivotTo(start)
root.Anchored = anchored
camera.CameraType, camera.CFrame = cameraType, cameraFrame
frameCounter:Disconnect()
if not ok then table.insert(failures, tostring(err)) end
local report = HttpService:JSONEncode({ passed = #failures == 0, failures = failures, biomes = results, meanFPS = frames / math.max(elapsed, .001) })
workspace:SetAttribute("BiomeVFXCheckResult", report)
print("BiomeVFX checks", report)
