--[[
	Boss raid bar: shows the active boss, its HP, time left, the top damage dealers and your
	rank, with a Join button that teleports you to the fight.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local Ui = require(Modules.Ui)
local Layout = require(Modules.Layout)
local State = require(Modules.State)

local T = Ui.Theme
local BOSS = Color3.fromRGB(255, 90, 140)

local BossBar = {}

function BossBar.Build(root: Frame)
	local player = Players.LocalPlayer
	-- a slim two-line bar: name + timer, then the health bar with Join at the end
	local bar = Ui.glass({
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(300, 60),
		Visible = false,
		Parent = root,
	}, { Ui.corner(12) })
	local edge = bar:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = BOSS
		edge.Transparency = 0.3
	end
	local title = Ui.text({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -80, 0, 18),
		Text = "",
		Font = T.FontHeavy,
		TextColor3 = Color3.fromRGB(255, 220, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = bar,
	})
	local timer = Ui.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 4),
		Size = UDim2.fromOffset(64, 18),
		Text = "",
		Font = T.Font,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 14,
		Parent = bar,
	})
	local back = Ui.new("Frame", {
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(1, -108, 0, 16),
		BackgroundColor3 = T.Background,
		Parent = bar,
	}, { Ui.round() })
	local fill = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BOSS,
		Parent = back,
	}, { Ui.round() })
	local hpText = Ui.text({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Font = T.Font,
		ZIndex = 2,
		MaxTextSize = 11,
		Parent = back,
	})
	Ui.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -6),
		Size = UDim2.fromOffset(88, 28),
		Text = "⚔️ Join",
		Variant = "Danger",
		Parent = bar,
	}, function()
		local ok, success, message = pcall(function()
			return Remotes.Function("GoToBoss"):InvokeServer()
		end)
		if ok and not success and message then
			Ui.toast(message, T.Bad)
		end
	end)

	-- Small countdown pill while no boss is up
	local pill = Ui.glass({
		Name = "BossTimer",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(150, 24),
		Visible = false,
		Parent = root,
	}, { Ui.round() })
	local pillText = Ui.text({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Font = T.Font,
		TextColor3 = Color3.fromRGB(255, 190, 210),
		MaxTextSize = 15,
		Parent = pill,
	})

	local current: any = nil
	local function render()
		local s = current
		-- nothing about bosses while you're in the Gloomwood (bosses are in the realms, and the
		-- forest has its own satchel / Gloom pill in this spot)
		if player:GetAttribute("InGloomwood") == true then
			bar.Visible = false
			pill.Visible = false
			return
		end
		if not s or not s.Active then
			bar.Visible = false
			local left = if s and s.NextAt then s.NextAt - State.Now() else -1
			pill.Visible = left > 0
			if left > 0 then
				pillText.Text = `⚔️ Boss in {Format.Time(left)}`
			end
			return
		end
		pill.Visible = false
		if not bar.Visible then
			bar.Visible = true
			local scale = bar:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = bar })
			scale.Scale = 0.6
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		-- your rank goes in the title when you've hit it
		local mine
		for i, entry in s.Top do
			if entry.UserId == player.UserId then
				mine = i
			end
		end
		title.Text = `⚔️ {s.Name}{if mine then `  ·  You #{mine}` else ""}`
		timer.Text = Format.Time(math.max(0, s.EndsAt - State.Now()))
		local pct = if s.MaxHP > 0 then math.clamp(s.HP / s.MaxHP, 0, 1) else 0
		TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(pct, 1) }):Play()
		hpText.Text = `{Format.Number(math.ceil(s.HP))} / {Format.Number(s.MaxHP)}`
	end

	local function arrange()
		local c = Layout.Compact
		bar.Size = UDim2.fromOffset(if c then 270 else 300, if c then 56 else 60)
		-- just under the top-centre Mana Surge banner (which sits in the top bar on phones)
		local y = if c then 30 else 60
		bar.Position = UDim2.new(0.5, 0, 0, y)
		pill.Position = UDim2.new(0.5, 0, 0, y)
	end
	Layout.Changed:Connect(arrange)
	arrange()

	player:GetAttributeChangedSignal("InGloomwood"):Connect(render)
	Remotes.Event("BossUpdate").OnClientEvent:Connect(function(state)
		current = state
		render()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if current then
				render()
			end
		end
	end)
end

return BossBar
