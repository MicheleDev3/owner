--[[
	PetEquipEffects
	Plays the Adopt Me style equip effect on this client for every pet or egg
	that gets equipped (yours and other players'):

	  equip    pet pops up out of the ground with a bouncy grow, sparkles,
	           a puff of smoke and a "bloop"
	  unequip  pet shrinks away with a puff and a swoosh

	Anchored pets are scaled here. Humanoid pets are scaled by the server,
	so only the sparkles and sound play for those.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetConfig = require(Shared:WaitForChild("PetConfig"))
local PetEffects = require(Shared:WaitForChild("PetEffects"))
local Effects = PetConfig.Effects

local petsFolder = workspace:WaitForChild("PlayerPets")

local function effectColor(model)
	local info = PetConfig.Items[model:GetAttribute("ItemName")]
	local rarity = info and PetConfig.Rarities[info.Rarity]
	return rarity or Color3.fromRGB(255, 240, 150)
end

local function watchUnequip(model)
	local isHumanoid = model:FindFirstChildOfClass("Humanoid") ~= nil
	local played = false
	local function onUnequip()
		if played or not model:GetAttribute("Unequipping") then
			return
		end
		played = true
		PetEffects.poof(model:GetPivot().Position, effectColor(model), Effects.UnequipSound, Effects.UnequipSoundPitch)
		if not isHumanoid then
			PetEffects.popOut(model)
		end
	end
	model:GetAttributeChangedSignal("Unequipping"):Connect(onUnequip)
	onUnequip()
end

local function onPetAdded(model)
	if not model:IsA("Model") then
		return
	end
	if model:GetAttribute("Unequipping") then
		return
	end
	if not model:FindFirstChildOfClass("Humanoid") then
		PetEffects.popIn(model)
	end
	PetEffects.poof(model:GetPivot().Position, effectColor(model), Effects.EquipSound, Effects.EquipSoundPitch)
	watchUnequip(model)
end

-- Pets that were already out when we joined: no pop-in, but still pop out.
for _, model in petsFolder:GetChildren() do
	if model:IsA("Model") then
		watchUnequip(model)
	end
end
petsFolder.ChildAdded:Connect(onPetAdded)
