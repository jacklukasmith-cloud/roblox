--[[
	The 💎 Crystal Vault window: opens when you step into the Vault circle on your island. Shows the
	Gloom Crystals you've sent home from the Gloomwood and lets you sell them for Essence. (Later
	they'll be used for crafting too.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gloomwood = require(Shared.Gloomwood)
local Sanctuary = require(Shared.Sanctuary)
local Zones = require(Shared.Zones)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)
local Sound = require(Modules.Sound)

local T = Ui.Theme

local VaultPanel = {}

-- Essence for one crystal (same sum as the server's Economy.GetProductEssence)
local function priceOf(data: any, def: any): number
	local zone = Zones.List[math.clamp(data.ZonesUnlocked or 1, 1, #Zones.List)]
	return zone.CrystalReward * def.Sell * (data.RebirthMultiplier or 1)
end

function VaultPanel.Build(screen: Frame)
	local _, content = Ui.panel(screen, "Vault", "Crystal Vault", UDim2.fromOffset(560, 470), "💎")
	local capacity = Ui.text({
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		Font = T.FontHeavy,
		TextColor3 = Color3.fromRGB(150, 200, 255),
		MaxTextSize = 19,
		Parent = content,
	})
	Ui.text({
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "Send Gloom Crystals home from the Gloomwood at a lantern. Sell them here, or keep them for crafting (coming soon).",
		Font = T.FontRegular,
		TextColor3 = T.SubText,
		TextWrapped = true,
		MaxTextSize = 14,
		Parent = content,
	})
	local list = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -72),
		BackgroundTransparency = 1,
		Parent = content,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local busy = false
	local function sell(id: string, count: number)
		if busy then
			return
		end
		busy = true
		Sound.Play("Click", 1.1)
		task.spawn(function()
			local ok, result, message = pcall(function()
				return Remotes.Function("SellCrystals"):InvokeServer(id, count)
			end)
			busy = false
			if ok and message then
				Ui.toast(message, if result then T.Gold else Color3.fromRGB(255, 120, 120))
			end
		end)
	end

	local rows = {}
	for i, def in Gloomwood.Crystals do
		local row = Ui.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = T.Card,
			BackgroundTransparency = 0.1,
			Parent = list,
		}, { Ui.corner(12) })
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(40, 40),
			Rotation = 45,
			BackgroundColor3 = def.Color,
			Parent = row,
		}, { Ui.corner(8) })
		Ui.text({
			Position = UDim2.fromOffset(70, 10),
			Size = UDim2.new(1, -300, 0, 26),
			Text = def.Name,
			Font = T.FontHeavy,
			TextColor3 = def.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 19,
			Parent = row,
		})
		local detail = Ui.text({
			Position = UDim2.fromOffset(70, 38),
			Size = UDim2.new(1, -300, 0, 22),
			Text = "",
			Font = T.FontRegular,
			TextColor3 = T.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 15,
			Parent = row,
		})
		local one = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -128, 0.5, 0),
			Size = UDim2.fromOffset(92, 44),
			Text = "Sell 1",
			Variant = "Secondary",
			Parent = row,
		}, function()
			sell(def.Id, 1)
		end)
		local all = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(108, 44),
			Text = "Sell all",
			Variant = "Gold",
			Parent = row,
		}, function()
			sell(def.Id, math.huge)
		end)
		rows[def.Id] = { Detail = detail, One = one, All = all }
	end

	local function render()
		local data = State.Data
		if not data then
			return
		end
		local g = data.Gloom or {}
		local vault = g.Vault or {}
		local level = data.Sanctuary and data.Sanctuary.Level or 1
		capacity.Text = `Vault: {Gloomwood.SatchelCount(vault)} / {Sanctuary.VaultCapacity(level)} crystals`
		for _, def in Gloomwood.Crystals do
			local row = rows[def.Id]
			local count = vault[def.Id] or 0
			row.Detail.Text = `You have {count}  ·  💎 {Format.Number(priceOf(data, def))} each`
			row.One.Visible = count > 0
			row.All.Visible = count > 0
		end
	end

	Ui.onPanelOpen("Vault", render)
	State.Changed:Connect(function(key)
		if key == "Data" and Ui.isOpen("Vault") then
			render()
		end
	end)
end

return VaultPanel
