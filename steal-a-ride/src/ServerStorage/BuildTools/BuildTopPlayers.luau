-- Edit-time tool (not used at runtime): the Top Players board at the Plaza's centre back (wooden notice board, three
-- podium cards with ledges for the avatars, crown, lanterns), the same wooden frame on the three leaderboards, the
-- Index stall moved to the back-left corner, and the spawn pad hidden (the spawn itself stays).
--   require(game.ServerStorage.BuildTools.BuildTopPlayers)()
-- Rerunning rebuilds the board and re-applies the rest. TopPlayersService fills the cards and stands the figures.
local rgb = Color3.fromRGB
local FLOOR = 0.4 -- top of Plaza.Floor
local WOOD, DARKWOOD, PANEL, DARK = rgb(120, 78, 44), rgb(70, 45, 26), rgb(48, 32, 22), rgb(40, 40, 55)
local GOLD = rgb(255, 205, 80)
local X, Z = 0, 211 -- board centre; its front faces the arch (-Z)
local INDEX_X, INDEX_Z = -58, 198 -- Index stall's new base centre (clear of the decor pine at -72, 206)
-- podium: rank -> card centre x, width, height (bottoms aligned; #1 taller). Seen from the arch +X is on the left,
-- so #2 sits at +x and #3 at -x to read 2-1-3 left to right
local CARDS = { { x = 0, w = 9, h = 14.2 }, { x = 9.8, w = 8.6, h = 13 }, { x = -9.8, w = 8.6, h = 13 } }
local FRAMES = { { GOLD, Enum.Material.Neon }, { rgb(200, 205, 215), Enum.Material.Metal }, { rgb(196, 120, 70), Enum.Material.Metal } }
local CARD_BOTTOM = FLOOR + 3.4

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cframe, color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props or {} do p[k] = v end
	p.Parent = parent
	return p
end

local function plankText(target, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, 0
	gui.Parent = target
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.Font, t.TextScaled, t.TextColor3, t.Text = UDim2.fromScale(1, 1), 1, Enum.Font.FredokaOne, true, GOLD, text
	t.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = rgb(60, 35, 10), 3
	stroke.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0.12, 0), UDim.new(0.12, 0), UDim.new(0.04, 0), UDim.new(0.04, 0)
	pad.Parent = t
end

return function()
	local plaza = workspace.Plaza
	local old = plaza:FindFirstChild("TopPlayers")
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = "TopPlayers"
	m.Parent = plaza

	-- frame: back panel, posts, top beam, header plank, crown
	part(m, "Back", Vector3.new(30, 18, 0.8), CFrame.new(X, FLOOR + 2.5 + 9, Z), DARKWOOD, Enum.Material.Wood)
	for _, s in { -1, 1 } do
		part(m, "Post", Vector3.new(1.4, 22.6, 1.4), CFrame.new(X + s * 15.7, FLOOR + 11.3, Z), WOOD, Enum.Material.Wood)
	end
	part(m, "Beam", Vector3.new(36, 1.2, 1.6), CFrame.new(X, FLOOR + 22, Z), WOOD, Enum.Material.Wood)
	plankText(part(m, "Header", Vector3.new(20, 3.2, 0.6), CFrame.new(X, FLOOR + 19.8, Z - 0.7), WOOD, Enum.Material.Wood), "TOP PLAYERS")
	part(m, "CrownBase", Vector3.new(4, 0.8, 0.5), CFrame.new(X, FLOOR + 23, Z - 0.6), GOLD, Enum.Material.Neon)
	for i, dx in { -1.6, 0, 1.6 } do
		local h = i == 2 and 1.8 or 1.4
		part(m, "CrownSpike", Vector3.new(0.8, h, 0.5), CFrame.new(X + dx, FLOOR + 23.4 + h / 2, Z - 0.6), GOLD, Enum.Material.Neon)
	end
	-- lanterns hanging off the beam ends
	for _, s in { -1, 1 } do
		part(m, "Chain", Vector3.new(0.2, 1.5, 0.2), CFrame.new(X + s * 17.4, FLOOR + 20.65, Z), DARK, Enum.Material.Metal)
		local lantern = part(m, "Lantern", Vector3.new(1.3, 1.8, 1.3), CFrame.new(X + s * 17.4, FLOOR + 19, Z), rgb(255, 190, 110), Enum.Material.Neon,
			{ CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = 16, 1.5, rgb(255, 200, 130)
		light.Parent = lantern
	end
	-- podium cards (Card1 = #1 in the centre) with metal frames and a ledge for each figure
	for rank, c in CARDS do
		local y = CARD_BOTTOM + c.h / 2
		part(m, "Frame" .. rank, Vector3.new(c.w + 0.6, c.h + 0.6, 0.3), CFrame.new(c.x, y, Z - 0.5), FRAMES[rank][1], FRAMES[rank][2])
		part(m, "Card" .. rank, Vector3.new(c.w, c.h, 0.2), CFrame.new(c.x, y, Z - 0.75), PANEL)
		local ledgeTop = CARD_BOTTOM + c.h * 0.42
		part(m, "Ledge" .. rank, Vector3.new(4.2, 0.4, 2.2), CFrame.new(c.x, ledgeTop - 0.2, Z - 1.95), WOOD, Enum.Material.Wood) -- thin, so it never hides the name row
	end

	-- leaderboards: the same wood instead of the neon gold frame and dark posts, plus a cap plank
	for _, board in plaza.Leaderboards:GetChildren() do
		board.Frame.Color, board.Frame.Material = WOOD, Enum.Material.Wood
		for _, p in board:GetChildren() do
			if p.Name == "Post" then
				p.Color, p.Material = WOOD, Enum.Material.Wood
			elseif p.Name == "Cap" then
				p:Destroy()
			end
		end
		board.Screen.Color = PANEL
		local s = board.Screen
		part(board, "Cap", Vector3.new(18, 1, 1.4), CFrame.new(s.Position.X, s.Position.Y + s.Size.Y / 2 + 0.9, s.Position.Z + 0.2), WOOD, Enum.Material.Wood)
	end

	-- Index stall (counter, keeper, books, prompt) to the back-left corner, still facing the arch
	local index = plaza.IndexBoard
	local base = index.Base.Position
	index:PivotTo(index:GetPivot() + Vector3.new(INDEX_X - base.X, 0, INDEX_Z - base.Z))

	-- spawn: keeps working and facing the arch; only the yellow pad disappears
	local spawn = plaza.SpawnLocation
	spawn.Transparency = 1
	for _, d in spawn:GetDescendants() do
		if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
	end
	return "Top Players board built; leaderboards restyled; Index stall moved; spawn pad hidden"
end
