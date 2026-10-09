-- Abilities that need the server: Dash timing, zone effects (water slows non-swimmers, lava burns
-- non-fireproof riders, thin ice cracks under non-gliders, quicksand swallows non-jumpers, falling into the chasm), and the escape-lane check guardians use.
-- Jump/Glide/Phase movement itself runs on the client (it owns its character's physics).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SpeedService = require(script.Parent.SpeedService)
local MountService = require(script.Parent.MountService)

local Remotes = ReplicatedStorage.Remotes
local Notify = Remotes.Notify

local AbilityService = {}
AbilityService.onPenalty = nil -- function(player): drop the carried egg, set by Main

local lastDash = {}
local lastPenalty = {}
local onPatchSince, stuckUntil = {}, {} -- escape patches: time on one, and the sinking timer

-- inside a zone part's footprint, from just below it to Headroom studs above it
local function inside(part: BasePart, pos: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(pos)
	local s = part.Size
	local headroom = part:GetAttribute("Headroom") or 12
	return math.abs(p.X) <= s.X / 2 and math.abs(p.Z) <= s.Z / 2 and p.Y >= -s.Y / 2 - 1 and p.Y <= s.Y / 2 + headroom
end

local function inAny(tag: string, pos: Vector3): boolean
	for _, part in CollectionService:GetTagged(tag) do
		if inside(part, pos) then
			return true
		end
	end
	return false
end

local function rootOf(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local zones = {} -- [biomeId] = the EscapeLane parts of its patches
local function patchAt(biomeId: string, pos: Vector3): BasePart?
	if not zones[biomeId] then
		zones[biomeId] = {}
		for _, p in workspace.Biomes[biomeId]:GetDescendants() do
			if p.Name == "EscapeLane" and p:IsA("BasePart") then
				table.insert(zones[biomeId], p)
			end
		end
	end
	for _, zone in zones[biomeId] do
		if inside(zone, pos) then
			return zone
		end
	end
	return nil
end

function AbilityService.canEscape(player, biomeId: string): boolean
	local root = rootOf(player)
	local zone = root and (stuckUntil[player] or 0) <= os.clock() and patchAt(biomeId, root.Position)
	return zone ~= nil and zone ~= false and MountService.hasAbility(player, zone:GetAttribute("Ability"))
end

local function biomeAt(z: number)
	for _, biome in Config.Biomes do
		local m = workspace.Biomes[biome.id]
		if z <= m:GetAttribute("EntranceZ") + 10 and z >= m:GetAttribute("FarZ") - 10 then
			return m
		end
	end
	return nil
end

-- stayed on a patch too long: sink, slowed hard, no jumping, and the patch stops protecting you (egg is kept)
local function sink(player, humanoid, biomeId: string)
	local P = Config.Patch
	stuckUntil[player] = os.clock() + P.stuckSeconds
	SpeedService.multiply(player, "stuck", P.stuckSpeed, P.stuckSeconds)
	local usePower = humanoid.UseJumpPower
	local jump = usePower and humanoid.JumpPower or humanoid.JumpHeight
	local hip = humanoid.HipHeight - P.sink
	if usePower then humanoid.JumpPower = 0 else humanoid.JumpHeight = 0 end
	humanoid.HipHeight = hip
	Notify:FireClient(player, "toast", P.messages[biomeId] or "You're sinking!")
	task.delay(P.stuckSeconds, function()
		if humanoid.Parent then -- restore only what nothing else (a remount) changed meanwhile
			if usePower and humanoid.JumpPower == 0 then humanoid.JumpPower = jump end
			if not usePower and humanoid.JumpHeight == 0 then humanoid.JumpHeight = jump end
			if humanoid.HipHeight == hip then humanoid.HipHeight = hip + P.sink end
		end
	end)
end

-- obstacle penalty: lose the egg, respawn at the biome's exit arch
local function penalty(player, message: string)
	if os.clock() - (lastPenalty[player] or 0) < 2 then
		return
	end
	lastPenalty[player] = os.clock()
	local root = rootOf(player)
	local biome = root and biomeAt(root.Position.Z)
	if AbilityService.onPenalty then
		AbilityService.onPenalty(player)
	end
	if biome then
		player.Character:PivotTo(CFrame.new(0, 6, biome:GetAttribute("EntranceZ") + 8))
	end
	Notify:FireClient(player, "toast", message)
end

local function check(player)
	local root = rootOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local pos = root.Position
	SpeedService.setInWater(player, inAny("Water", pos) and not MountService.hasAbility(player, "Swim"))
	if inAny("Lava", pos) and not MountService.hasAbility(player, "Fireproof") then
		penalty(player, "Burned by the lava! You need a Fireproof ride.")
	elseif inAny("ThinIce", pos) and not MountService.hasAbility(player, "Glide") then
		penalty(player, "The ice cracked under you! You need a Glide ride.")
	elseif inAny("Quicksand", pos) and not MountService.hasAbility(player, "Jump") then
		penalty(player, "Swallowed by quicksand! You need a Jump ride.")
	elseif inAny("Pit", pos) then
		penalty(player, "You fell into the chasm! Glide riders can make that jump.")
	end
	local biome = biomeAt(pos.Z)
	local now = os.clock()
	if biome and (stuckUntil[player] or 0) <= now and patchAt(biome.Name, pos) then
		if not onPatchSince[player] then
			onPatchSince[player] = now
			player:SetAttribute("PatchSince", workspace:GetServerTimeNow()) -- clients run the sink warning from this
		end
		if now - onPatchSince[player] >= Config.Patch.stuckAfter then
			onPatchSince[player] = nil
			player:SetAttribute("PatchSince", nil)
			sink(player, humanoid, biome.Name)
		end
	elseif (stuckUntil[player] or 0) <= now then
		onPatchSince[player] = nil
		if player:GetAttribute("PatchSince") then player:SetAttribute("PatchSince", nil) end
	end
end

function AbilityService.start()
	Remotes.UseAbility.OnServerEvent:Connect(function(player, ability)
		if ability == "Dash" and MountService.hasAbility(player, "Dash") then
			local dash = Config.Abilities.Dash
			if os.clock() - (lastDash[player] or -math.huge) >= dash.cooldown then
				lastDash[player] = os.clock()
				SpeedService.dash(player, dash.duration)
				Notify:FireClient(player, "dash", dash.cooldown)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastDash[player], lastPenalty[player], onPatchSince[player], stuckUntil[player] = nil, nil, nil, nil
	end)
end

return AbilityService
