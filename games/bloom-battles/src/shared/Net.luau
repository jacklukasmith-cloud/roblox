--[[
	Networking. The server creates the remotes; clients wait for them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER = "BloomRemotes"
local EVENTS = {
	"Notify", -- server -> client: text, color?
	"Effect", -- server -> all: kind, position, color, extra
	"Duel", -- server -> participants: duel state table
	"DuelTap", -- client -> server
}
local FUNCTIONS = { "Replant" }

local Net = {}
local folder

if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER
	for _, name in EVENTS do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	for _, name in FUNCTIONS do
		local r = Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER)
end

function Net.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
