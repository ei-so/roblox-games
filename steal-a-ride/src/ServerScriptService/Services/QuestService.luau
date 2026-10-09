-- Persistent daily/weekly assignments; only successful server actions advance progress.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)
local Remotes = ReplicatedStorage.Remotes
local QuestService = {}

local function assign(player, period, stamp)
	local pool = table.clone(Config.Quests[period])
	local random = Random.new((player.UserId + stamp * 97 + (period == "weekly" and 65537 or 0)) % 2147483647)
	for i = #pool, 2, -1 do local j = random:NextInteger(1, i); pool[i], pool[j] = pool[j], pool[i] end
	local goals, income = {}, CreatureService.incomeOf(player)
	for i = 1, 3 do
		local spec = pool[i]
		goals[i] = { id = spec.id, target = spec.target or math.max(spec.min, math.floor(income * spec.seconds)), progress = 0, claimed = false }
	end
	return goals
end

local function current(player)
	local data = DataService.get(player)
	if not data or player:GetAttribute("DataLoadFailed") then return nil end
	data.Quests = data.Quests or {}
	local q, day = data.Quests, os.time() // 86400
	local week = (day - 4) // 7 -- Unix day zero was Thursday; the first Monday was day 4.
	if q.day ~= day then q.day, q.daily = day, assign(player, "daily", day) end
	if q.week ~= week then q.week, q.weekly, q.weeklyBonus = week, assign(player, "weekly", week), false end
	return q
end

local function reward(player, period)
	local spec = Config.Quests
	return math.max(spec[period .. "Min"], math.floor(CreatureService.incomeOf(player) * spec[period .. "Seconds"]))
end

function QuestService.sync(player)
	local q = current(player)
	if q then
		player:SetAttribute("Quests", HttpService:JSONEncode({ day = q.day, week = q.week, daily = q.daily, weekly = q.weekly,
			weeklyBonus = q.weeklyBonus, dailyReward = reward(player, "daily"), weeklyReward = reward(player, "weekly") }))
	end
end

function QuestService.track(player, event, amount)
	amount = amount or 1
	if type(amount) ~= "number" or amount <= 0 or amount ~= amount or amount == math.huge then return end
	local q = current(player)
	if not q then return end
	local changed = false
	for _, period in { "daily", "weekly" } do
		for _, goal in q[period] do
			if not goal.claimed and goal.progress < goal.target and Config.Quests.byId[goal.id].event == event then
				goal.progress = math.min(goal.target, goal.progress + amount)
				changed = true
				if goal.progress >= goal.target then Remotes.Notify:FireClient(player, "toast", "Quest complete! Claim your reward in Quests.") end
			end
		end
	end
	if changed then QuestService.sync(player) end
end

function QuestService.claim(player, period, index, stamp): boolean
	if period ~= "daily" and period ~= "weekly" then return false end
	if type(index) ~= "number" or index ~= index or index % 1 ~= 0 or index < 1 or index > 3 then return false end
	local q = current(player)
	if not q or stamp ~= q[period == "daily" and "day" or "week"] then QuestService.sync(player); return false end
	local goal = q[period][index]
	if goal.claimed or goal.progress < goal.target then return false end
	goal.claimed = true -- mark before cash is granted so repeat requests cannot pay again
	local cash = reward(player, period)
	DataService.addCash(player, cash, true) -- quest rewards do not advance earn-cash goals
	Remotes.Notify:FireClient(player, "toast", ("Quest reward: +$%d!"):format(cash))
	if period == "weekly" and not q.weeklyBonus and q.weekly[1].claimed and q.weekly[2].claimed and q.weekly[3].claimed then
		q.weeklyBonus = true
		local data = DataService.get(player)
		data.LuckUntil = math.max(data.LuckUntil or 0, os.time()) + 900
		player:SetAttribute("LuckUntil", data.LuckUntil)
		Remotes.Notify:FireClient(player, "toast", "All weekly quests claimed! Luck Potion: +15 minutes!")
	end
	QuestService.sync(player)
	return true
end

function QuestService.start()
	Remotes.ClaimQuest.OnServerEvent:Connect(QuestService.claim)
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do QuestService.sync(player) end
		end
	end)
end

return QuestService
