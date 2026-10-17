--[[
	The Blacksmith shop: opens when you walk into the glowing circle next to the hub anvil and
	closes when you step out (Modules/ShopPads). Lists every pickaxe tier (owned / yours / buy the next one / locked)
	and features the Golden Pickaxe game pass.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Sound = require(Modules.Sound)

local T = Ui.Theme
local cfg = Config.Pickaxe
local GOLD = Color3.fromRGB(255, 205, 60)

local BlacksmithPanel = {}

local function goldenPass()
	for _, pass in Config.GamePasses do
		if pass.Key == "GoldenPickaxe" then
			return pass
		end
	end
	return nil
end

function BlacksmithPanel.Build(screen: Frame)
	local player = Players.LocalPlayer
	local _, content = Ui.panel(screen, "Blacksmith", "Blacksmith", UDim2.fromOffset(620, 560), "⛏")
	local header = Ui.text({
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		Font = T.FontHeavy,
		TextColor3 = Color3.fromRGB(255, 200, 120),
		MaxTextSize = 20,
		Parent = content,
	})
	local list = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = content,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Ui.new("UIPadding", { PaddingBottom = UDim.new(0, 6) }),
	})

	local function card(order: number, color: Color3, title: string, subtitle: string, highlight: boolean?)
		local frame = Ui.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 62),
			BackgroundColor3 = if highlight then color:Lerp(T.Card, 0.7) else T.Card,
			BackgroundTransparency = 0.1,
			Parent = list,
		}, { Ui.corner(12), Ui.stroke(color, if highlight then 2.5 else 1.2, if highlight then 0.1 else 0.5) })
		local chip = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.55,
			Parent = frame,
		}, { Ui.corner(12) })
		Ui.text({ Size = UDim2.fromScale(1, 1), Text = "⛏", MaxTextSize = 26, Parent = chip })
		Ui.text({
			Position = UDim2.fromOffset(64, 8),
			Size = UDim2.new(1, -220, 0, 24),
			Text = title,
			Font = T.FontHeavy,
			TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 19,
			Parent = frame,
		})
		Ui.text({
			Position = UDim2.fromOffset(64, 34),
			Size = UDim2.new(1, -220, 0, 18),
			Text = subtitle,
			Font = T.FontRegular,
			TextColor3 = T.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 14,
			Parent = frame,
		})
		return frame
	end

	local function rightLabel(frame: Frame, text: string, color: Color3)
		Ui.text({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(140, 24),
			Text = text,
			Font = T.FontHeavy,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 16,
			Parent = frame,
		})
	end

	local function render()
		local d = State.Data
		if not d then
			return
		end
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local tier = math.clamp(d.Pickaxe or 1, 1, #cfg.Tiers)
		local golden = d.OwnedPasses and d.OwnedPasses.GoldenPickaxe
		local current = cfg.Tiers[tier]
		header.Text = `Your pickaxe: {if golden then "Golden " else ""}{current.Name}  ·  x{current.Mult * (if golden
			then cfg.GoldenDamage
			else 1)} Power per swing`

		-- Golden Pickaxe pass (Robux)
		local pass = goldenPass()
		if pass then
			local frame =
				card(0, GOLD, "Golden Pickaxe", "+50% damage, faster swings, shining gold (game pass)", not golden)
			if golden then
				rightLabel(frame, "✅ Owned", T.Good)
			else
				Ui.button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(120, 40),
					Text = `R$ {pass.PriceHint}`,
					Variant = "Gold",
					Parent = frame,
				}, function()
					if pass.Id == 0 then
						Ui.toast("This pass isn't set up yet (add its ID in Config.luau)", T.Bad)
					else
						MarketplaceService:PromptGamePassPurchase(player, pass.Id)
					end
				end)
			end
		end

		for i, info in cfg.Tiers do
			local subtitle = `x{info.Mult} Power per swing`
			local frame = card(i, info.Color, info.Name, subtitle, i == tier + 1)
			if i < tier then
				rightLabel(frame, "✅ Owned", T.SubText)
			elseif i == tier then
				rightLabel(frame, "⭐ Yours", T.Gold)
			elseif i == tier + 1 then
				local canAfford = d.Essence >= info.Cost
				Ui.button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(130, 40),
					Text = `Buy · {Format.Number(info.Cost)}`,
					Variant = if canAfford then "Success" else "Secondary",
					Parent = frame,
				}, function()
					local ok, success, message = pcall(function()
						return Remotes.Function("UpgradePickaxe"):InvokeServer()
					end)
					if ok and message then
						Ui.toast(message, if success then GOLD else T.Bad)
					end
					if ok and success then
						Sound.Play("Fanfare", 1.2)
					end
				end)
			else
				rightLabel(frame, `🔒 {Format.Number(info.Cost)}`, T.SubText)
			end
		end
	end

	Ui.onPanelOpen("Blacksmith", render)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Blacksmith") then
			render()
		end
	end)
end

return BlacksmithPanel
