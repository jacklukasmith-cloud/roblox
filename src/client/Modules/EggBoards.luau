--[[
	Shows the egg odds signs with live 3D creature previews.

	The server builds each sign (a BillboardGui named "OddsGui" on the egg) with an empty
	"Preview" frame per creature, tagged with a CreatureId attribute. Cameras made on the
	server never reach clients, so a server-built ViewportFrame would draw nothing.

	Each client copies the sign into its own PlayerGui (still attached to the egg), hides the
	world copy and builds the ViewportFrames locally. ViewportFrames in PlayerGui billboards
	are the most reliable way to get 3D previews on a sign.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)

local EggBoards = {}

local adopted: { [Instance]: BillboardGui } = {}
local filled, failed = 0, 0

local function fillPreview(slot: Instance)
	if not slot:IsA("Frame") or slot.Name ~= "Preview" then
		return
	end
	local id = slot:GetAttribute("CreatureId")
	if type(id) ~= "string" or slot:FindFirstChildOfClass("ViewportFrame") then
		return
	end
	local ok, viewport = pcall(CreatureModels.Viewport, id, "Normal", { Size = UDim2.fromScale(1, 1) })
	if ok then
		viewport.ZIndex = 2
		viewport.Parent = slot
		filled += 1
	else
		failed += 1
		warn(`[Mythic Tamers] egg preview for {id} failed: {viewport}`)
	end
end

local function adopt(gui: Instance)
	if adopted[gui] or not gui:IsA("BillboardGui") or gui.Name ~= "OddsGui" then
		return
	end
	if not gui:IsDescendantOf(workspace) then
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local adornee = gui.Adornee or gui.Parent
	if not (adornee and adornee:IsA("BasePart")) then
		return
	end
	local copy = gui:Clone()
	copy.Name = "EggSign"
	copy.Adornee = adornee
	copy.ResetOnSpawn = false
	copy.Enabled = true
	copy.Parent = playerGui
	gui.Enabled = false
	adopted[gui] = copy
	for _, d in copy:GetDescendants() do
		fillPreview(d)
	end
	-- If the egg streams out or is rebuilt, drop our copy (a fresh sign will be adopted)
	gui.AncestryChanged:Connect(function()
		if not gui:IsDescendantOf(workspace) and adopted[gui] then
			adopted[gui]:Destroy()
			adopted[gui] = nil
		end
	end)
end

local function scan()
	for _, d in workspace:GetDescendants() do
		if d.Name == "OddsGui" then
			adopt(d)
		end
	end
end

-- report(message) is optional; Main uses it to show a status toast in Studio
function EggBoards.Start(report: ((string) -> ())?)
	scan()
	workspace.DescendantAdded:Connect(function(d)
		if d.Name == "OddsGui" then
			-- let the sign's children finish arriving before copying it
			task.defer(adopt, d)
		end
	end)
	-- Safety net: rescan for a while in case parts of the world stream in late
	task.spawn(function()
		for _ = 1, 10 do
			task.wait(3)
			scan()
		end
	end)
	if report then
		task.delay(5, function()
			local signs = 0
			for _ in adopted do
				signs += 1
			end
			report(`Egg signs: {signs}, previews: {filled} built, {failed} failed`)
		end)
	end
end

return EggBoards
