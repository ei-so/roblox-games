-- Run through execute_luau in Studio's Client datamodel with Stable open.
local gui = game.Players.LocalPlayer.PlayerGui.MainUI
local panel = gui.StablePanel
assert(panel.Visible, "open Stable before checking its typography")
local categories = 0
local tabSize
local shortSide = math.min(gui.AbsoluteSize.X, gui.AbsoluteSize.Y)
local touch = game:GetService("UserInputService").TouchEnabled
for _, tab in panel.RarityCategories:GetChildren() do
	if tab:IsA("TextButton") then
		assert(not tab.TextScaled, "rarity labels/counts must not autosize independently")
		assert(not tabSize or tab.TextSize == tabSize, "all rarity labels/counts share one size")
		tabSize = tab.TextSize
		assert(not tab.TextWrapped, "rarity counts stay on the label's line")
		assert(tab.TextBounds.X <= tab.AbsoluteSize.X, "rarity tab text fits: " .. tab.Name)
		categories += 1
	end
end
assert(categories == 7, "all rarity filters remain available")
if touch and shortSide < 500 then
	assert(tabSize <= 16 and panel.Title.TextSize <= 27, "phone typography stays restrained")
elseif touch then
	assert(tabSize <= 17 and panel.Title.TextSize <= 29, "tablet typography stays restrained")
else
	assert(tabSize == 18, "desktop preserves its established font sizes")
end
local sizes, count = {}, 0
for _, t in panel.List:GetDescendants() do
	local role = t:GetAttribute("TextRole")
	if role then
		assert(not t.TextScaled, "card copy must not autosize independently")
		if touch and shortSide < 500 then
			assert(role ~= "Name" or t.TextSize <= 18, "phone creature names use the responsive size")
			assert(role ~= "Action" or t.TextSize <= 12, "phone card actions use the responsive size")
		end
		assert(not sizes[role] or sizes[role] == t.TextSize, "matching card roles share one size: " .. role)
		assert(t.TextBounds.X <= t.AbsoluteSize.X + 1 and t.TextBounds.Y <= t.AbsoluteSize.Y + 1, "card text fits: " .. t:GetFullName())
		sizes[role] = t.TextSize
		count += 1
	end
end
if panel:GetAttribute("CompactCards") then
	for _, card in panel.List:GetChildren() do
		if card:IsA("Frame") then
			local stats, ability, actions = card.Stats, card.Ability, card:FindFirstChildOfClass("Frame")
			assert(stats.AbsolutePosition.Y + stats.AbsoluteSize.Y <= ability.AbsolutePosition.Y + 1, "compact stats and ability do not overlap")
			assert(ability.AbsolutePosition.Y + ability.AbsoluteSize.Y <= actions.AbsolutePosition.Y + 1, "compact ability clears actions")
			assert(ability.TextSize >= 10, "small metadata stays readable")
		end
	end
end
return { categories = categories, tabSize = tabSize, titleSize = panel.Title.TextSize, cardLabels = count, sizes = sizes, viewport = tostring(gui.AbsoluteSize), compact = panel:GetAttribute("CompactCards") }
