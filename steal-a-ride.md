# Steal a Ride: Game Plan and Build Spec

**Pitch:** Steal eggs from guarded biomes, hatch them, then **ride what you hatch**. Your creatures either earn money in your pen or carry you faster and further into tougher biomes. Every creature forces a choice: put it to work, or saddle it up.

> **For the AI reading this:** you're connected to Roblox Studio through MCP. Build this game inside the currently open place by creating the Instances, scripts, UI and objects yourself.
>
> **Build one part at a time.** Only build the part the user asks for (Part 1–6, under *Build parts*). When the part is done, playtest it, fix all errors, then stop and report what you built.

---

## 1. Research: what we borrow and what we cut

| Mechanic | Seen in | Our version |
|---|---|---|
| Grab an egg from a guarded nest and run it home before the guardian catches you | Steal an Egg | **Kept.** This is the core heist. |
| Speed gates each biome (Lake needs 900 speed, Cosmic 700M) | Steal an Egg | **Kept, but speed comes from the creature you ride**, not from grinding. |
| Treadmill speed training that showed AI-generated video feeds | Steal an Egg | **Cut.** Roblox pulled the game on Aug 24, 2026 until the feed was removed. On Aug 27 it age-gated games that reward watching autoplay or infinite-scroll media. |
| Steal from other players' bases; base locks (30 s on join, 60 s relock, +10 s per rebirth) | Steal a Brainrot | **Kept, but only eggs can be stolen.** Hatched creatures are always safe. |
| Steal an egg straight off a player who's carrying it | Steal an Egg | **Kept** |
| Fuse 3 identical pets into a higher rarity | Steal an Egg | **Kept** |
| Secret eggs on a 5-minute cycle | Steal an Egg | **Kept,** as a server-wide race |
| Weather events that mutate items for big value multipliers | Grow a Garden | **Kept:** weather mutates any egg you grab during the event |
| Growth continues while offline | Grow a Garden | **Kept:** eggs keep hatching offline, and the pen earns offline |
| Riding your pets to explore | Ride A Pet (#4 on Roblox, Sept 2026) | **The core twist** |
| An opt-out from PvP for players who don't want it | Build a Base and Steal | **New-player shield** for the first 15 minutes |

---

## 2. The twist: what you hatch, you ride

- **Every creature has three possible jobs:**
  - **In the pen:** earns cash every second.
  - **As your mount:** sets your speed and gives you its ability. It earns nothing while you ride it.
  - **In the stable:** storage, and fodder for fusing.
- **Your speed depends on what you ride.** A player on foot can only escape the Forest. To reach the Lake, you have to ride something you hatched in the Forest.
- **Abilities open escape lanes.** Each biome from the Lake on has a side lane that guardians can't enter: water, ledges, a chasm, lava or an energy wall. With the right ability, you can escape at lower speed. Creatures from early biomes carry the abilities you need for later ones, so the map plays like a light Metroidvania.
- **The core tension:** your best creature earns the most in the pen, but it's also your best mount.
- **On Rebirth you keep the creatures you're riding,** so each new run starts faster.

---

## 3. Core loop

1. Ride (or walk) out to a biome and grab an egg from the nest.
2. The guardian wakes up. Outrun it, or slip into an escape lane.
3. Get home. Other players can steal your egg along the way.
4. The egg goes into an incubator and hatches into a creature with a random species, rarity and possibly a mutation.
5. Put the creature in the pen for cash, ride it for speed and its ability, or fuse it.
6. Spend cash on saddle speed, incubators, pen slots and gear.
7. Reach deeper biomes for better eggs, then Rebirth for permanent multipliers.

---

## 4. World layout

**Parts 1–5 use Roblox primitives only, with no external models.** Part 6 then swaps in AI-generated meshes, materials and props made with Roblox Studio's built-in MCP tools, plus free Creator Store sounds. Keep every primitive version as a fallback.

```
[ Home Row ]  8 plots, 4 on each side of a 40-stud avenue, each plot 60x60 studs
      |
[ Biome Road ]  one straight road heading out from the end of Home Row
      |
  Forest → Lake → Desert → Jungle → Tundra → Volcano → Cosmic
  (each biome is 160 studs wide; depth is in the table below; 20-stud gaps between biomes)
```

- **Each biome:**
  - A themed ground color and material, with simple primitive props (trees, rocks, cacti, ice spikes, lava rocks, floating stars).
  - The **nest** sits at the far end, with the guardian sleeping 12 studs away.
  - An **exit line** at the biome's entrance (the side nearest home), marked by a glowing arch.
  - An **escape lane** running along one side, starting 30% of the way from the nest toward the exit and ending at the exit line.
- **Plaza:** a small area at the start of Home Row with the Fuse Machine, the Gear Shop and the Index board.
- **Lighting:** a different `Atmosphere` and `ColorCorrection` per biome, applied client-side when the player enters it.

---

## 5. Biomes

| # | Biome | Guardian | Guardian speed | Depth (studs) | Min escape speed* | Mount base speed** | Escape lane | Hatch time | Base income/s |
|---|---|---|---:|---:|---:|---:|---|---:|---:|
| 1 | Forest | Chicken | 14 | 140 | 11.6 | 18 | (none) | 10 s | 5 |
| 2 | Lake | Swan | 20 | 200 | 16.9 | 23 | Swim (water) | 20 s | 30 |
| 3 | Desert | Scorpion | 26 | 260 | 22.2 | 29 | Jump (mesa ledges) | 30 s | 150 |
| 4 | Jungle | Tiger | 33 | 330 | 28.4 | 35 | Swim (river) | 45 s | 800 |
| 5 | Tundra | Yeti | 40 | 400 | 34.6 | 42 | Glide (ice chasm) | 60 s | 4,000 |
| 6 | Volcano | Hellhound | 48 | 480 | 41.6 | 51 | Fireproof (lava river) | 90 s | 20,000 |
| 7 | Cosmic | Dragon | 58 | 580 | 50.4 | 60 | Phase (energy wall) | 120 s | 100,000 |

\* **Min escape speed** is the slowest speed that still escapes on the main road. It's calculated from: guardian wakes 1.5 s after the grab, sleeps 12 studs from the nest, depth = 10 × guardian speed. The default walk speed is 16, so **walkers can only escape the Forest.**
\*\* **Mount base speed** applies to the Common creatures of that biome. It's set so a biome's Common mount just clears the **next** biome.

**Nests:** the Forest nest holds 8 eggs and refills one egg every 20 s, so new players never get stuck. Every other nest holds 6 eggs, and they all refill together every 3 minutes with a server announcement: *"Nests refilled!"*

---

## 6. Creatures

### Species (3 per biome, built procedurally from primitives)

| Biome | Species (hatch weight 50 / 35 / 15%) | Abilities |
|---|---|---|
| Forest | Chick, Bunny, Fox | none (+2 speed), Jump, Dash |
| Lake | Duckling, Frog, Otter | Swim, Jump, Swim |
| Desert | Scarab, Lizard, Vulture | none (+2 speed), Dash, Glide |
| Jungle | Monkey, Parrot, Panther | Jump, Glide, Dash |
| Tundra | Penguin, Snow Owl, Mammoth | Swim, Glide, none (+2 speed) |
| Volcano | Salamander, Ember Bat, Hellpup | Fireproof, Glide, Dash |
| Cosmic | Star Jelly, Comet Fox, Baby Dragon | Phase, Dash, Phase |

### Rarity (rolled on hatch, on the server)

| Rarity | Odds | Income × | Mount speed + | Model scale |
|---|---:|---:|---:|---:|
| Common | 55% | 1 | +0 | 1.0 |
| Uncommon | 28% | 2 | +2 | 1.1 |
| Rare | 12% | 4 | +4 | 1.2 |
| Epic | 4% | 10 | +7 | 1.35 |
| Legendary | 1% | 25 | +12 | 1.5 |
| Mythic | Secret Eggs only | 100 | +18 | 1.7 |

### Mutations (rolled when the egg is grabbed during a weather event)

| Mutation | Event | Chance | Income × | Mount speed + | Look |
|---|---|---:|---:|---:|---|
| Shocked | Thunderstorm | 30% | 2 | +1 | Blue spark particles |
| Golden | Golden Hour | 15% | 3 | +2 | Gold material and shine |
| Cursed | Blood Moon | 10% | 5 | +3 | Dark red neon and smoke |

### Formulas

```
income/s   = biomeBaseIncome * rarityX * mutationX * rebirthMult
mountSpeed = biomeMountBase + rarityBonus + mutationBonus + (2 if species has no ability)
playerSpeed = (riding ? best mountSpeed : 16) + saddleLevel
rebirthMult = 1 + 0.5 * Rebirths
```

### CreatureBuilder

CreatureBuilder is a shared ModuleScript that builds a creature model from `(species, rarity, mutation)`. Each species is a small parts recipe:
- body shape (Ball or Block) and color
- head and eyes
- one feature: ears, wings, fins, horns, tail, shell or tentacles

The model is scaled by rarity and gets a mutation effect. Use the same builder for pen models, mounts, incubator previews and UI ViewportFrames.

---

## 7. Abilities

| Ability | How it works |
|---|---|
| **Dash** | Press the ability key (or mobile button): 2× speed for 1.5 s, 8 s cooldown. Tell the server through the `UseAbility` remote so the anti-speed check allows the burst. |
| **Jump** | JumpPower ×2 while riding. Lets the player climb mesa ledges. |
| **Glide** | While airborne, a VectorForce cancels 80% of gravity. Lets the player cross the ice chasm. |
| **Swim** | Full speed in water zones; non-swimmers drop to speed 6 in water. |
| **Fireproof** | Can cross lava. Non-fireproof players touching lava drop their egg (back to the nest) and respawn at the biome exit. |
| **Phase** | Can pass through energy walls (non-collidable only for Phase riders, using a client-side CollisionGroup). The server checks the ability before honoring the lane. |

- **Escape lanes:** guardians stop chasing as soon as their target enters a lane zone (`Workspace.Biomes.<Biome>.EscapeLane`). A player who isn't allowed in a lane gets the penalty for that obstacle.
- **Two mounts** (Rebirth 3 or the game pass): speed comes from the faster mount, and the player gets both abilities.

---

## 8. Guardians

- Build each guardian from primitives and keep it **anchored**. Move it on the server with `PivotTo` on Heartbeat at its speed. Don't use Humanoids or pathfinding; the road is flat.
- **Sleep:** idles next to the nest with a gentle breathing animation.
- **Wake:** 1.5 s after an egg is grabbed. Play a roar sound placeholder, then chase the carrier in a straight line, facing them.
- **Catch** (within 5 studs):
  - The egg returns to the nest.
  - The player gets flung (impulse away from the guardian plus upward) and stunned for 1.5 s.
- **Give up** when the carrier crosses the exit line or enters the escape lane, then walk back to sleep.
- **Blood Moon:** guardians are 15% faster.
- **Secret Egg grabbed:** every guardian in that biome wakes up.

---

## 9. Player base (plot)

- **Plot sign:** shows the owner's name. Plots are assigned on join and released on leave.
- **Incubators:** start with 2, max 6. Walking onto your plot with an egg puts it in a free incubator automatically. If all are full, show *"Incubators full!"* and the player keeps carrying the egg.
  - Each incubator shows a timer and a translucent preview of the egg type.
  - **Hatch timers use `os.time()`,** so eggs keep hatching while the player is offline.
- **Pen:** starts with 6 slots, max 20. Each slot is a pedestal with the creature model on top and a BillboardGui showing `$X/s`.
- **Stable:** inventory for up to 50 creatures (UI only, no models).
- **Lock button:** puts a laser barrier across the plot entrance.
  - It lasts 60 s (+10 s per rebirth), and the player must physically press the button to relock.
  - Plots auto-lock for 30 s on join.
  - Show the lock timer on the HUD.
- **Pen full:** a hatched creature goes to the Stable. If the Stable is full too, it waits in the incubator, which blocks it.

---

## 10. PvP stealing (eggs only, never creatures)

- **From a carrier:** a ProximityPrompt on every carrying player says *"Steal Egg"* (hold 0.7 s, range 8 studs). The thief takes the egg.
- **From a base:** in an **unlocked** plot, every incubator has a *"Steal Egg"* prompt (hold 2 s). The egg loses its hatch progress.
  - The owner gets a red screen flash, an alarm sound placeholder, and the alert *"Your base is being raided!"*
- **Take back:** within 10 s of a theft, the victim gets a *"Take Back"* prompt on the thief (hold 0.5 s, range 10 studs). Using it returns the egg to the victim's incubator.
- **Protections:**
  - **New-player shield:** for a player's first 15 minutes of total playtime, their plot is always locked, they can't be stolen from, and they can't steal either. Show a shield icon on the HUD.
  - Each player can be robbed at most once every 60 s.
  - Nobody can steal while stunned or within 3 s of a catch.

---

## 11. Gear (bought with cash)

**Price** = 30 seconds of the player's current income (minimum $50), so gear stays relevant all game.

| Gear | Effect |
|---|---|
| **Net Gun** | Hits a player within 40 studs: they're slowed 50% for 3 s. 20 s cooldown. Can't target shielded players. |
| **Slip Trap** | Placed on the ground. The first player or guardian to touch it is slowed 70% for 2 s. Max 2 placed at once; each lasts 60 s. |
| **Speed Soda** | +25% speed for 20 s. Single use. |

---

## 12. Server events

- **Secret Egg** (every 5 min):
  - Spawns at a random spot in a random biome from the Desert onward, with a rainbow beam visible across the whole map.
  - The server announces: *"A SECRET EGG appeared in the Volcano!"*
  - Grabbing it wakes every guardian in that biome.
  - It hatches (60 s) into a **Mythic** of one of that biome's species.
- **Weather** (every 10 min, lasts 2 min; picked at random):
  - **Thunderstorm:** rain particles, dark sky.
  - **Golden Hour:** warm ColorCorrection.
  - **Blood Moon:** red sky, guardians +15% speed.
  - A banner shows the event and its countdown, and any egg grabbed during it rolls for the matching mutation.
- **Mama's Revenge** (every 20 min): a co-op boss that pulls the whole server together in a game that's otherwise player-versus-player.
  - **Warning:** 30 s before she arrives, the sky darkens, a siren placeholder plays, and a banner reads *"MAMA DRAGON IS COMING! Defend your eggs!"* Don't start her while a weather event is running; wait until it ends.
  - **Mama Dragon:** the Cosmic Dragon recipe at 4× scale, anchored and moved with `PivotTo` like the other guardians. She walks from the Biome Road end of Home Row to the Plaza and back, which takes 2 min, with a camera-shake stomp every step.
  - **Snatching:** every 6 s she reaches toward the nearest plot that has eggs in its incubators and snatches one egg into her hoard (a glowing pile on her back). **Base locks don't stop her, but the new-player shield does:** she skips shielded players.
  - **Weak spots:** 3 glowing neon orbs on her body (head, chest, tail), each with a ClickDetector (`MaxActivationDistance = 80`). Each click is 1 damage. The server caps each player at 8 clicks per second. Her HP = `150 × players on the server` (minimum 300). Each hit makes her flinch and flashes the orb.
  - **Event UI:** a big HP bar at the top of the screen, a countdown, and a live top-3 damage list.
  - **She's defeated:** her hoard bursts. Every snatched egg goes back to its owner, keeping its hatch progress. Everyone who dealt at least 10 damage gets a **Lucky Egg**, and the top 3 damage dealers get a second one. Show *"MAMA DEFEATED!"* with a particle burst.
  - **She escapes:** the snatched eggs are lost, and the banner reads *"Mama escaped with N eggs…"*
  - **Lucky Egg:** hatches in 30 s into a creature from the deepest biome the player owns a creature from. Its rarity rolls one step better than normal, so the minimum is Uncommon.
  - **Delivery:** returned eggs and Lucky Eggs go into a free incubator. If every incubator is full, they wait in `PendingEggs` and are placed automatically as soon as an incubator frees up.

---

## 13. Fuse and sell

- **Fuse Machine** (in the Plaza): takes 3 creatures of the same species and rarity and makes 1 of the next rarity. The result keeps the best mutation of the three. It's free. Mythic can't be fused.
- **Sell:** a creature sells for 60 × its income/s. Players can sell from the Stable UI, with a confirmation for Epic and above.

---

## 14. Rebirth

| Rebirth | Cash | Must own a creature from | Rewards |
|---|---:|---|---|
| 1 | 100K | Jungle | +1 incubator |
| 2 | 1M | Tundra | +2 pen slots |
| 3 | 10M | Volcano | 2nd mount slot |
| 4 | 100M | Cosmic | +1 incubator |
| 5+ | ×10 each | Cosmic | +2 pen slots |

- **Every Rebirth also gives:** +0.5× cash multiplier and +10 s base lock.
- **Resets:** cash, creatures (**except equipped mounts**), incubator contents, pen, saddle level, gear.
- **Keeps:** rebirth rewards, mounts, Index, game passes.

---

## 15. Economy (starting values; tune in playtests)

| Item | Cost |
|---|---|
| Saddle level n (+1 speed, max 20) | `100 * 1.8^n` |
| Incubator 3 / 4 / 5 / 6 | 1K / 25K / 500K / 10M |
| Pen slot k (7–20) | `250 * 3^(k-7)` |
| Gear | 30 s of current income (min $50) |

**Offline:** the pen earns at 50% while the player is away (capped at 8 h), and eggs keep hatching. On return, show *"While you were away: +$X and N eggs hatched!"*

---

## 16. UI

Bright, chunky and readable on phones: big rounded buttons with UICorner, UIStroke and UIGradient, plus scale-based sizes and UIScale.

| Area | Contents |
|---|---|
| **Top** | Cash, Cash/s, Speed, Rebirths, shield icon (if active), base lock timer |
| **Left** | Stable, Shop, Index, Rebirth buttons |
| **Right** | Event banner (weather or Secret Egg), with a countdown |
| **Bottom center** | Gear hotbar and the ability button (ContextActionService buttons on mobile) |
| **Alerts** | Raid alerts, "Egg stolen!", "Caught by the Swan!", "Nests refilled!" |

- **Stable panel:** a grid of creature cards (ViewportFrame model, rarity color, mutation badge, income, speed, ability). Card buttons: **Pen**, **Ride**, **Fuse**, **Sell**.
- **Shop panel:** Saddle, Incubators, Pen Slots, Gear.
- **Index:** species × rarity grid. Silhouettes until discovered; each first discovery pays 60 s of income.
- **Tutorial** (first session): a `Beam` arrow guides the player through: grab a Forest egg → bring it home → wait for it to hatch → **ride it** → go steal from the Lake. Each step has a one-line hint.
- **Daily reward:** a 7-day streak of cash, then a Luck Potion on day 7.

---

## 17. Data and saving

DataStore `"StealARide_v1"`, key `"u_" .. UserId`:

```lua
{
  Cash, Rebirths, PlaytimeSeconds, LastOnline,
  Creatures = { [uid] = { species, rarity, mutation } },
  Pen = { uid, ... }, Mounts = { uid, ... },
  Incubators = { { biome, mutation, secret, lucky, startedAt } or false, ... },
  PendingEggs = { { biome, mutation, secret, lucky, progress }, ... },  -- waiting for a free incubator
  IncubatorCount, PenSlots, SaddleLevel,
  Gear = { net = 0, trap = 0, soda = 0 },
  Index = { ["Fox_Rare"] = true, ... },
  DailyStreak, LastDaily,
}
```

- Wrap every DataStore call in `pcall` and load with up to 3 retries.
- **If the load fails, never save that player this session,** and warn them in the UI.
- Save with `UpdateAsync` on leave, every 60 s, after a Rebirth and after a Fuse, and for every player in `game:BindToClose`.
- Replicate the HUD values through Player attributes. Send Stable and Index contents to the client through a RemoteFunction `GetInventory` and a RemoteEvent `InventoryChanged`.

---

## 18. Architecture

```
ReplicatedStorage
  Shared
    Config (ModuleScript)          -- biomes, species, rarities, mutations, costs, timers
    Format (ModuleScript)          -- 1.23K / M / B / T / Qa ...
    CreatureBuilder (ModuleScript)
  Remotes
    PlaceInPen, RemoveFromPen, EquipMount, UnequipMount, UseAbility,
    Fuse, Sell, Buy, UseGear, Rebirth, LockBase, ClaimDaily   (RemoteEvents)
    GetInventory (RemoteFunction), InventoryChanged (RemoteEvent)
ServerScriptService
  Main (Script)                    -- requires and starts the services
  Services
    DataService, PlotService, EggService (nests, carrying, Secret Egg),
    GuardianService, HatchService, CreatureService (pen, stable, income, mounts),
    StealService, ShopService, EventService (weather, Mama), RebirthService
StarterPlayerScripts
  ClientMain (LocalScript)         -- abilities, biome lighting, tutorial, effects
StarterGui
  MainUI (ScreenGui, ResetOnSpawn = false) + UIController (LocalScript)
Workspace
  HomeRow (plots), Plaza, Biomes/<Biome> (Nest, Guardian, ExitLine, EscapeLane, Props)
```

**Mounts:**
1. Clone the creature model with CreatureBuilder.
2. Make every part Massless and CanCollide = false.
3. Weld it under the HumanoidRootPart.
4. Raise `Humanoid.HipHeight` so the player sits on top.
5. The server sets WalkSpeed. The client plays a bobbing tween.

---

## 19. Security

- The server owns all cash, creatures, eggs and rolls. The client only fires the remotes above, and every remote validates its argument types, ownership of the uids involved, and costs.
- **Pickups and steals** use ProximityPrompts, whose `Triggered` event runs on the server, with server-side distance checks.
- **Anti speed-hack:** while a player carries an egg, the server samples their position every 0.5 s. If they move faster than `(allowedSpeed * 1.4 + 5)` studs/s (allowing for Dash and Speed Soda), the egg drops back to its nest.
- **Lanes:** the server checks that a player has the matching ability before a guardian gives up because of a lane.

---

## 20. Monetization and Roblox policy

- **Game passes:**
  - VIP: +50% cash, plus a chat tag
  - Extra Mount Slot
  - +2 Incubators
  - +5 Pen Slots
  - Lucky: rarity rolls shift one step for 10% of hatches
- **Developer products:**
  - Instant Hatch
  - 15-minute Luck Potion
  - Server Luck: affects everyone on the server, so buying it is social
- **Rewarded video ads** (Roblox's built-in feature, which is allowed): *"Watch an ad: 2× luck for 10 min."*
- **Don't sell** raw speed or guaranteed steals. In a PvP game that's pay-to-win, and it kills retention.
- **Never add** media feeds, autoplay video or infinite scroll tied to rewards. Roblox age-gates those for under-16s (August 2026 policy, after Steal an Egg).
- Fill out the Experience Questionnaire honestly. Theft is cartoon PvP, with no violence beyond the fling.

---

## 21. Balance targets (not simulated yet; tune in playtests)

| Milestone | Target |
|---|---|
| First Forest egg grabbed | < 30 s |
| First hatch | < 1 min |
| First ride | < 2 min (tutorial) |
| First Lake egg | ~5 min |
| First Rebirth | 45–60 min |
| First Cosmic egg | 3–4 h |

---

## Build parts

### Part 1: Foundation

1. Folders, Remotes, Config, Format and CreatureBuilder. Build one test model per species and screenshot-check that they look distinct.
2. DataService with the load-fail guard.
3. PlotService: 8 plots, assignment, owner signs.
4. Map skeleton: Home Row, Plaza, Biome Road, a full Forest and Lake, and flat placeholder zones for the other 5 biomes.
5. HUD (Cash, Cash/s, Speed).

**Done when:**
- [ ] A joining player gets a plot
- [ ] Data saves and loads
- [ ] All 21 species build without errors
- [ ] The playtest Output is clean

### Part 2: The heist loop

1. Nests and refills, egg carrying (welded above the head), and the `CarryingEgg` attribute.
2. GuardianService for Forest and Lake: sleep, wake, chase, catch, fling, give up.
3. Incubators and hatching (with `os.time()` timers), the rarity and species rolls, Pen, Stable and income.
4. Stable UI (Pen, Sell) and the first-session tutorial Beam.

**Done when:**
- [ ] Forest eggs can be stolen, hatched and placed in the pen, and they earn cash
- [ ] The Swan catches walkers but not players riding a Forest Common (verify with a server test)

### Part 3: The riding twist

1. Mounts: equip/unequip, weld, HipHeight, speed, Ride button.
2. All six abilities, escape lanes and their penalties.
3. Biomes 3–7 fully built, with guardians.
4. Shop: Saddle, Incubators, Pen Slots.

**Done when:**
- [ ] Each biome's Common mount escapes the next biome on the main road
- [ ] Each lane stops its guardian only for players with the right ability
- [ ] Abilities work on PC and mobile

### Part 4: PvP and events

1. StealService: carrier steals, base raids, take-back, lock button, new-player shield, rob cooldown.
2. Gear: Net Gun, Slip Trap, Speed Soda.
3. EventService: Secret Egg, weather, mutations.
4. Fuse Machine, Rebirth, anti speed-hack.

**Done when:**
- [ ] Stealing works between two players (test with a 2-player local server)
- [ ] The shield blocks all stealing
- [ ] Mutations apply
- [ ] Rebirth keeps the equipped mounts

### Part 5: Retention and polish

1. Index, daily rewards, the offline summary popup.
2. Effects: hatch burst, rarity-colored beams, catch fling effect, sound placeholders (SoundId left blank).
3. Monetization with placeholder IDs, and ProcessReceipt that's idempotent (store receipt IDs).
4. **Mama's Revenge**, exactly as described in section 12: warning, walk, snatching, weak spots, HP bar, rewards, Lucky Eggs and `PendingEggs`.
5. A full test pass and fixes.

**Done when:**
- [ ] Mama's Revenge runs start to finish in both outcomes (defeated and escaped)
- [ ] Everything on the testing list below passes

### Part 6: Polish pass (uses Roblox Studio's built-in MCP tools)

1. **3D models** (`generate_mesh`):
   - Generate a mesh for each of the 21 species, the 7 guardians and Mama Dragon.
   - Use one consistent style prompt for all of them: *"cute chunky toy-like creature, bright saturated colors, big friendly eyes, simple shapes, Roblox style"*, plus each species' description and biome.
   - Store them in `ReplicatedStorage/CreatureMeshes/<Name>`, each as a Model with a PrimaryPart.
   - CreatureBuilder uses the mesh when it exists and falls back to the primitive recipe when it doesn't. Rarity scale and mutation effects still apply; for Golden and Cursed, add a tinted `Highlight` plus the particles.
   - Mounts recompute their weld offset and `HipHeight` from the mesh's bounding box.
   - Guardians keep their anchored `PivotTo` movement.
2. **Materials** (`generate_material`): one MaterialVariant per biome floor:
   - Forest: mossy grass
   - Lake: wet pebbles
   - Desert: cracked sandstone
   - Jungle: mud
   - Tundra: packed snow
   - Volcano: basalt with glowing cracks
   - Cosmic: dark starfield glass
3. **Props** (`generate_procedural_model`): 5–8 prop types per biome (trees, cacti, ice spikes, lava rocks, crystals, floating rocks). Scatter them, but keep the road, nests, exit lines and escape lanes clear.
4. **Sound** (`search_asset` + `insert_asset`, **free Creator Store assets only**):
   - **Gameplay:** egg grab, a roar per guardian, catch fling, hatch crack, a reveal sting per rarity, purchase, lock and unlock, raid alarm.
   - **Mama Dragon:** siren and stomp.
   - **Weather:** rain and thunder loops.
   - **Ambience:** a loop for each of the 7 biomes.
   - **Music:** a Home Row theme and a chase sting.
   - Put them in `SoundService/SFX` and fill every blank SoundId from Parts 1–5. Record every asset ID in `Config.Sounds`.
   - If nothing suitable turns up for a sound, leave it blank and list it for the user.
5. **Game feel:**
   - **Hatch moment:** the egg wobbles for 1.5 s, cracks, and the camera tweens in. A burst of light in the rarity's color goes off and the creature pops out with a scale bounce. Legendary and Mythic hatches are announced to the whole server.
   - **Chase:**
     - A chase sting plays when the guardian wakes.
     - The heartbeat volume and a red screen-edge vignette grow as the guardian gets closer.
     - The camera shakes on a catch.
   - **Mounts:** a Trail in the rarity's color, plus a dust ParticleEmitter at the feet while moving.
   - **Biome ambience:** swapped client-side when the player enters a biome.
   - **Stable cards:** the ViewportFrame models rotate slowly.
6. **2D art (only if an image-generation connector is available, e.g. fal.ai; otherwise skip this step and tell the user):**
   - **In-game art:** ability icons, gear icons, rarity badges. Upload them with `upload_image`, which takes hosted image URLs, and use the returned asset IDs in the UI.
   - **For the Roblox page:** a 512×512 game icon and 3 thumbnails at 1920×1080: a heist escape, a riding moment, and the Mama Dragon fight. Save them to an `art` folder next to this file for the user to upload in Creator Hub.
7. **Visual check** (`screen_capture`): screenshot Home Row, every biome, a hatch, a chase, and the Stable panel. Fix anything that looks broken, and show the user the screenshots.

**Done when:**
- [ ] Every creature, guardian and Mama uses a mesh (or the fallback is noted) and mounts sit correctly
- [ ] Every SoundId is filled or listed as missing
- [ ] Each biome has its material and props, with the road and lanes clear
- [ ] A playtest with every pen full (spawn test creatures) runs without noticeable frame drops; if it doesn't, use the primitive fallback for other players' pens beyond 60 studs
- [ ] The playtest Output is clean

---

## Testing

Roblox Studio's built-in MCP tools let you **see and drive the game**. Use `screen_capture` to look at it, and `character_navigation`, `user_mouse_input` and `user_keyboard_input` to walk, click the UI and run real chases. You still can't control two players at once.

For logic checks, **call the service modules directly from a temporary server Script** during a playtest, then delete that Script. Check:

1. No script errors in Output
2. Plot assignment and release
3. Egg grab, guardian chase, catch and escape at the speeds in the biome table
4. Escape lanes, with and without the ability
5. Hatch rolls: run 10,000 simulated rolls and check the odds match the tables
6. Pen income and the formulas
7. Mounts, speed and HipHeight
8. Fuse, Sell and Rebirth (including what resets and what's kept)
9. Steal rules and all the protections
10. Mama's Revenge: start her early from a test Script, snatch eggs from a test plot, and confirm she skips shielded players. Run both outcomes: deal enough damage to defeat her (eggs come back, Lucky Eggs are granted), and let her escape (eggs are lost). Also check that eggs go to `PendingEggs` when incubators are full.
11. The saved data shape, and that a failed load blocks saving
12. That the UI fits a phone-sized screen

Tell the user which checks need a real **2-player local server** (Studio → Test → Clients and Servers).

---

## Setup notes (for the user)

- **Saving won't work in Studio until you turn it on.** Publish the place, then enable *Game Settings → Security → Enable Studio Access to API Services*.
- **Studio's MCP server must be on:** *Assistant → … → Manage MCP Servers → Enable Studio as MCP server*. Keep Studio open with the place loaded while the AI works.
- **To build, send one part at a time:** *"Build Part 1 from steal-a-ride.md"*, then Part 2, and so on through Part 6.
- **Part 6's 2D art step** needs an image-generation connector such as fal.ai, with your own API key. Without one, the AI skips that step.
- **Test PvP yourself** with Studio's *Test → Clients and Servers → 2 players*.
- **If something breaks:** tell the AI *"Playtest, read the Output, and fix all errors from your scripts."*
