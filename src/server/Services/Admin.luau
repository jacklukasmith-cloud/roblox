--[[
	Live events, Grow-a-Garden "admin abuse" style. The place owner (and Config.AdminUserIds)
	can type these in chat. Commands are broadcast to EVERY server with MessagingService,
	so you can throw a game-wide party:

	  !surge                     start a Mana Surge now
	  !weather ManaStorm 10      force a weather for N minutes (Clear, Starfall, Aurora, Eclipse, ManaStorm)
	  !announce Hello everyone   show a message to all players

	Testing commands (only affect you, only on this server):
	  !essence 1000000           give yourself Essence
	  !give EmberFox             hatch a specific creature (add "Shiny" or "Rainbow" after the name)
	  !giveall                   get one of every creature and equip your best
	  !boss                      spawn a boss raid now (on this server)
	  !bigpull Phoenix Rainbow   show the big-pull banner + fireworks (Legendary+ or Rainbow)
	  !treasure [realm]          hide a Lost Treasure now
	  !seasonend                 end the season now on this server and hand out rewards
	  !reset confirm             wipe ALL your progress (pets, Essence, pickaxe, realms...) back to a
	                             new save. Robux purchases and game passes are kept.
	  !hatchtest Phoenix Rainbow play the hatch animation for any creatures (up to 3, nothing is
	                             added to your inventory), e.g. !hatchtest GlowSprite MoonRabbit Shiny

	In Studio playtests you are always an admin, so you can use these straight away.
]]

local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Eggs = require(ReplicatedStorage.Shared.Eggs)
local Surge = require(script.Parent.Surge)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local WorldService = require(script.Parent.WorldService)

local Admin = {}

local TOPIC = "MythicTamersAdmin"
local notify = Remotes.Event("Notify")
local hatchResult = Remotes.Event("HatchResult")

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.AdminUserIds, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- Personal testing commands: run only for the player who typed them
local function runPersonal(player: Player, command: string, args: { string }): boolean
	local data = PlayerData.Get(player)
	if not data then
		return false
	end
	if command == "essence" then
		local amount = math.clamp(tonumber(args[1]) or 1e6, 0, 1e15)
		Economy.AddEssence(player, amount)
		notify:FireClient(player, `[TEST] +{amount} Essence`, Color3.fromRGB(140, 255, 200))
	elseif command == "give" or command == "giveall" then
		local list = {}
		if command == "giveall" then
			for _, def in Creatures.Ordered do
				table.insert(list, def.Id)
			end
		else
			-- accept any capitalisation: "!give emberfox"
			local wanted = string.lower(args[1] or "")
			for _, def in Creatures.Ordered do
				if string.lower(def.Id) == wanted then
					table.insert(list, def.Id)
				end
			end
			if #list == 0 then
				notify:FireClient(player, `[TEST] Unknown creature "{args[1] or ""}"`, Color3.fromRGB(255, 120, 120))
				return true
			end
		end
		local variant = args[2]
		if variant ~= "Shiny" and variant ~= "Rainbow" then
			variant = "Normal"
		end
		for _, id in list do
			PlayerData.NewCreature(data, id, variant)
			data.Bestiary[id] = true
		end
		Economy.EquipBest(player)
		notify:FireClient(player, `[TEST] Gave {#list} creature(s)`, Color3.fromRGB(140, 255, 200))
	elseif command == "reset" then
		if string.lower(args[1] or "") ~= "confirm" then
			notify:FireClient(
				player,
				"[TEST] This wipes ALL your progress. Type !reset confirm to do it",
				Color3.fromRGB(255, 200, 120)
			)
			return true
		end
		PlayerData.Reset(player)
		-- the starter creature, same as a brand-new player
		local uid = PlayerData.NewCreature(data, Config.StarterCreature, "Normal")
		data.Creatures[uid].Equipped = true
		data.Bestiary[Config.StarterCreature] = true
		local Pickaxe = require(script.Parent.Pickaxe) :: any
		pcall(Pickaxe.Give, player, true)
		notify:FireClient(player, "[TEST] Progress wiped - fresh start!", Color3.fromRGB(140, 255, 200))
	elseif command == "seasonend" then
		local Seasons = require(script.Parent.Seasons) :: any
		local count = Seasons.EndNowForTesting()
		notify:FireClient(player, `[TEST] Season rewards given to {count} player(s)`, Color3.fromRGB(140, 255, 200))
		return true
	elseif command == "treasure" then
		local Treasures = require(script.Parent.Treasures) :: any
		Treasures.Spawn(tonumber(args[1]))
		return true
	elseif command == "bigpull" then
		-- preview the big-pull banner + fireworks, e.g. !bigpull Phoenix Rainbow
		local wanted = string.lower(args[1] or "VoidLeviathan")
		local id = "VoidLeviathan"
		for _, def in Creatures.Ordered do
			if string.lower(def.Id) == wanted then
				id = def.Id
			end
		end
		local variant = if args[2] == "Shiny" or args[2] == "Rainbow" then args[2] else "Normal"
		local Celebrations = require(script.Parent.Celebrations) :: any
		Celebrations.Announce(player, id, variant, nil, true)
		return true
	elseif command == "boss" then
		local BossRaid = require(script.Parent.BossRaid) :: any
		local ok = BossRaid.Spawn(tonumber(args[1]))
		if not ok then
			notify:FireClient(player, "[TEST] A boss is already active", Color3.fromRGB(255, 120, 120))
		end
		return true
	elseif command == "hatchtest" then
		-- Only plays the animation: "!hatchtest GlowSprite MoonRabbit Shiny Phoenix Rainbow"
		local results = {}
		for _, word in args do
			local lower = string.lower(word)
			if (lower == "shiny" or lower == "rainbow") and #results > 0 then
				results[#results].Variant = if lower == "shiny" then "Shiny" else "Rainbow"
			else
				for _, def in Creatures.Ordered do
					if string.lower(def.Id) == lower and #results < 3 then
						table.insert(results, { Id = def.Id, Variant = "Normal", New = not data.Bestiary[def.Id] })
					end
				end
			end
		end
		if #results == 0 then
			notify:FireClient(
				player,
				"[TEST] Usage: !hatchtest Phoenix Rainbow  (up to 3 creatures)",
				Color3.fromRGB(255, 200, 120)
			)
			results = { { Id = "Phoenix", Variant = "Rainbow", New = true } }
		end
		-- Use an egg that actually contains the first creature, so the egg colour matches
		local eggId = Eggs.Order[1]
		for _, id in Eggs.Order do
			for _, drop in (Eggs.Get(id) :: any).Drops do
				if drop.Creature == results[1].Id then
					eggId = id
				end
			end
		end
		hatchResult:FireClient(player, eggId, results)
		return true
	else
		return false
	end
	PlayerData.MarkChanged(player)
	return true
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
		if runPersonal(player, command, words) then
			return
		end
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
