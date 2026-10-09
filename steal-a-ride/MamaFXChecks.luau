-- Execute in the Play CLIENT before ServerStorage.TestHooks:Invoke("mama", {warning=8,duration=60}).
-- Use SAMFeedback_20261007_a, wait for the profile to load, and restore Edit Config after Play.
-- Results live only in PlayerScripts.MamaFXCheckResults; never install this as a game script.
local player = game.Players.LocalPlayer
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local result = Instance.new("Folder")
result.Name = "MamaFXCheckResults"
result.Parent = player.PlayerScripts
result:SetAttribute("State", "waiting")
task.spawn(function()
	local evidence = { shadowMinZ = math.huge, shadowMaxZ = -math.huge }
	local ok, err = pcall(function()
		local deadline = os.clock() + 30
		repeat task.wait(0.1) until workspace:GetAttribute("MamaPhase") == "warning" or os.clock() > deadline
		assert(workspace:GetAttribute("MamaPhase") == "warning", "Mama warning never started")
		result:SetAttribute("State", "sampling")
		local started = os.clock()
		local mix = SoundService:FindFirstChild("MamaDuckedLoops")
		assert(mix, "Mama sound mixer missing")
		while workspace:GetAttribute("MamaPhase") and os.clock() - started < 85 do
			local phase = workspace:GetAttribute("MamaPhase")
			if os.clock() - started > 1.2 then
				assert(math.abs(mix.Volume - 0.2) < 0.01, "music duck did not persist through " .. phase)
				evidence[phase .. "Mix"] = mix.Volume
			end
			for _, s in SoundService:GetChildren() do
				if s:IsA("Sound") and s.IsPlaying then
					if s.Name == "MamaRoar" then
						evidence.roar = s.IsLoaded and s.PlaybackSpeed < 1 and s:FindFirstChildOfClass("ReverbSoundEffect") ~= nil
							and s:FindFirstChildOfClass("EqualizerSoundEffect") ~= nil
					elseif s.Name == "MamaStep" then evidence.step = s.IsLoaded
					elseif s.Looped then
						assert(s.SoundGroup == mix, s.Name .. " escaped Mama ducking")
						if s.Name == "HomeMusic" and phase == "warning" and os.clock() - started > 1.2 then
							evidence.homeEffectiveVolume = s.Volume * mix.Volume
						elseif s.Name == "EscapeMusic" then
							evidence.escapeEffectiveVolume = s.Volume * mix.Volume
						end
					end
				end
			end
			local shadow = workspace:FindFirstChild("MamaShadow")
			if shadow then
				assert(not shadow.CanCollide and not shadow.CanQuery and not shadow.CanTouch, "entrance shadow blocks gameplay")
				evidence.shadowMinZ = math.min(evidence.shadowMinZ, shadow.Position.Z)
				evidence.shadowMaxZ = math.max(evidence.shadowMaxZ, shadow.Position.Z)
				evidence.shadowFallback = shadow.Shape == Enum.PartType.Cylinder
				local whoosh = shadow:FindFirstChild("MamaWhoosh")
				if whoosh then evidence.whoosh = whoosh.IsLoaded and whoosh.IsPlaying end
			end
			local mama = workspace:FindFirstChild("MamaDragon")
			local wing = mama and mama:FindFirstChild("MamaWingLoop", true)
			if phase == "active" and wing then
				evidence.wing = wing.Looped and wing.IsPlaying and wing.IsLoaded and wing.Parent:IsA("BasePart")
			end
			result:SetAttribute("Evidence", HttpService:JSONEncode(evidence))
			task.wait(0.1)
		end
		assert(workspace:GetAttribute("MamaPhase") == nil, "Mama event never ended")
		task.wait(1.2)
		assert(evidence.roar and evidence.whoosh and evidence.step and evidence.wing, "Mama audio was missing or unloaded")
		assert(evidence.shadowMinZ < -125 and evidence.shadowMaxZ > 110, "shadow did not sweep road to plaza")
		assert(math.abs(mix.Volume - 1) < 0.01, "music not restored at event end")
		assert(not workspace:FindFirstChild("MamaShadow"), "shadow leaked after event")
		assert(not workspace:FindFirstChild("MamaDragon"), "Mama/wing loop leaked after event")
		evidence.restoredMix, evidence.cleanup = mix.Volume, true
	end)
	result:SetAttribute("Evidence", HttpService:JSONEncode(evidence))
	result:SetAttribute("State", ok and "PASS" or "FAIL")
	if not ok then result:SetAttribute("Error", tostring(err)) end
end)
return "Mama entrance checks waiting for warning"
