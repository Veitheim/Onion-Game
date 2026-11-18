-- Pop-up windows: Knife Shop, Bag Shop and Skill Tree.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local create = UIKit.create
local Theme = UIKit.Theme
local fmt = Config.FormatNumber

local player = Players.LocalPlayer
local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteFunction

local Menus = {}
Menus.OnToast = nil :: ((text: string, color: Color3) -> ())?
Menus.OnOpenChanged = nil :: ((name: string?) -> ())?

local windows: { [string]: Frame } = {}
local refreshers: { () -> () } = {}
local openName: string? = nil

local function toast(text: string, color: Color3)
	if Menus.OnToast then
		Menus.OnToast(text, color)
	end
end

local function makeWindow(gui: ScreenGui, name: string, title: string, color: Color3): Frame
	local window = UIKit.panel({
		Name = name .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(620, 500),
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	UIKit.autoScale(window, 700, 600)

	local titleBar = UIKit.panel({
		Size = UDim2.new(1, -90, 0, 52),
		Position = UDim2.fromOffset(16, -24),
		Parent = window,
	}, color)
	UIKit.text({
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleBar,
	})

	local close = UIKit.button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 4),
		Size = UDim2.fromOffset(50, 50),
		Parent = window,
	}, Theme.Red, "✕")
	close.Activated:Connect(function()
		Menus.Close()
	end)

	windows[name] = window
	return create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 40),
		Size = UDim2.new(1, -32, 1, -54),
		Parent = window,
	})
end

---------------------------------------------------------------- Knife / Bag shops

type TierDef = { Name: string, Icon: string, Cost: number }

local function buildTierShop(
	gui: ScreenGui,
	name: string,
	title: string,
	color: Color3,
	list: { any },
	attribute: string,
	action: string,
	statText: (def: any) -> string,
	currentText: string
)
	local content = makeWindow(gui, name, title, color)

	local coinsLabel = UIKit.text({
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Gold,
		Parent = content,
	})

	local scroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 1, -36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Muted,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = content,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(174, 206),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 10),
		}),
	})

	local cards = {}
	for index, def: TierDef in list do
		local card = UIKit.panel({ LayoutOrder = index, Parent = scroll }, Theme.PanelDark)
		local icon = UIKit.text({ Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 8), Text = def.Icon, Parent = card })
		UIKit.text({ Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 82), Text = def.Name, Parent = card })
		UIKit.text({
			Size = UDim2.new(1, -12, 0, 22),
			Position = UDim2.fromOffset(6, 110),
			Text = statText(def),
			TextColor3 = Theme.Muted,
			Parent = card,
		})
		local button, label = UIKit.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 46),
			Parent = card,
		}, Theme.Green, "")

		button.Activated:Connect(function()
			local owned = player:GetAttribute(attribute) or 1
			if index ~= owned + 1 then
				return
			end
			local ok, message = shopAction:InvokeServer(action)
			if ok then
				toast(`{def.Icon} {def.Name} unlocked!`, Theme.Green)
				UIKit.pop(card, 1.12)
			else
				toast(message or "Can't buy that yet", Theme.Red)
			end
		end)
		cards[index] = { icon = icon, button = button, label = label, state = "" }
	end

	table.insert(refreshers, function()
		local owned = player:GetAttribute(attribute) or 1
		local coins = player:GetAttribute("Coins") or 0
		coinsLabel.Text = `🪙 {fmt(coins)}`
		for index, card in cards do
			local def = list[index]
			local state, text, buttonColor
			if index == owned then
				state, text, buttonColor = "current", currentText, Theme.Purple
			elseif index < owned then
				state, text, buttonColor = "owned", "OWNED", Theme.Disabled
			elseif index == owned + 1 then
				local affordable = coins >= def.Cost
				state = if affordable then "buy" else "poor"
				text = `🪙 {fmt(def.Cost)}`
				buttonColor = if affordable then Theme.Green else Theme.Red
			else
				state, text, buttonColor = "locked", "🔒 LOCKED", Theme.Disabled
			end
			card.label.Text = text
			card.icon.TextTransparency = if state == "locked" then 0.6 else 0
			if card.state ~= state then
				card.state = state
				UIKit.setButtonColor(card.button, buttonColor)
			end
		end
	end)
end

---------------------------------------------------------------- Skill tree

local function buildSkillTree(gui: ScreenGui)
	local content = makeWindow(gui, "Skills", "🌳 SKILL TREE", Theme.Purple)
	local selected = "Sharp"

	local spLabel = UIKit.text({
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Gold,
		Parent = content,
	})

	local tree = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 310),
		Parent = content,
	})

	local function rowY(row: number): number
		return 40 + (row - 1) * 90
	end

	for b, branch in Config.Branches do
		UIKit.text({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new((b - 0.5) / 3, 0, 0, 0),
			Size = UDim2.fromOffset(170, 28),
			Text = branch.Name,
			TextColor3 = branch.Color,
			Parent = tree,
		})
	end

	local nodes = {}
	local lines: { [string]: Frame } = {}
	local refresh: () -> ()

	for id, def in Config.Skills do
		local x = (def.Branch - 0.5) / 3
		if def.Requires then
			lines[id] = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(x, 0, 0, rowY(def.Row - 1) + 76),
				Size = UDim2.fromOffset(8, 14),
				BorderSizePixel = 0,
				BackgroundColor3 = Theme.Disabled,
				Parent = tree,
			})
		end
		local node, label = UIKit.button({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(x, 0, 0, rowY(def.Row)),
			Size = UDim2.fromOffset(76, 76),
			Parent = tree,
		}, Config.Branches[def.Branch].Color, def.Icon)
		local pill = UIKit.text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(52, 22),
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.PanelDark,
			Parent = node,
		})
		UIKit.corner(11).Parent = pill
		node.Activated:Connect(function()
			selected = id
			refresh()
		end)
		nodes[id] = { node = node, label = label, pill = pill, state = "" }
	end

	local footer = UIKit.panel({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 96),
		Parent = content,
	}, Theme.PanelDark)
	local nameLabel = UIKit.text({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -210, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footer,
	})
	local descLabel = UIKit.text({
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -210, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Theme.Muted,
		Parent = footer,
	})
	local upgradeButton, upgradeLabel = UIKit.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(180, 64),
		Parent = footer,
	}, Theme.Green, "UPGRADE")
	local upgradeState = ""

	upgradeButton.Activated:Connect(function()
		local def = Config.Skills[selected]
		local ok, message = shopAction:InvokeServer("UpgradeSkill", selected)
		if ok then
			toast(`{def.Icon} {def.Name} upgraded!`, Theme.Purple)
			UIKit.pop(nodes[selected].node, 1.25)
		else
			toast(message or "Can't upgrade", Theme.Red)
		end
	end)

	local function level(id: string): number
		return player:GetAttribute("Skill_" .. id) or 0
	end

	refresh = function()
		local points = player:GetAttribute("SkillPoints") or 0
		spLabel.Text = `⭐ {points} Skill Points`

		for id, node in nodes do
			local def = Config.Skills[id]
			local branchColor = Config.Branches[def.Branch].Color
			local lvl = level(id)
			local locked = def.Requires ~= nil and level(def.Requires) < 1
			local state = if locked then "locked" elseif lvl >= def.Max then "max" else "open"
			node.pill.Text = `{lvl}/{def.Max}`
			node.label.Text = if locked then "🔒" else def.Icon
			if node.state ~= state then
				node.state = state
				UIKit.setButtonColor(node.node, if locked then Theme.Disabled elseif state == "max" then Theme.Gold else branchColor)
			end
			local border = node.node:FindFirstChildOfClass("UIStroke")
			if border then
				border.Color = if id == selected then Color3.new(1, 1, 1) else Theme.Stroke
				border.Thickness = if id == selected then 4 else 3
			end
			local line = lines[id]
			if line then
				line.BackgroundColor3 = if locked then Theme.Disabled else branchColor
			end
		end

		local def = Config.Skills[selected]
		local lvl = level(selected)
		local locked = def.Requires ~= nil and level(def.Requires) < 1
		nameLabel.Text = `{def.Icon} {def.Name}  ({lvl}/{def.Max})`
		descLabel.Text = if locked and def.Requires
			then `{def.Desc}\nNeeds {Config.Skills[def.Requires].Name} first`
			else def.Desc

		local state, color
		if lvl >= def.Max then
			state, color = "MAXED", Theme.Gold
			upgradeLabel.Text = "MAXED"
		elseif locked then
			state, color = "locked", Theme.Disabled
			upgradeLabel.Text = "🔒 LOCKED"
		else
			local cost = Config.GetSkillCost(lvl)
			local affordable = points >= cost
			state = if affordable then "buy" else "poor"
			color = if affordable then Theme.Green else Theme.Red
			upgradeLabel.Text = `UPGRADE ⭐{cost}`
		end
		if state ~= upgradeState then
			upgradeState = state
			UIKit.setButtonColor(upgradeButton, color)
		end
	end
	table.insert(refreshers, refresh)
end

---------------------------------------------------------------- API

function Menus.Refresh()
	for _, refresh in refreshers do
		refresh()
	end
end

function Menus.Close()
	if openName then
		windows[openName].Visible = false
	end
	openName = nil
	if Menus.OnOpenChanged then
		Menus.OnOpenChanged(nil)
	end
end

function Menus.Open(name: string)
	local window = windows[name]
	if not window then
		return
	end
	if openName and openName ~= name then
		windows[openName].Visible = false
	end
	openName = name
	window.Visible = true
	Menus.Refresh()
	UIKit.pop(window, 0.85)
	if Menus.OnOpenChanged then
		Menus.OnOpenChanged(name)
	end
end

function Menus.Toggle(name: string)
	if openName == name then
		Menus.Close()
	else
		Menus.Open(name)
	end
end

function Menus.IsOpen(): boolean
	return openName ~= nil
end

function Menus.Init(gui: ScreenGui)
	buildTierShop(gui, "Knives", "🔪 KNIFE SHOP", Theme.Red, Config.Knives, "Knife", "BuyKnife", function(def)
		return `⚔ {fmt(def.Damage)} damage`
	end, "EQUIPPED")
	buildTierShop(gui, "Bags", "🎒 BAG SHOP", Theme.Green, Config.Bags, "Bag", "BuyBag", function(def)
		return `Holds {fmt(def.Capacity)} peels`
	end, "IN USE")
	buildSkillTree(gui)

	player.AttributeChanged:Connect(function()
		if openName then
			Menus.Refresh()
		end
	end)
end

return Menus
