# Sounds & music

Every sound can be swapped for one from Roblox's free library. **Insert it, rename it, done**: the game
picks up any Sound with one of the names below (anywhere in Workspace, or in `ReplicatedStorage.GameSounds`).

## How to swap a sound (about 30 seconds each)

1. In Studio open **View → Toolbox**, pick the **Audio** tab (the music-note icon).
2. Search using the suggestions below. Press the **play button** on a result to preview it.
3. Click the one you like to insert it. It appears in **Workspace** as a Sound.
4. In the Explorer, **rename** it to the name in the table (exact spelling).
5. Press **Play**. Output says *"Using N custom sound(s)"*. Save the place when you're happy.

| Rename it to | Plays when | Try searching for |
|---|---|---|
| `Hit` | creatures hit a crystal (plays a lot, so keep it short and soft) | `crystal tap`, `gem hit`, `pop`, `soft hit` |
| `Break` | a crystal breaks | `crystal break`, `gem shatter`, `magic pop` |
| `ChestBreak` | a Mana Chest breaks | `treasure chest open`, `loot`, `big magic burst` |
| `Orb` | each Essence orb is collected | `coin collect`, `pickup`, `sparkle` |
| `EggShake` | an egg rattles before hatching | `egg crack`, `wobble`, `rattle` |
| `Reveal` | a creature hatches | `reveal`, `magic sparkle`, `ta-da` |
| `RareReveal` | a Legendary+, Shiny or Rainbow hatches | `epic reveal`, `victory`, `legendary` |
| `Fanfare` | Mana Surge starts, realm unlocked, rebirth | `fanfare`, `level up`, `achievement` |
| `Click` | menu buttons | `ui click`, `button` |
| `MusicHub` | music (used everywhere unless a realm has its own) | Audio → Music: `fantasy`, `adventure`, `magical`, `cozy` |
| `MusicMeadow` / `MusicEmber` / `MusicFrost` / `MusicSky` | music for one realm | `forest`, `lava`/`volcano`, `snow`/`winter`, `sky`/`heavenly` |

Tips:
- Set each Sound's **Volume** in the Properties panel: around 0.3 for `Hit`/`Orb`, 0.5 for the rest, 0.3–0.4 for music.
- Your sounds keep their natural pitch (with a tiny bit of variation so repeats don't sound robotic).
- Sounds you haven't replaced use simple built-in Roblox sounds; the generated music box is off
  (turn it back on with `Config.MusicBox = true`).
- Players can switch **Music** and **Sound Effects** off in **Settings**.
