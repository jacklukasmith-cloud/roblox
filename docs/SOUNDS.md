# Sounds & music

The game has sound straight away using sounds that ship with Roblox:

| Moment | Sound |
|---|---|
| Creatures hit a crystal | crystal tick (random pitch) |
| Crystal / Mana Chest breaks | glass shatter (deeper for chests) |
| Essence orbs collected | pings that climb in pitch as each orb lands |
| Egg hatching | rattles faster and higher, then a crack and a reveal jingle (bigger for rarer / Shiny / Rainbow) |
| Buttons | click |
| Mana Surge starts, zone unlocked, rebirth | fanfares |
| Music | a generated "music box" melody, different in every realm |

Players can turn **Music** and **Sound Effects** on/off in **Settings**.

## Swap in real music (recommended)

1. In Studio open the **Toolbox** → **Audio** → **Music**, search e.g. `fantasy`, `adventure`, `magic`, `chill`.
   Tracks uploaded by Roblox / licensed tracks are free to use.
2. Insert one; it appears in Workspace as a Sound. Rename it to one of these:

| Name | Plays in |
|---|---|
| `MusicHub` | the hub |
| `MusicMeadow` | Enchanted Meadow |
| `MusicEmber` | Ember Rift |
| `MusicFrost` | Frostpeak |
| `MusicSky` | Sky Sanctum |

3. Save and press Play. The game moves it into `ReplicatedStorage.GameSounds` and crossfades between realms.
   Set the Sound's **Volume** to taste (around 0.3–0.5).

You can replace any sound effect the same way: name a Sound `Hit`, `Break`, `ChestBreak`, `Orb`, `Click`,
`EggShake` or `Reveal`. Or paste asset ids into `Config.Sounds` in `src/shared/Config.luau`.
