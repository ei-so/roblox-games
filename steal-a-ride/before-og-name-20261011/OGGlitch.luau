-- OG overhead tags (built by Main): every 1.5-3 s each one glitches briefly — red/cyan ghosts split apart
-- and the letters corrupt, then snap back. Client-only; tags out of view range are skipped.
local CORRUPT = { "0G", "O#", "▓G", "QG", "O▒", "Ø6" }

local tags = {} -- [BillboardGui] = next glitch os.clock()

local function track(gui)
	if gui.Name == "OGTag" and gui:IsA("BillboardGui") then -- its labels may replicate after it; glitch() checks
		tags[gui] = os.clock() + math.random() * 3
	end
end

local function glitch(gui)
	local red, cyan, main = gui:FindFirstChild("Red"), gui:FindFirstChild("Cyan"), gui:FindFirstChild("Main")
	if not (red and cyan and main) then
		return
	end
	for _ = 1, 3 do
		local dx, dy = math.random(2, 5), math.random(-2, 2)
		red.Position = UDim2.fromOffset(-dx, dy)
		cyan.Position = UDim2.fromOffset(dx, -dy)
		main.Text = math.random() < 0.6 and CORRUPT[math.random(#CORRUPT)] or "OG"
		task.wait(0.06)
	end
	red.Position, cyan.Position = UDim2.new(), UDim2.new()
	main.Text = "OG"
end

for _, d in workspace:GetDescendants() do
	track(d)
end
workspace.DescendantAdded:Connect(function(d)
	track(d)
end)

while true do
	task.wait(0.1)
	local now = os.clock()
	local camera = workspace.CurrentCamera
	for gui, nextAt in tags do
		local head = gui.Parent
		if not head or not head:IsDescendantOf(workspace) then
			tags[gui] = nil
		elseif now >= nextAt then
			tags[gui] = now + 1.5 + math.random() * 1.5
			if camera and head:IsA("BasePart") and (head.Position - camera.CFrame.Position).Magnitude <= gui.MaxDistance then
				task.spawn(glitch, gui)
			end
		end
	end
end
