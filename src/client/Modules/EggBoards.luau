--[[
	Fills the 3D creature previews on the egg odds signs.

	The server builds the signs but leaves an empty "Preview" frame (with a CreatureId
	attribute) in each card, because cameras created on the server never reach clients and a
	ViewportFrame without its camera draws nothing. Each client builds the viewports itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)

local EggBoards = {}

local filled = 0
local failed = 0

local function fill(slot: Instance)
	if not slot:IsA("Frame") or slot.Name ~= "Preview" then
		return
	end
	local id = slot:GetAttribute("CreatureId")
	if type(id) ~= "string" then
		return
	end
	local existing = slot:FindFirstChildOfClass("ViewportFrame")
	if existing and existing.CurrentCamera then
		return
	end
	if existing then
		existing:Destroy()
	end
	local ok, viewport = pcall(CreatureModels.Viewport, id, "Normal", { Size = UDim2.fromScale(1, 1) })
	if ok then
		viewport.Parent = slot
		filled += 1
	else
		failed += 1
		warn(`[Mythic Tamers] egg preview for {id} failed: {viewport}`)
	end
end

local function scan()
	for _, d in workspace:GetDescendants() do
		if d.Name == "Preview" then
			fill(d)
		end
	end
end

-- report(message) is optional; Main uses it to show a status toast in Studio
function EggBoards.Start(report: ((string) -> ())?)
	scan()
	workspace.DescendantAdded:Connect(fill)
	-- Safety net: rescan for a while in case parts of the world stream in late
	task.spawn(function()
		for _ = 1, 10 do
			task.wait(3)
			scan()
		end
		if report then
			report(`Egg previews: {filled} built, {failed} failed`)
		end
	end)
	if report then
		task.delay(4, function()
			report(`Egg previews: {filled} built, {failed} failed`)
		end)
	end
end

return EggBoards
