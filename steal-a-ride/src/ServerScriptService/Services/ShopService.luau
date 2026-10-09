-- Shop: saddle levels (+1 speed), incubators, pen slots. Gear arrives in Part 4.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local CreatureService = require(script.Parent.CreatureService)
local HatchService = require(script.Parent.HatchService)

local Remotes = ReplicatedStorage.Remotes

local ShopService = {}
ShopService.extraItems = {} -- [itemId] = function(player, data) -> cost?, apply(); Part 4 adds gear here

function ShopService.sync(player)
	local data = DataService.get(player)
	if data then
		player:SetAttribute("SaddleLevel", data.SaddleLevel)
		player:SetAttribute("IncubatorCount", data.IncubatorCount)
		player:SetAttribute("PenSlots", data.PenSlots)
	end
end

-- returns cost (or nil if maxed) and the function that applies the purchase
local ITEMS = {
	saddle = function(player, data)
		local level = data.SaddleLevel + 1
		if level > Config.Costs.saddleMax then
			return nil
		end
		return Config.Costs.saddle(level, CreatureService.priceIncomeOf(player)), function()
			data.SaddleLevel = level
			SpeedService.refresh(player)
		end
	end,
	incubator = function(player, data)
		local n = data.IncubatorCount + 1
		local cost = Config.Costs.incubators[n]
		return cost, function()
			data.IncubatorCount = n
			HatchService.onPlayerReady(player)
		end
	end,
	pen = function(player, data)
		local slot = data.PenSlots + 1
		if slot > Config.Plot.maxPen then
			return nil
		end
		return Config.Costs.penSlot(slot), function()
			data.PenSlots = slot
			CreatureService.changed(player)
		end
	end,
}

function ShopService.buy(player, itemId): boolean
	local data = DataService.get(player)
	local item = type(itemId) == "string" and (ITEMS[itemId] or ShopService.extraItems[itemId])
	if not data or not item then
		return false
	end
	if itemId == "net" or itemId == "trap" or itemId == "soda" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local plaza = workspace:FindFirstChild("Plaza")
		local stall = plaza and plaza:FindFirstChild("GearShop")
		local body = stall and stall:FindFirstChild("Body")
		if not root or not humanoid or humanoid.Health <= 0 or not body or (root.Position - body.Position).Magnitude > 30 then
			return false
		end
	end
	local cost, apply = item(player, data)
	if not cost or data.Cash < cost then
		return false
	end
	DataService.addCash(player, -cost)
	apply()
	ShopService.sync(player)
	return true
end

function ShopService.start()
	Remotes.Buy.OnServerEvent:Connect(ShopService.buy)
end

return ShopService
