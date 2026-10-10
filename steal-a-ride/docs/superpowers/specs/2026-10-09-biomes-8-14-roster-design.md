# Biomes 8-14: escape abilities + creature roster (design)

Status: LOCKED by user 2026-10-09 (roster + escape abilities only). Not implemented.
Scope: which escape ability each new biome uses and which 3 species hatch there.
Out of scope (separate design passes): guardian/patrol speeds, hatch times, income, carry, rebirth table,
saddle costs, map layout, hazards/VFX/sounds, guardian models.

## Context (current game, confirmed in source)

- 7 biomes, 3 species each, hatch weights `Config.SpeciesWeights = { 50, 35, 15 }`.
- Escape abilities in use: Swim (Lake, Jungle), Jump (Desert), Glide (Tundra), Fireproof (Volcano), Phase (Cosmic).
- `GuardianService.hasLane` (Main.luau) = any ridden mount has the biome's ability. Abilities from all ridden mounts stack.
- `Config.Guardian.noLaneWakeDelay = 0`, `noLaneSpeedMult = 1`: lacking the ability is NOT penalised; the ability
  only lets you use that biome's escape patches safely. So no biome is hard-gated by an ability.
- Ride speed comes from the species' home biome (`mountBase`), so old pets still work on later patches, just slower.

## Escape ability per biome

**Order changed by user 2026-10-10:** 8 Mystic Grove, 9 Crystal Caverns (Climb), 10 Atlantis, 11 Sky Kingdom,
12 Haunted Realm, 13 Cyber City, 14 The Void (Glide now 3 biomes after Sky Kingdom, accepted). The table below
keeps the original numbering; species are unchanged. Crystal Caverns design: `2026-10-10-crystal-caverns-design.md`.

| # | Biome | Guardian | Escape ability | Patch idea | Ability last used |
|---|---|---|---|---|---|
| 8 | Mystic Grove | Giant Spider | Jump | Bouncy mushroom caps | Desert (#3) |
| 9 | Atlantis | Leviathan | Swim | Deep currents | Jungle (#4) |
| 10 | Sky Kingdom | Griffin | Glide | Gaps between clouds | Tundra (#5) |
| 11 | Haunted Realm | Cerberus | Phase | Ghost walls | Cosmic (#7) |
| 12 | Crystal Caverns | Crystal Golem | **Climb (new)** | Crystal walls | - |
| 13 | Cyber City | Mecha T-Rex | **Shockproof (new)** | Electrified floor grid | - |
| 14 | The Void | Void Titan | Glide | Falling between floating islands | Sky Kingdom (#10) |

Rules behind it: no ability repeats within 3 biomes; reuse an existing ability wherever it fits the theme;
only 2 new abilities, each placed in the biome where it is most obvious.

## Creature roster

| # | Biome | Common (50%) | Mid (35%) | Rarest (15%) |
|---|---|---|---|---|
| 8 | Mystic Grove | Shroomling (None) | Glow Deer (Jump) | Wisp Lynx (Phase) |
| 9 | Atlantis | Coral Crab (None) | Sea Turtle (Swim) | Manta Ray (Swim, flies) |
| 10 | Sky Kingdom | Cloud Sheep (Jump) | Pegasus (Glide, flies) | Phoenix (Glide, flies) |
| 11 | Haunted Realm | Ghost Cat (Phase) | Skeleton Horse (Dash) | Phantom Wolf (Phase) |
| 12 | Crystal Caverns | Crystal Beetle (None) | Gem Gecko (Climb) | Crystal Pangolin (None, large like Mammoth) |
| 13 | Cyber City | Robo Mouse (Shockproof) | Cyber Cheetah (Dash) | Mecha Raptor (Shockproof) |
| 14 | The Void | Voidling (Phase) | Rift Rabbit (Dash) | Eclipse Moth (Glide, flies) |

Decisions recorded:
- Wisp Lynx replaces Spirit Fox (Fox and Comet Fox already exist). Its Phase is a head start for Haunted Realm.
- Manta Ray gains flight so it differs from Sea Turtle; Crystal Pangolin drops Climb and is a big no-ability
  pet (Mammoth precedent) so it differs from Gem Gecko. Phoenix/Mecha Raptor duplicates accepted.
- Lane carriers: #8 Glow Deer; #9 Sea Turtle, Manta Ray; #10 Pegasus, Phoenix; #11 Ghost Cat, Phantom Wolf;
  #12 Gem Gecko only; #13 Robo Mouse, Mecha Raptor; #14 Eclipse Moth (plus any older Glide pet).
- Flyers added (`canFly`): Manta Ray, Pegasus, Phoenix, Eclipse Moth.
- No intro Climb/Shockproof mount: not needed because lacking an ability is not penalised (see Context).

## Implementation notes for later passes

- Each new species needs a `Config.Species` recipe; many need new `CreatureBuilder` features
  (antlers, mushroom cap, fins/ray wings, spiral shell, robot plating, horn, crystal spikes). List per species in the build spec.
- Climb and Shockproof each need: AbilityService hazard, patch type in BuildPatches, `Config.Patch.messages`,
  patch sound (Effects), BiomeVFX patch spec, Guide tip, tests.
- Tuning (speeds, hatchTime, baseIncome, carry, mountBase) to be set with tools/pacing-sim; the user's
  placeholder chase speeds (110..220, patrol = 0.45 x chase) predate the current guardian tuning.
