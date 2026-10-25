--[[
	The main HUD: Bloom counter with tier + progress, per-second rate, stats card,
	Replant button, toasts and big milestone banners. Also floats "+N" above heads.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.BloomShared.Config)
local Util = require(ReplicatedStorage.BloomShared.Util)
local Net = require(ReplicatedStorage.BloomShared.Net)
local Ui = require(script.Parent.Ui)
local Sfx = require(script.Parent.Sfx)
local Effects = require(script.Parent.Effects)
local Atmosphere = require(script.Parent.Atmosphere)

local Hud = {}

local player = Players.LocalPlayer
local C = Ui.Colors
local tween = Effects.Tween

local gui = Ui.new("ScreenGui", {
	Name = "BloomHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
Hud.Gui = gui
Effects.SetScreen(gui)

local uiScale = Ui.new("UIScale", { Parent = gui })
local function rescale()
	local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	uiScale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720) * 1.05, 0.55, 1.25)
end
rescale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

-- Bloom counter (top centre) -----------------------------------------------------------

local top = Ui.card({
	Name = "BloomCard",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(330, 104),
	Parent = gui,
})
local flower = Ui.new("TextLabel", {
	Text = "✿",
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.fromOffset(60, 60),
	TextColor3 = C.Pink,
	Parent = top,
})
local amount = Ui.new("TextLabel", {
	Text = "0",
	Position = UDim2.fromOffset(74, 6),
	Size = UDim2.new(1, -150, 0, 46),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = top,
})
local rate = Ui.new("TextLabel", {
	Text = "+1/s",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 14),
	Size = UDim2.fromOffset(84, 28),
	TextColor3 = Color3.fromRGB(120, 176, 140),
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = top,
})
local tierLabel = Ui.new("TextLabel", {
	Text = "Seedling",
	Position = UDim2.fromOffset(76, 50),
	Size = UDim2.new(1, -90, 0, 22),
	TextColor3 = C.Soft,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = top,
})
local barBack = Ui.new("Frame", {
	Position = UDim2.new(0, 14, 1, -24),
	Size = UDim2.new(1, -28, 0, 12),
	BackgroundColor3 = Color3.fromRGB(238, 230, 234),
	Parent = top,
}, { Ui.corner(6) })
local barFill = Ui.new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = C.Pink,
	Parent = barBack,
}, { Ui.corner(6), Ui.gradient(Color3.new(1, 1, 1), Color3.fromRGB(230, 230, 230), 90) })
local amountScale = Ui.new("UIScale", { Parent = amount })

-- Stats card (left) --------------------------------------------------------------------

local stats = Ui.card({
	Name = "Stats",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.42, 0),
	Size = UDim2.fromOffset(196, 150),
	Parent = gui,
})
Ui.new("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	Parent = stats,
})
Ui.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stats })
local function statRow(order: number, icon: string, color: Color3)
	return Ui.new("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 28),
		Text = icon,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stats,
	})
end
local zoneRow = statRow(1, "Sunny Meadow", Color3.fromRGB(120, 168, 120))
local multRow = statRow(2, "x1 Bloom", C.Text)
local winsRow = statRow(3, "0 Wins", Color3.fromRGB(214, 140, 160))
local bestRow = statRow(4, "Best 0", C.Soft)

-- Replant button (left, under stats) ----------------------------------------------------

local replant = Ui.new("TextButton", {
	Name = "Replant",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 12, 0.42, 84),
	Size = UDim2.fromOffset(196, 64),
	BackgroundTransparency = 0,
	BackgroundColor3 = C.Mint,
	AutoButtonColor = true,
	Text = "",
	Parent = gui,
}, { Ui.corner(16), Ui.stroke(Color3.fromRGB(140, 196, 164), 2), Ui.gradient(Color3.new(1, 1, 1), Color3.fromRGB(220, 230, 225), 90) })
local replantTitle = Ui.new("TextLabel", {
	Text = "Replant ❀",
	Position = UDim2.fromOffset(10, 6),
	Size = UDim2.new(1, -20, 0, 28),
	TextColor3 = Color3.new(1, 1, 1),
	Parent = replant,
}, { Ui.textStroke(Color3.fromRGB(96, 150, 120), 2) })
local replantSub = Ui.new("TextLabel", {
	Text = "Needs 10K Bloom",
	Position = UDim2.fromOffset(10, 36),
	Size = UDim2.new(1, -20, 0, 20),
	TextColor3 = Color3.fromRGB(70, 110, 90),
	Parent = replant,
})

-- Toasts + banners ---------------------------------------------------------------------

local toasts = Ui.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 124),
	Size = UDim2.fromOffset(460, 200),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	Ui.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local toastCount = 0

function Hud.Toast(text: string, color: Color3?)
	toastCount += 1
	local card = Ui.card({
		LayoutOrder = toastCount,
		Size = UDim2.fromOffset(440, 40),
		BackgroundTransparency = 0.08,
		Parent = toasts,
	})
	local bar = Ui.new("Frame", {
		Size = UDim2.new(0, 6, 1, -14),
		Position = UDim2.fromOffset(8, 7),
		BackgroundColor3 = color or C.Pink,
		Parent = card,
	}, { Ui.corner(3) })
	local label = Ui.new("TextLabel", {
		Text = text,
		Position = UDim2.fromOffset(22, 6),
		Size = UDim2.new(1, -34, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	local s = Ui.new("UIScale", { Scale = 0.6, Parent = card })
	tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.6, function()
		tween(card, 0.4, { BackgroundTransparency = 1 })
		tween(label, 0.4, { TextTransparency = 1 })
		tween(bar, 0.4, { BackgroundTransparency = 1 })
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, 0.4, { Transparency = 1 })
		end
		task.wait(0.45)
		card:Destroy()
	end)
	Sfx.Play("Click", 1.2, 0.6)
end

function Hud.Banner(title: string, subtitle: string, color: Color3)
	local holder = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(620, 130),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	})
	local t = Ui.new("TextLabel", {
		Text = title,
		Size = UDim2.new(1, 0, 0, 80),
		TextColor3 = color,
		ZIndex = 21,
		Parent = holder,
	}, { Ui.textStroke(Color3.fromRGB(110, 98, 124), 3) })
	local s = Ui.new("TextLabel", {
		Text = subtitle,
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 36),
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 21,
		Parent = holder,
	}, { Ui.textStroke(Color3.fromRGB(110, 98, 124), 2) })
	local scale = Ui.new("UIScale", { Scale = 0.3, Parent = holder })
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.4, function()
		tween(scale, 0.4, { Scale = 1.15 })
		for _, label in { t, s } do
			tween(label, 0.4, { TextTransparency = 1 })
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				tween(stroke, 0.4, { Transparency = 1 })
			end
		end
		task.wait(0.45)
		holder:Destroy()
	end)
end

-- Refresh ------------------------------------------------------------------------------

local shownBloom = 0
local targetBloom = 0

local function refresh()
	local bloomValue = player:GetAttribute("Bloom") or 0
	local rebirths = player:GetAttribute("Rebirths") or 0
	targetBloom = bloomValue
	local tierIndex = Util.TierIndex(bloomValue)
	local tier = Config.Tiers[tierIndex]
	local nextTier = Config.Tiers[tierIndex + 1]
	tierLabel.Text = if nextTier
		then tier.Name .. "  ·  next: " .. nextTier.Name .. " at " .. Util.Format(nextTier.Need)
		else tier.Name .. "  ·  max tier!"
	tierLabel.TextColor3 = tier.Color:Lerp(C.Text, 0.45)
	flower.TextColor3 = tier.Color:Lerp(C.Pink, 0.2)
	barFill.BackgroundColor3 = tier.Color
	local progress = 1
	if nextTier then
		local a, b = math.log10(tier.Need + 1), math.log10(nextTier.Need + 1)
		progress = math.clamp((math.log10(bloomValue + 1) - a) / (b - a), 0, 1)
	end
	tween(barFill, 0.4, { Size = UDim2.fromScale(progress, 1) })

	rate.Text = "+" .. Util.FormatGain(player:GetAttribute("PerSecond") or 1) .. "/s"
	local zone = Config.Zones[Atmosphere.Zone()]
	zoneRow.Text = "⌂ " .. zone.Name
	multRow.Text = "✦ x" .. tostring(Util.ReplantMultiplier(rebirths)) .. " Replant"
	winsRow.Text = "♥ " .. Util.Format(player:GetAttribute("Wins") or 0) .. " Wins"
	bestRow.Text = "★ Best " .. Util.Format(player:GetAttribute("BestBloom") or 0)

	local cost = Util.ReplantCost(rebirths)
	local ready = bloomValue >= cost
	replantSub.Text = if ready
		then "Ready! Next: x" .. Util.ReplantMultiplier(rebirths + 1)
		else Util.Format(bloomValue) .. " / " .. Util.Format(cost)
	replant.BackgroundColor3 = if ready then C.Mint else Color3.fromRGB(214, 222, 218)
end

for _, attr in { "Bloom", "Rebirths", "Wins", "BestBloom", "PerSecond" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
Atmosphere.OnZone(function(zone)
	local info = Config.Zones[zone]
	refresh()
	Hud.Banner(info.Name, "x" .. info.Multiplier .. " Bloom here", info.Flower[1])
end)
refresh()

-- Smooth counting number
game:GetService("RunService").RenderStepped:Connect(function(dt)
	if shownBloom ~= targetBloom then
		local diff = targetBloom - shownBloom
		if math.abs(diff) < 1 then
			shownBloom = targetBloom
		else
			shownBloom += diff * math.min(1, dt * 8)
		end
		amount.Text = Util.Format(shownBloom)
	end
end)

replant.Activated:Connect(function()
	Sfx.Play("Click")
	local ok, a, b = pcall(function()
		return Net.Function("Replant"):InvokeServer()
	end)
	if ok and b then
		Hud.Toast(b, if a then C.Mint else C.Pink)
	end
end)

-- "+N" pops above heads -----------------------------------------------------------------

local lastSeen = {}
local function watch(other: Player)
	lastSeen[other] = other:GetAttribute("Bloom")
	other:GetAttributeChangedSignal("Bloom"):Connect(function()
		local new = other:GetAttribute("Bloom") or 0
		local old = lastSeen[other]
		lastSeen[other] = new
		if not old or new <= old then
			return
		end
		local head = other.Character and other.Character:FindFirstChild("Head")
		if not head then
			return
		end
		local tier = Util.Tier(new)
		if other == player then
			Effects.Pop(head, "+" .. Util.FormatGain(new - old), tier.Color:Lerp(Color3.new(1, 1, 1), 0.25))
			Sfx.Play("Pop", 1.4 + math.random() * 0.3, 0.6)
			amountScale.Scale = 1.08
			tween(amountScale, 0.25, { Scale = 1 })
		else
			local me = player.Character and player.Character:FindFirstChild("Head")
			if me and (me.Position - head.Position).Magnitude < 50 then
				Effects.Pop(head, "+" .. Util.FormatGain(new - old), tier.Color, true)
			end
		end
	end)
end
for _, other in Players:GetPlayers() do
	watch(other)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(other)
	lastSeen[other] = nil
end)

return Hud
