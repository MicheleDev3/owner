--[[
	PetFollow
	Runs on every client and animates every equipped pet/egg in
	Workspace.PlayerPets so it follows its owner the way Adopt Me pets do:

	  * walks to a spot behind and to the right of its owner
	  * stays on the ground (raycast), even when the owner jumps
	  * turns to face where it walks, and faces your direction when idle
	  * pets trot with a small bounce; eggs hop and waddle side to side
	  * teleports back if it falls too far behind

	Movement is done locally every frame, so it is smooth for everyone and
	costs the server nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetConfig"))
local Follow = PetConfig.Follow

local petsFolder = workspace:WaitForChild("PlayerPets")

local states = setmetatable({}, { __mode = "k" })

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local function yawFromVector(dir)
	return math.atan2(-dir.X, -dir.Z)
end

local function lerpAngle(a, b, t)
	local diff = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + diff * t
end

local function feetY(root, humanoid)
	local y = root.Position.Y - root.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return y - humanoid.HipHeight
	end
	return y - 2
end

local function groundAt(x, z, fromY, fallbackY)
	local result = workspace:Raycast(Vector3.new(x, fromY + 4, z), Vector3.new(0, -60, 0), rayParams)
	return result and result.Position.Y or fallbackY
end

local function updateFilter()
	local ignore = { petsFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
end

local function getState(model)
	local state = states[model]
	if not state then
		local pivot = model:GetPivot()
		state = {
			pos = pivot.Position,
			yaw = yawFromVector(pivot.LookVector),
			phase = 0,
			moveBlend = 0,
			idleTime = 0,
			sitBlend = 0,
			clock = math.random() * 10,
		}
		states[model] = state
	end
	return state
end

local function updatePet(model, slot, root, humanoid, dt)
	local state = getState(model)
	local isEgg = model:GetAttribute("Kind") == "Egg"
	local style = isEgg and Follow.Egg or Follow.Pet

	-- Where the pet wants to stand (only the owner's yaw matters, not tilt).
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 1e-3 then
		flatLook = Vector3.new(0, 0, -1)
	end
	local ownerYaw = yawFromVector(flatLook)
	local offset = Follow.Offsets[slot] or Follow.Offsets[#Follow.Offsets] + Vector3.new(0, 0, 3 * (slot - #Follow.Offsets))
	local target = (CFrame.new(root.Position) * CFrame.Angles(0, ownerYaw, 0) * CFrame.new(offset)).Position

	local ownerFeet = feetY(root, humanoid)
	local flatPos = Vector3.new(state.pos.X, 0, state.pos.Z)
	local flatTarget = Vector3.new(target.X, 0, target.Z)
	local toTarget = flatTarget - flatPos
	local dist = toTarget.Magnitude

	-- Too far away (respawned, teleported, fell behind): snap to the owner.
	if dist > Follow.TeleportDistance or math.abs(state.pos.Y - ownerFeet) > Follow.TeleportDistance then
		state.pos = Vector3.new(target.X, groundAt(target.X, target.Z, root.Position.Y, ownerFeet), target.Z)
		state.yaw = ownerYaw
		flatPos = flatTarget
		dist = 0
	end

	local speed = 0
	if dist > Follow.StopDistance then
		local maxSpeed = math.max(humanoid.WalkSpeed * 1.5, Follow.MinMaxSpeed)
		speed = math.min(dist * Follow.CatchUpFactor, maxSpeed)
		local step = math.min(speed * dt, dist)
		local dir = toTarget / dist
		flatPos += dir * step
		state.yaw = lerpAngle(state.yaw, yawFromVector(dir), math.min(1, dt * Follow.TurnSpeed))
	else
		-- Standing still: face the same way as the owner.
		state.yaw = lerpAngle(state.yaw, ownerYaw, math.min(1, dt * Follow.TurnSpeed * 0.5))
	end

	-- Stay glued to the ground under the pet.
	local groundY = groundAt(flatPos.X, flatPos.Z, math.max(root.Position.Y, state.pos.Y), ownerFeet)
	local y = state.pos.Y + (groundY - state.pos.Y) * math.min(1, dt * 15)
	state.pos = Vector3.new(flatPos.X, y, flatPos.Z)

	-- Walk / hop animation.
	local moving = speed > 0.5 and 1 or 0
	state.moveBlend += (moving - state.moveBlend) * math.min(1, dt * 8)
	state.phase += speed * dt * style.HopFrequency
	state.clock += dt

	-- Pets sit down after standing around for a bit (eggs never sit).
	if speed > 0.5 then
		state.idleTime = 0
	else
		state.idleTime += dt
	end
	local sitting = (not isEgg and state.idleTime > style.SitAfter) and 1 or 0
	state.sitBlend += (sitting - state.sitBlend) * math.min(1, dt * 6)

	local bob, pitch, roll = 0, 0, 0
	local hop = math.abs(math.sin(state.phase))
	if isEgg then
		bob = hop * style.HopHeight * state.moveBlend
		roll = math.sin(state.phase) * style.WaddleRoll * state.moveBlend
			+ math.sin(state.clock * 2) * style.IdleWobble * (1 - state.moveBlend)
	else
		bob = hop * style.HopHeight * state.moveBlend
			+ (math.sin(state.clock * 2.5) * 0.5 + 0.5) * style.IdleBob * (1 - state.moveBlend) * (1 - state.sitBlend)
		pitch = -math.sin(state.phase * 2) * style.WalkTilt * state.moveBlend + style.SitPitch * state.sitBlend
	end

	model:PivotTo(
		CFrame.new(state.pos + Vector3.new(0, bob, 0))
			* CFrame.Angles(0, state.yaw, 0)
			* CFrame.Angles(pitch, 0, roll)
	)
end

local filterTimer = 0

RunService.RenderStepped:Connect(function(dt)
	filterTimer -= dt
	if filterTimer <= 0 then
		filterTimer = 0.5
		updateFilter()
	end

	local byOwner = {}
	for _, model in petsFolder:GetChildren() do
		-- Humanoid pets walk themselves (PetWalkHandler), so skip them here.
		if model:IsA("Model") and model.PrimaryPart and not model:FindFirstChildOfClass("Humanoid") then
			local ownerId = model:GetAttribute("OwnerUserId")
			if ownerId then
				byOwner[ownerId] = byOwner[ownerId] or {}
				table.insert(byOwner[ownerId], model)
			end
		end
	end

	for ownerId, models in byOwner do
		local owner = Players:GetPlayerByUserId(ownerId)
		local character = owner and owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			table.sort(models, function(a, b)
				return (a:GetAttribute("EquipOrder") or 0) < (b:GetAttribute("EquipOrder") or 0)
			end)
			for slot, model in models do
				updatePet(model, slot, root, humanoid, dt)
			end
		end
	end
end)
