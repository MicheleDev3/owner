--[[
	PetConfig
	Shared settings for the Adopt Me style pet / egg system.
	Add new pets or eggs to `Items`. If a Model with the same name exists in
	ReplicatedStorage.PetModels it is used instead of the built-in placeholder.
]]

local PetConfig = {}

PetConfig.Rarities = {
	Common = Color3.fromRGB(170, 170, 170),
	Uncommon = Color3.fromRGB(85, 200, 90),
	Rare = Color3.fromRGB(60, 140, 255),
	UltraRare = Color3.fromRGB(170, 80, 255),
	Legendary = Color3.fromRGB(255, 200, 40),
}

PetConfig.Items = {
	Dog = {
		Kind = "Pet",
		Rarity = "Common",
		Scale = 1,
		Color = Color3.fromRGB(196, 146, 94),
		AccentColor = Color3.fromRGB(240, 220, 190),
		Ears = "Floppy",
	},
	Cat = {
		Kind = "Pet",
		Rarity = "Common",
		Scale = 0.9,
		Color = Color3.fromRGB(255, 170, 80),
		AccentColor = Color3.fromRGB(255, 235, 210),
		Ears = "Pointy",
	},
	["Cracked Egg"] = {
		Kind = "Egg",
		Rarity = "Common",
		Scale = 1,
		Color = Color3.fromRGB(245, 235, 210),
		SpotColor = Color3.fromRGB(120, 90, 60),
	},
	["Pet Egg"] = {
		Kind = "Egg",
		Rarity = "Uncommon",
		Scale = 1,
		Color = Color3.fromRGB(150, 220, 255),
		SpotColor = Color3.fromRGB(255, 255, 255),
	},
	["Royal Egg"] = {
		Kind = "Egg",
		Rarity = "Legendary",
		Scale = 1.05,
		Color = Color3.fromRGB(150, 60, 200),
		SpotColor = Color3.fromRGB(255, 210, 60),
	},
}

-- Items every player starts with (for testing).
PetConfig.StarterItems = { "Dog", "Cat", "Cracked Egg", "Pet Egg", "Royal Egg" }

-- Adopt Me lets you have one pet/egg out at a time. Equipping another swaps it.
PetConfig.MaxEquipped = 1

PetConfig.Follow = {
	-- Slot offsets relative to the HumanoidRootPart (+X = right, +Z = behind).
	Offsets = {
		Vector3.new(3, 0, 2.5),
		Vector3.new(-3, 0, 2.5),
		Vector3.new(3, 0, 6),
		Vector3.new(-3, 0, 6),
	},
	StopDistance = 0.35, -- close enough to the slot to stand still
	CatchUpFactor = 4, -- speed = distance * factor (clamped)
	MinMaxSpeed = 24, -- floor for the max speed (studs/s)
	TeleportDistance = 60, -- snap to the owner if further than this
	TurnSpeed = 10, -- how fast the pet turns to face its direction

	Pet = {
		HopHeight = 0.35, -- small walking bounce
		HopFrequency = 1.1, -- radians of bounce per stud walked
		WalkTilt = math.rad(4),
		IdleBob = 0.04,
	},
	Egg = {
		HopHeight = 0.9, -- eggs hop along like in Adopt Me
		HopFrequency = 0.75,
		WaddleRoll = math.rad(12),
		IdleWobble = math.rad(3),
	},
}

PetConfig.EquipCooldown = 0.2

return PetConfig
