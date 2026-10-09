-- ODDS FIX apply (Claude Code). Exact replacements, all checked before any write.
assert(game.PlaceId == 123937616497204, "wrong place: " .. game.PlaceId)
local jobs = {}
local function rep(inst, old, new) table.insert(jobs, {inst, old, new}) end
rep(game.ReplicatedStorage.Shared.Config, [=[
Config.LuckyPassChance = 0.10

-- Free Creator Store audio used by SoundService.SFX (record of what's set there; swap IDs in both places)
Config.Sounds = {]=], [=[
Config.LuckyPassChance = 0.10

-- Exact chance (0..1) of each rarity 1..5 from a normal egg, matching HatchService.roll.
-- luck = roll twice, keep the better; luckyPass = LuckyPassChance of rolls go one rarity up.
-- Shown in the Store before purchase (paid random item odds disclosure).
function Config.hatchOdds(luck: boolean?, luckyPass: boolean?): { number }
	local total, cum, odds = 0, 0, {}
	for i = 1, 5 do
		total += Config.Rarities[i].odds
	end
	for i = 1, 5 do
		local before = cum
		cum += Config.Rarities[i].odds / total
		odds[i] = if luck then cum ^ 2 - before ^ 2 else cum - before
	end
	if luckyPass then
		local p = Config.LuckyPassChance
		for i = 5, 1, -1 do -- descending so odds[i - 1] is still the unshifted value
			odds[i] = odds[i] * (if i == 5 then 1 else 1 - p) + (if i > 1 then odds[i - 1] * p else 0)
		end
	end
	return odds
end

-- Free Creator Store audio used by SoundService.SFX (record of what's set there; swap IDs in both places)
Config.Sounds = {]=])
rep(game.ServerScriptService.Services.DataService, [=[
		Index = {}, -- ["Fox_Rare"] = true
		DailyStreak = 0, LastDaily = 0,
		LuckUntil = 0,
		PassesApplied = {}, -- one-time pass rewards already granted (Incubators, PenSlots)
		Receipts = {}, -- processed developer-product purchase ids (idempotent ProcessReceipt)]=], [=[
		Index = {}, -- ["Fox_Rare"] = true
		DailyStreak = 0, LastDaily = 0,
		LuckUntil = 0, -- free luck (day-7 daily reward)
		PaidLuckUntil = 0, -- Luck Potion (paid; off where paid random items are restricted)
		PassesApplied = {}, -- one-time pass rewards already granted (Incubators, PenSlots)
		Receipts = {}, -- processed developer-product purchase ids (idempotent ProcessReceipt)]=])
rep(game.ServerScriptService.Services.HatchService, [=[
				label.Text = ("%d:%02d"):format(left // 60, left % 60)
			else
				local luck = (data.LuckUntil or 0) > now or (workspace:GetAttribute("ServerLuckUntil") or 0) > now
				egg.result = egg.result or HatchService.roll(egg, luck, player:GetAttribute("LuckyPass")) -- roll once, even if it waits for room
				if CreatureService.add(player, egg.result) then
					Notify:FireClient(player, "hatched", egg.result, slot)]=], [=[
				label.Text = ("%d:%02d"):format(left // 60, left % 60)
			else
				local paidOk = player:GetAttribute("PaidLuckBlocked") == false -- set by MonetizationService from PolicyService
				local luck = (data.LuckUntil or 0) > now
					or paidOk and ((data.PaidLuckUntil or 0) > now or (workspace:GetAttribute("ServerLuckUntil") or 0) > now)
				egg.result = egg.result or HatchService.roll(egg, luck, paidOk and player:GetAttribute("LuckyPass")) -- roll once, even if it waits for room
				if CreatureService.add(player, egg.result) then
					Notify:FireClient(player, "hatched", egg.result, slot)]=])
rep(game.ServerScriptService.Services.MonetizationService, [=[
-- Game passes and developer products. IDs are placeholders in Config.Monetization (0 = not set up yet).
-- ProcessReceipt is idempotent: processed purchase ids are saved before PurchaseGranted is returned.
local Players = game:GetService("Players")]=], [=[
-- Game passes and developer products. IDs live in Config.Monetization (0 = not set up yet).
-- ProcessReceipt is idempotent: processed purchase ids are saved before PurchaseGranted is returned.
local Players = game:GetService("Players")]=])
rep(game.ServerScriptService.Services.MonetizationService, [=[
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)]=], [=[
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)]=])
rep(game.ServerScriptService.Services.MonetizationService, [=[

function MonetizationService.onPlayerReady(player)
	for key, pass in M.passes do
		if pass.id ~= 0 then]=], [=[

function MonetizationService.onPlayerReady(player)
	-- Paid luck (Lucky pass, Luck Potion, Server Luck) is a paid random item: off where the player's policy restricts it.
	-- Fails closed: if the policy can't be read, paid luck stays off.
	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	player:SetAttribute("PaidLuckBlocked", not ok or policy.ArePaidRandomItemsRestricted == true)
	local data = DataService.get(player)
	if data then
		player:SetAttribute("PaidLuckUntil", data.PaidLuckUntil)
	end
	for key, pass in M.passes do
		if pass.id ~= 0 then]=])
rep(game.ServerScriptService.Services.MonetizationService, [=[
	LuckPotion = function(player)
		local data = DataService.get(player)
		data.LuckUntil = math.max(data.LuckUntil, os.time()) + Config.LuckSeconds
		player:SetAttribute("LuckUntil", data.LuckUntil)
	end,
	ServerLuck = function(player)]=], [=[
	LuckPotion = function(player)
		local data = DataService.get(player)
		data.PaidLuckUntil = math.max(data.PaidLuckUntil, os.time()) + Config.LuckSeconds
		player:SetAttribute("PaidLuckUntil", data.PaidLuckUntil)
	end,
	ServerLuck = function(player)]=])
rep(game.StarterGui.MainUI.RetentionUI, [=[
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, storeList)

local PASS_ORDER = { "VIP", "ExtraMount", "Incubators", "PenSlots", "Lucky" }
local PRODUCT_ORDER = { "InstantHatch", "LuckPotion", "ServerLuck" }]=], [=[
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, storeList)

-- Hatch odds, shown before any purchase (paid random item disclosure)
local ODDS_COLUMNS = { { "Normal", false, false }, { "Luck", true, false }, { "Lucky pass", false, true }, { "Both", true, true } }
local oddsBox = new("Frame", { LayoutOrder = -1, Size = UDim2.new(1, -12, 0, 6 * 26 + 44), BackgroundTransparency = 1 }, storeList)
text({ Size = UDim2.new(1, 0, 0, 26), Text = "Hatch Odds (normal eggs)", TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = rgb(140, 255, 170) }, oddsBox)
local function oddsCell(row, col, label, color)
	text({ Position = UDim2.new(col / 5, 0, 0, 28 + row * 26), Size = UDim2.new(1 / 5, -4, 0, 24), Text = label,
		TextColor3 = color or WHITE }, oddsBox)
end
oddsCell(0, 0, "Rarity", rgb(190, 200, 220))
for c, column in ODDS_COLUMNS do
	oddsCell(0, c, column[1], rgb(190, 200, 220))
	local odds = Config.hatchOdds(column[2], column[3])
	for r = 1, 5 do
		oddsCell(r, c, ("%.2f%%"):format(odds[r] * 100))
	end
end
for r = 1, 5 do
	oddsCell(r, 0, Config.Rarities[r].id, Config.Rarities[r].color)
end
local secret = Config.Events.secretOdds
text({ Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = rgb(190, 200, 220), Text = ("Secret Egg: Epic %d%%, Legendary %d%%, Mythic %d%%. Luck: day-7 reward, Luck Potion, Server Luck.")
	:format(secret[4], secret[5], secret[6]) }, oddsBox)

local PAID_LUCK = { Lucky = true, LuckPotion = true, ServerLuck = true }
local luckButtons = {}
local PASS_ORDER = { "VIP", "ExtraMount", "Incubators", "PenSlots", "Lucky" }
local PRODUCT_ORDER = { "InstantHatch", "LuckPotion", "ServerLuck" }]=])
rep(game.StarterGui.MainUI.RetentionUI, [=[
			return localToast("Coming soon!")
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.id)]=], [=[
			return localToast("Coming soon!")
		end
		if PAID_LUCK[key] and player:GetAttribute("PaidLuckBlocked") ~= false then
			return localToast("Not available in your region")
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.id)]=])
rep(game.StarterGui.MainUI.RetentionUI, [=[
	if isPass then
		passButtons[key] = buy
	end
end]=], [=[
	if isPass then
		passButtons[key] = buy
	end
	if PAID_LUCK[key] then
		luckButtons[key] = buy
	end
end]=])
rep(game.StarterGui.MainUI.RetentionUI, [=[
		b.Active = not owned
	end
	local now = os.time()
	local mine = math.max(0, (player:GetAttribute("LuckUntil") or 0) - now)]=], [=[
		b.Active = not owned
	end
	local blocked = player:GetAttribute("PaidLuckBlocked") ~= false
	for key, b in luckButtons do
		if blocked and not (passButtons[key] and player:GetAttribute(key .. "Pass")) then
			b.Text = "Not available"
			b.BackgroundColor3 = rgb(110, 115, 140)
			b.Active = false
		end
	end
	local now = os.time()
	local mine = math.max(0, (player:GetAttribute("LuckUntil") or 0) - now)]=])
rep(game.StarterGui.MainUI.RetentionUI, [=[
	local now = os.time()
	local mine = math.max(0, (player:GetAttribute("LuckUntil") or 0) - now)
	local server = math.max(0, (workspace:GetAttribute("ServerLuckUntil") or 0) - now)
	local left = math.max(mine, server)
	luckLabel.Text = left > 0 and ("Luck active: %d:%02d"):format(left // 60, left % 60) or ""
end]=], [=[
	local now = os.time()
	local mine = math.max(0, (player:GetAttribute("LuckUntil") or 0) - now)
	local paid = if blocked then 0 else math.max(0, (player:GetAttribute("PaidLuckUntil") or 0) - now,
		(workspace:GetAttribute("ServerLuckUntil") or 0) - now)
	local left = math.max(mine, paid)
	luckLabel.Text = left > 0 and ("Luck active: %d:%02d"):format(left // 60, left % 60) or ""
end]=])
local pending = {}
for _, j in ipairs(jobs) do
	local s = pending[j[1]] or j[1].Source
	local a, b = string.find(s, j[2], 1, true)
	assert(a, "anchor not found in " .. j[1]:GetFullName() .. ": " .. j[2]:sub(1, 60))
	assert(not string.find(s, j[2], b + 1, true), "anchor not unique in " .. j[1]:GetFullName())
	pending[j[1]] = s:sub(1, a - 1) .. j[3] .. s:sub(b + 1)
end
for inst, s in pairs(pending) do inst.Source = s end
print("ODDS_FIX_OK", #jobs, "edits")