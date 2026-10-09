-- Game passes and developer products. IDs live in Config.Monetization (0 = not set up yet).
-- ProcessReceipt is idempotent: processed purchase ids are saved before PurchaseGranted is returned.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local HatchService = require(script.Parent.HatchService)
local CreatureService = require(script.Parent.CreatureService)
local MountService = require(script.Parent.MountService)
local ShopService = require(script.Parent.ShopService)

local Notify = ReplicatedStorage.Remotes.Notify
local M = Config.Monetization

local MonetizationService = {}

-- one-time pass rewards that change saved data
local function applyPass(player, key)
	local data = DataService.get(player)
	if not data then
		return
	end
	player:SetAttribute(key .. "Pass", true)
	if key == "Incubators" and not data.PassesApplied.Incubators then
		data.PassesApplied.Incubators = true
		-- capped at the base 6, but never lowers incubators bought with the base expansion
		data.IncubatorCount = math.max(data.IncubatorCount, math.min(Config.Plot.maxIncubators, data.IncubatorCount + 2))
		HatchService.onPlayerReady(player)
	elseif key == "PenSlots" and not data.PassesApplied.PenSlots then
		data.PassesApplied.PenSlots = true
		data.PenSlots = math.max(data.PenSlots, math.min(Config.Plot.maxPen, data.PenSlots + 5)) -- same for pen slots 21-30
	elseif key == "ExtraMount" then
		MountService.apply(player)
	end
	ShopService.sync(player)
	CreatureService.changed(player)
end

function MonetizationService.onPlayerReady(player)
	-- Paid luck (Lucky pass, Luck Potion, Server Luck) is a paid random item: off where the player's policy restricts it.
	-- Fails closed: if the policy can't be read, paid luck stays off.
	-- The policy and pass lookups are web calls: run them all at once (join waits for the slowest, not the sum),
	-- then apply owned passes one by one.
	local pending, owned = 1, {}
	task.spawn(function()
		local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		player:SetAttribute("PaidLuckBlocked", not ok or policy.ArePaidRandomItemsRestricted == true)
		pending -= 1
	end)
	for key, pass in M.passes do
		if pass.id ~= 0 then
			pending += 1
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
				owned[key] = ok and owns
				pending -= 1
			end)
		end
	end
	local data = DataService.get(player)
	if data then
		player:SetAttribute("PaidLuckUntil", data.PaidLuckUntil)
	end
	while pending > 0 do
		task.wait()
	end
	for key in M.passes do
		if owned[key] then
			applyPass(player, key)
		end
	end
end

local PRODUCTS = {
	InstantHatch = function(player)
		HatchService.instantHatch(player)
	end,
	LuckPotion = function(player)
		local data = DataService.get(player)
		data.PaidLuckUntil = math.max(data.PaidLuckUntil, os.time()) + Config.LuckSeconds
		player:SetAttribute("PaidLuckUntil", data.PaidLuckUntil)
	end,
	ServerLuck = function(player)
		workspace:SetAttribute("ServerLuckUntil", math.max(workspace:GetAttribute("ServerLuckUntil") or 0, os.time()) + Config.LuckSeconds)
		Notify:FireAllClients("toast", player.DisplayName .. " bought Server Luck for everyone!")
	end,
}

function MonetizationService.processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if data.Receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already delivered
	end
	local grant
	for key, product in M.products do
		if product.id ~= 0 and product.id == receipt.ProductId then
			grant = PRODUCTS[key]
		end
	end
	if not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grant(player)
	data.Receipts[receipt.PurchaseId] = os.time()
	-- keep the receipt log small: drop entries older than 30 days
	for id, t in data.Receipts do
		if type(t) == "number" and os.time() - t > 30 * 24 * 3600 then
			data.Receipts[id] = nil
		end
	end
	if not DataService.save(player) then
		data.Receipts[receipt.PurchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries; the receipt id guards against doubles
	end
	Notify:FireClient(player, "toast", "Thanks for your purchase!")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = MonetizationService.processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			for key, pass in M.passes do
				if pass.id == passId then
					applyPass(player, key)
				end
			end
		end
	end)
end

return MonetizationService
