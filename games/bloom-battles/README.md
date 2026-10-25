# +1 Bloom Every Second: Bloom Battles

A calm, low-poly Roblox game in the style of the "+1 every second" / mog battle games, with a
garden theme instead. Your flower spirit gains **+1 Bloom every second**. Bloom makes your
character bigger and brighter, opens new gardens with bigger multipliers, and powers you in
**Bloom Battles**: tap-fast tug-of-war duels against other players or wandering Garden Spirits.

Everything is built in code from blocks. No meshes, images or sounds need uploading.

## The loop

| Step | What happens |
| --- | --- |
| Grow | +1 Bloom per second, times your garden, Replant and game-pass multipliers. |
| Glow up | Your character scales up with Bloom (up to 3.2x) and wears a petal crown and aura that change colour at each of 8 tiers, from Seedling to Eternal Garden. |
| Explore | Four gardens in a row: Sunny Meadow (x1), Lavender Hills (x2 at 1K), Misty Lake (x4 at 25K) and Moon Grove (x8 at 500K). Gates dissolve once you reach the Bloom they need. |
| Battle | Every garden has an arena. Stand on a pad. A second player on the other pad starts a duel, or a Garden Spirit near your Bloom floats in after 4 seconds. |
| Replant | Spend 10K Bloom (x5 more each time) to reset and gain +50% on every gain, forever. |

**How a Bloom Battle works.** After a 3-second countdown you have 12 seconds to tap (click,
touch, Space or gamepad A). Each tap pulls the marker toward your opponent. How far a tap pulls
depends on your share of the total strength, and strength grows with Bloom. Bigger flowers pull
harder, but quick fingers still win close fights. Pull the marker all the way, or be ahead when
time runs out. The winner gets 10% of the loser's Bloom, capped to a minute of their own growth (25 seconds against a spirit)
so Bloom can't snowball. The loser still gets a little. The server owns the rope and rate-limits
taps.

## Effects

- Soft pastel lighting with bloom, haze, colour grading, sun rays and gentle depth of field.
  The time of day and colour mood ease into each garden: sunny afternoon, lavender golden hour,
  misty dusk, and a moonlit night.
- Drifting petals around the camera, and fireflies at the lake and in the grove.
- Swaying leaves and flowers, bobbing lily pads, flickering lanterns, glimmering crystals and
  slowly drifting block clouds.
- Floating "+N" pops above heads every second.
- Tier-ups: petal burst, flying low-poly shards, a growing ring, a soft screen flash, camera
  shake, an FOV punch, a banner and a chime melody.
- Battles: a side-on battle camera that always puts you on the left, a countdown, a tug bar,
  tap ripples, combo counter, sparks on the marker, confetti on a win.
- Gates shatter into shards when they open. Spirits arrive and leave in a puff.

## Run it in Studio

From the repository root (Rojo is already listed in `rokit.toml`):

```
rokit install
rojo serve games/bloom-battles/default.project.json
```

1. Open a new **Baseplate** place in Studio. The game removes the baseplate itself.
2. In the Rojo plugin, click **Connect**, then press **Play**.
3. To keep progress, publish the place and turn on
   **Game Settings > Security > Enable Studio Access to API Services**.

To build a place file instead of live syncing:

```
rojo build games/bloom-battles/default.project.json -o BloomBattles.rbxl
```

## Make it yours

All numbers live in `src/shared/Config.luau`: growth rate, tiers and colours, garden
requirements and multipliers, duel length, tap power, rewards and caps, and Replant cost.

- **Game pass:** create a "2x Bloom" pass and paste its id into `DoubleBloomPassId`.
- **Music and sounds:** paste asset ids into `Config.Sounds`. The defaults are built-in Roblox
  sounds so the game is never silent.
- **New garden:** add an entry to `Config.Zones`. The world builder lays it out automatically.

## Code map

| Path | What it does |
| --- | --- |
| `src/server/Services/World.luau` | Builds the low-poly world: tiles, hills, trees, flowers, lanterns, lake, crystals, gates, arenas, clouds. |
| `src/server/Services/Growth.luau` | +1 Bloom per second, multipliers, tiers, garden unlocks, Replant, character size, crown and aura. |
| `src/server/Services/Duels.luau` | Arena pads, Garden Spirit opponents, the server-side tug-of-war and rewards. |
| `src/server/Services/Data.luau` | DataStore load and save with retries, attributes and leaderstats. |
| `src/client/Modules/Atmosphere.luau` | Lighting, garden moods, ambient particles, animated scenery, gates. |
| `src/client/Modules/Effects.luau` | Bursts, shards, rings, pops, flashes, shake, FOV punch. |
| `src/client/Modules/Hud.luau` | Bloom counter, tier bar, stats, Replant button, toasts, banners. |
| `src/client/Modules/DuelUi.luau` | Battle screen, tap input and battle camera. |
