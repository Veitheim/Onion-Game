-- Client: HUD, peeling input, juicy feedback, tears, sell guidance and menus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script:WaitForChild("UIKit"))
local Menus = require(script:WaitForChild("Menus"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local peelRemote = remotes:WaitForChild("Peel") :: RemoteEvent
local onionEvent = remotes:WaitForChild("OnionEvent") :: RemoteEvent

local player = Players.LocalPlayer
local onion = Workspace:WaitForChild("GiantOnion") :: Model
local camera = Workspace.CurrentCamera
local create = UIKit.create
local Theme = UIKit.Theme
local fmt = Config.FormatNumber

-- The knife is always equipped, so the hotbar is just clutter.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local function skill(id: string): number
	return player:GetAttribute("Skill_" .. id) or 0
end

---------------------------------------------------------------- HUD

local gui = create("ScreenGui", {
	Name = "OnionHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local tearLayer = create("Frame", { Name = "Tears", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local popupLayer = create("Frame", { Name = "Popups", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Parent = gui })

-- Onion progress card (top center)
local onionCard = UIKit.panel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 62),
	Size = UDim2.fromOffset(380, 84),
	Parent = gui,
})
UIKit.autoScale(onionCard, 900, 620)
local onionTitle = UIKit.text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 30), Parent = onionCard })
local hpBack = create("Frame", {
	Position = UDim2.fromOffset(14, 44),
	Size = UDim2.new(1, -28, 0, 28),
	BackgroundColor3 = Theme.PanelDark,
	BorderSizePixel = 0,
	Parent = onionCard,
}, { UIKit.corner(10), UIKit.stroke(3, nil, true) })
local hpFill = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Parent = hpBack,
}, { UIKit.corner(10), UIKit.shade(Theme.Pink) })
local hpText = UIKit.text({ Position = UDim2.fromOffset(6, 3), Size = UDim2.new(1, -12, 1, -6), ZIndex = 2, Parent = hpBack })

-- Currencies (top left)
local currencies = create("Frame", {
	Position = UDim2.fromOffset(16, 64),
	Size = UDim2.fromOffset(190, 92),
	BackgroundTransparency = 1,
	Parent = gui,
}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
UIKit.autoScale(currencies, 900, 620)

local function pill(order: number, color: Color3): (Frame, TextLabel)
	local frame = UIKit.panel({ LayoutOrder = order, Size = UDim2.fromOffset(190, 42), Parent = currencies }, Theme.PanelDark)
	local label = UIKit.text({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		Parent = frame,
	})
	return frame, label
end
local coinPill, coinLabel = pill(1, Theme.Gold)
local spPill, spLabel = pill(2, Theme.Purple)

-- Menu buttons (left side)
local menuBar = create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 30),
	Size = UDim2.fromOffset(84, 3 * 84 + 2 * 10),
	BackgroundTransparency = 1,
	Parent = gui,
}, { create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
UIKit.autoScale(menuBar, 900, 620)

local menuButtons: { [string]: TextButton } = {}
for order, entry in { { "Knives", "🔪", "KNIVES", Theme.Red }, { "Bags", "🎒", "BAGS", Theme.Green }, { "Skills", "🌳", "SKILLS", Theme.Purple } } do
	local name, icon, caption, color = entry[1], entry[2], entry[3], entry[4]
	local button, label = UIKit.button({ LayoutOrder = order, Size = UDim2.fromOffset(84, 84), Parent = menuBar }, color, icon)
	label.Size = UDim2.new(1, -16, 0, 46)
	label.Position = UDim2.new(0.5, 0, 0, 30)
	UIKit.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -8, 0, 20),
		Text = caption,
		Parent = button,
	})
	button.Activated:Connect(function()
		Menus.Toggle(name)
	end)
	menuButtons[name] = button
end

local skillBadge = UIKit.text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(30, 30),
	BackgroundTransparency = 0,
	BackgroundColor3 = Theme.Red,
	Visible = false,
	ZIndex = 3,
	Parent = menuButtons.Skills,
})
UIKit.corner(15).Parent = skillBadge

-- Bag meter (bottom center)
local bagCard = UIKit.panel({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(340, 58),
	Parent = gui,
})
UIKit.autoScale(bagCard, 900, 620)
UIKit.text({ Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(46, 46), Text = "🎒", Parent = bagCard })
local bagBack = create("Frame", {
	Position = UDim2.fromOffset(60, 13),
	Size = UDim2.new(1, -74, 0, 32),
	BackgroundColor3 = Theme.PanelDark,
	BorderSizePixel = 0,
	Parent = bagCard,
}, { UIKit.corner(10), UIKit.stroke(3, nil, true) })
local bagFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Theme.Green,
	BorderSizePixel = 0,
	Parent = bagBack,
}, { UIKit.corner(10) })
local bagText = UIKit.text({ Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 1, -8), ZIndex = 2, Parent = bagBack })

-- Toasts (under the onion card)
local toastList = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 160),
	Size = UDim2.fromOffset(420, 200),
	BackgroundTransparency = 1,
	Parent = gui,
}, { create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
UIKit.autoScale(toastList, 900, 620)

local function toast(text: string, color: Color3)
	local label = UIKit.text({ Size = UDim2.fromOffset(420, 32), Text = text, TextColor3 = color, Parent = toastList })
	UIKit.pop(label, 1.3)
	task.delay(2.2, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 })
		fade:Play()
		local textStroke = label:FindFirstChildOfClass("UIStroke")
		if textStroke then
			TweenService:Create(textStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		fade.Completed:Wait()
		label:Destroy()
	end)
	if #toastList:GetChildren() > 6 then
		for _, child in toastList:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end
end

-- Big center announcements
local announceLabel = UIKit.text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.new(0.85, 0, 0, 90),
	Visible = false,
	ZIndex = 15,
	Parent = gui,
})
local announceScale = create("UIScale", { Parent = announceLabel })
local announceToken = 0

local function announce(text: string, color: Color3, duration: number)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = text
	announceLabel.TextColor3 = color
	announceLabel.TextTransparency = 0
	announceLabel.Visible = true
	announceScale.Scale = 0.3
	TweenService:Create(announceScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duration, function()
		if token ~= announceToken then
			return
		end
		local fade = TweenService:Create(announceLabel, TweenInfo.new(0.4), { TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		if token == announceToken then
			announceLabel.Visible = false
		end
	end)
end

Menus.OnToast = toast
Menus.Init(gui)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local menu = prompt:GetAttribute("OpensMenu")
	if type(menu) == "string" then
		Menus.Open(menu)
	end
end)

---------------------------------------------------------------- HUD updates

local function updateOnionCard()
	local number = onion:GetAttribute("OnionNumber") or 1
	local layer = onion:GetAttribute("Layer") or 1
	local count = onion:GetAttribute("LayerCount") or Config.LayerCount
	local hp = onion:GetAttribute("LayerHP") or 0
	local maxHp = math.max(onion:GetAttribute("LayerMaxHP") or 1, 1)

	if layer > count then
		onionTitle.Text = `🧅 ONION #{number} · CORE OPEN!`
		hpText.Text = "✨ ✨ ✨"
		hpFill.Size = UDim2.fromScale(0, 1)
		return
	end
	onionTitle.Text = `🧅 ONION #{number} · LAYER {layer}/{count}`
	hpText.Text = `{fmt(hp)} / {fmt(maxHp)} HP`
	TweenService:Create(hpFill, TweenInfo.new(0.12), { Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1) }):Play()
end
for _, attribute in { "OnionNumber", "Layer", "LayerCount", "LayerHP", "LayerMaxHP" } do
	onion:GetAttributeChangedSignal(attribute):Connect(updateOnionCard)
end
updateOnionCard()

local bagWasFull = false
local guideBeam: Beam? = nil

local function setSellGuide(enabled: boolean)
	if guideBeam then
		guideBeam:Destroy()
		guideBeam = nil
	end
	if not enabled then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local stand = Workspace:FindFirstChild("SellStand")
	local pad = stand and stand:FindFirstChild("SellPad")
	if not root or not pad then
		return
	end
	local from = root:FindFirstChild("SellGuideFrom") or create("Attachment", { Name = "SellGuideFrom", Parent = root })
	local to = pad:FindFirstChild("SellGuideTo") or create("Attachment", { Name = "SellGuideTo", Position = Vector3.new(0, 1, 0), Parent = pad })
	guideBeam = create("Beam", {
		Attachment0 = from,
		Attachment1 = to,
		Color = ColorSequence.new(Theme.Green),
		Transparency = NumberSequence.new(0.2),
		Width0 = 0.8,
		Width1 = 0.8,
		FaceCamera = true,
		LightEmission = 1,
		Segments = 20,
		CurveSize0 = 6,
		Parent = root,
	})
end

local function updateBag()
	local peels = player:GetAttribute("Peels") or 0
	local capacity = math.max(player:GetAttribute("Capacity") or 1, 1)
	local ratio = math.clamp(peels / capacity, 0, 1)
	local full = peels >= capacity
	TweenService:Create(bagFill, TweenInfo.new(0.15), {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = if full then Theme.Red elseif ratio > 0.7 then Theme.Gold else Theme.Green,
	}):Play()
	bagText.Text = if full then "BAG FULL! GO SELL ➜" else `{fmt(peels)} / {fmt(capacity)} peels`
	if full ~= bagWasFull then
		bagWasFull = full
		setSellGuide(full)
		if full then
			UIKit.pop(bagCard, 1.2)
			toast("🎒 Your bag is full! Follow the green line to SELL", Theme.Red)
		end
	end
end

local function updateCurrencies()
	coinLabel.Text = `🪙 {fmt(player:GetAttribute("Coins") or 0)}`
	local points = player:GetAttribute("SkillPoints") or 0
	spLabel.Text = `⭐ {fmt(points)} SP`
	skillBadge.Visible = points > 0
	skillBadge.Text = tostring(points)
end

player.AttributeChanged:Connect(function(attribute)
	if attribute == "Peels" or attribute == "Capacity" then
		updateBag()
	elseif attribute == "Coins" or attribute == "SkillPoints" then
		updateCurrencies()
	end
end)
updateBag()
updateCurrencies()

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	setSellGuide(bagWasFull)
end)

---------------------------------------------------------------- Sounds & shake

local function makeSound(id: string, volume: number): Sound
	return create("Sound", { SoundId = id, Volume = volume })
end
local peelSound = makeSound("rbxasset://sounds/swordslash.wav", 0.3)
local popSound = makeSound("rbxasset://sounds/electronicpingshort.wav", 0.5)

local function playSound(template: Sound, pitch: number)
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

local shakeStrength = 0
RunService:BindToRenderStep("OnionShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeStrength < 0.01 then
		shakeStrength = 0
		return
	end
	local s = shakeStrength
	camera.CFrame *= CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
	shakeStrength *= 0.88 ^ (dt * 60)
end)

local function shake(amount: number)
	shakeStrength = math.max(shakeStrength, amount)
end

---------------------------------------------------------------- Popups

local function popupAt(screenPos: Vector2, text: string, color: Color3, size: number)
	local label = UIKit.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(screenPos.X + math.random(-24, 24), screenPos.Y),
		Size = UDim2.fromOffset(size * 3.5, size),
		Text = text,
		TextColor3 = color,
		Parent = popupLayer,
	})
	UIKit.pop(label, 1.6)
	TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 80),
		TextTransparency = 1,
	}):Play()
	Debris:AddItem(label, 0.85)
end

local function popupWorld(worldPos: Vector3, text: string, color: Color3, size: number)
	local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
	if onScreen then
		popupAt(Vector2.new(screenPos.X, screenPos.Y), text, color, size)
	end
end

local function guiCenter(gui: GuiObject): Vector2
	return gui.AbsolutePosition + gui.AbsoluteSize / 2
end

-- Coins fly from the bag into the coin counter when you sell.
local function coinShower(count: number)
	local from = guiCenter(bagCard)
	local to = guiCenter(coinPill)
	for i = 1, count do
		local coin = UIKit.text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(from.X + math.random(-80, 80), from.Y + math.random(-30, 10)),
			Size = UDim2.fromOffset(34, 34),
			Text = "🪙",
			Parent = popupLayer,
		})
		task.delay(i * 0.035, function()
			local tween = TweenService:Create(coin, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(to.X, to.Y),
			})
			tween:Play()
			tween.Completed:Wait()
			coin:Destroy()
			UIKit.pop(coinPill, 1.08)
		end)
	end
end

---------------------------------------------------------------- Peeling

local activeInput: InputObject? = nil
local lastPeelTime = 0
local baseSizes: { [BasePart]: Vector3 } = {}
local pendingHits: { Vector3 } = {}
local lastFullWarning = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { onion }

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		activeInput = input
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == activeInput then
		activeInput = nil
	end
end)

local function pointerRay(input: InputObject): Ray
	if input.UserInputType == Enum.UserInputType.Touch then
		return camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	end
	local mouse = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouse.X, mouse.Y)
end

local function playSlash()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool then
		-- The default Animate script plays a slash when it sees this value.
		create("StringValue", { Name = "toolanim", Value = "Slash", Parent = tool })
	end
end

local function spawnLocalChips(part: BasePart, position: Vector3, normal: Vector3)
	for _ = 1, 3 do
		local chip = create("Part", {
			Size = Vector3.new(0.8, 0.2, 0.8),
			Color = part.Color,
			Material = part.Material,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(position),
		})
		chip.AssemblyLinearVelocity = (normal + Vector3.new(math.random() - 0.5, 1, math.random() - 0.5)) * 25
		chip.AssemblyAngularVelocity = Vector3.new(math.random(), math.random(), math.random()) * 20
		chip.Parent = Workspace
		Debris:AddItem(chip, 1.2)
	end
end

local function localHitFeedback(part: BasePart, position: Vector3, normal: Vector3)
	spawnLocalChips(part, position, normal)
	playSound(peelSound, 0.9 + math.random() * 0.3)
	playSlash()

	local base = baseSizes[part] or part.Size
	baseSizes[part] = base
	part.Size = base
	TweenService:Create(part, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
		Size = base * 0.97,
	}):Play()
end

---------------------------------------------------------------- Tears

local blur = create("BlurEffect", { Name = "OnionTearsBlur", Size = 0, Parent = Lighting })
local tint = create("ColorCorrectionEffect", { Name = "OnionTearsTint", Parent = Lighting })
local intensity = 0
local tearAccumulator = 0
local cryWarned = false

local function targetIntensity(): number
	local layerIndex = onion:GetAttribute("Layer") or 1
	local count = onion:GetAttribute("LayerCount") or Config.LayerCount
	local layerPart = onion:FindFirstChild("Layer" .. layerIndex) :: BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not layerPart or not root then
		return 0
	end
	local depth = math.clamp((layerIndex - 1) / count, 0, 1)
	local distance = (root.Position - layerPart.Position).Magnitude - layerPart.Size.X / 2
	local closeness = math.clamp(1 - distance / 60, 0, 1)
	return (0.1 + depth * 0.9) * closeness * Config.GetTearMultiplier(skill("ThickSkin"))
end

local function spawnTear()
	local x = (if math.random() < 0.5 then 0.4 else 0.6) + (math.random() - 0.5) * 0.06
	local tear = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(x, 0.38),
		Size = UDim2.fromOffset(14, 20),
		BackgroundColor3 = Color3.fromRGB(120, 190, 255),
		BackgroundTransparency = 0.1,
		Parent = tearLayer,
	}, { UIKit.corner(10), UIKit.stroke(2, Color3.fromRGB(40, 90, 170), true) })
	local duration = 1.2 + math.random() * 0.6
	TweenService:Create(tear, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.04, 1.1),
		BackgroundTransparency = 0.6,
	}):Play()
	Debris:AddItem(tear, duration + 0.1)
end

local function updateTears(dt: number)
	intensity += (targetIntensity() - intensity) * math.min(1, dt * 2)
	blur.Size = intensity * 10
	tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(165, 200, 255), intensity)
	tint.Saturation = -0.3 * intensity

	tearAccumulator += dt * intensity * 8
	while tearAccumulator >= 1 do
		tearAccumulator -= 1
		spawnTear()
	end

	if intensity > 0.6 and not cryWarned then
		cryWarned = true
		announce("😭 THE ONION IS MAKING YOU CRY 😭", Theme.Blue, 2.5)
		if skill("ThickSkin") < 3 then
			task.delay(2.6, toast, "🥽 Tip: 'Thick Skin' in the Skill Tree stops the tears", Theme.Blue)
		end
	end
end

---------------------------------------------------------------- Main loop

RunService.Heartbeat:Connect(function(dt)
	local input = activeInput
	if input and os.clock() - lastPeelTime >= Config.GetSwingInterval(skill("Quick")) then
		local ray = pointerRay(input)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
		local part = result and result.Instance
		if result and part and part:IsA("BasePart") and string.match(part.Name, "^Layer") then
			lastPeelTime = os.clock()
			peelRemote:FireServer()
			table.insert(pendingHits, result.Position)
			if #pendingHits > 10 then
				table.remove(pendingHits, 1)
			end
			localHitFeedback(part, result.Position, result.Normal)
		end
	end
	updateTears(dt)
end)

---------------------------------------------------------------- Server events

onionEvent.OnClientEvent:Connect(function(kind: string, ...)
	if kind == "Hit" then
		local damage, crit, golden, added, full = ...
		local position = table.remove(pendingHits, 1)
		if not position then
			return
		end
		if crit then
			popupWorld(position, `💥 CRIT {fmt(damage)}!`, Theme.Orange, 44)
			shake(0.6)
		end
		if golden then
			popupWorld(position, `✨ +{fmt(added)} GOLDEN!`, Theme.Gold, 44)
			playSound(popSound, 1.6)
		elseif added > 0 then
			popupWorld(position, `+{fmt(added)}`, Color3.new(1, 1, 1), 32)
		elseif full and os.clock() - lastFullWarning > 1.5 then
			lastFullWarning = os.clock()
			popupWorld(position, "BAG FULL!", Theme.Red, 36)
		end
	elseif kind == "Collected" then
		local added, _, position = ...
		if added > 0 then
			popupWorld(position, `+{fmt(added)} 🧅`, Theme.Green, 30)
			playSound(popSound, 1.2 + math.random() * 0.3)
		end
	elseif kind == "Sold" then
		local peels, coins = ...
		coinShower(math.clamp(math.floor(peels / 5), 6, 18))
		playSound(popSound, 0.7)
		announce(`SOLD {fmt(peels)} PEELS\n+🪙 {fmt(coins)}`, Theme.Gold, 2)
	elseif kind == "SkillPoint" then
		local amount = ...
		toast(`⭐ +{amount} Skill Point! Open the Skill Tree`, Theme.Purple)
		UIKit.pop(menuButtons.Skills, 1.25)
	elseif kind == "LayerPeeled" then
		local index = ...
		table.clear(baseSizes)
		table.clear(pendingHits)
		cryWarned = false
		shake(1.5)
		playSound(popSound, 0.8 + index * 0.05)
		announce(`LAYER {index} PEELED! 🧅`, Theme.Pink, 1.5)
	elseif kind == "OnionDone" then
		shake(3)
		announce("✨ THE CORE IS OPEN! ✨", Theme.Gold, 3)
	elseif kind == "Prize" then
		local displayName, coins, skillPoints, color = ...
		shake(2)
		playSound(popSound, 1.4)
		local extra = if skillPoints > 0 then `  +⭐{skillPoints}` else ""
		announce(`YOU FOUND: {displayName}\n+🪙 {fmt(coins)}{extra}`, color, 5)
	elseif kind == "Announcement" then
		local text, color = ...
		announce(text, color, 5)
	elseif kind == "OnionSpawned" then
		local number = ...
		announce(`ONION #{number} SPAWNED – EVEN THICKER! 🧅`, Color3.new(1, 1, 1), 3)
	end
end)
