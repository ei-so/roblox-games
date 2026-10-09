-- Gives each player one of the Home Row plots, labels its sign, and spawns them there.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local PlotService = {}

local plots = workspace:WaitForChild("HomeRow"):WaitForChild("Plots")

local function setSign(plot, text)
	for _, label in plot.Sign.Board:GetDescendants() do
		if label:IsA("TextLabel") then
			label.Text = text
		end
	end
end

function PlotService.assign(player)
	for i = 1, Config.Plot.count do
		local plot = plots:FindFirstChild("Plot" .. i)
		if plot and plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("Plot", plot.Name)
			setSign(plot, player.DisplayName .. "'s Base")
			return plot
		end
	end
	warn("[PlotService] No free plot for " .. player.Name .. ". Set Max Players to 8 in Game Settings > Places.")
	return nil
end

function PlotService.get(player)
	local name = player:GetAttribute("Plot")
	return name and plots:FindFirstChild(name)
end

function PlotService.release(player)
	local plot = PlotService.get(player)
	if plot and plot:GetAttribute("OwnerUserId") == player.UserId then
		plot:SetAttribute("OwnerUserId", 0)
		setSign(plot, "Empty Plot")
	end
	player:SetAttribute("Plot", nil)
end

-- An occupied Seat is welded into the character assembly, even when anchored.
-- Release it before moving the character so the furniture stays in its plot.
function PlotService.teleport(character, cframe)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and (humanoid.Sit or humanoid.SeatPart) then
		local seat = humanoid.SeatPart
		local weld = seat and seat:FindFirstChild("SeatWeld")
		if weld and weld.Part1 and weld.Part1:IsDescendantOf(character) then
			weld:Destroy()
		end
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		task.wait() -- let the detached seat assembly settle before moving the character
	end
	character:PivotTo(cframe)
end

function PlotService.spawn(player, character)
	local plot = PlotService.get(player)
	if not plot then
		return
	end
	character:WaitForChild("HumanoidRootPart")
	task.defer(function() -- after the default SpawnLocation placement
		PlotService.teleport(character, plot.Spawn.CFrame + Vector3.new(0, 3, 0))
	end)
end

return PlotService
