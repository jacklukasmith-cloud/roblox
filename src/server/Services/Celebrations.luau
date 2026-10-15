--[[
	Big-pull celebrations (like PS99's hatch announcements).

	- Legendary+ or any Rainbow: everyone on this server gets a banner, and fireworks burst over
	  the lucky player's head.
	- Mythic / Champion / Exclusive, or a Rainbow Epic+: the banner also shows in EVERY server
	  (MessagingService), marked "in another server".
]]

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Creatures)
local Remotes = require(Shared.Remotes)

local Celebrations = {}

local TOPIC = "MythicTamersBigPull"
local bigPull = Remotes.Event("BigPull")
local subscribed = false
local lastPublish = 0

-- 0 = nothing, 1 = this server, 2 = every server
function Celebrations.Tier(creatureId: string, variant: string?): number
	local def = Creatures.Get(creatureId)
	if not def then
		return 0
	end
	local order = Creatures.Rarities[def.Rarity].Order
	local rainbow = variant == "Rainbow"
	if order >= 6 or (rainbow and order >= 4) then
		return 2
	end
	if order >= 5 or rainbow then
		return 1
	end
	return 0
end

-- verb: "hatched" (default), "fused" or "got". preview = admin test (the sender sees the banner too)
function Celebrations.Announce(player: Player, creatureId: string, variant: string?, verb: string?, preview: boolean?)
	local tier = Celebrations.Tier(creatureId, variant)
	if tier == 0 then
		return
	end
	local payload = {
		Name = player.DisplayName,
		UserId = player.UserId,
		Id = creatureId,
		Variant = variant or "Normal",
		Verb = verb or "hatched",
		Global = false,
		Preview = preview == true,
	}
	bigPull:FireAllClients(payload)
	if tier == 2 and subscribed and not preview and os.clock() - lastPublish > 1 then
		lastPublish = os.clock()
		local message = table.clone(payload)
		message.JobId = game.JobId
		task.spawn(pcall, MessagingService.PublishAsync, MessagingService, TOPIC, message)
	end
end

function Celebrations.Start()
	subscribed = pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local data = message.Data
			if type(data) ~= "table" or data.JobId == game.JobId then
				return
			end
			if type(data.Id) ~= "string" or not Creatures.Get(data.Id) or type(data.Name) ~= "string" then
				return
			end
			bigPull:FireAllClients({
				Name = string.sub(data.Name, 1, 40),
				UserId = 0, -- not in this server: banner only, no fireworks
				Id = data.Id,
				Variant = if data.Variant == "Shiny" or data.Variant == "Rainbow" then data.Variant else "Normal",
				Verb = if data.Verb == "fused" or data.Verb == "got" then data.Verb else "hatched",
				Global = true,
			})
		end)
	end)
end

return Celebrations
