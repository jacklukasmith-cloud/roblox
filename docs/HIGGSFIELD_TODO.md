# Art to make with Higgsfield

Everything in the game has a built-in block version, so none of this blocks playing. Each 3D model
is picked up automatically once it's imported into Studio with the right name (see
[WORLD_MESHES.md](WORLD_MESHES.md)). Icons are set in `src/shared/Config.luau` (`Icon = "rbxassetid://..."`)
or on the Creator Hub.

Done items move to the bottom.

## 3D models (name = the model name the game looks for)

### Sanctuary islands
| Model name | What | Replaces |
|---|---|---|
| `UpgradeStone` | Tall glowing purple rune stone | the block stone on every island |
| `CrystalVault` | Ornate chest with crystals growing out of the lid | the block chest |
| `HabitatFence` | A short wooden garden fence section (curved) | the fence posts round the Pet Habitat |
| `SkyBridgeLamp` | Small hanging lantern for the bridge posts | the glowing cubes |
| `PlazaCrystal` | Huge floating crystal cluster for the Sky Plaza | the neon pillars in the middle |
| `IslandTree` | Round pastel tree (2-3 colour variants: green, pink) | the ball-on-trunk trees |
| `Hangar` | Open workshop shed with a hoverboard rack | the plank shed on every island |
| `VehiclePrismGlider` | A translucent rainbow-prism glider board | the glass board |
| `GloomWagon` | A 4-seat party wagon (when it's added) | - |

### Gloomwood
| Model name | What | Replaces |
|---|---|---|
| `GloomTree` | Twisted dark tree with purple-green leaves (2 variants) | the block trees (hundreds of them) |
| `DeadTree` | Bare twisted trunk (for the Deepwood and the Heart) | block trunks |
| `CourierLantern` | Wooden post with a hanging warm lantern | the post + glowing cube |
| `GloomMushroom` | Glowing mushroom cluster (teal and purple variants) | the stem + cap parts |
| `ThornWall` | A section of thorny bramble wall | the dark planks round the Deepwood |
| `DeepwoodGate` | Twisted bramble archway with torches (for the wall openings) | the two posts |
| `GloomCliff` | Craggy rock ledge with a ramp | the block cliffs |
| `GloomCave` | Rock mound with a dark opening | the box caves |
| `StandingStone` | Rune-carved standing stone | the blocks in the Heart's stone circle |
| `HeartPedestal` | Carved stone pedestal | the block pedestal |
| `GloomwoodGate` | Big stone archway covered in moss (the exit gate) | the pillars |
| `DeepCampTent` | Small canvas tent | the wedge tents |
| `Campfire` | Stone-ringed campfire | the block + fire |
| `BrokenWatchtower` | Collapsed wooden watchtower | the block tower |
| `GiantDeadTree` | Enormous dead tree landmark | the cylinder trunk |
| `MapFragment` | Rolled-up glowing parchment | the neon cylinder |

### Gloom Crystals
| Model name | What |
|---|---|
| `MoonshardCrystal` | Pale blue-white crystal cluster |
| `EmberheartCrystal` | Orange-red crystal with embers |
| `FrostglassCrystal` | Clear icy blue crystal |
| `StormquartzCrystal` | Yellow crystal with lightning veins |
| `VoidstoneCrystal` | Dark purple crystal with a black core |

### Gloomwood animals (these need rigging to walk; the block versions walk already)
| Model name | What |
|---|---|
| `ShadowWolf` | Dark wolf with glowing purple eyes |
| `DuskBat` | Small purple bat |
| `CinderFox` | Orange fox with an ember-tipped tail |
| `BrambleBoar` | Brown boar with green bramble spikes along its back |
| `ThicketSpider` | Dark green spider with glowing green eyes |
| `MossBear` | Big brown bear with moss growing on its back |
| `FrostStag` | Pale stag with glowing ice antlers |
| `ShadowWisp` | Floating ghostly flame |

### Realms 5 and 6 (Starfall Desert, Void Abyss)
| Model name | What | Replaces |
|---|---|---|

| `StarCactus` | Tall cartoon cactus with a star on top | the block cacti |
| `FallenStar` | Glowing pink star half-buried in sand | the neon cubes |
| `DesertRuin` | Sandstone ruin arch | - |
| `VoidShard` | Floating purple crystal shard | the neon shards |
| `AbyssPillar` | Cracked dark obsidian pillar | the block pillars |
| `WatchingEye` | Floating glowing eye orb | - |

### Realm 5 and 6 creatures
All 12 have concept art ([CREATURE_MESHES.md](CREATURE_MESHES.md)); the two Mythics have GLBs. Still to convert
(30 credits each): Dune Scarab, Mirage Jackal, Sand Wyrm, Comet Hawk, Sphinx Guardian, Void Moth, Shadow Lynx,
Eclipse Raven, Nether Wyvern, Abyssal Kraken.

## Icons and UI images

### Game pass icons
| Pass | Done? |
|---|---|
| Master Alchemist | done ([ICONS.md](ICONS.md)) |
| Board Skins | done ([ICONS.md](ICONS.md)) |

### Product icons
| Product | Done? |
|---|---|
| Spin Pack | done ([ICONS.md](ICONS.md)) |
| Essence Pouch, Essence Chest, Luck Potion, Merchant Restock, Nebula Kitsune | to do |

### Item icons (the Bag uses emoji for now; proper icons would look much better)
Luck Potion, Essence Potion, Shiny Elixir, Speed Potion, Owl Eye Potion, Gloom Ward, Power Potion, XP Potion,
Rainbow Brew, Pet Treat, Golden Treat, Essence Bag, Mystic Egg, Mystery Gift, Treasure Map, Boss Horn.

### Crystal icons (for the Vault, Cauldron and satchel)
Moonshard, Emberheart, Frostglass, Stormquartz, Voidstone, Prismheart.

### Other
| Image | Where |
|---|---|
| Sanctuary / Gloomwood update thumbnails | the experience page |
| "The Sanctuary Update" banner | What's New pop-up header |

## Done
| Name | What |
|---|---|
| `AlchemyCauldron` | The Cauldron on every island ([WORLD_MESHES.md](WORLD_MESHES.md)) |
| `PrismheartCrystal` | The legendary crystal in the Heart (see WORLD_MESHES.md) |
| `GloomTreant` | Static 3D model made (see WORLD_MESHES.md); it still needs rigging before it can replace the block treant that walks |
| `VehicleMossBoard` | The Moss Board, textured 3D model (see WORLD_MESHES.md) |
| `VehicleCrystalBoard` | The Crystal Hoverboard, textured 3D model (see WORLD_MESHES.md) |
| `VehicleMushroomKart` | The Mushroom Kart, textured 3D model (see WORLD_MESHES.md) |
| `IslandChest` | The daily island chest, textured 3D model (see WORLD_MESHES.md) |
| Board Skins icon | Game pass icon ([ICONS.md](ICONS.md)) |
| Gloomwood map parchment | Background for the 🗺️ forest map ([image](https://d8j0ntlcm91z4.cloudfront.net/user_3KYQFgB4C3XHu6lUsXw00hrVntX/hf_20261017_235908_cd0256e5-ec3c-45fc-b808-7306ae8a2396.png)). Upload it to Roblox as a Decal and put its `rbxassetid://` in `Gloomwood.MapImage` (`src/shared/Gloomwood.luau`) |
| Master Alchemist icon | Game pass icon ([ICONS.md](ICONS.md)) |
| Spin Pack icon | Product icon ([ICONS.md](ICONS.md)) |
| `StarfallEgg`, `VoidEgg`, `StarfallCrystal`, `VoidCrystal` | Realm 5/6 eggs and crystals (see WORLD_MESHES.md) |
| `StarfallColossus`, `EternityPhoenix` | The two new Mythics, textured GLBs (see CREATURE_MESHES.md) |
| Spin Wheel art | Background image for the 🎡 wheel ([ICONS.md](ICONS.md)); paste its id in `Config.Images.SpinWheel` |
