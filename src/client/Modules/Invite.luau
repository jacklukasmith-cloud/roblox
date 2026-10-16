--[[ Opens Roblox's own "invite friends" screen (used by the Trade menu and Settings). ]]

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local Ui = require(script.Parent.Ui)

local Invite = {}

function Invite.Prompt()
	local player = Players.LocalPlayer
	local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and canInvite then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	else
		Ui.toast("Invites aren't available right now", Ui.Theme.Bad)
	end
end

return Invite
