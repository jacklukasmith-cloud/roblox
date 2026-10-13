--[[
	UI toolkit: theme, element builder, buttons, pop-up panels, responsive grids, toasts.
	Everything is built in design units inside Layout's scaled Root frame.
]]

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Layout = require(script.Parent.Layout)
local Sound = require(script.Parent.Sound)

local Ui = {}

local rgb = Color3.fromRGB
Ui.Theme = {
	Background = rgb(24, 17, 42),
	Panel = rgb(38, 27, 66),
	PanelLight = rgb(56, 40, 96),
	Card = rgb(62, 45, 104),
	Accent = rgb(170, 110, 255),
	Text = rgb(255, 255, 255),
	SubText = rgb(205, 195, 235),
	Good = rgb(95, 220, 125),
	Bad = rgb(255, 95, 105),
	Gold = rgb(255, 205, 70),
	Essence = rgb(120, 255, 200),
	Trophy = rgb(0, 235, 215),
	Power = rgb(255, 150, 110),
	Outline = rgb(14, 8, 28),
	Font = Enum.Font.FredokaOne,
}
local T = Ui.Theme

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

function Ui.round(): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Ui.stroke(color: Color3?, thickness: number?): UIStroke
	return Ui.new("UIStroke", {
		Color = color or T.Outline,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Ui.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

-- Vertical light-to-dark gradient that makes flat colours look "glossy"
function Ui.gloss(strength: number?): UIGradient
	local s = strength or 0.25
	return Ui.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - s, 1 - s, 1 - s)),
		Rotation = 90,
	})
end

function Ui.text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = T.Font,
		TextColor3 = T.Text,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for k, v in props do
		defaults[k] = v
	end
	local label = Ui.new("TextLabel", defaults)
	Ui.new("UIStroke", { Thickness = 1.6, Color = T.Outline, Transparency = 0.15, Parent = label })
	Ui.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 34, MinTextSize = 7, Parent = label })
	return label
end

-- A chunky glossy button. onClick runs on mouse, touch and gamepad A.
function Ui.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults = {
		BackgroundColor3 = T.Accent,
		Font = T.Font,
		TextColor3 = T.Text,
		TextScaled = true,
		AutoButtonColor = false,
		Selectable = true,
		Size = UDim2.fromOffset(130, 44),
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = Ui.new("TextButton", defaults, { Ui.corner(12), Ui.stroke(T.Outline, 2.5), Ui.gloss(0.3) })
	Ui.new("UIStroke", {
		Thickness = 1.5,
		Color = T.Outline,
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = button,
	})
	Ui.new("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 8, Parent = button })
	Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = button,
	})
	local scale = Ui.new("UIScale", { Parent = button })
	local function tweenScale(to: number, time: number)
		TweenService:Create(scale, TweenInfo.new(time, Enum.EasingStyle.Back), { Scale = to }):Play()
	end
	button.MouseEnter:Connect(function()
		tweenScale(1.05, 0.12)
	end)
	button.MouseLeave:Connect(function()
		tweenScale(1, 0.12)
	end)
	button.SelectionGained:Connect(function()
		tweenScale(1.08, 0.12)
	end)
	button.SelectionLost:Connect(function()
		tweenScale(1, 0.12)
	end)
	button.Activated:Connect(function()
		scale.Scale = 0.9
		tweenScale(1, 0.18)
		Sound.Play("Click", 1.1)
		onClick()
	end)
	return button
end

-- Pop-up panels: one open at a time, dim the screen, tap outside to close -----------------
type PanelInfo = { Backdrop: TextButton, Frame: Frame, Size: UDim2? }
local panels: { [string]: PanelInfo } = {}
local onOpen: { [string]: () -> () } = {}
local openName: string? = nil

local function applyPanelSize(info: PanelInfo)
	if Layout.Compact then
		info.Frame.Size = UDim2.fromScale(0.96, 0.94)
	else
		info.Frame.Size = info.Size or UDim2.fromScale(0.62, 0.8)
	end
end

function Ui.panel(parent: Instance, name: string, title: string, size: UDim2?, icon: string?): (Frame, Frame)
	local backdrop = Ui.new("TextButton", {
		Name = name .. "Backdrop",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	})
	local frame = Ui.new("Frame", {
		Name = name,
		Active = true, -- clicks on the panel don't fall through to the backdrop
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = T.Panel,
		Parent = backdrop,
	}, { Ui.corner(18), Ui.stroke(T.Outline, 3) })
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(940, 620), MinSize = Vector2.new(320, 240), Parent = frame })
	-- Header bar
	local header = Ui.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = T.Accent,
		Parent = frame,
	}, { Ui.corner(18), Ui.gloss(0.35) })
	-- square off the header's bottom corners
	Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		BackgroundColor3 = T.Accent,
		BorderSizePixel = 0,
		Parent = header,
	}, { Ui.gloss(0.35) })
	Ui.text({
		Text = (if icon then icon .. "  " else "") .. title,
		Size = UDim2.new(1, -90, 0, 40),
		Position = UDim2.fromOffset(16, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = header,
	})
	Ui.button({
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(44, 44),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		BackgroundColor3 = T.Bad,
		ZIndex = 3,
		Parent = header,
	}, function()
		Ui.toggle(name, false)
	end)
	local content = Ui.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -28, 1, -76),
		Parent = frame,
	})
	local info: PanelInfo = { Backdrop = backdrop, Frame = frame, Size = size }
	panels[name] = info
	applyPanelSize(info)
	backdrop.Activated:Connect(function()
		Ui.toggle(name, false)
	end)
	return frame, content
end

Layout.Changed:Connect(function()
	for _, info in panels do
		applyPanelSize(info)
	end
end)

function Ui.onPanelOpen(name: string, callback: () -> ())
	onOpen[name] = callback
end

local function firstSelectable(root: Instance): GuiObject?
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable and d.Visible and d.Name ~= "Close" then
			return d
		end
	end
	return nil
end

function Ui.toggle(name: string, forceOpen: boolean?)
	local target = panels[name]
	if not target then
		return
	end
	local open = if forceOpen ~= nil then forceOpen else not target.Backdrop.Visible
	for other, info in panels do
		info.Backdrop.Visible = other == name and open
	end
	openName = if open then name else nil
	if open then
		local scale = target.Frame:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = target.Frame })
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if onOpen[name] then
			onOpen[name]()
		end
		if Layout.Gamepad then
			task.defer(function()
				GuiService.SelectedObject = firstSelectable(target.Frame)
			end)
		end
	elseif Layout.Gamepad then
		GuiService.SelectedObject = nil
	end
end

function Ui.isOpen(name: string): boolean
	return panels[name] ~= nil and panels[name].Backdrop.Visible
end

function Ui.openPanel(): string?
	return openName
end

function Ui.closeAll()
	for name in panels do
		panels[name].Backdrop.Visible = false
	end
	openName = nil
end

-- Responsive grid: cards are at least minWidth wide and stretch to fill each row.
function Ui.autoGrid(scroll: ScrollingFrame, minWidth: number, height: number, gap: number?): UIGridLayout
	local g = gap or 8
	local grid = Ui.new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(g, g),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	grid:SetAttribute("AutoMinWidth", minWidth) -- lets layout previews reproduce the sizing
	local function resize()
		local width = scroll.AbsoluteSize.X / math.max(Layout.Scale, 0.01) - scroll.ScrollBarThickness - 4
		local cols = math.max(2, math.floor((width + g) / (minWidth + g)))
		grid.CellSize = UDim2.new(1 / cols, -g * (cols - 1) / cols - 2, 0, height)
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	Layout.Changed:Connect(resize)
	resize()
	return grid
end

-- Toasts: pill notifications under the top banner (clear of mobile controls) -------------
local toastHolder: Frame? = nil

function Ui.initToasts(parent: Instance)
	toastHolder = Ui.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.fromOffset(560, 170),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = parent,
	}, {
		Ui.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function place()
		if toastHolder then
			-- sits just above the bottom currency bar
			toastHolder.Position = UDim2.new(0.5, 0, 1, Layout.pick(-84, -128))
			toastHolder.Size = UDim2.fromOffset(Layout.pick(440, 560), Layout.pick(110, 170))
		end
	end
	Layout.Changed:Connect(place)
	place()
end

local toastCount = 0
function Ui.toast(text: string, color: Color3?)
	if not toastHolder then
		return
	end
	toastCount += 1
	local pill = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = toastCount, -- newest at the bottom, nearest the currency bar
		ZIndex = 30,
		Parent = toastHolder,
	}, { Ui.round(), Ui.stroke(color or T.Accent, 2) })
	local label = Ui.text({
		Text = text,
		TextColor3 = color or T.Text,
		Size = UDim2.new(1, -24, 1, -8),
		Position = UDim2.fromOffset(12, 4),
		ZIndex = 31,
		MaxTextSize = 22,
		Parent = pill,
	})
	local scale = Ui.new("UIScale", { Scale = 0.6, Parent = pill })
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local pills = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(pills, child)
		end
	end
	if #pills > Layout.pick(2, 4) then
		table.sort(pills, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		pills[1]:Destroy() -- oldest
	end
	task.delay(4, function()
		if pill.Parent then
			TweenService:Create(pill, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.4)
			pill:Destroy()
		end
	end)
end

return Ui
