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

-- Builder Sans is Roblox's modern UI font; fall back to Gotham on older clients
local function pickFont(name: string, fallback: Enum.Font): Enum.Font
	local ok, font = pcall(function()
		return (Enum.Font :: any)[name]
	end)
	return if ok and font then font else fallback
end

Ui.Theme = {
	-- surfaces (dark "frosted glass")
	Glass = rgb(16, 18, 34),
	GlassLight = rgb(34, 38, 66),
	Background = rgb(16, 18, 34),
	Panel = rgb(20, 22, 40),
	PanelLight = rgb(30, 33, 58),
	Card = rgb(34, 38, 66),
	Edge = rgb(255, 255, 255), -- thin highlight edge, used with high transparency
	-- brand + states
	Accent = rgb(124, 92, 255),
	Text = rgb(255, 255, 255),
	SubText = rgb(168, 176, 210),
	Good = rgb(46, 196, 118),
	Bad = rgb(232, 70, 92),
	Gold = rgb(255, 196, 64),
	Essence = rgb(96, 232, 190),
	Trophy = rgb(84, 210, 255),
	Power = rgb(255, 140, 100),
	Outline = rgb(6, 6, 16),
	Font = pickFont("BuilderSansBold", Enum.Font.GothamBold),
	FontHeavy = pickFont("BuilderSansExtraBold", Enum.Font.GothamBlack),
	FontRegular = pickFont("BuilderSansMedium", Enum.Font.GothamMedium),
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

function Ui.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Ui.new("UIStroke", {
		Color = color or T.Edge,
		Thickness = thickness or 1.2,
		Transparency = transparency or (if color then 0 else 0.86),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- A frosted-glass surface: dark, slightly see-through, with a thin light edge
function Ui.glass(props: { [string]: any }, children: { Instance }?): Frame
	local defaults: { [string]: any } = {
		BackgroundColor3 = T.Glass,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}
	for k, v in props do
		defaults[k] = v
	end
	local frame = Ui.new("Frame", defaults, children)
	Ui.stroke().Parent = frame
	Ui.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 220)),
		Rotation = 90,
		Parent = frame,
	})
	return frame
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

-- Text label. Extra option (not a Roblox property): MaxTextSize caps the auto-scaled size.
function Ui.text(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = T.Font,
		TextColor3 = T.Text,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 24),
	}
	local maxSize = 32
	for k, v in props do
		if k == "MaxTextSize" then
			maxSize = v
		else
			defaults[k] = v
		end
	end
	local label = Ui.new("TextLabel", defaults)
	-- soft outline keeps text readable over the bright 3D world
	Ui.new("UIStroke", { Thickness = 1, Color = T.Outline, Transparency = 0.55, Parent = label })
	Ui.new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 7, Parent = label })
	return label
end

-- Buttons. props.Variant = "Primary" (default) | "Secondary" | "Success" | "Danger" | "Gold",
-- or set BackgroundColor3 directly. onClick runs on mouse, touch and gamepad A.
local VARIANTS = {
	Primary = T.Accent,
	Secondary = T.GlassLight,
	Success = T.Good,
	Danger = T.Bad,
	Gold = T.Gold,
}

function Ui.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults: { [string]: any } = {
		BackgroundColor3 = VARIANTS[props.Variant or "Primary"] or T.Accent,
		Font = T.Font,
		TextColor3 = T.Text,
		TextScaled = true,
		AutoButtonColor = false,
		Selectable = true,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(130, 42),
	}
	for k, v in props do
		if k ~= "Variant" then
			defaults[k] = v
		end
	end
	if defaults.TextColor3 == T.Text and (props.Variant == "Gold") then
		defaults.TextColor3 = Color3.fromRGB(40, 28, 6)
	end
	local button = Ui.new("TextButton", defaults, { Ui.corner(10), Ui.stroke(), Ui.gloss(0.14) })
	Ui.new("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 8, Parent = button })
	Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = button,
	})
	local scale = Ui.new("UIScale", { Parent = button })
	local function tweenScale(to: number, time: number)
		TweenService:Create(scale, TweenInfo.new(time, Enum.EasingStyle.Quad), { Scale = to }):Play()
	end
	button.MouseEnter:Connect(function()
		tweenScale(1.04, 0.1)
	end)
	button.MouseLeave:Connect(function()
		tweenScale(1, 0.1)
	end)
	button.SelectionGained:Connect(function()
		tweenScale(1.06, 0.1)
	end)
	button.SelectionLost:Connect(function()
		tweenScale(1, 0.1)
	end)
	button.Activated:Connect(function()
		scale.Scale = 0.94
		tweenScale(1, 0.14)
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
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Parent = backdrop,
	}, { Ui.corner(16), Ui.stroke(nil, 1.4) })
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(940, 620), MinSize = Vector2.new(320, 240), Parent = frame })
	-- Header: icon + title on the left, round close button on the right, hairline divider below
	local header = Ui.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	if icon then
		local chip = Ui.new("Frame", {
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.fromOffset(16, 10),
			BackgroundColor3 = T.Accent,
			Parent = header,
		}, { Ui.corner(10), Ui.gloss(0.2) })
		Ui.text({
			Text = icon,
			Size = UDim2.fromScale(0.72, 0.72),
			Position = UDim2.fromScale(0.14, 0.14),
			Parent = chip,
		})
	end
	Ui.text({
		Text = title,
		Font = T.FontHeavy,
		Size = UDim2.new(1, -140, 0, 30),
		Position = UDim2.fromOffset(if icon then 60 else 18, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Parent = header,
	})
	Ui.button({
		Name = "Close",
		Text = "✕",
		Variant = "Secondary",
		Size = UDim2.fromOffset(38, 38),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Parent = header,
	}, function()
		Ui.toggle(name, false)
	end)
	Ui.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, -32, 0, 1),
		Position = UDim2.new(0, 16, 1, 0),
		BackgroundColor3 = T.Edge,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Parent = header,
	})
	local content = Ui.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.new(1, -32, 1, -80),
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
		Size = UDim2.fromOffset(440, 110),
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
	local pill = Ui.glass({
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 0.12,
		LayoutOrder = toastCount, -- newest at the bottom, nearest the currency bar
		ZIndex = 30,
		Parent = toastHolder,
	}, { Ui.round() })
	Ui.new("Frame", {
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		BackgroundColor3 = color or T.Accent,
		ZIndex = 31,
		Parent = pill,
	}, { Ui.round() })
	local label = Ui.text({
		Text = text,
		Font = T.FontRegular,
		TextColor3 = T.Text,
		Size = UDim2.new(1, -48, 1, -10),
		Position = UDim2.fromOffset(34, 5),
		ZIndex = 31,
		MaxTextSize = 18,
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
	if #pills > 2 then -- never more than 2 on screen
		table.sort(pills, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		pills[1]:Destroy() -- oldest
	end
	task.delay(3, function()
		if pill.Parent then
			TweenService:Create(pill, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.4)
			pill:Destroy()
		end
	end)
end

return Ui
