--[[
	Tiny UI kit: calm pastel palette, rounded cards, soft strokes.
]]

local Ui = {}

Ui.Font = Enum.Font.FredokaOne
Ui.Colors = {
	Card = Color3.fromRGB(255, 251, 245),
	Text = Color3.fromRGB(96, 86, 110),
	Soft = Color3.fromRGB(150, 140, 162),
	Pink = Color3.fromRGB(244, 182, 198),
	Mint = Color3.fromRGB(170, 220, 192),
	Lavender = Color3.fromRGB(200, 184, 236),
	Sky = Color3.fromRGB(172, 208, 240),
	Butter = Color3.fromRGB(255, 226, 160),
	Stroke = Color3.fromRGB(226, 214, 222),
}

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?)
	local inst = Instance.new(className)
	if inst:IsA("GuiObject") then
		(inst :: any).BorderSizePixel = 0
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") then
		(inst :: any).Font = Ui.Font
		;(inst :: any).TextColor3 = Ui.Colors.Text
		;(inst :: any).BackgroundTransparency = 1
		;(inst :: any).TextScaled = true
	end
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

function Ui.corner(radius: number?)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function Ui.stroke(color: Color3?, thickness: number?, transparency: number?)
	return Ui.new("UIStroke", {
		Color = color or Ui.Colors.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.textStroke(color: Color3?, thickness: number?)
	return Ui.new("UIStroke", {
		Color = color or Color3.fromRGB(110, 98, 124),
		Thickness = thickness or 2,
		Transparency = 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Ui.gradient(a: Color3, b: Color3, rotation: number?)
	return Ui.new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90 })
end

function Ui.card(props)
	props.BackgroundColor3 = props.BackgroundColor3 or Ui.Colors.Card
	props.BackgroundTransparency = props.BackgroundTransparency or 0.06
	return Ui.new("Frame", props, { Ui.corner(16), Ui.stroke() })
end

return Ui
