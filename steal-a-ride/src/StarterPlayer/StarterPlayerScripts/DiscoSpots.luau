-- Disco balls (BaseService, tag "DiscoBall"): a soft neon spot where each spotlight beam lands, so the colours show on the
-- floor even in daylight (real lights wash out). Local only; follows the spinning ball every frame and pulses with
-- the ball's music (Sound.PlaybackLoudness, measured against the track's own recent peak).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local camera = workspace.CurrentCamera
local RANGE = 150 -- only balls this close to the camera
local spots = {} -- [SpotLight] = local disc
local beats = setmetatable({}, { __mode = "k" }) -- [ball] = { level = 0..1 smoothed, peak = recent loudest }

local function pulseOf(ball): number
	local music = ball:FindFirstChild("Music")
	local loud = music and music.IsPlaying and music.PlaybackLoudness or 0
	local beat = beats[ball] or { level = 0, peak = 50 }
	beats[ball] = beat
	beat.peak = math.max(loud, beat.peak * 0.995, 50) -- slowly forgets old peaks; floor keeps silence from looking loud
	beat.level += (loud / beat.peak - beat.level) * 0.35 -- quick attack/release so beats read clearly
	return beat.level
end

local function disc()
	local p = Instance.new("Part")
	p.Shape, p.Material, p.Transparency = Enum.PartType.Cylinder, Enum.Material.Neon, 0.35
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = camera
	return p
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

RunService.RenderStepped:Connect(function()
	local ignore = { camera }
	for _, player in Players:GetPlayers() do
		table.insert(ignore, player.Character)
	end
	local seen = {}
	for _, ball in CollectionService:GetTagged("DiscoBall") do
		if ball:IsDescendantOf(workspace) and (ball.Position - camera.CFrame.Position).Magnitude < RANGE then
			table.insert(ignore, ball)
			params.FilterDescendantsInstances = ignore
			local pulse = pulseOf(ball)
			for _, light in ball:GetDescendants() do
				if light:IsA("SpotLight") and light.Enabled then
					local aim = light.Parent.WorldCFrame
					local hit = workspace:Raycast(aim.Position, aim.LookVector * light.Range, params)
					if hit then
						local spot = spots[light] or disc()
						spots[light] = spot
						local size = math.min(hit.Distance * 0.45, 6) * (0.75 + 0.45 * pulse) -- widens with distance, swells on the beat
						spot.Size, spot.Color, spot.Transparency = Vector3.new(0.05, size, size), light.Color, 0.6 - 0.4 * pulse
						-- a cylinder's axis is its X: point it along the surface normal, just off the surface
						spot.CFrame = CFrame.lookAt(hit.Position + hit.Normal * 0.04, hit.Position + hit.Normal * 2) * CFrame.Angles(0, math.rad(90), 0)
						seen[light] = true
					end
				end
			end
		end
	end
	for light, spot in spots do
		if not seen[light] then
			spot:Destroy()
			spots[light] = nil
		end
	end
end)
