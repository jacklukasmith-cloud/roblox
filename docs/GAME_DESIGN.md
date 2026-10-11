# Mythic Tamers: Game Design

## Core loop
**Click crystals → earn Essence → hatch creatures → more Power → unlock the next realm → rebirth.**

- **Power** = 1 + the power of every equipped creature. Each click deals Power damage to a crystal.
- Crystals are **shared**: when one breaks, everyone who hit it is paid for their share of the damage.
  Players in the same zone naturally race each other.
- You start with 4 creature slots (+3 with a pass). Storage holds 150. Use **Equip Best** or **Release** extras.

## Realms
| # | Realm | Unlock | Crystal HP | Reward | Egg (cost) | Best drop |
|---|---|---|---|---|---|---|
| 1 | Enchanted Meadow | free | 10 | 5 | Meadow Egg (60) | Fae Dragonling 0.3% |
| 2 | Ember Rift | 2.5K | 250 | 90 | Ember Egg (1.5K) | Phoenix 0.3% |
| 3 | Frostpeak | 60K | 6K | 1.8K | Frost Egg (35K) | Aurora Kirin (Mythic) 0.02% |
| 4 | Sky Sanctum | 1.5M | 150K | 40K | Sky Egg (900K) | Void Leviathan (Mythic) 0.02% |
| hub | Champion Egg | - | - | - | **15 Trophies** | Titan Unicorn 5% |

25 creatures across 7 rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic, and Champion
(Champion creatures come only from Trophies). Each egg shows its odds above it.

**Variants:** each hatch can be **Shiny** (1/40, x2 power) or **Rainbow** (1/400, x5 power). Aurora
weather and the Shiny Elixir raise these odds.

## Progression systems
- **Rebirth:** costs 25K × 3^rebirths Essence and resets Essence and zones. Gives +50% Essence per rebirth, forever. Creatures are kept.
- **Bestiary:** +2% Essence for each species discovered (25 species = +50%).
- **Offline earnings:** while you're away, creatures gather Essence at 50% efficiency in your best zone. The cap is 8h (24h with the *Night Shift* pass).

## Competitive layer
### Mana Surge (inside each server, every ~4 min, lasts 90 s)
- Everyone earns **double Essence**, and a live top-5 scoreboard shows at the top of the screen.
- **Score = base crystal reward × rebirth multiplier.** Paid boosts (VIP, 2x, potions) **do not** count, so the competition stays fair.
- 1st/2nd/3rd win **5/3/2 Trophies** and 50/30/20 House points. Everyone who scored gets 1 Trophy.

### House War (across all servers, weekly)
- Pledge to **Emberclaw**, **Frostfang** or **Stormwing** at the hub. You can switch once per week.
- Breaking crystals earns points (higher zones are worth more), plus Surge placement bonuses.
- Each server adds its points to a shared global total once a minute. The winning House's members get
  **10 Trophies**; other participants get 2.

### Trophies
Trophies are the competitive currency. They're shown first on the player list, ranked on a global
leaderboard, and spent on the **Champion Egg**. They are **never sold for Robux**, so nobody can buy their way onto the board.

## Live-ops systems (synced across every server)
- **Weather**: every 10 minutes a 3-minute event rolls: Starfall (+50% Essence), Aurora (x3 Shiny),
  Eclipse (x1.5 luck) or the rare Mana Storm (x2 everything). The sky tints for everyone. The HUD forecasts the next one.
- **Wandering Merchant**: restocks every 5 minutes. It sells Luck/Essence potions, the Shiny Elixir and the
  Mystic Egg (guaranteed Rare+). Prices scale with your best zone.
- **Admin events**: the `!surge`, `!weather` and `!announce` chat commands run in every server at once.

## Monetization
| Type | Item | Suggested R$ | Why players buy it |
|---|---|---|---|
| Pass | VIP | 199 | +50% Essence, gold `[VIP]` chat tag (status) |
| Pass | 2x Essence | 299 | The classic best seller |
| Pass | Auto Collect | 149 | Convenience: mines nearby crystals for you |
| Pass | Lucky Hatch | 249 | x1.5 Rare+ odds, forever |
| Pass | Triple Hatch | 199 | The "Hatch x3" prompt shows on every egg and asks free players to buy it |
| Pass | +3 Creature Slots | 349 | Direct Power increase |
| Pass | Night Shift | 99 | Cheap impulse buy: 24h offline earnings |
| Product | Essence Pouch / Chest | 49 / 249 | Scales with your best zone, so it stays worth buying |
| Product | Luck Potion | 79 | Repeat purchase, stacks time |
| Product | Merchant Restock | 39 | Repeat purchase when a Mystic Egg sells out |

Design rules: **sell speed and convenience, never Trophies or wins**. Show all odds. All product
receipts are recorded in the save file, so purchases can't be granted twice.

## Roadmap ideas (next updates)
1. **Trading** with a confirm screen, a 5-second lock and a trade log. This is what drives Adopt Me's and PS99's economies.
2. **Quest NPCs** (Bee Swarm style): daily and weekly quests that reward potions and eggs.
3. **Creature fusion**: combine 5 of a kind into a Shiny, 5 Shinies into a Rainbow. This adds a reason to keep duplicates.
4. **Limited-time event eggs** (Halloween, Winter) with exclusive creatures that never return.
5. **Boss raids**: a giant crystal golem every hour that everyone in the server fights together.
6. **Skill minigame** (Fisch style): a timing bar on Legendary crystals for bonus rewards.
7. **Hand-made meshes**: the procedural creatures can be swapped for Blender/Studio meshes later. `CreatureModels.Build`
   is the only place that needs to change. A game thumbnail is also still needed.
8. **Rewarded video ads**, if eligible, for a free potion, and **subscriptions** (monthly VIP perks).
