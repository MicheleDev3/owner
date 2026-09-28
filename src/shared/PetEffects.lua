--[[
	PetEffects
	The Adopt Me style equip / unequip effect.

	  popIn(model)            grow from nothing with a bouncy overshoot
	  popOut(model)           shrink away
	  poof(position, color, sound, pitch)
	                          sparkle burst, puff of smoke and a sound

	Scaling uses Model:ScaleTo around the model's pivot, which is at the
	pet's feet, so the pet grows up out of the ground.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PetConfig = require(script.Parent.PetConfig)
local Effects = PetConfig.Effects

local PetEffects = {}

local MIN_SCALE = 0.01

local function tweenScale(model, from, to, duration, style, direction)
	model:ScaleTo(math.max(from, MIN_SCALE))
	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not model.Parent then
			connection:Disconnect()
			return
		end
		local alpha = math.min((os.clock() - start) / duration, 1)
		local eased = TweenService:GetValue(alpha, style, direction)
		model:ScaleTo(math.max(from + (to - from) * eased, MIN_SCALE))
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

function PetEffects.popIn(model)
	tweenScale(model, 0, 1, Effects.PopInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

function PetEffects.popOut(model)
	tweenScale(model, model:GetScale(), 0, Effects.PopOutTime, Enum.EasingStyle.Back, Enum.EasingDirection.In)
end

function PetEffects.poof(position, color, soundId, pitch)
	color = color or Color3.new(1, 1, 1)

	local anchor = Instance.new("Part")
	anchor.Name = "PetPoof"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0))
	anchor.Parent = workspace

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = Effects.SparkleTexture
	sparkles.Rate = 0
	sparkles.Lifetime = NumberRange.new(0.45, 0.8)
	sparkles.Speed = NumberRange.new(8, 14)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Drag = 6
	sparkles.LightEmission = 1
	sparkles.Rotation = NumberRange.new(0, 360)
	sparkles.RotSpeed = NumberRange.new(-180, 180)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	sparkles.Parent = anchor

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = Effects.SmokeTexture
	smoke.Rate = 0
	smoke.Lifetime = NumberRange.new(0.35, 0.55)
	smoke.Speed = NumberRange.new(3, 6)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Drag = 4
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 3),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Color = ColorSequence.new(Color3.new(1, 1, 1))
	smoke.Parent = anchor

	sparkles:Emit(Effects.SparkleCount)
	smoke:Emit(Effects.SmokeCount)

	if soundId and soundId ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = Effects.SoundVolume
		sound.PlaybackSpeed = (pitch or 1) * (0.95 + math.random() * 0.1)
		sound.RollOffMaxDistance = 80
		sound.Parent = anchor
		sound:Play()
	end

	Debris:AddItem(anchor, 2)
end

return PetEffects
