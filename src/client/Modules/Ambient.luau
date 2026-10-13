--[[
	Client-side ambient animation for the world:
	  - anything with a "Spin" (radians/sec) or "Bob" (studs) attribute spins / floats
]]

local RunService = game:GetService("RunService")

local Ambient = {}

type Animated = { Inst: PVInstance, Base: CFrame, Spin: number, Bob: number, Phase: number }

local animated: { Animated } = {}
local CULL_DISTANCE = 260

local function pivotOf(inst: PVInstance): CFrame
	return inst:GetPivot()
end

local function register(inst: Instance)
	if not (inst:IsA("Model") or inst:IsA("BasePart")) then
		return
	end
	local spin = inst:GetAttribute("Spin")
	local bob = inst:GetAttribute("Bob")
	if spin == nil and bob == nil then
		return
	end
	local pv = inst :: PVInstance
	table.insert(animated, {
		Inst = pv,
		Base = pivotOf(pv),
		Spin = tonumber(spin) or 0,
		Bob = tonumber(bob) or 0,
		Phase = (#animated * 1.7) % (math.pi * 2),
	})
end

function Ambient.Start()
	task.spawn(function()
		local world = workspace:WaitForChild("World")
		for _, d in world:GetDescendants() do
			register(d)
		end
		world.DescendantAdded:Connect(function(d)
			task.defer(function()
				register(d)
			end)
		end)
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		for i = #animated, 1, -1 do
			local a = animated[i]
			if not a.Inst.Parent then
				table.remove(animated, i)
			elseif (a.Base.Position - camPos).Magnitude < CULL_DISTANCE then
				local offset = Vector3.new(0, math.sin(t * 1.4 + a.Phase) * a.Bob, 0)
				local cf = CFrame.new(a.Base.Position + offset) * CFrame.Angles(0, t * a.Spin, 0) * a.Base.Rotation
				a.Inst:PivotTo(cf)
			end
		end
	end)
end

return Ambient
