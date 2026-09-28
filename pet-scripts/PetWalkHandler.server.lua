--[[
	PetWalkHandler (Script inside a Humanoid pet model)

	Adopt Me style walking for a Humanoid pet:
	  * walks to its spot next to / behind the owner at the owner's pace,
	    and speeds up smoothly when it falls behind (no speed spikes)
	  * slides into place and turns to face the owner's direction when idle
	  * jumps when the owner is above it or when it gets stuck on something
	  * teleports next to the owner (not inside them) when it gets too far

	The owner is read from the "OwnerUserId" attribute, or from the model's
	name (the owner's UserId) like before.

	Optional marker parts on the owner's character (used if they exist,
	otherwise the offsets below are used):
	  PetPosition          idle spot while the pet can see PetProtector
	  PetWalkingPosition   walking spot while the pet can see PetProtector
	  PetBackStopPosition  idle spot when the view is blocked
	  PetBackPosition      walking spot when the view is blocked
	  PetProtector         the part the pet checks line of sight to
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local pet = script.Parent
local myHuman = pet:WaitForChild("Humanoid")
local myRoot = pet:WaitForChild("HumanoidRootPart")

-- Fallback offsets from the owner's HumanoidRootPart (+X right, +Z behind).
local FALLBACK_OFFSETS = {
	PetPosition = Vector3.new(3, 0, 1),
	PetWalkingPosition = Vector3.new(3, 0, 3),
	PetBackStopPosition = Vector3.new(0, 0, 4),
	PetBackPosition = Vector3.new(0, 0, 5),
}

local ARRIVE_DISTANCE = 1.5 -- close enough to stop walking
local SLIDE_DISTANCE = 4 -- idle: slide the last few studs instead of walking
local CATCH_UP = 2.5 -- extra speed per stud behind
local MIN_SPEED = 8
local MAX_SPEED_MULTIPLIER = 2.2 -- never faster than owner speed * this
local LOOK_AHEAD = 0.12 -- seconds of owner velocity to aim ahead
local TELEPORT_DISTANCE = 50
local TELEPORT_HEIGHT = 25
local JUMP_HEIGHT = 3 -- jump if the goal is this much higher
local STUCK_TIME = 0.4 -- jump if not moving for this long while walking
local TURN_SPEED = 8

local ownerId = pet:GetAttribute("OwnerUserId") or tonumber(pet.Name)

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.FilterDescendantsInstances = { pet }

local stuckTimer = 0

local function getOwnerCharacter()
	local owner = ownerId and Players:GetPlayerByUserId(ownerId)
	local character = owner and owner.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character, root, humanoid
end

local function canSee(target, character)
	local offset = target.Position - myRoot.Position
	if offset.Magnitude > 80 then
		return false
	end
	local hit = workspace:Raycast(myRoot.Position, offset, sightParams)
	if hit and not hit.Instance:IsDescendantOf(character) and math.abs(hit.Position.Y - myRoot.Position.Y) < 12 then
		return false
	end
	return true
end

-- Returns the goal position and whether it is an idle (standing) spot.
local function getGoal(character, root, humanoid)
	local isIdle = humanoid.MoveDirection.Magnitude < 0.01
	local protector = character:FindFirstChild("PetProtector")

	local name
	if protector and canSee(protector, character) then
		name = isIdle and "PetPosition" or "PetWalkingPosition"
	else
		name = isIdle and "PetBackStopPosition" or "PetBackPosition"
	end

	local marker = character:FindFirstChild(name)
	if marker and marker:IsA("BasePart") then
		return marker.Position, isIdle
	end

	-- No marker part: offset from the owner, using only their facing (yaw).
	local look = root.CFrame.LookVector
	local flat = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
	return (flat * CFrame.new(FALLBACK_OFFSETS[name])).Position, isIdle
end

local function feetY(root, humanoid)
	local y = root.Position.Y - root.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return y - humanoid.HipHeight
	end
	return y - 2
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function teleportTo(goal, root, humanoid)
	local look = root.CFrame.LookVector
	local facing = Vector3.new(look.X, 0, look.Z)
	local ground = Vector3.new(goal.X, feetY(root, humanoid), goal.Z)
	local height = myHuman.HipHeight + myRoot.Size.Y / 2
	pet:PivotTo(CFrame.lookAt(ground, ground + facing) + Vector3.new(0, height, 0))
	myRoot.AssemblyLinearVelocity = Vector3.zero
	myHuman:Move(Vector3.zero)
end

local function faceDirection(direction, dt)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local current = myRoot.CFrame
	local target = CFrame.lookAt(current.Position, current.Position + flat)
	myRoot.CFrame = current:Lerp(target, math.min(1, dt * TURN_SPEED))
end

local function update(dt)
	local character, root, humanoid = getOwnerCharacter()
	if not character then
		myHuman:Move(Vector3.zero)
		return
	end

	local goal, isIdle = getGoal(character, root, humanoid)
	if not isIdle then
		-- Aim slightly ahead so the pet keeps pace instead of trailing.
		local velocity = root.AssemblyLinearVelocity
		goal += Vector3.new(velocity.X, 0, velocity.Z) * LOOK_AHEAD
	end

	local toOwner = root.Position - myRoot.Position
	if toOwner.Magnitude > TELEPORT_DISTANCE or math.abs(toOwner.Y) > TELEPORT_HEIGHT then
		teleportTo(goal, root, humanoid)
		return
	end

	local distance = flatDistance(goal, myRoot.Position)
	local ownerSpeed = math.max(humanoid.WalkSpeed, MIN_SPEED)

	if isIdle and distance < ARRIVE_DISTANCE then
		-- Arrived: stand still and face the same way as the owner.
		myHuman:Move(Vector3.zero)
		faceDirection(root.CFrame.LookVector, dt)
		stuckTimer = 0
		return
	end

	if isIdle and distance < SLIDE_DISTANCE then
		-- Last few studs while the owner is idle: glide into place.
		myHuman:Move(Vector3.zero)
		local target = Vector3.new(goal.X, myRoot.Position.Y, goal.Z)
		local rotation = myRoot.CFrame - myRoot.Position
		myRoot.CFrame = CFrame.new(myRoot.Position:Lerp(target, math.min(1, dt * 10))) * rotation
		faceDirection(root.CFrame.LookVector, dt)
		stuckTimer = 0
		return
	end

	-- Walk at the owner's pace, faster the further behind the pet is.
	local speed = ownerSpeed * 0.9 + math.max(distance - ARRIVE_DISTANCE, 0) * CATCH_UP
	myHuman.WalkSpeed = math.clamp(speed, MIN_SPEED, ownerSpeed * MAX_SPEED_MULTIPLIER)
	myHuman:MoveTo(goal)

	-- Hop up ledges / stairs and over things it gets stuck on.
	local horizontalSpeed = Vector3.new(myRoot.AssemblyLinearVelocity.X, 0, myRoot.AssemblyLinearVelocity.Z).Magnitude
	if distance > ARRIVE_DISTANCE and horizontalSpeed < 1 then
		stuckTimer += dt
	else
		stuckTimer = 0
	end
	local petFeet = myRoot.Position.Y - myHuman.HipHeight - myRoot.Size.Y / 2
	local ownerGrounded = humanoid.FloorMaterial ~= Enum.Material.Air -- don't copy the owner's jumps
	local goalAbove = ownerGrounded and feetY(root, humanoid) - petFeet > JUMP_HEIGHT
	if (goalAbove and distance < 6) or stuckTimer > STUCK_TIME then
		myHuman.Jump = true
		stuckTimer = 0
	end
end

local connection
connection = RunService.Heartbeat:Connect(function(dt)
	if not pet.Parent or myHuman.Health <= 0 then
		connection:Disconnect()
		return
	end
	update(dt)
end)
