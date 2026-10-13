--[[ Tiny UI toolkit: theme, element builder, buttons, panels and toasts. ]]

local TweenService = game:GetService("TweenService")

local Sound = require(script.Parent.Sound)

local Ui = {}

local rgb = Color3.fromRGB
Ui.Theme = {
	Background = rgb(28, 20, 48),
	Panel = rgb(42, 30, 72),
	Card = rgb(58, 42, 98),
	Accent = rgb(170, 110, 255),
	Text = rgb(255, 255, 255),
	SubText = rgb(200, 190, 230),
	Good = rgb(110, 230, 140),
	Bad = rgb(255, 110, 110),
	Gold = rgb(255, 210, 80),
	Essence = rgb(140, 255, 200),
	Trophy = rgb(0, 255, 225),
	Font = Enum.Font.FredokaOne,
}

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function Ui.corner(radius: number?): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Ui.stroke(color: Color3?, thickness: number?): UIStroke
	return Ui.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Ui.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Ui.text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Ui.Theme.Font,
		TextColor3 = Ui.Theme.Text,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for k, v in props do
		defaults[k] = v
	end
	local label = Ui.new("TextLabel", defaults)
	Ui.new("UIStroke", { Thickness = 1.5, Transparency = 0.3, Parent = label })
	return label
end

function Ui.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults = {
		BackgroundColor3 = Ui.Theme.Accent,
		Font = Ui.Theme.Font,
		TextColor3 = Ui.Theme.Text,
		TextScaled = true,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(120, 40),
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = Ui.new("TextButton", defaults, { Ui.corner(10), Ui.stroke(Color3.new(0, 0, 0), 2) })
	Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = button,
	})
	local scale = Ui.new("UIScale", { Parent = button })
	button.MouseButton1Click:Connect(function()
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		Sound.Play("Click", 1.1)
		onClick()
	end)
	return button
end

-- Panels: only one open at a time --------------------------------------------------
local panels: { [string]: Frame } = {}
local onOpen: { [string]: () -> () } = {}

function Ui.panel(screen: ScreenGui, name: string, title: string, size: UDim2?): (Frame, Frame)
	local frame = Ui.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size or UDim2.fromScale(0.55, 0.65),
		BackgroundColor3 = Ui.Theme.Panel,
		Visible = false,
		Parent = screen,
	}, { Ui.corner(16), Ui.stroke(Ui.Theme.Accent, 3) })
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(820, 560), MinSize = Vector2.new(300, 260), Parent = frame })
	Ui.text({
		Text = title,
		Size = UDim2.new(1, -60, 0, 40),
		Position = UDim2.fromOffset(14, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	Ui.button({
		Text = "X",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -44, 0, 8),
		BackgroundColor3 = Ui.Theme.Bad,
		Parent = frame,
	}, function()
		frame.Visible = false
	end)
	local content = Ui.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 1, -64),
		Parent = frame,
	})
	panels[name] = frame
	return frame, content
end

function Ui.onPanelOpen(name: string, callback: () -> ())
	onOpen[name] = callback
end

function Ui.toggle(name: string, forceOpen: boolean?)
	local target = panels[name]
	if not target then
		return
	end
	local open = if forceOpen ~= nil then forceOpen else not target.Visible
	for other, frame in panels do
		frame.Visible = other == name and open
	end
	if open then
		local scale = target:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = target })
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if onOpen[name] then
			onOpen[name]()
		end
	end
end

function Ui.isOpen(name: string): boolean
	return panels[name] ~= nil and panels[name].Visible
end

-- Toasts ------------------------------------------------------------------------------
local toastHolder: Frame? = nil

function Ui.initToasts(screen: ScreenGui)
	toastHolder = Ui.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(520, 220),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Ui.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local toastCount = 0
function Ui.toast(text: string, color: Color3?)
	if not toastHolder then
		return
	end
	toastCount += 1
	local label = Ui.text({
		Text = text,
		TextColor3 = color or Ui.Theme.Text,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = toastCount,
		Parent = toastHolder,
	})
	local items = toastHolder:GetChildren()
	local labels = {}
	for _, child in items do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels > 5 then
		table.sort(labels, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		labels[1]:Destroy()
	end
	task.delay(4, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			task.wait(0.5)
			label:Destroy()
		end
	end)
end

return Ui
