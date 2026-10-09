-- PvP: steal eggs from carriers and from unlocked bases (never creatures), take-backs, the base stun stick,
-- base locks, and the new-player shield (first 15 min: can't steal or be stolen from).
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local EggService = require(script.Parent.EggService)
local HatchService = require(script.Parent.HatchService)
local GuardianService = require(script.Parent.GuardianService)
local SpeedService = require(script.Parent.SpeedService)
local BaseService = require(script.Parent.BaseService)

local Notify = ReplicatedStorage.Remotes.Notify
local S = Config.Steal

local StealService = {}
StealService.onStolen = nil

local robbedAt = {} -- [victim] = os.clock()
local lockedUntil = {} -- [owner] = os.time()

local function rootOf(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

function StealService.shielded(player): boolean
	return DataService.get(player) ~= nil and DataService.playtime(player) < S.shieldSeconds
end

function StealService.lockSeconds(player): number
	local data = DataService.get(player)
	return Config.Plot.lockSeconds + Config.Plot.lockPerRebirth * (data and data.Rebirths or 0)
end

function StealService.isLocked(owner): boolean
	return StealService.shielded(owner) or (lockedUntil[owner] or 0) > os.time()
end

function StealService.lock(owner, seconds: number)
	lockedUntil[owner] = math.max(lockedUntil[owner] or 0, os.time() + seconds)
end

-- returns ok, reason
function StealService.canSteal(thief, victim)
	local humanoid = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
	if thief == victim or not humanoid or humanoid.Health <= 0 then
		return false, nil
	elseif workspace:GetAttribute("MamaPhase") == "active" then
		return false, "No stealing while Mama Dragon attacks. Fight her together!"
	elseif StealService.shielded(thief) then
		return false, "You're shielded for your first 15 minutes, so you can't steal yet."
	elseif StealService.shielded(victim) then
		return false, victim.DisplayName .. " is a new player and is shielded."
	elseif EggService.isCarrying(thief) then
		return false, "You're already carrying an egg!"
	elseif os.clock() - (robbedAt[victim] or -math.huge) < S.robCooldown then
		return false, victim.DisplayName .. " was just robbed. Give them a minute!"
	elseif os.clock() - (GuardianService.caughtAt[thief] or -math.huge) < S.catchGrace then
		return false, nil
	end
	return true, nil
end

local function refuse(player, reason)
	if reason then
		Notify:FireClient(player, "toast", reason)
	end
end

local function hand(thief, victim, egg)
	egg.stolenFrom = victim
	egg.stolenAt = os.clock()
	egg.victims = egg.victims or {} -- everyone it was stolen from while carried (stick hits chained thieves too)
	egg.victims[victim] = true
	robbedAt[victim] = os.clock()
	local attached = EggService.attach(thief, egg)
	if attached and StealService.onStolen then StealService.onStolen(thief) end
	Notify:FireClient(thief, "toast", "Stolen! Get it home!")
end

function StealService.stealFromCarrier(thief, victim)
	local ok, reason = StealService.canSteal(thief, victim)
	local a, b = rootOf(thief), rootOf(victim)
	if not ok or not a or not b or (a.Position - b.Position).Magnitude > S.carrierRange + 2 then
		return refuse(thief, reason)
	end
	local egg = EggService.take(victim)
	if egg then
		hand(thief, victim, egg)
		Notify:FireClient(victim, "alarm", thief.DisplayName .. " stole your egg! Catch them to take it back!")
	end
end

function StealService.raid(thief, owner, slot: number)
	local ok, reason = StealService.canSteal(thief, owner)
	if not ok then
		return refuse(thief, reason)
	end
	if StealService.isLocked(owner) then
		return refuse(thief, "That base is locked!")
	end
	local plot = PlotService.get(owner)
	local pad = plot and plot.Incubators:FindFirstChild("Incubator" .. slot)
	local root = rootOf(thief)
	if not pad or not root or (root.Position - pad.Position).Magnitude > 12 then
		return
	end
	local egg = HatchService.takeEgg(owner, slot)
	if egg then
		egg.owner = owner -- raided eggs have no nest: if dropped, they go back to the owner
		hand(thief, owner, egg)
		Notify:FireClient(owner, "alarm", "Your base is being raided by " .. thief.DisplayName .. "!")
	end
end

function StealService.takeBack(victim, thief)
	local egg = EggService.getCarried(thief)
	local a, b = rootOf(victim), rootOf(thief)
	if not egg or egg.stolenFrom ~= victim or os.clock() - egg.stolenAt > S.takeBackWindow
		or not a or not b or (a.Position - b.Position).Magnitude > S.takeBackRange + 2 then
		return
	end
	EggService.take(thief)
	HatchService.give(victim, egg)
	Notify:FireClient(victim, "toast", "Got it back! It's in your incubator.")
	Notify:FireClient(thief, "toast", victim.DisplayName .. " took their egg back!")
end

-- dropped eggs with no nest: raided eggs go home to their owner
function StealService.returnToOwner(egg)
	if egg.owner and egg.owner.Parent then
		HatchService.give(egg.owner, egg)
	end
end

local function prompt(parent, name, action, hold, range, owner)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.HoldDuration = hold
	p.MaxActivationDistance = range
	p.RequiresLineOfSight = false
	p:SetAttribute("Owner", owner.UserId)
	p.Parent = parent
	return p
end

local function insidePlot(plot, pos)
	local floor = plot.Floor
	local offset = pos - floor.Position
	return math.abs(offset.X) < floor.Size.X / 2 + 0.5 and math.abs(offset.Z) < floor.Size.Z / 2 + 0.5
end

-- Base stun stick: owners hold it only inside their own plot. A hit on someone carrying an egg stolen from the owner
-- (directly or further down a chain of steals) stuns them, sends the egg home and clears the robbed cooldown.
local lastSwing = {} -- [owner] = os.clock()

local function hitFx(root, item)
	local burst = Instance.new("ParticleEmitter")
	burst.Color = item.glitch and ColorSequence.new(Color3.fromRGB(255, 42, 79), Color3.fromRGB(37, 232, 255)) or ColorSequence.new(item.color)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Speed = NumberRange.new(10, 18)
	burst.Lifetime = NumberRange.new(0.3, 0.5)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Parent = root
	burst:Emit(item.burst)
	Debris:AddItem(burst, 1)
	local bonk = SoundService.SFX:FindFirstChild("StickHit") -- played at the thief so everyone nearby hears the whack land
	if bonk then
		bonk = bonk:Clone()
		bonk.Parent = root
		bonk:Play()
		Debris:AddItem(bonk, 2)
	end
end

function StealService.swing(owner)
	local now = os.clock()
	if now - (lastSwing[owner] or -math.huge) < Config.Stick.cooldown then
		return nil
	end
	lastSwing[owner] = now
	local plot, root = PlotService.get(owner), rootOf(owner)
	local humanoid = owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
	if not plot or not root or not humanoid or humanoid.Health <= 0 or not insidePlot(plot, root.Position) then
		return nil
	end
	local thief, best
	for carrier, egg in EggService.carriers() do
		local r = rootOf(carrier)
		local d = r and (r.Position - root.Position).Magnitude
		if egg.victims and egg.victims[owner] and d and d <= Config.Stick.range and (not best or d < best) then
			thief, best = carrier, d
		end
	end
	if not thief then
		return nil
	end
	local egg = EggService.take(thief)
	HatchService.give(owner, egg)
	SpeedService.stun(thief, Config.Stick.stun)
	robbedAt[owner] = nil
	hitFx(rootOf(thief), Config.Base.itemById[BaseService.equipped(DataService.get(owner), "stick")])
	Notify:FireClient(owner, "toast", "Whacked! Your egg is back home.")
	Notify:FireClient(thief, "toast", owner.DisplayName .. " whacked you! The egg went home.")
	return thief
end

-- a click: clicks inside the swing cooldown do nothing at all (no anim spam from exploit clients)
function StealService.activate(owner, tool)
	if os.clock() - (lastSwing[owner] or -math.huge) < Config.Stick.cooldown then
		return nil
	end
	local anim = Instance.new("StringValue")
	anim.Name, anim.Value = "toolanim", "Slash" -- the default Animate script plays a slash
	anim.Parent = tool
	Debris:AddItem(anim, 1)
	local whoosh = SoundService.SFX:FindFirstChild("StickSwing") -- played at the stick so nearby players hear it
	if whoosh and tool.Handle then
		whoosh = whoosh:Clone()
		whoosh.Parent = tool.Handle
		whoosh:Play()
		Debris:AddItem(whoosh, 2)
	end
	return StealService.swing(owner)
end

local function buildStick(owner, itemId)
	local item = Config.Base.itemById[itemId]
	local tool = Instance.new("Tool")
	tool.Name = "Stick"
	tool.CanBeDropped = false
	tool.ToolTip = item.name
	tool:SetAttribute("Skin", itemId)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 4.2)
	handle.Color = item.color
	handle.Material = Enum.Material[item.material]
	handle.CanCollide, handle.Massless = false, true
	handle.Parent = tool
	tool.GripPos, tool.GripUp = Vector3.new(0, 0, -1.6), Vector3.new(0, 0, 1) -- classic sword grip: held near one end, raised
	tool.GripForward, tool.GripRight = Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0)
	if item.trail then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0, 2), Vector3.new(0, 0, 1)
		a0.Parent, a1.Parent = handle, handle
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.25
		trail.LightEmission = 1
		trail.Color = item.glitch and ColorSequence.new(Color3.fromRGB(255, 42, 79), Color3.fromRGB(37, 232, 255)) or ColorSequence.new(item.color)
		trail.Parent = handle
	end
	tool.Activated:Connect(function() -- Tool activation replicates to the server: no RemoteEvent needed
		StealService.activate(owner, tool)
	end)
	return tool
end

-- fully automatic: held while inside your own plot (put back in hand if unequipped), re-skinned on equip change, gone outside
local function syncStick(player, root)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = (character and character:FindFirstChild("Stick")) or (backpack and backpack:FindFirstChild("Stick"))
	local plot, data = PlotService.get(player), DataService.get(player)
	local want = root and plot and data and insidePlot(plot, root.Position) and BaseService.equipped(data, "stick")
	if tool and tool:GetAttribute("Skin") ~= want then
		tool:Destroy()
		tool = nil
	end
	if want then
		tool = tool or buildStick(player, want)
		if tool.Parent ~= character then
			tool.Parent = character
		end
	end
end

local function tick()
	local now = os.clock()
	local carriers = EggService.carriers()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local egg = carriers[player]
		syncStick(player, root)
		-- carrier prompts: Steal Egg for everyone else; Take Back for the victim during the window
		if root then
			local steal = root:FindFirstChild("StealPrompt")
			if egg and not steal then
				prompt(root, "StealPrompt", "Steal Egg", S.carrierHold, S.carrierRange, player).Triggered:Connect(function(thief)
					StealService.stealFromCarrier(thief, player)
				end)
			elseif not egg and steal then
				steal:Destroy()
			end
			local back = root:FindFirstChild("TakeBackPrompt")
			local open = egg and egg.stolenFrom and egg.stolenFrom.Parent and now - egg.stolenAt <= S.takeBackWindow
			if open and not back then
				back = prompt(root, "TakeBackPrompt", "Take Back", S.takeBackHold, S.takeBackRange, player)
				back:SetAttribute("OnlyFor", egg.stolenFrom.UserId)
				back.Triggered:Connect(function(victim)
					StealService.takeBack(victim, player)
				end)
			elseif not open and back then
				back:Destroy()
			end
		end
		-- shield + lock state for the HUD
		player:SetAttribute("Shielded", StealService.shielded(player))
		local left = math.max(0, (lockedUntil[player] or 0) - os.time())
		player:SetAttribute("LockLeft", left)
		local plot = PlotService.get(player)
		if plot then
			plot.Barrier.Transparency = StealService.isLocked(player) and 0.35 or 1
		end
	end
	-- locked bases push out everyone except the owner
	for _, owner in Players:GetPlayers() do
		local plot = PlotService.get(owner)
		if plot and StealService.isLocked(owner) then
			for _, other in Players:GetPlayers() do
				local root = rootOf(other)
				if other ~= owner and root and insidePlot(plot, root.Position) then
					local side = plot:GetAttribute("Side")
					PlotService.teleport(other.Character, CFrame.new(plot.Floor.Position.X - side * 36, 4, plot.Floor.Position.Z))
					Notify:FireClient(other, "toast", "That base is locked!")
				end
			end
		end
	end
end

function StealService.onPlayerReady(player)
	StealService.lock(player, Config.Plot.joinLock)
	local plot = PlotService.get(player)
	local button = plot and plot:FindFirstChild("LockButton")
	if button and not button:FindFirstChild("LockPrompt") then
		local p = Instance.new("ProximityPrompt")
		p.Name = "LockPrompt"
		p.ActionText = "Lock Base"
		p.HoldDuration = 0
		p.MaxActivationDistance = 8
		p.RequiresLineOfSight = false
		p.Parent = button
		p.Triggered:Connect(function(who)
			local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId"))
			if who == owner and (lockedUntil[owner] or 0) <= os.time() then
				StealService.lock(owner, StealService.lockSeconds(owner))
				Notify:FireClient(owner, "toast", ("Base locked for %d seconds"):format(StealService.lockSeconds(owner)))
			end
		end)
	end
end

function StealService.start()
	HatchService.onRaid = StealService.raid
	task.spawn(function()
		while true do
			task.wait(0.3)
			tick()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		robbedAt[player], lockedUntil[player], lastSwing[player] = nil, nil, nil
	end)
end

return StealService
