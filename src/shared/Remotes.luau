--[[
	All networking in one place. The server creates the remotes; clients wait for them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "MythicTamersRemotes"

local EVENTS = {
	"DataChanged", -- server -> client: full player snapshot
	"Notify", -- server -> client: toast message (text, color?)
	"HatchResult", -- server -> client: eggId, { {Id, Variant} }
	"SurgeUpdate", -- server -> client: surge state
	"WorldState", -- server -> client: weather / house war / merchant info
	"CrystalHit", -- server -> client: crystal model, damage (for damage numbers)
	"CrystalBroken", -- server -> client: crystal model, essence earned, orb count, combo, window
	"BossUpdate", -- server -> all: boss raid state for the boss bar
}

local FUNCTIONS = {
	"GetSnapshot",
	"Equip",
	"Unequip",
	"EquipBest",
	"Release",
	"Rebirth",
	"SetAutoCollect",
	"ChooseHouse",
	"BuyMerchantItem",
	"ClaimDaily",
	"ClaimQuest",
	"Fuse",
	"GoToBoss",
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	-- Lives directly in ReplicatedStorage with a unique name. (It used to sit next to this
	-- ModuleScript, also called "Remotes", and clients found the module instead of the folder.)
	folder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
