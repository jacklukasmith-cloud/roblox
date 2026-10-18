# Mythic Tamers: Expansion Plan

Plans for the next big chunk of the game. Nothing here is built yet. Sizes are rough:
**S** = an evening, **M** = a few sessions, **L** = a big update.

What's in it:
1. [Player bases](#1-player-bases-the-sanctuary)
2. [The Gloomwood (gloomy forest)](#2-the-gloomwood)
3. [Crafting: potions, teleport crystals, vehicles](#3-crafting-at-your-base)
4. [A bigger hub](#4-a-bigger-hub)
5. [Better leaderboards](#5-better-leaderboards)
6. [Reasons to invite friends](#6-reasons-to-invite-friends)
7. [More zones and a longer game](#7-more-zones-and-a-longer-game)
8. [Build order](#8-build-order)
9. [Questions to decide](#9-questions-to-decide)

How it all fits together:

```
            HUB (bigger, with a portal ring)
           /        |           \
   Realms 1-8   Gloomwood      Your Sanctuary (base)
  (break crystals,  (find rare   (store crystals, craft potions,
   hatch pets)    Gloom Crystals)  teleport crystals, hoverboards, cars)
        \_____________|______________/
     Essence + crystals + pets  ->  crafted items  ->  faster farming / exploring
```

---

## 1. Player bases (the Sanctuary)

Every player gets their own **Sanctuary**: a floating island they own, reached from a portal in the hub.

**Decided:**
- **Location:** islands in each server that other players can visit, reached through the Sanctuary portal in
  Portal Plaza.
- **Look:** a floating sky island with waterfalls off the edges and glowing crystals.
- **Building it up:** a fixed layout with **upgrade levels 1-10**, paid with Essence. Each level unlocks stations,
  decorations and a bigger island.
- **First version includes all four stations:** Pet Habitat, Crystal Vault, Alchemy Cauldron and Hangar.
- **Money (looks and time-savers only, nothing pay-to-win):**
  - island themes (crystal cave, lava isle, candy island...);
  - decoration packs;
  - a faster-crafting pass (2 cauldron slots, 25% faster) plus a small "finish brew now" product;
  - hoverboard and kart skins.
- **Fun extras:**
  - ~~visit and ❤️ like other players' bases, with a weekly "Most Liked Sanctuary" board~~ (done; a prize for the
    weekly top 3 is still to come);
  - ~~a daily island chest~~ (done: the 🧰 chest by the Upgrade Stone, better loot per island level);
  - ~~a pet playground that earns pet XP while you're away~~ (done: it's part of the Pet Habitat);
  - a crystal garden where seeds grow over real time (like Grow a Garden).

**How it works (recommended):** each server has a ring of floating base plots away from the main map (like a
tycoon game's plots). When you join, you're given a free plot and your saved base is built on it. When you leave,
it's removed. Everyone in the server can visit everyone else's base. This is simpler and cheaper than private
servers, and visiting is part of the fun.

**What's in a base:**
| Station | What it does |
|---|---|
| **Crystal Vault** | Stores the Gloom Crystals you send home from the forest. Upgrade it for more space. |
| **Alchemy Cauldron** | Brews potions (see crafting). |
| **Crystal Forge** | Makes teleport crystals. |
| **Hangar** | Builds hoverboards and cars. Your vehicles are kept here. |
| **Pet Habitat** | Your favourite pets wander around your base so visitors can see them. |
| **Decorations** | Statues, lights and plants bought with Essence or crafted. Pure show-off. |

**Base level (1 to 10):** upgrading costs Essence plus crystals. Each level unlocks a new station, more vault
space or new recipes. This is a long-term goal that doesn't reset on Rebirth.

**Getting there:** a Sanctuary portal in the hub, a "🏠 Base" button once you've unlocked it, and later a crafted
Home Teleport Crystal.

Size: **L**. It needs a new BaseService, base data in the save, plot placement, stations and a base panel.

---

## 2. The Gloomwood

A dark, foggy forest reached through a gate in the hub. It's a different kind of play from the realms:
**explore and search** instead of standing at a crystal.

**Unlock:** you need Frostpeak (realm 3) unlocked, so new players aren't overwhelmed and it gives mid-game players
something new.

**The feel:** thick fog, a dark purple-green sky, twisted trees, glowing mushrooms, fireflies, creaky sounds. It's
built from parts and textures, not Terrain. Your pets carry little lanterns.

**Size: very big, so the rare crystals are a real challenge.** The plan is about **1,200 x 1,200 studs**,
around 60 times the area of one realm. Walking straight from the gate to the centre takes about 40 seconds, but
the paths wind, the fog hides everything past ~60 studs and there's no straight route. A trip to the Heart and
back is a proper expedition of 5-10 minutes. The forest is built in **rings** that get darker, harder and more
rewarding the deeper you go:

```
 +--------------------------------------------------+
 |  EDGE (gate side)  - light fog, wide paths        |
 |   +------------------------------------------+   |
 |   |  MIDWOOD - thicker fog, side trails,      |   |
 |   |  burnt clearing, frozen pond, Deep Camp   |   |
 |   |   +----------------------------------+   |   |
 |   |   |  DEEPWOOD - dark, cliffs + caves, |   |   |
 |   |   |  few lanterns, Gloom fills fast   |   |   |
 |   |   |       +------------------+       |   |   |
 |   |   |       |  THE HEART       |       |   |   |
 |   |   |       |  (Prismheart)    |       |   |   |
 |   |   |       +------------------+       |   |   |
 |   |   +----------------------------------+   |   |
 |   +------------------------------------------+   |
 +--------------------------------------------------+
```

| Ring | Distance from the gate | Crystals | Lanterns | Gloom meter |
|---|---|---|---|---|
| Edge | 0-250 studs | Moonshard | Many | Barely moves |
| Midwood | 250-550 | Moonshard, Emberheart, Frostglass | Every ~120 studs | Slow |
| Deepwood | 550-850 | Stormquartz, Voidstone | Few and far apart | Fast |
| The Heart | centre | Prismheart (one at a time, moves each time it's found) | None | Very fast |

**What makes it a challenge (beyond the size):**
- **Getting lost is part of it.** Fog, look-alike trees and winding trails. There are landmarks to steer by:
  a giant dead tree, a broken watchtower, the frozen pond, a glowing stone circle.
- **Rare crystals are hidden**, not lying on the path: behind waterfalls, on top of cliffs you have to climb or
  parkour to, inside caves and in hollow trees.
- **Crystals move.** Each spot regrows on a timer and rare ones respawn at a random hidden spot, so you can't
  just memorise one route.
- **Map Fragments** found in the forest slowly fill in a map in your UI. Players who explore more get better at
  finding their way.
- **The Deep Camp** (in Midwood) is a safe spot with a lantern and a teleport point once you've found it. It
  works like a checkpoint so deep trips don't always start from the gate.
- **Vehicles** work in the Edge and Midwood, but the Deepwood and the Heart are too thick with roots: you walk.
- **The Heart** has a guardian (a Gloom Treant boss) that wakes up when you mine the Prismheart.

**Keeping it running smoothly on phones:** a forest this big needs care.
- Use Roblox's **StreamingEnabled**, so each player only loads the area around them.
- Trees are a handful of reused models, not thousands of separate parts.
- The fog hides the distance anyway, so far-off detail doesn't need to load.

**Gloom Crystals** grow hidden around the forest: behind trees, in hollows, in caves and on ledges. Each glows
faintly and hums when you're close. You mine them with **your pickaxe**, which gives the pickaxe a big new job.
| Crystal | Rarity | Where |
|---|---|---|
| Moonshard | Common | Everywhere |
| Emberheart | Uncommon | Near the burnt clearing |
| Frostglass | Uncommon | By the frozen pond |
| Stormquartz | Rare | On high ledges (jump or hoverboard to reach) |
| Voidstone | Epic | Deep caves, in darker areas |
| Prismheart | Legendary | Rare spawn, with a server-wide "a Prismheart is glowing somewhere..." message |

**Risk and reward (what makes it exciting):**
- **Satchel:** you can only carry so many crystals (for example 20). You have to **send them home** to keep them.
- **Courier Lanterns** are dotted around the forest. Stand at one to send your satchel to your base vault safely.
- **Gloom meter:** it slowly fills while you're deep in the forest and fills faster in the dark areas. Standing
  by a lantern lowers it. If it fills up, you're pushed out of the forest and **drop half of your unsent
  crystals**. So you choose between pushing deeper for rare crystals and heading back to bank them.
- ~~Forest animals~~ (done): Shadow Wolves roam and chase, Bramble Boars and Moss Bears guard crystals and wake
  when you mine them; pets help fight them.
- **Shadow Wisps** float around and try to drain your satchel. Your pets fight them, so pet Power and Speed matter
  here too.
- **Gloom Ward potions** (crafted) slow the meter down.

**Later:** this is the natural home for the **very rare wild pets** idea. A wild creature could appear deep in
the Gloomwood now and then and has to be found and tamed.

Size: **L+** for the area plus systems, because of how big it is. It's best built in two steps: the Edge and
Midwood first (with lanterns, satchel and the Gloom meter), then the Deepwood and the Heart. The art can start
simple and be improved with Higgsfield models.

---

## 3. Crafting at your base

Recipes use **Gloom Crystals + Essence** (and sometimes a pet). Crafting takes time, so you set up a brew, go
farming, and come back. Ideas:

**Potions (Alchemy Cauldron)**
| Potion | Effect | Example recipe |
|---|---|---|
| Luck Potion | +50% Rare+ hatch chance, 10 min | 5 Moonshard + Essence |
| Essence Potion | x2 Essence, 10 min | 3 Moonshard + 2 Emberheart |
| Swift Potion | +30% walk speed, 10 min | 4 Frostglass |
| Gloom Ward | Gloom meter fills 50% slower, 1 forest trip | 3 Moonshard + 1 Voidstone |
| Shiny Elixir | x3 Shiny chance, 5 min | 2 Stormquartz + 1 Voidstone |

**Teleport crystals (Crystal Forge)** are single-use crystals that teleport you instantly:
- Hub, any unlocked realm, your base, a **friend's base**, or the **Deep Camp** (a safe camp in the middle of the
  Gloomwood).

**Vehicles (Hangar)** are built once and kept forever. You summon one with a button.
| Vehicle | Speed | Seats | Notes |
|---|---|---|---|
| Moss Board (hoverboard) | Fast | 1 | Starter vehicle |
| Crystal Hoverboard | Very fast | 1 | Glows in its crystal's colour; tricks on jumps |
| Mushroom Kart (car) | Fast | 2 | Bring a friend |
| Gloom Wagon | Medium | 4 | Party car |
| Prism Glider | Glides | 1 | Late-game; floats down from ledges |

Vehicles turn off inside realms while you're attacking crystals, so they don't make farming trivial. They're
for getting around the bigger hub, the forest and visiting bases.

**Monetization ideas (optional):**
- Robux skins for vehicles (looks only).
- A "Master Alchemist" game pass: 2 cauldron slots and 25% faster crafting.
- A small Developer Product to finish a craft instantly.

Size: **M** for the crafting system plus potions and teleport crystals. **M** for vehicles (VehicleSeat or a
custom hover controller).

---

## 4. A bigger hub

The hub becomes a proper town square, about **2x the area** of now, split into districts so it doesn't feel
crowded:

```
                   [ Realm gates 1-8 ]
                          |
   [ House statues ] -- [ Plaza ] -- [ Market Row: Shop, Merchant, Blacksmith ]
                          |
     [ Leaderboard Hall ] | [ Portal Ring: Gloomwood gate, Sanctuary portal ]
                          |
                     [ Spawn + Egg Garden ]
```

- **Plaza:** spawn, a fountain, the season board and the Mana Surge obelisk.
- **Market Row:** the shop, the merchant, the Blacksmith and later an Alchemist NPC.
- **Leaderboard Hall:** the new boards (see below), with top-3 player statues.
- **Portal Ring:** the Gloomwood gate and the Sanctuary portal.
- **Egg Garden:** the egg pedestals, with more space around them.
- **Hoverboard paths** loop around the hub so vehicles have somewhere fun to go.

This builds on the `SPREAD` setting already in WorldBuilder, plus a new hub layout. Size: **M**.

---

## 5. Better leaderboards

Now there are two global boards (Trophies and Essence) plus the House and Surge boards. Plan:

- **More categories:**
  - Trophies
  - Total Essence
  - Rebirths
  - Index (species found)
  - Rarest pet owned
  - Crystals broken this week
  - Gloom Crystals found
  - Base level
- **Weekly and all-time** for each one, so new players can actually get on a board every week. The weekly boards
  reset on the same timer as Seasons.
- **Player avatar pictures** next to the names, and **top-3 statues** in the Leaderboard Hall that copy the
  real players' avatars.
- **A 🏆 Leaderboards panel** in the UI with tabs. It shows **your own rank** ("You: #1,204") even if you're not in
  the top 50.
- **Friends tab:** shows only you and your Roblox friends, so there's always a board you can win.

Size: **M**. It's mostly more OrderedDataStores, a panel, and avatar statues from
`Players:GetHumanoidDescriptionFromUserId`.

---

## 6. Reasons to invite friends

The things that work best in Roblox games are bonuses for **playing together**, not just for sending invites.
(Roblox's rules don't allow rewards just for sending an invite, but rewards for friends actually joining and
playing together are fine.)

1. **Friend Boost:** +10% Essence for each Roblox friend in the same server, up to +30%. It's shown on the HUD
   ("👥 +20% friend boost").
2. **Invite button:** opens Roblox's own invite screen (`SocialService:PromptGameInvite`).
3. **"Joined with a friend" reward:** when a friend joins **for the first time** from your invite, you **both**
   get a Friendship Egg with a chance at an exclusive **Twin Spirit** pet that can only be hatched this way.
4. **Co-op bonuses:**
   - Friends breaking the same Mana Chest or boss get +25% rewards each.
   - Bosses get a "team up" banner when friends fight together.
5. **Things that are better with friends:**
   - Visit each other's bases.
   - Ride in each other's karts and wagons (2 and 4 seats).
   - Teleport to a friend's base with a teleport crystal.
6. **Friend quests:** daily quests like "Break 50 crystals with a friend" that pay extra.
7. **Trading** (already on the roadmap) is the biggest reason people bring friends in pet games.

Size: Friend Boost and the invite button are **S**. The invite reward and co-op bonuses are **M**.

---

## 7. More zones and a longer game

**Why it might feel too easy:**
- You own every game pass. VIP plus 2x Essence is already **3x Essence**, plus Auto Collect and 3 extra slots.
- There are only 4 realms. Sky Sanctum unlocks at 1.5M Essence, which a boosted player reaches quickly.
- To check properly, test without your passes. Plan item: add a **`!nopasses`** admin command that pretends you
  own nothing (only for you and only in testing), plus `!reset confirm`, so you can play it like a new player.

**New realms (5 to 8):** each one costs about **25x** more than the last and has crystals about **25x** stronger.
Each has its own egg with 5 creatures, a boss, a pickaxe tier that suits it and ground textures.
| # | Realm | Theme | Unlock | Extra requirement |
|---|---|---|---|---|
| 5 | Coral Abyss | Underwater reef, bubbles, glowing coral | ~40M | 1 Rebirth |
| 6 | Sunscorch Dunes | Desert ruins, sandstorms | ~1B | 3 Rebirths |
| 7 | Clockwork Citadel | Brass gears and steam | ~25B | 5 Rebirths and 40 species in the Index |
| 8 | Astral Void | Space, floating islands, stars | ~600B | 8 Rebirths and a base level of 5 |

**Other ways to make the game last longer:**
- Gates need **more than Essence**: Rebirths, Index count or base level. You can't just buy your way through.
- A **Mastery** goal for each realm: break 10,000 crystals there for a permanent +10% in that realm and a badge.
- A **Rebirth shop**: Rebirth Tokens buy permanent upgrades (more satchel space, faster crafting, an extra pet slot).
- **Prestige titles** after 10, 25 and 50 rebirths.
- **Ultra-rare pets** (1 in a million) that people chase for weeks.

Size: each new realm is **M**. They need an egg, 5 creatures and their models, a boss, textures and tuning.
The Rebirth and Index requirements are **S**.

---

## Ideas from other games

**Already added** (the Bag update): the 🎒 Bag, collect-then-use potions, Pet Treats, Mystery Gifts, Treasure Maps,
Boss Horns and item drops from crystals, chests and bosses. These come from Pet Simulator 99's breakables, gifts
and potions, Bee Swarm Simulator's treats and Grow a Garden's restocking shop.

**More ideas to add later:**
| Idea | From | How it would work here |
|---|---|---|
| **Enchant books** | Pet Simulator 99 | Equip up to 3 enchants (+10% Essence, +Luck, +Crit). Found as rare drops or crafted at the base. |
| **Pet cosmetics** | Adopt Me | Hats, wings and trails for creatures. Earned from missions, gifts and events; some sold for Robux. |
| **Ride and fly on pets** | Adopt Me | A "Ride Potion" or "Fly Potion" makes one creature rideable or flyable for good. |
| **Gold and Rainbow machines** | Pet Simulator | Turn 5 pets into a Golden one at a machine. Different from fusion: it uses up common pets. |
| **Huge pets** | Pet Simulator 99 | Ultra-rare, extra-big versions of creatures (1 in 100,000+). They're what people chase. |
| **Key and lock chests** | Pet Simulator 99 | Crystal Keys (from bosses) open a locked chest in each realm with big loot. |
| ~~**Codes**~~ (done) | Most Roblox games | A "Codes" box in Settings. Codes give potions or gifts. Great for TikTok and YouTube. |
| **Spin wheel** | Pet Simulator / Bee Swarm | A free spin every few hours for a random item. |
| **Fishing or mini-games** | Fisch | A timing mini-game at a pond in the hub that pays out items. |
| **Event items** | Grow a Garden | Limited items during weekend events that never return. People log in for them. |
| ~~**Trading**~~ (done) | Adopt Me / PS99 | Trade creatures and items with a confirm screen. This is the biggest one for a lasting economy. |
| **Item index** | Pet Simulator 99 | An Index page for items as well as creatures, with a reward for finding every item. |

## Decided next ideas

- **Rule for Robux:** mostly cosmetics and time-savers. Boosts stay modest, so free players can still reach the top.
- **Weekend events:** ~~rotating bonus weekends~~ (done: Double Essence, Lucky, Hatch Fest, Gloom Rush, Shiny); limited event realms or eggs (Halloween, Snow festival) with pets that never come back are still to come.
- ~~**Spin wheel:** one free spin every 4 hours, and extra spins for Robux.~~ (done: 🎡 Spin, Spin Pack product)
- ~~**Huge pets:** ultra-rare giant versions of creatures.~~ (done: 1 in 50,000, x12 power, 2.4x size, global banner, Most HUGE Pets board)

## Missions for the new content

The main game now has a mission chain (`src/shared/Missions.luau`). Each new part of the expansion
should add its own missions to the end of that list, so the missions keep guiding players into new
content. For example:
- ~~"Enter the Gloomwood", "Send 10 crystals home", "Reach the Deep Camp"~~ (done), "Find a Stormquartz"
- ~~"Visit your Sanctuary", "Redeem a code", "Check the Leaderboards", island levels 2 and 3, "Brew your first
  potion", "Build a hoverboard"~~ (done)
- "Visit a friend's base", "Unlock Coral Abyss"

## 8. Build order

Each step works by itself and makes the next one easier.

| Step | What | Why first | Size |
|---|---|---|---|
| 1 | ~~`!nopasses` test command~~ (done) plus a difficulty check | So we can tell how easy the game really is before adding more | S |
| 2 | ~~Friend Boost (+5% per friend) and the invite button~~ (done) | Quick, and helps the game grow straight away | S |
| 3 | ~~Leaderboard panel, weekly boards and your rank~~ (done) | Quick win, gives everyone something to chase | M |
| 4 | ~~Bigger hub with districts~~ (done: west wing for the Merchant and Blacksmith, House Quarter, Portal Plaza) | Makes room for the portals, boards and vehicles below | M |
| 5 | ~~Sanctuary base: islands and travel, levels 1-10, Pet Habitat with XP while away, Crystal Vault, Alchemy Cauldron, Hangar~~ (done) | Everything after this needs a base | L |
| 6a | ~~Gloomwood part 1: Edge and Midwood, Gloom Crystals, satchel, lanterns, Gloom meter, Deep Camp~~ (done, with the Crystal Vault and selling) | The main new adventure | L |
| 6b | Gloomwood part 2: Deepwood (cliffs, caves), the Heart, Prismheart, Gloom Treant, Map Fragments | Where the hardest, rarest crystals are | L |
| 7 | ~~Crafting: potions and teleport crystals~~ (done: the Cauldron brews 9 potions and 3 teleport crystals) | Gives forest crystals a use | M |
| 8 | Vehicles: ~~hoverboards~~ (done: the Hangar, three boards, Board Skins pass), ~~then karts~~ (done: Mushroom Kart with a passenger seat; the 4-seat Gloom Wagon is still to come) | Fun to show off, and good with friends | M |
| 9 | Realms 5 and 6, plus Rebirth requirements | Fixes "I finished it" for top players | M each |
| 10 | Joined-with-a-friend reward, co-op bonuses, friend quests | Builds on bases and vehicles | M |
| 11 | Wild pets in the Gloomwood, realms 7 and 8 | Later content updates | M to L |

**What I'll need from you along the way:**
- Approval of names and themes.
- Higgsfield models for stations, vehicles, Gloom Crystals and the new creatures. I can generate these.
- New game pass and product IDs if we add the crafting pass.
- Testing in Studio after each step.

---

## 9. Questions to decide

1. ~~**Bases:**~~ decided: islands in each server, floating sky island, upgrade levels, all four stations.
2. ~~**Gloomwood danger:**~~ decided: a full Gloom meter pushes you out and you **drop half** of your unsent
   crystals. In part 1 the crystals go to the Crystal Vault and can be sold; Shadow Wisps come with part 2.
3. **Crafting timers:** real-time timers that run while you're offline (keeps people coming back), or instant
   crafting?
4. **Vehicles in realms:** allowed everywhere, or only in the hub, forest and bases (recommended, so farming
   stays the same)?
5. **New realm themes:** do Coral Abyss, Sunscorch Dunes, Clockwork Citadel and Astral Void sound good, or do you
   have others in mind?
