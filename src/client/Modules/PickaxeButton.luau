--[[
	The ⛏ button (and Q on keyboards / X on controllers): takes your pickaxe out or puts it away.
	Roblox's hotbar is hidden in this game, so this is how you hold it. Lights up while held.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local Layout = require(Modules.Layout)
local Sound = require(Modules.Sound)

local T = Ui.Theme

local PickaxeButton = {}

function PickaxeButton.Build(root: Frame)
	local player = Players.LocalPlayer
	local busy = false
	local button: TextButton
	local function holding(): boolean
		local character = player.Character
		local tool = character and character:FindFirstChild("Pickaxe")
		return tool ~= nil and tool:IsA("Tool")
	end
	local function refresh()
		local held = holding()
		button.BackgroundColor3 = if held then T.Gold else T.Glass
		button.BackgroundTransparency = if held then 0.05 else 0.18
	end
	local function toggle()
		if busy then
			return
		end
		busy = true
		Sound.Play("Click", 1.2)
		pcall(function()
			Remotes.Function("TogglePickaxe"):InvokeServer()
		end)
		busy = false
		refresh()
	end
	button = Ui.button({
		Name = "PickaxeButton",
		Text = "⛏",
		AnchorPoint = Vector2.new(1, 1),
		Variant = "Secondary",
		Parent = root,
	}, toggle)
	local hint = Ui.text({
		Name = "KeyHint",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(16, 14),
		Text = "Q",
		Font = T.FontHeavy,
		TextColor3 = T.SubText,
		MaxTextSize = 12,
		Parent = button,
	})
	local function arrange()
		local touch = Layout.Touch or Layout.Compact
		local size = if Layout.Compact then 46 else 54
		button.Size = UDim2.fromOffset(size, size)
		-- phones/tablets: above the jump button; PC: bottom-right corner
		button.Position = if touch then UDim2.new(1, -24, 1, -205) else UDim2.new(1, -20, 1, -20)
		hint.Visible = not Layout.Touch and not Layout.Gamepad
	end
	Layout.Changed:Connect(arrange)
	arrange()

	ContextActionService:BindAction("MythicPickaxe", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(toggle)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)

	-- keep the button in sync when the tool comes and goes (respawn, upgrades)
	local function watch(character: Model)
		character.ChildAdded:Connect(refresh)
		character.ChildRemoved:Connect(refresh)
		refresh()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

return PickaxeButton
