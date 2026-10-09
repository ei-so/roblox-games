-- Places ability/flight touch buttons beside Roblox's jump button, which is 70 px on phones but 120 px (and higher up)
-- on tablets, so fixed offsets cover it there. Dash sits just left of the jump button; the flight row (+ Get off at its left end) sits just above it.
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local TouchButtons = {}
local GAP = 10

-- Top-left corner (screen pixels) for a button of `size` px, from the jump button's top-left `jumpPos` and `jumpSize`
function TouchButtons.slot(name: string, jumpPos: Vector2, jumpSize: Vector2, size: number): Vector2?
	local step = size + GAP
	if name == "Dash" then
		return Vector2.new(jumpPos.X - step, jumpPos.Y + (jumpSize.Y - size) / 2)
	end
	local column = ({ RideDown = 0, RideUp = 1, RideFlight = 2, GetOff = 3 })[name]
	return column and Vector2.new(jumpPos.X + jumpSize.X - size - column * step, jumpPos.Y - step)
end

-- Reposition a bound action's touch button (Roblox creates it asynchronously, so call after a short delay)
function TouchButtons.place(name: string)
	local button = ContextActionService:GetButton(name)
	local touchGui = Players.LocalPlayer.PlayerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if not button or not button.Parent or not jump or jump.AbsoluteSize.X <= 0 then
		return false
	end
	local at = TouchButtons.slot(name, jump.AbsolutePosition, jump.AbsoluteSize, button.AbsoluteSize.X)
	if not at then
		return false
	end
	local screen = button:FindFirstAncestorOfClass("ScreenGui")
	if screen then screen.DisplayOrder = -1 end -- under open panels (Stable, Shop...), not over them
	local frame = button.Parent.AbsolutePosition
	ContextActionService:SetPosition(name, UDim2.fromOffset(at.X - frame.X, at.Y - frame.Y))
	return true
end

-- Re-place every listed button after the screen (and so the jump button) changes size
function TouchButtons.follow(names: { string })
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.delay(0.2, function()
			for _, name in names do TouchButtons.place(name) end
		end)
	end)
end

return TouchButtons
