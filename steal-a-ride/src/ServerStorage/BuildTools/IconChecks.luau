-- Run in Studio: require(game.ServerStorage.BuildTools.IconChecks)()
return function()
	local module = game.ReplicatedStorage.Shared.Config:Clone()
	local Config = require(module)
	module:Destroy()
	local function check(category, id)
		local value = Config.Icons and Config.Icons[category] and Config.Icons[category][id]
		assert(type(value) == "string" and value:match("^rbxassetid://[1-9]%d*$"), category .. "." .. id .. ": missing uploaded image")
	end
	for id, spec in Config.Gear do if type(spec) == "table" then check("Gear", id) end end
	for _, species in Config.Species do if species.ability then check("Abilities", species.ability) end end
	for _, rarity in Config.Rarities do check("Rarities", rarity.id) end
	return "PASS: all hotbar, Shop, ability and rarity icon references point to uploaded images"
end