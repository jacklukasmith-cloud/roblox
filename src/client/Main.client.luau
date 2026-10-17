--[[
	Mythic Tamers - client entry point.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Modules = script.Parent:WaitForChild("Modules")
local State = require(Modules.State)
local Layout = require(Modules.Layout)
local Ui = require(Modules.Ui)
local Hud = require(Modules.Hud)
local Panels = require(Modules.Panels)
local Followers = require(Modules.Followers)
local Ambient = require(Modules.Ambient)
local Breaking = require(Modules.Breaking)
local Sound = require(Modules.Sound)
local EggBoards = require(Modules.EggBoards)
local HatchAnim = require(Modules.HatchAnim)
local BossBar = require(Modules.BossBar)
local Celebrate = require(Modules.Celebrate)
local PickaxeButton = require(Modules.PickaxeButton)
local Guide = require(Modules.Guide)

local player = Players.LocalPlayer

local screen = Instance.new("ScreenGui")
screen.Name = "MythicTamers"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- Keep clear of Roblox's top bar, the notch and other core UI on every device
screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
screen.Parent = player:WaitForChild("PlayerGui")

-- No tools in this game: hide the backpack bar (frees the bottom of the screen + number keys)
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local root = Layout.Init(screen)
Ui.initToasts(root)

-- Studio playtests: show script errors on screen too, so they're hard to miss
if game:GetService("RunService"):IsStudio() then
	game:GetService("ScriptContext").Error:Connect(function(message, _trace, source)
		local where = if source then source:GetFullName() else "?"
		Ui.toast(`[ERROR] {where}: {message}`, Color3.fromRGB(255, 90, 90))
	end)
end
-- Start each part on its own, so one failing part can't take the rest of the game down with it
local function start(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(`[Mythic Tamers] {name} failed to start: {err}`)
		Ui.toast(`[ERROR] {name}: {err}`, Color3.fromRGB(255, 90, 90))
	end
end
start("Creatures", Followers.Start)
start("Effects", Ambient.Start)
start("Breaking", Breaking.Start)
start("Sound", Sound.Start)
start("Egg previews", function()
	EggBoards.Start(if game:GetService("RunService"):IsStudio()
		then function(message)
			print(`[Mythic Tamers] {message}`)
			Ui.toast(message)
		end
		else nil)
end)
start("HUD", function()
	Hud.Build(root)
end)
start("Boss bar", function()
	BossBar.Build(root)
end)
start("New-player guide", Guide.Start)
start("Pickaxe button", function()
	PickaxeButton.Build(root)
end)
start("Celebrations", function()
	Celebrate.Build(root)
end)
start("Hatching", function()
	HatchAnim.Init(root)
end)
start("Menus", function()
	Panels.Build(root)
end)
start("Mission card", function()
	Guide.BuildTracker(root)
end)
start("Shop circles", function()
	require(Modules.ShopPads).Start()
end)
start("Home button", function()
	require(Modules.HomeButton).Build(root)
end)
start("Pet Habitat", function()
	require(Modules.HabitatPanel).Build(root)
	require(Modules.IslandPets).Start()
end)
start("Gloomwood", function()
	require(Modules.VaultPanel).Build(root)
	require(Modules.CauldronPanel).Build(root)
	require(Modules.GloomMapPanel).Build(root)
	require(Modules.GloomwoodClient).Build(root)
end)
start("What's New", function()
	require(Modules.WhatsNewPanel).Build(root)
end)

-- Networking ------------------------------------------------------------------------------
Remotes.Event("DataChanged").OnClientEvent:Connect(function(snapshot)
	State.Set("Data", snapshot)
end)
Remotes.Event("SurgeUpdate").OnClientEvent:Connect(function(surge)
	State.Set("Surge", surge)
end)
Remotes.Event("WorldState").OnClientEvent:Connect(function(world)
	State.Set("World", world)
end)
Remotes.Event("Notify").OnClientEvent:Connect(function(text, color)
	Ui.toast(text, color)
end)

task.spawn(function()
	local snapshot = Remotes.Function("GetSnapshot"):InvokeServer()
	if snapshot then
		State.Set("Data", snapshot)
		print("[Mythic Tamers] Connected to server - data loaded")
	end
end)

-- Gates: open the ones you've unlocked (only on your screen) ------------------------------
local function refreshGates()
	local d = State.Data
	local world = workspace:FindFirstChild("World")
	if not d or not world then
		return
	end
	for _, gate in world:GetDescendants() do
		if gate.Name == "Gate" and gate:IsA("BasePart") then
			local open = d.ZonesUnlocked >= (gate:GetAttribute("ZoneIndex") or math.huge)
			gate.CanCollide = not open
			gate.Transparency = if open then 1 else 0.2
			for _, child in gate:GetDescendants() do
				if child:IsA("SurfaceGui") then
					child.Enabled = not open
				elseif child:IsA("ProximityPrompt") then
					child.Enabled = not open
				elseif child:IsA("BasePart") then
					child.Transparency = if open then 1 else 0
					child.CanCollide = not open
				end
			end
		end
	end
end

local lastZones = -1
local lastRebirths = -1
State.Changed:Connect(function(key)
	local d = State.Data
	if key ~= "Data" or not d then
		return
	end
	if d.ZonesUnlocked ~= lastZones then
		if lastZones ~= -1 and d.ZonesUnlocked > lastZones then
			Sound.Jingle("Unlock")
		end
		lastZones = d.ZonesUnlocked
		refreshGates()
	end
	if d.Rebirths ~= lastRebirths then
		if lastRebirths ~= -1 and d.Rebirths > lastRebirths then
			Sound.Jingle("Rebirth")
		end
		lastRebirths = d.Rebirths
	end
end)
workspace.ChildAdded:Connect(function(child)
	if child.Name == "World" then
		task.wait(1)
		refreshGates()
	end
end)

-- VIP chat tag ---------------------------------------------------------------------------
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local speaker = source and Players:GetPlayerByUserId(source.UserId)
	if speaker and speaker:GetAttribute("VIP") then
		props.PrefixText = `<font color="#FFD250">[VIP]</font> ` .. message.PrefixText
	end
	return props
end
