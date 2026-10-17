--[[
	Shop circles: walk into one and its window opens, step out and it closes. The circles are
	built on the server (WorldBuilder's shopPad) and found here by name. Island circles only work
	on your own island.
]]

local Players = game:GetService("Players")

local Ui = require(script.Parent.Ui)

local ShopPads = {}

local PADS = {
	BlacksmithPad = "Blacksmith",
	MerchantPad = "Merchant",
}
-- circles on your own Sanctuary island
local ISLAND_PADS = {
	HabitatPad = "Habitat",
	VaultPad = "Vault",
}
local RADIUS = 4.5 -- the circle is 9 studs across

function ShopPads.Start()
	local player = Players.LocalPlayer
	local inside: string? = nil -- the panel whose circle we're standing in
	local found: { [string]: BasePart? } = {}
	task.spawn(function()
		while true do
			task.wait(0.2)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local world = workspace:FindFirstChild("World")
			local now: string? = nil
			local function check(container: Instance?, pads: { [string]: string }, deep: boolean)
				if not root or not container then
					return
				end
				for padName, panel in pads do
					-- the hub's circles are looked up once (a deep search every 0.2s adds up)
					local pad = if deep then found[padName] else nil
					if not pad or not pad.Parent then
						pad = container:FindFirstChild(padName, deep) :: BasePart?
						if deep then
							found[padName] = pad
						end
					end
					if pad then
						local offset = root.Position - pad.Position
						if Vector2.new(offset.X, offset.Z).Magnitude <= RADIUS and math.abs(offset.Y) < 8 then
							now = panel
						end
					end
				end
			end
			check(world, PADS, true)
			local islands = workspace:FindFirstChild("Sanctuaries")
			check(islands and islands:FindFirstChild(`Sanctuary_{player.UserId}`), ISLAND_PADS, false)
			if now ~= inside then
				if inside and Ui.isOpen(inside) then
					Ui.toggle(inside, false)
				end
				if now then
					Ui.toggle(now, true)
				end
				inside = now
			end
		end
	end)
end

return ShopPads
