--[[
	The "What's New" pop-up (Shared/WhatsNew): shown once after each update when you join, and from
	⚙️ Settings any time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local WhatsNew = require(Shared.WhatsNew)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local State = require(Modules.State)

local T = Ui.Theme

local WhatsNewPanel = {}

local SHOW_DELAY = 3 -- let the world load in first

function WhatsNewPanel.Build(screen: Frame)
	local _, content = Ui.panel(screen, "WhatsNew", WhatsNew.Title, UDim2.fromOffset(520, 560), "📰")
	local list = Ui.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -62),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = content,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, entry in WhatsNew.List do
		local row = Ui.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, -8, 0, 58),
			BackgroundColor3 = T.Card,
			BackgroundTransparency = 0.1,
			Parent = list,
		}, { Ui.corner(10) })
		Ui.text({
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0, 40, 1, 0),
			Text = entry.Icon,
			MaxTextSize = 28,
			Parent = row,
		})
		Ui.text({
			Position = UDim2.fromOffset(56, 6),
			Size = UDim2.new(1, -66, 0, 22),
			Text = entry.Title,
			Font = T.FontHeavy,
			TextColor3 = T.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			Parent = row,
		})
		Ui.text({
			Position = UDim2.fromOffset(56, 28),
			Size = UDim2.new(1, -66, 0, 24),
			Text = entry.Text,
			Font = T.FontRegular,
			TextColor3 = T.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			MaxTextSize = 14,
			Parent = row,
		})
	end
	Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.6, 0, 0, 48),
		Text = "Let's go!",
		Variant = "Gold",
		Parent = content,
	}, function()
		Ui.toggle("WhatsNew", false)
	end)

	-- once per update: pop up the first time we see data from a save that hasn't seen it
	local shown = false
	local function check()
		local data = State.Data
		if shown or not data or (data.SeenUpdate or 0) >= WhatsNew.Version then
			return
		end
		shown = true
		task.delay(SHOW_DELAY, function()
			Ui.toggle("WhatsNew", true)
			pcall(function()
				Remotes.Function("SeenWhatsNew"):InvokeServer()
			end)
		end)
	end
	State.Changed:Connect(function(key)
		if key == "Data" then
			check()
		end
	end)
	check()
end

return WhatsNewPanel
