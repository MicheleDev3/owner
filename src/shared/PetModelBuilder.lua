--[[
	PetModelBuilder
	Builds the Model for a pet or egg. Used by the server (the model that
	follows you) and by the client (inventory previews).

	Every model it returns:
	  * has an invisible PrimaryPart named "Root" at ground level (feet)
	  * faces -Z (Root.CFrame.LookVector is the pet's "forward")
	  * is fully anchored with no collisions, so it never pushes players
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(script.Parent.PetConfig)

local PetModelBuilder = {}

local function makePart(model, props)
	local p = Instance.new(props.ClassName or "Part")
	p.Name = props.Name
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or Color3.new(1, 1, 1)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

local function makeRoot(model, cframe)
	local root = makePart(model, {
		Name = "Root",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = cframe or CFrame.new(),
		Transparency = 1,
	})
	model.PrimaryPart = root
	return root
end

local function buildPet(model, info)
	local s = info.Scale or 1
	local color = info.Color
	local accent = info.AccentColor or color
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.25)
	local black = Color3.fromRGB(25, 25, 25)

	local function v(x, y, z)
		return Vector3.new(x, y, z) * s
	end

	makeRoot(model)

	-- Legs
	for _, x in { -0.5, 0.5 } do
		for _, z in { -0.6, 0.6 } do
			makePart(model, {
				Name = "Leg",
				Size = v(0.45, 0.7, 0.45),
				CFrame = CFrame.new(v(x, 0.35, z)),
				Color = dark,
			})
		end
	end

	makePart(model, { Name = "Body", Size = v(1.5, 1.2, 2.1), CFrame = CFrame.new(v(0, 1.1, 0)), Color = color, Sphere = true })
	makePart(model, { Name = "Belly", Size = v(1.1, 0.8, 1.6), CFrame = CFrame.new(v(0, 0.95, 0)), Color = accent, Sphere = true })
	makePart(model, { Name = "Head", Size = v(1.5, 1.4, 1.4), CFrame = CFrame.new(v(0, 2.0, -1.0)), Color = color, Sphere = true })
	makePart(model, { Name = "Snout", Size = v(0.75, 0.5, 0.6), CFrame = CFrame.new(v(0, 1.8, -1.6)), Color = accent, Sphere = true })
	makePart(model, { Name = "Nose", Size = v(0.25, 0.2, 0.2), CFrame = CFrame.new(v(0, 1.92, -1.9)), Color = black, Sphere = true })

	for _, x in { -0.35, 0.35 } do
		makePart(model, { Name = "Eye", Size = v(0.22, 0.3, 0.15), CFrame = CFrame.new(v(x, 2.2, -1.62)), Color = black, Sphere = true })
		makePart(model, { Name = "EyeShine", Size = v(0.08, 0.08, 0.05), CFrame = CFrame.new(v(x + 0.04, 2.27, -1.69)), Color = Color3.new(1, 1, 1), Sphere = true })
	end

	if info.Ears == "Pointy" then
		for _, x in { -0.45, 0.45 } do
			makePart(model, {
				Name = "Ear",
				ClassName = "WedgePart",
				Size = v(0.15, 0.55, 0.45),
				CFrame = CFrame.new(v(x, 2.8, -0.95)) * CFrame.Angles(0, 0, math.rad(x > 0 and -15 or 15)),
				Color = color,
			})
		end
	else
		for _, x in { -0.75, 0.75 } do
			makePart(model, {
				Name = "Ear",
				Size = v(0.35, 0.9, 0.6),
				CFrame = CFrame.new(v(x, 2.1, -0.9)) * CFrame.Angles(0, 0, math.rad(x > 0 and 20 or -20)),
				Color = dark,
				Sphere = true,
			})
		end
	end

	makePart(model, {
		Name = "Tail",
		Size = v(0.3, 0.3, 0.9),
		CFrame = CFrame.new(v(0, 1.5, 1.2)) * CFrame.Angles(math.rad(-35), 0, 0),
		Color = color,
		Sphere = true,
	})
end

-- Fixed spot directions so every egg of a type looks the same.
local SPOT_DIRECTIONS = {
	Vector3.new(0.6, 0.35, -0.7),
	Vector3.new(-0.75, 0.1, -0.55),
	Vector3.new(0.1, 0.8, -0.55),
	Vector3.new(0.9, -0.2, 0.3),
	Vector3.new(-0.5, 0.55, 0.65),
	Vector3.new(-0.9, -0.3, -0.1),
	Vector3.new(0.3, -0.35, 0.85),
	Vector3.new(0.2, -0.1, -1),
}

local function buildEgg(model, info)
	local s = info.Scale or 1
	local rx, ry = 0.9 * s, 1.15 * s
	local center = Vector3.new(0, ry, 0)

	makeRoot(model)
	makePart(model, {
		Name = "Shell",
		Size = Vector3.new(rx * 2, ry * 2, rx * 2),
		CFrame = CFrame.new(center),
		Color = info.Color,
		Sphere = true,
	})

	for _, dir in SPOT_DIRECTIONS do
		dir = dir.Unit
		local point = center + Vector3.new(dir.X * rx, dir.Y * ry, dir.Z * rx)
		local normal = Vector3.new(dir.X / rx, dir.Y / ry, dir.Z / rx).Unit
		makePart(model, {
			Name = "Spot",
			Size = Vector3.new(0.5, 0.5, 0.12) * s,
			CFrame = CFrame.lookAt(point - normal * 0.03, point + normal),
			Color = info.SpotColor,
			Sphere = true,
		})
	end
end

-- Uses a custom model from ReplicatedStorage.PetModels if one exists.
local function buildCustom(model, template)
	for _, child in template:GetChildren() do
		child:Clone().Parent = model
	end

	local look = template.PrimaryPart and template.PrimaryPart.CFrame.LookVector or Vector3.new(0, 0, -1)
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end

	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end

	makeRoot(model, CFrame.lookAt(bottom, bottom + look.Unit))
end

function PetModelBuilder.build(itemName)
	local info = PetConfig.Items[itemName]
	assert(info, "Unknown pet/egg: " .. tostring(itemName))

	local model = Instance.new("Model")
	model.Name = itemName

	local customFolder = ReplicatedStorage:FindFirstChild("PetModels")
	local template = customFolder and customFolder:FindFirstChild(itemName)
	if template and template:IsA("Model") then
		buildCustom(model, template)
	elseif info.Kind == "Egg" then
		buildEgg(model, info)
	else
		buildPet(model, info)
	end

	model:SetAttribute("ItemName", itemName)
	model:SetAttribute("Kind", info.Kind)
	return model
end

return PetModelBuilder
