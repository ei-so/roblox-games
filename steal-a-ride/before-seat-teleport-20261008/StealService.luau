-- PvP: steal eggs from carriers and from unlocked bases (never creatures), take-backs,
-- base locks, and the new-player shield (first 15 min: can't steal or be stolen from).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local EggService = require(script.Parent.EggService)
local HatchService = require(script.Parent.HatchService)
local GuardianService = require(script.Parent.GuardianService)

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

local function tick()
	local now = os.clock()
	local carriers = EggService.carriers()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local egg = carriers[player]
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
					other.Character:PivotTo(CFrame.new(plot.Floor.Position.X - side * 36, 4, plot.Floor.Position.Z))
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
		robbedAt[player], lockedUntil[player] = nil, nil
	end)
end

return StealService
