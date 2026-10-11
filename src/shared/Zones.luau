--[[ The four worlds, laid out in a line from the hub. ]]

export type ZoneDef = {
	Index: number,
	Name: string,
	UnlockCost: number,
	CrystalHP: number,
	CrystalReward: number,
	EggId: string,
	GroundColor: Color3,
	GroundMaterial: Enum.Material,
	CrystalColor: Color3,
	DecorColor: Color3,
}

local rgb = Color3.fromRGB

local Zones = {}

Zones.List = {
	{
		Index = 1,
		Name = "Enchanted Meadow",
		UnlockCost = 0,
		CrystalHP = 10,
		CrystalReward = 5,
		EggId = "MeadowEgg",
		GroundColor = rgb(95, 170, 85),
		GroundMaterial = Enum.Material.Grass,
		CrystalColor = rgb(140, 255, 200),
		DecorColor = rgb(255, 150, 220),
	},
	{
		Index = 2,
		Name = "Ember Rift",
		UnlockCost = 2500,
		CrystalHP = 250,
		CrystalReward = 90,
		EggId = "EmberEgg",
		GroundColor = rgb(70, 45, 40),
		GroundMaterial = Enum.Material.Basalt,
		CrystalColor = rgb(255, 120, 40),
		DecorColor = rgb(255, 80, 20),
	},
	{
		Index = 3,
		Name = "Frostpeak",
		UnlockCost = 60000,
		CrystalHP = 6000,
		CrystalReward = 1800,
		EggId = "FrostEgg",
		GroundColor = rgb(225, 240, 255),
		GroundMaterial = Enum.Material.Snow,
		CrystalColor = rgb(120, 200, 255),
		DecorColor = rgb(170, 220, 255),
	},
	{
		Index = 4,
		Name = "Sky Sanctum",
		UnlockCost = 1500000,
		CrystalHP = 150000,
		CrystalReward = 40000,
		EggId = "SkyEgg",
		GroundColor = rgb(250, 245, 230),
		GroundMaterial = Enum.Material.Marble,
		CrystalColor = rgb(255, 225, 110),
		DecorColor = rgb(255, 255, 255),
	},
} :: { ZoneDef }

function Zones.Get(index: number): ZoneDef?
	return Zones.List[index]
end

return Zones
