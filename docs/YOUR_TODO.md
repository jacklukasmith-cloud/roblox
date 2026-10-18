# Things only you can do

Everything here needs the Creator Hub or Roblox Studio, so Claude can't do it from the repo. None of it blocks
playing: every feature has a built-in fallback until you fill it in. Newest items are added at the bottom of
each section; tick things off as you go.

## 1. IDs to paste into `src/shared/Config.luau`

| What | Where in Config | Status |
|---|---|---|
| Board Skins game pass (hoverboard colours) | `Config.GamePasses` → `BoardSkins.Id` | `Id = 0` |
| Spin Pack developer product (5 spins) | `Config.DevProducts` → `SpinPack.Id` | `Id = 0` |
| Price check: set the real Robux prices on the Creator Hub (the `PriceHint`s are only shown in the shop UI) | all passes/products | - |

## 2. Images to upload (Creator Hub → Creations → Development Items → Images / Decals)

| Image | Link | Paste the `rbxassetid://` into |
|---|---|---|
| Gloomwood map parchment | [ICONS.md](ICONS.md) / [HIGGSFIELD_TODO.md](HIGGSFIELD_TODO.md) | `Gloomwood.MapImage` in `src/shared/Gloomwood.luau` |
| Spin Wheel art | [ICONS.md](ICONS.md) | `Config.Images.SpinWheel` |
| Master Alchemist, Board Skins, Spin Pack icons | [ICONS.md](ICONS.md) | the pass/product `Icon` fields, and the pass/product page on the Creator Hub |

## 3. 3D models to import into Studio

1. Run `scripts\download-world.bat` (or `download-world.sh`) to fetch every GLB.
2. In Studio: **File → Import 3D**, pick the files, keep the names, put them in `ReplicatedStorage.WorldMeshes`.
3. The game finds them by name automatically ([WORLD_MESHES.md](WORLD_MESHES.md) has the full list).

New since the last import:

| Model | Used for |
|---|---|
| `AlchemyCauldron`, `PrismheartCrystal` | the island Cauldron, the Heart crystal |
| `VehicleMossBoard`, `VehicleCrystalBoard` | hoverboards under your feet |
| `VehicleMushroomKart` | the kart (the game adds the passenger seat) |
| `IslandChest` | the daily chest on every island |
| `StarfallEgg`, `VoidEgg`, `StarfallCrystal`, `VoidCrystal` | realm 5 and 6 egg stands and crystals |
| `StarfallColossus`, `EternityPhoenix` (run `download-creatures` too) | the two new Mythic creatures; import into `ReplicatedStorage.CreatureMeshes` |
| `GloomTreant` | static only: needs rigging in Studio (or Higgsfield rigging) before it can replace the walking block treant |

## 3b. Optional art for realms 5 and 6

Ground textures for `Config.GroundTextures[5]` / `[6]` and music for `Config.Sounds.MusicStarfall` / `MusicVoid`
are empty: the realms use plain sand and slate materials and the Sky music until you add them.

## 4. Game settings

- **Max Players = 8** (Creator Hub → experience → Places → Server size). There are 8 islands per server.
- **Enable Studio Access to API Services** (Game Settings → Security) so saving and leaderboards work in Studio.
- Add any co-admins' UserIds to `Config.AdminUserIds`.

## 5. Playtest these (Claude can't test physics or Roblox UI for real)

- **Mushroom Kart passenger seat:** a friend sits on the back and should be carried along. If they fall off or the
  kart jitters, say so and it'll be rebuilt as a proper driven vehicle.
- **Spin Wheel** animation and that the toast shows the right prize.
- **Island chest:** hold E on it, check the prompt switches to "Opened · back tomorrow".
- **Realms 5 and 6:** give yourself Essence with `!essence 50000000`, Rebirth, then check the Starfall gate shows "1 Rebirth" and refused before you had one.
- **Weekend events:** try `!event HatchFest 5` in chat and check the egg stands show the sale price and the HUD line.
- **❤️ Likes:** like a friend's island, check their sign count goes up and the weekly board shows it.
- **Teleport crystals** from the Bag: Home Crystal from the forest, Camp Crystal into the Deep Camp.
- **Hoverboards** switching off at the realm edge and in the Deepwood.
- **Gloomwood** fog getting darker deeper in, the Owl Eye Potion, and the Treant fight.
- The **What's New** pop-up shows once, then only from Settings.

## 6. Store page

- Update the experience description and thumbnails ([STORE_DESCRIPTION.md](STORE_DESCRIPTION.md)); the update
  thumbnails are on the Higgsfield list.
