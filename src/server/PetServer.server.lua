--[[
	PetServer
	Owns the inventory and equipping. When a player equips a pet or egg the
	server spawns its model in Workspace.PlayerPets; every client then
	animates it following its owner (see PetFollow.client.lua).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetConfig = require(Shared:WaitForChild("PetConfig"))
local PetModelBuilder = require(Shared:WaitForChild("PetModelBuilder"))

local remotes = Instance.new("Folder")
remotes.Name = "PetRemotes"

local equipRemote = Instance.new("RemoteEvent")
equipRemote.Name = "EquipItem"
equipRemote.Parent = remotes

local unequipRemote = Instance.new("RemoteEvent")
unequipRemote.Name = "UnequipItem"
unequipRemote.Parent = remotes

remotes.Parent = ReplicatedStorage

local petsFolder = workspace:FindFirstChild("PlayerPets") or Instance.new("Folder")
petsFolder.Name = "PlayerPets"
petsFolder.Parent = workspace

-- equipped[player] = { { itemId = string, model = Model }, ... } in equip order
local equipped = {}
local lastRequest = {}

local function getInventory(player)
	return player:FindFirstChild("PetInventory")
end

local function addItem(player, itemName)
	local inventory = getInventory(player)
	if not inventory or not PetConfig.Items[itemName] then
		return nil
	end
	local item = Instance.new("StringValue")
	item.Name = HttpService:GenerateGUID(false)
	item.Value = itemName
	item:SetAttribute("Equipped", false)
	item.Parent = inventory
	return item
end

local function unequip(player, itemId)
	local list = equipped[player]
	if not list then
		return
	end
	for i, entry in list do
		if entry.itemId == itemId then
			entry.model:Destroy()
			table.remove(list, i)
			local inventory = getInventory(player)
			local item = inventory and inventory:FindFirstChild(itemId)
			if item then
				item:SetAttribute("Equipped", false)
			end
			return
		end
	end
end

local function spawnPosition(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return CFrame.new(0, 5, 0)
	end
	local look = root.CFrame.LookVector
	local flat = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
	local feetY = root.Position.Y - root.Size.Y / 2
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
		feetY -= humanoid.HipHeight
	else
		feetY -= 2
	end
	local pos = (flat * CFrame.new(PetConfig.Follow.Offsets[1])).Position
	return CFrame.new(pos.X, feetY, pos.Z) * flat.Rotation
end

local function equip(player, itemId)
	local inventory = getInventory(player)
	local item = inventory and inventory:FindFirstChild(itemId)
	if not item or item:GetAttribute("Equipped") then
		return
	end

	local list = equipped[player]
	if not list then
		list = {}
		equipped[player] = list
	end

	-- Like Adopt Me: equipping another pet/egg swaps out the oldest one.
	while #list >= PetConfig.MaxEquipped do
		unequip(player, list[1].itemId)
	end

	local customFolder = ReplicatedStorage:FindFirstChild("PetModels")
	local template = customFolder and customFolder:FindFirstChild(item.Value)
	local model
	if template and template:FindFirstChildOfClass("Humanoid") then
		-- Humanoid pet: walks by itself with PetWalkHandler inside it.
		-- Named after the owner's UserId, which older pet scripts expect.
		model = template:Clone()
		model.Name = tostring(player.UserId)
		model:SetAttribute("ItemName", item.Value)
		model:SetAttribute("Kind", PetConfig.Items[item.Value].Kind)
	else
		model = PetModelBuilder.build(item.Value)
		model.Name = player.Name .. "_" .. item.Value
	end
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("EquipOrder", os.clock())
	local spawnCFrame = spawnPosition(player)
	model:PivotTo(spawnCFrame)
	if model:FindFirstChildOfClass("Humanoid") then
		-- Lift so its feet (not its pivot) are on the ground.
		local box, size = model:GetBoundingBox()
		local bottom = box.Position.Y - size.Y / 2
		model:PivotTo(model:GetPivot() + Vector3.new(0, spawnCFrame.Position.Y - bottom, 0))
	end
	model.Parent = petsFolder

	table.insert(list, { itemId = itemId, model = model })
	item:SetAttribute("Equipped", true)
end

local function canRequest(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < PetConfig.EquipCooldown then
		return false
	end
	lastRequest[player] = now
	return true
end

equipRemote.OnServerEvent:Connect(function(player, itemId)
	if typeof(itemId) ~= "string" or not canRequest(player) then
		return
	end
	equip(player, itemId)
end)

unequipRemote.OnServerEvent:Connect(function(player, itemId)
	if typeof(itemId) ~= "string" or not canRequest(player) then
		return
	end
	unequip(player, itemId)
end)

local function onPlayerAdded(player)
	local inventory = Instance.new("Folder")
	inventory.Name = "PetInventory"
	inventory.Parent = player

	-- Replace with your DataStore loading.
	for _, itemName in PetConfig.StarterItems do
		addItem(player, itemName)
	end

	inventory.ChildRemoved:Connect(function(item)
		unequip(player, item.Name)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local list = equipped[player]
	if list then
		for _, entry in list do
			entry.model:Destroy()
		end
	end
	equipped[player] = nil
	lastRequest[player] = nil
end)
