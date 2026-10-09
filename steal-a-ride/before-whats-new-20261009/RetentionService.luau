-- Daily login streak and the "while you were away" offline summary.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)
local HatchService = require(script.Parent.HatchService)

local Remotes = ReplicatedStorage.Remotes
local Notify = Remotes.Notify

local RetentionService = {}
local DAY = 24 * 3600

local TIP_KEYS = {} -- tutorial keys a client may mark as seen/done
for _, tip in Config.Tips do TIP_KEYS[tip.key] = true end
for _, key in Config.TutorialSteps do TIP_KEYS[key] = true end

local function dayNumber(t) return t // DAY end

-- which streak day the player can claim now (nil = already claimed today)
function RetentionService.claimableDay(data): number?
	local today, last = dayNumber(os.time()), dayNumber(data.LastDaily)
	if data.LastDaily > 0 and today == last then
		return nil
	end
	local continuing = data.LastDaily > 0 and today - last == 1
	return continuing and (data.DailyStreak % #Config.Daily) + 1 or 1
end

function RetentionService.sync(player)
	local data = DataService.get(player)
	if data then
		player:SetAttribute("DailyDay", RetentionService.claimableDay(data))
		player:SetAttribute("LuckUntil", data.LuckUntil)
		local tips = {}
		for key in data.Tips do table.insert(tips, key) end
		player:SetAttribute("Tips", table.concat(tips, ",")) -- "" = none yet; nil = not loaded
	end
end

function RetentionService.markTip(player, key)
	local data = DataService.get(player)
	if data and type(key) == "string" and TIP_KEYS[key] and not data.Tips[key] then
		data.Tips[key] = true
		RetentionService.sync(player)
	end
end

function RetentionService.claim(player)
	local data = DataService.get(player)
	local day = data and RetentionService.claimableDay(data)
	if not day then
		return
	end
	local reward = Config.Daily[day]
	data.DailyStreak = day
	data.LastDaily = os.time()
	if reward.luckMinutes then
		data.LuckUntil = math.max(data.LuckUntil, os.time()) + reward.luckMinutes * 60
		Notify:FireClient(player, "toast", ("Day %d: Luck Potion for %d minutes!"):format(day, reward.luckMinutes))
	else
		local cash = math.max(reward.min, reward.seconds * CreatureService.incomeOf(player))
		DataService.addCash(player, cash)
		Notify:FireClient(player, "toast", ("Day %d reward: +$%d"):format(day, math.floor(cash)))
	end
	RetentionService.sync(player)
end

-- call once on join, after the pen is set up
function RetentionService.onPlayerReady(player, lastOnline: number)
	if lastOnline > 0 then
		local away = math.min(os.time() - lastOnline, Config.Offline.capSeconds)
		local cash = math.floor(away * CreatureService.incomeOf(player) * Config.Offline.rate)
		local hatched = HatchService.readyCount(player)
		if away >= 60 and (cash > 0 or hatched > 0) then
			DataService.addCash(player, cash)
			-- an attribute, not a remote: it fires during join, before the client's UI scripts are listening
			player:SetAttribute("OfflineSummary", game:GetService("HttpService"):JSONEncode({ cash = cash, hatched = hatched, seconds = away }))
		end
	end
	RetentionService.sync(player)
end

function RetentionService.start()
	Remotes.ClaimDaily.OnServerEvent:Connect(RetentionService.claim)
	Remotes.TipSeen.OnServerEvent:Connect(RetentionService.markTip)
end

return RetentionService
