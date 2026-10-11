--[[
	Live events, Grow-a-Garden "admin abuse" style. The place owner (and Config.AdminUserIds)
	can type these in chat. Commands are broadcast to EVERY server with MessagingService,
	so you can throw a game-wide party:

	  !surge                     start a Mana Surge now
	  !weather ManaStorm 10      force a weather for N minutes (Clear, Starfall, Aurora, Eclipse, ManaStorm)
	  !announce Hello everyone   show a message to all players
]]

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Surge = require(script.Parent.Surge)
local WorldService = require(script.Parent.WorldService)

local Admin = {}

local TOPIC = "MythicTamersAdmin"
local notify = Remotes.Event("Notify")

local function isAdmin(player: Player): boolean
	if table.find(Config.AdminUserIds, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function run(command: string, args: { string })
	if command == "surge" then
		Surge.StartNow()
	elseif command == "weather" then
		local id = args[1]
		local minutes = math.clamp(tonumber(args[2]) or 5, 1, 60)
		if Weather.Types[id] then
			WorldService.SetOverride(id, os.time() + minutes * 60)
			for _, player in Players:GetPlayers() do
				notify:FireClient(
					player,
					`An admin summoned {Weather.Types[id].Name} for {minutes} minutes!`,
					Weather.Types[id].SkyTint
				)
			end
		end
	elseif command == "announce" then
		local text = table.concat(args, " ")
		for _, player in Players:GetPlayers() do
			notify:FireClient(player, "[EVENT] " .. text, Color3.fromRGB(255, 215, 80))
		end
	end
end

function Admin.Start()
	local subscribed = pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local payload = message.Data
			if type(payload) == "table" and type(payload.Command) == "string" and type(payload.Args) == "table" then
				run(payload.Command, payload.Args)
			end
		end)
	end)

	local function onChatted(player: Player, text: string)
		if string.sub(text, 1, 1) ~= "!" or not isAdmin(player) then
			return
		end
		local words = string.split(string.sub(text, 2), " ")
		local command = string.lower(table.remove(words, 1) or "")
		if command ~= "surge" and command ~= "weather" and command ~= "announce" then
			return
		end
		local published = subscribed
			and pcall(MessagingService.PublishAsync, MessagingService, TOPIC, { Command = command, Args = words })
		if not published then
			run(command, words) -- Studio / MessagingService down: run on this server only
		end
	end

	local function hook(player: Player)
		player.Chatted:Connect(function(text)
			onChatted(player, text)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return Admin
