--[[ The six realms, laid out in a line from the hub. Realms 5 and 6 also need Rebirths. ]]

export type ZoneDef = {
	Index: number,
	Name: string,
	UnlockCost: number,
	RequiresRebirths: number?, -- Rebirths needed before the gate opens (late realms)
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
	{
		Index = 5,
		Name = "Starfall Desert",
		UnlockCost = 30000000,
		RequiresRebirths = 1,
		CrystalHP = 3000000,
		CrystalReward = 800000,
		EggId = "StarfallEgg",
		GroundColor = rgb(235, 195, 120),
		GroundMaterial = Enum.Material.Sand,
		CrystalColor = rgb(255, 160, 220),
		DecorColor = rgb(255, 220, 140),
	},
	{
		Index = 6,
		Name = "Void Abyss",
		UnlockCost = 600000000,
		RequiresRebirths = 3,
		CrystalHP = 60000000,
		CrystalReward = 16000000,
		EggId = "VoidEgg",
		GroundColor = rgb(40, 25, 60),
		GroundMaterial = Enum.Material.Slate,
		CrystalColor = rgb(170, 90, 255),
		DecorColor = rgb(120, 60, 200),
	},
} :: { ZoneDef }

function Zones.Get(index: number): ZoneDef?
	return Zones.List[index]
end

return Zones
