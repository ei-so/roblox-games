local res = {}
local function apply(inst, list) local s = inst.Source
 for i, r in list do local a = string.find(s, r[1], 1, true); if a and not string.find(s, r[1], a + 1, true) then s = string.sub(s, 1, a-1) .. r[2] .. string.sub(s, a + #r[1]) else table.insert(res, inst.Name .. ' FAIL hunk ' .. i) return end end
 inst.Source = s; table.insert(res, inst.Name .. ' ' .. #s) end
apply(game.ReplicatedStorage.Shared.Config, {{[=====[
mamaClickCap = 8, mamaRewardMinDamage = 10, luckyHatch = 30,]=====], [=====[
mamaClickCap = 8, luckyHatch = 30,]=====]},
{[=====[
	mamaCashHits = 75, mamaCashTime = 300, -- 75 hits = 2x cash for 5 min; defeat = 1 Lucky Egg (mamaRewardMinDamage hits)
]=====], [=====[
	mamaCashHits = 75, mamaCashTime = 300, -- 75 hits = 2x cash for 5 min (online income only, not offline)
	mamaEggHits = 100, -- 100 hits = 1 Lucky Egg (a solo kill is exactly 100)
]=====]}})
apply(game.ServerScriptService.Services.MamaService, {{[=====[
-- go home plus one Lucky Egg per contributor; let her escape and her hoard is lost. Hitting her 50 / 75 times
-- grants 1.25x speed / 2x cash right away, win or lose.]=====], [=====[
-- go home; let her escape and her hoard is lost. Hitting her 50 / 75 / 100 times grants 1.25x speed / 2x cash /
-- a Lucky Egg right away, win or lose.]=====]},
{[=====[
		Notify:FireClient(player, "toast", ("%d hits! 2x cash for %d min"):format(E.mamaCashHits, E.mamaCashTime // 60))
	end
end]=====], [=====[
		Notify:FireClient(player, "toast", ("%d hits! 2x cash for %d min"):format(E.mamaCashHits, E.mamaCashTime // 60))
	end
	if before < E.mamaEggHits and after >= E.mamaEggHits then
		local best = player:GetAttribute("BestBiome") or 0
		HatchService.give(player, { biome = Config.Biomes[math.max(1, best)].id, lucky = true })
		Notify:FireClient(player, "toast", ("%d hits! You got a Lucky Egg!"):format(E.mamaEggHits))
	end
end]=====]},
{[=====[
		for _, row in topList(fight) do
			if row.dmg >= E.mamaRewardMinDamage then
				local best = row.player:GetAttribute("BestBiome") or 0
				HatchService.give(row.player, { biome = Config.Biomes[math.max(1, best)].id, lucky = true })
				Notify:FireClient(row.player, "toast", "You got a Lucky Egg!")
			end
		end
]=====], [=====[
]=====]}})
apply(game.ServerScriptService.Services.CreatureService, {{[=====[
					local boost = (player:GetAttribute("CashBoostUntil") or 0) > os.time() and 2 or 1 -- Mama 75-hit reward
					DataService.addCash(player, CreatureService.incomeOf(player) * boost)]=====], [=====[
					local boost = (player:GetAttribute("CashBoostUntil") or 0) > os.time() and 2 or 1 -- Mama 75-hit reward
					local perSecond = CreatureService.incomeOf(player) * boost
					player:SetAttribute("CashPerSecond", perSecond) -- HUD shows the doubled rate while boosted
					DataService.addCash(player, perSecond)]=====]}})
apply(game.StarterGui.MainUI.RetentionUI, {{[=====[
			local reward = damage < E.mamaRewardMinDamage and ("%d more hits for a Lucky Egg"):format(E.mamaRewardMinDamage - damage)
				or damage < E.mamaSpeedHits and ("%d to 1.25x speed"):format(E.mamaSpeedHits - damage)
				or damage < E.mamaCashHits and ("%d to 2x cash"):format(E.mamaCashHits - damage)
				or "Lucky Egg if defeated"]=====], [=====[
			local reward = damage < E.mamaSpeedHits and ("%d to 1.25x speed"):format(E.mamaSpeedHits - damage)
				or damage < E.mamaCashHits and ("%d to 2x cash"):format(E.mamaCashHits - damage)
				or damage < E.mamaEggHits and ("%d to a Lucky Egg"):format(E.mamaEggHits - damage)
				or "All rewards earned"]=====]}})
return table.concat(res, ' | ')