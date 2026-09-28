--[[
	PetInventoryUI
	Adopt Me style backpack: press the Backpack button (or B), then click a
	pet or egg to equip it. Click the equipped one again to put it away.
	Equipping a different one swaps it out.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetConfig = require(Shared:WaitForChild("PetConfig"))
local PetModelBuilder = require(Shared:WaitForChild("PetModelBuilder"))

local remotes = ReplicatedStorage:WaitForChild("PetRemotes")
local equipRemote = remotes:WaitForChild("EquipItem")
local unequipRemote = remotes:WaitForChild("UnequipItem")

local player = Players.LocalPlayer
local inventory = player:WaitForChild("PetInventory")

local FONT = Enum.Font.FredokaOne
local BLUE = Color3.fromRGB(75, 170, 255)
local GREEN = Color3.fromRGB(90, 210, 90)
local WHITE = Color3.new(1, 1, 1)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function label(parent, text, size, position, textSize)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = FONT
	l.Text = text
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = textSize
	c.Parent = l
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = Color3.fromRGB(40, 40, 60)
	s.Parent = l
	return l
end

-- Screen ----------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "PetBackpack"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local openButton = Instance.new("TextButton")
openButton.Name = "BackpackButton"
openButton.AnchorPoint = Vector2.new(0, 0.5)
openButton.Position = UDim2.new(0, 16, 0.5, 0)
openButton.Size = UDim2.fromOffset(84, 84)
openButton.BackgroundColor3 = BLUE
openButton.Text = ""
openButton.AutoButtonColor = true
openButton.Parent = gui
corner(openButton, 20)
stroke(openButton, WHITE, 3)
label(openButton, "🎒", UDim2.new(1, 0, 0.62, 0), UDim2.new(0, 0, 0.04, 0), 40)
label(openButton, "Backpack", UDim2.new(1, -8, 0.3, 0), UDim2.new(0, 4, 0.66, 0), 16)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.6, 0, 0.62, 0)
panel.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
panel.Visible = false
panel.Parent = gui
corner(panel, 24)
stroke(panel, BLUE, 5)
local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MaxSize = Vector2.new(720, 520)
panelLimit.MinSize = Vector2.new(300, 260)
panelLimit.Parent = panel
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = BLUE
header.Parent = panel
corner(header, 24)
label(header, "Pets", UDim2.new(1, -120, 1, -8), UDim2.fromOffset(60, 4), 34)

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -10, 0.5, 0)
closeButton.Size = UDim2.fromOffset(40, 40)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeButton.Text = ""
closeButton.Parent = header
corner(closeButton, 12)
stroke(closeButton, WHITE, 2)
label(closeButton, "X", UDim2.fromScale(1, 1), UDim2.new(), 26)

local grid = Instance.new("ScrollingFrame")
grid.Position = UDim2.fromOffset(12, 68)
grid.Size = UDim2.new(1, -24, 1, -80)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 8
grid.ScrollBarImageColor3 = BLUE
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingLeft = UDim.new(0, 6)
padding.PaddingRight = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.Parent = grid

local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromOffset(120, 140)
layout.CellPadding = UDim2.fromOffset(12, 12)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

local function setOpen(open)
	if open == panel.Visible then
		return
	end
	panel.Visible = open
	if open then
		panelScale.Scale = 0.85
		TweenService:Create(panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

openButton.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.B then
		setOpen(not panel.Visible)
	end
end)

-- Cards -----------------------------------------------------------------

local cards = {}

local rarityOrder = { Legendary = 1, UltraRare = 2, Rare = 3, Uncommon = 4, Common = 5 }

local function refreshCard(item)
	local card = cards[item]
	if not card then
		return
	end
	local isEquipped = item:GetAttribute("Equipped") == true
	card.Button.BackgroundColor3 = isEquipped and Color3.fromRGB(200, 255, 200) or WHITE
	card.Check.Visible = isEquipped
end

local function makePreview(parent, itemName)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.new(1, -16, 0, 90)
	viewport.Position = UDim2.fromOffset(8, 8)
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = WHITE
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = parent

	local model = PetModelBuilder.build(itemName)
	model:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
	model.Parent = viewport

	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = size.Magnitude * 1.4
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.2, -distance), cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function addCard(item)
	local info = PetConfig.Items[item.Value]
	if not info or cards[item] then
		return
	end

	local rarityColor = PetConfig.Rarities[info.Rarity] or PetConfig.Rarities.Common

	local button = Instance.new("TextButton")
	button.Name = item.Name
	button.Text = ""
	button.BackgroundColor3 = WHITE
	button.AutoButtonColor = true
	button.LayoutOrder = (rarityOrder[info.Rarity] or 9) * 10 + (info.Kind == "Egg" and 1 or 0)
	button.Parent = grid
	corner(button, 16)
	stroke(button, rarityColor, 4)

	makePreview(button, item.Value)

	local nameLabel = label(button, item.Value, UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 98), 18)
	nameLabel.TextColor3 = Color3.fromRGB(60, 60, 80)
	nameLabel:FindFirstChildOfClass("UIStroke"):Destroy()

	local rarity = label(button, info.Rarity, UDim2.new(1, -10, 0, 16), UDim2.fromOffset(5, 120), 14)
	rarity.TextColor3 = rarityColor

	local check = Instance.new("Frame")
	check.AnchorPoint = Vector2.new(1, 0)
	check.Position = UDim2.new(1, -6, 0, 6)
	check.Size = UDim2.fromOffset(28, 28)
	check.BackgroundColor3 = GREEN
	check.Visible = false
	check.Parent = button
	corner(check, 14)
	stroke(check, WHITE, 2)
	label(check, "✓", UDim2.fromScale(1, 1), UDim2.new(), 22)

	cards[item] = { Button = button, Check = check }

	button.Activated:Connect(function()
		if item:GetAttribute("Equipped") then
			unequipRemote:FireServer(item.Name)
		else
			equipRemote:FireServer(item.Name)
		end
	end)

	item:GetAttributeChangedSignal("Equipped"):Connect(function()
		refreshCard(item)
	end)
	refreshCard(item)
end

local function removeCard(item)
	local card = cards[item]
	if card then
		card.Button:Destroy()
		cards[item] = nil
	end
end

for _, item in inventory:GetChildren() do
	addCard(item)
end
inventory.ChildAdded:Connect(addCard)
inventory.ChildRemoved:Connect(removeCard)
