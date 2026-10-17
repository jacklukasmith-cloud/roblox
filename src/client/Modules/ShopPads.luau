--[[
	Shop circles: walk into one and its window opens, step out and it closes. The circles are
	built on the server (WorldBuilder's shopPad) and found here by name.
]]

local Players = game:GetService("Players")

local Ui = require(script.Parent.Ui)

local ShopPads = {}

local PADS = {
	BlacksmithPad = "Blacksmith",
	MerchantPad = "Merchant",
}
local RADIUS = 4.5 -- the circle is 9 studs across

function ShopPads.Start()
	local player = Players.LocalPlayer
	local inside: string? = nil -- the panel whose circle we're standing in
	task.spawn(function()
		while true do
			task.wait(0.2)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local world = workspace:FindFirstChild("World")
			local now: string? = nil
			if root and world then
				for padName, panel in PADS do
					local pad = world:FindFirstChild(padName, true) :: BasePart?
					if pad then
						local offset = root.Position - pad.Position
						if Vector2.new(offset.X, offset.Z).Magnitude <= RADIUS and math.abs(offset.Y) < 8 then
							now = panel
						end
					end
				end
			end
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
