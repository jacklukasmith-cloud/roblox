--[[
	The Alchemy Cauldron on your Sanctuary island (Services/Cauldron, the ⚗️ Cauldron window).
	Recipes use Gloom Crystals from your Crystal Vault plus a little Essence, and take real time to
	brew (they keep brewing while you're away). A finished potion goes straight into your Bag.

	Ingredients = { [crystal id] = count } (Shared/Gloomwood crystals)
	Essence     = Essence worth this many crystals of your best realm (like the shop's products)
	Minutes     = brewing time (the Master Alchemist pass makes it 25% quicker)
	Item        = what you get (Shared/Items)
]]

local Alchemy = {}

Alchemy.BaseSlots = 1 -- brews at once (Master Alchemist: Config.GamePassBonuses.CauldronSlots)

Alchemy.Recipes = {
	{ Id = "LuckPotion", Item = "LuckPotion", Ingredients = { Moonshard = 5 }, Essence = 20, Minutes = 3 },
	{
		Id = "SpeedPotion",
		Item = "SpeedPotion",
		Ingredients = { Moonshard = 2, Frostglass = 3 },
		Essence = 10,
		Minutes = 3,
	},
	{
		Id = "OwlEyePotion",
		Item = "OwlEyePotion",
		Ingredients = { Moonshard = 4, Frostglass = 2 },
		Essence = 15,
		Minutes = 5,
	},
	{
		Id = "GloomWard",
		Item = "GloomWard",
		Ingredients = { Moonshard = 3, Voidstone = 1 },
		Essence = 25,
		Minutes = 6,
	},
	{
		Id = "EssencePotion",
		Item = "EssencePotion",
		Ingredients = { Moonshard = 3, Emberheart = 2 },
		Essence = 30,
		Minutes = 5,
	},
	{
		Id = "PowerPotion",
		Item = "PowerPotion",
		Ingredients = { Moonshard = 2, Emberheart = 4 },
		Essence = 40,
		Minutes = 6,
	},
	{
		Id = "ShinyElixir",
		Item = "ShinyElixir",
		Ingredients = { Stormquartz = 2, Voidstone = 1 },
		Essence = 50,
		Minutes = 10,
	},
	{
		Id = "XPPotion",
		Item = "XPPotion",
		Ingredients = { Stormquartz = 3, Frostglass = 2 },
		Essence = 40,
		Minutes = 8,
	},
	-- teleport crystals: cheap and quick, so they're something to brew every visit
	{ Id = "HomeCrystal", Item = "HomeCrystal", Ingredients = { Moonshard = 2 }, Essence = 5, Minutes = 1 },
	{
		Id = "GloomCrystal",
		Item = "GloomCrystal",
		Ingredients = { Moonshard = 3, Emberheart = 1 },
		Essence = 10,
		Minutes = 2,
	},
	{
		Id = "CampCrystal",
		Item = "CampCrystal",
		Ingredients = { Moonshard = 4, Voidstone = 1 },
		Essence = 20,
		Minutes = 4,
	},
	{
		Id = "RainbowBrew",
		Item = "RainbowBrew",
		Ingredients = { Prismheart = 1, Stormquartz = 3, Voidstone = 3 },
		Essence = 200,
		Minutes = 20,
	},
}

function Alchemy.Get(id: string): any
	for _, recipe in Alchemy.Recipes do
		if recipe.Id == id then
			return recipe
		end
	end
	return nil
end

-- Seconds a recipe takes (speed < 1 = quicker)
function Alchemy.Duration(recipe: any, speed: number): number
	return math.max(10, math.floor(recipe.Minutes * 60 * speed))
end

-- Does the vault hold everything the recipe needs?
function Alchemy.HasIngredients(vault: { [string]: number }?, recipe: any): boolean
	for id, n in recipe.Ingredients do
		if ((vault or {})[id] or 0) < n then
			return false
		end
	end
	return true
end

return Alchemy
