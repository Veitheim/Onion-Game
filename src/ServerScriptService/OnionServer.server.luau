-- Main game loop: build the giant onion, validate peels, drop collectible peels,
-- selling, knife tools, shop/skill purchases and core prizes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local remotes = ReplicatedStorage.Remotes
local peelRemote = remotes.Peel :: RemoteEvent
local onionEvent = remotes.OnionEvent :: RemoteEvent
local shopAction = remotes.ShopAction :: RemoteFunction

local rng = Random.new()

local onionModel = Instance.new("Model")
onionModel.Name = "GiantOnion"
onionModel.Parent = Workspace

local chunkFolder = Instance.new("Folder")
chunkFolder.Name = "OnionPeels"
chunkFolder.Parent = Workspace

local layers: { [number]: BasePart } = {}
local core: BasePart? = nil
local currentLayer = 1
local layerHP = 0
local layerMaxHP = 1
local onionNumber = 1
local busy = false

local layerContributors: { [Player]: boolean } = {}
local onionContributors: { [Player]: boolean } = {}
local lastPeel: { [Player]: number } = {}
local lastSell: { [Player]: number } = {}

---------------------------------------------------------------- Onion building

local function layerRadius(index: number): number
	local t = (index - 1) / math.max(Config.LayerCount - 1, 1)
	return Config.OuterRadius + (Config.InnerRadius - Config.OuterRadius) * t
end

-- Every layer rests on the board so even the small ones are reachable.
local function centerFor(radius: number): Vector3
	return Vector3.new(Config.OnionPosition.X, Config.GroundY + radius - 0.5, Config.OnionPosition.Z)
end

local function computeLayerHP(index: number): number
	local playerCount = math.max(1, #Players:GetPlayers())
	local hp = Config.BaseLayerHP
		* Config.LayerHPGrowth ^ (index - 1)
		* Config.OnionHPGrowth ^ (onionNumber - 1)
		* (1 + (playerCount - 1) * Config.PlayerHPFactor)
	return math.floor(hp)
end

local function publishState()
	onionModel:SetAttribute("OnionNumber", onionNumber)
	onionModel:SetAttribute("Layer", currentLayer)
	onionModel:SetAttribute("LayerCount", Config.LayerCount)
	onionModel:SetAttribute("LayerHP", math.max(layerHP, 0))
	onionModel:SetAttribute("LayerMaxHP", layerMaxHP)
end

-- A face that always looks at you and gets sadder with every layer.
local faceAnchor = Instance.new("Part")
faceAnchor.Name = "FaceAnchor"
faceAnchor.Anchored = true
faceAnchor.CanCollide = false
faceAnchor.CanQuery = false
faceAnchor.CanTouch = false
faceAnchor.Transparency = 1
faceAnchor.Size = Vector3.one
faceAnchor.Parent = onionModel

local faceGui = Instance.new("BillboardGui")
faceGui.Name = "Face"
faceGui.LightInfluence = 0
faceGui.MaxDistance = 1000
faceGui.Parent = faceAnchor

local faceLabel = Instance.new("TextLabel")
faceLabel.BackgroundTransparency = 1
faceLabel.Size = UDim2.fromScale(1, 1)
faceLabel.TextScaled = true
faceLabel.Font = Enum.Font.FredokaOne
faceLabel.Parent = faceGui

local function updateFace(radius: number?, emoji: string?)
	if not radius then
		faceGui.Enabled = false
		return
	end
	faceGui.Enabled = true
	faceAnchor.Position = centerFor(radius)
	faceGui.Size = UDim2.fromScale(radius * 0.9, radius * 0.9)
	faceGui.StudsOffset = Vector3.new(0, 0, radius + 1)
	faceLabel.Text = emoji or "🙂"
end

local function faceForLayer(index: number): string
	local t = (index - 1) / math.max(Config.LayerCount - 1, 1)
	return Config.Faces[math.clamp(math.floor(t * #Config.Faces) + 1, 1, #Config.Faces)]
end

local function placeStem(radius: number?)
	local old = onionModel:FindFirstChild("Stem")
	if old then
		old:Destroy()
	end
	if not radius then
		return
	end

	local stem = Instance.new("Model")
	stem.Name = "Stem"
	local top = centerFor(radius) + Vector3.new(0, radius - 1, 0)
	local length = math.max(radius * 0.6, 3)
	local thickness = math.max(radius * 0.09, 0.8)
	for i = 1, 3 do
		local leaf = Instance.new("Part")
		leaf.Name = "Leaf"
		leaf.Shape = Enum.PartType.Cylinder
		leaf.Size = Vector3.new(length, thickness, thickness)
		leaf.Color = Color3.fromRGB(110, 200, 80)
		leaf.Material = Enum.Material.SmoothPlastic
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.CanQuery = false
		leaf.CFrame = CFrame.new(top)
			* CFrame.Angles(0, math.rad(i * 120), math.rad(12 + i * 4))
			* CFrame.new(0, length / 2, 0)
			* CFrame.Angles(0, 0, math.rad(90))
		leaf.Parent = stem
	end
	stem.Parent = onionModel
end

local function buildOnion()
	for _, part in layers do
		part:Destroy()
	end
	table.clear(layers)
	if core then
		core:Destroy()
	end

	for i = 1, Config.LayerCount do
		local r = layerRadius(i)
		local part = Instance.new("Part")
		part.Name = "Layer" .. i
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * r * 2
		part.Color = Config.GetLayerColor(i)
		part.Material = if i == 1 then Enum.Material.Fabric else Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CFrame = CFrame.new(centerFor(r))
		part:SetAttribute("LayerIndex", i)
		part.Parent = onionModel
		layers[i] = part
	end

	local newCore = Instance.new("Part")
	newCore.Name = "Core"
	newCore.Shape = Enum.PartType.Ball
	newCore.Size = Vector3.one * Config.InnerRadius * 1.1
	newCore.Color = Color3.fromRGB(255, 210, 70)
	newCore.Material = Enum.Material.Neon
	newCore.Anchored = true
	newCore.CanCollide = false
	newCore.CanQuery = false
	newCore.CFrame = CFrame.new(centerFor(Config.InnerRadius))
	local light = Instance.new("PointLight")
	light.Color = newCore.Color
	light.Range = 30
	light.Brightness = 0
	light.Parent = newCore
	newCore.Parent = onionModel
	core = newCore

	currentLayer = 1
	layerMaxHP = computeLayerHP(1)
	layerHP = layerMaxHP
	placeStem(layerRadius(1))
	updateFace(layerRadius(1), faceForLayer(1))
	publishState()
end

---------------------------------------------------------------- Collectible peels

local function dropPeels(layer: BasePart, totalPeels: number)
	local radius = layer.Size.X / 2
	local center = layer.Position
	local perChunk = math.max(1, math.ceil(totalPeels / Config.ChunkCount))
	local readyAt = os.clock() + 0.8
	for _ = 1, Config.ChunkCount do
		local dir = rng:NextUnitVector()
		dir = Vector3.new(dir.X, math.abs(dir.Y) * 0.8 + 0.2, dir.Z).Unit
		local chunk = Instance.new("Part")
		chunk.Name = "Peel"
		chunk.Size = Vector3.new(rng:NextNumber(2, 4), 0.5, rng:NextNumber(2, 4)) * math.clamp(radius / 20, 0.7, 1.5)
		chunk.Color = layer.Color
		chunk.Material = layer.Material
		chunk.CanQuery = false
		chunk.CFrame = CFrame.lookAt(center + dir * radius, center + dir * (radius + 1)) * CFrame.Angles(math.rad(90), 0, 0)
		chunk.AssemblyLinearVelocity = dir * rng:NextNumber(40, 75) + Vector3.new(0, 30, 0)
		chunk.AssemblyAngularVelocity = rng:NextUnitVector() * 10
		chunk:SetAttribute("Peels", perChunk)
		chunk:SetAttribute("ReadyAt", readyAt)
		chunk:SetAttribute("ExpiresAt", readyAt + Config.ChunkLifetime)

		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = Color3.fromRGB(255, 240, 180)
		sparkle.Parent = chunk

		chunk.Parent = chunkFolder
	end
end

local pickupTimer = 0
RunService.Heartbeat:Connect(function(dt)
	pickupTimer += dt
	if pickupTimer < 0.15 then
		return
	end
	pickupTimer = 0

	local now = os.clock()
	local roots: { [Player]: BasePart } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			roots[player] = root
		end
	end

	for _, chunk in chunkFolder:GetChildren() do
		if not chunk:IsA("BasePart") then
			continue
		end
		if now > (chunk:GetAttribute("ExpiresAt") or 0) then
			chunk:Destroy()
			continue
		end
		if now < (chunk:GetAttribute("ReadyAt") or 0) then
			continue
		end
		for player, root in roots do
			local range = Config.GetPickupRange(PlayerData.GetSkill(player, "Magnet"))
			if (root.Position - chunk.Position).Magnitude <= range and not PlayerData.IsBagFull(player) then
				local added, full = PlayerData.AddPeels(player, chunk:GetAttribute("Peels") or 1)
				onionEvent:FireClient(player, "Collected", added, full, chunk.Position)
				chunk:Destroy()
				break
			end
		end
	end
end)

---------------------------------------------------------------- Core prizes

local function rollPrize(lucky: number): Config.PrizeDef
	local total = 0
	for _, prize in Config.Prizes do
		total += Config.GetPrizeWeight(prize, lucky)
	end
	local roll = rng:NextNumber(0, total)
	for _, prize in Config.Prizes do
		roll -= Config.GetPrizeWeight(prize, lucky)
		if roll <= 0 then
			return prize
		end
	end
	return Config.Prizes[1]
end

local function finishOnion()
	busy = true
	placeStem(nil)
	updateFace(nil)
	publishState()
	onionEvent:FireAllClients("OnionDone", onionNumber)

	local revealed = core
	if revealed then
		TweenService:Create(revealed, TweenInfo.new(Config.CoreRevealTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.one * Config.InnerRadius * 1.8,
			CFrame = revealed.CFrame * CFrame.new(0, 4, 0),
		}):Play()
		local light = revealed:FindFirstChildOfClass("PointLight")
		if light then
			TweenService:Create(light, TweenInfo.new(Config.CoreRevealTime), { Brightness = 6 }):Play()
		end
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(revealed.Color)
		sparkles.LightEmission = 1
		sparkles.Rate = 60
		sparkles.Speed = NumberRange.new(10, 25)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Lifetime = NumberRange.new(0.8, 1.5)
		sparkles.Size = NumberSequence.new(1, 0)
		sparkles.Parent = revealed
	end

	task.wait(Config.CoreRevealTime)

	for player in onionContributors do
		if player.Parent then
			local prize = rollPrize(PlayerData.GetSkill(player, "Lucky"))
			local coins = prize.Coins * onionNumber
			PlayerData.AddCoins(player, coins)
			if prize.SkillPoints > 0 then
				PlayerData.AddSkillPoints(player, prize.SkillPoints)
			end
			if prize.Golden then
				PlayerData.AddGoldenOnion(player)
				for _, other in Players:GetPlayers() do
					if other ~= player then
						onionEvent:FireClient(other, "Announcement", `👑 {player.DisplayName} found the GOLDEN ONION! 👑`, prize.Color)
					end
				end
			end
			onionEvent:FireClient(player, "Prize", prize.DisplayName, coins, prize.SkillPoints, prize.Color)
		end
	end

	task.wait(Config.RespawnDelay)
	onionNumber += 1
	table.clear(onionContributors)
	table.clear(layerContributors)
	buildOnion()
	busy = false
	onionEvent:FireAllClients("OnionSpawned", onionNumber)
end

---------------------------------------------------------------- Peeling

local function peelLayer()
	local layer = layers[currentLayer]
	local peeledIndex = currentLayer
	if layer then
		dropPeels(layer, layerMaxHP * Config.ChunkPeelShare)
		layer:Destroy()
		layers[currentLayer] = nil
	end

	for player in layerContributors do
		if player.Parent then
			PlayerData.AddSkillPoints(player, Config.SkillPointsPerLayer)
			PlayerData.AddLayer(player)
			onionEvent:FireClient(player, "SkillPoint", Config.SkillPointsPerLayer)
		end
	end
	table.clear(layerContributors)
	onionEvent:FireAllClients("LayerPeeled", peeledIndex, Config.LayerCount)

	currentLayer += 1
	if currentLayer > Config.LayerCount then
		layerHP = 0
		task.spawn(finishOnion)
	else
		layerMaxHP = computeLayerHP(currentLayer)
		layerHP = layerMaxHP
		placeStem(layerRadius(currentLayer))
		updateFace(layerRadius(currentLayer), faceForLayer(currentLayer))
		publishState()
	end
end

peelRemote.OnServerEvent:Connect(function(player: Player)
	if busy then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	-- Allow some network jitter, but block autoclickers that go faster than the skill allows.
	local now = os.clock()
	local minInterval = Config.GetSwingInterval(PlayerData.GetSkill(player, "Quick")) * 0.75
	if now - (lastPeel[player] or 0) < minInterval then
		return
	end
	lastPeel[player] = now

	local layer = layers[currentLayer]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not layer or not root then
		return
	end
	if (root.Position - layer.Position).Magnitude > layer.Size.X / 2 + Config.MaxPeelDistance then
		return
	end

	local damage = Config.GetDamage(data.Knife, PlayerData.GetSkill(player, "Sharp"))
	local crit = rng:NextNumber() < Config.GetCritChance(PlayerData.GetSkill(player, "Crit"))
	if crit then
		damage *= 3
	end
	local golden = rng:NextNumber() < Config.GetGoldenChance(PlayerData.GetSkill(player, "GoldTouch"))
	local added, full = PlayerData.AddPeels(player, damage * (if golden then 10 else 1))

	layerContributors[player] = true
	onionContributors[player] = true
	onionEvent:FireClient(player, "Hit", damage, crit, golden, added, full)

	layerHP -= damage
	if layerHP <= 0 then
		peelLayer()
	else
		onionModel:SetAttribute("LayerHP", layerHP)
	end
end)

---------------------------------------------------------------- Selling

task.spawn(function()
	local stand = Workspace:WaitForChild("SellStand", 30)
	local pad = stand and stand:WaitForChild("SellPad", 10) :: BasePart?
	if not pad then
		warn("[OnionServer] Workspace.SellStand.SellPad not found – selling is disabled")
		return
	end
	pad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		local now = os.clock()
		if now - (lastSell[player] or 0) < 1 then
			return
		end
		lastSell[player] = now
		local peels, coins = PlayerData.Sell(player)
		if peels > 0 then
			onionEvent:FireClient(player, "Sold", peels, coins)
		end
	end)
end)

---------------------------------------------------------------- Knife tool

local function buildKnifeTool(index: number): Tool
	local def = Config.Knives[index]
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = `{def.Damage} damage`
	tool:SetAttribute("OnionKnife", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 1.1, 0.35)
	handle.Color = Color3.fromRGB(70, 45, 30)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(0.5, 0.15, 0.7)
	guard.Color = Color3.fromRGB(40, 40, 45)
	guard.Material = Enum.Material.Metal
	guard.CanCollide = false
	guard.Massless = true
	guard.CFrame = CFrame.new(0, 0.6, 0)
	guard.Parent = tool

	local bladeLength = 1.5 + index * 0.18
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.1, bladeLength, 0.5 + index * 0.03)
	blade.Color = def.Color
	blade.Material = def.Material
	blade.Reflectance = if def.Material == Enum.Material.Metal then 0.2 else 0
	blade.CanCollide = false
	blade.Massless = true
	blade.CFrame = CFrame.new(0, 0.67 + bladeLength / 2, 0)
	blade.Parent = tool

	for _, part in { guard, blade } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end
	return tool
end

local function giveKnife(player: Player)
	local data = PlayerData.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	local character = player.Character
	for _, container in { backpack, character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("OnionKnife") then
					child:Destroy()
				end
			end
		end
	end
	local tool = buildKnifeTool(data.Knife)
	tool.Parent = backpack
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end
end

---------------------------------------------------------------- Shop

shopAction.OnServerInvoke = function(player: Player, action: unknown, arg: unknown)
	if action == "BuyKnife" then
		local ok, msg = PlayerData.BuyNextTier(player, "Knife")
		if ok then
			giveKnife(player)
		end
		return ok, msg
	elseif action == "BuyBag" then
		return PlayerData.BuyNextTier(player, "Bag")
	elseif action == "UpgradeSkill" and type(arg) == "string" then
		return PlayerData.UpgradeSkill(player, arg)
	end
	return false, "Invalid"
end

---------------------------------------------------------------- Players

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		task.wait(0.2)
		giveKnife(player)
	end)
	PlayerData.Load(player)
	if player.Character then
		giveKnife(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	lastPeel[player] = nil
	lastSell[player] = nil
	layerContributors[player] = nil
	onionContributors[player] = nil
	PlayerData.Release(player)
end)

game:BindToClose(function()
	PlayerData.SaveAll()
	task.wait(2)
end)

task.spawn(function()
	while true do
		task.wait(120)
		PlayerData.SaveAll()
	end
end)

buildOnion()
