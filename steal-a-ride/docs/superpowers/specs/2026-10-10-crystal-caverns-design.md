# Crystal Caverns (biome #9) + new Climb ability (design)

Status: APPROVED in conversation 2026-10-10 (all four sections). Awaiting written-spec review. Not implemented.
Supersedes the biome order in `2026-10-09-biomes-8-14-roster-design.md` (updated there too).

## Goal

Add biome #9, Crystal Caverns, beyond Mystic Grove, with the game's first brand-new escape ability since Phase:
**Climb**. Climb is a *route* ability (shortcuts over walls), not another hiding patch. Ship it with a biome
checklist test so this and every later biome keeps every per-biome hook (effects, sounds, music, odds, ...).

## User decisions (2026-10-10)

- New order: 8 Mystic Grove (live), **9 Crystal Caverns (Climb)**, 10 Atlantis (Swim), 11 Sky Kingdom (Glide),
  12 Haunted Realm (Phase), 13 Cyber City (Shockproof), 14 The Void (Glide). Glide repeats 3 biomes apart (accepted).
- Climb = shortcuts (option 2). Wall tops crack after **1.5 s** and drop you down the exit side (option a).
- **3-4 walls** across the route, gaps alternating sides.
- Look: **prism quartz** (bright cave, white/clear quartz, rainbow light). Not purple/dark (too close to Cosmic).
- Pacing: first Crystal Caverns **30-45 real min after first Mystic Grove** (same gap as Mystic after Cosmic).
- Models: **Blender meshes for all four** (Golem + 3 species) plus props.
- Imports: Claude imports the FBX files into Studio via computer use (desktop control) when the user grants it.
- Species unchanged from the roster: Crystal Beetle (none, 50%), Gem Gecko (Climb, 35%), Crystal Pangolin
  (none, large like Mammoth, 15%).

## 1. Biome and run

- Built by a new edit-time tool `ServerStorage.BuildTools.BuildCrystalCaverns`, appended past Mystic Grove's far
  end like `BuildMysticGrove`. It asserts the biome doesn't exist yet and never moves/rebuilds earlier biomes; it
  extends the shared road into a cave mouth.
- Look: pale grey stone floor and walls, a rock ceiling over the route with open cracks; light shafts through the
  cracks; clear/milky quartz clusters; rainbow beams and coloured light spots where light hits quartz. Bright overall.
- Run: enter from Mystic Grove's end, ride to the nest at the back (Golem patrols its usual circle), grab, head home.
  **3-4 quartz walls** cross the route between nest and exit. Each wall is a single faceted slab, taller than any
  jump, with a gap at one end; gap sides alternate wall to wall; every gap is wide enough for the Golem's
  `pathRadius` and leads toward the exit (no dead ends).
- With Climb: run up the wall, cross the top, the top cracks after 1.5 s and drops you on the exit side; the Golem
  detours through the gap. Without Climb: take the gaps (same path as the Golem, a normal race); Dash still works.
- After the exit the normal rules apply (leash ~35 studs, rage, Forest surge, Blood Moon). So a wall's lead only
  helps you get out of the cave; it can't trivialise the escape.
- No escape patches (EscapeLane) and no other hazards in this biome; the walls replace patches.

## 2. Climb (code)

- Walls: anchored, collidable slabs (pathfinding treats them as obstacles). Faces tagged `ClimbWall`; a thin zone
  on each wall top tagged `ClimbTop`.
- Height: ~40 studs, final value measured in Studio against the best Jump (`jumpMult` 2, ~29 studs) + Glide
  combination. Also puts a rider on top beyond the guardian's vertical catch reach (`height*0.5 + catchRadius`).
- Client (player's device, like Jump/Glide/Phase): riding a Climb mount and pushing into a `ClimbWall` face (short
  forward raycast from the root, length scaled to the mount) moves you up at ~0.6 x ride speed; at the top edge you
  continue onto the top. EggService's anti-speed check is horizontal-only, so climbing never drops the egg.
- Server (`AbilityService.check`, 0.2 s loop):
  - In `ClimbTop` with Climb: start a timer and set player attribute `ClimbSince` (server time; clients play a
    quick crack warning, separate from the 4 s patch warning). At `Config.Abilities.Climb.crackAfter` (1.5 s):
    toast "The crystal cracks!" and push the rider off the exit side of that wall. Egg kept.
  - In `ClimbTop` without Climb: push off the side they came from immediately, toast "Only Climb riders can cross
    the crystal". Egg kept (not the entrance-teleport penalty).
- Pure helpers for tests: `AbilityService.climbPush(wallCFrame, wallSize, pos, exitSide)` (where to land) and the
  crack-timer decision, unit-tested in the harness like the guardian helpers.
- Config: `Config.Abilities.Climb = { speedMult = 0.6, crackAfter = 1.5 }`; `Config.Patch.messages.CrystalCaverns`
  = the crack message; Climb icon in the ability icon table (new image upload); Guide tip; Gem Gecko `ability = "Climb"`.
- First plan task: a throwaway test wall in Studio to prove a large mount climbs smoothly (raycast + upward push)
  before any map work.

## 3. Golem, species, Blender pipeline

| Model | Role | Gait | Notes |
|---|---|---|---|
| Crystal Golem | guardian | biped (like Tundra Yeti) | hulking quartz body, rainbow core, heavy fists; no fly, no climb |
| Crystal Beetle | common, none | insect quad (like Scarab) | small, faceted quartz shell |
| Gem Gecko | mid, Climb | quad | slim, gem-studded, sticky toe pads |
| Crystal Pangolin | rarest, none | quad, large (like Mammoth) | overlapping quartz scale plates |

- Pipeline: existing `CreatureRig` mesh path: one mesh per creature, cut at fixed heights into legs/arms at server
  start, animated by `WalkCycle`. In Blender, legs (and the Golem's arms) stay clearly separated below one cut
  height. Each creature gets its `CreatureRig` cut entries plus `Config.Species` / `Config.Guardians` entries.
- Shading: Roblox materials/colours (Glass or semi-transparent white/grey quartz, Neon core/gem accents), no baked
  textures. Rainbow comes from the FX layer.
- Budgets: Golem <= ~10k triangles, pets <= ~4k, props <= ~2k (Roblox limit 20k per mesh).
- Props: 3 quartz wall slab variants, 4 crystal clusters, 2 boulders, 1 ceiling-crack piece.
- Flow: Claude models in Blender (new session, using the Blender connector on port 9877), renders previews for the user, exports
  FBX to `steal-a-ride/assets/crystal-caverns/`; Claude imports via Studio's 3D Importer with computer use; then
  places, rigs, configures in Studio via the Roblox MCP.
- Golem FX (`Config.GuardianFX.guardians.CrystalCaverns`): quartz glint + soft rainbow sparkle, quartz-dust step,
  `rage` overlay of rainbow shards on top of the shared enraged package. Sounds (`Config.GuardianSounds`): idle,
  alert, chase, step from licensed Roblox audio, load-checked; rage sound = a grinding-stone roar. Egg/hatch theme:
  quartz sparkle.

## 4. Tuning, checklist test, testing, release

- Pacing: `tools/pacing-sim/crystal.py` (from `mystic.py`) models the Golem, walls as lead-per-wall for Climb
  riders, and the post-exit leash. Tunes guardianSpeed, depth, nest z, carry, hatchTime, baseIncome, mountBase and
  Secret Egg odds (~`{0,0,0,50,30,20}`). Targets: first Crystal median ~37 real min after first Mystic (30-45);
  a Dash rider without Climb can escape; Climb adds ~10-20 percentage points of escapes at equal ride speed.
  Numbers shown to the user before applying.
- **Biome checklist test** `tests/run_biome_checks.py`, written first (RED), loops `Config.Biomes` and asserts per
  biome: 3 species whose abilities exist; `Config.Guardians` recipe; `GuardianFX` set; `GuardianSounds`
  idle/alert/chase/step; `Config.guardianRage` package; `EggFX.themes`; `EscapeMusic.tracks`; `Ambience<Biome>`
  sound id; `Patch.messages`; `secretOddsByBiome`; BiomeVFX air/light/particle entries; a Guide tip; lane ability in
  `Config.Abilities` with an icon; `CreatureRig` cut entries for every mesh creature. The file lists every
  per-biome hook in one place for Atlantis and later. Done when it passes.
- Ambience: cave drips + soft crystal chimes; escape music; BiomeVFX light shafts, rainbow floor spots, floating
  dust motes, bloom tuned for bright quartz.
- Verification: all test suites pass; Studio == local (LF djb2) with backups (ServerStorage + local `before-*`);
  Play: climb/cross/crack/drop, non-Climb push-off, Golem paths every gap without sticking, Dash escape without
  Climb, Climb runs gain the expected lead, Golem rage FX/SFX, hatch + Index for all 3 species, best Jump+Glide
  height vs wall height.
- Release: What's New entry for Crystal Caverns (v6, or folded into v5 if v5 is still unpublished at release:
  user's call); roster spec order updated; HANDOFF updated; commit on `main`; user publishes from Studio.

## Out of scope

Atlantis and later biomes; rebirth table / cash milestones; new base themes; any change to existing biomes'
balance.
