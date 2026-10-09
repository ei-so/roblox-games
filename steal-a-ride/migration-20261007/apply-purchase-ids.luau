-- Run in the destination Studio Command Bar. Original backup is preserved.
assert(game.GameId == 10769659624 and game.PlaceId == 123937616497204 and game.CreatorId == 7908166657, "Wrong destination game")
local replacements = {
    ["2005773845"] = "2009138282", ["2006763831"] = "2006037890",
    ["2007609755"] = "2008886448", ["2005335814"] = "2006001857",
    ["2005827919"] = "2008862492", ["3716909972"] = "3716940270",
    ["3716910052"] = "3716940345", ["3716910127"] = "3716940466",
}
local config = game.ReplicatedStorage.Shared.Config
local editor = game:GetService("ScriptEditorService")
editor:UpdateSourceAsync(config, function(source)
    for old, new in replacements do
        local count
        source, count = source:gsub(old, new)
        assert(count == 1 or (count == 0 and source:find(new, 1, true)), "Missing or duplicate purchase ID: " .. old)
    end
    return source
end)
local source = editor:GetEditorSource(config)
for old, new in replacements do
    assert(not source:find(old, 1, true) and source:find(new, 1, true), "Purchase ID verification failed")
end
print("MIGRATION_PURCHASE_IDS_OK", game.PlaceId, game.GameId)
