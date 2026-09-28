--[[
	PetAnimator
	Plays real animations on a rigged pet model.

	Put a Folder named "Animations" inside the pet model with Animation
	objects named any of:
	  Idle    looped, standing still
	  Walk    looped, walking (speed scales with how fast the pet moves)
	  Run     looped, catching up (falls back to Walk)
	  Sit     looped, after standing still a while (falls back to Idle)
	  Equip   played once when the pet is equipped

	The model needs Motor6D joints (a normal rig). It uses the model's
	Humanoid or AnimationController, and creates an AnimationController if
	neither exists.

	PetAnimator.get(model) returns one shared animator per model (or nil if
	the model has no animations), so several scripts can use it together.
]]

local PetAnimator = {}
PetAnimator.__index = PetAnimator

local cache = setmetatable({}, { __mode = "k" })

local FADE = 0.2

local function findAnimator(model)
	local controller = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	return animator
end

function PetAnimator.get(model)
	local existing = cache[model]
	if existing ~= nil then
		return existing or nil
	end

	local folder = model:FindFirstChild("Animations")
	if not folder then
		cache[model] = false
		return nil
	end

	local animator = findAnimator(model)
	local tracks = {}
	for _, animation in folder:GetChildren() do
		if animation:IsA("Animation") and animation.AnimationId ~= "" then
			local ok, track = pcall(animator.LoadAnimation, animator, animation)
			if ok and track then
				local isEquip = animation.Name == "Equip"
				track.Looped = not isEquip
				track.Priority = isEquip and Enum.AnimationPriority.Action or Enum.AnimationPriority.Core
				tracks[animation.Name] = track
			else
				warn("PetAnimator: could not load", animation:GetFullName(), track)
			end
		end
	end

	if next(tracks) == nil then
		cache[model] = false
		return nil
	end

	local self = setmetatable({ tracks = tracks, current = nil }, PetAnimator)
	cache[model] = self
	return self
end

local FALLBACKS = {
	Run = "Walk",
	Sit = "Idle",
}

-- Switch to a looped state ("Idle", "Walk", "Run", "Sit"), optionally
-- setting its playback speed.
function PetAnimator:setState(name, speed)
	local track = self.tracks[name] or (FALLBACKS[name] and self.tracks[FALLBACKS[name]])
	if not track then
		return
	end
	if self.current ~= track then
		if self.current then
			self.current:Stop(FADE)
		end
		track:Play(FADE)
		self.current = track
	end
	if speed then
		track:AdjustSpeed(speed)
	end
end

function PetAnimator:playOnce(name)
	local track = self.tracks[name]
	if track then
		track:Play(0.05)
	end
	return track
end

function PetAnimator:has(name)
	return self.tracks[name] ~= nil
end

return PetAnimator
