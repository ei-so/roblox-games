-- Edit-time tool (not used at runtime): moves each Home Row plot's incubators into a row near the entrance,
-- shifts the Pen 8 studs deeper to make room, and lifts the incubator timers above the egg so they can be read.
--   require(game.ServerStorage.BuildTools.BuildBases)()
-- Safe to rerun: plots already laid out (attribute BaseLayout = 2) are not moved again.
-- Enclosure: the gate is the only way in. A low force-field fence sits on every wall and invisible walls rise to
-- y = 150, well above the flight ceiling (takeoff ground + rider + Config.Flight.maxHeight, about 55 from flat ground).
-- The gate sign is raised 4 studs so the tallest rider (Mythic BabyDragon, head about 9.1) fits under it.
local FENCE_TOP, WALL_TOP, SIGN_RAISE = 12, 150, 4

local function slab(parent, name, footprint: BasePart, bottom: number, top: number, visible: boolean)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = name, true, true, false, false, false
	p.Size = Vector3.new(footprint.Size.X, top - bottom, footprint.Size.Z)
	p.Position = Vector3.new(footprint.Position.X, (bottom + top) / 2, footprint.Position.Z)
	p.Material, p.Color = Enum.Material.ForceField, Color3.fromRGB(200, 230, 255)
	p.Transparency = visible and 0.3 or 1 -- 0.3+: the camera never zooms in on it
	p.Parent = parent
end

local function enclose(plot)
	local board = plot.Sign.Board
	board.Position += Vector3.new(0, SIGN_RAISE, 0)
	for _, post in plot.Sign:GetChildren() do
		if post.Name == "Post" then
			post.Size += Vector3.new(0, SIGN_RAISE, 0)
			post.Position += Vector3.new(0, SIGN_RAISE / 2, 0)
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Enclosure"
	for _, wall in plot:GetChildren() do
		if wall.Name == "Wall" then
			local top = wall.Position.Y + wall.Size.Y / 2
			slab(folder, "Fence", wall, top, FENCE_TOP, true)
			slab(folder, "Invisible", wall, FENCE_TOP, WALL_TOP, false)
		end
	end
	slab(folder, "Invisible", board, board.Position.Y + board.Size.Y / 2, WALL_TOP, false) -- over the gate
	folder.Parent = plot
end

return function()
	for _, plot in workspace.HomeRow.Plots:GetChildren() do
		local inward = Vector3.new(plot:GetAttribute("Side"), 0, 0)
		local move = plot:GetAttribute("BaseLayout") ~= 2
		if move then
			for _, pad in plot.Pen:GetChildren() do
				pad.Position += inward * 8 -- 16..40 -> 24..48 studs in from the entrance
			end
			plot:SetAttribute("BaseLayout", 2)
		end
		for _, pad in plot.Incubators:GetChildren() do
			if move then
				pad.Position -= inward * 40 -- back wall (52) -> just past the spawn (12)
				pad.Ring.Position -= inward * 40
			end
			local timer = pad.Timer -- above the egg and its glass pod; sized in studs (pads are 9 apart) so a row never piles up on phones
			timer.Size, timer.StudsOffset = UDim2.fromScale(5, 1.6), Vector3.new(0, 6, 0)
			timer.Text.TextStrokeTransparency, timer.Text.TextStrokeColor3 = 0, Color3.fromRGB(25, 30, 40)
		end
		if not plot:FindFirstChild("Enclosure") then
			enclose(plot)
		end
	end
end
