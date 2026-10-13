--[[
	Responsive layout for every device.

	All UI lives inside one "Root" frame that is scaled with a UIScale, so the rest of the
	code can use fixed "design units". The design canvas is about 1280x720 on PC/tablet and
	about 900x430 on phones ("compact"), where elements are arranged more tightly and
	touch targets stay big.

	Layout.Changed fires when the screen size or input type changes (rotate a tablet,
	plug in a controller...).
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Layout = {
	Compact = false, -- phone-sized screen
	Touch = false, -- touch is the main input
	Gamepad = false, -- a controller is being used
	Scale = 1,
	Size = Vector2.new(1280, 720), -- design-unit size of the root (screen size / scale)
}

local changed = Instance.new("BindableEvent")
Layout.Changed = changed.Event

local root: Frame? = nil
local uiScale: UIScale? = nil

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local function lastInputIsGamepad(): boolean
	local t = UserInputService:GetLastInputType()
	return t == Enum.UserInputType.Gamepad1
		or t == Enum.UserInputType.Gamepad2
		or t == Enum.UserInputType.Gamepad3
		or t == Enum.UserInputType.Gamepad4
end

function Layout.Update()
	local vp = viewport()
	local compact = vp.Y < 540 or vp.X < 700
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	-- Design canvas: PC ~1280x720, tablets ~1024x680 (bigger touch targets), phones ~900x430
	local refW, refH = 1280, 720
	if compact then
		refW, refH = 900, 430
	elseif touch then
		refW, refH = 1024, 680
	end
	local scale = math.clamp(math.min(vp.X / refW, vp.Y / refH), 0.5, 1.6)
	local gamepad = lastInputIsGamepad() or GuiService:IsTenFootInterface()

	local different = compact ~= Layout.Compact
		or touch ~= Layout.Touch
		or gamepad ~= Layout.Gamepad
		or math.abs(scale - Layout.Scale) > 0.005
	Layout.Compact, Layout.Touch, Layout.Gamepad, Layout.Scale = compact, touch, gamepad, scale
	Layout.Size = vp / scale
	if root and uiScale then
		uiScale.Scale = scale
		root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	if different then
		changed:Fire()
	end
end

-- Creates the scaled root frame inside the ScreenGui. Everything else parents to it.
function Layout.Init(screen: ScreenGui): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = screen
	local s = Instance.new("UIScale")
	s.Parent = frame
	root, uiScale = frame, s

	Layout.Update()
	local function hookCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(Layout.Update)
		end
	end
	hookCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		hookCamera()
		Layout.Update()
	end)
	UserInputService.LastInputTypeChanged:Connect(Layout.Update)
	return frame
end

-- Pick a value depending on the layout: Layout.pick(phoneValue, normalValue)
function Layout.pick<T>(compactValue: T, normalValue: T): T
	return if Layout.Compact then compactValue else normalValue
end

return Layout
