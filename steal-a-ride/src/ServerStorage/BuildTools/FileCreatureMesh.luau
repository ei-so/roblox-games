-- Edit-time tool: turns a generated mesh (found by its Assistant tag) into a CreatureBuilder template in
-- ReplicatedStorage.CreatureMeshes: Model <name> > MeshPart "Body" (PrimaryPart), pivot at the center.
--   require(clone)({ { "Fox", "<tag guid>", seatFrac?, matchLengthZ? }, ... })
-- matchLengthZ (guardians): scale so body length equals the primitive's, keeping catch distances unchanged.
local CS = game:GetService("CollectionService")

return function(items)
	local root = game.ReplicatedStorage:FindFirstChild("CreatureMeshes") or Instance.new("Folder")
	root.Name = "CreatureMeshes"
	root.Parent = game.ReplicatedStorage
	local out = {}
	for _, it in items do
		local name, tag, seatFrac, matchZ = it[1], it[2], it[3], it[4]
		local source
		for _, inst in CS:GetTagged("Assistant-" .. tag) do
			if inst:IsA("Model") and inst.Parent == workspace then
				source = inst
			end
		end
		local mesh = source and source:FindFirstChildWhichIsA("MeshPart", true)
		if not mesh then
			table.insert(out, name .. ": not found")
			continue
		end
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = name
		mesh.Name = "Body"
		mesh.Anchored, mesh.CanCollide, mesh.CanTouch, mesh.CanQuery = true, false, false, false
		mesh.CFrame = CFrame.new(mesh.Position - mesh.Position) * mesh.CFrame.Rotation
		mesh.Parent = model
		model.PrimaryPart = mesh
		if seatFrac then
			model:SetAttribute("SeatFrac", seatFrac)
		end
		if matchZ then
			local _, size = model:GetBoundingBox()
			model:ScaleTo(matchZ / size.Z)
		end
		model.Parent = root
		source:Destroy()
		local _, size = model:GetBoundingBox()
		table.insert(out, ("%s %.1f x %.1f x %.1f"):format(name, size.X, size.Y, size.Z))
	end
	return table.concat(out, ", ")
end
