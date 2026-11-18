-- Small UI toolkit for the chunky cartoon look: thick outlines, gradients, bouncy buttons.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne

UIKit.Theme = {
	Panel = Color3.fromRGB(44, 32, 74),
	PanelDark = Color3.fromRGB(26, 19, 46),
	Stroke = Color3.fromRGB(14, 9, 26),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(185, 175, 215),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(85, 215, 105),
	Red = Color3.fromRGB(235, 75, 85),
	Purple = Color3.fromRGB(170, 95, 255),
	Pink = Color3.fromRGB(255, 105, 200),
	Orange = Color3.fromRGB(255, 140, 50),
	Blue = Color3.fromRGB(80, 170, 255),
	Disabled = Color3.fromRGB(90, 84, 110),
}

local Theme = UIKit.Theme

function UIKit.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local create = UIKit.create

function UIKit.corner(radius: number?): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function UIKit.stroke(thickness: number?, color: Color3?, border: boolean?): UIStroke
	return create("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Theme.Stroke,
		ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function UIKit.gradient(top: Color3, bottom: Color3): UIGradient
	return create("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) })
end

-- Lighter on top, darker at the bottom: the classic glossy cartoon button.
function UIKit.shade(color: Color3): UIGradient
	local h, s, v = color:ToHSV()
	return UIKit.gradient(Color3.fromHSV(h, s * 0.8, math.min(v * 1.15, 1)), Color3.fromHSV(h, s, v * 0.75))
end

function UIKit.text(props: { [string]: any }): TextLabel
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextScaled = true,
		TextColor3 = Theme.Text,
	}, { UIKit.stroke(2) })
	for key, value in props do
		if key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

function UIKit.panel(props: { [string]: any }, color: Color3?): Frame
	local frame = create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, { UIKit.corner(16), UIKit.stroke(3, nil, true), UIKit.shade(color or Theme.Panel) })
	for key, value in props do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

-- Returns the button and its text label. Use UIKit.setButtonColor to recolor.
function UIKit.button(props: { [string]: any }, color: Color3, text: string): (TextButton, TextLabel)
	local button = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, { UIKit.corner(12), UIKit.stroke(3, nil, true), UIKit.shade(color), create("UIScale", {}) })
	for key, value in props do
		if key ~= "Parent" then
			(button :: any)[key] = value
		end
	end
	local label = UIKit.text({
		Name = "Label",
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = text,
		Parent = button,
	})
	button.MouseEnter:Connect(function()
		TweenService:Create(button.UIScale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button.UIScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(button.UIScale, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(button.UIScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	if props.Parent then
		button.Parent = props.Parent
	end
	return button, label
end

function UIKit.setButtonColor(button: GuiObject, color: Color3)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient:Destroy()
	end
	UIKit.shade(color).Parent = button
end

-- Quick "pop" on any GuiObject that has (or gets) a UIScale.
function UIKit.pop(gui: GuiObject, amount: number?)
	local scale = gui:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = gui })
	local base = scale:GetAttribute("Base") or 1
	scale.Scale = base * (amount or 1.2)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = base }):Play()
end

-- Scales a HUD element down on small screens (phones) and keeps it updated.
function UIKit.autoScale(gui: GuiObject, designWidth: number, designHeight: number)
	local scale = gui:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = gui })
	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local value = math.clamp(math.min(viewport.X / designWidth, viewport.Y / designHeight), 0.55, 1)
		scale:SetAttribute("Base", value)
		scale.Scale = value
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

return UIKit
