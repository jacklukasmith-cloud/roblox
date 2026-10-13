--[[
	Fills the 3D creature previews on the egg odds signs.

	The server builds the signs but leaves an empty "Preview" frame (with a CreatureId
	attribute) in each card, because cameras created on the server never reach clients and a
	ViewportFrame without its camera draws nothing. Each client builds the viewports itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)

local EggBoards = {}

local function fill(slot: Instance)
	if not slot:IsA("Frame") or slot.Name ~= "Preview" or slot:FindFirstChildOfClass("ViewportFrame") then
		return
	end
	local id = slot:GetAttribute("CreatureId")
	if type(id) ~= "string" then
		return
	end
	local ok, viewport = pcall(CreatureModels.Viewport, id, "Normal", { Size = UDim2.fromScale(1, 1) })
	if ok then
		viewport.Parent = slot
	else
		warn(`[Mythic Tamers] egg preview for {id} failed: {viewport}`)
	end
end

function EggBoards.Start()
	for _, d in workspace:GetDescendants() do
		fill(d)
	end
	workspace.DescendantAdded:Connect(fill)
end

return EggBoards
