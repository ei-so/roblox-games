-- Run in Studio: require(game.ServerStorage.BuildTools.MovementChecks)()
return function()
	local sources = assert(game.ReplicatedStorage:FindFirstChild("CreatureMeshSources"), "Persistent original meshes are missing")
	assert(#sources:GetChildren() == 28, "Original species or guardian meshes are missing")
	for _, model in sources:GetChildren() do
		assert(model.PrimaryPart and model.PrimaryPart.MeshId ~= "", model.Name .. ": original mesh asset cannot survive a reload")
	end
	local shared = game.ReplicatedStorage.Shared:Clone()
	shared.Name = "MovementCheckModules"
	shared.Parent = game.ReplicatedStorage
	local ok, result = pcall(function()
		local Config = require(shared.Config)
		local Builder = require(shared.CreatureBuilder)
		local Motion = require(shared.WalkCycle)
		for _, gait in { "quad", "biped", "hop", "heavy", "waddle", "float", "fly" } do
			assert(typeof(Motion.offset(.5, 1, 4, gait)) == "CFrame", gait .. ": invalid body pose")
		end
		assert(Config.Species.Parrot.canFly and Config.Species.BabyDragon.canFly, "Birds and dragons need rideable flight")
		assert(not Config.Species.Penguin.canFly and not Config.Species.Chick.canFly, "Flightless birds must stay grounded")
		assert(Motion.gaitOf("Bunny") == "hop", "Bunny should hop")
		assert(Motion.gaitOf("Penguin") == "waddle", "Penguin should waddle")
		local n = 0
		for name, spec in Config.Species do
			for _, rarity in { "Common", "Mythic" } do
				local model = Builder.build(name, rarity)
				local joints = Motion.bind(model)
				local legs, wings, movingParts = 0, 0, {}
				for _, j in joints do
					assert(j.motor.Part0 and j.motor.Part1, name .. ": detached joint")
					movingParts[j.motor.Part1] = true
					if j.kind == "Leg" then legs += 1 elseif j.kind == "Wing" then wings += 1 end
				end
				assert(legs == (spec.legs or 4), name .. ": incorrect animated leg count")
				assert(not spec.canFly or wings == 2, name .. ": flying creature needs two animated wings")
				for _, d in model:GetDescendants() do
					assert(not (d:IsA("WeldConstraint") and movingParts[d.Part1]), name .. ": limb was welded rigidly")
				end
				Motion.animateJoints(joints, .5, 1, 1, Motion.gaitOf(name), false)
				local changed = false
				for _, j in joints do if j.motor.C0 ~= j.base then changed = true end end
				assert(changed, name .. ": motion did not animate any limbs")
				Motion.animateJoints(joints, 0, 0, 0, Motion.gaitOf(name), false)
				model:Destroy()
				n += 1
			end
		end
		for _, biome in Config.Biomes do
			local model = Builder.buildGuardian(biome.id)
			assert(#Motion.bind(model) >= 2, biome.id .. ": guardian needs animated limbs")
			model:Destroy()
		end
		assert(Motion.flightVelocity(Vector3.new(2,0,0), 30, 1).X <= 30.01, "Flight diagonal speed must be bounded")
		assert(Motion.flightVelocity(Vector3.zero, 0, 1) == Vector3.zero, "Stunned riders must not fly")
		assert(Motion.flightVelocity(Vector3.zero, 30, 100).Y == Config.Flight.verticalSpeed, "Vertical input must be clamped")
		return "PASS: " .. n .. " species/rarity rigs, 7 guardian rigs, gaits, flight classification and speed limits"
	end)
	shared:Destroy()
	assert(ok, result)
	return result
end