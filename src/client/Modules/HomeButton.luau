--[[
	The 🏠 button (next to the ⛏ pickaxe button): takes you to your Sanctuary island, and when
	you're up on the islands it turns into 🌀 to take you back to the hub. Key: H.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Sanctuary = require(Shared.Sanctuary)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local Layout = require(Modules.Layout)
local Sound = require(Modules.Sound)

local T = Ui.Theme

local HomeButton = {}

-- Are we up on the sky islands?
local function onIslands(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and root.Position.Y > Sanctuary.Center.Y - 40
end

function HomeButton.Build(root: Frame)
	local busy = false
	local button: TextButton
	local caption: TextLabel
	local function go()
		if busy then
			return
		end
		busy = true
		Sound.Play("Click", 1.1)
		local ok, success, message = pcall(function()
			return Remotes.Function("Travel"):InvokeServer(if onIslands() then "Hub" else "Home")
		end)
		if ok and message then
			Ui.toast(message, if success then T.Good else T.Bad)
		end
		task.wait(0.5)
		busy = false
	end
	button = Ui.button({
		Name = "HomeButton",
		Text = "🏠",
		AnchorPoint = Vector2.new(1, 1),
		Variant = "Secondary",
		Parent = root,
	}, go)
	caption = Ui.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(60, 14),
		Text = "Base",
		Font = T.Font,
		TextColor3 = T.SubText,
		MaxTextSize = 12,
		Parent = button,
	})
	local function arrange()
		local touch = Layout.Touch or Layout.Compact
		local size = if Layout.Compact then 46 else 54
		button.Size = UDim2.fromOffset(size, size)
		-- just left of the ⛏ button
		button.Position = if touch
			then UDim2.new(1, -24 - size - 10, 1, -205)
			else UDim2.new(1, -20 - size - 12, 1, -20)
	end
	Layout.Changed:Connect(arrange)
	arrange()
	-- 🏠 down in the world, 🌀 up on the islands
	task.spawn(function()
		while true do
			task.wait(0.5)
			local up = onIslands()
			button.Text = if up then "🌀" else "🏠"
			caption.Text = if up then "Hub" else "Base"
		end
	end)
	ContextActionService:BindAction("MythicHome", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(go)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.H)
end

return HomeButton
