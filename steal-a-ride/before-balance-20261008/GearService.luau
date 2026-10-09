-- Gear bought with cash (price = 30 s of your income, min $50): Net Gun, Slip Trap, Speed Soda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local CreatureService = require(script.Parent.CreatureService)
local ShopService = require(script.Parent.ShopService)
local GuardianService = require(script.Parent.GuardianService)

local Remotes = ReplicatedStorage.Remotes
local Notify = Remotes.Notify
local G = Config.Gear

local GearService = {}
GearService.isShielded = function(_player) return false end -- set by Main (StealService)

local lastNet = {}
local traps = {} -- { part, owner, expires }

function GearService.price(player): number
	return math.max(G.minPrice, math.floor(G.priceSeconds * CreatureService.incomeOf(player)))
end

function GearService.sync(player)
	local data = DataService.get(player)
	if data then
		player:SetAttribute("GearNet", data.Gear.net)
		player:SetAttribute("GearTrap", data.Gear.trap)
		player:SetAttribute("GearSoda", data.Gear.soda)
		player:SetAttribute("GearPrice", GearService.price(player))
	end
end

local function rootOf(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function use(player, gear: string, target)
	local data = DataService.get(player)
	local root = rootOf(player)
	if not data or not root or (data.Gear[gear] or 0) <= 0 then
		return
	end
	if gear == "soda" then
		SpeedService.multiply(player, "soda", 1 + G.soda.boost, G.soda.duration)
		Notify:FireClient(player, "toast", "Speed Soda! +25% speed")
	elseif gear == "net" then
		local targetRoot = typeof(target) == "Instance" and target:IsA("Player") and target ~= player and rootOf(target)
		if not targetRoot or (targetRoot.Position - root.Position).Magnitude > G.net.range then
			return Notify:FireClient(player, "toast", "No one in range for the Net Gun")
		elseif os.clock() - (lastNet[player] or -math.huge) < G.net.cooldown then
			return Notify:FireClient(player, "toast", "Net Gun is reloading")
		elseif GearService.isShielded(target) then
			return Notify:FireClient(player, "toast", target.DisplayName .. " is shielded")
		end
		lastNet[player] = os.clock()
		SpeedService.multiply(target, "net", G.net.slow, G.net.duration)
		Notify:FireClient(target, "toast", "You got netted by " .. player.DisplayName .. "!")
		Notify:FireClient(player, "toast", "Netted " .. target.DisplayName .. "!")
	elseif gear == "trap" then
		local mine = 0
		for _, t in traps do
			if t.owner == player then
				mine += 1
			end
		end
		if mine >= G.trap.maxPlaced then
			return Notify:FireClient(player, "toast", "You already have 2 traps out")
		end
		local part = Instance.new("Part")
		part.Name = "SlipTrap"
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.3, 4, 4)
		part.CFrame = CFrame.new(root.Position.X, 0.6, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		part.Color = Color3.fromRGB(255, 220, 60)
		part.Material = Enum.Material.Neon
		part.Parent = workspace
		table.insert(traps, { part = part, owner = player, expires = os.clock() + G.trap.lifetime })
	else
		return
	end
	data.Gear[gear] -= 1
	GearService.sync(player)
end

function GearService.start()
	for _, gear in { "net", "trap", "soda" } do
		ShopService.extraItems[gear] = function(player, data)
			return GearService.price(player), function()
				data.Gear[gear] += 1
				GearService.sync(player)
			end
		end
	end
	Remotes.UseGear.OnServerEvent:Connect(function(player, gear, target)
		if type(gear) == "string" then
			use(player, gear, target)
		end
	end)
	-- traps: first player (not the owner) or guardian on it gets slowed
	task.spawn(function()
		while true do
			task.wait(0.2)
			for i = #traps, 1, -1 do
				local t = traps[i]
				local hit = os.clock() > t.expires
				if not hit then
					for _, player in Players:GetPlayers() do
						local root = rootOf(player)
						if player ~= t.owner and root and not GearService.isShielded(player) and (Vector3.new(root.Position.X, 0.6, root.Position.Z) - t.part.Position).Magnitude < 3.5 then
							SpeedService.multiply(player, "trap", 1 - G.trap.slow, G.trap.duration)
							Notify:FireClient(player, "toast", "You slipped on a trap!")
							hit = true
							break
						end
					end
					hit = hit or GuardianService.trapNear(t.part.Position, 1 - G.trap.slow, G.trap.duration)
				end
				if hit then
					t.part:Destroy()
					table.remove(traps, i)
				end
			end
		end
	end)
	-- keep gear prices current as income changes
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				if DataService.get(player) then
					player:SetAttribute("GearPrice", GearService.price(player))
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastNet[player] = nil
		for i = #traps, 1, -1 do
			if traps[i].owner == player then
				traps[i].part:Destroy()
				table.remove(traps, i)
			end
		end
	end)
end

return GearService
